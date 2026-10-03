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
static var _fabrics: Dictionary = {}
static var _glow: ShaderMaterial
static var _flower: ShaderMaterial
static var _glass: ShaderMaterial


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
	if p[0] == "series":
		var mesh := _series(p[1])
		_cache[key] = mesh
		return mesh
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
			_flower_clump(k, p[1], p[2], p.size() > 3 and p[3] == "picked")
		"creature":
			CreatureModels.build(k, p[1])
		"fishshadow":
			CreatureModels.shadow(k, p[1])
		"bobber":
			CreatureModels.bobber(k)
		"hairflower":
			_hair_flower(k, p[1])
		"vase":
			_vase_flower(k, p[1])
		"tent":
			_tent(k)
		"office":
			_office(k)
		"lucy_shop":
			_lucy_shop(k)
		"museum_tent":
			_museum_tent(k)
		"museum":
			_museum(k)
		"exhibit":
			_exhibit(k, p[1] if p.size() > 1 else "tank", p[2] if p.size() > 2 else "")
		"house":
			_house(k)
		"nhouse":
			# A neighbour's house in their colours.
			var home: Dictionary = NpcData.get_character(p[1]).get("home", {})
			_house(k, Color(home.get("wall", "fbf0d9")), Color(home.get("roof", "e0857a")), Color(home.get("door", "9fd3c7")))
		"plot":
			_plot(k)
		"bridge":
			_bridge(k, int(p[1]))
		"drop":
			_drop(k, p[1])
		"tool":
			_tool(k, p[1])
		"furniture":
			FurnitureModels.build(k, p[1])
			if p.size() > 2:
				FurnitureModels.repaint(k, ItemDB.woods.get(p[2], {}))
		"clothing":
			_clothing(k, p[1])
		_:
			push_warning("Unknown model key %s" % key)
			k.sphere(Vector3(0, 0.3, 0), Vector3.ONE * 0.3, MeshKit.lin(Color.MAGENTA))
	var mesh := k.commit()
	_cache[key] = mesh
	return mesh


## A furniture series piece: wood in the prop material; fabric, if any, in its own
## surface drawn with the cloth shader in the variant's print; and glowing parts, if
## any, in a surface that lights up at night. Show it with `dress`.
static func _series(id: String) -> ArrayMesh:
	var spec: Dictionary = ItemDB.get_item(id).get("build", {})
	var k := MeshKit.new()
	var fabric := MeshKit.new()
	var glow := MeshKit.new()
	SeriesModels.build(k, fabric, spec, glow)
	var mesh := k.commit()
	if not fabric.is_empty():
		mesh.set_meta("fabric_surface", mesh.get_surface_count())
		fabric.commit(mesh)
		mesh.set_meta("fabric", spec["variant"].get("fabric", ["ffffff", "ffffff", "plain"]))
	if not glow.is_empty():
		mesh.set_meta("glow_surface", mesh.get_surface_count())
		glow.commit(mesh)
	return mesh


## Sets a mesh instance's material: `base` for a plain model; for a model with fabric,
## `base` on the wood and the fabric material on the rest. `icon` for menus and icons
## (no world curve, fixed lighting).
static func dress(mi: MeshInstance3D, base: Material, icon: bool = false) -> void:
	var mesh := mi.mesh
	if mesh and (mesh.has_meta("fabric") or mesh.has_meta("glow_surface")):
		mi.material_override = null
		var fabric_index: int = mesh.get_meta("fabric_surface", -1)
		var glow_index: int = mesh.get_meta("glow_surface", -1)
		for i in mesh.get_surface_count():
			var mat := base
			if i == fabric_index:
				mat = fabric_material(mesh.get_meta("fabric"), icon)
			elif i == glow_index and not icon:
				mat = glow_material()
			mi.set_surface_override_material(i, mat)
	else:
		mi.material_override = base


## The prop material for flowers: short, so they sway more for their height.
static func flower_material() -> ShaderMaterial:
	if _flower == null:
		_flower = material().duplicate()
		_flower.set_shader_parameter("sway_scale", 3.5)
	return _flower


## The prop material for window glass: the sky outside, dark blue at night.
static func glass_material() -> ShaderMaterial:
	if _glass == null:
		_glass = material().duplicate()
		_glass.set_shader_parameter("night_sky", 1.0)
	return _glass


## The prop material for parts that glow at night (see DayNight.glow_at).
static func glow_material() -> ShaderMaterial:
	if _glow == null:
		_glow = material().duplicate()
		_glow.set_shader_parameter("glow", 0.9)
	return _glow


## Cloth-shader material for furniture fabric: [colour a, colour b, print id] with print
## ids from appearance.json "pattern". Cached.
static func fabric_material(spec: Array, icon: bool = false) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [spec[0], spec[1], spec[2], icon]
	if not _fabrics.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/cloth.gdshader")
		m.set_shader_parameter("colour_a", Color(spec[0]))
		m.set_shader_parameter("colour_b", Color(spec[1]))
		var pattern := 0
		var list := Appearance.options("top_pattern")
		for i in list.size():
			if list[i]["id"] == spec[2]:
				pattern = i
		m.set_shader_parameter("pattern", pattern)
		m.set_shader_parameter("pattern_scale", 1.8)
		m.set_shader_parameter("light_softness", 0.1)
		m.set_shader_parameter("curved", not icon)
		m.set_shader_parameter("fixed_tints", icon)
		_fabrics[key] = m
	return _fabrics[key]


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
			return "flower:%s:%s%s" % [obj["species"], obj["color"], ":picked" if obj.get("picked", false) else ""]
		"bridge":
			return "bridge:%d" % obj["length"]
		"drop":
			return "drop:%s" % obj["item"]
		"placed":
			if obj.has("exhibit"):
				return "exhibit:%s:%s" % ["tank" if obj["item"] == "exhibit_tank" else "case", obj["exhibit"]]
			if obj.has("resident"):
				return "nhouse:" + String(obj["resident"])
			return ItemDB.placeable(obj["item"]).get("model", "drop:" + obj["item"])
	return "unknown"


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


# --- Nature --------------------------------------------------------------------------

