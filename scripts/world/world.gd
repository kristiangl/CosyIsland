class_name World
extends Node3D
## The live island: terrain meshes, object nodes, walkability and the island's rules
## (chopping, hitting rocks, shaking trees, dropping and picking up items, placing things).

const T := IslandData.Tile
const WOOD_PER_DAY := 3
const ROCK_HITS := 8
const ROCK_COUNT := 6
const FRUIT_REGROW_DAYS := 3
const BRANCHES_PER_TREE := 2
const GIFT_TREES := 2
const BLOCKING_KINDS := ["tree", "fruit_tree", "palm", "rock", "placed"]
const ROCK_TABLE := [["stone", 60], ["clay", 25], ["iron_nugget", 14], ["gold_nugget", 1]]

var data: IslandData
## True for a room inside a home: no terrain, sea or island rules, lamps always lit.
var interior := false
## Look of the room's floor and walls (see RoomBuilder.STYLES).
var room_style := "tent"
## Wallpaper, flooring and curtains put up in this room:
## {"wall": item id, "floor": item id, "window": item id}.
var room_look: Dictionary = {}
var day_key: int
var money_rock_uid: int = -1
var grass: GrassField
## Fish and bugs (outdoors only).
var critters: Critters

var _objects: Dictionary = {}   # uid -> object dictionary
var _nodes: Dictionary = {}     # uid -> Node3D
var _occupant: Dictionary = {}  # tile index -> uid
var _deck: Dictionary = {}      # tile index -> bridge deck height
var _on_surface: Dictionary = {} # tile index -> uid of a small thing sitting on furniture
var _door_fronts: Dictionary = {} # tile index -> uid of the home whose door it's in front of
var _reserved: Dictionary = {}    # tile index -> true where characters stand
var _rugs: Dictionary = {}        # tile index -> uid of the rug on the floor there
var _rng := RandomNumberGenerator.new()
var _is_night := false
var _light_check := 0.0


func setup(island: IslandData, saved: Dictionary = {}) -> void:
	data = island
	_rng.seed = island.seed_value + GameClock.day_key()
	if saved.has("objects"):
		data.objects.clear()
		for obj in saved["objects"]:
			# Natural things left in the water by a change to the island's shape are gone.
			if obj["kind"] in ["tree", "palm", "rock", "flower", "drop"] and not interior \
					and not island.is_land(int(obj["x"]), int(obj["z"])):
				continue
			data.objects.append(_ints(obj))
		data.next_uid = int(saved.get("next_uid", data.next_uid))
	day_key = int(saved.get("day_key", GameClock.day_key()))
	money_rock_uid = int(saved.get("money_rock_uid", -1))

	if interior:
		_is_night = true
		room_look = saved.get("look", {}).duplicate()
		add_child(RoomBuilder.build(data, room_style, room_look))
		for obj in data.objects:
			_register(obj)
		return
	_build_terrain()
	for obj in data.objects:
		_register(obj)
	_add_forest_glow()
	critters = Critters.new()
	add_child(critters)
	critters.setup(self)
	Events.day_changed.connect(_on_day_changed)
	if day_key != GameClock.day_key():
		_on_day_changed(GameClock.day_key())
	elif money_rock_uid < 0:
		_pick_money_rock()
	if not saved.has("objects"):
		wash_up_bottle()
		_hide_tree_gifts()
	else:
		_upgrade_old_save()


func _process(delta: float) -> void:
	if interior:
		return
	_light_check -= delta
	if _light_check > 0.0:
		return
	_light_check = 1.0
	var hour := GameClock.hour_float()
	var night := hour < 6.0 or hour >= 18.5
	if night != _is_night:
		_is_night = night
		get_tree().call_group("night_lights", "set_visible", night)


func to_save() -> Dictionary:
	var out := {"objects": data.objects, "next_uid": data.next_uid, "day_key": day_key, "money_rock_uid": money_rock_uid}
	if interior:
		out["look"] = room_look
	return out


## Puts up wallpaper or flooring indoors. Returns the item it replaced ("" for the
## home's own walls or floor).
func set_room_look(item_id: String) -> String:
	var part: String = ItemDB.get_item(item_id).get("interior", {}).get("part", "")
	if not interior or part == "":
		return ""
	var old: String = room_look.get(part, "")
	room_look[part] = item_id
	var shell := get_node_or_null("Room")
	if shell:
		shell.free()
	var rebuilt := RoomBuilder.build(data, room_style, room_look)
	add_child(rebuilt)
	move_child(rebuilt, 0)
	return old


func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = TerrainBuilder.build_ground(data)
	ground.material_override = TerrainBuilder.terrain_material()
	var plaza := Rect2(data.plaza)
	ground.material_override.set_shader_parameter("plaza", Vector4(plaza.position.x, plaza.position.y, plaza.size.x, plaza.size.y))
	add_child(ground)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = TerrainBuilder.build_sea(data)
	sea.material_override = TerrainBuilder.sea_material()
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	var fresh := MeshInstance3D.new()
	fresh.name = "FreshWater"
	fresh.mesh = TerrainBuilder.build_fresh_water(data)
	fresh.material_override = TerrainBuilder.fresh_material()
	fresh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fresh)
	var foam := MeshInstance3D.new()
	foam.name = "BankFoam"
	foam.mesh = TerrainBuilder.build_bank_foam(data)
	foam.material_override = TerrainBuilder.foam_material()
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)
	grass = GrassField.new()
	grass.name = "Grass"
	grass.build(data, float(Game.args.get("grass", "1.0")))
	add_child(grass)


