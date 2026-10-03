class_name SeriesModels
extends RefCounted
## Furniture series pieces (data/furniture/*.json) built from a shared library of parts:
## legs, backs, cushions, drawers, headboards and shades. A piece is a kind ("chair") plus
## a few params ("back": "ladder") in a variant's colours, so one builder makes the same
## kind of piece for every series.
##
## Wood and painted parts go in the main kit (the prop material). Fabric goes in a second
## kit drawn with the cloth shader, so cushions, quilts and shades take the series print.
## Fabric vertex colours follow the cloth shader: red is brightness, green 0 is trim (plain
## second colour). Pieces are centred on their footprint, sit on y = 0 and face +Z.

const FABRIC := Color(1, 1, 1, 0)
const FABRIC_TRIM := Color(1, 0, 1, 0)
const ROPE := Color("dcc69c")
const IRON := Color("7d8790")
const GLOW := Color("ffe7a3")
const PILLOW := Color("fff8ec")
const BOOKS := [Color("f28e7e"), Color("78a6dc"), Color("f4d672"), Color("aadfc8"), Color("c6b2ea"), Color("f6aac4")]

var k: MeshKit
var f: MeshKit
## Parts that glow at night (a surface of their own).
var g: MeshKit
var glow: Color
## Window glass, if it has its own kit (rooms: it darkens at night).
var glass: MeshKit
var params: Dictionary
var wood: Color
var wood_light: Color
var trim: Color
var accent: Color
var log_end: Color
## Footprint in tiles (width, depth).
var size := Vector2.ONE


## A builder for one variant's colours, adding to `main` (wood) and `fabric`.
static func make(main: MeshKit, fabric: MeshKit, v: Dictionary, piece_params: Dictionary = {},
		glowing: MeshKit = null) -> SeriesModels:
	var s := SeriesModels.new()
	s.k = main
	s.f = fabric
	s.g = glowing if glowing else main
	s.glow = MeshKit.lin(Color(v.get("glow", "ffe7a3")))
	s.params = piece_params
	s.wood = MeshKit.lin(Color(v.get("wood", "d4a77e")))
	s.wood_light = s.wood.lightened(0.14)
	s.trim = MeshKit.lin(Color(v.get("trim", "b08463")))
	var fab: Array = v.get("fabric", ["fff4e0", "f2a7a0", "plain"])
	s.accent = MeshKit.lin(Color(v.get("accent", fab[1])))
	s.log_end = s.wood.lerp(Color("fbe8c8"), 0.55)
	s.log_end.a = 0.0
	return s


## Builds the piece described by an item's "build" entry (see ItemDB._load_furniture).
static func build(main: MeshKit, fabric: MeshKit, spec: Dictionary, glowing: MeshKit = null) -> void:
	var s := make(main, fabric, spec.get("variant", {}), spec.get("params", {}), glowing)
	var footprint: Array = spec.get("footprint", [1, 1])
	s.size = Vector2(footprint[0], footprint[1])
	match spec.get("kind", ""):
		"chair": s._chair()
		"stool": s._stool()
		"table": s._table()
		"side_table": s._side_table()
		"armchair": s._armchair(1)
		"sofa": s._armchair(2)
		"bed": s._bed()
		"dresser": s._dresser()
		"bookcase": s._bookcase()
		"floor_lamp": s._floor_lamp()
		"table_lamp": s._table_lamp()
		"bench": s._bench()
		"crate": s._crate()
		"rug": s._rug()
		"curtains":
			# A window dressed with the curtains, for icons.
			main.box(Vector3(0, 0.75, -0.06), Vector3(1.3, 1.5, 0.04), MeshKit.lin(Color("fbf0d9")))
			s.window(Vector3(0, 0.8, -0.04), Vector2(0.8, 0.75), true)
		_:
			main.box(Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), MeshKit.lin(Color.MAGENTA))


# --- Parts ---------------------------------------------------------------------------

## A leg from the floor (or a rail) up to whatever it holds.
func leg(from: Vector3, to: Vector3, style: String, r: float = 0.035) -> void:
	match style:
		"turned":
			var mid := from.lerp(to, 0.4)
			k.cylinder(from, mid, r * 0.75, r * 1.15, wood, 7, true)
			k.sphere(mid, Vector3(r * 1.55, r * 1.2, r * 1.55), wood, 3, 7)
			k.cylinder(mid, to, r * 1.15, r * 0.95, wood, 7, false)
		"plank":
			if is_equal_approx(from.x, to.x) and is_equal_approx(from.z, to.z):
				k.box((from + to) * 0.5, Vector3(r * 2.6, absf(to.y - from.y), r * 1.8), trim)
			else:
				k.cylinder(from, to, r * 1.3, r * 1.3, trim, 4, true)
		"branch":
			# Two crooked lengths with a knot where they meet.
			var kink := from.lerp(to, 0.5) + Vector3(r * 0.6, 0, -r * 0.4)
			k.cylinder(from, kink, r * 1.05, r * 0.95, trim, 6, false)
			k.cylinder(kink, to, r * 0.95, r * 0.85, trim, 6, true)
			k.sphere(kink, Vector3.ONE * r * 1.25, trim, 3, 6)
		"log":
			k.cylinder(from, to, r * 1.7, r * 1.6, wood, 8, true, log_end)
		"none", "stump":
			pass
		_:
			k.cylinder(from, to, r * 0.75, r * 1.1, wood, 6, true)


## Four legs under a rectangle, at +-half, from the floor to `top`.
func legs(half: Vector2, top: float, style: String, r: float = 0.035) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			leg(Vector3(sx * half.x, 0, sz * half.y), Vector3(sx * half.x, top, sz * half.y), style, r)


## A cushion in the fabric kit: a box whose faces bulge out by `puff` in the middle.
func cushion(centre: Vector3, size: Vector3, puff: float = 0.03, col: Color = FABRIC, steps: int = 4) -> void:
	var h := size * 0.5
	for axis in 3:
		for sgn: float in [-1.0, 1.0]:
			if axis == 1 and sgn < 0.0:
				continue
			var n := Vector3.ZERO
			n[axis] = sgn
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var hu: float = h[(axis + 1) % 3]
			var hv: float = h[(axis + 2) % 3]
			var hn: float = h[axis]
			var start := f.verts.size()
			for i in steps + 1:
				for j in steps + 1:
					var a := lerpf(-1.0, 1.0, float(i) / steps)
					var b := lerpf(-1.0, 1.0, float(j) / steps)
					var p := centre + n * (hn + puff * (1.0 - a * a) * (1.0 - b * b)) + u * a * hu + v * b * hv
					# The bulge's slope tips the normal outwards towards the edges.
					var normal := (n + u * (2.0 * a * puff * (1.0 - b * b) / hu) + v * (2.0 * b * puff * (1.0 - a * a) / hv)).normalized()
					f.vertex(p, normal, col, MeshKit.planar_uv(p, n))
			for i in steps:
				for j in steps:
					var q := start + i * (steps + 1) + j
					f.quad(q, q + steps + 1, q + steps + 2, q + 1, f.xform.basis * n)