## Trees in the Animal Crossing manner: a short trunk under stacked, rounded tiers of
## leaves, each a ring of soft puffs, so the cel lighting picks out every layer.
static func _tree(k: MeshKit, variant: int, fruit: String, fruit_count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7919 + 17
	var bark := MeshKit.lin(BARK, 0.12)
	var lean := Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
	k.cylinder(Vector3.ZERO, Vector3(0, 0.7, 0) + lean * 0.5, 0.17, 0.13, bark, 8, false)
	k.cylinder(Vector3(0, 0.7, 0) + lean * 0.5, Vector3(0, 1.45, 0) + lean, 0.13, 0.09, bark, 8, false, MeshKit.lin(BARK_LIGHT, 0.3))
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf() * 0.8
		var dir := Vector3(cos(a), 0.0, sin(a))
		k.cylinder(dir * 0.05 + Vector3(0, 0.26, 0), dir * 0.3, 0.08, 0.035, bark, 5, false)
	var fruity := fruit != ""
	var leaf := FRUIT_LEAF if fruity else LEAF_MID
	var colours := [leaf.darkened(0.16), leaf.lightened(0.04), leaf.lightened(0.2)]
	# Tier: [height, radius, thickness, puffs]
	var tiers := [[1.3, 1.02, 0.3, 9], [1.86, 0.8, 0.28, 8], [2.36, 0.5, 0.26, 6]]
	if fruity:
		tiers = [[1.3, 0.98, 0.32, 8], [1.84, 0.7, 0.3, 7], [2.28, 0.38, 0.26, 5]]
	for t in tiers.size():
		var tier: Array = tiers[t]
		var y: float = tier[0]
		var r: float = tier[1]
		var thick: float = tier[2]
		var puffs: int = tier[3]
		var col := MeshKit.lin(colours[t], 1.0)
		var centre := Vector3(0, y, 0) + lean
		# A domed middle with a scalloped rim of puffs drooping a little at the edge.
		k.sphere(centre + Vector3(0, thick * 0.25, 0), Vector3(r * 0.72, thick * 1.1, r * 0.72), col, 8, 14, 0.6, 0.06, variant * 7 + t)
		var turn := rng.randf() * TAU
		for i in puffs:
			var a := turn + TAU * i / puffs + rng.randf_range(-0.12, 0.12)
			var pr := r * rng.randf_range(0.34, 0.4)
			var off := Vector3(cos(a) * r * 0.68, -thick * 0.25 + rng.randf_range(-0.03, 0.03), sin(a) * r * 0.68)
			k.sphere(centre + off, Vector3(pr, thick * 0.8, pr), col, 7, 10, 0.6, 0.08, variant * 31 + t * 7 + i)
	if fruity and fruit_count > 0:
		var fruit_col := MeshKit.lin(ItemDB.color_of(fruit), 1.0)
		var spots := [Vector3(-0.55, 1.02, 0.6), Vector3(0.55, 1.05, 0.58), Vector3(0.0, 0.98, 0.82)]
		for i in mini(fruit_count, spots.size()):
			var s: Vector3 = spots[i] + lean
			k.sphere(s, Vector3.ONE * 0.13, fruit_col, 6, 9, 0.3)
			k.cylinder(s + Vector3(0, 0.1, 0), s + Vector3(0.02, 0.2, 0), 0.015, 0.01, MeshKit.lin(BARK, 1.0), 4, false)


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


## A clump of flowers: a rosette of leaves and four or five stems of different heights,
## leaning out a little. Picked clumps keep their stems and leaves, with green buds
## where the blooms were, until they flower again the next day.
static func _flower_clump(k: MeshKit, species: String, colour: String, picked: bool = false) -> void:
	var petal := MeshKit.lin(Color(ItemDB.flowers.get(species, {}).get("colors", {}).get(colour, "#ffffff")), 0.9)
	var leaf_dark := MeshKit.lin(Color("5a9a46"), 0.45)
	var leaf_light := MeshKit.lin(Color("7cbb5c"), 0.45)
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var lift := 0.3 + (i % 3) * 0.12
		k.leaf(Vector3(0, 0.02, 0), Vector3(cos(a), lift, sin(a)), 0.22 + (i % 2) * 0.06, 0.12, leaf_dark if i % 2 == 0 else leaf_light, 0.07)
	var stems := [[Vector3(-0.12, 0, 0.06), 0.34], [Vector3(0.13, 0, 0.09), 0.4], [Vector3(0.02, 0, -0.12), 0.47],
		[Vector3(0.06, 0, 0.15), 0.27], [Vector3(-0.08, 0, -0.06), 0.42]]
	var stem_col := MeshKit.lin(Color("5f9e45"), 0.7)
	for i in stems.size():
		var base: Vector3 = stems[i][0]
		var height: float = stems[i][1]
		var top := base + Vector3(base.x * 0.35, height, base.z * 0.35)
		k.cylinder(base, top, 0.016, 0.012, stem_col, 4, false)
		# A small leaf partway up every other stem.
		if i % 2 == 0:
			var mid := base.lerp(top, 0.45)
			k.leaf(mid, Vector3(base.x + 0.01, 0.6, base.z + 0.01), 0.1, 0.05, leaf_light, 0.02)
		if picked or i == 4:
			# A closed green bud (the last stem is always still budding).
			k.sphere(top + Vector3(0, 0.025, 0), Vector3(0.025, 0.04, 0.025), MeshKit.lin(Color("8cc56a"), 0.8), 3, 5)
		else:
			bloom(k, top, species, petal, i)


## One flower head at `top`, facing up. `variant` varies the turn so a clump isn't uniform.
static func bloom(k: MeshKit, top: Vector3, species: String, c: Color, variant: int = 0) -> void:
	var light := Color(c.lightened(0.18), c.a)
	var deep := Color(c.darkened(0.12), c.a)
	var turn := variant * 0.9
	var centre_col := MeshKit.lin(Color("f2c641"), 0.8)
	match species:
		"tulip":
			# A cup of six petals, three outer and three inner.
			k.sphere(top + Vector3(0, 0.05, 0), Vector3(0.045, 0.06, 0.045), deep, 4, 6)
			for i in 6:
				var a := turn + TAU * i / 6.0
				var inner := i % 2 == 1
				k.leaf(top + Vector3(0, 0.005, 0), Vector3(cos(a) * (0.25 if inner else 0.4), 1.0, sin(a) * (0.25 if inner else 0.4)),
					0.15 if inner else 0.17, 0.1, light if inner else c, -0.01)
		"rose":
			k.sphere(top + Vector3(0, 0.045, 0), Vector3(0.045, 0.045, 0.045), deep, 4, 7)
			for i in 5:
				var a := turn + TAU * i / 5.0
				k.leaf(top + Vector3(0, 0.02, 0), Vector3(cos(a), 1.1, sin(a)), 0.085, 0.09, c, -0.015)
			for i in 6:
				var a := turn + TAU * (i + 0.5) / 6.0
				k.leaf(top + Vector3(0, 0.01, 0), Vector3(cos(a), 0.35, sin(a)), 0.11, 0.1, light, 0.01)
		"hyacinth":
			for i in 13:
				var a := turn + i * 2.4
				var y := 0.02 + i * 0.016
				var r := 0.042 * (1.0 - i / 18.0)
				k.sphere(top + Vector3(cos(a) * r, y, sin(a) * r), Vector3.ONE * (0.03 - i * 0.0009), c if i % 3 else light, 3, 5)
		"lily":
			for i in 6:
				var a := turn + TAU * i / 6.0
				k.leaf(top, Vector3(cos(a), 0.75, sin(a)), 0.16, 0.06, c if i % 2 else light, 0.04)
			for i in 3:
				var a := turn + TAU * i / 3.0 + 0.4
				var tip := top + Vector3(cos(a) * 0.04, 0.09, sin(a) * 0.04)
				k.cylinder(top, tip, 0.004, 0.004, MeshKit.lin(Color("c8d68a"), 0.8), 3, false)
				k.sphere(tip, Vector3.ONE * 0.01, MeshKit.lin(Color("d9894a"), 0.8), 2, 4)
		_:
			# Flat flowers: a back ring of petals and a lighter front ring between them.
			var count: int = {"pansy": 5, "cosmos": 8, "windflower": 6, "mum": 12}.get(species, 6)
			var length: float = {"pansy": 0.11, "cosmos": 0.12, "windflower": 0.1, "mum": 0.09}.get(species, 0.1)
			var width: float = {"pansy": 0.12, "cosmos": 0.06, "windflower": 0.08, "mum": 0.035}.get(species, 0.07)
			var tilt: float = {"pansy": 0.3, "cosmos": 0.15, "windflower": 0.25, "mum": 0.55}.get(species, 0.2)
			for i in count:
				var a := turn + TAU * i / count
				k.leaf(top, Vector3(cos(a), tilt, sin(a)), length, width, c, 0.0)
			if species in ["mum", "cosmos"]:
				for i in count:
					var a := turn + TAU * (i + 0.5) / count
					k.leaf(top + Vector3(0, 0.008, 0), Vector3(cos(a), tilt + 0.35, sin(a)), length * 0.75, width * 0.9, light, 0.0)
			var middle := centre_col
			if species in ["pansy", "windflower"]:
				middle = MeshKit.lin(Color("3a2b3a"), 0.8)
			k.sphere(top + Vector3(0, 0.012, 0), Vector3(0.03, 0.02, 0.03), middle, 3, 6)


## A single picked flower with a leaf, for wearing in your hair.
static func _hair_flower(k: MeshKit, id: String) -> void:
	var def := ItemDB.get_item(id)
	var c := MeshKit.lin(ItemDB.color_of(id))
	k.leaf(Vector3.ZERO, Vector3(-1, 0.2, -0.6), 0.1, 0.05, MeshKit.lin(Color("7cbb5c")), 0.0)
	k.leaf(Vector3.ZERO, Vector3(-0.6, -0.4, -1), 0.09, 0.05, MeshKit.lin(Color("5a9a46")), 0.0)
	bloom(k, Vector3.ZERO, def.get("species", "pansy"), c, 1)


## A bud vase with one picked flower in it.
static func _vase_flower(k: MeshKit, id: String) -> void:
	var def := ItemDB.get_item(id)
	var glass := MeshKit.lin(Color("bfe3ef"))
	k.cylinder(Vector3.ZERO, Vector3(0, 0.1, 0), 0.06, 0.07, glass, 10, true)
	k.cylinder(Vector3(0, 0.1, 0), Vector3(0, 0.17, 0), 0.07, 0.03, glass, 10, false)
	k.cylinder(Vector3(0, 0.17, 0), Vector3(0, 0.2, 0), 0.03, 0.035, glass, 10, false)
	k.cylinder(Vector3(0, 0.08, 0), Vector3(0.02, 0.36, 0), 0.008, 0.008, MeshKit.lin(Color("5f9e45")), 4, false)
	k.leaf(Vector3(0.01, 0.24, 0), Vector3(1, 0.7, 0.2), 0.08, 0.04, MeshKit.lin(Color("7cbb5c")), 0.0)
	bloom(k, Vector3(0.02, 0.36, 0), def.get("species", "pansy"), MeshKit.lin(ItemDB.color_of(id)), 2)


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


## A little cottage: cream walls with timber trim, a tiled roof, round windows, a
## chimney and a front door with a step.
static func _house(k: MeshKit, wall_col: Color = Color("fbf0d9"), roof_col: Color = Color("e0857a"),
		door_col: Color = Color("9fd3c7")) -> void:
	var w := 1.3
	var d := 1.15
	var eave := 1.45
	var top := 2.6
	var wall := MeshKit.lin(wall_col)
	var trim := MeshKit.lin(PLANK_DARK)
	var roof := MeshKit.lin(roof_col)
	var roof_dark := MeshKit.lin(roof_col.darkened(0.12))
	var glass := MeshKit.lin(Color("a9d7e6"))
	k.box(Vector3(0, 0.08, 0), Vector3(w * 2 + 0.12, 0.16, d * 2 + 0.12), MeshKit.lin(Color("c9bfb0")))
	k.box(Vector3(0, eave * 0.5 + 0.08, 0), Vector3(w * 2, eave, d * 2), wall)
	# Timber corners and a beam under the roof.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(sx * w, eave * 0.5 + 0.08, sz * d), Vector3(0.1, eave, 0.1), trim)
	k.box(Vector3(0, eave + 0.08, d), Vector3(w * 2 + 0.1, 0.1, 0.1), trim)
	# Gable ends.
	for sz: float in [-1.0, 1.0]:
		var n := Vector3(0, 0, sz)
		var a := k.vertex(Vector3(-w, eave + 0.08, sz * d), n, wall)
		var b := k.vertex(Vector3(w, eave + 0.08, sz * d), n, wall)
		var c := k.vertex(Vector3(0, top, sz * d), n, wall)
		k.tri(a, b, c, n)
	# Roof: two slopes with rows of tiles, overhanging a little.
	var over := 0.22
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx * (top - eave), w, 0).normalized()
		var rows := 5
		for i in rows:
			var t0 := float(i) / rows
			var t1 := float(i + 1) / rows
			var lo := Vector3(sx * (w + over), eave - 0.08, 0).lerp(Vector3(0, top + 0.06, 0), t0)
			var hi := Vector3(sx * (w + over), eave - 0.08, 0).lerp(Vector3(0, top + 0.06, 0), t1)
			var z := d + over
			k.flat_quad(lo + Vector3(0, 0, -z), lo + Vector3(0, 0, z), hi + Vector3(0, 0, z), hi + Vector3(0, 0, -z), n,
				roof if i % 2 == 0 else roof_dark)
	k.cylinder(Vector3(0, top + 0.04, -d - over), Vector3(0, top + 0.04, d + over), 0.07, 0.07, roof_dark, 6, true)
	# Chimney.
	k.box(Vector3(0.65, top - 0.1, -0.35), Vector3(0.28, 0.75, 0.28), MeshKit.lin(Color("c9bfb0")))
	k.box(Vector3(0.65, top + 0.3, -0.35), Vector3(0.34, 0.08, 0.34), MeshKit.lin(Color("b3a99a")))
	# Door with a little roof, step and knob.
	var front := d + 0.01
	k.box(Vector3(0, 0.6, front), Vector3(0.62, 1.04, 0.05), MeshKit.lin(door_col))
	k.box(Vector3(0, 0.6, front + 0.005), Vector3(0.7, 1.12, 0.03), trim)
	k.sphere(Vector3(0.2, 0.58, front + 0.05), Vector3.ONE * 0.04, MeshKit.lin(Color("f4d672")), 3, 6)
	k.box(Vector3(0, 0.1, front + 0.22), Vector3(0.9, 0.12, 0.38), MeshKit.lin(Color("c9bfb0")))
	k.box(Vector3(0, 1.3, front + 0.18), Vector3(0.95, 0.06, 0.4), roof_dark)
	# Round windows either side of the door, and on the sides.
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * 0.78, 0.92, front + 0.01)
		k.cylinder(c, c + Vector3(0, 0, 0.04), 0.27, 0.27, trim, 14, true)
		k.cylinder(c + Vector3(0, 0, 0.02), c + Vector3(0, 0, 0.05), 0.21, 0.21, glass, 14, true)
		k.box(c + Vector3(0, 0, 0.055), Vector3(0.42, 0.035, 0.01), trim)
		k.box(c + Vector3(0, 0, 0.055), Vector3(0.035, 0.42, 0.01), trim)
		# Flower box under each front window.
		k.box(c + Vector3(0, -0.34, 0.08), Vector3(0.5, 0.12, 0.14), MeshKit.lin(PLANK))
		for f in 3:
			k.sphere(c + Vector3(-0.15 + f * 0.15, -0.25, 0.1), Vector3.ONE * 0.06, MeshKit.lin([Color("f2a7a0"), Color("f6d58c"), Color("c6b2ea")][f], 0.4), 3, 6)
		var side := Vector3(sx * (w + 0.01), 0.95, 0)
		k.box(side, Vector3(0.05, 0.5, 0.5), trim)
		k.box(side + Vector3(sx * 0.02, 0, 0), Vector3(0.04, 0.4, 0.4), glass)