# --- Objects -------------------------------------------------------------------------

func objects() -> Array:
	return _objects.values()


func get_object(uid: int) -> Dictionary:
	return _objects.get(uid, {})


func object_at(x: int, z: int) -> Dictionary:
	if not data.in_bounds(x, z):
		return {}
	return _objects.get(_occupant.get(data.idx(x, z), -1), {})


## Rugs lie on the floor under everything else: walkable, and furniture stands on them.
static func is_rug(obj: Dictionary) -> bool:
	return obj.get("kind", "") == "placed" and ItemDB.placeable(obj.get("item", "")).get("rug", false)


func rug_at(x: int, z: int) -> Dictionary:
	if not data.in_bounds(x, z):
		return {}
	return _objects.get(_rugs.get(data.idx(x, z), -1), {})


func add_object(obj: Dictionary) -> Dictionary:
	obj["uid"] = data.new_uid()
	data.objects.append(obj)
	_register(obj)
	if obj["kind"] == "placed":
		Events.placed_changed.emit()
	return obj


func remove_object(uid: int) -> void:
	var obj: Dictionary = _objects.get(uid, {})
	if obj.is_empty():
		return
	_door_fronts.erase(_door_fronts.find_key(uid))
	for tile in footprint(obj):
		var i := data.idx(tile.x, tile.y)
		if obj.has("on"):
			_on_surface.erase(i)
			continue
		if _occupant.get(i, -1) == uid:
			_occupant.erase(i)
		if _rugs.get(i, -1) == uid:
			_rugs.erase(i)
		if obj["kind"] == "placed" and grass:
			var covered: bool = _rugs.has(i) or _objects.get(_occupant.get(i, -1), {}).get("kind", "") == "placed"
			grass.set_tile_visible(data, tile.x, tile.y, not covered)
	_objects.erase(uid)
	data.objects.erase(obj)
	if _nodes.has(uid):
		_nodes[uid].queue_free()
		_nodes.erase(uid)
	if obj["kind"] == "placed":
		Events.placed_changed.emit()


func footprint(obj: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	match obj["kind"]:
		"placed":
			for z in obj["d"]:
				for x in obj["w"]:
					tiles.append(Vector2i(obj["x"] + x, obj["z"] + z))
		"bridge":
			var axis := Vector2i(1, 0) if obj["axis"] == "x" else Vector2i(0, 1)
			for k in obj["length"]:
				tiles.append(Vector2i(obj["x"], obj["z"]) + axis * k)
		_:
			tiles.append(Vector2i(obj["x"], obj["z"]))
	return tiles


func _register(obj: Dictionary) -> void:
	var uid: int = obj["uid"]
	_objects[uid] = obj
	if obj["kind"] == "bridge":
		var deck := IslandData.tier_height(data.tier(obj["x"], obj["z"]))
		for tile in footprint(obj):
			_deck[data.idx(tile.x, tile.y)] = deck
		var axis := Vector2i(1, 0) if obj["axis"] == "x" else Vector2i(0, 1)
		var ends := [Vector2i(obj["x"], obj["z"]) - axis, Vector2i(obj["x"], obj["z"]) + axis * obj["length"]]
		for end: Vector2i in ends:
			grass.set_tile_visible(data, end.x, end.y, false)
	elif obj.has("on"):
		_on_surface[data.idx(obj["x"], obj["z"])] = uid
	elif is_rug(obj):
		for tile in footprint(obj):
			_rugs[data.idx(tile.x, tile.y)] = uid
			if grass:
				grass.set_tile_visible(data, tile.x, tile.y, false)
	else:
		var door := door_of(obj)
		if not door.is_empty():
			var front: Vector2i = door["tile"] + door["out"]
			_door_fronts[data.idx(front.x, front.y)] = uid
		for tile in footprint(obj):
			_occupant[data.idx(tile.x, tile.y)] = uid
			if obj["kind"] == "placed" and grass:
				grass.set_tile_visible(data, tile.x, tile.y, false)
	_spawn_node(obj)


func _spawn_node(obj: Dictionary) -> void:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = Models.get_mesh(Models.key_for(obj))
	Models.dress(mesh, Models.flower_material() if obj["kind"] == "flower" else Models.material())
	if obj["kind"] == "drop" or is_rug(obj):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mesh)
	var tiles := footprint(obj)
	var centre := Vector2.ZERO
	for t in tiles:
		centre += Vector2(t) + Vector2(0.5, 0.5)
	centre /= tiles.size()
	var y := data.height_at(centre.x, centre.y)
	match obj["kind"]:
		"bridge":
			y = _deck[data.idx(tiles[0].x, tiles[0].y)]
			if obj["axis"] == "z":
				node.rotation.y = PI * 0.5
		"placed":
			node.rotation.y = -PI * 0.5 * obj.get("rot", 0)
			if obj.has("on"):
				y += ItemDB.placeable(_objects.get(obj["on"], {}).get("item", "")).get("surface", 0.0)
		"tree", "fruit_tree", "palm", "rock", "flower":
			node.rotation.y = fposmod(obj["uid"] * 2.399, TAU)
			if obj["kind"] == "flower":
				node.scale = Vector3.ONE * 1.4
	node.position = Vector3(centre.x, y, centre.y)
	if obj["kind"] == "placed" and ItemDB.placeable(obj["item"]).get("light", false):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ffcf8a")
		lamp.light_energy = 0.4 if interior else 0.7
		lamp.omni_range = 3.0
		lamp.omni_attenuation = 1.5
		lamp.position = Vector3(0, 1.0, 0)
		lamp.visible = _is_night
		lamp.add_to_group("night_lights")
		node.add_child(lamp)
	# Fires, candle flames, chimney smoke.
	if obj["kind"] == "placed":
		for fx: Dictionary in ItemDB.placeable(obj["item"]).get("effects", []):
			var e := Effects.emitter(fx["kind"])
			var at: Array = fx["at"]
			e.position = Vector3(at[0], at[1], at[2])
			e.emitting = true
			if fx.get("night", false):
				e.visible = _is_night
				e.add_to_group("night_lights")
			node.add_child(e)
	add_child(node)
	_nodes[obj["uid"]] = node


