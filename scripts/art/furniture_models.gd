class_name FurnitureModels
extends RefCounted
## Procedural furniture. Each model is centred on its footprint, sits on y = 0 and faces
## +Z (towards the camera). Width runs along X, depth along Z, in tiles.

const WOOD := Color("d4a77e")
const WOOD_DARK := Color("b08463")
const WOOD_LIGHT := Color("eccaa2")
const STONE := Color("c4bfd0")
const STONE_DARK := Color("a8a2b8")
const CLAY := Color("e09a72")
const CLAY_DARK := Color("c47a58")
const IRON := Color("7d8790")
const CREAM := Color("fff4e0")
const GLOW := Color("ffe7a3")
const SOIL := Color("8a6650")


static func build(k: MeshKit, id: String) -> void:
	match id:
		"workbench": _workbench(k)
		"wooden_stool": _stool(k)
		"wooden_chair": _chair(k)
		"wooden_table": _table(k)
		"log_bench": _log_bench(k)
		"stump_table": _stump_table(k)
		"wooden_box": _box(k)
		"wooden_shelf": _shelf(k)
		"simple_bed": _bed(k)
		"barrel": _barrel(k)
		"firewood_pile": _firewood(k)
		"campfire": _campfire(k)
		"stone_lantern": _stone_lantern(k)
		"stone_stool": _stone_stool(k)
		"flower_pot": _flower_pot(k)
		"clay_vase": _vase(k)
		"garden_lantern": _garden_lantern(k)
		"wooden_fence": _fence(k)
		"signpost": _signpost(k)
		"mailbox": _mailbox(k)
		"birdhouse": _birdhouse(k)
		"iron_bench": _iron_bench(k)
		"garden_well": _well(k)
		_:
			k.box(Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), c(Color.MAGENTA))


static func c(col: Color, sway: float = 0.0) -> Color:
	return MeshKit.lin(col, sway)


