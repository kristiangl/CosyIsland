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
const BLOCKING_KINDS := ["tree", "fruit_tree", "palm", "rock", "bush", "stump", "placed"]
const ROCK_TABLE := [["stone", 60], ["clay", 25], ["iron_nugget", 14], ["gold_nugget", 1]]

var data: IslandData
## True for a room inside a home: no terrain, sea or island rules, lamps always lit.
var interior := false
## Look of the room's floor and walls (see RoomBuilder.STYLES).
var room_style := "tent"
## Wallpaper, flooring and curtains put up in this room:
## {"wall": item id, "floor": item id, "window": item id}.
var room_look: Dictionary = {}
## Doors through a room's walls to the home's other rooms: {"tile": the floor tile in
## front of the door, "out": Vector2i through the wall, "to": room index}.
var room_doors: Array[Dictionary] = []
## Slopes the player has built, laid on the generated island when it loads (saved):
## [top x, top z, dir x, dir z] each.
var built_ramps: Array = []
## The island's own slopes the player has taken away (saved): [top x, top z, dir x, dir z].
var removed_ramps: Array = []
## Landscaping (saved): tile index -> [tile type, tier] for tiles the player has
## raised, lowered, dug out or filled in.
var land_edits: Dictionary = {}
## Paths laid with the landscaping app (saved): tile index -> kind.
var paths: Dictionary = {}
const PATH_KINDS := ["stone", "brick", "wood", "terracotta", "sand", "dirt"]
const PATH_NAMES := {"stone": "Stone path", "brick": "Brick path", "wood": "Wooden path",
	"terracotta": "Terracotta path", "sand": "Sandy path", "dirt": "Dirt path"}
## A slope laid with one of these becomes stairs; sand and dirt stay slopes.
const STAIR_KINDS := ["stone", "brick", "wood", "terracotta"]
## The ground is built in chunks this many tiles across.
const GROUND_CHUNK := 32
var _ground_material: ShaderMaterial
var day_key: int
var money_rock_uid: int = -1
var grass: GrassField
## Fish and bugs (outdoors only).
var critters: Critters
## A room in someone else's home: look, don't touch.
var visitor := false
## An island visited on a tour: gather all you like, but nothing gets built or saved.
var tour := false

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
			if obj["kind"] in ["tree", "palm", "rock", "bush", "stump", "flower", "drop"] and not interior \
					and not island.is_land(int(obj["x"]), int(obj["z"])):
				continue
			data.objects.append(_ints(obj))
		data.next_uid = int(saved.get("next_uid", data.next_uid))
	day_key = int(saved.get("day_key", GameClock.day_key()))
	money_rock_uid = int(saved.get("money_rock_uid", -1))

	if interior:
		_is_night = true
		room_look = saved.get("look", {}).duplicate()
		add_child(RoomBuilder.build(data, room_style, room_look, room_doors))
		for obj in data.objects:
			_register(obj)
		return
	for e: Array in saved.get("land", []):
		var i := data.idx(int(e[0]), int(e[1]))
		data.tiles[i] = int(e[2])
		data.tiers[i] = int(e[3])
		data.ramps.erase(i)
		land_edits[i] = [int(e[2]), int(e[3])]
	for p: Array in saved.get("paths", []):
		if str(p[2]) in PATH_KINDS:
			paths[data.idx(int(p[0]), int(p[1]))] = str(p[2])
	for r: Array in saved.get("unramps", []):
		var top := Vector2i(int(r[0]), int(r[1]))
		var dir := Vector2i(int(r[2]), int(r[3]))
		for t: Vector2i in [top + dir, top + dir * 2]:
			data.ramps.erase(data.idx(t.x, t.y))
		removed_ramps.append([top.x, top.y, dir.x, dir.y])
	for r: Array in saved.get("ramps", []):
		var top := Vector2i(int(r[0]), int(r[1]))
		var dir := Vector2i(int(r[2]), int(r[3]))
		if not data.is_ramp(top.x + dir.x, top.y + dir.y):
			data.add_ramp(top, dir)
			built_ramps.append([top.x, top.y, dir.x, dir.y])
	var built_bridge := data.objects.any(func(o): return o["kind"] == "bridge" and o.get("built", false))
	if not land_edits.is_empty() or not built_ramps.is_empty() or not removed_ramps.is_empty() or built_bridge:
		_reshape()
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
	else:
		if not built_ramps.is_empty():
			out["ramps"] = built_ramps
		if not removed_ramps.is_empty():
			out["unramps"] = removed_ramps
		if not paths.is_empty():
			var laid := []
			for i: int in paths:
				laid.append([i % data.width, i / data.width, paths[i]])
			out["paths"] = laid
		if not land_edits.is_empty():
			var land := []
			for i: int in land_edits:
				land.append([i % data.width, i / data.width, land_edits[i][0], land_edits[i][1]])
			out["land"] = land
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
	var rebuilt := RoomBuilder.build(data, room_style, room_look, room_doors)
	add_child(rebuilt)
	move_child(rebuilt, 0)
	return old


func _build_terrain() -> void:
	# The ground in a few big chunks, so landscaping only remakes the ones it touches.
	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	# Its own copy: the plaza is this island's (a tour island mustn't move the home
	# island's paving).
	_ground_material = TerrainBuilder.terrain_material().duplicate()
	var plaza := Rect2(data.plaza)
	_ground_material.set_shader_parameter("plaza", Vector4(plaza.position.x, plaza.position.y, plaza.size.x, plaza.size.y))
	for cz in ceili(data.height / float(GROUND_CHUNK)):
		for cx in ceili(data.width / float(GROUND_CHUNK)):
			var chunk := MeshInstance3D.new()
			chunk.name = "%d_%d" % [cx, cz]
			chunk.material_override = _ground_material
			ground.add_child(chunk)
			_build_chunk(chunk, cx, cz)
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
	var laid := MeshInstance3D.new()
	laid.name = "Paths"
	laid.material_override = TerrainBuilder.path_material()
	laid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(laid)
	_build_paths()