## The island office: a striped marquee with a leaf sign over the entrance.
static func _office(k: MeshKit) -> void:
	var w := 1.75
	var d := 1.2
	var eave := 1.35
	var top := 2.75
	var ridge := 0.55
	var coral := MeshKit.lin(Color("f2a091"))
	var cream := MeshKit.lin(CREAM)
	var canvas := MeshKit.lin(Color("fbefd6"))
	var dark := MeshKit.lin(Color("8d6f66"))
	var pole := MeshKit.lin(PLANK_DARK)
	# Canvas walls.
	k.box(Vector3(0, eave * 0.5, 0), Vector3(w * 2.0, eave, d * 2.0), canvas)
	# Striped hip roof: front and back trapezoids, triangular ends.
	var strips := 8
	for side: float in [1.0, -1.0]:
		var n := Vector3(0, d, side * (top - eave)).normalized()
		for i in strips:
			var t0 := float(i) / strips
			var t1 := float(i + 1) / strips
			var a := Vector3(lerpf(-w, w, t0), eave, side * d) + Vector3(0, 0, side * 0.12)
			var b := Vector3(lerpf(-w, w, t1), eave, side * d) + Vector3(0, 0, side * 0.12)
			var c := Vector3(lerpf(-ridge, ridge, t1), top, 0)
			var e := Vector3(lerpf(-ridge, ridge, t0), top, 0)
			k.flat_quad(a, b, c, e, n, coral if i % 2 == 0 else cream)
	for side: float in [1.0, -1.0]:
		var n := Vector3(side * (top - eave), w - ridge, 0).normalized()
		for i in 4:
			var t0 := float(i) / 4
			var t1 := float(i + 1) / 4
			var a := Vector3(side * (w + 0.12), eave, lerpf(-d - 0.12, d + 0.12, t0))
			var b := Vector3(side * (w + 0.12), eave, lerpf(-d - 0.12, d + 0.12, t1))
			var c := Vector3(side * ridge, top, 0)
			var ia := k.vertex(a, n, cream if i % 2 == 0 else coral)
			var ib := k.vertex(b, n, cream if i % 2 == 0 else coral)
			var ic := k.vertex(c, n, cream if i % 2 == 0 else coral)
			k.tri(ia, ib, ic, n)
	# Scalloped valance round the eaves.
	var scallops := 9
	for i in scallops:
		var x := lerpf(-w, w, (i + 0.5) / scallops)
		k.sphere(Vector3(x, eave - 0.02, d + 0.13), Vector3(w / scallops, 0.13, 0.03), coral if i % 2 == 0 else cream, 3, 8)
	# Entrance: dark doorway, tied-back flaps, a little step.
	var dz := d + 0.01
	k.flat_quad(Vector3(-0.42, 0, dz), Vector3(0.42, 0, dz), Vector3(0.42, 1.05, dz), Vector3(-0.42, 1.05, dz), Vector3.BACK, dark)
	for s: float in [-1.0, 1.0]:
		var f0 := k.vertex(Vector3(s * 0.42, 0, dz + 0.01), Vector3.BACK, coral)
		var f1 := k.vertex(Vector3(s * 0.6, 0, dz + 0.01), Vector3.BACK, coral)
		var f2 := k.vertex(Vector3(s * 0.6, 1.2, dz + 0.01), Vector3.BACK, coral)
		var f3 := k.vertex(Vector3(s * 0.2, 1.2, dz + 0.01), Vector3.BACK, coral)
		k.quad(f0, f1, f2, f3, Vector3.BACK)
		k.sphere(Vector3(s * 0.52, 0.55, dz + 0.04), Vector3(0.06, 0.05, 0.04), cream, 3, 6)
	k.box(Vector3(0, 0.03, d + 0.25), Vector3(1.0, 0.06, 0.4), MeshKit.lin(PLANK))
	# Leaf sign on two posts above the door.
	for s: float in [-1.0, 1.0]:
		k.cylinder(Vector3(s * 0.55, eave - 0.1, d + 0.2), Vector3(s * 0.55, top - 0.25, d + 0.2), 0.035, 0.035, pole, 5)
	k.rounded_box(Vector3(0, eave + 0.55, d + 0.26), Vector3(1.25, 0.5, 0.08), cream, 0.15)
	var leaf := MeshKit.lin(Color("7cbf6a"))
	k.leaf(Vector3(-0.1, eave + 0.36, d + 0.32), Vector3(0.75, 1.0, 0.0), 0.44, 0.3, leaf)
	k.leaf(Vector3(-0.1, eave + 0.36, d + 0.32), Vector3(-0.7, 0.8, 0.0), 0.3, 0.2, MeshKit.lin(Color("9ad68a")))
	# Corner poles, a pennant on top and guy pegs.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cylinder(Vector3(sx * (w + 0.06), 0, sz * (d + 0.06)), Vector3(sx * (w + 0.06), eave + 0.05, sz * (d + 0.06)), 0.045, 0.04, pole, 5)
	k.cylinder(Vector3(0, top - 0.1, 0), Vector3(0, top + 0.45, 0), 0.04, 0.035, pole, 5)
	var flag := MeshKit.lin(Color("9fd3c7"), 0.8)
	var fa := k.vertex(Vector3(0, top + 0.45, 0), Vector3.BACK, flag)
	var fb := k.vertex(Vector3(0.38, top + 0.36, 0), Vector3.BACK, flag)
	var fc := k.vertex(Vector3(0, top + 0.27, 0), Vector3.BACK, flag)
	k.tri(fa, fb, fc, Vector3.BACK)
	k.tri(fa, fc, fb, Vector3.FORWARD)


