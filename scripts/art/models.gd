class_name Models
extends RefCounted
## Procedural models for everything on the island. Meshes are cached by key, e.g.
## "tree:2", "flower:tulip:red", "drop:wood".
##
## Everything uses one shared prop material and vertex colours, so the art style can be
## tuned in shaders/prop.gdshader and the palette constants below.

const BARK := Color("a87d62")
const BARK_LIGHT := Color("c19a7c")
const LEAF_DARK := Color("6aac72")
const LEAF_MID := Color("80c17e")
const LEAF_LIGHT := Color("9cd28f")
const FRUIT_LEAF := Color("7fbf80")
const PALM_LEAF := Color("78bd7a")
const ROCK := Color("bdb8cc")
const WOOD_END := Color("f6dcb4")
const FABRIC := Color("7fc6b8")
const FABRIC_DARK := Color("4f9488")
const CREAM := Color("fff6e4")
const PLANK := Color("d4a77e")
const PLANK_DARK := Color("b08463")

static var _cache: Dictionary = {}
static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/prop.gdshader")
		# A touch softer than the ground so round shapes keep a hint of roundness.
		_material.set_shader_parameter("light_softness", 0.1)
	return _material


static func get_mesh(key: String) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var p := key.split(":")
	var k := MeshKit.new()
	match p[0]:
		"tree":
			_tree(k, int(p[1]), "", 0)
		"fruit_tree":
			_tree(k, int(p[1]), p[2], int(p[3]))
		"palm":
			_palm(k, int(p[1]))
		"rock":
			_rock(k, int(p[1]))
		"flower":
			_flower_clump(k, p[1], p[2])
		"tent":
			_tent(k)
		"bridge":
			_bridge(k, int(p[1]))
		"drop":
			_drop(k, p[1])
		"tool":
			_tool(k, p[1])
		_:
			push_warning("Unknown model key %s" % key)
			k.sphere(Vector3(0, 0.3, 0), Vector3.ONE * 0.3, MeshKit.lin(Color.MAGENTA))
	var mesh := k.commit()
	_cache[key] = mesh
	return mesh


## Model key for an island object dictionary.
static func key_for(obj: Dictionary) -> String:
	match obj["kind"]:
		"tree":
			return "tree:%d" % obj.get("variant", 0)
		"fruit_tree":
			return "fruit_tree:%d:%s:%d" % [obj.get("variant", 0), obj["fruit"], obj.get("fruit_count", 0)]
		"palm":
			return "palm:%d" % obj.get("variant", 0)
		"rock":
			return "rock:%d" % obj.get("variant", 0)
		"flower":
			return "flower:%s:%s" % [obj["species"], obj["color"]]
		"bridge":
			return "bridge:%d" % obj["length"]
		"drop":
			return "drop:%s" % obj["item"]
		"placed":
			return ItemDB.placeable(obj["item"]).get("model", "drop:" + obj["item"])
	return "unknown"


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


# --- Nature --------------------------------------------------------------------------

