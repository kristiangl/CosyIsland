class_name Models
extends RefCounted
## Procedural models for everything on the island. Meshes are cached by key, e.g.
## "tree:2", "flower:tulip:red", "drop:wood".
##
## Everything uses one shared prop material and vertex colours, so the art style can be
## tuned in shaders/prop.gdshader and the palette constants below.

const BARK := Color("a87d62")
const BARK_LIGHT := Color("c19a7c")
const PALM_LEAF := Color("78bd7a")
const WOOD_END := Color("f6dcb4")
const FABRIC := Color("7fc6b8")
const FABRIC_DARK := Color("4f9488")
const CREAM := Color("fff6e4")
const PLANK := Color("d4a77e")
const PLANK_DARK := Color("b08463")
## The player's house before it's painted: cream walls, a coral roof and a mint door.
const HOUSE_WALL := Color("fbf0d9")
const HOUSE_ROOF := Color("e0857a")
const HOUSE_DOOR := Color("9fd3c7")

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
	if p[0] == "kaykit":
		# A model converted from KayKit by tools/kaykit_import.gd.
		var converted: ArrayMesh = load("res://assets/kaykit/%s.res" % p[1])
		_cache[key] = converted
		return converted
	if p[0] == "head":
		# A generated animal head (tools/head_import.gd), for checking it in the gallery.
		var head: ArrayMesh = load("res://assets/characters/heads/%s.res" % p[1])
		_cache[key] = head
		return head
	if p[0] == "festive_tree":
		var tree := _festive_tree()
		_cache[key] = tree
		return tree
	if p[0] == "series":
		var mesh := _series(p[1])
		_cache[key] = mesh
		return mesh
	match p[0]:
		"tree":
			k = _kit_from(TREES[int(p[1]) % TREES.size()])
		"fruit_tree":
			k = _kit_from(FRUIT_TREES[int(p[1]) % FRUIT_TREES.size()])
			_fruit_tree(k, p[2], int(p[3]))
		"palm":
			_palm(k, int(p[1]))
		"bush":
			k = _kit_from(BUSHES[int(p[1]) % BUSHES.size()])
		"rock":
			k = _kit_from(ROCKS[int(p[1]) % ROCKS.size()])
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
		"tailor_shop":
			# KayKit's tall cottage on its stone footing, in a tailor's lavender and cream.
			k = _kit_from("hex_home_b")
			Palette.repaint(k.colours, {"red": ["a58cc8", "bba4da", "d2c0ea"], "white": ["eee4dc", "f8f0ea", "fffaf4"]})
			_grow(k, PREBUILT_SCALE)
		"lucy_shop":
			# KayKit's market stall, its awning in Lucy's sunny yellow.
			k = _kit_from("hex_market")
			Palette.repaint(k.colours, {"yellow": ["e8b84f", "f2cc6a", "f8e0a0"], "white": ["eee6d6", "f8f2e6", "fffaf0"]})
			_grow(k, PREBUILT_SCALE)
		"museum_tent":
			_museum_tent(k)
		"museum":
			_museum(k)
		"exhibit":
			_exhibit(k, p[1] if p.size() > 1 else "tank", p[2] if p.size() > 2 else "")
		"house", "big_house":
			# The player's house, in its paint (wall, roof, door) if it's been painted.
			if p.size() >= 4:
				_house(k, Color(p[1]), Color(p[2]), Color(p[3]), p[0] == "big_house")
			else:
				_house(k, HOUSE_WALL, HOUSE_ROOF, HOUSE_DOOR, p[0] == "big_house")
		"nhouse":
			# A neighbour's house in their colours.
			# KayKit's timbered cottage, its roof and walls painted in their colours.
			var home: Dictionary = NpcData.get_character(p[1]).get("home", {})
			k = _kit_from("hex_home_a")
			Palette.repaint(k.colours, {"blue": _ramp(Color(home.get("roof", "e0857a"))), "white": _ramp(Color(home.get("wall", "fbf0d9")))})
			_grow(k, PREBUILT_SCALE)
		"fitting_mirror":
			_fitting_mirror(k)
		"clothes_rail":
			_clothes_rail(k)
		"mannequin":
			_mannequin(k)
		"plot":
			_plot(k)
		"dock":
			_dock(k)
		"site":
			_site(k, int(p[1]), int(p[2]), Color(p[3]))
		"bridge":
			_bridge(k, int(p[1]))
		"drop":
			_drop(k, p[1])
		"tool":
			if ItemDB.tool_type(p[1]) in ["axe", "shovel", "pickaxe"]:
				k = _kit_from("tool_" + ItemDB.tool_type(p[1]))
				_tint_metal(k, ItemDB.color_of(p[1]))
				if ItemDB.tool_type(p[1]) == "axe":
					# Held in the hand slot, KayKit's axe would swing with its blade trailing:
					# turn it about the handle so the edge leads.
					for i in k.verts.size():
						k.verts[i] = Vector3(-k.verts[i].x, k.verts[i].y, -k.verts[i].z)
						k.normals[i] = Vector3(-k.normals[i].x, k.normals[i].y, -k.normals[i].z)
			else:
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
	if spec.get("kaykit", "") != "":
		var kit := _kit_from(spec["kaykit"])
		Palette.repaint(kit.colours, spec["variant"].get("paint", {}))
		return kit.commit()
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
			return "tree:%d" % _pick(obj, TREES.size())
		"fruit_tree":
			return "fruit_tree:%d:%s:%d" % [_pick(obj, FRUIT_TREES.size()), obj["fruit"], obj.get("fruit_count", 0)]
		"palm":
			return "palm:%d" % obj.get("variant", 0)
		"rock":
			return "rock:%d" % _pick(obj, ROCKS.size())
		"bush":
			return "bush:%d" % _pick(obj, BUSHES.size())
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
			if obj.has("paint"):
				var paint: Dictionary = obj["paint"]
				return "%s:%s:%s:%s" % [ItemDB.placeable(obj["item"]).get("model", "house"), paint.get("wall", HOUSE_WALL.to_html(false)),
					paint.get("roof", HOUSE_ROOF.to_html(false)), paint.get("door", HOUSE_DOOR.to_html(false))]
			return ItemDB.placeable(obj["item"]).get("model", "drop:" + obj["item"])
	return "unknown"