static func _legs(k: MeshKit, half: Vector2, top: float, r: float, col: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.cylinder(Vector3(sx * half.x, 0, sz * half.y), Vector3(sx * half.x, top, sz * half.y), r, r, c(col), 6, true)


static func _workbench(k: MeshKit) -> void:
	k.box(Vector3(0, 0.74, 0), Vector3(1.8, 0.12, 0.78), c(WOOD), c(WOOD_LIGHT))
	_legs(k, Vector2(0.8, 0.3), 0.68, 0.06, WOOD_DARK)
	k.box(Vector3(0, 0.22, 0), Vector3(1.6, 0.06, 0.6), c(WOOD_DARK))
	# Tools on top: a vice, a hammer, a saw and a pot of nails.
	k.box(Vector3(-0.65, 0.88, 0.05), Vector3(0.22, 0.16, 0.22), c(IRON))
	k.box(Vector3(-0.65, 0.98, 0.05), Vector3(0.3, 0.04, 0.08), c(IRON))
	k.cylinder(Vector3(-0.15, 0.82, 0.15), Vector3(0.15, 0.82, 0.05), 0.025, 0.025, c(WOOD_DARK), 6)
	k.box(Vector3(0.17, 0.84, 0.04), Vector3(0.08, 0.06, 0.16), c(IRON))
	k.box(Vector3(0.5, 0.81, -0.12), Vector3(0.5, 0.02, 0.16), c(Color("c8ccd2")))
	k.cylinder(Vector3(0.7, 0.8, 0.18), Vector3(0.7, 0.92, 0.18), 0.07, 0.08, c(CLAY), 10)
	# Pegboard at the back.
	k.box(Vector3(0, 1.15, -0.35), Vector3(1.6, 0.7, 0.05), c(WOOD_LIGHT))
	for i in 3:
		k.cylinder(Vector3(-0.5 + i * 0.5, 1.25, -0.33), Vector3(-0.5 + i * 0.5, 1.0, -0.3), 0.02, 0.02, c(IRON), 4)


static func _stool(k: MeshKit) -> void:
	k.cylinder(Vector3(0, 0.4, 0), Vector3(0, 0.48, 0), 0.26, 0.26, c(WOOD), 14, true, c(WOOD_LIGHT))
	for i in 3:
		var a := TAU * i / 3.0
		k.cylinder(Vector3(cos(a) * 0.22, 0, sin(a) * 0.22), Vector3(cos(a) * 0.14, 0.41, sin(a) * 0.14), 0.035, 0.03, c(WOOD_DARK), 6)


static func _chair(k: MeshKit) -> void:
	k.box(Vector3(0, 0.44, 0.02), Vector3(0.55, 0.08, 0.5), c(WOOD), c(WOOD_LIGHT))
	_legs(k, Vector2(0.22, 0.2), 0.42, 0.035, WOOD_DARK)
	for s: float in [-1.0, 1.0]:
		k.cylinder(Vector3(s * 0.22, 0.44, -0.2), Vector3(s * 0.22, 1.0, -0.2), 0.035, 0.035, c(WOOD_DARK), 6)
	k.box(Vector3(0, 0.96, -0.2), Vector3(0.52, 0.12, 0.05), c(WOOD))
	# A heart cut-out on the backrest.
	k.box(Vector3(0, 0.7, -0.2), Vector3(0.4, 0.3, 0.04), c(WOOD))
	for s: float in [-1.0, 1.0]:
		k.sphere(Vector3(s * 0.04, 0.74, -0.17), Vector3(0.05, 0.05, 0.02), c(Color("f29a96")), 4, 8)
	k.cone(Vector3(0, 0.73, -0.17), Vector3(0, 0.63, -0.17), 0.075, c(Color("f29a96")), 4)


static func _table(k: MeshKit) -> void:
	k.box(Vector3(0, 0.7, 0), Vector3(1.75, 0.1, 0.82), c(WOOD), c(WOOD_LIGHT))
	_legs(k, Vector2(0.75, 0.32), 0.66, 0.05, WOOD_DARK)
	k.box(Vector3(0, 0.25, 0), Vector3(1.5, 0.05, 0.06), c(WOOD_DARK))


static func _log_bench(k: MeshKit) -> void:
	k.cylinder(Vector3(-0.85, 0.36, 0), Vector3(0.85, 0.36, 0), 0.2, 0.2, c(WOOD_DARK), 12, true, c(WOOD_LIGHT))
	k.box(Vector3(0, 0.5, 0), Vector3(1.66, 0.06, 0.34), c(WOOD), c(WOOD_LIGHT))
	for s: float in [-1.0, 1.0]:
		k.cylinder(Vector3(s * 0.6, 0, 0), Vector3(s * 0.6, 0.24, 0), 0.13, 0.12, c(WOOD_DARK), 8, true, c(WOOD_LIGHT))


static func _stump_table(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.55, 0), 0.36, 0.33, c(WOOD_DARK), 14, true, c(WOOD_LIGHT))
	k.cylinder(Vector3(0, 0.555, 0), Vector3(0, 0.56, 0), 0.2, 0.2, c(WOOD), 14, true)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		k.cylinder(Vector3(cos(a) * 0.25, 0.15, sin(a) * 0.25), Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45), 0.09, 0.05, c(WOOD_DARK), 6)


static func _box(k: MeshKit) -> void:
	k.box(Vector3(0, 0.33, 0), Vector3(0.66, 0.66, 0.66), c(WOOD), c(WOOD_LIGHT))
	for y in [0.12, 0.54]:
		k.box(Vector3(0, y, 0), Vector3(0.68, 0.07, 0.68), c(WOOD_DARK))
	k.box(Vector3(0, 0.33, 0), Vector3(0.08, 0.6, 0.68), c(WOOD_DARK))