static func _tree(k: MeshKit, variant: int, fruit: String, fruit_count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7919 + 17
	var bark := MeshKit.lin(BARK, 0.12)
	k.cylinder(Vector3.ZERO, Vector3(0.03, 1.3, 0.0), 0.17, 0.1, bark, 7, false, MeshKit.lin(BARK_LIGHT, 0.3))
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf() * 0.8
		var dir := Vector3(cos(a), 0.0, sin(a))
		k.cylinder(dir * 0.05 + Vector3(0, 0.28, 0), dir * 0.3 + Vector3(0, 0.0, 0), 0.08, 0.035, bark, 5, false)
	var fruity := fruit != ""
	var dark := MeshKit.lin(FRUIT_LEAF if fruity else LEAF_DARK, 1.0)
	var mid := MeshKit.lin(_shade(FRUIT_LEAF, 1.06) if fruity else LEAF_MID, 1.0)
	var light := MeshKit.lin(_shade(FRUIT_LEAF, 1.13) if fruity else LEAF_LIGHT, 1.0)
	var centre := Vector3(0, 1.9 if not fruity else 1.75, 0)
	k.sphere(centre, Vector3(0.95, 0.75, 0.95), dark, 9, 14, 0.45, 0.12, variant)
	var lumps := 5 + variant % 2
	for i in lumps:
		var a := TAU * i / lumps + rng.randf() * 0.7
		var r := rng.randf_range(0.45, 0.6)
		var off := Vector3(cos(a) * 0.62, rng.randf_range(-0.2, 0.3), sin(a) * 0.62)
		k.sphere(centre + off, Vector3(r, r * 0.85, r), mid if off.y < 0.1 else light, 8, 12, 0.5, 0.14, variant * 10 + i)
	k.sphere(centre + Vector3(rng.randf_range(-0.15, 0.15), 0.52, 0.05), Vector3(0.55, 0.45, 0.55), light, 8, 12, 0.35, 0.12, variant + 99)
	if fruity and fruit_count > 0:
		var fruit_col := MeshKit.lin(ItemDB.color_of(fruit), 1.0)
		var spots := [Vector3(-0.55, -0.1, 0.75), Vector3(0.5, 0.15, 0.78), Vector3(0.0, -0.3, 0.95)]
		for i in mini(fruit_count, spots.size()):
			var s: Vector3 = spots[i]
			k.sphere(centre + s, Vector3.ONE * 0.13, fruit_col, 5, 8, 0.3)
			k.cylinder(centre + s + Vector3(0, 0.1, 0), centre + s + Vector3(0.02, 0.18, 0), 0.015, 0.01, MeshKit.lin(BARK, 1.0), 4, false)


static func _palm(k: MeshKit, variant: int) -> void:
	var lean_angle := variant * 1.7
	var lean := Vector3(cos(lean_angle), 0, sin(lean_angle)) * 0.55
	var prev := Vector3.ZERO
	var segments := 7
	for i in segments:
		var t := float(i + 1) / segments
		var p := lean * pow(t, 1.6) + Vector3(0, t * 2.7, 0)
		var col := MeshKit.lin(BARK_LIGHT if i % 2 == 0 else BARK, t * 0.6)
		k.cylinder(prev, p, lerpf(0.16, 0.1, t - 1.0 / segments), lerpf(0.16, 0.1, t), col, 7, false)
		prev = p
	var top := prev
	var leaf := MeshKit.lin(PALM_LEAF, 1.0)
	var leaf_light := MeshKit.lin(_shade(PALM_LEAF, 1.2), 1.0)
	for i in 8:
		var a := TAU * i / 8.0 + variant
		var dir := Vector3(cos(a), 0.35 if i % 2 == 0 else 0.15, sin(a))
		k.leaf(top, dir, 1.55, 0.5, leaf if i % 2 == 0 else leaf_light, 0.75)
	for i in 3:
		var a := TAU * i / 3.0
		k.sphere(top + Vector3(cos(a) * 0.14, -0.14, sin(a) * 0.14), Vector3.ONE * 0.12, MeshKit.lin(Color("a07858"), 0.6), 4, 7)


static func _rock(k: MeshKit, variant: int) -> void:
	var col := MeshKit.lin(_shade(ROCK, 0.95 + variant * 0.03), 0.0)
	k.sphere(Vector3(0, 0.3, 0), Vector3(0.5, 0.42, 0.46), col, 6, 9, 0.45, 0.3, variant + 3)
	k.sphere(Vector3(0.28, 0.15, 0.2), Vector3(0.24, 0.2, 0.22), MeshKit.lin(_shade(ROCK, 0.9)), 4, 7, 0.4, 0.3, variant + 8)


static func _flower_clump(k: MeshKit, species: String, colour: String) -> void:
	var petal_col := MeshKit.lin(Color(ItemDB.flowers.get(species, {}).get("colors", {}).get(colour, "#ffffff")), 0.6)
	var spots := [Vector3(-0.14, 0, 0.08), Vector3(0.15, 0, 0.12), Vector3(0.0, 0, -0.14)]
	for i in spots.size():
		var base: Vector3 = spots[i]
		var height := 0.36 + i * 0.05
		_flower(k, base, height, species, petal_col)
	var leaf_col := MeshKit.lin(Color("4f8f3c"), 0.4)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		k.leaf(Vector3(0, 0.02, 0), Vector3(cos(a), 0.5, sin(a)), 0.3, 0.12, leaf_col, 0.08)


static func _flower(k: MeshKit, base: Vector3, height: float, species: String, c: Color) -> void:
	var stem := MeshKit.lin(Color("5b9a42"), 0.5)
	var top := base + Vector3(0, height, 0)
	k.cylinder(base, top, 0.02, 0.015, stem, 4, false)
	var centre_col := MeshKit.lin(Color("f2c641"), 0.6)
	match species:
		"tulip":
			k.sphere(top + Vector3(0, 0.07, 0), Vector3(0.075, 0.1, 0.075), c, 5, 8, 0.3)
			for i in 3:
				var a := TAU * i / 3.0
				k.sphere(top + Vector3(cos(a) * 0.04, 0.15, sin(a) * 0.04), Vector3(0.035, 0.05, 0.035), c, 3, 5)
		"rose":
			k.sphere(top + Vector3(0, 0.05, 0), Vector3(0.085, 0.07, 0.085), c, 5, 8, 0.35)
			for i in 5:
				var a := TAU * i / 5.0
				k.sphere(top + Vector3(cos(a) * 0.06, 0.03, sin(a) * 0.06), Vector3(0.05, 0.045, 0.05), _shade(c, 0.9), 3, 6)
		"hyacinth":
			for i in 9:
				var a := i * 2.4
				var y := 0.02 + i * 0.022
				k.sphere(top + Vector3(cos(a) * 0.045, y, sin(a) * 0.045), Vector3.ONE * 0.035, c, 3, 5)
		_:
			var count: int = {"pansy": 5, "cosmos": 8, "windflower": 6, "mum": 14, "lily": 6}.get(species, 6)
			var length: float = {"pansy": 0.12, "cosmos": 0.13, "windflower": 0.11, "mum": 0.09, "lily": 0.15}.get(species, 0.11)
			var width: float = {"pansy": 0.12, "cosmos": 0.06, "windflower": 0.08, "mum": 0.04, "lily": 0.06}.get(species, 0.07)
			var tilt: float = {"pansy": 0.25, "cosmos": 0.15, "windflower": 0.2, "mum": 0.5, "lily": 0.9}.get(species, 0.2)
			for i in count:
				var a := TAU * i / count
				k.leaf(top, Vector3(cos(a), tilt, sin(a)), length, width, c, 0.0)
			var middle := centre_col
			if species in ["pansy", "windflower"]:
				middle = MeshKit.lin(Color("3a2b3a"), 0.6)
			k.sphere(top + Vector3(0, 0.015, 0), Vector3.ONE * 0.03, middle, 3, 6)


# --- Buildings -----------------------------------------------------------------------

static func _tent(k: MeshKit) -> void:
	var w := 1.25
	var d := 1.2
	var h := 1.9
	var fabric := MeshKit.lin(FABRIC)
	var fabric_dark := MeshKit.lin(FABRIC_DARK)
	var cream := MeshKit.lin(CREAM)
	# Roof panels.
	var left_n := Vector3(-h, w, 0).normalized()
	var right_n := Vector3(h, w, 0).normalized()
	k.flat_quad(Vector3(-w, 0, -d), Vector3(-w, 0, d), Vector3(0, h, d), Vector3(0, h, -d), left_n, fabric)
	k.flat_quad(Vector3(w, 0, -d), Vector3(w, 0, d), Vector3(0, h, d), Vector3(0, h, -d), right_n, fabric)
	# Cream hem along the bottom edges.
	for s: float in [-1.0, 1.0]:
		var n := right_n if s > 0 else left_n
		var out := Vector3(s * 0.02, 0, 0)
		k.flat_quad(Vector3(s * w, 0.0, -d) + out, Vector3(s * w, 0.0, d) + out,
			Vector3(s * w * 0.88, h * 0.12, d) + out, Vector3(s * w * 0.88, h * 0.12, -d) + out, n, cream)
	# Front and back gables.
	for z in [d, -d]:
		var n := Vector3(0, 0, signf(z))
		var a := k.vertex(Vector3(-w, 0, z), n, fabric)
		var b := k.vertex(Vector3(w, 0, z), n, fabric)
		var c := k.vertex(Vector3(0, h, z), n, fabric)
		k.tri(a, b, c, n)
	# Door: dark opening with tied-back flaps.
	var dz := d + 0.01
	var door_n := Vector3(0, 0, 1)
	var a := k.vertex(Vector3(-0.45, 0, dz), door_n, fabric_dark)
	var b := k.vertex(Vector3(0.45, 0, dz), door_n, fabric_dark)
	var c := k.vertex(Vector3(0, 1.25, dz), door_n, fabric_dark)
	k.tri(a, b, c, door_n)
	for s: float in [-1.0, 1.0]:
		var f0 := k.vertex(Vector3(s * 0.45, 0, dz + 0.01), door_n, cream)
		var f1 := k.vertex(Vector3(s * 0.62, 0, dz + 0.01), door_n, cream)
		var f2 := k.vertex(Vector3(s * 0.05, 1.2, dz + 0.01), door_n, cream)
		k.tri(f0, f1, f2, door_n)
	# Poles, pennant and pegs.
	var pole := MeshKit.lin(PLANK_DARK)
	for z in [d + 0.05, -d - 0.05]:
		k.cylinder(Vector3(0, h - 0.2, z), Vector3(0, h + 0.25, z), 0.04, 0.035, pole, 5)
	var flag := MeshKit.lin(Color("f5a3a3"), 0.8)
	var fa := k.vertex(Vector3(0, h + 0.25, d + 0.05), Vector3.BACK, flag)
	var fb := k.vertex(Vector3(0.3, h + 0.17, d + 0.05), Vector3.BACK, flag)
	var fc := k.vertex(Vector3(0, h + 0.09, d + 0.05), Vector3.BACK, flag)
	k.tri(fa, fb, fc, Vector3.BACK)
	k.tri(fa, fc, fb, Vector3.FORWARD)
	for s: float in [-1.0, 1.0]:
		for z in [d * 0.8, -d * 0.8]:
			k.cylinder(Vector3(s * (w + 0.25), 0, z), Vector3(s * (w + 0.25), 0.15, z), 0.03, 0.03, pole, 4)


static func _bridge(k: MeshKit, length: int) -> void:
	var half := length * 0.5 + 0.5
	var plank := MeshKit.lin(PLANK)
	var plank_dark := MeshKit.lin(PLANK_DARK)
	var planks := int(half * 2.0 / 0.25)
	for i in planks:
		var x := -half + 0.125 + i * 0.25
		var col := plank if i % 2 == 0 else MeshKit.lin(_shade(PLANK, 0.92))
		k.box(Vector3(x, -0.05, 0), Vector3(0.23, 0.1, 1.3), col)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(0, -0.1, s * 0.55), Vector3(half * 2.0, 0.12, 0.12), plank_dark)
		for i in length + 2:
			var x := -half + i * (half * 2.0 / (length + 1))
			k.cylinder(Vector3(x, -0.9, s * 0.62), Vector3(x, 0.55, s * 0.62), 0.06, 0.06, plank_dark, 6)
		k.box(Vector3(0, 0.45, s * 0.62), Vector3(half * 2.0, 0.08, 0.08), plank)