## A dark-to-light ramp around one colour, for Palette.repaint.
static func _ramp(c: Color) -> Array:
	return [c.darkened(0.22).to_html(false), c.to_html(false), c.lightened(0.18).to_html(false)]


## Which of `count` models a tree or rock uses: its saved variant mixed with its uid, so
## neighbours differ.
static func _pick(obj: Dictionary, count: int) -> int:
	return (int(obj.get("uid", 0)) * 7 + int(obj.get("variant", 0))) % count


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


# --- Nature --------------------------------------------------------------------------

## Island trees and rocks, from KayKit's Forest Nature pack (tools/kaykit.json): cube
## cluster trees and pines, and faceted boulders.
const TREES := ["tree_2_a", "tree_2_b", "tree_2_c", "tree_2_d", "tree_2_e", "tree_4_a", "tree_4_b", "tree_4_c"]
## The cube trees with room on their canopy for fruit.
const FRUIT_TREES := ["tree_2_a", "tree_2_b", "tree_2_d", "tree_2_e"]
## Bushes: cube clusters and angular ones.
const BUSHES := ["bush_2_a", "bush_2_b", "bush_2_c", "bush_2_d", "bush_2_e", "bush_2_f", "bush_4_a", "bush_4_b", "bush_4_c", "bush_4_d", "bush_4_e", "bush_4_f"]
const ROCKS := ["rock_3_a", "rock_3_b", "rock_3_c", "rock_3_d", "rock_3_e", "rock_3_f", "rock_3_g", "rock_3_h"]


## A converted KayKit mesh as a MeshKit, to add more to it.
## The KayKit buildings (neighbours' houses, Lucy's stall, the tailors') a size up, so
## they stand as tall as the player's house.
const PREBUILT_SCALE := 1.2


## Scales a model about its base (the middle of its footprint, on the ground).
static func _grow(k: MeshKit, f: float) -> void:
	for i in k.verts.size():
		k.verts[i] *= f


static func _kit_from(name: String) -> MeshKit:
	var k := MeshKit.new()
	var mesh: ArrayMesh = load("res://assets/kaykit/%s.res" % name)
	var arrays := mesh.surface_get_arrays(0)
	k.verts = arrays[Mesh.ARRAY_VERTEX]
	k.normals = arrays[Mesh.ARRAY_NORMAL]
	k.colours = arrays[Mesh.ARRAY_COLOR]
	k.indices = arrays[Mesh.ARRAY_INDEX]
	k.uvs.resize(k.verts.size())
	return k