## A little heart facing +Z (Meadow Cottage's motif).
func heart(at: Vector3, s: float, col: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		k.sphere(at + Vector3(sx * 0.04 * s, 0, 0), Vector3(0.05, 0.05, 0.02) * s, col, 4, 8)
	k.cone(at + Vector3(0, -0.01 * s, 0), at + Vector3(0, -0.11 * s, 0), 0.075 * s, col, 4)


## Rope wound round a post or rail between two points.
func lashing(at: Vector3, axis: Vector3, r: float, turns: int = 3) -> void:
	for i in turns:
		var c := at + axis * (i - (turns - 1) * 0.5) * 0.028
		k.cylinder(c - axis * 0.011, c + axis * 0.011, r + 0.012, r + 0.012, MeshKit.lin(ROPE), 7, false)


## A drawer front with a knob, on the face at z.
func drawer(centre: Vector3, size: Vector2, col: Color) -> void:
	k.box(centre, Vector3(size.x, size.y, 0.03), col)
	k.sphere(centre + Vector3(0, 0, 0.03), Vector3(0.035, 0.035, 0.03), accent, 3, 6)


## A row of books standing on a shelf, from x0 to x1.
func books(x0: float, x1: float, y: float, z: float, seed_value: int) -> void:
	var x := x0
	var i := seed_value
	while x < x1 - 0.06:
		var w := 0.05 + (i * 7 % 3) * 0.012
		var h := 0.2 + (i * 5 % 4) * 0.025
		if (i * 13) % 7 == 3:
			x += 0.08
		else:
			k.box(Vector3(x + w * 0.5, y + h * 0.5, z), Vector3(w, h, 0.2), MeshKit.lin(BOOKS[i % BOOKS.size()]))
			x += w + 0.006
		i += 1


# --- Pieces --------------------------------------------------------------------------

func _chair() -> void:
	var style: String = params.get("legs", "turned")
	var seat := 0.42
	k.box(Vector3(0, seat - 0.03, 0.02), Vector3(0.54, 0.06, 0.5), wood, wood_light)
	legs(Vector2(0.21, 0.19), seat - 0.06, style)
	var back := -0.21
	match params.get("back", "ladder"):
		"ladder":
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * 0.22, seat, back), Vector3(sx * 0.22, 1.0, back), 0.035, 0.03, wood, 7, true)
				k.sphere(Vector3(sx * 0.22, 1.03, back), Vector3.ONE * 0.045, wood, 3, 7)
			for y: float in [0.62, 0.76, 0.9]:
				k.box(Vector3(0, y, back), Vector3(0.42, 0.07, 0.035), wood, wood_light)
			if params.get("cushion", false):
				heart(Vector3(0, 0.98, back + 0.03), 0.6, accent)
		"slat":
			for sx: float in [-1.0, 1.0]:
				leg(Vector3(sx * 0.22, seat, back), Vector3(sx * 0.22, 0.98, back), "plank")
			k.box(Vector3(0, 0.95, back), Vector3(0.5, 0.08, 0.05), wood, wood_light)
			for i in 3:
				k.box(Vector3(-0.11 + i * 0.11, 0.7, back), Vector3(0.07, 0.42, 0.03), wood)
			if params.get("rope", false):
				for sx: float in [-1.0, 1.0]:
					lashing(Vector3(sx * 0.22, 0.95, back), Vector3.UP, 0.04, 2)
		"log":
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * 0.22, seat, back), Vector3(sx * 0.22, 1.0, back), 0.055, 0.05, wood, 8, true, log_end)
			for y: float in [0.68, 0.92]:
				k.cylinder(Vector3(-0.28, y, back - 0.01), Vector3(0.28, y, back - 0.01), 0.045, 0.045, wood, 8, true, log_end)
		"star":
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * 0.2, seat, back), Vector3(sx * 0.12, 0.72, back), 0.03, 0.025, wood, 7, true)
			prism(k, star_points(0.27), Vector3(0, 0.86, back), 0.05, trim)
			prism(g, star_points(0.12), Vector3(0, 0.86, back + 0.03), 0.02, glow)
		"cap":
			# A toadstool cap stood on end for a backrest, on a stalk.
			k.cylinder(Vector3(0, seat, back), Vector3(0, 0.62, back), 0.06, 0.05, wood, 8, false)
			f.xform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.8, back - 0.03))
			dome(f, Vector3.ZERO, Vector3(0.28, 0.07, 0.24), FABRIC)
			f.xform = Transform3D.IDENTITY
			k.cylinder(Vector3(0, 0.8, back - 0.035), Vector3(0, 0.8, back - 0.03), 0.28, 0.28, wood, 14, true)
	if params.get("cushion", false):
		cushion(Vector3(0, seat + 0.02, 0.03), Vector3(0.46, 0.05, 0.42), 0.025)
		for sx: float in [-1.0, 1.0]:
			k.sphere(Vector3(sx * 0.2, seat + 0.03, back + 0.04), Vector3(0.02, 0.04, 0.02), MeshKit.lin(PILLOW), 3, 5)


func _stool() -> void:
	var seat: float = 0.46
	match params.get("top", "round"):
		"round":
			k.cylinder(Vector3(0, seat - 0.07, 0), Vector3(0, seat, 0), 0.24, 0.25, wood, 14, true, wood_light)
		"rope":
			k.cylinder(Vector3(0, seat - 0.07, 0), Vector3(0, seat - 0.02, 0), 0.24, 0.24, trim, 12, true)
			k.cylinder(Vector3(0, seat - 0.02, 0), Vector3(0, seat, 0), 0.22, 0.22, MeshKit.lin(ROPE), 12, true)
			for r: float in [0.08, 0.15]:
				k.cylinder(Vector3(0, seat - 0.005, 0), Vector3(0, seat + 0.005, 0), r + 0.012, r + 0.012, MeshKit.lin(ROPE.darkened(0.12)), 12, false)
		"stump":
			k.cylinder(Vector3.ZERO, Vector3(0, seat - 0.05, 0), 0.27, 0.23, wood, 12, true, log_end)
			for i in 3:
				var a := TAU * i / 3.0 + 0.5
				k.cylinder(Vector3(cos(a) * 0.18, 0.1, sin(a) * 0.18), Vector3(cos(a) * 0.32, 0.0, sin(a) * 0.32), 0.07, 0.04, wood, 6)
			cushion(Vector3(0, seat - 0.03, 0), Vector3(0.36, 0.05, 0.36), 0.03)
		"cap":
			stalk(Vector3.ZERO, seat - 0.08, 0.13)
			dome(f, Vector3(0, seat - 0.08, 0), Vector3(0.28, 0.1, 0.28), FABRIC)
			sprouts(Vector2(0.3, 0.2), 2)
	var style: String = params.get("legs", "turned")
	for i in 3:
		var a := TAU * i / 3.0 + PI * 0.5
		leg(Vector3(cos(a) * 0.22, 0, sin(a) * 0.22), Vector3(cos(a) * 0.15, seat - 0.07, sin(a) * 0.15), style, 0.03)
	if style != "none":
		k.cylinder(Vector3(0, 0.18, 0), Vector3(0, 0.2, 0), 0.19, 0.19, trim if style != "turned" else wood, 10, false)