static func _shelf(k: MeshKit) -> void:
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.38, 0.55, -0.12), Vector3(0.05, 1.1, 0.36), c(WOOD_DARK))
	for y in [0.04, 0.42, 0.78, 1.1]:
		k.box(Vector3(0, y, -0.12), Vector3(0.8, 0.05, 0.36), c(WOOD), c(WOOD_LIGHT))
	k.box(Vector3(0, 0.55, -0.29), Vector3(0.76, 1.08, 0.03), c(WOOD_LIGHT))
	# Little things on the shelves.
	var books := [Color("f28e7e"), Color("78a6dc"), Color("f4d672"), Color("aadfc8")]
	for i in books.size():
		k.box(Vector3(-0.28 + i * 0.07, 0.56, -0.12), Vector3(0.06, 0.24 - (i % 2) * 0.04, 0.22), c(books[i]))
	k.sphere(Vector3(0.18, 0.54, -0.1), Vector3(0.1, 0.1, 0.1), c(CLAY), 6, 10)
	k.sphere(Vector3(-0.12, 0.9, -0.1), Vector3(0.09, 0.08, 0.09), c(Color("8cc67f"), 0.3), 5, 8)
	k.cylinder(Vector3(-0.12, 0.8, -0.1), Vector3(-0.12, 0.86, -0.1), 0.07, 0.08, c(CLAY), 8)


static func _bed(k: MeshKit) -> void:
	k.box(Vector3(0, 0.2, 0), Vector3(1.2, 0.3, 1.8), c(WOOD), c(WOOD_LIGHT))
	k.box(Vector3(0, 0.55, -0.88), Vector3(1.26, 1.0, 0.1), c(WOOD_DARK))
	k.box(Vector3(0, 0.35, 0.88), Vector3(1.26, 0.5, 0.08), c(WOOD_DARK))
	k.rounded_box(Vector3(0, 0.42, -0.62), Vector3(0.9, 0.18, 0.36), c(CREAM), 0.5)
	# Patchwork quilt in squares.
	var patches := [Color("f6aac4"), Color("aed4f2"), Color("f4d672"), Color("aadfc8")]
	for row in 4:
		for col in 3:
			var col_colour: Color = patches[(row + col) % patches.size()]
			k.box(Vector3(-0.38 + col * 0.38, 0.4, -0.28 + row * 0.33), Vector3(0.38, 0.1, 0.33), c(col_colour))


static func _barrel(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.38, 0), 0.27, 0.33, c(WOOD), 14, true)
	k.cylinder(Vector3(0, 0.38, 0), Vector3(0, 0.76, 0), 0.33, 0.27, c(WOOD), 14, true, c(WOOD_LIGHT))
	for y in [0.12, 0.64]:
		k.cylinder(Vector3(0, y, 0), Vector3(0, y + 0.05, 0), 0.305, 0.31, c(IRON), 14, false)


static func _firewood(k: MeshKit) -> void:
	var rows := [[-0.24, 0.0, 0.24], [-0.12, 0.12], [0.0]]
	for r in rows.size():
		for z in rows[r]:
			var y := 0.11 + r * 0.19
			k.cylinder(Vector3(-0.38, y, z), Vector3(0.38, y, z), 0.11, 0.11, c(WOOD_DARK), 8, true, c(WOOD_LIGHT))


static func _campfire(k: MeshKit) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		k.sphere(Vector3(cos(a) * 0.3, 0.07, sin(a) * 0.3), Vector3(0.11, 0.08, 0.1), c(STONE_DARK), 4, 7, 0.3, 0.2, i)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		k.cylinder(Vector3(cos(a) * 0.2, 0.02, sin(a) * 0.2), Vector3(0, 0.35, 0), 0.035, 0.025, c(WOOD_DARK), 5)
	k.cone(Vector3(0, 0.05, 0), Vector3(0, 0.55, 0), 0.17, c(Color("f2a660"), 0.6), 8)
	k.cone(Vector3(0, 0.05, 0.02), Vector3(0.02, 0.4, 0.04), 0.1, c(Color("ffe08a"), 0.8), 7)