## Lucy's shop: a timber shopfront with a striped awning over an open counter, crates
## of fruit outside and an acorn sign.
static func _lucy_shop(k: MeshKit) -> void:
	var w := 1.85
	var d := 1.3
	var wall_h := 1.6
	var plank := MeshKit.lin(PLANK)
	var plank_dark := MeshKit.lin(PLANK_DARK)
	var cream := MeshKit.lin(CREAM)
	var green := MeshKit.lin(Color("8fc58a"))
	var roof := MeshKit.lin(Color("e0857a"))
	var roof_dark := MeshKit.lin(Color("c86c64"))
	k.box(Vector3(0, 0.06, 0), Vector3(w * 2 + 0.1, 0.12, d * 2 + 0.1), MeshKit.lin(Color("c9bfb0")))
	# Board walls round the back and sides.
	k.box(Vector3(0, wall_h * 0.5 + 0.12, -d + 0.06), Vector3(w * 2, wall_h, 0.12), plank)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * (w - 0.06), wall_h * 0.5 + 0.12, 0), Vector3(0.12, wall_h, d * 2), plank)
	for i in 9:
		var x := lerpf(-w + 0.2, w - 0.2, i / 8.0)
		k.box(Vector3(x, wall_h * 0.5 + 0.12, -d + 0.125), Vector3(0.02, wall_h, 0.01), plank_dark)
	# Shelves of goods behind the counter.
	for y: float in [0.75, 1.2]:
		k.box(Vector3(0, y, -d + 0.3), Vector3(w * 2 - 0.4, 0.05, 0.36), plank_dark)
		for i in 7:
			var x := lerpf(-w + 0.45, w - 0.45, i / 6.0)
			var col: Color = [Color("f2a7a0"), Color("9fd3c7"), Color("f6d58c"), Color("c6b2ea")][(i + int(y * 10)) % 4]
			if i % 2 == 0:
				k.cylinder(Vector3(x, y + 0.025, -d + 0.3), Vector3(x, y + 0.2, -d + 0.3), 0.07, 0.07, MeshKit.lin(col), 8, true, cream)
			else:
				k.box(Vector3(x, y + 0.1, -d + 0.3), Vector3(0.16, 0.16, 0.16), MeshKit.lin(col), MeshKit.lin(col.lightened(0.2)))
	# The counter across the open front.
	k.box(Vector3(0, 0.5, d - 0.25), Vector3(w * 2 - 0.3, 0.76, 0.4), green)
	k.box(Vector3(0, 0.9, d - 0.25), Vector3(w * 2 - 0.2, 0.06, 0.5), plank, MeshKit.lin(Color("eccaa2")))
	k.box(Vector3(0, 0.5, d - 0.04), Vector3(0.5, 0.4, 0.02), cream)
	k.sphere(Vector3(-0.9, 0.98, d - 0.2), Vector3(0.1, 0.06, 0.1), MeshKit.lin(Color("f6d58c")), 4, 8)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * (w - 0.08), (wall_h + 0.4) * 0.5 + 0.12, d - 0.08), Vector3(0.14, wall_h + 0.4, 0.14), plank_dark)
	# Gable roof.
	var eave := wall_h + 0.12
	var top := eave + 0.8
	var over := 0.2
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx * (top - eave), w, 0).normalized()
		for i in 4:
			var t0 := float(i) / 4
			var t1 := float(i + 1) / 4
			var lo := Vector3(sx * (w + over), eave, 0).lerp(Vector3(0, top, 0), t0)
			var hi := Vector3(sx * (w + over), eave, 0).lerp(Vector3(0, top, 0), t1)
			var z := d + over
			k.flat_quad(lo + Vector3(0, 0, -z), lo + Vector3(0, 0, z), hi + Vector3(0, 0, z), hi + Vector3(0, 0, -z), n, roof if i % 2 == 0 else roof_dark)
	for sz: float in [-1.0, 1.0]:
		var n := Vector3(0, 0, sz)
		var a := k.vertex(Vector3(-w, eave, sz * d), n, plank)
		var b := k.vertex(Vector3(w, eave, sz * d), n, plank)
		var c := k.vertex(Vector3(0, top, sz * d), n, plank)
		k.tri(a, b, c, n)
	# A striped awning sloping out over the counter, with a scalloped edge.
	var strips := 8
	var awn_n := Vector3(0, 0.6, 0.35).normalized()
	for i in strips:
		var x0 := lerpf(-w, w, float(i) / strips)
		var x1 := lerpf(-w, w, float(i + 1) / strips)
		k.flat_quad(Vector3(x0, eave - 0.05, d), Vector3(x1, eave - 0.05, d), Vector3(x1, eave - 0.4, d + 0.6), Vector3(x0, eave - 0.4, d + 0.6),
			awn_n, green if i % 2 == 0 else cream)
		k.sphere(Vector3((x0 + x1) * 0.5, eave - 0.42, d + 0.6), Vector3((x1 - x0) * 0.5, 0.09, 0.03), green if i % 2 == 0 else cream, 3, 8)
	# The acorn sign on the gable.
	k.cylinder(Vector3(0, top - 0.42, d + 0.02), Vector3(0, top - 0.42, d + 0.06), 0.24, 0.24, cream, 16, true)
	k.sphere(Vector3(0, top - 0.47, d + 0.08), Vector3(0.1, 0.12, 0.04), MeshKit.lin(Color("b7864f")), 5, 8)
	k.sphere(Vector3(0, top - 0.36, d + 0.08), Vector3(0.12, 0.05, 0.045), MeshKit.lin(Color("7a5532")), 4, 8)
	# Crates of fruit either side of the front.
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * (w + 0.05), 0.12, d + 0.45)
		k.box(c + Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.4), plank, MeshKit.lin(Color("eccaa2")))
		var fruit := Color("e0453a") if sx < 0 else Color("f2922b")
		for i in 4:
			k.sphere(c + Vector3(-0.12 + (i % 2) * 0.24, 0.34, -0.08 + (i / 2) * 0.16), Vector3.ONE * 0.08, MeshKit.lin(fruit), 4, 7)