func _table() -> void:
	var top := 0.76
	var style: String = params.get("legs", "turned")
	match params.get("shape", "rect"):
		"rect":
			k.box(Vector3(0, top - 0.04, 0), Vector3(1.8, 0.08, 0.86), wood, wood_light)
			k.box(Vector3(0, top - 0.13, 0), Vector3(1.6, 0.1, 0.7), trim)
			legs(Vector2(0.78, 0.32), top - 0.08, style, 0.045)
			# A gingham runner down the middle, hanging over the sides.
			cushion(Vector3(0, top + 0.004, 0), Vector3(0.42, 0.008, 0.9), 0.0, FABRIC, 1)
			for sz: float in [-1.0, 1.0]:
				cushion(Vector3(0, top - 0.06, sz * 0.455), Vector3(0.42, 0.13, 0.008), 0.0, FABRIC, 1)
		"plank":
			for i in 3:
				var col := wood_light if i == 1 else wood
				k.box(Vector3(0, top - 0.035, -0.28 + i * 0.28), Vector3(1.84, 0.07, 0.26), col)
			for sx: float in [-1.0, 1.0]:
				k.box(Vector3(sx * 0.7, top - 0.1, 0), Vector3(0.1, 0.06, 0.8), trim)
				k.box(Vector3(sx * 0.7, 0.2, 0), Vector3(0.08, 0.06, 0.66), trim)
			legs(Vector2(0.7, 0.32), top - 0.07, style, 0.04)
		"cap":
			# A toadstool table: a spotted top on a stout stalk.
			top = 0.7
			var r := minf(size.x, size.y) * 0.5 - 0.06
			stalk(Vector3.ZERO, top - 0.08, 0.24)
			f.xform = Transform3D(Basis.from_scale(Vector3(size.x * 0.5 / (r + 0.06), 1, size.y * 0.5 / (r + 0.06))), Vector3.ZERO)
			f.cylinder(Vector3(0, top - 0.08, 0), Vector3(0, top, 0), r, r - 0.02, FABRIC, 20, true)
			f.xform = Transform3D.IDENTITY
			sprouts(Vector2(0.55, 0.45), 3)
		"slab":
			k.box(Vector3(0, top - 0.06, 0), Vector3(1.84, 0.12, 0.84), wood, wood_light)
			for sz: float in [-1.0, 1.0]:
				k.box(Vector3(0, top - 0.06, sz * 0.43), Vector3(1.86, 0.11, 0.04), trim)
			legs(Vector2(0.72, 0.28), top - 0.12, style, 0.045)
	if params.get("stars", false):
		for sz: float in [-1.0, 1.0]:
			for i in 3:
				prism(g, star_points(0.05), Vector3(-0.5 + i * 0.5, top - 0.13, sz * 0.36), 0.03, glow)


func _side_table() -> void:
	var top: float = 0.6
	var style: String = params.get("legs", "turned")
	match style:
		"stump":
			top = 0.56
			k.cylinder(Vector3.ZERO, Vector3(0, top - 0.06, 0), 0.3, 0.26, wood, 12, true, log_end)
			k.cylinder(Vector3(0, top - 0.06, 0), Vector3(0, top, 0), 0.34, 0.34, wood, 12, true, wood_light)
			for i in 4:
				var a := TAU * i / 4.0 + 0.3
				k.cylinder(Vector3(cos(a) * 0.2, 0.12, sin(a) * 0.2), Vector3(cos(a) * 0.38, 0.0, sin(a) * 0.38), 0.08, 0.04, wood, 6)
			# A sprig of moss on top.
			k.sphere(Vector3(0.18, top, 0.12), Vector3(0.08, 0.03, 0.06), MeshKit.lin(Color("8fbf73")), 3, 6)
		"plank":
			top = 0.58
			k.box(Vector3(0, top - 0.03, 0), Vector3(0.66, 0.06, 0.6), wood, wood_light)
			k.box(Vector3(0, 0.16, 0), Vector3(0.58, 0.05, 0.52), wood)
			legs(Vector2(0.27, 0.24), top - 0.06, style, 0.035)
			k.sphere(Vector3(-0.12, 0.22, 0.05), Vector3(0.09, 0.06, 0.07), accent, 4, 7)
		_:
			k.cylinder(Vector3(0, top - 0.05, 0), Vector3(0, top, 0), 0.32, 0.32, wood, 16, true, wood_light)
			legs(Vector2(0.18, 0.18), top - 0.05, style, 0.03)
			if params.get("drawer", false):
				k.box(Vector3(0, top - 0.12, 0), Vector3(0.42, 0.13, 0.42), wood)
				k.box(Vector3(0, top - 0.12, 0.205), Vector3(0.38, 0.11, 0.02), trim)
				drawer(Vector3(0, top - 0.12, 0.215), Vector2(0.34, 0.08), wood_light)