static func _stone_lantern(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.1, 0), 0.28, 0.26, c(STONE_DARK), 8, true)
	k.cylinder(Vector3(0, 0.1, 0), Vector3(0, 0.52, 0), 0.1, 0.09, c(STONE), 8)
	k.cylinder(Vector3(0, 0.52, 0), Vector3(0, 0.6, 0), 0.22, 0.22, c(STONE_DARK), 8, true)
	k.cylinder(Vector3(0, 0.6, 0), Vector3(0, 0.86, 0), 0.16, 0.16, c(STONE), 8, true)
	k.cylinder(Vector3(0, 0.64, 0), Vector3(0, 0.82, 0), 0.165, 0.165, c(GLOW), 4, false)
	k.cylinder(Vector3(0, 0.86, 0), Vector3(0, 1.04, 0), 0.34, 0.06, c(STONE_DARK), 8, true)
	k.sphere(Vector3(0, 1.07, 0), Vector3.ONE * 0.06, c(STONE), 4, 6)


static func _stone_stool(k: MeshKit) -> void:
	k.sphere(Vector3(0, 0.2, 0), Vector3(0.3, 0.22, 0.28), c(STONE), 6, 12, 0.3, 0.12, 7)


static func _flower_pot(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.34, 0), 0.18, 0.24, c(CLAY), 14, true)
	k.cylinder(Vector3(0, 0.3, 0), Vector3(0, 0.38, 0), 0.26, 0.26, c(CLAY_DARK), 14, true)
	k.cylinder(Vector3(0, 0.37, 0), Vector3(0, 0.385, 0), 0.22, 0.22, c(SOIL), 12, true)


static func _vase(k: MeshKit) -> void:
	k.sphere(Vector3(0, 0.28, 0), Vector3(0.24, 0.26, 0.24), c(CLAY), 10, 14)
	k.cylinder(Vector3(0, 0.45, 0), Vector3(0, 0.62, 0), 0.09, 0.08, c(CLAY), 10, false)
	k.cylinder(Vector3(0, 0.6, 0), Vector3(0, 0.66, 0), 0.12, 0.12, c(CLAY_DARK), 10, true)
	k.cylinder(Vector3(0, 0.24, 0), Vector3(0, 0.32, 0), 0.245, 0.245, c(Color("78a6dc")), 14, false)


static func _garden_lantern(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 1.1, 0), 0.05, 0.045, c(WOOD_DARK), 6)
	k.box(Vector3(0, 1.22, 0), Vector3(0.28, 0.3, 0.28), c(IRON))
	k.box(Vector3(0, 1.22, 0), Vector3(0.22, 0.24, 0.3), c(GLOW))
	k.box(Vector3(0, 1.22, 0), Vector3(0.3, 0.24, 0.22), c(GLOW))
	k.cone(Vector3(0, 1.37, 0), Vector3(0, 1.55, 0), 0.24, c(IRON), 4)


static func _fence(k: MeshKit) -> void:
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.44, 0.38, 0), Vector3(0.1, 0.76, 0.1), c(WOOD))
		k.cone(Vector3(s * 0.44, 0.76, 0), Vector3(s * 0.44, 0.86, 0), 0.07, c(WOOD), 4)
	for y in [0.25, 0.55]:
		k.box(Vector3(0, y, -0.03), Vector3(0.9, 0.07, 0.04), c(WOOD_DARK))
	for i in 3:
		var x := -0.22 + i * 0.22
		k.box(Vector3(x, 0.33, 0.0), Vector3(0.09, 0.66, 0.04), c(WOOD_LIGHT))
		k.cone(Vector3(x, 0.66, 0.0), Vector3(x, 0.74, 0.0), 0.06, c(WOOD_LIGHT), 4)


static func _signpost(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 1.2, 0), 0.05, 0.05, c(WOOD_DARK), 6)
	for i in 2:
		var y := 0.95 - i * 0.28
		var s := 1.0 if i == 0 else -1.0
		var board := WOOD_LIGHT if i == 0 else Color("aed4f2")
		k.box(Vector3(s * 0.15, y, 0.06), Vector3(0.5, 0.18, 0.04), c(board))
		k.xform = Transform3D(Basis(Vector3.BACK, -PI * 0.5 * s), Vector3(s * 0.4, y, 0.06))
		k.cone(Vector3(0, -0.02, 0), Vector3(0, 0.1, 0), 0.13, c(board), 3)
		k.xform = Transform3D.IDENTITY


