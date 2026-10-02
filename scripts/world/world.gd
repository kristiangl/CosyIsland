class_name World
extends Node3D
## The live island: terrain meshes, object nodes, walkability and the island's rules
## (chopping, hitting rocks, shaking trees, dropping and picking up items, placing things).

const T := IslandData.Tile
const WOOD_PER_DAY := 3
const ROCK_HITS := 8
const ROCK_COUNT := 6
const FRUIT_REGROW_DAYS := 3
const BLOCKING_KINDS := ["tree", "fruit_tree", "palm", "rock", "placed"]
const ROCK_TABLE := [["stone", 60], ["clay", 25], ["iron_nugget", 14], ["gold_nugget", 1]]

var data: IslandData
var day_key: int
var money_rock_uid: int = -1
var grass: GrassField

var _objects: Dictionary = {}   # uid -> object dictionary
var _nodes: Dictionary = {}     # uid -> Node3D
var _occupant: Dictionary = {}  # tile index -> uid
var _deck: Dictionary = {}      # tile index -> bridge deck height
var _rng := RandomNumberGenerator.new()


func setup(island: IslandData, saved: Dictionary = {}) -> void:
	data = island
	_rng.seed = island.seed_value + GameClock.day_key()
	if saved.has("objects"):
		data.objects.clear()
		for obj in saved["objects"]:
			data.objects.append(_ints(obj))
		data.next_uid = int(saved.get("next_uid", data.next_uid))
	day_key = int(saved.get("day_key", GameClock.day_key()))
	money_rock_uid = int(saved.get("money_rock_uid", -1))

	_build_terrain()
	for obj in data.objects:
		_register(obj)
	Events.day_changed.connect(_on_day_changed)
	if day_key != GameClock.day_key():
		_on_day_changed(GameClock.day_key())
	elif money_rock_uid < 0:
		_pick_money_rock()


func to_save() -> Dictionary:
	return {"objects": data.objects, "next_uid": data.next_uid, "day_key": day_key, "money_rock_uid": money_rock_uid}


func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = TerrainBuilder.build_ground(data)
	ground.material_override = TerrainBuilder.terrain_material()
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


func add_object(obj: Dictionary) -> Dictionary:
	obj["uid"] = data.new_uid()
	data.objects.append(obj)
	_register(obj)
	return obj


func remove_object(uid: int) -> void:
	var obj: Dictionary = _objects.get(uid, {})
	if obj.is_empty():
		return
	for tile in footprint(obj):
		var i := data.idx(tile.x, tile.y)
		if _occupant.get(i, -1) == uid:
			_occupant.erase(i)
		if obj["kind"] == "placed":
			grass.set_tile_visible(data, tile.x, tile.y, true)
	_objects.erase(uid)
	data.objects.erase(obj)
	if _nodes.has(uid):
		_nodes[uid].queue_free()
		_nodes.erase(uid)


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
	else:
		for tile in footprint(obj):
			_occupant[data.idx(tile.x, tile.y)] = uid
			if obj["kind"] == "placed":
				grass.set_tile_visible(data, tile.x, tile.y, false)
	_spawn_node(obj)


func _spawn_node(obj: Dictionary) -> void:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = Models.get_mesh(Models.key_for(obj))
	mesh.material_override = Models.material()
	if obj["kind"] in ["flower", "drop"]:
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
		"tree", "fruit_tree", "palm", "rock", "flower":
			node.rotation.y = fposmod(obj["uid"] * 2.399, TAU)
			if obj["kind"] == "flower":
				node.scale = Vector3.ONE * 1.4
	node.position = Vector3(centre.x, y, centre.y)
	add_child(node)
	_nodes[obj["uid"]] = node


func refresh_node(obj: Dictionary) -> void:
	var node: Node3D = _nodes.get(obj["uid"])
	if node:
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
	if not data.is_land(x, z):
		return false
	var uid: int = _occupant.get(i, -1)
	return uid < 0 or not _objects[uid]["kind"] in BLOCKING_KINDS


## True if the player can step from `from` to the point (px, pz).
func can_step(from: Vector3, px: float, pz: float) -> bool:
	return is_walkable(px, pz) and absf(ground_height(px, pz) - from.y) <= IslandData.MAX_STEP


# --- Island rules --------------------------------------------------------------------

func chop(obj: Dictionary, player_pos: Vector3) -> void:
	_wiggle(obj, 5.0)
	if obj.get("wood_left", 0) <= 0:
		return
	if _drop_near(obj, player_pos, {"item": "wood", "count": 1}):
		obj["wood_left"] -= 1


func strike_rock(obj: Dictionary, player_pos: Vector3) -> bool:
	_squash(obj)
	if obj.get("hits_left", 0) <= 0:
		return false
	var drop := {"item": _roll_rock_item(), "count": 1}
	if obj["uid"] == money_rock_uid:
		drop = {"item": "acorn_pouch", "count": 1, "amount": 100 * (ROCK_HITS + 1 - obj["hits_left"])}
	if not _drop_near(obj, player_pos, drop):
		obj["hits_left"] = 0
		return false
	obj["hits_left"] -= 1
	return true


func shake(obj: Dictionary, player_pos: Vector3) -> void:
	_wiggle(obj, 3.0)
	if obj["kind"] == "fruit_tree" and obj.get("fruit_count", 0) > 0:
		for i in obj["fruit_count"]:
			_drop_near(obj, player_pos, {"item": obj["fruit"], "count": 1})
		obj["fruit_count"] = 0
		obj["picked_day"] = day_key
		refresh_node(obj)
	elif obj["kind"] == "tree" and obj.get("shaken_day", -1) != day_key:
		obj["shaken_day"] = day_key
		if _rng.randf() < 0.6:
			_drop_near(obj, player_pos, {"item": "tree_branch", "count": 1})


## Picks up whatever is on the tile. Returns true if something was taken.
func pick_up(x: int, z: int) -> bool:
	var obj := object_at(x, z)
	if obj.is_empty():
		return false
	match obj["kind"]:
		"drop":
			if obj["item"] == "acorn_pouch":
				Inventory.add_currency(obj.get("amount", 100))
				Events.toast.emit("You got %d %s!" % [obj.get("amount", 100), Game.CURRENCY_NAME.to_lower()])
			else:
				if Inventory.add_item(obj["item"], obj.get("count", 1)) > 0:
					Events.toast.emit("Your pockets are full!")
					return false
				Events.toast.emit("You got %s!" % ItemDB.display_name(obj["item"]).to_lower())
			remove_object(obj["uid"])
			return true
		"flower":
			var id := "%s_%s" % [obj["species"], obj["color"]]
			if Inventory.add_item(id) > 0:
				Events.toast.emit("Your pockets are full!")
				return false
			Events.toast.emit("You picked some %s." % ItemDB.display_name(id).to_lower())
			remove_object(obj["uid"])
			return true
	return false


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
	return data.is_land(x, z) and not _occupant.has(data.idx(x, z)) and not _deck.has(data.idx(x, z))


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
			if not data.is_land(x, z) or not data.is_flat(x, z):
				return false
			var i := data.idx(x, z)
			if _occupant.has(i) or _deck.has(i):
				return false
			var h := data.corner(x, z, IslandData.NW)
			if is_nan(level):
				level = h
			elif not is_equal_approx(level, h):
				return false
	return not rect.has_point(Vector2i(floori(player_pos.x), floori(player_pos.z)))


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
	if rocks < ROCK_COUNT:
		_respawn_rock()
	_pick_money_rock()


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


func _pop_in(obj: Dictionary) -> void:
	var node := node_of(obj["uid"])
	if node == null:
		return
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
