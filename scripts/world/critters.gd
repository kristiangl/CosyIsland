class_name Critters
extends Node3D
## Fish and bugs about the island (data/creatures.json), kept near the player: fish as
## shadows in the sea near the shore, rivers and ponds; bugs on flowers, trees, rocks,
## grass and the beach, in the air and over water. Which ones turn up depends on the
## time of day. Nothing here is saved: they come and go.
##
## Fishing: the player casts a bobber (`cast`); a nearby fish of that water comes to look,
## nibbles a few times and bites, and `reel` catches it if it's biting.

const FISH_MAX := 8
const BUGS_MAX := 7
const NEAR := 16.0
const FAR := 24.0
## How long a bite lasts before the fish gets away.
const BITE_TIME := 0.7

## Water kinds per tile: 0 none, else "sea" (near the shore), "river" or "pond".
const WATER_KINDS := ["", "sea", "river", "pond"]
## Bugs are drawn bigger than life so they read from the camera; small ones more so
## than the big-winged ones.
const BUG_SCALE := 2.2
const SMALL_BUG_SCALE := 3.0
const BIG_WINGS := ["butterfly", "moth", "dragonfly"]
## How long one hop takes, and how far it goes from home at most.
const HOP_TIME := 0.32
const HOP_RANGE := 0.45

var world: World
var fish: Array[Dictionary] = []
var bugs: Array[Dictionary] = []
var bobber: Node3D
var _water := PackedByteArray()
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _shadow_material: ShaderMaterial
var _bobber_kind := ""
## The fish that's taken an interest in the bobber, or {}.
var _hooked: Dictionary = {}


func setup(w: World) -> void:
	world = w
	_rng.seed = w.data.seed_value * 13 + Time.get_ticks_msec()
	_classify_water()
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = load("res://shaders/blob_shadow.gdshader")
	bobber = MeshInstance3D.new()
	bobber.mesh = Models.get_mesh("bobber")
	bobber.material_override = Models.material()
	bobber.visible = false
	add_child(bobber)


## Marks each water tile: sea within a few tiles of land, and fresh water split into
## ponds (small pools on their own) and rivers.
func _classify_water(sea := true) -> void:
	var d := world.data
	if _water.size() != d.width * d.height:
		_water.resize(d.width * d.height)
	var seen := {}
	for z in d.height:
		for x in d.width:
			var t := d.tile(x, z)
			if t == IslandData.Tile.OCEAN and sea:
				for dz in range(-2, 3):
					for dx in range(-2, 3):
						if d.is_land(x + dx, z + dz):
							_water[d.idx(x, z)] = 1
			elif t == IslandData.Tile.WATER and not seen.has(d.idx(x, z)):
				# Flood fill the body of fresh water.
				var body: Array[Vector2i] = []
				var open: Array[Vector2i] = [Vector2i(x, z)]
				var touches_sea := false
				seen[d.idx(x, z)] = true
				while not open.is_empty():
					var p: Vector2i = open.pop_back()
					body.append(p)
					for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var q := p + step
						if not d.in_bounds(q.x, q.y):
							continue
						if d.tile(q.x, q.y) == IslandData.Tile.OCEAN:
							touches_sea = true
						elif d.tile(q.x, q.y) == IslandData.Tile.WATER and not seen.has(d.idx(q.x, q.y)):
							seen[d.idx(q.x, q.y)] = true
							open.append(q)
				var kind := 3 if body.size() < 60 and not touches_sea else 2
				for p in body:
					_water[d.idx(p.x, p.y)] = kind


## Sorts the water out again after landscaping.
func refresh_water() -> void:
	for i in _water.size():
		if _water[i] >= 2:
			_water[i] = 0
	_classify_water(false)


func water_kind(x: int, z: int) -> String:
	if not world.data.in_bounds(x, z):
		return ""
	return WATER_KINDS[_water[world.data.idx(x, z)]]


## The kind of water at a point, if it's deep enough to swim in there ("" if not).
func swim_kind(p: Vector3) -> String:
	var t := Vector2i(floori(p.x), floori(p.z))
	var kind := water_kind(t.x, t.y)
	if kind == "" or world.data.height_at(p.x, p.z) > _surface(t.x, t.y) - 0.12:
		return ""
	return kind