func _build_chunk(chunk: MeshInstance3D, cx: int, cz: int) -> void:
	var area := Rect2i(cx * GROUND_CHUNK, cz * GROUND_CHUNK, GROUND_CHUNK, GROUND_CHUNK).intersection(Rect2i(0, 0, data.width, data.height))
	chunk.mesh = TerrainBuilder.build_ground(data, area)


## Builds the ground in `area` (and the rivers and ponds) again after the land changed
## there, and settles the grass on it. The sea never changes.
func rebuild_terrain(area: Rect2i) -> void:
	var ground := get_node("Ground")
	# Walls along the area's edge belong to the tiles just outside it too.
	var walls := area.grow(1).intersection(Rect2i(0, 0, data.width, data.height))
	for cz in range(walls.position.y / GROUND_CHUNK, (walls.end.y - 1) / GROUND_CHUNK + 1):
		for cx in range(walls.position.x / GROUND_CHUNK, (walls.end.x - 1) / GROUND_CHUNK + 1):
			var chunk: MeshInstance3D = ground.get_node_or_null("%d_%d" % [cx, cz])
			if chunk:
				_build_chunk(chunk, cx, cz)
	(get_node("FreshWater") as MeshInstance3D).mesh = TerrainBuilder.build_fresh_water(data)
	_build_paths()
	(get_node("BankFoam") as MeshInstance3D).mesh = TerrainBuilder.build_bank_foam(data)
	grass.settle(data, area)
	IslandMap.invalidate()
	IslandMap.terrain_texture(data)
	Events.placed_changed.emit()


# --- Building slopes and bridges ------------------------------------------------------

## The nearest of the four directions to `v`.
static func cardinal(v: Vector3) -> Vector2i:
	if absf(v.x) > absf(v.z):
		return Vector2i(signi(int(signf(v.x))), 0)
	return Vector2i(0, signi(int(signf(v.z))))


## Where a slope would go from standing on `tile` facing `facing`: at the foot of a
## cliff facing up it, or at the top facing down. {"top", "dir"} if it fits, else
## {"why": what's wrong}.
func incline_plan(tile: Vector2i, facing: Vector2i) -> Dictionary:
	if interior or tour:
		return {"why": "Slopes are for building on your own island."}
	var ahead := tile + facing
	var top := Vector2i(-1, -1)
	var dir := Vector2i.ZERO
	if data.tier(ahead.x, ahead.y) == data.tier(tile.x, tile.y) + 1:
		top = ahead
		dir = -facing
	elif data.tier(ahead.x, ahead.y) == data.tier(tile.x, tile.y) - 1:
		top = tile
		dir = facing
	else:
		return {"why": "Stand at the foot or the top of a cliff, facing it."}
	var level := data.tier(top.x, top.y)
	if data.tile(top.x, top.y) != IslandData.Tile.GRASS or level < 2 or data.is_ramp(top.x, top.y):
		return {"why": "A slope can't go here."}
	var side := Vector2i(dir.y, dir.x)
	for s in [-1, 1]:
		var t: Vector2i = top + side * s
		if data.tier(t.x, t.y) != level:
			return {"why": "The cliff needs to run straight here for a slope."}
	for k in [1, 2, 3]:
		var q: Vector2i = top + dir * k
		if not data.in_bounds(q.x, q.y) or data.tile(q.x, q.y) != IslandData.Tile.GRASS or data.tier(q.x, q.y) != level - 1 \
				or data.is_ramp(q.x, q.y):
			return {"why": "A slope needs flat ground below the cliff, two tiles long and one more to step off."}
		if not object_at(q.x, q.y).is_empty() or _rugs.has(data.idx(q.x, q.y)):
			return {"why": "Clear the way first: the slope needs %s empty." % ("these tiles" if k < 3 else "the tile at its foot")}
		if k < 3:
			for s in [-1, 1]:
				var r: Vector2i = q + side * s
				if data.is_ramp(r.x, r.y):
					# Beside another slope going the same way: together they make a wider one.
					var other: Dictionary = data.ramps[data.idx(r.x, r.y)]
					var high := IslandData.tier_height(level) if k == 1 else (IslandData.tier_height(level) + IslandData.tier_height(level - 1)) * 0.5
					if other["up"] == -dir and is_equal_approx(other["high"], high):
						continue
					return {"why": "There isn't room beside it for a slope here."}
				if data.tile(r.x, r.y) != IslandData.Tile.GRASS or data.tier(r.x, r.y) != level - 1:
					return {"why": "There isn't room beside it for a slope here."}
	return {"top": top, "dir": dir}


func build_incline(plan: Dictionary) -> void:
	var top: Vector2i = plan["top"]
	var dir: Vector2i = plan["dir"]
	data.add_ramp(top, dir)
	built_ramps.append([top.x, top.y, dir.x, dir.y])
	var area := Rect2i(top, Vector2i.ONE).expand(top + dir * 2).grow(RESHAPE_REACH)
	_reshape(area)
	rebuild_terrain(area)


## A bridge from the bank at `tile` straight across the water ahead (one to four tiles
## of river or pond) to the same height on the other side: {"x", "z", "length", "axis"}
## like the island's own bridges, or {"why": what's wrong}.
func bridge_plan(tile: Vector2i, facing: Vector2i) -> Dictionary:
	if interior or tour:
		return {"why": "Bridges are for building on your own island."}
	if data.tile(tile.x, tile.y) == IslandData.Tile.WATER or not data.is_land(tile.x, tile.y):
		return {"why": "Stand on the bank, facing the water you want to cross."}
	var length := 0
	while data.tile(tile.x + facing.x * (length + 1), tile.y + facing.y * (length + 1)) == IslandData.Tile.WATER:
		length += 1
		var w := tile + facing * length
		if _deck.has(data.idx(w.x, w.y)):
			return {"why": "There's already a bridge there."}
		if length > 4:
			return {"why": "That's too far to bridge. Find a narrower spot."}
	if length == 0:
		return {"why": "Stand on the bank, facing the water you want to cross."}
	var far := tile + facing * (length + 1)
	if not data.is_land(far.x, far.y) or data.tier(far.x, far.y) != data.tier(tile.x, tile.y) \
			or absf(data.height_at(far.x + 0.5, far.y + 0.5) - data.height_at(tile.x + 0.5, tile.y + 0.5)) > 0.05:
		return {"why": "The banks either side need to be the same height."}
	if not is_walkable(far.x + 0.5, far.y + 0.5):
		return {"why": "Clear the far bank first."}
	var water := tile + facing
	if absf(IslandData.tier_height(data.tier(water.x, water.y)) - data.height_at(tile.x + 0.5, tile.y + 0.5)) > 0.05:
		return {"why": "The banks are too high above the water here for a bridge."}
	var first := tile + facing if facing.x + facing.y > 0 else tile + facing * length
	return {"x": first.x, "z": first.y, "length": length, "axis": "x" if facing.x != 0 else "z"}