## A little fir dressed for the holidays: three tiers of branches, baubles round each
## tier and a star on top, the baubles and star in a glow surface to shine at night.
static func _festive_tree() -> ArrayMesh:
	var k := MeshKit.new()
	k.cylinder(Vector3.ZERO, Vector3(0, 0.35, 0), 0.08, 0.07, MeshKit.lin(BARK), 6, false)
	k.cylinder(Vector3(0, 0.0, 0), Vector3(0, 0.12, 0), 0.22, 0.2, MeshKit.lin(Color("c8574f")), 8, true)
	var greens := [Color("4f8a58"), Color("5f9e64"), Color("6aac72")]
	var glow := MeshKit.new()
	var baubles := [Color("e86a6a"), Color("f2c94c"), Color("7fa9e6"), Color("f4f0e6")]
	# Tier: [bottom, height, radius, baubles]
	var tiers := [[0.3, 0.75, 0.62, 7], [0.78, 0.62, 0.48, 6], [1.18, 0.55, 0.32, 4]]
	for t in tiers.size():
		var tier: Array = tiers[t]
		var y: float = tier[0]
		var r: float = tier[2]
		k.cone(Vector3(0, y, 0), Vector3(0, y + float(tier[1]), 0), r, MeshKit.lin(greens[t]), 10)
		for b in int(tier[3]):
			var a := TAU * b / float(tier[3]) + t * 0.7
			var at := Vector3(cos(a) * r * 0.82, y + 0.1, sin(a) * r * 0.82)
			glow.sphere(at, Vector3.ONE * 0.055, MeshKit.lin(baubles[(b + t) % baubles.size()]), 4, 6)
	var tip := 1.18 + 0.55
	var star := MeshKit.lin(Color("ffd95a"))
	for a in 5:
		var d := Vector3(cos(TAU * a / 5.0 + PI * 0.5), sin(TAU * a / 5.0 + PI * 0.5), 0)
		glow.cone(Vector3(0, tip + 0.1, 0), Vector3(0, tip + 0.1, 0) + d * 0.13, 0.05, star, 4)
	glow.sphere(Vector3(0, tip + 0.1, 0), Vector3.ONE * 0.05, star, 4, 6)
	var mesh := k.commit()
	mesh.set_meta("glow_surface", mesh.get_surface_count())
	glow.commit(mesh)
	return mesh


## A cube tree with fruit tucked into the sides of its canopy, spread round it at
## different heights.
static func _fruit_tree(k: MeshKit, fruit: String, fruit_count: int) -> void:
	if fruit_count <= 0:
		return
	var leaves: Array[int] = []
	var low := INF
	var high := -INF
	for i in k.verts.size():
		var c := k.colours[i]
		if c.g > c.r:
			leaves.append(i)
			low = minf(low, k.verts[i].y)
			high = maxf(high, k.verts[i].y)
	var fruit_col := MeshKit.lin(ItemDB.color_of(fruit), 1.0)
	var stem := MeshKit.lin(BARK, 1.0)
	for f in mini(fruit_count, 3):
		var dir := Vector3(cos(TAU * f / 3.0 + 0.5), 0, sin(TAU * f / 3.0 + 0.5))
		var y := lerpf(low, high, [0.3, 0.5, 0.4][f])
		# The leafy spot furthest out that way, near that height.
		var best := -1
		for i in leaves:
			if absf(k.verts[i].y - y) < (high - low) * 0.15 and (best < 0 or k.verts[i].dot(dir) > k.verts[best].dot(dir)):
				best = i
		if best < 0:
			continue
		var at := Vector3(k.verts[best].x, y, k.verts[best].z) - dir * 0.04
		k.sphere(at, Vector3.ONE * 0.16, fruit_col, 6, 9, 0.3)
		k.cylinder(at + Vector3(0, 0.13, 0), at + Vector3(0.02, 0.24, 0), 0.016, 0.011, stem, 4, false)


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
## chimney and a front door with a step. `tall` adds an upstairs with two windows.
static func _house(k: MeshKit, wall_col: Color = HOUSE_WALL, roof_col: Color = HOUSE_ROOF,
		door_col: Color = HOUSE_DOOR, tall := false) -> void:
	var w := 1.3
	var d := 1.15
	var eave := 1.45 if not tall else 2.5
	var top := 2.6 if not tall else 3.65
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
		if tall:
			# Upstairs: a square window over each round one, with shutters, a beam
			# between the floors, and a window in each side.
			var up := Vector3(sx * 0.62, 1.95, front + 0.01)
			k.box(up, Vector3(0.5, 0.52, 0.04), trim)
			k.box(up + Vector3(0, 0, 0.02), Vector3(0.4, 0.42, 0.04), glass)
			k.box(up + Vector3(0, 0, 0.045), Vector3(0.4, 0.035, 0.01), trim)
			k.box(up + Vector3(0, 0, 0.045), Vector3(0.035, 0.42, 0.01), trim)
			for shutter: float in [-1.0, 1.0]:
				k.box(up + Vector3(shutter * 0.34, 0, 0.01), Vector3(0.14, 0.52, 0.04), MeshKit.lin(door_col))
			k.box(side + Vector3(0, 1.05, 0), Vector3(0.05, 0.5, 0.5), trim)
			k.box(side + Vector3(sx * 0.02, 1.05, 0), Vector3(0.04, 0.4, 0.4), glass)
	if tall:
		k.box(Vector3(0, 1.52, d + 0.02), Vector3(w * 2 + 0.1, 0.09, 0.08), trim)