func refresh_node(obj: Dictionary) -> void:
	var node: Node3D = _nodes.get(obj["uid"])
	if node and obj["kind"] == "placed":
		# Furniture and buildings are rebuilt whole (effects and lights may change too).
		node.queue_free()
		_nodes.erase(obj["uid"])
		_spawn_node(obj)
	elif node:
		var mesh: MeshInstance3D = node.get_child(0)
		mesh.mesh = Models.get_mesh(Models.key_for(obj))


func node_of(uid: int) -> Node3D:
	return _nodes.get(uid)


# --- Walking -------------------------------------------------------------------------

func ground_height(px: float, pz: float) -> float:
	var x := floori(px)
	var z := floori(pz)
	if data.in_bounds(x, z) and _deck.has(data.idx(x, z)):
		return _deck[data.idx(x, z)]
	return data.height_at(px, pz)


func is_walkable(px: float, pz: float) -> bool:
	var x := floori(px)
	var z := floori(pz)
	if not data.in_bounds(x, z):
		return false
	var i := data.idx(x, z)
	if _deck.has(i):
		return true
	var surface := data.surface_at(px, pz)
	if surface != T.GRASS and surface != T.SAND:
		return false
	# Don't wade out past the waterline on sloping beaches.
	if surface == T.SAND and data.height_at(px, pz) < IslandData.SEA_LEVEL - 0.06:
		return false
	var uid: int = _occupant.get(i, -1)
	return uid < 0 or not _objects[uid]["kind"] in BLOCKING_KINDS


## True if the player can step from `from` to the point (px, pz).
func can_step(from: Vector3, px: float, pz: float) -> bool:
	return is_walkable(px, pz) and absf(ground_height(px, pz) - from.y) <= IslandData.MAX_STEP


# --- Island rules --------------------------------------------------------------------

func chop(obj: Dictionary, player_pos: Vector3) -> void:
	_wiggle(obj, 5.0)
	_burst_towards(obj, player_pos, "chips", 0.55)
	if obj.get("wood_left", 0) <= 0:
		return
	if _drop_near(obj, player_pos, {"item": "wood", "count": 1}):
		obj["wood_left"] -= 1
		Journal.add("wood")


func strike_rock(obj: Dictionary, player_pos: Vector3) -> bool:
	_squash(obj)
	_burst_towards(obj, player_pos, "sparks", 0.35)
	_burst_towards(obj, player_pos, "pebbles", 0.3)
	if obj.get("hits_left", 0) <= 0:
		return false
	var drop := {"item": _roll_rock_item(), "count": 1}
	if obj["uid"] == money_rock_uid:
		drop = {"item": "acorn_pouch", "count": 1, "amount": 100 * (ROCK_HITS + 1 - obj["hits_left"])}
	if not _drop_near(obj, player_pos, drop):
		obj["hits_left"] = 0
		return false
	obj["hits_left"] -= 1
	Journal.add("rock_hits")
	return true


func shake(obj: Dictionary, player_pos: Vector3) -> void:
	_wiggle(obj, 3.0)
	var node := node_of(obj["uid"])
	if node:
		Effects.burst("leaves", node.global_position + Vector3(0, 1.9 if obj["kind"] != "palm" else 2.4, 0))
	if obj["kind"] == "fruit_tree" and obj.get("fruit_count", 0) > 0:
		for i in obj["fruit_count"]:
			_drop_near(obj, player_pos, {"item": obj["fruit"], "count": 1})
		Journal.add("fruit", obj["fruit_count"])
		obj["fruit_count"] = 0
		obj["picked_day"] = day_key
		refresh_node(obj)
	if obj["kind"] in ["tree", "fruit_tree"]:
		if obj.has("gift"):
			# A piece of furniture tumbles out (two trees a day hide one).
			_drop_near(obj, player_pos, {"item": obj["gift"], "count": 1})
			Events.toast.emit("Something fell out of the tree!")
			if node:
				Effects.burst("sparkle", node.global_position + Vector3(0, 1.2, 0))
			obj.erase("gift")
			return
		if obj.get("shaken_day", -1) != day_key:
			obj["shaken_day"] = day_key
			obj["branches"] = 0
		if obj.get("branches", 0) < BRANCHES_PER_TREE and _rng.randf() < 0.75:
			obj["branches"] = obj.get("branches", 0) + 1
			_drop_near(obj, player_pos, {"item": "tree_branch", "count": 1})
			Journal.add("branches")