## Bramble's museum: a round canvas tent with a scalloped trim and a pennant, its flap
## tied open, a fish tank and a bug jar on a stand outside.
static func _museum_tent(k: MeshKit) -> void:
	var canvas := MeshKit.lin(Color("e8e0c8"))
	var green := MeshKit.lin(Color("8fa86f"))
	var green_dark := MeshKit.lin(Color("6f8a55"))
	var pole := MeshKit.lin(PLANK_DARK)
	k.cylinder(Vector3(0, 0, -0.1), Vector3(0, 0.08, -0.1), 1.55, 1.55, MeshKit.lin(Color("c9bfb0")), 20, true)
	# Round walls, then a cone roof in green and cream panels.
	k.cylinder(Vector3(0, 0.08, -0.1), Vector3(0, 1.2, -0.1), 1.35, 1.35, canvas, 18, false)
	var panels := 12
	for i in panels:
		var a0 := TAU * i / panels
		var a1 := TAU * (i + 1) / panels
		var p0 := Vector3(cos(a0) * 1.5, 1.2, sin(a0) * 1.5 - 0.1)
		var p1 := Vector3(cos(a1) * 1.5, 1.2, sin(a1) * 1.5 - 0.1)
		var tip := Vector3(0, 2.45, -0.1)
		var n := ((p0 + p1) * 0.5 - Vector3(0, 0, -0.1)).normalized() + Vector3(0, 0.9, 0)
		var col := green if i % 2 == 0 else canvas
		var ia := k.vertex(p0, n.normalized(), col)
		var ib := k.vertex(p1, n.normalized(), col)
		var ic := k.vertex(tip, n.normalized(), col)
		k.tri(ia, ib, ic, n)
		k.sphere((p0 + p1) * 0.5 - Vector3(0, 0.04, 0), Vector3(0.38, 0.1, 0.38) * Vector3(1, 1, 1), green_dark if i % 2 == 0 else canvas, 3, 8)
	k.cylinder(Vector3(0, 2.3, -0.1), Vector3(0, 2.85, -0.1), 0.035, 0.03, pole, 5)
	var flag := MeshKit.lin(Color("f6d58c"), 0.8)
	var fa := k.vertex(Vector3(0, 2.85, -0.1), Vector3.BACK, flag)
	var fb := k.vertex(Vector3(0.36, 2.76, -0.1), Vector3.BACK, flag)
	var fc := k.vertex(Vector3(0, 2.67, -0.1), Vector3.BACK, flag)
	k.tri(fa, fb, fc, Vector3.BACK)
	k.tri(fa, fc, fb, Vector3.FORWARD)
	# The doorway with its flaps tied back.
	var dz := 1.26
	k.flat_quad(Vector3(-0.4, 0.08, dz), Vector3(0.4, 0.08, dz), Vector3(0.3, 1.1, dz), Vector3(-0.3, 1.1, dz), Vector3.BACK, MeshKit.lin(Color("5a4a40")))
	for s: float in [-1.0, 1.0]:
		var f0 := k.vertex(Vector3(s * 0.4, 0.08, dz + 0.02), Vector3.BACK, green)
		var f1 := k.vertex(Vector3(s * 0.62, 0.08, dz - 0.02), Vector3.BACK, green)
		var f2 := k.vertex(Vector3(s * 0.32, 1.12, dz + 0.02), Vector3.BACK, green)
		k.tri(f0, f1, f2, Vector3.BACK)
		k.sphere(Vector3(s * 0.48, 0.55, dz + 0.04), Vector3(0.05, 0.04, 0.03), MeshKit.lin(Color("f6d58c")), 3, 6)
	# A stand outside with a fish tank and a bug jar.
	var stand := Vector3(1.25, 0.08, 1.05)
	k.box(stand + Vector3(0, 0.3, 0), Vector3(0.7, 0.06, 0.4), MeshKit.lin(PLANK), MeshKit.lin(Color("eccaa2")))
	for sx: float in [-1.0, 1.0]:
		k.box(stand + Vector3(sx * 0.3, 0.14, 0), Vector3(0.05, 0.28, 0.32), pole)
	k.box(stand + Vector3(-0.14, 0.47, 0), Vector3(0.3, 0.26, 0.24), MeshKit.lin(Color("a9dce6")), MeshKit.lin(Color("c9edf2")))
	k.sphere(stand + Vector3(-0.16, 0.47, 0.12), Vector3(0.06, 0.03, 0.01), MeshKit.lin(Color("f2922b")), 3, 6)
	k.cylinder(stand + Vector3(0.18, 0.33, 0), stand + Vector3(0.18, 0.58, 0), 0.09, 0.08, MeshKit.lin(Color("dff3e8")), 10, true, MeshKit.lin(Color("c19a6e")))
	k.leaf(stand + Vector3(0.18, 0.38, 0.0), Vector3(0.2, 1, 0.3), 0.14, 0.06, MeshKit.lin(Color("7cbb5c")))