## A wooden rail two tiles long with shirts and dresses hanging from it, side on.
static func _clothes_rail(k: MeshKit) -> void:
	var wood := MeshKit.lin(PLANK_DARK)
	for sx: float in [-1.0, 1.0]:
		k.cylinder(Vector3(sx * 0.85, 0.0, 0), Vector3(sx * 0.85, 1.45, 0), 0.04, 0.04, wood, 6, true)
		k.box(Vector3(sx * 0.85, 0.03, 0), Vector3(0.1, 0.06, 0.45), wood)
	k.cylinder(Vector3(-0.88, 1.42, 0), Vector3(0.88, 1.42, 0), 0.025, 0.025, MeshKit.lin(Color("c8c0b8")), 6, true)
	var colours: Array[Color] = [Color("f2a7a0"), Color("9fd3c7"), Color("f6d58c"), Color("b9b3e6"), Color("f6c9c0"),
		Color("8fc58a"), Color("6a9ac8")]
	for i in colours.size():
		var x := -0.66 + i * 0.22
		var col := MeshKit.lin(colours[i])
		# A hanger, then a shirt (or a longer dress every third one) seen side on.
		k.cylinder(Vector3(x, 1.42, 0), Vector3(x, 1.33, 0), 0.01, 0.01, MeshKit.lin(Color("8a6b4f")), 4, false)
		var long := i % 3 == 1
		k.rounded_box(Vector3(x, 1.1 if not long else 0.98, 0), Vector3(0.07, 0.42 if not long else 0.66, 0.46), col, 0.3)
		k.box(Vector3(x, 1.27, 0), Vector3(0.06, 0.08, 0.6), col)


## A dressmaker's dummy on a stand, in a summer dress.
static func _mannequin(k: MeshKit) -> void:
	var wood := MeshKit.lin(PLANK_DARK)
	k.cylinder(Vector3(0, 0.0, 0), Vector3(0, 0.05, 0), 0.24, 0.24, wood, 12, true)
	k.cylinder(Vector3(0, 0.05, 0), Vector3(0, 0.7, 0), 0.03, 0.03, wood, 6, false)
	var dress := MeshKit.lin(Color("f2b8c8"))
	k.cylinder(Vector3(0, 0.62, 0), Vector3(0, 0.98, 0), 0.3, 0.16, dress, 12, true)
	k.rounded_box(Vector3(0, 1.12, 0), Vector3(0.34, 0.32, 0.22), MeshKit.lin(Color("f3e4c4")), 0.4)
	k.rounded_box(Vector3(0, 1.08, 0.01), Vector3(0.35, 0.22, 0.23), dress, 0.4)
	k.cylinder(Vector3(0, 1.28, 0), Vector3(0, 1.36, 0), 0.04, 0.04, wood, 6, false)
	k.sphere(Vector3(0, 1.4, 0), Vector3.ONE * 0.06, wood, 4, 8)
	# A sash and a flower.
	k.box(Vector3(0, 0.96, 0.0), Vector3(0.34, 0.05, 0.24), MeshKit.lin(Color("e0656b")))
	k.sphere(Vector3(0.1, 1.14, 0.12), Vector3.ONE * 0.04, MeshKit.lin(Color("fff4c8")), 3, 6)