## Puts placed furniture back in the pockets. Fixed things and homes stay put.
func pack_up(obj: Dictionary) -> bool:
	if obj.get("fixed", false) or ItemDB.placeable(obj["item"]).get("structure", false):
		Events.toast.emit("That's staying right where it is.")
		return false
	for tile in footprint(obj):
		if not obj.has("on") and not is_rug(obj) and _on_surface.has(data.idx(tile.x, tile.y)):
			Events.toast.emit("Clear the things off it first.")
			return false
	if Inventory.add_item(obj["item"]) > 0:
		Events.toast.emit("Your pockets are full!")
		return false
	var node := node_of(obj["uid"])
	if node:
		Effects.burst("dust", node.global_position + Vector3(0, 0.1, 0))
	remove_object(obj["uid"])
	return true


## Picks up whatever is on the tile. Returns true if something was taken.
func pick_up(x: int, z: int) -> bool:
	var obj := object_at(x, z)
	if obj.is_empty():
		return false
	match obj["kind"]:
		"drop":
			if obj["item"] == "acorn_pouch":
				Inventory.add_currency(obj.get("amount", 100))
				Journal.add("acorns_earned", obj.get("amount", 100))
				Events.toast.emit("You got %d %s!" % [obj.get("amount", 100), Game.CURRENCY_NAME.to_lower()])
			elif obj["item"] == "message_bottle":
				Effects.burst("sparkle", Vector3(x + 0.5, data.height_at(x + 0.5, z + 0.5) + 0.4, z + 0.5))
				var learned := Recipes.learn_random(_rng)
				Journal.add("bottles")
				if learned == "":
					Events.toast.emit("A note inside says: \"Hello from across the sea!\"")
				else:
					Events.toast.emit("There's a recipe inside! You learned to make: %s." % ItemDB.display_name(learned))
			else:
				if Inventory.add_item(obj["item"], obj.get("count", 1)) > 0:
					Events.toast.emit("Your pockets are full!")
					return false
				Events.toast.emit("You got %s!" % ItemDB.display_name(obj["item"]).to_lower())
			remove_object(obj["uid"])
			return true
		"flower":
			# Picking takes a bloom and leaves the plant, which flowers again tomorrow.
			if obj.get("picked", false):
				Events.toast.emit("It'll bloom again tomorrow. Dig it up with a shovel to move it.")
				return false
			var id := "%s_%s" % [obj["species"], obj["color"]]
			if Inventory.add_item(id) > 0:
				Events.toast.emit("Your pockets are full!")
				return false
			Events.toast.emit("You picked a %s." % ItemDB.display_name(id).to_lower())
			obj["picked"] = true
			refresh_node(obj)
			Journal.add("flowers_picked")
			Effects.burst("leaves", Vector3(x + 0.5, data.height_at(x + 0.5, z + 0.5) + 0.4, z + 0.5))
			return true
	return false


## Digs up a flower, roots and all, into the pockets. Returns true if it was taken.
func dig_up(obj: Dictionary) -> bool:
	if obj.get("kind", "") != "flower":
		return false
	var id := "%s_%s_plant" % [obj["species"], obj["color"]]
	if Inventory.add_item(id) > 0:
		Events.toast.emit("Your pockets are full!")
		return false
	var node := node_of(obj["uid"])
	if node:
		Effects.burst("pebbles", node.global_position + Vector3(0, 0.15, 0))
	remove_object(obj["uid"])
	Events.toast.emit("You dug up the %s." % ItemDB.display_name(id).to_lower())
	return true


## Whether a flower can be planted on this tile: open ground outdoors.
func can_plant(tile: Vector2i) -> bool:
	return not interior and data.in_bounds(tile.x, tile.y) and _can_hold_drop(tile.x, tile.y) and not _rugs.has(data.idx(tile.x, tile.y))


## Plants a dug-up flower (an item "<species>_<colour>_plant") on a tile.
func plant_flower(item_id: String, tile: Vector2i) -> Dictionary:
	var def := ItemDB.get_item(item_id)
	var obj := add_object({"kind": "flower", "x": tile.x, "z": tile.y, "species": def["species"], "color": def["flower_color"]})
	_pop_in(obj)
	Journal.add("flowers_planted")
	return obj


func _roll_rock_item() -> String:
	var roll := _rng.randi_range(1, 100)
	for entry in ROCK_TABLE:
		roll -= entry[1]
		if roll <= 0:
			return entry[0]
	return "stone"