## A staked-out plot waiting for a neighbour: string between corner stakes, a little
## sign, and a pile of planks.
static func _plot(k: MeshKit) -> void:
	var stake := MeshKit.lin(PLANK_DARK)
	var string := MeshKit.lin(Color("f6f1e0"))
	var corners := [Vector3(-1.3, 0, -1.15), Vector3(1.3, 0, -1.15), Vector3(1.3, 0, 1.15), Vector3(-1.3, 0, 1.15)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		k.cylinder(a, a + Vector3(0, 0.45, 0), 0.04, 0.035, stake, 5, true)
		k.cylinder(a + Vector3(0, 0.38, 0), b + Vector3(0, 0.38, 0), 0.008, 0.008, string, 3, false)
	k.cylinder(Vector3(0, 0, 1.25), Vector3(0, 0.8, 1.25), 0.035, 0.035, stake, 5, true)
	k.box(Vector3(0, 0.8, 1.27), Vector3(0.6, 0.36, 0.05), MeshKit.lin(Color("fbf0d9")))
	k.sphere(Vector3(0, 0.82, 1.3), Vector3(0.1, 0.1, 0.02), MeshKit.lin(Color("e0857a")), 3, 8)
	for i in 4:
		k.box(Vector3(-0.6, 0.05 + i * 0.07, -0.3 + (i % 2) * 0.05), Vector3(0.9, 0.06, 0.18), MeshKit.lin(PLANK if i % 2 == 0 else PLANK_DARK))


## The museum: a stone hall with columns, steps, a pediment with a leaf emblem and
## banners either side of tall doors.
static func _museum(k: MeshKit) -> void:
	var stone := MeshKit.lin(Color("e8e2d6"))
	var stone_dark := MeshKit.lin(Color("cfc6b6"))
	var roof := MeshKit.lin(Color("8fa86f"))
	var w := 1.9
	var d := 1.3
	var wall_h := 1.9
	k.box(Vector3(0, 0.07, 0), Vector3(w * 2 + 0.2, 0.14, d * 2 + 0.2), stone_dark)
	k.box(Vector3(0, 0.2, d + 0.12), Vector3(1.6, 0.12, 0.3), stone_dark, stone)
	k.box(Vector3(0, 0.14 + wall_h * 0.5, -0.05), Vector3(w * 2 - 0.2, wall_h, d * 2 - 0.3), stone)
	# Columns along the front under a deep cornice.
	for i in 6:
		var x := lerpf(-w + 0.15, w - 0.15, i / 5.0)
		k.cylinder(Vector3(x, 0.14, d - 0.05), Vector3(x, 0.14 + wall_h, d - 0.05), 0.12, 0.1, stone, 10, false)
		k.box(Vector3(x, 0.2, d - 0.05), Vector3(0.3, 0.12, 0.3), stone_dark)
		k.box(Vector3(x, 0.1 + wall_h, d - 0.05), Vector3(0.3, 0.1, 0.3), stone_dark)
	var top := 0.14 + wall_h
	k.box(Vector3(0, top + 0.1, 0), Vector3(w * 2 + 0.2, 0.2, d * 2 + 0.1), stone_dark, stone)
	# A low green roof and a triangular pediment over the front.
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx * 0.6, w, 0).normalized()
		k.flat_quad(Vector3(sx * (w + 0.12), top + 0.2, -d - 0.08), Vector3(sx * (w + 0.12), top + 0.2, d + 0.08),
			Vector3(0, top + 0.9, d + 0.08), Vector3(0, top + 0.9, -d - 0.08), n, roof)
	var pn := Vector3.BACK
	var pa := k.vertex(Vector3(-w - 0.1, top + 0.2, d + 0.09), pn, stone)
	var pb := k.vertex(Vector3(w + 0.1, top + 0.2, d + 0.09), pn, stone)
	var pc := k.vertex(Vector3(0, top + 0.88, d + 0.09), pn, stone)
	k.tri(pa, pb, pc, pn)
	k.leaf(Vector3(-0.05, top + 0.36, d + 0.11), Vector3(0.7, 1, 0.0), 0.32, 0.2, MeshKit.lin(Color("7cbb5c")))
	k.leaf(Vector3(-0.05, top + 0.36, d + 0.11), Vector3(-0.8, 0.6, 0.0), 0.22, 0.14, MeshKit.lin(Color("9ad68a")))
	# Tall doors and banners.
	k.box(Vector3(0, 0.75, d - 0.17), Vector3(0.8, 1.2, 0.06), MeshKit.lin(Color("7a5532")))
	k.cylinder(Vector3(0, 1.35, d - 0.15), Vector3(0, 1.35, d - 0.12), 0.4, 0.4, MeshKit.lin(Color("7a5532")), 14, true)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(sx * 1.05, 1.15, d - 0.14), Vector3(0.36, 0.9, 0.03), roof)
		k.sphere(Vector3(sx * 1.05, 1.2, d - 0.12), Vector3(0.1, 0.1, 0.02), MeshKit.lin(Color("f6d58c")), 3, 8)