## A tall oval mirror in a painted wooden frame on two feet, for the tailors.
static func _fitting_mirror(k: MeshKit) -> void:
	var frame := MeshKit.lin(Color("e8b8a8"))
	var wood := MeshKit.lin(PLANK_DARK)
	var glass := MeshKit.lin(Color("cfe8f0"))
	var centre := Vector3(0, 1.0, 0)
	var segments := 20
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		k.cylinder(centre + Vector3(cos(a0) * 0.32, sin(a0) * 0.62, 0), centre + Vector3(cos(a1) * 0.32, sin(a1) * 0.62, 0),
			0.05, 0.05, frame, 6, false)
	k.sphere(centre + Vector3(0, 0, 0.005), Vector3(0.3, 0.6, 0.02), glass, 8, 16)
	# A shine across the glass.
	k.box(centre + Vector3(-0.1, 0.18, 0.03), Vector3(0.05, 0.36, 0.01), MeshKit.lin(Color("ffffff")))
	k.box(centre + Vector3(-0.02, 0.26, 0.03), Vector3(0.03, 0.2, 0.01), MeshKit.lin(Color("ffffff")))
	for sx: float in [-1.0, 1.0]:
		k.cylinder(Vector3(sx * 0.3, 0.0, 0), Vector3(sx * 0.33, 0.95, 0), 0.04, 0.035, wood, 6, true)
		k.box(Vector3(sx * 0.3, 0.03, 0), Vector3(0.12, 0.06, 0.4), wood)
	k.sphere(centre + Vector3(0, 0.66, 0.02), Vector3.ONE * 0.06, frame, 4, 8)


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


## Marlow's ferry dock: a plank pier running out to sea from the beach (+Z), on posts,
## with his little sailing boat tied up alongside and a sign at the landward end.
static func _dock(k: MeshKit) -> void:
	var post := MeshKit.lin(PLANK_DARK)
	var top := 0.14
	for i in 19:
		var z := -0.85 + i * 0.3
		k.box(Vector3(0, top - 0.05, z), Vector3(1.3, 0.1, 0.27), MeshKit.lin(PLANK if i % 3 != 1 else Color("c99a72")))
	for z: float in [0.5, 2.0, 3.5, 4.55]:
		for sx: float in [-0.68, 0.68]:
			k.cylinder(Vector3(sx, -1.0, z), Vector3(sx, top + 0.22, z), 0.08, 0.08, post, 6, true)
	# A bollard with a rope out to the boat, and a ferry sign by the beach.
	k.cylinder(Vector3(0.5, top, 3.0), Vector3(0.5, top + 0.22, 3.0), 0.08, 0.1, MeshKit.lin(Color("6a7480")), 8, true)
	k.cylinder(Vector3(0.5, top + 0.16, 3.0), Vector3(1.05, 0.3, 3.2), 0.02, 0.02, MeshKit.lin(Color("efe2c0")), 4, false)
	k.cylinder(Vector3(-0.85, 0, -0.6), Vector3(-0.85, 1.25, -0.6), 0.045, 0.045, post, 5, true)
	k.box(Vector3(-0.85, 1.12, -0.57), Vector3(0.7, 0.4, 0.06), MeshKit.lin(Color("fbf0d9")))
	k.sphere(Vector3(-0.85, 1.13, -0.53), Vector3(0.12, 0.12, 0.02), MeshKit.lin(Color("6fa8d8")), 3, 8)
	_boat(k, Vector3(1.32, -0.12, 3.6))