## Drops an item on a free tile next to the object, nearest the player first.
func _drop_near(obj: Dictionary, player_pos: Vector3, drop: Dictionary) -> bool:
	var origin := Vector2i(obj["x"], obj["z"])
	var options: Array[Vector2i] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var t := origin + Vector2i(dx, dz)
			if (dx != 0 or dz != 0) and _can_hold_drop(t.x, t.y):
				options.append(t)
	if options.is_empty():
		return false
	var p := Vector2(player_pos.x, player_pos.z)
	options.sort_custom(func(a, b): return p.distance_to(Vector2(a) + Vector2(0.5, 0.5)) < p.distance_to(Vector2(b) + Vector2(0.5, 0.5)))
	var target := options[0]
	drop["kind"] = "drop"
	drop["x"] = target.x
	drop["z"] = target.y
	var added := add_object(drop)
	_pop_in(added)
	return true


## Drops items from the pockets at the player's feet, or in front if that tile is taken.
func drop_from_pockets(here: Vector2i, front: Vector2i, item: String, count: int) -> bool:
	for t in [here, front]:
		if _can_hold_drop(t.x, t.y):
			_pop_in(add_object({"kind": "drop", "item": item, "count": count, "x": t.x, "z": t.y}))
			return true
	return false


func _can_hold_drop(x: int, z: int) -> bool:
	return data.is_land(x, z) and not _keep_clear(x, z) and not _occupant.has(data.idx(x, z)) and not _deck.has(data.idx(x, z)) \
		and not data.splits.has(data.idx(x, z)) and data.height_at(x + 0.5, z + 0.5) > IslandData.SEA_LEVEL


# --- Placement -----------------------------------------------------------------------

## Footprint of an item (already-rotated size) placed starting at the tile in front of
## the player and stretching away from them, centred across their line of sight.
func placement_rect(front: Vector2i, dir: Vector2i, size: Vector2i) -> Rect2i:
	var w := size.x
	var d := size.y
	var pos := front
	if dir == Vector2i(0, -1):
		pos = Vector2i(front.x - (w - 1) / 2, front.y - (d - 1))
	elif dir == Vector2i(0, 1):
		pos = Vector2i(front.x - (w - 1) / 2, front.y)
	elif dir == Vector2i(1, 0):
		pos = Vector2i(front.x, front.y - (d - 1) / 2)
	else:
		pos = Vector2i(front.x - (w - 1), front.y - (d - 1) / 2)
	return Rect2i(pos, Vector2i(w, d))


func can_place(rect: Rect2i, player_pos: Vector3) -> bool:
	var level := NAN
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not data.is_land(x, z) or not data.is_flat(x, z) or _keep_clear(x, z):
				return false
			var i := data.idx(x, z)
			if _occupant.has(i) or _deck.has(i) or _door_fronts.has(i):
				return false
			var h := data.corner(x, z, IslandData.NW)
			if is_nan(level):
				level = h
			elif not is_equal_approx(level, h):
				return false
	return not rect.has_point(Vector2i(floori(player_pos.x), floori(player_pos.z)))


## Rugs need flat, level floor with no other rug, and can go under furniture (or the
## player), but not under trees, rocks or drops.
func can_place_rug(rect: Rect2i) -> bool:
	var level := NAN
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not data.is_land(x, z) or not data.is_flat(x, z):
				return false
			var i := data.idx(x, z)
			if _rugs.has(i) or _deck.has(i) or _reserved.has(i):
				return false
			if _occupant.has(i) and _objects.get(_occupant[i], {}).get("kind", "") != "placed":
				return false
			var h := data.corner(x, z, IslandData.NW)
			if is_nan(level):
				level = h
			elif not is_equal_approx(level, h):
				return false
	return true


## Indoors, the doormat and the tile inside it stay free so there's always a way out.
func _keep_clear(x: int, z: int) -> bool:
	if _reserved.has(data.idx(x, z)):
		return true
	if not interior:
		return false
	var door := data.room_door()
	return x == door.x and z >= door.y - 1


## Keeps a tile free of furniture and drops (where a character stands).
func reserve(tile: Vector2i) -> void:
	_reserved[data.idx(tile.x, tile.y)] = true


# --- Homes ---------------------------------------------------------------------------

## The door of a home or building: {"tile": the footprint tile with the door, "out":
## Vector2i pointing out of the door}. Empty if it has no door.
func door_of(obj: Dictionary) -> Dictionary:
	if obj.get("kind", "") != "placed":
		return {}
	var def := ItemDB.placeable(obj["item"])
	if not def.has("room") and not def.get("door", false):
		return {}
	var facing := Basis(Vector3.UP, -PI * 0.5 * obj.get("rot", 0)) * Vector3.BACK
	var out := Vector2i(roundi(facing.x), roundi(facing.z))
	var w: int = obj["w"]
	var d: int = obj["d"]
	var tile := Vector2i(obj["x"] + w / 2, obj["z"] + d - 1)
	match out:
		Vector2i(0, -1):
			tile = Vector2i(obj["x"] + w / 2, obj["z"])
		Vector2i(1, 0):
			tile = Vector2i(obj["x"] + w - 1, obj["z"] + d / 2)
		Vector2i(-1, 0):
			tile = Vector2i(obj["x"], obj["z"] + d / 2)
	return {"tile": tile, "out": out}