func build_bridge(plan: Dictionary) -> Dictionary:
	var obj := add_object({"kind": "bridge", "x": plan["x"], "z": plan["z"], "length": plan["length"], "axis": plan["axis"], "built": true})
	var axis := Vector2i(1, 0) if obj["axis"] == "x" else Vector2i(0, 1)
	var start := Vector2i(obj["x"], obj["z"])
	var area := Rect2i(start - axis, Vector2i.ONE).expand(start + axis * int(obj["length"])).grow(RESHAPE_REACH)
	_reshape(area)
	rebuild_terrain(area)
	return obj


## Recomputes the ground's corners after the land changed; where things stand (and
## where bridges land) stays square.
## (Only in `area` if given: it must reach RESHAPE_REACH past what changed.)
func _reshape(area := Rect2i()) -> void:
	var keep := {}
	for obj in data.objects:
		if obj["kind"] != "bridge":
			for tile in footprint(obj):
				if data.in_bounds(tile.x, tile.y):
					keep[data.idx(tile.x, tile.y)] = true
	IslandGenerator.reshape(data, keep, area)


# --- Landscaping ----------------------------------------------------------------------

## How far round a changed tile its corners can be rounded differently, plus one for the
## beach corners next to it.
const RESHAPE_REACH := 4

## What the cliff pick ("cliff") or water spade ("water") would do to the tile ahead of
## `tile`, facing `facing`: {"tile", "type", "tier", "verb"} or {"why": what's wrong}.
## The pick raises a tile level with you, or cuts back a cliff one step up; the spade
## digs out a tile level with you, or fills in water level with you.
func terraform_plan(tile: Vector2i, facing: Vector2i, what: String) -> Dictionary:
	if interior or tour:
		return {"why": "Landscaping is for your own island."}
	if data.is_ramp(tile.x, tile.y):
		return {"why": "Step off the slope first."}
	var t := tile + facing
	if t.x < 2 or t.y < 2 or t.x >= data.width - 2 or t.y >= data.height - 2:
		return {"why": "Not out here."}
	var here := data.tier(tile.x, tile.y)
	var type := data.tile(t.x, t.y)
	var level := data.tier(t.x, t.y)
	var plan := {}
	if what == "cliff":
		if type != IslandData.Tile.GRASS:
			return {"why": "Cliffs are made of grassy ground."}
		if level == here:
			if level >= 3:
				return {"why": "That's as high as cliffs go."}
			plan = {"tile": t, "type": type, "tier": level + 1, "verb": "raise"}
		elif level == here + 1:
			plan = {"tile": t, "type": type, "tier": here, "verb": "lower"}
		else:
			return {"why": "Face the ground beside you, or a cliff one step up."}
	else:
		if type == IslandData.Tile.GRASS and level == here:
			plan = {"tile": t, "type": IslandData.Tile.WATER, "tier": level, "verb": "dig"}
		elif type == IslandData.Tile.WATER and level == here:
			plan = {"tile": t, "type": IslandData.Tile.GRASS, "tier": level, "verb": "fill"}
		else:
			return {"why": "Face the ground or water beside you."}
	if data.plaza.grow(1).has_point(t):
		return {"why": "Not in the plaza!"}
	var i := data.idx(t.x, t.y)
	if data.is_ramp(t.x, t.y) or _deck.has(i) or _bridge_ends().has(i):
		return {"why": "There's a slope or a bridge in the way."}
	if not object_at(t.x, t.y).is_empty() or _rugs.has(i) or _keep_clear(t.x, t.y) or _door_fronts.has(i):
		return {"why": "Clear the ground first."}
	var why := _land_fits(t, plan["type"], plan["tier"])
	if why != "":
		return {"why": why}
	return plan


## Why the land around `t` wouldn't work with `t` as `type` at `tier` ("" if it would):
## cliffs only ever one step at a time, water level with its banks or just below them,
## and nothing changed up against the beach or a slope.
func _land_fits(t: Vector2i, type: int, level: int) -> String:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var n := t + Vector2i(dx, dz)
			var nt := data.tile(n.x, n.y)
			var nl := data.tier(n.x, n.y)
			if data.is_ramp(n.x, n.y):
				return "That's too close to a slope."
			if nt == IslandData.Tile.OCEAN or (nt == IslandData.Tile.SAND and (type == IslandData.Tile.WATER or level > 1)):
				return "That's too close to the beach."
			if type == IslandData.Tile.GRASS:
				if nt == IslandData.Tile.GRASS and absi(nl - level) > 1:
					return "The cliffs would be too steep there."
				if nt == IslandData.Tile.WATER and level != nl and level != nl + 1:
					return "The water would spill out there."
			elif type == IslandData.Tile.WATER:
				if nt == IslandData.Tile.WATER and nl != level:
					return "The water would spill out there."
				if nt == IslandData.Tile.GRASS and nl != level and nl != level + 1:
					return "The water would spill out there."
	return ""


## Tiles where bridges land.
func _bridge_ends() -> Dictionary:
	var ends := {}
	for obj in data.objects:
		if obj["kind"] == "bridge":
			var axis := Vector2i(1, 0) if obj["axis"] == "x" else Vector2i(0, 1)
			for q: Vector2i in [Vector2i(obj["x"], obj["z"]) - axis, Vector2i(obj["x"], obj["z"]) + axis * int(obj["length"])]:
				ends[data.idx(q.x, q.y)] = true
	return ends