## A little sailing boat, bow to +Z, sitting at `at` (its waterline).
static func _boat(k: MeshKit, at: Vector3) -> void:
	var hull := MeshKit.lin(Color("f6f1e6"))
	var stripe := MeshKit.lin(Color("e0857a"))
	var deck := MeshKit.lin(PLANK)
	var w := 0.5
	var lo := at.y - 0.2
	var hi := at.y + 0.35
	var back := at.z - 1.0
	var front := at.z + 0.7
	var bow := at.z + 1.35
	k.box(Vector3(at.x, (lo + hi) * 0.5, (back + front) * 0.5), Vector3(w * 2, hi - lo, front - back), hull)
	k.box(Vector3(at.x, hi - 0.1, (back + front) * 0.5), Vector3(w * 2 + 0.02, 0.08, front - back + 0.02), stripe)
	# The bow: two slanted sides meeting at a point, decked over.
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx * (bow - front), 0, w).normalized()
		k.flat_quad(Vector3(at.x + sx * w, lo, front), Vector3(at.x, lo, bow), Vector3(at.x, hi, bow), Vector3(at.x + sx * w, hi, front), n, hull)
	k.flat_quad(Vector3(at.x - w, hi, front), Vector3(at.x + w, hi, front), Vector3(at.x, hi, bow), Vector3(at.x, hi, bow), Vector3.UP, deck)
	k.box(Vector3(at.x, hi + 0.01, (back + front) * 0.5), Vector3(w * 2 - 0.12, 0.02, front - back - 0.12), deck)
	# A cabin at the stern, a mast and a striped sail.
	k.box(Vector3(at.x, hi + 0.25, back + 0.4), Vector3(0.75, 0.5, 0.6), MeshKit.lin(Color("9cc4e4")), MeshKit.lin(Color("e0857a")))
	k.box(Vector3(at.x, hi + 0.3, back + 0.71), Vector3(0.4, 0.18, 0.02), MeshKit.lin(Color("fbf6d8")))
	var mast := Vector3(at.x, hi, at.z + 0.25)
	k.cylinder(mast, mast + Vector3(0, 2.0, 0), 0.045, 0.035, MeshKit.lin(PLANK_DARK), 6, true)
	for i in 3:
		var y0 := 0.3 + i * 0.55
		var y1 := y0 + 0.55
		var z0 := 0.95 * (1.0 - (y0 - 0.3) / 1.65)
		var z1 := 0.95 * (1.0 - (y1 - 0.3) / 1.65)
		var c := MeshKit.lin(Color("fbf6ec") if i % 2 == 0 else Color("e0857a"))
		for sx: float in [-1.0, 1.0]:
			k.flat_quad(mast + Vector3(sx * 0.01, y0, 0.06), mast + Vector3(sx * 0.01, y0, 0.06 + z0),
				mast + Vector3(sx * 0.01, y1, 0.06 + z1), mast + Vector3(sx * 0.01, y1, 0.06), Vector3(sx, 0, 0), c)
	k.sphere(mast + Vector3(0, 2.05, 0), Vector3(0.06, 0.06, 0.06), MeshKit.lin(Color("f2c94c")), 3, 6)


## A building kit staked out and waiting to go up overnight: string round its
## footprint (w x d tiles), KayKit scaffolding at the back, a pile of timber and stone,
## and a sign in the building's colour by the door.
static func _site(k: MeshKit, w: int, d: int, colour: Color) -> void:
	var stake := MeshKit.lin(PLANK_DARK)
	var string := MeshKit.lin(Color("f6f1e0"))
	var hx := w * 0.5 - 0.2
	var hz := d * 0.5 - 0.35
	var corners := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		k.cylinder(a, a + Vector3(0, 0.45, 0), 0.04, 0.035, stake, 5, true)
		k.cylinder(a + Vector3(0, 0.38, 0), b + Vector3(0, 0.38, 0), 0.008, 0.008, string, 3, false)
	_paste(k, "hex_scaffolding", Transform3D(Basis().scaled(Vector3.ONE * 0.62), Vector3(-hx * 0.35, 0, -hz * 0.3)))
	_paste(k, "hex_stage_a", Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3.ONE * 0.42), Vector3(hx * 0.55, 0, hz * 0.35)))
	var sign_at := Vector3(-hx * 0.6, 0, hz + 0.1)
	k.cylinder(sign_at, sign_at + Vector3(0, 0.8, 0), 0.035, 0.035, stake, 5, true)
	k.box(sign_at + Vector3(0, 0.8, 0.02), Vector3(0.6, 0.36, 0.05), MeshKit.lin(Color("fbf0d9")))
	k.sphere(sign_at + Vector3(0, 0.82, 0.05), Vector3(0.1, 0.1, 0.02), MeshKit.lin(colour), 3, 8)