## The home whose door the player is walking into from `pos` heading `dir`, or {}.
func home_entrance(pos: Vector3, dir: Vector3) -> Dictionary:
	if interior or dir.length() < 0.5:
		return {}
	var ahead := pos + dir.normalized() * 0.45
	var obj := object_at(floori(ahead.x), floori(ahead.z))
	var door := door_of(obj)
	if door.is_empty() or door["tile"] != Vector2i(floori(ahead.x), floori(ahead.z)) or not ItemDB.placeable(obj["item"]).has("room"):
		return {}
	if Vector2(dir.x, dir.z).normalized().dot(Vector2(door["out"])) > -0.7:
		return {}
	return obj


## True if a home placed at `rect` would have open ground in front of its door.
func door_clear(item_id: String, rect: Rect2i, rot: int) -> bool:
	var door := door_of({"kind": "placed", "item": item_id, "x": rect.position.x, "z": rect.position.y,
		"w": rect.size.x, "d": rect.size.y, "rot": rot})
	if door.is_empty():
		return true
	var front: Vector2i = door["tile"] + door["out"]
	return is_walkable(front.x + 0.5, front.y + 0.5) and data.is_flat(front.x, front.y)


## Where to stand just outside a home's door, facing out. If something's in the way
## (an old save, say), the nearest open spot around the home.
func outside_door(obj: Dictionary) -> Dictionary:
	var door := door_of(obj)
	var out := Vector3(door["out"].x, 0, door["out"].y)
	var spot := Vector2(door["tile"]) + Vector2(0.5, 0.5) + Vector2(door["out"]) * 1.1
	if not is_walkable(spot.x, spot.y):
		var best := INF
		var rect := Rect2i(obj["x"], obj["z"], obj["w"], obj["d"]).grow(1)
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2(x + 0.5, z + 0.5)
				var dist := c.distance_to(spot)
				if dist < best and is_walkable(c.x, c.y) and object_at(x, z).is_empty():
					best = dist
					spot = c
	return {"position": Vector3(spot.x, ground_height(spot.x, spot.y), spot.y), "facing": out}


# --- Surfaces and seats --------------------------------------------------------------

## The small thing sitting on furniture at this tile, if any.
func surface_item_at(x: int, z: int) -> Dictionary:
	if not data.in_bounds(x, z):
		return {}
	return _objects.get(_on_surface.get(data.idx(x, z), -1), {})


## Height of the furniture top at this tile that small things can stand on, or -1.
func surface_height(x: int, z: int) -> float:
	var obj := object_at(x, z)
	if obj.get("kind", "") != "placed":
		return -1.0
	return ItemDB.placeable(obj["item"]).get("surface", -1.0)


func can_place_on_surface(tile: Vector2i) -> bool:
	return surface_height(tile.x, tile.y) > 0.0 and not _on_surface.has(data.idx(tile.x, tile.y))


func place_on_surface(item_id: String, tile: Vector2i, rot: int) -> Dictionary:
	var base := object_at(tile.x, tile.y)
	var obj := add_object({"kind": "placed", "item": item_id, "x": tile.x, "z": tile.y,
		"w": 1, "d": 1, "rot": rot, "on": base["uid"]})
	_pop_in(obj)
	return obj


## Where you can sit on a piece of furniture: one spot per tile of width, each as
## {"position": Vector3, "facing": Vector3, "height": float}. Empty if it's not a seat.
func seats(obj: Dictionary) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var height: float = ItemDB.placeable(obj.get("item", "")).get("seat", -1.0)
	var node := node_of(obj.get("uid", -1))
	if height <= 0.0 or node == null:
		return spots
	var width: int = ItemDB.placeable(obj["item"])["footprint"][0]
	for i in width:
		var local := Vector3(i - (width - 1) * 0.5, 0, 0)
		spots.append({"position": node.global_transform * local, "facing": node.global_basis * Vector3.BACK, "height": height})
	return spots


func place_item(item_id: String, rect: Rect2i, rot: int) -> Dictionary:
	var obj := add_object({"kind": "placed", "item": item_id, "x": rect.position.x, "z": rect.position.y,
		"w": rect.size.x, "d": rect.size.y, "rot": rot})
	_pop_in(obj)
	return obj


# --- Days ----------------------------------------------------------------------------

func _on_day_changed(key: int) -> void:
	day_key = key
	var rocks := 0
	for obj in data.objects:
		match obj["kind"]:
			"tree", "palm":
				obj["wood_left"] = WOOD_PER_DAY
			"fruit_tree":
				obj["wood_left"] = WOOD_PER_DAY
				if obj.get("fruit_count", 0) == 0 and key - obj.get("picked_day", key) >= FRUIT_REGROW_DAYS:
					obj["fruit_count"] = 3
					refresh_node(obj)
			"rock":
				obj["hits_left"] = ROCK_HITS
				rocks += 1
			"flower":
				# Picked flowers bloom again overnight.
				if obj.get("picked", false):
					obj.erase("picked")
					refresh_node(obj)
	if rocks < ROCK_COUNT:
		_respawn_rock()
	_pick_money_rock()
	wash_up_bottle()
	_hide_tree_gifts()