## The slope tool: takes away the slope you face (or stand on), whether you built it or
## it was always there, or lays a new one (`incline_plan`). {"remove": [top, dir]}, the
## incline plan, or {"why"}.
func slope_plan(tile: Vector2i, facing: Vector2i) -> Dictionary:
	if interior or tour:
		return {"why": "Slopes are for building on your own island."}
	for t: Vector2i in [tile + facing, tile]:
		if data.is_ramp(t.x, t.y):
			# A slope is two tiles in a line going the same way: find its top.
			var up: Vector2i = data.ramps[data.idx(t.x, t.y)]["up"]
			var high := t
			var q := t + up
			if data.is_ramp(q.x, q.y) and data.ramps[data.idx(q.x, q.y)]["up"] == up:
				high = q
			return {"remove": [high + up, -up]}
	return incline_plan(tile, facing)


func remove_slope(plan: Dictionary) -> void:
	var top: Vector2i = plan["remove"][0]
	var dir: Vector2i = plan["remove"][1]
	for t: Vector2i in [top + dir, top + dir * 2]:
		data.ramps.erase(data.idx(t.x, t.y))
		paths.erase(data.idx(t.x, t.y))
	var built := built_ramps.find_custom(func(r): return Vector2i(int(r[0]), int(r[1])) == top and Vector2i(int(r[2]), int(r[3])) == dir)
	if built >= 0:
		built_ramps.remove_at(built)
	else:
		removed_ramps.append([top.x, top.y, dir.x, dir.y])
	var area := Rect2i(top, Vector2i.ONE).expand(top + dir * 2).grow(RESHAPE_REACH)
	_reshape(area)
	rebuild_terrain(area)


## The path tool laying `kind` on the tile ahead: {"tile", "kind"} ("" to take up a path
## of the same kind that's there), or {"why"}. Paths go on flat grass and on slopes.
func path_plan(tile: Vector2i, facing: Vector2i, kind: String) -> Dictionary:
	if interior or tour:
		return {"why": "Paths are for your own island."}
	var t := tile + facing
	if not data.in_bounds(t.x, t.y):
		return {"why": "Not out here."}
	var i := data.idx(t.x, t.y)
	if data.plaza.has_point(t):
		return {"why": "The plaza's paved already!"}
	if _deck.has(i) or data.tile(t.x, t.y) != IslandData.Tile.GRASS:
		return {"why": "Paths go on grassy ground."}
	if not data.is_ramp(t.x, t.y) and (not data.is_flat(t.x, t.y)):
		return {"why": "It's too bumpy there for a path."}
	return {"tile": t, "kind": "" if paths.get(i, "") == kind else kind}


func set_path(plan: Dictionary) -> void:
	var t: Vector2i = plan["tile"]
	var i := data.idx(t.x, t.y)
	if plan["kind"] == "":
		paths.erase(i)
	else:
		paths[i] = plan["kind"]
	_build_paths()
	grass.set_tile_visible(data, t.x, t.y, _grass_shown(t.x, t.y))
	Events.placed_changed.emit()


func _build_paths() -> void:
	var laid := get_node_or_null("Paths") as MeshInstance3D
	if laid:
		laid.mesh = TerrainBuilder.build_paths(data, paths) if not paths.is_empty() else null
	for i: int in paths:
		grass.set_tile_visible(data, i % data.width, i / data.width, false)


## Grass grows on a tile unless something covers it: furniture, a rug, a path or a
## bridge's end.
func _grass_shown(x: int, z: int) -> bool:
	var i := data.idx(x, z)
	if paths.has(i) or _rugs.has(i) or _bridge_ends().has(i):
		return false
	return _objects.get(_occupant.get(i, -1), {}).get("kind", "") != "placed"


func terraform(plan: Dictionary) -> void:
	var t: Vector2i = plan["tile"]
	var i := data.idx(t.x, t.y)
	data.tiles[i] = plan["type"]
	data.tiers[i] = plan["tier"]
	land_edits[i] = [plan["type"], plan["tier"]]
	if paths.has(i):
		paths.erase(i)
		grass.set_tile_visible(data, t.x, t.y, _grass_shown(t.x, t.y))
	var area := Rect2i(t, Vector2i.ONE).grow(RESHAPE_REACH)
	_reshape(area)
	rebuild_terrain(area)
	if critters:
		critters.refresh_water()


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
			grass.set_tile_visible(data, tile.x, tile.y, _grass_shown(tile.x, tile.y))
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
	var base := Models.material()
	if obj["kind"] == "flower":
		base = Models.flower_material()
	elif obj["kind"] in ["tree", "fruit_tree"]:
		base = Models.foliage_material()
	elif obj["kind"] == "bush":
		base = Models.bush_material()
	Models.dress(mesh, base)
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
		"tree", "fruit_tree", "palm", "rock", "bush", "stump", "flower":
			node.rotation.y = fposmod(obj["uid"] * 2.399, TAU)
			if obj["kind"] == "flower":
				node.scale = Vector3.ONE * 1.4
			elif obj.has("planted"):
				node.scale = Vector3.ONE * growth_scale(obj)
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
		if obj["kind"] == "fruit_tree":
			node.scale = Vector3.ONE * growth_scale(obj)


func node_of(uid: int) -> Node3D:
	return _nodes.get(uid)


# --- Walking -------------------------------------------------------------------------

## What's underfoot at a world position, for footsteps (Sfx.STEPS): grass, sand, snow,
## stone (paths, the plaza), wood (bridges, the dock, wooden paths, floors) or carpet.
func step_surface(p: Vector3) -> String:
	var x := floori(p.x)
	var z := floori(p.z)
	if not data.in_bounds(x, z):
		return "grass"
	var i := data.idx(x, z)
	if interior:
		return "carpet" if _rugs.has(i) else "wood"
	if _deck.has(i) or object_at(x, z).get("item", "") == "dock":
		return "wood"
	var path: String = paths.get(i, "")
	if path != "":
		return {"wood": "wood", "sand": "sand", "dirt": "grass"}.get(path, "stone")
	if data.plaza.has_point(Vector2i(x, z)):
		return "stone"
	if Weather.snow_cover > 0.5:
		return "snow"
	if data.surface_at(p.x, p.z) == IslandData.Tile.SAND:
		return "sand"
	return "grass"