static func _mailbox(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.75, 0), 0.05, 0.05, c(WOOD_DARK), 6)
	k.box(Vector3(0, 0.82, 0), Vector3(0.46, 0.18, 0.3), c(Color("7fbcd8")))
	k.cylinder(Vector3(-0.23, 0.91, 0), Vector3(0.23, 0.91, 0), 0.15, 0.15, c(Color("7fbcd8")), 12, true)
	k.box(Vector3(0.05, 0.98, 0.17), Vector3(0.06, 0.2, 0.03), c(Color("dc5c58")))
	k.box(Vector3(0.1, 1.05, 0.17), Vector3(0.14, 0.08, 0.03), c(Color("dc5c58")))


static func _birdhouse(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 1.0, 0), 0.04, 0.04, c(WOOD_DARK), 6)
	k.box(Vector3(0, 1.15, 0), Vector3(0.3, 0.3, 0.3), c(Color("f2a6a0")))
	var roof := Color("78a6dc")
	for s: float in [-1.0, 1.0]:
		k.xform = Transform3D(Basis(Vector3.BACK, -s * 0.7), Vector3(s * 0.1, 1.38, 0))
		k.box(Vector3.ZERO, Vector3(0.28, 0.04, 0.38), c(roof))
	k.xform = Transform3D.IDENTITY
	k.cylinder(Vector3(0, 1.17, 0.15), Vector3(0, 1.17, 0.152), 0.06, 0.06, c(Color("4a3a3a")), 10, true)
	k.cylinder(Vector3(0, 1.06, 0.15), Vector3(0, 1.06, 0.24), 0.015, 0.015, c(WOOD_DARK), 4)


static func _iron_bench(k: MeshKit) -> void:
	for s: float in [-1.0, 1.0]:
		k.cylinder(Vector3(s * 0.8, 0, 0.2), Vector3(s * 0.8, 0.45, 0.15), 0.035, 0.035, c(IRON), 6)
		k.cylinder(Vector3(s * 0.8, 0, -0.2), Vector3(s * 0.8, 0.95, -0.25), 0.035, 0.035, c(IRON), 6)
		k.cylinder(Vector3(s * 0.8, 0.62, 0.2), Vector3(s * 0.8, 0.62, -0.22), 0.03, 0.03, c(IRON), 6)
	for i in 4:
		k.box(Vector3(0, 0.45, 0.15 - i * 0.11), Vector3(1.66, 0.04, 0.09), c(WOOD))
	for i in 3:
		k.box(Vector3(0, 0.62 + i * 0.12, -0.25), Vector3(1.66, 0.09, 0.04), c(WOOD))


static func _well(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.6, 0), 0.62, 0.6, c(STONE), 16, false)
	k.cylinder(Vector3(0, 0.55, 0), Vector3(0, 0.62, 0), 0.62, 0.62, c(STONE_DARK), 16, true)
	k.cylinder(Vector3(0, 0.62, 0), Vector3(0, 0.625, 0), 0.5, 0.5, c(Color("5f8fa8")), 16, true)
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(s * 0.55, 1.05, 0), Vector3(0.1, 1.0, 0.1), c(WOOD_DARK))
	k.cylinder(Vector3(-0.55, 1.3, 0), Vector3(0.55, 1.3, 0), 0.04, 0.04, c(WOOD), 6)
	for s: float in [-1.0, 1.0]:
		k.xform = Transform3D(Basis(Vector3.RIGHT, s * 0.7), Vector3(0, 1.55, s * 0.2))
		k.box(Vector3.ZERO, Vector3(1.3, 0.06, 0.52), c(Color("cc6c86")))
	k.xform = Transform3D.IDENTITY
	k.cylinder(Vector3(0.1, 1.3, 0), Vector3(0.1, 0.95, 0), 0.01, 0.01, c(WOOD_LIGHT), 4)
	k.cylinder(Vector3(0.1, 0.8, 0), Vector3(0.1, 0.95, 0), 0.08, 0.1, c(WOOD), 10, true)