## Armchair (width 1) or sofa (width 2).
func _armchair(width: int) -> void:
	var style: String = params.get("legs", "turned")
	var hw := 0.4 if width == 1 else 0.88
	var seat := 0.46
	var framed: bool = params.get("frame", true)
	legs(Vector2(hw - 0.07, 0.3), 0.12, style if style != "log" else "turned", 0.03 if style != "log" else 0.04)
	if framed:
		# Upholstered: a wooden plinth with padded arms and back.
		k.box(Vector3(0, 0.19, 0), Vector3(hw * 2.0, 0.14, 0.74), wood, wood_light)
		for sx: float in [-1.0, 1.0]:
			cushion(Vector3(sx * (hw - 0.08), 0.43, 0.0), Vector3(0.16, 0.34, 0.72), 0.03)
			k.box(Vector3(sx * (hw - 0.08), 0.615, 0.0), Vector3(0.18, 0.04, 0.74), wood, wood_light)
		cushion(Vector3(0, 0.62, -0.29), Vector3(hw * 2.0 - 0.32, 0.66, 0.16), 0.04)
	else:
		# Open wooden frame with loose cushions.
		k.box(Vector3(0, 0.2, 0), Vector3(hw * 2.0, 0.08, 0.66), wood)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * (hw - 0.03), 0.42, 0.0), Vector3(0.06, 0.44, 0.66), trim)
			k.box(Vector3(sx * (hw - 0.03), 0.65, 0.04), Vector3(0.12, 0.04, 0.74), wood, wood_light)
		for i in 5 * width:
			var x := lerpf(-hw + 0.12, hw - 0.12, i / float(5 * width - 1))
			k.box(Vector3(x, 0.62, -0.3), Vector3(0.09, 0.8, 0.04), wood)
		k.box(Vector3(0, 1.0, -0.3), Vector3(hw * 2.0, 0.06, 0.06), trim)
		cushion(Vector3(0, 0.66, -0.23), Vector3(hw * 2.0 - 0.22, 0.48, 0.1), 0.04)
	var seats := width
	var inner := hw * 2.0 - (0.32 if framed else 0.14)
	for i in seats:
		var w := inner / seats
		cushion(Vector3(-inner * 0.5 + w * (i + 0.5), seat - 0.08, 0.06), Vector3(w - 0.02, 0.16, 0.58), 0.03)
	if params.get("moon", false):
		prism(g, crescent_points(0.2), Vector3(0, 1.08, -0.3), 0.05, glow)
		for sx: float in [-1.0, 1.0]:
			prism(g, star_points(0.06), Vector3(sx * 0.3, 1.02, -0.3), 0.03, glow)
	if width == 2:
		# Scatter cushions in the corners.
		for sx: float in [-1.0, 1.0]:
			k.xform = Transform3D(Basis(Vector3.BACK, sx * 0.2), Vector3(sx * (inner * 0.5 - 0.14), 0.66, -0.17))
			k.rounded_box(Vector3.ZERO, Vector3(0.26, 0.24, 0.08), accent, 0.4)
			k.xform = Transform3D.IDENTITY


func _bed() -> void:
	var hw := 0.74
	var hd := 0.94
	legs(Vector2(hw - 0.06, hd - 0.06), 0.14, "turned" if params.get("headboard", "") == "arched" else "plank", 0.035)
	k.box(Vector3(0, 0.22, 0), Vector3(hw * 2.0, 0.16, hd * 2.0), wood, wood_light)
	k.box(Vector3(0, 0.36, 0.0), Vector3(hw * 2.0 - 0.08, 0.12, hd * 2.0 - 0.1), MeshKit.lin(PILLOW))
	for sx: float in [-1.0, 1.0]:
		k.rounded_box(Vector3(sx * 0.32, 0.47, -hd + 0.28), Vector3(0.5, 0.12, 0.3), MeshKit.lin(PILLOW), 0.5)
	# The quilt, with its top edge folded back in plain trim.
	cushion(Vector3(0, 0.44, 0.2), Vector3(hw * 2.0 - 0.02, 0.06, hd * 2.0 - 0.52), 0.02)
	cushion(Vector3(0, 0.475, -0.5), Vector3(hw * 2.0 - 0.02, 0.03, 0.14), 0.01, FABRIC_TRIM, 2)
	for sx: float in [-1.0, 1.0]:
		cushion(Vector3(sx * (hw + 0.005), 0.33, 0.2), Vector3(0.012, 0.22, hd * 2.0 - 0.52), 0.0, FABRIC, 1)
	var head := -hd - 0.03
	match params.get("headboard", "arched"):
		"arched":
			k.box(Vector3(0, 0.55, head), Vector3(hw * 2.0, 0.7, 0.07), wood)
			k.cylinder(Vector3(0, 0.88, head - 0.035), Vector3(0, 0.88, head + 0.035), 0.5, 0.5, wood, 18, true)
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * hw, 0.0, head), Vector3(sx * hw, 1.0, head), 0.05, 0.045, wood_light, 8, true)
				k.sphere(Vector3(sx * hw, 1.04, head), Vector3.ONE * 0.06, wood_light, 3, 7)
			heart(Vector3(0, 1.12, head + 0.04), 1.3, accent)
			k.box(Vector3(0, 0.38, hd + 0.02), Vector3(hw * 2.0, 0.32, 0.06), wood, wood_light)
		"plank":
			for i in 7:
				var x := lerpf(-hw + 0.1, hw - 0.1, i / 6.0)
				var h := 0.92 + 0.06 * sin(i * 2.1) + (0.08 if i == 3 else 0.0)
				k.box(Vector3(x, h * 0.5, head), Vector3(0.19, h, 0.06), wood if i % 2 == 0 else wood_light)
			k.box(Vector3(0, 0.68, head + 0.04), Vector3(hw * 2.0, 0.03, 0.03), MeshKit.lin(ROPE))
			for sx: float in [-1.0, 1.0]:
				lashing(Vector3(sx * 0.5, 0.68, head + 0.04), Vector3.RIGHT, 0.02, 2)
			k.sphere(Vector3(0.35, 0.86, head + 0.05), Vector3(0.06, 0.06, 0.03), accent, 4, 7)
		"log":
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * hw, 0.0, head), Vector3(sx * hw, 1.08, head), 0.08, 0.07, wood, 8, true, log_end)
				k.cylinder(Vector3(sx * hw, 0.0, hd), Vector3(sx * hw, 0.6, hd), 0.07, 0.065, wood, 8, true, log_end)
			for y: float in [0.5, 0.72, 0.94]:
				k.cylinder(Vector3(-hw, y, head), Vector3(hw, y, head), 0.08, 0.08, wood, 8, false)
			k.cylinder(Vector3(-hw, 0.46, hd), Vector3(hw, 0.46, hd), 0.065, 0.065, wood, 8, false)
		"cap":
			# A big spotted cap for a headboard, with little ones on the posts.
			for sx: float in [-1.0, 1.0]:
				stalk(Vector3(sx * hw, 0, head), 0.62, 0.07)
				dome(f, Vector3(sx * hw, 0.62, head), Vector3(0.17, 0.09, 0.17), FABRIC)
			k.box(Vector3(0, 0.45, head), Vector3(hw * 2.0, 0.5, 0.07), wood)
			f.xform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.7, head - 0.02))
			dome(f, Vector3.ZERO, Vector3(0.62, 0.08, 0.5), FABRIC, 5, 18)
			f.xform = Transform3D.IDENTITY
			sprouts(Vector2(hw + 0.08, hd - 0.2), 3)
		"moon":
			k.box(Vector3(0, 0.5, head), Vector3(hw * 2.0, 0.6, 0.07), wood)
			k.box(Vector3(0, 0.82, head), Vector3(hw * 2.0 + 0.06, 0.05, 0.1), trim)
			prism(g, crescent_points(0.34), Vector3(-0.1, 1.15, head), 0.07, glow)
			for spot: Vector3 in [Vector3(0.35, 1.25, head), Vector3(0.55, 1.0, head), Vector3(0.25, 0.98, head)]:
				prism(g, star_points(0.07), spot, 0.04, glow)
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * hw, 0.0, head), Vector3(sx * hw, 0.9, head), 0.045, 0.04, trim, 8, true)
				k.sphere(Vector3(sx * hw, 0.94, head), Vector3.ONE * 0.06, trim, 3, 7)