func ground_height(px: float, pz: float) -> float:
	var x := floori(px)
	var z := floori(pz)
	if data.in_bounds(x, z) and _deck.has(data.idx(x, z)):
		return _deck[data.idx(x, z)]
	if not paths.is_empty() and data.in_bounds(x, z) and paths.get(data.idx(x, z), "") in STAIR_KINDS and data.is_ramp(x, z):
		return TerrainBuilder.stair_height(data.ramps[data.idx(x, z)], px - x, pz - z)
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


## True if something `radius` round standing at `from` can move its middle to (px, pz):
## the middle must step there, and four points round its edge must each land somewhere
## walkable, level either with where that same point is now or with where the middle is
## going. (Going up a ramp, a point over the ground beside it stays level while the middle
## climbs; at the top it meets the cliff alongside, level with the middle. Neither should
## stop you; walking off a cliff still does, as both the middle and that point drop.)
func can_move(from: Vector3, px: float, pz: float, radius: float) -> bool:
	if not can_step(from, px, pz):
		return false
	var middle := ground_height(px, pz)
	for off: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		var x := px + off.x
		var z := pz + off.y
		if not is_walkable(x, z):
			return false
		var h := ground_height(x, z)
		var here := ground_height(from.x + off.x, from.z + off.y)
		if absf(h - here) > IslandData.MAX_STEP and absf(h - middle) > IslandData.MAX_STEP:
			return false
	return true


## Where a vault with the pole from `from` facing `dir` lands: {"to": Vector3} across a
## river or pond (straight ahead along the nearest of the four directions, up to
## VAULT_WATER of water), or {"why": what's wrong} if there's no such hop.
const VAULT_WATER := 4.5


func vault_landing(from: Vector3, dir: Vector3) -> Dictionary:
	if interior:
		return {"why": "There's no room to vault in here!"}
	var step := Vector3(signf(dir.x), 0, 0) if absf(dir.x) > absf(dir.z) else Vector3(0, 0, signf(dir.z))
	var water := 0.0
	var at := 0.3
	while at < 1.5 + VAULT_WATER:
		var p := from + step * at
		var tile := data.tile(floori(p.x), floori(p.z))
		if tile == T.OCEAN or not data.in_bounds(floori(p.x), floori(p.z)):
			return {"why": "That's the sea! The pole's for rivers and ponds."}
		if is_walkable(p.x, p.z):
			if water > 0.0:
				# Land: come down a little way in from the bank.
				var to := p + step * 0.55
				var h := ground_height(to.x, to.z)
				if h > from.y + IslandData.MAX_STEP:
					return {"why": "The bank over there is too high to land on."}
				if not can_move(Vector3(to.x, h, to.z), to.x, to.z, Player.RADIUS):
					return {"why": "There's nowhere to land over there."}
				return {"to": Vector3(to.x, h, to.z)}
			if at > 1.3:
				break
		elif tile == T.WATER:
			water += 0.1
			if water > VAULT_WATER:
				return {"why": "Too far to vault across."}
		elif water == 0.0 and at > 1.3:
			break
		at += 0.1
	return {"why": "Face a river or pond, right at the edge, to vault across."}


# --- Island rules --------------------------------------------------------------------

func chop(obj: Dictionary, player_pos: Vector3) -> void:
	if obj.has("planted"):
		_wiggle(obj, 2.0)
		Events.toast.emit("It's only little! Give it time to grow.")
		return
	_wiggle(obj, 5.0)
	_burst_towards(obj, player_pos, "chips", 0.55)
	if obj.get("wood_left", 0) <= 0:
		return
	if _drop_near(obj, player_pos, {"item": "wood", "count": 1}):
		obj["wood_left"] -= 1
		Journal.add("wood")


## A rock hit with the wrong tool: a jolt and a few sparks, nothing comes off.
func bump_rock(obj: Dictionary, player_pos: Vector3) -> void:
	_squash(obj)
	_burst_towards(obj, player_pos, "sparks", 0.35)


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
	if obj.has("planted"):
		_wiggle(obj, 2.0)
		return
	_wiggle(obj, 3.0)
	var node := node_of(obj["uid"])
	if node:
		Effects.burst("leaves", node.global_position + Vector3(0, {"palm": 2.4, "bush": 0.6}.get(obj["kind"], 1.9), 0))
	if obj["kind"] == "fruit_tree" and obj.get("fruit_count", 0) > 0:
		Sfx.play_later("thud", 0.25, -2.0)
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
			Sfx.play_later("thud", 0.25)
			Sfx.play("jingle_ding", -2.0, 1.0, 0.0)
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
	if visitor:
		Events.toast.emit("That's not yours to take!")
		return false
	# A staked-out kit can still be moved until it's built that night.
	var staked: bool = obj.has("plot_day") and ItemDB.get_item(obj["item"]).get("category", "") == "kit"
	if obj.get("fixed", false) or (ItemDB.placeable(obj["item"]).get("structure", false) and not staked):
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
	Sfx.play("pop")
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
				Sfx.play("coins")
				Inventory.add_currency(obj.get("amount", 100))
				Journal.add("acorns_earned", obj.get("amount", 100))
				Events.toast.emit("You got %d %s!" % [obj.get("amount", 100), Game.CURRENCY_NAME.to_lower()])
			elif obj["item"] == "message_bottle":
				Effects.burst("sparkle", Vector3(x + 0.5, data.height_at(x + 0.5, z + 0.5) + 0.4, z + 0.5))
				var learned := Recipes.learn_random(_rng)
				Journal.add("bottles")
				Sfx.play("jingle_learn" if learned != "" else "pop", 0.0, 1.0, 0.0)
				if learned == "":
					Events.toast.emit("A note inside says: \"Hello from across the sea!\"")
				else:
					Events.toast.emit("There's a recipe inside! You learned to make: %s." % ItemDB.display_name(learned))
			else:
				if Inventory.add_item(obj["item"], obj.get("count", 1)) > 0:
					Events.toast.emit("Your pockets are full!")
					return false
				Events.toast.emit("You got %s!" % ItemDB.display_name(obj["item"]).to_lower())
				Sfx.play("pop")
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
			Sfx.play("rustle", -4.0, 1.3)
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