func _surface(x: int, z: int) -> float:
	if world.data.tile(x, z) == IslandData.Tile.OCEAN:
		return IslandData.SEA_LEVEL
	return world.data.water_surface(x, z)


static func _in_hours(c: Dictionary, hour: float) -> bool:
	var from: float = c["hours"][0]
	var to: float = c["hours"][1]
	if from <= to:
		return hour >= from and hour < to
	return hour >= from or hour < to


## Creatures with "weather" come out only in the rain ("rain"), in the snow ("snow"), or
## when it's dry ("dry": butterflies hide from the rain).
static func weather_suits(c: Dictionary) -> bool:
	match c.get("weather", ""):
		"rain":
			return Weather.rain > 0.1
		"snow":
			return Weather.snow > 0.1 or Weather.snow_cover > 0.5
		"dry":
			return Weather.rain < 0.1 and Weather.snow < 0.1
	return true


## Creatures with "islands" only live on those kinds of tour island.
static func lives_here(c: Dictionary, kind: String) -> bool:
	return not c.has("islands") or kind in c["islands"]


## How common a creature is; the rare ones of a rare island are its point, so they're
## easy to come across there.
func _weight(c: Dictionary) -> float:
	return float(c.get("weight", 1)) * (6.0 if c.has("islands") else 1.0)


## A creature for a place at this hour, by weight, or {} if none are about.
func pick(table: Dictionary, where: String, hour: float) -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for c: Dictionary in table.values():
		if c["where"] == where and _in_hours(c, hour) and lives_here(c, world.data.kind) and weather_suits(c):
			pool.append(c)
			total += _weight(c)
	var roll := _rng.randf() * total
	for c: Dictionary in pool:
		roll -= _weight(c)
		if roll <= 0.0:
			return c
	return {}


func _process(delta: float) -> void:
	var player := Game.player
	if player == null or player.world != world:
		return
	var hour := GameClock.hour_float()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.6
		var more := float(TourKinds.get_kind(world.data.kind).get("critters", 1.0)) if world.data.kind != "" else 1.0
		if fish.size() < FISH_MAX * more:
			_spawn_fish(player.position, hour)
		if bugs.size() < BUGS_MAX * more:
			_spawn_bug(player.position, hour)
	for f in fish.duplicate():
		_update_fish(f, delta, player)
	for b in bugs.duplicate():
		_update_bug(b, delta, player)


# --- Fish ----------------------------------------------------------------------------