func _dresser() -> void:
	var hw := 0.8
	var depth := 0.56
	var top := 0.9
	legs(Vector2(hw - 0.06, depth * 0.5 - 0.06), 0.1, "turned", 0.03)
	k.box(Vector3(0, 0.1 + (top - 0.15) * 0.5, -0.04), Vector3(hw * 2.0, top - 0.15, depth), wood)
	k.box(Vector3(0, top - 0.025, -0.04), Vector3(hw * 2.0 + 0.08, 0.05, depth + 0.06), wood, wood_light)
	var rows: int = params.get("drawers", 3)
	var front := depth * 0.5 - 0.02
	var h := (top - 0.25) / rows
	# A darker recess shows round the drawer fronts.
	k.box(Vector3(0, 0.16 + (top - 0.25) * 0.5, front - 0.01), Vector3(hw * 2.0 - 0.06, top - 0.23, 0.02), trim)
	for r in rows:
		var y := 0.16 + h * (r + 0.5)
		if r == rows - 1:
			for sx: float in [-1.0, 1.0]:
				drawer(Vector3(sx * hw * 0.5, y, front), Vector2(hw - 0.08, h - 0.05), wood_light)
		else:
			drawer(Vector3(0, y, front), Vector2(hw * 2.0 - 0.12, h - 0.05), wood_light)
	if params.get("hearts", false):
		for sx: float in [-1.0, 1.0]:
			heart(Vector3(sx * (hw - 0.12), 0.18 + h * 0.5, front + 0.04), 0.5, accent)
	if params.get("stars", false):
		for sx: float in [-1.0, 1.0]:
			prism(g, star_points(0.08), Vector3(sx * (hw - 0.1), top + 0.1, -0.2), 0.04, glow)
			k.cylinder(Vector3(sx * (hw - 0.1), top, -0.2), Vector3(sx * (hw - 0.1), top + 0.03, -0.2), 0.05, 0.04, trim, 8, true)
			k.cylinder(Vector3(sx * (hw - 0.1), top, -0.2), Vector3(sx * (hw - 0.1), top + 0.06, -0.2), 0.01, 0.01, trim, 4, false)
	# A little doily on top.
	cushion(Vector3(-0.35, top + 0.004, -0.04), Vector3(0.44, 0.008, 0.34), 0.0, FABRIC, 1)


func _bookcase() -> void:
	var hw := 0.82
	var depth := 0.38
	var z := -0.25
	var height := 1.5
	var style: String = params.get("top", "scalloped")
	var open: bool = params.get("open", false)
	var shelves := [0.06, 0.52, 0.98, height - 0.03]
	if style == "log":
		for sx: float in [-1.0, 1.0]:
			k.cylinder(Vector3(sx * hw, 0.0, z), Vector3(sx * hw, height + 0.08, z), 0.07, 0.065, wood, 8, true, log_end)
	elif open:
		# Driftwood ladder sides lashed with rope.
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				leg(Vector3(sx * hw, 0, z + sz * depth * 0.4), Vector3(sx * hw, height + 0.06, z + sz * depth * 0.4), "plank", 0.03)
	else:
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * hw, height * 0.5, z), Vector3(0.06, height, depth), wood)
	if not open:
		k.box(Vector3(0, height * 0.5, z - depth * 0.5 + 0.015), Vector3(hw * 2.0 - 0.04, height, 0.03), wood_light)
	for i in shelves.size():
		var y: float = shelves[i]
		k.box(Vector3(0, y, z), Vector3(hw * 2.0 + (0.06 if style != "log" else 0.0), 0.05, depth), wood, wood_light)
		if open:
			for sx: float in [-1.0, 1.0]:
				lashing(Vector3(sx * hw, y, z + depth * 0.4), Vector3.UP, 0.03, 2)
	for i in 3:
		var y: float = shelves[i] + 0.025
		if open and i == 1:
			# Shells and a glass float instead of books.
			k.sphere(Vector3(-0.4, y + 0.1, z), Vector3.ONE * 0.1, accent, 6, 9)
			k.cone(Vector3(0.1, y, z), Vector3(0.1, y + 0.16, z), 0.08, MeshKit.lin(Color("f6d8c8")), 7)
			k.sphere(Vector3(0.45, y + 0.05, z + 0.05), Vector3(0.09, 0.05, 0.07), MeshKit.lin(Color("fbe7d4")), 4, 7)
		else:
			books(-hw + 0.06, hw - 0.06, y, z + 0.02, i * 5 + style.length())
	match style:
		"scalloped":
			for i in 7:
				var x := lerpf(-hw, hw, i / 6.0)
				k.cylinder(Vector3(x, height, z + depth * 0.5 - 0.04), Vector3(x, height, z + depth * 0.5), 0.13, 0.13, wood, 12, true)
			heart(Vector3(0, height + 0.06, z + depth * 0.5 + 0.01), 0.7, accent)
		"rope":
			k.cylinder(Vector3(-hw, height + 0.06, z + depth * 0.4), Vector3(hw, height + 0.06, z + depth * 0.4), 0.018, 0.018, MeshKit.lin(ROPE), 5, false)
		"cap":
			# A spotted cap for a roof, with sprouts along the shelves.
			dome(f, Vector3(0, height, z), Vector3(hw + 0.14, 0.26, depth * 0.5 + 0.12), FABRIC, 5, 18)
			for spot: Vector3 in [Vector3(hw - 0.15, shelves[1] + 0.025, z + 0.08), Vector3(-hw + 0.2, shelves[2] + 0.025, z + 0.08)]:
				sprout(spot, 0.9)
		"log":
			k.cylinder(Vector3(-hw - 0.1, height + 0.06, z), Vector3(hw + 0.1, height + 0.06, z), 0.07, 0.07, wood, 8, true, log_end)
			# A pinecone on top.
			k.sphere(Vector3(0.5, height + 0.17, z), Vector3(0.05, 0.07, 0.05), trim, 4, 7, 0.4, 0.3, 3)