## Copies a converted KayKit mesh into this kit, moved by `xform`.
static func _paste(k: MeshKit, name: String, xform: Transform3D) -> void:
	var arrays := (load("res://assets/kaykit/%s.res" % name) as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var base := k.verts.size()
	for i in verts.size():
		k.verts.append(xform * verts[i])
		k.normals.append((xform.basis * normals[i]).normalized())
		k.colours.append(colours[i])
		k.uvs.append(Vector2.ZERO)
	for idx: int in arrays[Mesh.ARRAY_INDEX]:
		k.indices.append(base + idx)


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
		"tour_ticket":
			# A paper ticket with a sea-blue band and a little sail, tilted up to read.
			k.xform = Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.12, 0))
			k.box(Vector3(0, 0, 0), Vector3(0.36, 0.2, 0.015), MeshKit.lin(Color("fbf3e0")))
			k.box(Vector3(0, -0.05, 0.009), Vector3(0.36, 0.06, 0.004), MeshKit.lin(Color("6fa8d8")))
			k.flat_quad(Vector3(-0.1, -0.01, 0.012), Vector3(-0.02, -0.01, 0.012), Vector3(-0.06, 0.08, 0.012), Vector3(-0.06, 0.08, 0.012), Vector3.BACK, MeshKit.lin(Color("e0857a")))
			k.box(Vector3(0.09, 0.04, 0.009), Vector3(0.1, 0.02, 0.004), MeshKit.lin(Color("c8b89a")))
			k.box(Vector3(0.09, 0.0, 0.009), Vector3(0.1, 0.02, 0.004), MeshKit.lin(Color("c8b89a")))
			k.xform = Transform3D.IDENTITY
		"iron_nugget", "gold_nugget":
			k.sphere(Vector3(0, 0.09, 0), Vector3(0.13, 0.1, 0.12), col, 3, 5, 0.3, 0.4, 5)
		"bridge_kit":
			# A bundle of planks tied with rope.
			for i in 3:
				k.box(Vector3(0, 0.04 + i * 0.07, (i - 1) * 0.02), Vector3(0.42, 0.06, 0.12), MeshKit.lin(Color("c9a072") if i % 2 == 0 else Color("b98a5c")))
			for sx: float in [-1.0, 1.0]:
				k.box(Vector3(sx * 0.12, 0.12, 0), Vector3(0.03, 0.22, 0.16), MeshKit.lin(Color("dcc69c")))
		"incline_kit":
			# A little wedge of turf on a board.
			k.box(Vector3(0, 0.02, 0), Vector3(0.4, 0.04, 0.3), MeshKit.lin(Color("b98a5c")))
			k.flat_quad(Vector3(-0.18, 0.04, 0.13), Vector3(0.18, 0.04, 0.13), Vector3(0.18, 0.24, -0.13), Vector3(-0.18, 0.24, -0.13),
				Vector3(0, 0.8, 0.6).normalized(), MeshKit.lin(Color("8fbf73")))
			k.box(Vector3(0, 0.14, -0.13), Vector3(0.36, 0.2, 0.02), MeshKit.lin(Color("a08a6a")))
		_:
			# Generic parcel, like a wrapped leaf.
			k.leaf(Vector3(-0.15, 0.05, 0.0), Vector3(1, 0.2, 0), 0.32, 0.26, MeshKit.lin(Color("9bbf5a")))


## Gives a KayKit tool's metal (its blue-grey parts, not the wooden handle) the item's
## colour, keeping the shading.
static func _tint_metal(k: MeshKit, colour: Color) -> void:
	for i in k.colours.size():
		var c := k.colours[i]
		if c.s < 0.18 or (c.h > 0.4 and c.h < 0.75):
			var t := Color.from_hsv(colour.h, colour.s * 0.8, clampf(c.v * colour.v / 0.7, 0.0, 1.0))
			k.colours[i] = Color(t, c.a)