func _spawn_fish(around: Vector3, hour: float) -> void:
	for attempt in 12:
		var p := Vector2(around.x, around.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(4.0, NEAR)
		var tile := Vector2i(floori(p.x), floori(p.y))
		var kind := swim_kind(Vector3(p.x, 0, p.y))
		if kind == "":
			continue
		var c := pick(ItemDB.fish, kind, hour)
		if c.is_empty():
			return
		add_fish(c["id"], Vector3(p.x, _surface(tile.x, tile.y) + 0.03, p.y))
		return


## Puts a fish shadow in the water at `at` (also used by tests).
func add_fish(id: String, at: Vector3) -> Dictionary:
	var c: Dictionary = ItemDB.fish[id]
	var node := MeshInstance3D.new()
	node.mesh = Models.get_mesh("fishshadow:" + String(c.get("size", "small")))
	node.material_override = _shadow_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	add_child(node)
	var f := {"id": id, "node": node, "kind": water_kind(floori(at.x), floori(at.z)), "target": at,
		"state": "swim", "timer": 0.0, "nibbles": 0, "fade": 0.0}
	fish.append(f)
	return f


func _update_fish(f: Dictionary, delta: float, player: Player) -> void:
	var node: Node3D = f["node"]
	var pos := node.position
	if Vector2(pos.x - player.position.x, pos.z - player.position.z).length() > FAR:
		_remove_fish(f)
		return
	f["timer"] = float(f["timer"]) - delta
	var speed := 0.35
	match f["state"]:
		"swim":
			if bobber.visible and _hooked.is_empty() and f["kind"] == _bobber_kind \
					and Vector2(pos.x - bobber.position.x, pos.z - bobber.position.z).length() < 2.6:
				_hooked = f
				f["state"] = "approach"
				f["nibbles"] = _rng.randi_range(1, 3)
			elif float(f["timer"]) <= 0.0 or pos.distance_to(f["target"]) < 0.1:
				f["timer"] = _rng.randf_range(2.0, 5.0)
				for attempt in 6:
					var t: Vector3 = pos + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
					if swim_kind(t) == f["kind"]:
						f["target"] = Vector3(t.x, pos.y, t.z)
						break
		"approach":
			f["target"] = bobber.position + (pos - bobber.position).normalized() * 0.3 * Vector3(1, 0, 1)
			f["target"].y = pos.y
			speed = 0.5
			if Vector2(pos.x - f["target"].x, pos.z - f["target"].z).length() < 0.06:
				f["state"] = "nibble"
				f["timer"] = _rng.randf_range(0.8, 1.6)
		"nibble":
			if float(f["timer"]) <= 0.0:
				if int(f["nibbles"]) > 0:
					f["nibbles"] = int(f["nibbles"]) - 1
					f["timer"] = _rng.randf_range(0.7, 1.5)
					_dip(0.03)
					Sfx.play("plop", -10.0, 1.3)
				else:
					f["state"] = "bite"
					f["timer"] = BITE_TIME
					_dip(0.09)
					Effects.burst("splash", bobber.position)
					Sfx.play("splash", -2.0)
		"bite":
			if float(f["timer"]) <= 0.0:
				# Too slow: it got away.
				Sfx.play("jingle_lost", -4.0, 1.0, 0.0)
				_escape(f)
		"flee":
			f["fade"] = float(f["fade"]) + delta * 2.0
			speed = 1.6
			node.transparency = clampf(float(f["fade"]), 0.0, 1.0)
			if float(f["fade"]) >= 1.0:
				_remove_fish(f)
				return
	var to: Vector3 = f["target"] - pos
	to.y = 0.0
	if to.length() > 0.01:
		node.position += to.normalized() * minf(speed * delta, to.length())
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-to.z, to.x), 1.0 - exp(-delta * 6.0))


func _dip(depth: float) -> void:
	if not bobber.visible:
		return
	var rest := bobber.position.y
	var tw := bobber.create_tween()
	tw.tween_property(bobber, "position:y", rest - depth, 0.08)
	tw.tween_property(bobber, "position:y", rest, 0.25)


func _escape(f: Dictionary) -> void:
	if _hooked == f:
		_hooked = {}
	f["state"] = "flee"
	var away: Vector3 = f["node"].position - bobber.position
	f["target"] = f["node"].position + Vector3(away.x, 0, away.z).normalized() * 3.0


func _remove_fish(f: Dictionary) -> void:
	if _hooked == f:
		_hooked = {}
	f["node"].queue_free()
	fish.erase(f)


## Where a cast from `from` heading `dir` lands: the first water within reach, or null.
func cast_spot(from: Vector3, dir: Vector3) -> Variant:
	for i in 8:
		var p := from + dir.normalized() * (1.4 + i * 0.25)
		if swim_kind(p) != "":
			return Vector3(p.x, _surface(floori(p.x), floori(p.z)), p.z)
	return null


func cast(at: Vector3) -> void:
	bobber.position = at
	bobber.visible = true
	_bobber_kind = water_kind(floori(at.x), floori(at.z))
	Effects.burst("splash", at)
	Sfx.play("plop", -3.0)


## True while a fish has the bait: reel in now to catch it.
func is_biting() -> bool:
	return not _hooked.is_empty() and _hooked["state"] == "bite"


## Reels in: returns the caught fish's id if one was biting, else "" (and any fish
## that was nibbling swims off).
func reel() -> String:
	var caught := ""
	if is_biting():
		caught = _hooked["id"]
		Sfx.play("splash")
		var f := _hooked
		_hooked = {}
		_remove_fish(f)
	elif not _hooked.is_empty():
		_escape(_hooked)
	bobber.visible = false
	_bobber_kind = ""
	return caught