func _floor_lamp() -> void:
	match params.get("shade", "frilly"):
		"cap":
			# A tall, slightly bent toadstool whose cap glows.
			k.cylinder(Vector3.ZERO, Vector3(0.04, 0.7, 0), 0.08, 0.06, wood, 8, false)
			k.cylinder(Vector3(0.04, 0.7, 0), Vector3(0, 1.25, 0), 0.06, 0.05, wood, 8, false)
			dome(g, Vector3(0, 1.22, 0), Vector3(0.36, 0.22, 0.36), accent.lerp(glow, 0.45))
			k.cylinder(Vector3(0, 1.215, 0), Vector3(0, 1.22, 0), 0.355, 0.355, wood_light, 16, true)
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				g.sphere(Vector3(cos(a) * 0.24, 1.33, sin(a) * 0.24), Vector3(0.05, 0.03, 0.05), MeshKit.lin(PILLOW), 3, 6)
			g.sphere(Vector3(0, 1.45, 0), Vector3(0.06, 0.02, 0.06), MeshKit.lin(PILLOW), 3, 6)
			sprouts(Vector2(0.25, 0.25), 3)
			return
		"moon":
			# A glowing moon hung from a crook.
			k.cylinder(Vector3.ZERO, Vector3(0, 0.05, 0), 0.2, 0.18, wood, 12, true, wood_light)
			k.cylinder(Vector3(0, 0.05, 0), Vector3(0, 1.4, 0), 0.025, 0.025, trim, 6, false)
			k.cylinder(Vector3(0, 1.4, 0), Vector3(0.28, 1.5, 0), 0.025, 0.025, trim, 6, false)
			k.cylinder(Vector3(0.28, 1.5, 0), Vector3(0.36, 1.38, 0), 0.025, 0.02, trim, 6, true)
			k.cylinder(Vector3(0.36, 1.38, 0), Vector3(0.36, 1.25, 0), 0.006, 0.006, trim, 4, false)
			g.sphere(Vector3(0.36, 1.1, 0), Vector3.ONE * 0.15, glow, 8, 12)
			prism(g, star_points(0.05), Vector3(0.12, 1.3, 0), 0.02, glow)
			return
	k.cylinder(Vector3.ZERO, Vector3(0, 0.05, 0), 0.2, 0.18, wood, 12, true, wood_light)
	leg(Vector3(0, 0.05, 0), Vector3(0, 1.22, 0), "turned", 0.03)
	k.sphere(Vector3(0, 1.22, 0), Vector3(0.07, 0.08, 0.07), MeshKit.lin(GLOW), 4, 8)
	# A fabric shade with a frill round the hem.
	f.cylinder(Vector3(0, 1.12, 0), Vector3(0, 1.44, 0), 0.3, 0.17, FABRIC, 14, false)
	f.cylinder(Vector3(0, 1.44, 0), Vector3(0, 1.45, 0), 0.17, 0.0, FABRIC, 14, false)
	for i in 14:
		var a := TAU * (i + 0.5) / 14.0
		f.sphere(Vector3(cos(a) * 0.3, 1.11, sin(a) * 0.3), Vector3(0.07, 0.045, 0.07), FABRIC_TRIM, 3, 6)
	k.cylinder(Vector3(0, 1.13, 0), Vector3(0, 1.14, 0), 0.27, 0.27, MeshKit.lin(GLOW), 14, true)


func _table_lamp() -> void:
	match params.get("shade", "float"):
		"float":
			# A glass fishing float in a rope net, on a driftwood base.
			k.cylinder(Vector3.ZERO, Vector3(0, 0.05, 0), 0.13, 0.12, trim, 10, true, wood)
			k.sphere(Vector3(0, 0.19, 0), Vector3.ONE * 0.14, accent.lightened(0.15), 8, 12)
			k.sphere(Vector3(0, 0.19, 0), Vector3.ONE * 0.08, MeshKit.lin(GLOW), 4, 8)
			for y: float in [0.13, 0.25]:
				var r := sqrt(maxf(0.0, 0.0196 - pow(y - 0.19, 2.0)))
				k.cylinder(Vector3(0, y - 0.006, 0), Vector3(0, y + 0.006, 0), r + 0.008, r + 0.008, MeshKit.lin(ROPE), 12, false)
			k.cylinder(Vector3(0, 0.32, 0), Vector3(0, 0.36, 0), 0.03, 0.025, MeshKit.lin(ROPE), 6, true)
		"star":
			k.cylinder(Vector3.ZERO, Vector3(0, 0.05, 0), 0.12, 0.11, wood, 10, true, wood_light)
			k.cylinder(Vector3(0, 0.05, 0), Vector3(0, 0.12, 0), 0.015, 0.015, trim, 5, false)
			prism(g, star_points(0.15), Vector3(0, 0.26, 0), 0.07, glow)
		"cluster":
			# Little glowing toadstools on a mossy mound.
			k.sphere(Vector3(0, 0.02, 0), Vector3(0.22, 0.06, 0.18), MeshKit.lin(Color("8fbf73")), 4, 10)
			for spot: Array in [[Vector3(-0.06, 0.03, 0.0), 1.4], [Vector3(0.09, 0.03, 0.05), 1.0], [Vector3(0.03, 0.03, -0.08), 0.75]]:
				sprout(spot[0], spot[1])
		"lantern":
			k.box(Vector3(0, 0.025, 0), Vector3(0.24, 0.05, 0.24), wood, wood_light)
			k.box(Vector3(0, 0.17, 0), Vector3(0.17, 0.24, 0.17), MeshKit.lin(GLOW))
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					k.box(Vector3(sx * 0.095, 0.17, sz * 0.095), Vector3(0.03, 0.26, 0.03), trim)
			k.cone(Vector3(0, 0.3, 0), Vector3(0, 0.42, 0), 0.19, MeshKit.lin(IRON), 4)
			k.cylinder(Vector3(-0.05, 0.47, 0), Vector3(0.05, 0.47, 0), 0.04, 0.04, MeshKit.lin(IRON), 6, false)