# --- Items ---------------------------------------------------------------------------

static func _drop(k: MeshKit, item: String) -> void:
	var def := ItemDB.get_item(item)
	var col := MeshKit.lin(ItemDB.color_of(item))
	match def.get("category", ""):
		"fruit":
			k.sphere(Vector3(0, 0.15, 0), Vector3.ONE * 0.15, col, 5, 8, 0.3)
			k.leaf(Vector3(0, 0.3, 0), Vector3(1, 0.4, 0), 0.14, 0.08, MeshKit.lin(Color("5c9e46")))
			return
		"flower":
			for i in 3:
				var a := TAU * i / 3.0
				var base := Vector3(cos(a) * 0.05, 0, sin(a) * 0.05)
				k.cylinder(base, base + Vector3(0, 0.22, 0), 0.015, 0.015, MeshKit.lin(Color("5b9a42")), 4, false)
				k.sphere(base + Vector3(0, 0.25, 0), Vector3.ONE * 0.06, col, 4, 6)
			return
	match item:
		"wood":
			# Three logs lying crosswise, two below and one on top.
			for i in 3:
				var y := 0.09 + (0.15 if i == 2 else 0.0)
				var z := (-0.09 + i * 0.18) if i < 2 else 0.0
				k.cylinder(Vector3(-0.24, y, z), Vector3(0.24, y, z), 0.09, 0.09, col, 8, true, MeshKit.lin(WOOD_END))
		"tree_branch":
			k.cylinder(Vector3(-0.25, 0.04, 0.05), Vector3(0.25, 0.04, -0.05), 0.03, 0.02, col, 5)
			k.cylinder(Vector3(0.05, 0.04, 0.0), Vector3(0.15, 0.06, 0.12), 0.015, 0.01, col, 4)
		"stone", "clay":
			k.sphere(Vector3(0, 0.1, 0), Vector3(0.17, 0.11, 0.15), col, 4, 7, 0.4, 0.3, item.length())
		"acorn_pouch":
			k.sphere(Vector3(0, 0.15, 0), Vector3(0.17, 0.16, 0.17), col, 5, 8, 0.35)
			k.sphere(Vector3(0, 0.31, 0), Vector3(0.07, 0.05, 0.07), MeshKit.lin(Color("8a5e34")), 3, 6)
			k.sphere(Vector3(0, 0.15, 0.15), Vector3(0.06, 0.07, 0.03), MeshKit.lin(Color("6b4a2b")), 3, 6)
		"iron_nugget", "gold_nugget":
			k.sphere(Vector3(0, 0.09, 0), Vector3(0.13, 0.1, 0.12), col, 3, 5, 0.3, 0.4, 5)
		_:
			# Generic parcel, like a wrapped leaf.
			k.leaf(Vector3(-0.15, 0.05, 0.0), Vector3(1, 0.2, 0), 0.32, 0.26, MeshKit.lin(Color("9bbf5a")))


static func _tool(k: MeshKit, item: String) -> void:
	var handle := MeshKit.lin(Color("a07a4d"))
	match ItemDB.tool_type(item):
		"axe":
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.55, 0), 0.03, 0.028, handle, 5)
			k.box(Vector3(0.09, 0.47, 0), Vector3(0.16, 0.14, 0.04), MeshKit.lin(Color("9aa3a8")))
		"shovel":
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.6, 0), 0.028, 0.028, handle, 5)
			k.box(Vector3(0, 0.72, 0), Vector3(0.18, 0.22, 0.03), MeshKit.lin(Color("8aa0b0")))
		_:
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.5, 0), 0.03, 0.03, handle, 5)