# --- Bugs ----------------------------------------------------------------------------

const BUG_PLACES := ["flowers", "flowers", "air", "grass", "trees", "rocks", "beach", "water"]


func _spawn_bug(around: Vector3, hour: float) -> void:
	var where: String = BUG_PLACES[_rng.randi() % BUG_PLACES.size()]
	var c := pick(ItemDB.bugs, where, hour)
	if c.is_empty():
		return
	var spot: Variant = _bug_spot(where, around)
	if spot == null:
		return
	add_bug(c["id"], spot, where)


## A place for a bug of this kind near `around`, or null.
func _bug_spot(where: String, around: Vector3) -> Variant:
	var d := world.data
	match where:
		"flowers", "trees", "rocks":
			var kinds: Array = {"flowers": ["flower"], "trees": ["tree", "fruit_tree"], "rocks": ["rock"]}[where]
			var near: Array = []
			for obj in world.objects():
				if obj["kind"] in kinds and Vector2(obj["x"] + 0.5 - around.x, obj["z"] + 0.5 - around.z).length() < NEAR \
						and Vector2(obj["x"] + 0.5 - around.x, obj["z"] + 0.5 - around.z).length() > 3.0:
					near.append(obj)
			if near.is_empty():
				return null
			var obj: Dictionary = near[_rng.randi() % near.size()]
			var ground := d.height_at(obj["x"] + 0.5, obj["z"] + 0.5)
			match where:
				"flowers":
					return Vector3(obj["x"] + 0.5, ground + 0.55, obj["z"] + 0.5)
				"trees":
					# On the trunk, on the side facing the camera.
					return Vector3(obj["x"] + 0.5, ground + 0.75, obj["z"] + 0.5 + 0.17)
				_:
					return Vector3(obj["x"] + 0.5, ground + 0.62, obj["z"] + 0.5)
		_:
			for attempt in 10:
				var p := Vector2(around.x, around.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(4.0, NEAR)
				var t := Vector2i(floori(p.x), floori(p.y))
				if not d.in_bounds(t.x, t.y):
					continue
				var tile := d.tile(t.x, t.y)
				var ok := false
				match where:
					"air", "grass":
						ok = tile == IslandData.Tile.GRASS and world.object_at(t.x, t.y).is_empty()
					"beach":
						ok = tile == IslandData.Tile.SAND and world.object_at(t.x, t.y).is_empty()
					"water":
						ok = water_kind(t.x, t.y) in ["river", "pond"]
				if not ok:
					continue
				var y := _surface(t.x, t.y) if where == "water" else d.height_at(p.x, p.y)
				var lift: float = {"air": 1.0, "water": 0.6}.get(where, 0.02)
				return Vector3(p.x, y + lift, p.y)
	return null


## Puts a bug on the island at `at` (also used by tests).
func add_bug(id: String, at: Vector3, where: String) -> Dictionary:
	var node := MeshInstance3D.new()
	node.mesh = Models.get_mesh("creature:" + id)
	node.material_override = Models.material()
	node.position = at
	var size := bug_scale(id)
	node.scale = Vector3.ONE * size
	add_child(node)
	var flies: bool = where in ["flowers", "air", "water"] and not ItemDB.bugs[id].get("shape", "") in ["ladybug"]
	if where == "trees":
		# Clinging to the trunk, head up.
		node.rotation.x = -PI * 0.5
	var b := {"id": id, "node": node, "where": where, "home": at, "flies": flies, "t": _rng.randf() * 10.0,
		"state": "idle", "away": Vector3.ZERO, "size": size,
		"hop": -1.0, "wait": _rng.randf_range(0.5, 3.0), "from": at, "to": at}
	bugs.append(b)
	return b


func _update_bug(b: Dictionary, delta: float, player: Player) -> void:
	var node: Node3D = b["node"]
	var to_player := Vector2(node.position.x - player.position.x, node.position.z - player.position.z)
	if to_player.length() > FAR:
		_remove_bug(b)
		return
	b["t"] = float(b["t"]) + delta
	var t: float = b["t"]
	if b["state"] == "flee":
		node.position += Vector3(b["away"]) * delta
		node.scale *= 1.0 - delta * 0.6
		if node.scale.y < 0.2 * float(b["size"]):
			_remove_bug(b)
		return
	# Running nearby scares bugs off; walking up slowly doesn't.
	if to_player.length() < 2.6 and player._speed > Player.WALK_SPEED + 0.5:
		scare(b, to_player)
		return
	var home: Vector3 = b["home"]
	if b["flies"]:
		var wander := Vector3(sin(t * 0.7) * 0.6, sin(t * 1.9) * 0.15, cos(t * 0.53) * 0.5)
		if b["where"] == "flowers":
			wander *= 0.6
		node.position = home + wander
		node.rotation.y = atan2(cos(t * 0.7) * 0.42, -sin(t * 0.53) * 0.27)
		# Wings flapping: squash the wings in and out.
		node.scale = Vector3(0.35 + 0.65 * absf(sin(t * 14.0)), 1, 1) * float(b["size"])
	elif b["where"] in ["grass", "beach"]:
		_hop(b, delta)


## Grass and beach bugs: a pause, then a hop (or a crab's sideways scuttle) to a new
## spot near home, turning to face where they're going.
func _hop(b: Dictionary, delta: float) -> void:
	var node: Node3D = b["node"]
	var crab: bool = ItemDB.bugs[b["id"]].get("shape", "") == "crab"
	if float(b["hop"]) < 0.0:
		b["wait"] = float(b["wait"]) - delta
		if float(b["wait"]) > 0.0:
			return
		var home: Vector3 = b["home"]
		var a := _rng.randf() * TAU
		var to := home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.1, HOP_RANGE)
		var from := node.position
		from.y = home.y
		b["from"] = from
		b["to"] = to
		b["hop"] = 0.0
		var d := to - from
		if d.length() > 0.01:
			node.rotation.y = atan2(d.x, d.z) + (PI * 0.5 if crab else 0.0)
		return
	var k := minf(float(b["hop"]) + delta / (HOP_TIME * (2.0 if crab else 1.0)), 1.0)
	b["hop"] = k
	var lift := 0.0 if crab else sin(k * PI) * 0.14
	node.position = Vector3(b["from"]).lerp(Vector3(b["to"]), k) + Vector3(0, lift, 0)
	if k >= 1.0:
		b["hop"] = -1.0
		b["wait"] = _rng.randf_range(1.2, 3.5)