## A bug net's hoop and bag: the hoop opens towards +X (the way the hand swings it
## in the hand slot) and the bag trails behind, pale outside and shaded inside so you can
## see into it.
static func _net_head(k: MeshKit, centre: Vector3, r: float) -> void:
	var rim := MeshKit.lin(Color("9aa4ad"))
	var segments := 14
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		k.cylinder(centre + Vector3(0, cos(a0), sin(a0)) * r, centre + Vector3(0, cos(a1), sin(a1)) * r, 0.013, 0.013, rim, 4, false)
	var outside := MeshKit.lin(Color("f2f4f2"), 0.25)
	var inside := MeshKit.lin(Color("c4ced4"), 0.25)
	# Rings of the bag from the hoop back to a rounded tip.
	var rings := [[0.0, 1.0], [-0.1, 0.92], [-0.2, 0.72], [-0.28, 0.42], [-0.31, 0.0]]
	var rows: Array = []
	for ring: Array in rings:
		var row_out: Array[int] = []
		var row_in: Array[int] = []
		for i in segments:
			var ang := TAU * i / segments
			var dir := Vector3(0, cos(ang), sin(ang))
			var p := centre + Vector3(ring[0], 0, 0) + dir * r * float(ring[1])
			var n := (dir + Vector3(-0.6, 0, 0)).normalized()
			row_out.append(k.vertex(p, n, outside))
			row_in.append(k.vertex(p, -n, inside))
		rows.append([row_out, row_in])
	for j in rows.size() - 1:
		for i in segments:
			var i2 := (i + 1) % segments
			for side in 2:
				var a: Array[int] = rows[j][side]
				var b: Array[int] = rows[j + 1][side]
				var ang := TAU * (i + 0.5) / segments
				var out := (Vector3(0, cos(ang), sin(ang)) + Vector3(-0.6, 0, 0)).normalized()
				k.quad(a[i], a[i2], b[i2], b[i], out if side == 0 else -out)


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
			# The reel in the rod's own metal (iron, gold...).
			k.cylinder(Vector3(0.03, 0.05, 0), Vector3(0.03, 0.08, 0), 0.04, 0.04, head if not item.begins_with("flimsy") else MeshKit.lin(Color("7d8790")), 8, true)
			k.sphere(Vector3(0, 0.9, 0), Vector3.ONE * 0.016, MeshKit.lin(Color("e0453a")), 3, 5)
		"net":
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.62, 0), 0.025, 0.025, handle, 5)
			if not item.begins_with("flimsy"):
				# A metal collar where the hoop meets the handle.
				k.cylinder(Vector3(0, 0.56, 0), Vector3(0, 0.64, 0), 0.034, 0.034, head, 6, true)
			_net_head(k, Vector3(0, 0.79, 0), 0.17)
		"pole":
			# A long pole, taller than its owner, with painted bands.
			k.cylinder(Vector3(0, -0.45, 0), Vector3(0, 1.55, 0), 0.026, 0.022, head, 6)
			for y: float in [-0.35, 1.4]:
				k.cylinder(Vector3(0, y, 0), Vector3(0, y + 0.08, 0), 0.03, 0.03, MeshKit.lin(Color("e0685a")), 6)
		"cliff":
			# A chunky mattock with a painted head and a band round the handle.
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.62, 0), 0.03, 0.028, handle, 5)
			k.rounded_box(Vector3(0, 0.6, 0), Vector3(0.36, 0.09, 0.09), head, 0.4)
			k.box(Vector3(0.19, 0.6, 0), Vector3(0.05, 0.06, 0.07), MeshKit.lin(Color("8a8f99")))
			k.box(Vector3(-0.19, 0.6, 0), Vector3(0.05, 0.12, 0.06), MeshKit.lin(Color("8a8f99")))
			k.cylinder(Vector3(0, 0.2, 0), Vector3(0, 0.27, 0), 0.034, 0.034, MeshKit.lin(Color("e0685a")), 6)
		"water":
			# A spade with a rounded blue blade and a T grip.
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.6, 0), 0.028, 0.028, handle, 5)
			k.box(Vector3(0, -0.12, 0), Vector3(0.14, 0.03, 0.03), handle)
			k.rounded_box(Vector3(0, 0.74, 0), Vector3(0.2, 0.26, 0.035), head, 0.6)
			k.sphere(Vector3(0, 0.74, 0.025), Vector3(0.04, 0.05, 0.01), MeshKit.lin(Color("fbf3dc")), 3, 5)
		_:
			k.cylinder(Vector3(0, -0.1, 0), Vector3(0, 0.5, 0), 0.03, 0.03, handle, 5)