func _bench() -> void:
	var style: String = params.get("legs", "plank")
	var seat := 0.46
	if style == "log":
		k.box(Vector3(0, seat - 0.05, 0.04), Vector3(1.8, 0.1, 0.44), wood, wood_light)
		k.cylinder(Vector3(-0.9, seat - 0.12, 0.04), Vector3(0.9, seat - 0.12, 0.04), 0.1, 0.1, wood, 9, true, log_end)
		for sx: float in [-1.0, 1.0]:
			leg(Vector3(sx * 0.66, 0, 0.04), Vector3(sx * 0.66, seat - 0.2, 0.04), "log", 0.05)
	else:
		for i in 2:
			k.box(Vector3(0, seat - 0.035, -0.08 + i * 0.2), Vector3(1.8, 0.07, 0.18), wood if i == 0 else wood_light)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.72, seat - 0.21, 0.02), Vector3(0.08, seat - 0.07, 0.4), trim)
			k.box(Vector3(sx * 0.72, 0.04, 0.02), Vector3(0.12, 0.08, 0.46), trim)
	if params.get("back", false):
		for sx: float in [-1.0, 1.0]:
			k.cylinder(Vector3(sx * 0.72, seat - 0.1, -0.2), Vector3(sx * 0.74, 1.02, -0.24), 0.05, 0.045, wood, 8, true, log_end)
		for y: float in [0.72, 0.94]:
			k.cylinder(Vector3(-0.88, y, -0.23), Vector3(0.88, y, -0.23), 0.055, 0.055, wood, 8, true, log_end)
	if params.get("pad", false):
		cushion(Vector3(0, seat + 0.025, 0.02), Vector3(1.6, 0.05, 0.38), 0.025)
		for sx: float in [-1.0, 1.0]:
			lashing(Vector3(sx * 0.6, seat + 0.025, 0.02), Vector3.RIGHT, 0.04, 1)


func _crate() -> void:
	var s := 0.56
	for i in 3:
		var y := 0.09 + i * 0.19
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0, y, sz * 0.27), Vector3(0.58, 0.15, 0.04), wood if i % 2 == 0 else wood_light)
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.27, y, 0), Vector3(0.04, 0.15, 0.5), wood if i % 2 == 1 else wood_light)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(sx * 0.27, s * 0.5, sz * 0.27), Vector3(0.06, s, 0.06), trim)
	k.box(Vector3(0, s - 0.02, 0), Vector3(0.6, 0.04, 0.6), wood, wood_light)
	# A painted band and rope handles.
	k.box(Vector3(0, 0.28, 0.295), Vector3(0.4, 0.06, 0.012), accent)
	if params.get("rope", false):
		for sx: float in [-1.0, 1.0]:
			k.cylinder(Vector3(sx * 0.3, 0.4, -0.1), Vector3(sx * 0.34, 0.36, 0.0), 0.016, 0.016, MeshKit.lin(ROPE), 5, false)
			k.cylinder(Vector3(sx * 0.34, 0.36, 0.0), Vector3(sx * 0.3, 0.4, 0.1), 0.016, 0.016, MeshKit.lin(ROPE), 5, false)


## A rug lying on the floor, filling most of its footprint. Shapes: rect, round, oval.
func _rug() -> void:
	var w := size.x - 0.14
	var d := size.y - 0.14
	var shape: String = params.get("shape", "rect")
	var border: bool = params.get("border", true)
	if shape == "rect":
		cushion(Vector3(0, 0.012, 0), Vector3(w, 0.02, d), 0.0, FABRIC_TRIM if border else FABRIC, 1)
		if border:
			cushion(Vector3(0, 0.014, 0), Vector3(w - 0.16, 0.02, d - 0.16), 0.0, FABRIC, 1)
		if params.get("fringe", false):
			for sz: float in [-1.0, 1.0]:
				var count := int(w / 0.07)
				for i in count:
					var x := lerpf(-w * 0.5 + 0.03, w * 0.5 - 0.03, i / float(count - 1))
					k.box(Vector3(x, 0.006, sz * (d * 0.5 + 0.035)), Vector3(0.025, 0.01, 0.07), wood)
		return
	# Round and oval rugs: a disc, squashed for an oval, with a plain ring round it.
	var r := minf(w, d) * 0.5
	f.xform = Transform3D(Basis.from_scale(Vector3(w * 0.5 / r, 1, d * 0.5 / r)), Vector3.ZERO)
	if border:
		f.cylinder(Vector3(0, 0.0, 0), Vector3(0, 0.02, 0), r, r, FABRIC_TRIM, 28, true)
	f.cylinder(Vector3(0, 0.0, 0), Vector3(0, 0.024, 0), r - (0.09 if border else 0.0), r - (0.09 if border else 0.0), FABRIC, 28, true)
	f.xform = Transform3D.IDENTITY


## A window in a wall, centred at `centre` and facing +Z (the room), `size` across and
## high, with curtains (fabric) on a rod, tied back, and a valance.
func window(centre: Vector3, opening: Vector2, curtains: bool) -> void:
	var hw := opening.x * 0.5
	var hh := opening.y * 0.5
	var frame := MeshKit.lin(Color("fff8ec"))
	var pane := glass if glass else k
	pane.box(centre, Vector3(opening.x, opening.y, 0.02), MeshKit.lin(Color("bfe3ef")), MeshKit.lin(Color("bfe3ef")))
	# A soft cloud of light on the glass.
	pane.sphere(centre + Vector3(-hw * 0.3, hh * 0.35, 0.012), Vector3(hw * 0.35, hh * 0.18, 0.004), MeshKit.lin(Color("e6f5fa")), 3, 8)
	for sx: float in [-1.0, 1.0]:
		k.box(centre + Vector3(sx * (hw + 0.03), 0, 0.02), Vector3(0.06, opening.y + 0.12, 0.05), frame)
	k.box(centre + Vector3(0, hh + 0.03, 0.02), Vector3(opening.x + 0.12, 0.06, 0.05), frame)
	k.box(centre + Vector3(0, -hh - 0.04, 0.04), Vector3(opening.x + 0.2, 0.06, 0.1), frame)
	k.box(centre + Vector3(0, 0, 0.02), Vector3(0.035, opening.y, 0.03), frame)
	k.box(centre + Vector3(0, 0, 0.02), Vector3(opening.x, 0.035, 0.03), frame)
	if not curtains:
		return
	var top := centre.y + hh + 0.14
	var bottom := centre.y - hh - 0.12
	k.cylinder(Vector3(centre.x - hw - 0.3, top, centre.z + 0.1), Vector3(centre.x + hw + 0.3, top, centre.z + 0.1), 0.022, 0.022, trim, 6, true)
	for sx: float in [-1.0, 1.0]:
		k.sphere(Vector3(centre.x + sx * (hw + 0.32), top, centre.z + 0.1), Vector3.ONE * 0.04, trim, 3, 6)
		# Each curtain is gathered into pleats and pinched in by a tie-back.
		var outer := centre.x + sx * (hw + 0.24)
		var inner := centre.x + sx * (hw - 0.1)
		var pleats := 4
		for i in pleats:
			var t0 := float(i) / pleats
			var t1 := float(i + 1) / pleats
			var depth := 0.03 if i % 2 == 0 else 0.0
			var x_top := lerpf(outer, inner, (t0 + t1) * 0.5)
			var x_tie := lerpf(outer, outer + (inner - outer) * 0.35, (t0 + t1) * 0.5)
			var tie := lerpf(bottom, top, 0.38)
			var wide := absf(inner - outer) / pleats
			var narrow := wide * 0.4
			_panel(Vector3(x_top, top - 0.03, centre.z + 0.08 + depth), Vector3(x_tie, tie, centre.z + 0.1 + depth), wide, narrow)
			_panel(Vector3(x_tie, tie, centre.z + 0.1 + depth), Vector3(x_tie + (x_top - x_tie) * 0.3, bottom, centre.z + 0.09 + depth), narrow, wide * 0.8)
		cushion(Vector3(lerpf(outer, outer + (inner - outer) * 0.35, 0.5), lerpf(bottom, top, 0.38), centre.z + 0.13),
			Vector3(absf(inner - outer) * 0.4, 0.05, 0.05), 0.01, FABRIC_TRIM, 1)
	# A gathered valance across the top.
	cushion(Vector3(centre.x, top - 0.08, centre.z + 0.13), Vector3(opening.x + 0.62, 0.16, 0.04), 0.02, FABRIC, 2)
	cushion(Vector3(centre.x, top - 0.165, centre.z + 0.13), Vector3(opening.x + 0.62, 0.025, 0.045), 0.0, FABRIC_TRIM, 1)