## A museum exhibit: a fish in a tank on a stand, or a bug under a glass dome on a
## plinth. With no creature, an empty stand with a little card.
static func _exhibit(k: MeshKit, kind: String, id: String) -> void:
	var wood := MeshKit.lin(Color("a07858"))
	var stone := MeshKit.lin(Color("dcd4c4"))
	var card := MeshKit.lin(Color("fbf6ea"))
	if kind == "tank":
		k.box(Vector3(0, 0.25, 0), Vector3(0.8, 0.5, 0.7), wood, MeshKit.lin(Color("b48b66")))
		if id == "":
			k.box(Vector3(0, 0.55, 0.3), Vector3(0.3, 0.12, 0.02), card)
			return
		# Open at the front so the fish shows: blue water behind, a frame round it.
		var water := MeshKit.lin(Color("9fd3e0"))
		k.box(Vector3(0, 0.82, -0.31), Vector3(0.78, 0.6, 0.04), water)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.37, 0.82, 0), Vector3(0.04, 0.6, 0.66), MeshKit.lin(Color("c9edf2")))
		var frame := MeshKit.lin(Color("6f8a95"))
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0, 1.13, sz * 0.32), Vector3(0.8, 0.04, 0.04), frame)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.38, 1.13, 0), Vector3(0.04, 0.04, 0.68), frame)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.39, 0.82, 0.32), Vector3(0.03, 0.62, 0.03), frame)
		k.box(Vector3(0, 0.53, 0), Vector3(0.74, 0.05, 0.62), MeshKit.lin(Color("e6d6b0")))
		for i in 3:
			k.leaf(Vector3(-0.25 + i * 0.22, 0.55, -0.2), Vector3(0.1, 1, 0), 0.3 - i * 0.04, 0.07, MeshKit.lin(Color("7cbb5c"), 0.6))
		var length: float = CreatureModels.SIZES.get(ItemDB.fish.get(id, {}).get("size", "small"), 0.2)
		k.xform = Transform3D(Basis(Vector3.UP, 0.35).scaled(Vector3.ONE * clampf(0.5 / length, 1.2, 2.6)), Vector3(0, 0.72, 0.05))
		CreatureModels.build(k, id)
		k.xform = Transform3D.IDENTITY
	else:
		k.cylinder(Vector3.ZERO, Vector3(0, 0.6, 0), 0.25, 0.22, stone, 12, true)
		k.cylinder(Vector3(0, 0.6, 0), Vector3(0, 0.65, 0), 0.28, 0.28, stone, 12, true)
		if id == "":
			k.box(Vector3(0, 0.67, 0.12), Vector3(0.22, 0.06, 0.1), card)
			return
		k.cylinder(Vector3(0, 0.65, 0), Vector3(-0.02, 0.8, 0.02), 0.012, 0.008, wood, 4, false)
		k.leaf(Vector3(-0.02, 0.78, 0.02), Vector3(0.6, 0.4, 0.3), 0.14, 0.08, MeshKit.lin(Color("7cbb5c")))
		k.xform = Transform3D(Basis().scaled(Vector3.ONE * 2.6), Vector3(0, 0.82, 0.02))
		CreatureModels.build(k, id)
		k.xform = Transform3D.IDENTITY
		# A wire dome over it.
		var wire := MeshKit.lin(Color("c8ccd2"))
		for i in 3:
			var a := PI * i / 3.0
			var prev := Vector3(cos(a), 0, sin(a)) * 0.24 + Vector3(0, 0.65, 0)
			for j in range(1, 7):
				var t := PI * j / 6.0
				var p := Vector3(cos(a) * cos(t) * 0.24, 0.65 + sin(t) * 0.32, sin(a) * cos(t) * 0.24)
				k.cylinder(prev, p, 0.008, 0.008, wire, 3, false)
				prev = p
		k.sphere(Vector3(0, 0.98, 0), Vector3.ONE * 0.025, wire, 3, 5)


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

## A piece of clothing on its own (for icons), in its colours.
static func _clothing(k: MeshKit, id: String) -> void:
	var P := CharacterParts
	var look := Appearance.DEFAULT.duplicate()
	look.merge(ItemDB.get_item(id).get("wear", {}), true)
	var slot: String = ItemDB.get_item(id).get("slot", "top")
	var keys: Array = ItemDB.SLOT_KEYS[slot]
	var a := Appearance.color(look, keys[1])
	var b := Appearance.color(look, keys[2]) if keys[2] != "" else a.lightened(0.5)
	match slot:
		"top":
			var t := P.top(look["top"])
			_append(k, t["torso"], Transform3D.IDENTITY, a, b)
			for sx: float in [-1.0, 1.0]:
				var shoulder := P.SHOULDER * Vector3(sx, 1, 1)
				# Arms held a little out, like on a hanger.
				var arm := Transform3D(Basis(Vector3.BACK, sx * 0.35), shoulder)
				if t["sleeve"]:
					_append(k, t["sleeve"], arm, a, b)
				if t["cuff"]:
					_append(k, t["cuff"], arm * Transform3D(Basis(), Vector3(0, -P.ARM_UPPER, 0)), a, b)
		"bottom":
			var bt := P.bottom(look["bottom"])
			_append(k, bt["hips"], Transform3D.IDENTITY, a, b)
			for sx: float in [-1.0, 1.0]:
				var hip := Transform3D(Basis(), Vector3(sx * P.LEG_X, P.HIP_Y, 0))
				if bt["leg"]:
					_append(k, bt["leg"], hip, a, b)
				if bt["shin"]:
					_append(k, bt["shin"], hip * Transform3D(Basis(), Vector3(0, -P.LEG_UPPER, 0)), a, b)
		"shoes":
			for sx: float in [-1.0, 1.0]:
				_append(k, P.shoe(look["shoes"]), Transform3D(Basis(), Vector3(sx * 0.11, P.LEG_LOWER, 0)), a, b)
		"hat":
			_append(k, P.hat(look["hat"]), Transform3D.IDENTITY, a, b)


## Copies a character part into this kit, turning its colour codes (see CharacterParts)
## into real colours: the second colour on trim, shaded a touch where marked.
static func _append(k: MeshKit, mesh: ArrayMesh, xform: Transform3D, a: Color, b: Color) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base := k.verts.size()
	for i in verts.size():
		var code := colours[i]
		var c := (b if code.g < 0.5 else a) * Color(code.r, code.r, code.r)
		k.verts.append(xform * verts[i])
		k.normals.append((xform.basis * normals[i]).normalized())
		k.colours.append(Color(c.r, c.g, c.b, 0.0))
		k.uvs.append(Vector2.ZERO)
	for idx in indices:
		k.indices.append(base + idx)