## Hides a random piece of furniture in a couple of trees, to be shaken out.
func _hide_tree_gifts() -> void:
	var trees: Array = []
	for obj in data.objects:
		obj.erase("gift")
		if obj["kind"] == "tree":
			trees.append(obj)
	var furniture: Array[String] = []
	for id in ItemDB.items:
		var def := ItemDB.get_item(id)
		if def.get("category", "") == "furniture" and id != "workbench" and not def.get("placeable", {}).get("structure", false):
			furniture.append(id)
	for i in mini(GIFT_TREES, trees.size()):
		var tree: Dictionary = trees.pop_at(_rng.randi() % trees.size())
		tree["gift"] = furniture[_rng.randi() % furniture.size()]


## A message bottle washes up on the beach (one at a time).
func wash_up_bottle() -> void:
	for obj in data.objects:
		if obj["kind"] == "drop" and obj["item"] == "message_bottle":
			return
	for attempt in 400:
		var x := _rng.randi_range(0, data.width - 1)
		var z := _rng.randi_range(0, data.height - 1)
		if data.tile(x, z) != T.SAND or not _can_hold_drop(x, z):
			continue
		# Right by the water's edge.
		var by_sea := false
		for dir in IslandGenerator.DIRS:
			by_sea = by_sea or data.tile(x + dir.x, z + dir.y) == T.OCEAN
		if by_sea:
			add_object({"kind": "drop", "item": "message_bottle", "count": 1, "x": x, "z": z})
			return


## Islands saved before the plaza update get the island office. The old workbench spot
## is where the office goes, so the workbench moves aside first.
func _add_office() -> void:
	for obj in data.objects:
		if obj["kind"] == "placed" and obj["item"] == "island_office":
			return
	var office_rect := Rect2i(data.plaza.position + IslandGenerator.OFFICE_AT, Vector2i(4, 3))
	for obj in data.objects.duplicate():
		if obj["kind"] == "placed" and obj["item"] == "workbench" and obj.get("fixed", false) \
				and office_rect.intersects(Rect2i(obj["x"], obj["z"], obj["w"], obj["d"])):
			remove_object(obj["uid"])
			var bench_rect := Rect2i(data.plaza.position + IslandGenerator.WORKBENCH_AT, Vector2i(2, 1))
			if can_place(bench_rect, Vector3(-10, 0, -10)):
				place_item("workbench", bench_rect, 0)["fixed"] = true
	var spots: Array[Rect2i] = [office_rect]
	for dz in range(-1, data.plaza.size.y - 1):
		for dx in range(-1, data.plaza.size.x - 2):
			spots.append(Rect2i(data.plaza.position + Vector2i(dx, dz), Vector2i(4, 3)))
	for rect in spots:
		if can_place(rect, Vector3(-10, 0, -10)) and door_clear("island_office", rect, 0):
			place_item("island_office", rect, 0)["fixed"] = true
			return


## A building the islanders put up beside the plaza (Lucy's shop, the museum): just
## below it first, else round its sides, facing the camera, on the first spot with
## nothing built there; trees and flowers there are cleared away. Returns the building,
## or {} if there's nowhere to put it.
func add_building(item_id: String) -> Dictionary:
	var existing := building(item_id)
	if not existing.is_empty():
		return existing
	var plaza := data.plaza
	var size := Vector2i(ItemDB.placeable(item_id)["footprint"][0], ItemDB.placeable(item_id)["footprint"][1])
	var spots: Array[Rect2i] = []
	for ring in range(0, 6):
		spots.append(Rect2i(plaza.position + Vector2i(plaza.size.x / 2 - 2, plaza.size.y + ring), size))
		for dz in range(0, plaza.size.y - 2):
			spots.append(Rect2i(plaza.position + Vector2i(plaza.size.x + ring, dz), size))
			spots.append(Rect2i(plaza.position + Vector2i(-size.x - ring, dz), size))
	for rect in spots:
		if not _clearable(rect):
			continue
		for obj in data.objects.duplicate():
			if obj["kind"] in NATURAL_KINDS and rect.grow(1).has_point(Vector2i(obj["x"], obj["z"])):
				remove_object(obj["uid"])
		if can_place(rect, Vector3(-10, 0, -10)) and door_clear(item_id, rect, 0):
			var placed := place_item(item_id, rect, 0)
			placed["fixed"] = true
			return placed
	return {}


func add_shop() -> Dictionary:
	return add_building("lucy_shop")


func building(item_id: String) -> Dictionary:
	for obj in data.objects:
		if obj["kind"] == "placed" and obj["item"] == item_id:
			return obj
	return {}


func shop() -> Dictionary:
	return building("lucy_shop")


## Things that can be cleared away to make room for a building.
const NATURAL_KINDS := ["tree", "fruit_tree", "palm", "flower", "drop"]


## Whether a rect would be free to build on once trees, flowers and drops are cleared.
func _clearable(rect: Rect2i) -> bool:
	var level := NAN
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not data.is_land(x, z) or not data.is_flat(x, z) or _keep_clear(x, z):
				return false
			var i := data.idx(x, z)
			if _deck.has(i) or _door_fronts.has(i) or _rugs.has(i):
				return false
			if _occupant.has(i) and not _objects.get(_occupant[i], {}).get("kind", "") in NATURAL_KINDS:
				return false
			var h := data.corner(x, z, IslandData.NW)
			if is_nan(level):
				level = h
			elif not is_equal_approx(level, h):
				return false
	return true