## One flat strip of curtain from `a` (top) to `b` (bottom), `wa` and `wb` wide.
func _panel(a: Vector3, b: Vector3, wa: float, wb: float) -> void:
	var n := Vector3.BACK
	var p0 := a + Vector3(-wa * 0.5, 0, 0)
	var p1 := a + Vector3(wa * 0.5, 0, 0)
	var p2 := b + Vector3(wb * 0.5, 0, 0)
	var p3 := b + Vector3(-wb * 0.5, 0, 0)
	f.flat_quad(p0, p1, p2, p3, n, FABRIC)
	f.flat_quad(p0, p1, p2, p3, -n, FABRIC)


# --- Shapes for Mushroom Grove and Starlight -------------------------------------------

## The top half of an ellipsoid (a toadstool cap), textured flat from above so prints
## look right from the camera.
func dome(kit: MeshKit, centre: Vector3, radius: Vector3, col: Color, rings: int = 4, segments: int = 14) -> void:
	var start := kit.verts.size()
	for i in rings + 1:
		var phi := PI * 0.5 * i / rings
		for j in segments + 1:
			var theta := TAU * j / segments
			var unit := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var p := centre + unit * radius
			var n := Vector3(unit.x / radius.x, unit.y / radius.y, unit.z / radius.z).normalized()
			kit.vertex(p, n, col, Vector2(p.x, p.z))
	var row := segments + 1
	for i in rings:
		for j in segments:
			var a := start + i * row + j
			var b := a + row
			var out := (kit.verts[a] + kit.verts[b + 1]) * 0.5 - kit.xform * centre
			if i == 0:
				kit.tri(a, b, b + 1, out)
			else:
				kit.quad(a, b, b + 1, a + 1, out)


## A toadstool stalk from `base` up `height`, a little fatter at the foot.
func stalk(base: Vector3, height: float, r: float) -> void:
	k.cylinder(base, base + Vector3(0, height * 0.3, 0), r * 1.25, r, wood, 10, true)
	k.cylinder(base + Vector3(0, height * 0.3, 0), base + Vector3(0, height, 0), r, r * 0.85, wood, 10, false)


## A tiny toadstool whose cap glows at night.
func sprout(at: Vector3, s: float) -> void:
	k.cylinder(at, at + Vector3(0, 0.07 * s, 0), 0.018 * s, 0.014 * s, wood, 5, false)
	dome(g, at + Vector3(0, 0.065 * s, 0), Vector3(0.05, 0.035, 0.05) * s, glow, 2, 8)
	k.cylinder(at + Vector3(0, 0.063 * s, 0), at + Vector3(0, 0.066 * s, 0), 0.048 * s, 0.048 * s, wood_light, 8, true)


## A few sprouts round the foot of a piece, inside +-half.
func sprouts(half: Vector2, count: int) -> void:
	var spots := [Vector2(1, 0.8), Vector2(-0.9, 0.6), Vector2(0.7, -0.9), Vector2(-0.6, -0.7)]
	for i in mini(count, spots.size()):
		var p: Vector2 = spots[i] * half
		sprout(Vector3(p.x, 0, p.y), 1.0 - i * 0.15)


## A flat shape (points anticlockwise in x, y) cut `depth` thick, facing +Z, at `at`.
func prism(kit: MeshKit, points: PackedVector2Array, at: Vector3, depth: float, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(points)
	for side: float in [1.0, -1.0]:
		var n := Vector3(0, 0, side)
		var start := kit.verts.size()
		for p in points:
			kit.vertex(at + Vector3(p.x, p.y, side * depth * 0.5), n, col)
		for t in range(0, tris.size(), 3):
			kit.tri(start + tris[t], start + tris[t + 1], start + tris[t + 2], kit.xform.basis * n)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var n := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		kit.flat_quad(at + Vector3(a.x, a.y, depth * 0.5), at + Vector3(b.x, b.y, depth * 0.5),
			at + Vector3(b.x, b.y, -depth * 0.5), at + Vector3(a.x, a.y, -depth * 0.5), n, col)


## A five-pointed star, point up.
static func star_points(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		out.append(Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return out


## A crescent moon opening to the right.
static func crescent_points(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 13:
		var a := lerpf(PI / 3.0, PI * 5.0 / 3.0, i / 12.0)
		out.append(Vector2(cos(a), sin(a)) * r)
	# Back up the inside edge: a circle through both tips, centred to the right.
	var c := Vector2(r * 0.35, 0)
	var tip := Vector2(cos(PI / 3.0), sin(PI / 3.0)) * r
	var inner := (tip - c).length()
	var top := atan2(tip.y - c.y, tip.x - c.x)
	for i in range(1, 12):
		var a := lerpf(TAU - top, top, i / 12.0)
		out.append(c + Vector2(cos(a), sin(a)) * inner)
	return out