static func _drop(k: MeshKit, item: String) -> void:
	var def := ItemDB.get_item(item)
	var col := MeshKit.lin(ItemDB.color_of(item))
	match def.get("category", ""):
		"fish", "bug":
			CreatureModels.build(k, item)
			return
		"clothing":
			# A neatly folded bundle tied with a ribbon.
			k.rounded_box(Vector3(0, 0.07, 0), Vector3(0.36, 0.14, 0.28), col, 0.4)
			k.box(Vector3(0, 0.08, 0), Vector3(0.05, 0.16, 0.3), MeshKit.lin(Color("fff4e0")))
			return
		"fruit":
			k.sphere(Vector3(0, 0.15, 0), Vector3.ONE * 0.15, col, 5, 8, 0.3)
			k.leaf(Vector3(0, 0.3, 0), Vector3(1, 0.4, 0), 0.14, 0.08, MeshKit.lin(Color("5c9e46")))
			return
		"interior":
			var look: Dictionary = def["interior"]
			if look["part"] == "window":
				# Curtains, folded up with their tie-back.
				var fab: Array = def["build"]["variant"]["fabric"]
				k.rounded_box(Vector3(0, 0.06, 0), Vector3(0.4, 0.12, 0.3), MeshKit.lin(Color(fab[0])), 0.4)
				k.box(Vector3(0, 0.07, 0), Vector3(0.06, 0.14, 0.32), MeshKit.lin(Color(fab[1])))
				return
			var a := MeshKit.lin(Color(look["a"]))
			var b := MeshKit.lin(Color(look["b"]))
			if look["part"] == "wall":
				# A roll of wallpaper with its end unrolled a little.
				k.cylinder(Vector3(-0.22, 0.1, 0), Vector3(0.22, 0.1, 0), 0.1, 0.1, a, 10, true, b)
				k.box(Vector3(0, 0.012, 0.16), Vector3(0.42, 0.02, 0.18), b, a)
			else:
				# A little stack of floor tiles in its two colours.
				for i in 4:
					var x := (i % 2) * 0.2 - 0.1
					var z := (i / 2) * 0.2 - 0.1
					k.box(Vector3(x, 0.04, z), Vector3(0.19, 0.08, 0.19), a if (i == 0 or i == 3) else b)
				k.box(Vector3(0, 0.12, 0), Vector3(0.18, 0.06, 0.18), a)
			return
		"flower":
			# A little posy: three stems fanning out from a ribbon.
			var species: String = def.get("species", "pansy")
			for i in 3:
				var tip := Vector3((i - 1) * 0.09, 0.3 - absf(i - 1) * 0.04, (i % 2) * 0.03)
				k.cylinder(Vector3(0, 0.0, 0), tip, 0.012, 0.012, MeshKit.lin(Color("5f9e45")), 4, false)
				bloom(k, tip, species, col, i)
			k.cylinder(Vector3(0, 0.08, 0), Vector3(0, 0.11, 0), 0.03, 0.03, MeshKit.lin(Color("fff4e0")), 6, true)
			return
		"flower_plant":
			# A whole plant with a ball of soil round its roots.
			k.sphere(Vector3(0, 0.08, 0), Vector3(0.14, 0.1, 0.14), MeshKit.lin(Color("8a6650")), 5, 8, 0.3, 0.2, 3)
			k.xform = Transform3D(Basis.from_scale(Vector3.ONE * 0.7), Vector3(0, 0.12, 0))
			_flower_clump(k, def.get("species", "pansy"), def.get("flower_color", "red"))
			k.xform = Transform3D.IDENTITY
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
		"message_bottle":
			k.xform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.1, 0))
			k.cylinder(Vector3(0, -0.16, 0), Vector3(0, 0.08, 0), 0.09, 0.09, MeshKit.lin(Color("bfe6ec")), 10, true)
			k.cylinder(Vector3(0, 0.08, 0), Vector3(0, 0.17, 0), 0.06, 0.035, MeshKit.lin(Color("bfe6ec")), 8, false)
			k.cylinder(Vector3(0, 0.16, 0), Vector3(0, 0.22, 0), 0.04, 0.04, MeshKit.lin(Color("c19a6e")), 6, true)
			k.box(Vector3(0, -0.04, 0), Vector3(0.1, 0.16, 0.02), MeshKit.lin(Color("fff4e0")))
			k.xform = Transform3D.IDENTITY
		"acorn_pouch":
			k.sphere(Vector3(0, 0.15, 0), Vector3(0.17, 0.16, 0.17), col, 5, 8, 0.35)
			k.sphere(Vector3(0, 0.31, 0), Vector3(0.07, 0.05, 0.07), MeshKit.lin(Color("8a5e34")), 3, 6)
			k.sphere(Vector3(0, 0.15, 0.15), Vector3(0.06, 0.07, 0.03), MeshKit.lin(Color("6b4a2b")), 3, 6)
		"customisation_kit":
			# A paint pot with a drip, a brush and a little roll of fabric.
			k.cylinder(Vector3(-0.06, 0, 0), Vector3(-0.06, 0.18, 0), 0.1, 0.1, MeshKit.lin(Color("dfe3ea")), 12, true, MeshKit.lin(Color("f2a7a0")))
			k.box(Vector3(-0.06, 0.12, 0.095), Vector3(0.05, 0.1, 0.02), MeshKit.lin(Color("f2a7a0")))
			k.cylinder(Vector3(-0.1, 0.17, -0.02), Vector3(0.04, 0.34, -0.06), 0.015, 0.015, MeshKit.lin(Color("c19a6e")), 5)
			k.cylinder(Vector3(0.12, 0.06, 0.06), Vector3(0.12, 0.06, -0.14), 0.06, 0.06, MeshKit.lin(Color("9fd3c7")), 10, true, MeshKit.lin(Color("fff4e0")))
		"iron_nugget", "gold_nugget":
			k.sphere(Vector3(0, 0.09, 0), Vector3(0.13, 0.1, 0.12), col, 3, 5, 0.3, 0.4, 5)
		_:
			# Generic parcel, like a wrapped leaf.
			k.leaf(Vector3(-0.15, 0.05, 0.0), Vector3(1, 0.2, 0), 0.32, 0.26, MeshKit.lin(Color("9bbf5a")))


static func _tool(k: MeshKit, item: String) -> void:
	var handle := MeshKit.lin(Color("c19a6e"))
	var head := MeshKit.lin(ItemDB.color_of(item).lightened(0.15))
	match ItemDB.tool_type(item):
		"axe":
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.55, 0), 0.03, 0.028, handle, 5)
			k.box(Vector3(0.09, 0.47, 0), Vector3(0.16, 0.14, 0.04), head)
		"shovel":
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.6, 0), 0.028, 0.028, handle, 5)
			k.box(Vector3(0, 0.72, 0), Vector3(0.18, 0.22, 0.03), head)
		"rod":
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.9, 0), 0.025, 0.012, handle, 5)
			k.cylinder(Vector3(0.03, 0.05, 0), Vector3(0.03, 0.08, 0), 0.04, 0.04, MeshKit.lin(Color("7d8790")), 8, true)
			k.sphere(Vector3(0, 0.9, 0), Vector3.ONE * 0.016, MeshKit.lin(Color("e0453a")), 3, 5)
		"net":
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.62, 0), 0.025, 0.025, handle, 5)
			k.xform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.78, 0))
			k.cylinder(Vector3(0, -0.01, 0), Vector3(0, 0.01, 0), 0.17, 0.17, MeshKit.lin(Color("c8ccd2")), 14, false)
			k.xform = Transform3D.IDENTITY
			k.sphere(Vector3(0, 0.78, -0.08), Vector3(0.15, 0.15, 0.12), MeshKit.lin(Color("f4f0e6"), 0.3), 5, 10)
		_:
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.5, 0), 0.03, 0.03, handle, 5)