## Whether a fruit can be planted here to grow a tree: open grass outdoors at home,
## with nothing tall right next to it.
func can_plant_tree(tile: Vector2i) -> bool:
	if tour or not can_plant(tile) or data.tile(tile.x, tile.y) != IslandData.Tile.GRASS or not data.is_flat(tile.x, tile.y) \
			or Rect2i(data.plaza).grow(1).has_point(tile):
		return false
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var near := object_at(tile.x + dx, tile.y + dz)
			if near.get("kind", "") in ["tree", "fruit_tree", "palm", "placed"]:
				return false
	return true


## Plants a fruit, which grows into a tree of that fruit over GROW_DAYS nights.
func plant_fruit(fruit_id: String, tile: Vector2i) -> Dictionary:
	var obj := add_object({"kind": "fruit_tree", "x": tile.x, "z": tile.y, "fruit": fruit_id, "fruit_count": 0,
		"planted": day_key, "wood_left": 0})
	_pop_in(obj)
	Journal.add("trees_planted")
	return obj


## How big a growing tree is: a sapling the day it's planted, nearly full size the
## night before it's grown.
func growth_scale(obj: Dictionary) -> float:
	var days := clampi(day_key - int(obj.get("planted", day_key - GROW_DAYS)), 0, GROW_DAYS)
	return lerpf(0.22, 0.85, days / float(GROW_DAYS - 1)) if days < GROW_DAYS else 1.0


## Plants a dug-up flower (an item "<species>_<colour>_plant") on a tile.
func plant_flower(item_id: String, tile: Vector2i) -> Dictionary:
	var def := ItemDB.get_item(item_id)
	var obj := add_object({"kind": "flower", "x": tile.x, "z": tile.y, "species": def["species"], "color": def["flower_color"]})
	_pop_in(obj)
	Journal.add("flowers_planted")
	return obj


# --- Landscaping: trees and rocks ----------------------------------------------------

## What the landscaping app's Move tool can carry somewhere else.
const MOVABLE_KINDS := ["tree", "fruit_tree", "palm", "bush", "rock", "stump"]
## Chops with the landscaping Trees tool it takes to bring a grown tree down.
const FELL_CHOPS := 3
## How high a stump is to sit on.
const STUMP_SEAT := 0.32
var _chops: Dictionary = {}  # uid -> chops so far with the Trees tool (not saved)


## One chop with the Trees tool. The third brings a grown tree down, away from the
## player: it leaves a stump, its wood, and any fruit or furniture it was holding.
## Returns true once it's down.
func chop_down(obj: Dictionary, player_pos: Vector3) -> bool:
	var uid: int = obj["uid"]
	_chops[uid] = _chops.get(uid, 0) + 1
	_burst_towards(obj, player_pos, "chips", 0.55)
	if _chops[uid] < FELL_CHOPS:
		_wiggle(obj, 7.0)
		return false
	_chops.erase(uid)
	disturb(obj)
	var node := node_of(uid)
	if node:
		_nodes.erase(uid)
		_topple(node, Vector3(obj["x"] + 0.5 - player_pos.x, 0.0, obj["z"] + 0.5 - player_pos.z))
	var drops: Array[Dictionary] = []
	for i in (2 if obj["kind"] == "palm" else 3):
		drops.append({"item": "wood", "count": 1})
	if obj["kind"] == "fruit_tree":
		for i in obj.get("fruit_count", 0):
			drops.append({"item": obj["fruit"], "count": 1})
	if obj.has("gift"):
		drops.append({"item": obj["gift"], "count": 1})
	var was: String = obj["kind"]
	for key: String in ["fruit", "fruit_count", "wood_left", "picked_day", "shaken_day", "branches", "gift", "planted"]:
		obj.erase(key)
	obj["kind"] = "stump"
	obj["tree"] = was
	_spawn_node(obj)
	for drop in drops:
		_drop_near(obj, player_pos, drop)
	Journal.add("trees_felled")
	return true


## A felled tree tips over away from the player, lands with a thump and sinks away.
func _topple(node: Node3D, away: Vector3) -> void:
	var dir := away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var axis := Vector3.UP.cross(dir).normalized()
	var start := node.basis
	var tw := create_tween()
	tw.tween_method(func(a: float): node.basis = Basis(axis, a) * start, 0.0, deg_to_rad(84.0), 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Sfx.play_at("thud", node.global_position, 2.0, 0.8)
		Effects.burst("leaves", node.global_position + dir * 1.8 + Vector3(0, 0.4, 0))
		Effects.burst("dust", node.global_position + dir * 1.2 + Vector3(0, 0.1, 0)))
	tw.tween_property(node, "scale", Vector3.ZERO, 0.4).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


## The Trees tool on a bush, a stump or a young tree: up it comes in one go (a young
## tree's fruit goes back in the pockets). Returns false if there's no room for it.
func dig_out(obj: Dictionary) -> bool:
	if obj["kind"] == "fruit_tree" and obj.has("planted") and Inventory.add_item(obj["fruit"]) > 0:
		Events.toast.emit("Your pockets are full!")
		return false
	var uid: int = obj["uid"]
	var at := Vector3(obj["x"] + 0.5, data.height_at(obj["x"] + 0.5, obj["z"] + 0.5), obj["z"] + 0.5)
	disturb(obj)
	var node := node_of(uid)
	if node:
		# Pops up out of the ground and shrinks away.
		_nodes.erase(uid)
		var tw := create_tween()
		tw.tween_property(node, "position:y", node.position.y + 0.45, 0.16).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "scale", Vector3.ZERO, 0.32).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.queue_free)
	Effects.burst("dust", at + Vector3(0, 0.1, 0))
	Effects.burst("pebbles", at + Vector3(0, 0.15, 0))
	if obj["kind"] in ["bush", "fruit_tree"]:
		Effects.burst("leaves", at + Vector3(0, 0.5, 0))
	remove_object(uid)
	return true