## How much bigger than life a bug is drawn.
static func bug_scale(id: String) -> float:
	return BUG_SCALE if ItemDB.bugs.get(id, {}).get("shape", "") in BIG_WINGS else SMALL_BUG_SCALE


func scare(b: Dictionary, away: Vector2) -> void:
	b["state"] = "flee"
	var dir := Vector3(away.x, 0, away.y).normalized()
	b["away"] = dir * 3.0 + Vector3(0, 1.6, 0)


## Something shook the spot where bugs sit (a tree felled or dug up, a rock lifted): any
## close by fly off.
func disturb(at: Vector3, radius: float = 1.0) -> void:
	for b in bugs:
		var home: Vector3 = b["home"]
		var away := Vector2(home.x - at.x, home.z - at.z)
		if b["state"] != "flee" and away.length() < radius:
			scare(b, away if away.length() > 0.01 else Vector2(0, 1))


func _remove_bug(b: Dictionary) -> void:
	b["node"].queue_free()
	bugs.erase(b)


## Swings a net at `point`: catches the bug there, if any. Returns its id or "".
func net(point: Vector3) -> String:
	for b in bugs:
		if b["state"] == "flee":
			continue
		var p: Vector3 = b["node"].position
		if Vector2(p.x - point.x, p.z - point.z).length() < 0.75 and p.y - point.y < 1.6:
			var id: String = b["id"]
			_remove_bug(b)
			return id
	return ""