## Islands saved before the DIY update get a plaza workbench and a first bottle.
func _upgrade_old_save() -> void:
	_add_office()
	for obj in data.objects:
		if obj["kind"] == "placed" and obj["item"] == "workbench" and obj.get("fixed", false):
			return
	var spots: Array[Rect2i] = [Rect2i(data.plaza.position + IslandGenerator.WORKBENCH_AT, Vector2i(2, 1))]
	for dz in range(0, data.plaza.size.y):
		for dx in range(0, data.plaza.size.x - 1):
			spots.append(Rect2i(data.plaza.position + Vector2i(dx, dz), Vector2i(2, 1)))
	for rect in spots:
		if can_place(rect, Vector3(-10, 0, -10)):
			place_item("workbench", rect, 0)["fixed"] = true
			wash_up_bottle()
			return


func _pick_money_rock() -> void:
	var rocks := data.objects.filter(func(o): return o["kind"] == "rock")
	money_rock_uid = rocks[_rng.randi() % rocks.size()]["uid"] if not rocks.is_empty() else -1


func _respawn_rock() -> void:
	for attempt in 300:
		var x := _rng.randi_range(2, data.width - 3)
		var z := _rng.randi_range(2, data.height - 3)
		var ok := data.tile(x, z) == T.GRASS
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				ok = ok and data.tile(x + dx, z + dz) == T.GRASS and data.is_flat(x + dx, z + dz) \
					and data.tier(x + dx, z + dz) == data.tier(x, z) and not _occupant.has(data.idx(x + dx, z + dz))
		if ok and not data.plaza.grow(1).has_point(Vector2i(x, z)):
			add_object({"kind": "rock", "x": x, "z": z, "hits_left": ROCK_HITS, "variant": _rng.randi() % 4})
			return


# --- Juice ---------------------------------------------------------------------------

func _wiggle(obj: Dictionary, degrees: float) -> void:
	var node := node_of(obj["uid"])
	if node == null:
		return
	var mesh: Node3D = node.get_child(0)
	var tw := create_tween()
	for a in [degrees, -degrees * 0.8, degrees * 0.5, -degrees * 0.25, 0.0]:
		tw.tween_property(mesh, "rotation_degrees:z", a, 0.07)


func _squash(obj: Dictionary) -> void:
	var node := node_of(obj["uid"])
	if node == null:
		return
	var mesh: Node3D = node.get_child(0)
	var tw := create_tween()
	tw.tween_property(mesh, "scale", Vector3(1.12, 0.88, 1.12), 0.05)
	tw.tween_property(mesh, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## At night the thickest bits of forest glow: soft moss light on the ground and spores
## drifting up. A few emitters, placed once where trees cluster.
func _add_forest_glow() -> void:
	var trees: Array[Vector2] = []
	for obj in data.objects:
		if obj["kind"] in ["tree", "fruit_tree"]:
			trees.append(Vector2(obj["x"] + 0.5, obj["z"] + 0.5))
	var picked: Array[Vector2] = []
	for t in trees:
		var near: Array[Vector2] = []
		for u in trees:
			if t.distance_to(u) < 2.6:
				near.append(u)
		if near.size() < 5:
			continue
		var centre := Vector2.ZERO
		for u in near:
			centre += u
		centre /= near.size()
		if picked.any(func(p: Vector2): return p.distance_to(centre) < 7.0):
			continue
		picked.append(centre)
		if picked.size() >= 12:
			break
	for c in picked:
		for kind: String in ["moss_glow", "spores"]:
			var e := Effects.emitter(kind)
			e.position = Vector3(c.x, data.height_at(c.x, c.y) + (0.05 if kind == "moss_glow" else 0.2), c.y)
			e.emitting = true
			e.visible = _is_night
			e.add_to_group("night_lights")
			add_child(e)


## A burst on the side of an object facing the player, at a height.
func _burst_towards(obj: Dictionary, player_pos: Vector3, kind: String, height: float) -> void:
	var node := node_of(obj["uid"])
	if node == null:
		return
	var to := player_pos - node.global_position
	to.y = 0.0
	Effects.burst(kind, node.global_position + to.normalized() * 0.35 + Vector3(0, height, 0))


func _pop_in(obj: Dictionary) -> void:
	var node := node_of(obj["uid"])
	if node == null:
		return
	if obj["kind"] == "placed":
		# Furniture lands with a little puff of dust.
		get_tree().create_timer(0.3).timeout.connect(func():
			if is_instance_valid(node):
				Effects.burst("dust", node.global_position + Vector3(0, 0.05, 0)))
	var mesh: Node3D = node.get_child(0)
	mesh.scale = Vector3.ONE * 0.2
	mesh.position.y = 0.6
	var tw := create_tween().set_parallel()
	tw.tween_property(mesh, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mesh, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## JSON turns every number into a float; turn whole numbers back into ints.
static func _ints(obj: Dictionary) -> Dictionary:
	for key in obj:
		var v = obj[key]
		if v is float and v == floorf(v):
			obj[key] = int(v)
	return obj