## Why `obj` can't be set down on tile `t` with the Move tool, or "" if it can: flat,
## clear, dry ground off the paths and the plaza; grass for trees, bushes and stumps
## (palms and rocks sit on sand too); and a tile's room all round between trees.
func move_spot(obj: Dictionary, t: Vector2i, player_pos: Vector3) -> String:
	if interior or tour or visitor:
		return "Landscaping is for outdoors on your own island."
	if not data.in_bounds(t.x, t.y) or not data.is_land(t.x, t.y) or data.height_at(t.x + 0.5, t.y + 0.5) <= IslandData.SEA_LEVEL:
		return "That needs dry land."
	if t == Vector2i(floori(player_pos.x), floori(player_pos.z)):
		return "You're standing there!"
	var i := data.idx(t.x, t.y)
	var kind: String = obj["kind"]
	if not data.is_flat(t.x, t.y):
		return "It needs flat ground."
	if data.tile(t.x, t.y) == T.SAND and not kind in ["palm", "rock"]:
		return "That won't grow in the sand."
	if data.plaza.has_point(t):
		return "Better keep the plaza clear."
	if paths.has(i):
		return "Better keep the paths clear."
	var occupant: int = _occupant.get(i, obj["uid"])
	if occupant != obj["uid"] or _deck.has(i) or _door_fronts.has(i) or _rugs.has(i) or _keep_clear(t.x, t.y) or _bridge_ends().has(i):
		return "Something's in the way there."
	if kind in ["tree", "fruit_tree", "palm"]:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var near := object_at(t.x + dx, t.y + dz)
				if near.get("uid", -1) != obj["uid"] and near.get("kind", "") in ["tree", "fruit_tree", "palm", "placed"]:
					return "Trees need a little room round them."
	return ""


## Bugs sitting on or by an island object fly off (it's being chopped, dug or moved).
func disturb(obj: Dictionary) -> void:
	if critters:
		critters.disturb(Vector3(obj["x"] + 0.5, 0.0, obj["z"] + 0.5))


## Sets `obj` down on tile `t` (the Move tool), just as it was.
func move_object(obj: Dictionary, t: Vector2i) -> void:
	var uid: int = obj["uid"]
	var i := data.idx(obj["x"], obj["z"])
	if _occupant.get(i, -1) == uid:
		_occupant.erase(i)
	if _nodes.has(uid):
		_nodes[uid].queue_free()
		_nodes.erase(uid)
	obj["x"] = t.x
	obj["z"] = t.y
	_register(obj)
	_pop_in(obj)


func _roll_rock_item() -> String:
	# Some tour islands have richer rocks.
	var table: Array = TourKinds.get_kind(data.kind).get("rock_table", ROCK_TABLE) if data.kind != "" else ROCK_TABLE
	var total := 0
	for entry in table:
		total += int(entry[1])
	var roll := _rng.randi_range(1, total)
	for entry in table:
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
			Sfx.play("thud", -4.0)
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
	for inner in room_doors:
		if inner["tile"] == Vector2i(x, z):
			return true
	var door := data.room_door()
	return x == door.x and z >= door.y - 1


## Doors for a room `w` by `d` tiles to other rooms, one per wall named in `walls`
## ("back", "left" or "right"), leading to rooms 1, 2... in that order.
static func doors_for(w: int, d: int, walls: Array) -> Array[Dictionary]:
	var doors: Array[Dictionary] = []
	for i in walls.size():
		match walls[i]:
			"back":
				doors.append({"tile": Vector2i(w / 2, 0), "out": Vector2i(0, -1), "to": i + 1})
			"left":
				doors.append({"tile": Vector2i(0, d / 2), "out": Vector2i(-1, 0), "to": i + 1})
			"right":
				doors.append({"tile": Vector2i(w - 1, d / 2), "out": Vector2i(1, 0), "to": i + 1})
	return doors


## The room behind the inner door the player at `pos` is walking into (heading `dir`),
## or -1.
func room_door_ahead(pos: Vector3, dir: Vector3) -> int:
	if not interior or dir.length() < 0.5:
		return -1
	var tile := Vector2i(floori(pos.x), floori(pos.z))
	var ahead := pos + dir.normalized() * 0.45
	var heading := Vector2(dir.x, dir.z).normalized()
	for door in room_doors:
		# Standing in front of it, pushing on into the wall.
		if door["tile"] == tile and heading.dot(Vector2(door["out"])) > 0.7 \
				and (ahead.x < 0.0 or ahead.z < 0.0 or ahead.x > data.width):
			return door["to"]
	return -1


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
	if obj.get("kind", "") == "stump":
		# Sit facing whichever way you came from: a spot a hair's breadth off the middle
		# on each side, so the nearest one faces you.
		var centre := Vector3(obj["x"] + 0.5, data.height_at(obj["x"] + 0.5, obj["z"] + 0.5), obj["z"] + 0.5)
		for dir: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			spots.append({"position": centre + dir * 0.05, "facing": dir, "height": STUMP_SEAT})
		return spots
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
	var fields := {"kind": "placed", "item": item_id, "x": rect.position.x, "z": rect.position.y,
		"w": rect.size.x, "d": rect.size.y, "rot": rot}
	if ItemDB.placeable(item_id).get("plot", false):
		# A neighbour moves in the day after the plot is staked out.
		fields["plot_day"] = day_key
	var obj := add_object(fields)
	_pop_in(obj)
	return obj


# --- Days ----------------------------------------------------------------------------

func _on_day_changed(key: int) -> void:
	day_key = key
	_chops.clear()
	var rocks := 0
	for obj in data.objects:
		match obj["kind"]:
			"tree", "palm":
				obj["wood_left"] = WOOD_PER_DAY
			"fruit_tree":
				obj["wood_left"] = WOOD_PER_DAY
				if obj.has("planted"):
					# A planted tree grows a bit each night, and fruits once it's grown.
					if key - int(obj["planted"]) >= GROW_DAYS:
						obj.erase("planted")
						obj["fruit_count"] = 3
					refresh_node(obj)
				elif obj.get("fruit_count", 0) == 0 and key - obj.get("picked_day", key) >= FRUIT_REGROW_DAYS:
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


func building_of(resident: String) -> Dictionary:
	for obj in data.objects:
		if obj.get("resident", "") == resident:
			return obj
	return {}


func building(item_id: String) -> Dictionary:
	for obj in data.objects:
		if obj["kind"] == "placed" and obj["item"] == item_id:
			return obj
	return {}


func shop() -> Dictionary:
	return building("lucy_shop")


## Marlow's ferry dock: on flat sand a tile back from the sea, with open water ahead for
## the pier and alongside it for the boat. The north shore if there's room (the pier
## runs out to sea away from the camera), then east, west and south; nearest `near`.
func add_dock(near: Vector2i) -> Dictionary:
	var existing := building("dock")
	if not existing.is_empty():
		return existing
	# On a tour, Marlow lands on the main island, not a strip of beach cut off from it.
	var labels := IslandGenerator.regions(data) if tour else PackedInt32Array()
	var main := -1
	if tour:
		var sizes := {}
		for l in labels:
			if l >= 0:
				sizes[l] = sizes.get(l, 0) + 1
		for l: int in sizes:
			if main < 0 or sizes[l] > sizes[main]:
				main = l
	# rot 0 faces +Z (south), 3 faces +X, 1 faces -X, 2 faces -Z. The south shore first:
	# it's the side facing the camera, easiest to get to.
	for rot: int in [0, 3, 1, 2]:
		var best := Rect2i()
		var best_dist := INF
		for z in range(1, data.height - 2):
			for x in range(1, data.width - 2):
				var rect := Rect2i(x, z, 2, 2)
				var dist := Vector2(rect.get_center()).distance_to(Vector2(near))
				var land := _dock_tile(rect, rot, 0, -1)
				if tour and (not data.in_bounds(land.x, land.y) or labels[data.idx(land.x, land.y)] != main):
					continue
				if dist < best_dist and _dock_fits(rect, rot):
					best = rect
					best_dist = dist
		if best_dist < INF:
			for obj in data.objects.duplicate():
				if obj["kind"] in NATURAL_KINDS and best.grow(1).has_point(Vector2i(obj["x"], obj["z"])):
					remove_object(obj["uid"])
			var dock := place_item("dock", best, rot)
			dock["fixed"] = true
			return dock
	return {}


## Islands from before Marlow moved to the south shore: his dock moves there (if it
## fits). Returns true if it moved.
func move_dock_south(near: Vector2i) -> bool:
	var dock := building("dock")
	if dock.is_empty() or int(dock.get("rot", 0)) == 0:
		return false
	var old := dock.duplicate()
	remove_object(dock["uid"])
	var moved := add_dock(near)
	if moved.is_empty():
		var back := place_item("dock", Rect2i(old["x"], old["z"], old["w"], old["d"]), old["rot"])
		back["fixed"] = true
		return false
	return int(moved["rot"]) != int(old["rot"])


## A tile next to a 2x2 rect, seen from the dock: `side` across (0 and 1 are the
## footprint, -1 left of it) and `ahead` out to sea (0 and 1 are the footprint).
static func _dock_tile(rect: Rect2i, rot: int, side: int, ahead: int) -> Vector2i:
	match rot:
		3:
			return rect.position + Vector2i(ahead, 1 - side)
		1:
			return rect.position + Vector2i(1 - ahead, side)
		2:
			return rect.position + Vector2i(1 - side, 1 - ahead)
	return rect.position + Vector2i(side, ahead)


func _dock_fits(rect: Rect2i, rot: int) -> bool:
	# Flat sand under the dock, open ground beside it for Marlow and behind it to land on.
	for t: Vector2i in [_dock_tile(rect, rot, 0, 0), _dock_tile(rect, rot, 1, 0), _dock_tile(rect, rot, 0, 1), _dock_tile(rect, rot, 1, 1)]:
		if data.tile(t.x, t.y) != IslandData.Tile.SAND or not data.is_flat(t.x, t.y):
			return false
	for t: Vector2i in [_dock_tile(rect, rot, -1, 0), _dock_tile(rect, rot, 0, -1), _dock_tile(rect, rot, 1, -1)]:
		# Beach or the grass just above it (not up a cliff).
		if not data.is_land(t.x, t.y) or data.height_at(t.x + 0.5, t.y + 0.5) > IslandData.GRASS_HEIGHT + 0.05 \
				or (_occupant.has(data.idx(t.x, t.y)) and not _objects.get(_occupant[data.idx(t.x, t.y)], {}).get("kind", "") in NATURAL_KINDS):
			return false
	if not _clearable(rect):
		return false
	# Beach or sea under the start of the pier, then open sea for the end of it and the
	# boat beside it.
	for ahead in range(2, 6):
		for side in range(0, 3):
			var t := _dock_tile(rect, rot, side, ahead)
			var kind := data.tile(t.x, t.y) if data.in_bounds(t.x, t.y) else -1
			var sea_needed := ahead >= 4 or (side == 2 and ahead >= 3)
			if kind != IslandData.Tile.OCEAN and (sea_needed or kind != IslandData.Tile.SAND):
				return false
	return true


## Where Marlow stands by the dock (on the sand to its left) and where you land from
## the boat (in front, on the beach): {"skipper", "arrive": Vector3, "facing": inland}.
func dock_spots(dock: Dictionary) -> Dictionary:
	var rect := Rect2i(dock["x"], dock["z"], 2, 2)
	var rot := int(dock.get("rot", 0))
	var inland := Vector3(Vector2(_dock_tile(rect, rot, 0, -1) - _dock_tile(rect, rot, 0, 0)).x, 0,
		Vector2(_dock_tile(rect, rot, 0, -1) - _dock_tile(rect, rot, 0, 0)).y)
	var stand := Vector2(_dock_tile(rect, rot, -1, 0)) + Vector2(0.5, 0.5)
	var land := (Vector2(_dock_tile(rect, rot, 0, -1)) + Vector2(_dock_tile(rect, rot, 1, -1))) * 0.5 + Vector2(0.5, 0.5)
	return {"skipper": Vector3(stand.x, ground_height(stand.x, stand.y), stand.y),
		"arrive": Vector3(land.x, ground_height(land.x, land.y), land.y), "facing": inland}


## Nights a planted fruit takes to grow into a tree that bears fruit.
const GROW_DAYS := 4

## Things that can be cleared away to make room for a building.
const NATURAL_KINDS := ["tree", "fruit_tree", "palm", "bush", "stump", "flower", "drop"]


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
