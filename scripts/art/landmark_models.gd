class_name LandmarkModels
extends RefCounted
## Big island decorations built in code: fairground rides, carts and stalls, and statues
## after famous ones. Models keys are "landmark:<id>" for the whole thing standing still
## (icons, placing) and, for rides whose parts move in the world (`Ride`), "landmark:<id>_base"
## for what stays put plus a key per moving part. Front faces +Z; one tile is one unit.

const CREAM := Color("fbf3dc")
const WHITE := Color("f8f4ec")
const PINK := Color("f2a7c0")
const ROSE := Color("e0656b")
const MINT := Color("9fd3c7")
const SKY := Color("8cc8e8")
const LEMON := Color("f2d36b")
const LILAC := Color("b9a6e6")
const PEACH := Color("f6b98a")
const GREEN := Color("8cc47a")
const GOLD := Color("e8b84f")
const METAL := Color("9aa3ab")
const WOOD := Color("b8875a")
const DARK := Color("3a3236")
const BULB := Color("ffe9a8")

## The Ferris wheel: axle height, wheel radius, cabins, and how fast it turns (rad/s).
const FERRIS_AXLE := 2.75
const FERRIS_R := 1.7
const FERRIS_CABS := 8
const FERRIS_SPEED := 0.14
const CAB_COLOURS := [PINK, MINT, LEMON, SKY, LILAC, PEACH, ROSE, GREEN]
## The carousel: horses on poles this far out, going round this fast.
const HORSES := 6
const HORSE_R := 1.0
const HORSE_Y := 0.85
const CAROUSEL_SPEED := 0.45
const HORSE_COLOURS := [WHITE, Color("f2c0d0"), Color("bfe6d8"), Color("f6e3a0"), Color("c4def0"), Color("d8ccf2")]
## The teacups: three cups on a turning floor, each spinning on its own.
const CUPS := 3
const CUP_R := 0.95
const TEACUP_SPEED := 0.35
const CUP_SPIN := 1.3
const CUP_COLOURS := [PINK, MINT, LEMON]
## The lucky cat's beckoning paw turns about its shoulder here.
const CAT_SHOULDER := Vector3(-0.27, 0.8, 0.05)


## Builds `p` ("landmark", id, maybe a part number) into `k`, with anything that lights
## up at night into `glow`.
static func build(k: MeshKit, glow: MeshKit, p: PackedStringArray) -> void:
	var part := int(p[2]) if p.size() > 2 else 0
	match p[1]:
		"ferris_wheel":
			_ferris_base(k)
			_with([k, glow], Transform3D(Basis.IDENTITY, Vector3(0, FERRIS_AXLE, 0)), func(): _ferris_ring(k, glow))
			for i in FERRIS_CABS:
				var a := i * TAU / FERRIS_CABS
				_with([k], Transform3D(Basis.IDENTITY, Vector3(cos(a), sin(a), 0) * FERRIS_R + Vector3(0, FERRIS_AXLE, 0)), func(): _ferris_cab(k, i))
		"ferris_wheel_base":
			_ferris_base(k)
		"ferris_ring":
			_ferris_ring(k, glow)
		"ferris_cab":
			_ferris_cab(k, part)
		"carousel":
			_carousel_base(k)
			_carousel_top(k, glow)
			for i in HORSES:
				var spot := horse_spot(i, 0.0, 0.0)
				_with([k], spot, func(): _horse(k, i))
		"carousel_base":
			_carousel_base(k)
		"carousel_top":
			_carousel_top(k, glow)
		"horse":
			_horse(k, part)
		"teacups":
			_teacup_base(k)
			_teacup_floor(k)
			for i in CUPS:
				_with([k], cup_spot(i, 0.0, 0.0), func(): _teacup(k, i))
		"teacups_base":
			_teacup_base(k)
		"teacup_floor":
			_teacup_floor(k)
		"teacup":
			_teacup(k, part)
		"hot_air_balloon":
			_balloon_base(k)
			_balloon_up(k, glow)
		"hot_air_balloon_base":
			_balloon_base(k)
		"balloon_up":
			_balloon_up(k, glow)
		"lucky_cat":
			_lucky_cat(k)
			_with([k], Transform3D(Basis.IDENTITY, CAT_SHOULDER), func(): _lucky_paw(k))
		"lucky_cat_base":
			_lucky_cat(k)
		"lucky_paw":
			_lucky_paw(k)
		"ice_cream_cart":
			_ice_cream_cart(k)
		"popcorn_cart":
			_popcorn_cart(k)
		"candy_floss":
			_candy_floss(k)
		"balloon_bunch":
			_balloon_bunch(k)
		"strength_tester":
			_strength_tester(k)
		"rubber_duck":
			_rubber_duck(k)
		"moai":
			_moai(k)
		"sphinx_cat":
			_sphinx_cat(k)
		"torch_statue":
			_torch_statue(k, glow)
		"leaning_tower":
			_leaning_tower(k)
		"clock_tower":
			_clock_tower(k, glow)
		_:
			push_warning("Unknown landmark " + p[1])
			k.sphere(Vector3(0, 0.3, 0), Vector3.ONE * 0.3, MeshKit.lin(Color.MAGENTA))


## Builds into `kits` with `t` on top of their own transforms.
static func _with(kits: Array, t: Transform3D, f: Callable) -> void:
	var saved: Array[Transform3D] = []
	for kit: MeshKit in kits:
		saved.append(kit.xform)
		kit.xform = kit.xform * t
	f.call()
	for i in kits.size():
		(kits[i] as MeshKit).xform = saved[i]


static func c(col: Color, sway: float = 0.0) -> Color:
	return MeshKit.lin(col, sway)


## A cone in stripes: `colours` in turn round it, each stripe its own flat colour.
static func _striped_cone(k: MeshKit, base: Vector3, tip: Vector3, r: float, colours: Array, segments: int, turn: float = 0.0) -> void:
	var slope := r / maxf(tip.y - base.y, 0.01)
	for j in segments:
		var a0 := turn + TAU * j / segments
		var a1 := turn + TAU * (j + 1) / segments
		var col := c(colours[j % colours.size()])
		var n0 := Vector3(cos(a0), slope, sin(a0)).normalized()
		var n1 := Vector3(cos(a1), slope, sin(a1)).normalized()
		var a := k.vertex(base + Vector3(cos(a0), 0, sin(a0)) * r, n0, col)
		var b := k.vertex(base + Vector3(cos(a1), 0, sin(a1)) * r, n1, col)
		var t := k.vertex(tip, (n0 + n1).normalized(), col)
		k.tri(a, b, t, k.xform.basis * (n0 + n1))
		# The underside, in the first colour.
		var under := c(colours[0]).darkened(0.15)
		var u0 := k.vertex(base + Vector3(cos(a0), 0, sin(a0)) * r, Vector3.DOWN, under)
		var u1 := k.vertex(base + Vector3(cos(a1), 0, sin(a1)) * r, Vector3.DOWN, under)
		var um := k.vertex(base + Vector3(0, 0.02, 0), Vector3.DOWN, under)
		k.tri(u0, u1, um, k.xform.basis * Vector3.DOWN)


## A ball in stripes from pole to pole (a hot air balloon, a headdress).
static func _striped_ball(k: MeshKit, centre: Vector3, radius: Vector3, colours: Array, rings: int, segments: int, sway: float = 0.0) -> void:
	var unit := func(i: int, j: int) -> Vector3:
		var phi := PI * i / rings
		var theta := TAU * j / segments
		return Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
	for j in segments:
		var col := c(colours[j % colours.size()], sway)
		for i in rings:
			var corners: Array[int] = []
			for q: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var u: Vector3 = unit.call(q.x, q.y)
				var n := Vector3(u.x / radius.x, u.y / radius.y, u.z / radius.z).normalized()
				corners.append(k.vertex(centre + u * radius, n, col))
			var out: Vector3 = k.xform.basis * (unit.call(i, j) + unit.call(i + 1, j + 1))
			if i == 0:
				k.tri(corners[0], corners[1], corners[2], out)
			elif i == rings - 1:
				k.tri(corners[0], corners[1], corners[3], out)
			else:
				k.quad(corners[0], corners[1], corners[2], corners[3], out)


## A hoop of tube round `centre` in the plane across `axis`.
static func _hoop(k: MeshKit, centre: Vector3, axis: Vector3, r: float, tube: float, col: Color, segments: int) -> void:
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := axis.cross(side).normalized()
	for j in segments:
		var a0 := TAU * j / segments
		var a1 := TAU * (j + 1) / segments
		k.cylinder(centre + (side * cos(a0) + fwd * sin(a0)) * r, centre + (side * cos(a1) + fwd * sin(a1)) * r, tube, tube, col, 5, false)


# --- Ferris wheel ---------------------------------------------------------------------

static func _ferris_base(k: MeshKit) -> void:
	k.box(Vector3(0, 0.06, 0), Vector3(3.9, 0.12, 1.9), c(Color("e9dcc4")), c(Color("f6eedd")))
	for z: float in [-0.44, 0.44]:
		for x: float in [-1.3, 1.3]:
			k.cylinder(Vector3(x, 0.12, z), Vector3(0, FERRIS_AXLE, z * 0.9), 0.075, 0.06, c(WHITE), 6)
		k.cylinder(Vector3(-0.86, 0.95, z * 0.96), Vector3(0.86, 0.95, z * 0.96), 0.04, 0.04, c(WHITE), 5)
	k.cylinder(Vector3(0, FERRIS_AXLE, -0.5), Vector3(0, FERRIS_AXLE, 0.5), 0.08, 0.08, c(METAL), 8)
	# Steps up to the cabins, and a ticket booth.
	k.box(Vector3(0, 0.2, 0.62), Vector3(0.7, 0.16, 0.36), c(WOOD))
	k.box(Vector3(1.55, 0.42, 0.55), Vector3(0.46, 0.6, 0.4), c(PINK))
	k.box(Vector3(1.55, 0.5, 0.76), Vector3(0.3, 0.18, 0.02), c(DARK))
	k.sphere(Vector3(1.55, 0.74, 0.55), Vector3(0.3, 0.12, 0.26), c(CREAM), 3, 8)


## The wheel, its middle at the origin, turning about z.
static func _ferris_ring(k: MeshKit, glow: MeshKit) -> void:
	var rim := c(Color("e88aa6"))
	for z: float in [-0.28, 0.28]:
		_hoop(k, Vector3(0, 0, z), Vector3.BACK, FERRIS_R, 0.05, rim, 20)
		_hoop(k, Vector3(0, 0, z), Vector3.BACK, FERRIS_R * 0.55, 0.03, c(CREAM), 12)
		for i in FERRIS_CABS:
			var a := i * TAU / FERRIS_CABS
			k.cylinder(Vector3(cos(a), sin(a), 0) * 0.2 + Vector3(0, 0, z), Vector3(cos(a), sin(a), 0) * FERRIS_R + Vector3(0, 0, z), 0.026, 0.026, c(CREAM), 4, false)
		for i in 16:
			var a := (i + 0.5) * TAU / 16.0
			glow.sphere(Vector3(cos(a) * FERRIS_R, sin(a) * FERRIS_R, z * 1.18), Vector3.ONE * 0.05, c(BULB), 3, 5)
	for i in FERRIS_CABS:
		var a := i * TAU / FERRIS_CABS
		var at := Vector3(cos(a), sin(a), 0) * FERRIS_R
		k.cylinder(at + Vector3(0, 0, -0.3), at + Vector3(0, 0, 0.3), 0.03, 0.03, c(CREAM), 5, false)
	k.cylinder(Vector3(0, 0, -0.34), Vector3(0, 0, 0.34), 0.21, 0.21, c(GOLD), 10)
	glow.sphere(Vector3(0, 0, 0.36), Vector3(0.1, 0.1, 0.04), c(BULB), 3, 8)


## A cabin hanging from the origin.
static func _ferris_cab(k: MeshKit, i: int) -> void:
	var col := c(CAB_COLOURS[i % CAB_COLOURS.size()])
	k.cylinder(Vector3.ZERO, Vector3(0, -0.22, 0), 0.025, 0.025, c(METAL), 4)
	k.sphere(Vector3(0, -0.27, 0), Vector3(0.27, 0.1, 0.24), col.lightened(0.25), 3, 10)
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.16, 0.16]:
			k.cylinder(Vector3(x, -0.3, z), Vector3(x, -0.52, z), 0.02, 0.02, c(WHITE), 4, false)
	k.box(Vector3(0, -0.66, 0), Vector3(0.48, 0.3, 0.42), col, col.lightened(0.15))


# --- Carousel ---------------------------------------------------------------------------

static func _carousel_base(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.12, 0), 1.5, 1.5, c(LILAC), 16, true, c(Color("d8ccf2")))
	k.box(Vector3(0, 0.05, 1.5), Vector3(0.6, 0.1, 0.24), c(WOOD))


## Everything that goes round but the horses: the floor, the middle, the poles and the
## striped roof.
static func _carousel_top(k: MeshKit, glow: MeshKit) -> void:
	k.cylinder(Vector3(0, 0.12, 0), Vector3(0, 0.22, 0), 1.42, 1.42, c(Color("e9dcc4")), 16, true, c(Color("f8efe0")))
	k.cylinder(Vector3(0, 0.22, 0), Vector3(0, 2.05, 0), 0.32, 0.32, c(MINT), 10)
	for y: float in [0.6, 1.4]:
		k.cylinder(Vector3(0, y, 0), Vector3(0, y + 0.07, 0), 0.34, 0.34, c(GOLD), 10)
	for i in HORSES:
		var a := i * TAU / HORSES
		var at := Vector3(cos(a), 0, sin(a)) * HORSE_R
		k.cylinder(at + Vector3(0, 0.22, 0), at + Vector3(0, 2.05, 0), 0.028, 0.028, c(GOLD), 5, false)
	_striped_cone(k, Vector3(0, 2.05, 0), Vector3(0, 2.85, 0), 1.62, [PINK, CREAM], 12)
	for i in 12:
		var a := (i + 0.5) * TAU / 12.0
		k.sphere(Vector3(cos(a) * 1.55, 2.0, sin(a) * 1.55), Vector3(0.17, 0.1, 0.17), c(CREAM if i % 2 == 0 else PINK), 3, 6)
		glow.sphere(Vector3(cos(a + PI / 12.0) * 1.62, 2.06, sin(a + PI / 12.0) * 1.62), Vector3.ONE * 0.045, c(BULB), 3, 5)
	k.sphere(Vector3(0, 2.92, 0), Vector3.ONE * 0.1, c(GOLD), 4, 8)
	k.cylinder(Vector3(0, 2.95, 0), Vector3(0, 3.2, 0), 0.015, 0.015, c(WHITE), 4)
	k.cone(Vector3(0, 3.12, 0), Vector3(0.18, 3.16, 0), 0.05, c(ROSE), 4)


## Where horse `i` is with the top turned `turn` and `t` seconds gone: its pole, facing
## the way it goes, rising and falling.
static func horse_spot(i: int, turn: float, t: float) -> Transform3D:
	var a := i * TAU / HORSES
	var at := Basis(Vector3.UP, turn) * Vector3(cos(a), 0, sin(a)) * HORSE_R
	at.y = HORSE_Y + 0.14 * sin(t * 2.2 + i * 2.1)
	return Transform3D(Basis(Vector3.UP, turn + atan2(sin(a), -cos(a))), at)


## A prancing horse round the origin (on its pole), facing +z.
static func _horse(k: MeshKit, i: int) -> void:
	var col := c(HORSE_COLOURS[i % HORSE_COLOURS.size()])
	var mane := c(PINK if i % 2 == 0 else LILAC)
	k.sphere(Vector3.ZERO, Vector3(0.12, 0.13, 0.25), col, 5, 8)
	k.cylinder(Vector3(0, 0.06, 0.16), Vector3(0, 0.25, 0.26), 0.07, 0.06, col, 6)
	k.sphere(Vector3(0, 0.3, 0.33), Vector3(0.07, 0.075, 0.12), col, 4, 8)
	for x: float in [-1.0, 1.0]:
		k.sphere(Vector3(x * 0.055, 0.33, 0.37), Vector3.ONE * 0.016, c(DARK), 2, 4)
		k.cone(Vector3(x * 0.035, 0.36, 0.28), Vector3(x * 0.045, 0.44, 0.27), 0.025, col, 4)
		# Front legs reaching forward, back legs pushing off.
		k.cylinder(Vector3(x * 0.06, -0.04, 0.15), Vector3(x * 0.06, -0.2, 0.33), 0.035, 0.03, col, 5)
		k.cylinder(Vector3(x * 0.06, -0.05, -0.16), Vector3(x * 0.06, -0.27, -0.26), 0.035, 0.03, col, 5)
		k.sphere(Vector3(x * 0.06, -0.21, 0.34), Vector3.ONE * 0.035, c(GOLD), 2, 5)
		k.sphere(Vector3(x * 0.06, -0.28, -0.27), Vector3.ONE * 0.035, c(GOLD), 2, 5)
	for j in 3:
		k.sphere(Vector3(0, 0.17 + j * 0.07, 0.17 + j * 0.05), Vector3(0.035, 0.05, 0.04), mane, 3, 5)
	k.cone(Vector3(0, 0.03, -0.23), Vector3(0, -0.14, -0.42), 0.05, mane, 5)
	k.box(Vector3(0, 0.13, -0.02), Vector3(0.27, 0.05, 0.2), c(ROSE), c(Color("e98088")))


# --- Teacups ----------------------------------------------------------------------------

static func _teacup_base(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.1, 0), 1.5, 1.5, c(Color("e9dcc4")), 16, true, c(CREAM))
	# The big teapot in the middle.
	k.cylinder(Vector3(0, 0.16, 0), Vector3(0, 0.36, 0), 0.32, 0.28, c(WHITE), 10)
	k.sphere(Vector3(0, 0.68, 0), Vector3(0.38, 0.33, 0.38), c(SKY), 6, 12, 0.6)
	for i in 6:
		var a := i * TAU / 6.0
		k.sphere(Vector3(cos(a) * 0.3, 0.74, sin(a) * 0.3), Vector3.ONE * 0.05, c(WHITE), 2, 5)
	k.cylinder(Vector3(0, 0.96, 0), Vector3(0, 1.04, 0), 0.2, 0.16, c(SKY), 10)
	k.sphere(Vector3(0, 1.08, 0), Vector3.ONE * 0.07, c(GOLD), 3, 6)
	k.cylinder(Vector3(0.3, 0.6, 0), Vector3(0.62, 0.86, 0), 0.08, 0.045, c(SKY), 6)
	for j in 4:
		var a0 := -PI * 0.5 + j * PI / 4.0
		var a1 := -PI * 0.5 + (j + 1) * PI / 4.0
		k.cylinder(Vector3(-0.36 - cos(a0) * 0.18, 0.68 + sin(a0) * 0.18, 0), Vector3(-0.36 - cos(a1) * 0.18, 0.68 + sin(a1) * 0.18, 0), 0.035, 0.035, c(SKY), 5)


## The turning floor the cups ride on (a ring round the teapot).
static func _teacup_floor(k: MeshKit) -> void:
	k.cylinder(Vector3(0, 0.1, 0), Vector3(0, 0.15, 0), 1.45, 1.45, c(MINT), 16, true, c(Color("c4e8de")))
	for i in 12:
		var a := (i + 0.5) * TAU / 12.0
		k.sphere(Vector3(cos(a) * 1.25, 0.16, sin(a) * 1.25), Vector3(0.08, 0.02, 0.08), c(WHITE), 2, 5)


static func cup_spot(i: int, turn: float, t: float) -> Transform3D:
	var a := turn + i * TAU / CUPS
	return Transform3D(Basis(Vector3.UP, t * CUP_SPIN + i * 1.3), Vector3(cos(a) * CUP_R, 0.15, -sin(a) * CUP_R))


## A teacup on its saucer, standing on the origin.
static func _teacup(k: MeshKit, i: int) -> void:
	var col := c(CUP_COLOURS[i % CUP_COLOURS.size()])
	k.cylinder(Vector3.ZERO, Vector3(0, 0.05, 0), 0.38, 0.38, c(WHITE), 12)
	k.cylinder(Vector3(0, 0.05, 0), Vector3(0, 0.4, 0), 0.24, 0.34, col, 12, false)
	k.cylinder(Vector3(0, 0.4, 0), Vector3(0, 0.44, 0), 0.34, 0.345, c(WHITE), 12, false)
	k.cylinder(Vector3(0, 0.08, 0), Vector3(0, 0.36, 0), 0.22, 0.31, col, 12, true, c(Color("6b4f3a")))
	for j in 4:
		var a := j * TAU / 4.0 + 0.4
		k.sphere(Vector3(cos(a) * 0.3, 0.24, sin(a) * 0.3), Vector3(0.04, 0.04, 0.04), c(WHITE), 2, 5)
	for j in 3:
		var a0 := -PI * 0.4 + j * PI * 0.8 / 3.0
		var a1 := -PI * 0.4 + (j + 1) * PI * 0.8 / 3.0
		k.cylinder(Vector3(0.32 + cos(a0) * 0.1, 0.25 + sin(a0) * 0.1, 0), Vector3(0.32 + cos(a1) * 0.1, 0.25 + sin(a1) * 0.1, 0), 0.03, 0.03, col, 5)


# --- Hot air balloon ---------------------------------------------------------------------

static func _balloon_base(k: MeshKit) -> void:
	k.box(Vector3(0, 0.05, 0), Vector3(1.3, 0.1, 1.3), c(WOOD), c(Color("c89a6c")))
	for x: float in [-0.56, 0.56]:
		for z: float in [-0.56, 0.56]:
			k.cylinder(Vector3(x, 0.1, z), Vector3(x, 0.24, z), 0.035, 0.03, c(Color("8a6040")), 5)
	k.sphere(Vector3(0.5, 0.18, 0.32), Vector3(0.12, 0.09, 0.1), c(Color("c8a878")), 3, 6)
	k.sphere(Vector3(-0.48, 0.18, -0.36), Vector3(0.12, 0.09, 0.1), c(Color("c8a878")), 3, 6)


## The basket and balloon, which bob on their ropes.
static func _balloon_up(k: MeshKit, glow: MeshKit) -> void:
	var wicker := c(Color("c8955a"))
	k.box(Vector3(0, 0.46, 0), Vector3(0.62, 0.42, 0.62), wicker, c(Color("7a5236")))
	k.box(Vector3(0, 0.68, 0), Vector3(0.68, 0.06, 0.68), c(Color("9c6b3f")))
	for x: float in [-0.29, 0.29]:
		for z: float in [-0.29, 0.29]:
			k.cylinder(Vector3(x, 0.7, z), Vector3(x * 1.2, 1.6, z * 1.2), 0.015, 0.015, c(CREAM), 3, false)
			k.cylinder(Vector3(x, 0.26, z), Vector3(x * 1.9, 0.22, z * 1.9), 0.012, 0.012, c(CREAM), 3, false)
	k.cylinder(Vector3(0, 0.72, 0), Vector3(0, 0.95, 0), 0.08, 0.07, c(METAL), 6)
	glow.cone(Vector3(0, 0.95, 0), Vector3(0, 1.15, 0), 0.06, c(Color("ffb35a")), 5)
	k.cylinder(Vector3(0, 1.55, 0), Vector3(0, 1.8, 0), 0.34, 0.55, c(ROSE), 12, false)
	_striped_ball(k, Vector3(0, 2.68, 0), Vector3(1.0, 1.08, 1.0), [ROSE, CREAM, LEMON, SKY], 8, 12)


# --- Lucky cat ---------------------------------------------------------------------------

static func _lucky_cat(k: MeshKit) -> void:
	k.rounded_box(Vector3(0, 0.1, 0), Vector3(0.86, 0.2, 0.86), c(ROSE), 0.35)
	for x: float in [-0.4, 0.4]:
		for z: float in [-0.4, 0.4]:
			k.sphere(Vector3(x, 0.08, z), Vector3.ONE * 0.05, c(GOLD), 2, 5)
	k.sphere(Vector3(0, 0.56, 0), Vector3(0.36, 0.38, 0.32), c(WHITE), 6, 12, 0.6)
	k.sphere(Vector3(0.14, 0.24, 0.24), Vector3(0.1, 0.07, 0.1), c(WHITE), 3, 6)
	k.sphere(Vector3(-0.14, 0.24, 0.24), Vector3(0.1, 0.07, 0.1), c(WHITE), 3, 6)
	k.sphere(Vector3(0.0, 0.3, -0.32), Vector3(0.09, 0.08, 0.12), c(WHITE), 3, 6)
	k.cylinder(Vector3(0, 0.84, 0), Vector3(0, 0.9, 0), 0.27, 0.26, c(ROSE), 12)
	k.sphere(Vector3(0, 0.8, 0.27), Vector3.ONE * 0.07, c(GOLD), 4, 8)
	k.sphere(Vector3(0, 1.17, 0.02), Vector3(0.38, 0.32, 0.32), c(WHITE), 6, 12, 0.5)
	for x: float in [-1.0, 1.0]:
		k.cone(Vector3(x * 0.22, 1.36, 0.0), Vector3(x * 0.29, 1.6, 0.03), 0.11, c(WHITE), 6)
		k.cone(Vector3(x * 0.22, 1.37, 0.06), Vector3(x * 0.28, 1.55, 0.08), 0.06, c(PINK), 5)
		k.sphere(Vector3(x * 0.13, 1.2, 0.31), Vector3(0.045, 0.065, 0.03), c(DARK), 3, 6)
		k.sphere(Vector3(x * 0.23, 1.09, 0.27), Vector3(0.06, 0.04, 0.03), c(PINK), 3, 6)
	k.sphere(Vector3(0, 1.11, 0.335), Vector3(0.035, 0.028, 0.025), c(PINK), 3, 6)
	# The other paw holds a gold coin to its chest.
	k.sphere(Vector3(0.17, 0.64, 0.27), Vector3(0.1, 0.12, 0.09), c(WHITE), 4, 8)
	k.sphere(Vector3(0.06, 0.6, 0.33), Vector3(0.14, 0.1, 0.03), c(GOLD), 4, 10)


## The beckoning paw, from its shoulder at the origin.
static func _lucky_paw(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(-0.05, 0.34, 0.05), 0.09, 0.085, c(WHITE), 8)
	k.sphere(Vector3(-0.05, 0.41, 0.06), Vector3(0.11, 0.11, 0.1), c(WHITE), 4, 8)
	k.sphere(Vector3(-0.05, 0.41, 0.15), Vector3(0.06, 0.05, 0.02), c(PINK), 3, 6)


# --- Carts and stalls --------------------------------------------------------------------

static func _ice_cream_cart(k: MeshKit) -> void:
	for z: float in [-0.34, 0.34]:
		k.cylinder(Vector3(-0.45, 0.24, z), Vector3(-0.45, 0.24, z * 1.15), 0.24, 0.24, c(WHITE), 12)
		k.cylinder(Vector3(-0.45, 0.24, z * 1.15), Vector3(-0.45, 0.24, z * 1.18), 0.07, 0.07, c(PINK), 6)
		k.cylinder(Vector3(0.55, 0.32, z * 0.8), Vector3(0.55, 0.0, z * 0.8), 0.04, 0.04, c(METAL), 5)
	k.box(Vector3(0, 0.6, 0), Vector3(1.3, 0.56, 0.6), c(MINT))
	k.box(Vector3(0, 0.45, 0), Vector3(1.32, 0.1, 0.62), c(PINK))
	k.box(Vector3(0, 0.915, 0), Vector3(1.42, 0.07, 0.68), c(CREAM))
	k.cylinder(Vector3(0.28, 0.64, 0.3), Vector3(0.28, 0.64, 0.32), 0.17, 0.17, c(CREAM), 10)
	k.sphere(Vector3(0.28, 0.68, 0.33), Vector3(0.1, 0.08, 0.02), c(PINK), 3, 8)
	k.cone(Vector3(0.28, 0.6, 0.33), Vector3(0.28, 0.48, 0.33), 0.06, c(Color("e8b06a")), 5)
	for i in 3:
		var at := Vector3(-0.32 + i * 0.3, 0.95, 0.08)
		k.cylinder(at, at + Vector3(0, 0.05, 0), 0.12, 0.12, c(WHITE), 8)
		k.sphere(at + Vector3(0, 0.06, 0), Vector3(0.1, 0.06, 0.1), c([PINK, CREAM, Color("c6905a")][i]), 3, 8)
	for z: float in [-0.25, 0.25]:
		k.cylinder(Vector3(0.65, 0.78, z), Vector3(0.88, 0.98, z), 0.03, 0.03, c(METAL), 5)
	k.cylinder(Vector3(0.88, 0.98, -0.27), Vector3(0.88, 0.98, 0.27), 0.04, 0.04, c(ROSE), 6)
	# A striped sunshade, and a giant cone on top.
	k.cylinder(Vector3(-0.38, 0.95, -0.12), Vector3(-0.38, 2.02, -0.12), 0.03, 0.03, c(WHITE), 5)
	_striped_cone(k, Vector3(-0.38, 1.82, -0.12), Vector3(-0.38, 2.12, -0.12), 0.62, [PINK, CREAM], 10)
	k.sphere(Vector3(-0.38, 2.14, -0.12), Vector3.ONE * 0.05, c(PINK), 3, 6)
	k.cylinder(Vector3(0.45, 0.95, -0.12), Vector3(0.45, 1.05, -0.12), 0.03, 0.03, c(WHITE), 5)
	k.cone(Vector3(0.45, 1.42, -0.12), Vector3(0.45, 1.02, -0.12), 0.14, c(Color("e8b06a")), 8)
	k.sphere(Vector3(0.45, 1.5, -0.12), Vector3(0.16, 0.13, 0.16), c(PINK), 4, 8)
	k.sphere(Vector3(0.45, 1.68, -0.12), Vector3(0.14, 0.12, 0.14), c(MINT), 4, 8)
	k.sphere(Vector3(0.45, 1.82, -0.12), Vector3.ONE * 0.045, c(ROSE), 3, 6)


static func _popcorn_cart(k: MeshKit) -> void:
	for x: float in [-0.36, 0.36]:
		k.cylinder(Vector3(x, 0.2, 0.0), Vector3(x * 1.1, 0.2, 0.0), 0.2, 0.2, c(WHITE), 10)
		k.cylinder(Vector3(x * 1.1, 0.2, 0.0), Vector3(x * 1.13, 0.2, 0.0), 0.06, 0.06, c(ROSE), 6)
	k.box(Vector3(0, 0.5, 0), Vector3(0.66, 0.42, 0.5), c(ROSE))
	for x: float in [-0.2, 0.0, 0.2]:
		k.box(Vector3(x, 0.5, 0.252), Vector3(0.07, 0.42, 0.01), c(WHITE))
	k.box(Vector3(0, 0.74, 0), Vector3(0.7, 0.06, 0.54), c(LEMON))
	for x: float in [-0.29, 0.29]:
		for z: float in [-0.21, 0.21]:
			k.cylinder(Vector3(x, 0.77, z), Vector3(x, 1.18, z), 0.02, 0.02, c(WHITE), 4, false)
	k.box(Vector3(0, 0.83, 0), Vector3(0.54, 0.12, 0.38), c(Color("fbe7b0")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 16:
		var at := Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(0.9, 1.0), rng.randf_range(-0.15, 0.15))
		k.sphere(at, Vector3.ONE * rng.randf_range(0.05, 0.075), c(Color("fff4d6") if i % 3 else Color("f6dc8a")), 3, 5, 0.0, 0.4, i)
	_striped_cone(k, Vector3(0, 1.18, 0), Vector3(0, 1.46, 0), 0.5, [ROSE, WHITE], 4, PI * 0.25)
	k.sphere(Vector3(0, 1.5, 0), Vector3.ONE * 0.06, c(GOLD), 3, 6)


static func _candy_floss(k: MeshKit) -> void:
	k.box(Vector3(0, 0.36, 0), Vector3(0.74, 0.72, 0.52), c(LILAC))
	k.box(Vector3(0, 0.22, 0), Vector3(0.76, 0.1, 0.54), c(PINK))
	k.box(Vector3(0, 0.75, 0), Vector3(0.8, 0.06, 0.58), c(CREAM))
	for x: float in [-0.33, 0.33]:
		k.cylinder(Vector3(x, 0.78, -0.22), Vector3(x, 1.4, -0.22), 0.025, 0.025, c(WHITE), 4)
	_striped_cone(k, Vector3(0, 1.38, -0.05), Vector3(0, 1.63, -0.05), 0.56, [PINK, WHITE], 4, PI * 0.25)
	k.cylinder(Vector3(0, 0.78, -0.1), Vector3(0, 0.89, -0.1), 0.18, 0.2, c(METAL), 10)
	var fluff := [Color("f6b6d0"), Color("bfe0f4"), Color("d8c4f0")]
	for i in 3:
		var at := Vector3(-0.22 + i * 0.22, 0.78, 0.14)
		k.cylinder(at, at + Vector3(0, 0.3, 0), 0.012, 0.012, c(WHITE), 4)
		k.sphere(at + Vector3(0, 0.38, 0), Vector3(0.12, 0.13, 0.12), c(fluff[i], 0.25), 4, 7, 0.0, 0.35, i)


static func _balloon_bunch(k: MeshKit) -> void:
	k.cylinder(Vector3.ZERO, Vector3(0, 0.26, 0), 0.2, 0.16, c(Color("c4def0")), 10)
	k.cylinder(Vector3(0, 0.2, 0), Vector3(0, 0.24, 0), 0.165, 0.165, c(PINK), 10, false)
	var colours := [ROSE, LEMON, SKY, MINT, LILAC, PEACH, PINK]
	for i in colours.size():
		var a := i * TAU / colours.size() + 0.3
		var r := 0.0 if i == 0 else 0.3
		var top := Vector3(cos(a) * r, 1.65 + 0.2 * sin(i * 2.3), sin(a) * r)
		var string_top := c(CREAM, 0.5)
		k.cylinder(Vector3(0, 0.26, 0), top - Vector3(0, 0.22, 0), 0.008, 0.008, c(CREAM), 3, false, string_top)
		k.sphere(top, Vector3(0.17, 0.21, 0.17), c(colours[i], 0.5), 5, 8)
		k.cone(top - Vector3(0, 0.18, 0), top - Vector3(0, 0.25, 0), 0.03, c(colours[i], 0.5), 4)


static func _strength_tester(k: MeshKit) -> void:
	k.box(Vector3(0, 0.06, 0), Vector3(0.8, 0.12, 0.8), c(WOOD), c(Color("c89a6c")))
	k.cylinder(Vector3(0, 0.12, 0.18), Vector3(0, 0.2, 0.18), 0.17, 0.17, c(ROSE), 10)
	k.box(Vector3(0, 1.45, -0.15), Vector3(0.18, 2.5, 0.12), c(CREAM))
	var bands := [ROSE, PEACH, LEMON, MINT, SKY]
	for i in bands.size():
		k.box(Vector3(0, 0.55 + i * 0.42, -0.088), Vector3(0.19, 0.34, 0.01), c(bands[i]))
	k.box(Vector3(0, 0.9, -0.07), Vector3(0.12, 0.08, 0.06), c(ROSE))
	k.sphere(Vector3(0, 2.78, -0.15), Vector3(0.17, 0.13, 0.17), c(GOLD), 4, 10, 0.5)
	k.cylinder(Vector3(0, 2.7, -0.15), Vector3(0, 2.66, -0.15), 0.17, 0.17, c(GOLD), 10)
	k.sphere(Vector3(0, 2.94, -0.15), Vector3.ONE * 0.05, c(ROSE), 3, 6)
	k.cylinder(Vector3(0.3, 0.12, 0.15), Vector3(0.17, 1.0, 0.0), 0.03, 0.03, c(WOOD), 5)
	k.cylinder(Vector3(0.08, 1.0, 0.0), Vector3(0.27, 1.05, 0.0), 0.09, 0.09, c(ROSE), 8)


# --- Statues -----------------------------------------------------------------------------

## A giant rubber duck, in a puddle.
static func _rubber_duck(k: MeshKit) -> void:
	var yellow := c(Color("f6d34a"))
	k.cylinder(Vector3.ZERO, Vector3(0, 0.03, 0), 0.98, 0.98, c(Color("a8d8ec")), 16)
	k.sphere(Vector3(0, 0.55, -0.1), Vector3(0.72, 0.52, 0.86), yellow, 6, 14, 0.5)
	k.cone(Vector3(0, 0.72, -0.72), Vector3(0, 1.05, -0.98), 0.24, yellow, 8)
	for x: float in [-1.0, 1.0]:
		k.sphere(Vector3(x * 0.64, 0.64, -0.15), Vector3(0.12, 0.3, 0.46), c(Color("eec53c")), 4, 8)
		k.sphere(Vector3(x * 0.2, 1.44, 0.71), Vector3.ONE * 0.065, c(DARK), 3, 6)
		k.sphere(Vector3(x * 0.18, 1.47, 0.765), Vector3.ONE * 0.02, c(WHITE), 2, 4)
	k.sphere(Vector3(0, 1.3, 0.38), Vector3(0.44, 0.42, 0.42), yellow, 6, 12, 0.4)
	k.sphere(Vector3(0, 1.2, 0.8), Vector3(0.22, 0.08, 0.18), c(Color("f29a3a")), 4, 10)
	k.sphere(Vector3(0, 1.13, 0.76), Vector3(0.17, 0.05, 0.13), c(Color("e8862e")), 3, 8)


## After Easter Island's moai: a long stone face under a red topknot.
static func _moai(k: MeshKit) -> void:
	var stone := c(Color("8f8a80"))
	var dark := c(Color("76716a"))
	k.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.8), c(Color("a8a296")))
	k.box(Vector3(0, 0.42, 0), Vector3(0.7, 0.66, 0.46), stone)
	k.box(Vector3(0, 1.32, 0.02), Vector3(0.6, 1.2, 0.5), stone, c(Color("8fae6e")))
	k.box(Vector3(0, 1.62, 0.27), Vector3(0.62, 0.13, 0.14), dark)
	for x: float in [-1.0, 1.0]:
		k.box(Vector3(x * 0.15, 1.5, 0.27), Vector3(0.17, 0.08, 0.04), c(Color("5f5a52")))
		k.box(Vector3(x * 0.31, 1.3, 0.0), Vector3(0.05, 0.62, 0.15), dark)
	k.box(Vector3(0, 1.36, 0.3), Vector3(0.15, 0.45, 0.16), stone)
	k.box(Vector3(0, 1.15, 0.31), Vector3(0.24, 0.08, 0.16), dark)
	k.box(Vector3(0, 0.98, 0.28), Vector3(0.3, 0.07, 0.07), dark)
	k.box(Vector3(0, 0.82, 0.19), Vector3(0.5, 0.16, 0.3), stone)
	k.cylinder(Vector3(0, 1.92, 0), Vector3(0, 2.14, 0), 0.28, 0.25, c(Color("b0654e")), 10)


## After the Great Sphinx, but a cat: lying down in a striped headdress.
static func _sphinx_cat(k: MeshKit) -> void:
	var sand := c(Color("e3c38a"))
	var shade := c(Color("d2ad72"))
	k.box(Vector3(0, 0.08, 0), Vector3(1.9, 0.16, 2.9), c(Color("cfb388")), c(Color("e2cba2")))
	k.sphere(Vector3(0, 0.56, -0.45), Vector3(0.55, 0.4, 0.85), sand, 6, 12, 0.5)
	for x: float in [-1.0, 1.0]:
		k.sphere(Vector3(x * 0.32, 0.5, -0.82), Vector3(0.3, 0.32, 0.4), sand, 5, 10)
		k.sphere(Vector3(x * 0.28, 0.28, 0.62), Vector3(0.15, 0.11, 0.42), sand, 4, 8)
		k.cone(Vector3(x * 0.22, 1.56, 0.28), Vector3(x * 0.3, 1.82, 0.3), 0.1, sand, 5)
		k.box(Vector3(x * 0.13, 1.33, 0.63), Vector3(0.13, 0.045, 0.03), c(DARK))
		# The headdress hangs down beside the face in stripes.
		for j in 5:
			k.box(Vector3(x * 0.37, 1.28 - j * 0.11, 0.4), Vector3(0.1, 0.11, 0.3), c(GOLD if j % 2 == 0 else Color("4f7fb8")))
	k.sphere(Vector3(0, 0.7, 0.22), Vector3(0.42, 0.42, 0.34), sand, 5, 10)
	k.sphere(Vector3(0, 1.3, 0.34), Vector3(0.35, 0.33, 0.31), sand, 6, 12, 0.4)
	_striped_ball(k, Vector3(0, 1.42, 0.28), Vector3(0.4, 0.29, 0.36), [GOLD, Color("4f7fb8")], 5, 14)
	k.sphere(Vector3(0, 1.22, 0.64), Vector3.ONE * 0.04, shade, 3, 5)
	for j in 5:
		var a := j * 0.45
		k.sphere(Vector3(0.62 + sin(a) * 0.1, 0.2, -0.9 + j * 0.28), Vector3(0.07, 0.06, 0.16), sand, 3, 6)


## After the Statue of Liberty: small and green, torch held high (lit at night).
static func _torch_statue(k: MeshKit, glow: MeshKit) -> void:
	var copper := c(Color("86c4ae"))
	var deep := c(Color("6aa892"))
	k.box(Vector3(0, 0.46, 0), Vector3(0.84, 0.92, 0.84), c(Color("d8cfbd")), c(Color("e6dfd0")))
	k.box(Vector3(0, 0.96, 0), Vector3(0.94, 0.08, 0.94), c(Color("c9bfa9")))
	k.cylinder(Vector3(0, 1.0, 0), Vector3(0, 1.92, 0), 0.28, 0.17, copper, 10)
	k.cylinder(Vector3(-0.05, 1.0, 0.1), Vector3(0.08, 1.75, 0.13), 0.14, 0.06, deep, 6)
	k.sphere(Vector3(0, 2.13, 0), Vector3.ONE * 0.21, copper, 6, 10)
	k.cylinder(Vector3(0, 2.2, 0), Vector3(0, 2.26, 0), 0.215, 0.21, deep, 10)
	for i in 7:
		var a := deg_to_rad(-75.0 + i * 25.0)
		var dir := Vector3(sin(a) * 0.85, 0.55, cos(a) * 0.6).normalized()
		k.cone(Vector3(0, 2.25, 0) + dir * 0.17, Vector3(0, 2.25, 0) + dir * 0.36, 0.035, copper, 4)
	k.cylinder(Vector3(0.15, 1.86, 0), Vector3(0.24, 2.45, 0.03), 0.065, 0.055, copper, 6)
	k.cylinder(Vector3(0.24, 2.45, 0.03), Vector3(0.25, 2.62, 0.03), 0.04, 0.04, deep, 6)
	k.cylinder(Vector3(0.25, 2.62, 0.03), Vector3(0.25, 2.72, 0.03), 0.05, 0.1, copper, 8)
	glow.cone(Vector3(0.25, 2.72, 0.03), Vector3(0.25, 2.98, 0.03), 0.085, c(Color("ffcf5e")), 7)
	k.cylinder(Vector3(-0.15, 1.84, 0), Vector3(-0.2, 1.62, 0.14), 0.06, 0.05, copper, 6)
	_with([k], Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(-0.2, 1.68, 0.19)), func(): k.box(Vector3.ZERO, Vector3(0.16, 0.25, 0.05), deep))


## After the Leaning Tower of Pisa: white tiers of arches, tipped over a little.
static func _leaning_tower(k: MeshKit) -> void:
	var marble := c(Color("f4efe6"))
	var band := c(Color("e2d9c8"))
	var arch := c(Color("a8a091"))
	k.box(Vector3(0, 0.06, 0), Vector3(1.8, 0.12, 1.8), c(Color("d8d0c0")), c(Color("e6dfd2")))
	var saved := k.xform
	k.xform = k.xform * Transform3D(Basis(Vector3.BACK, deg_to_rad(-5.5)), Vector3(0, 0.12, 0))
	var y := 0.0
	for tier in 7:
		var r := 0.62 if tier < 6 else 0.44
		var h := 0.62 if tier == 0 else (0.5 if tier < 6 else 0.45)
		k.cylinder(Vector3(0, y, 0), Vector3(0, y + h, 0), r, r, marble, 14, tier == 6)
		k.cylinder(Vector3(0, y + h - 0.03, 0), Vector3(0, y + h + 0.04, 0), r + 0.06, r + 0.06, band, 14)
		var arches := 10 if tier < 6 else 6
		for j in arches:
			var a := (j + 0.5 * (tier % 2)) * TAU / arches
			var at := Vector3(cos(a), 0, sin(a)) * (r + 0.005) + Vector3(0, y + h * 0.48, 0)
			var keep := k.xform
			k.xform = k.xform * Transform3D(Basis(Vector3.UP, -a + PI * 0.5), at)
			k.box(Vector3.ZERO, Vector3(0.12 if tier < 6 else 0.14, h * 0.5, 0.04), arch)
			k.sphere(Vector3(0, h * 0.25, 0), Vector3(0.06 if tier < 6 else 0.07, 0.05, 0.02), arch, 2, 5)
			k.xform = keep
		y += h + 0.04
	k.sphere(Vector3(0, y, 0), Vector3(0.4, 0.16, 0.4), band, 3, 12)
	k.xform = saved


## After Big Ben: a clock tower with a lit clock face on each side.
static func _clock_tower(k: MeshKit, glow: MeshKit) -> void:
	var stone := c(Color("e9dcc0"))
	var trim := c(Color("c9b48e"))
	k.box(Vector3(0, 0.08, 0), Vector3(1.7, 0.16, 1.7), c(Color("a8a296")), c(Color("bcb6aa")))
	k.box(Vector3(0, 1.7, 0), Vector3(1.2, 3.1, 1.2), stone)
	for y: float in [0.5, 1.5, 2.55, 3.22]:
		k.box(Vector3(0, y, 0), Vector3(1.28, 0.1, 1.28), trim)
	for x: float in [-0.6, 0.6]:
		for z: float in [-0.6, 0.6]:
			k.cone(Vector3(x, 3.27, z), Vector3(x, 3.68, z), 0.1, trim, 4)
	for side in 4:
		var keep := k.xform
		var glow_keep := glow.xform
		var t := Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3.ZERO)
		k.xform = k.xform * t
		glow.xform = glow.xform * t
		k.cylinder(Vector3(0, 2.92, 0.6), Vector3(0, 2.92, 0.63), 0.41, 0.41, c(GOLD), 14)
		glow.cylinder(Vector3(0, 2.92, 0.63), Vector3(0, 2.92, 0.645), 0.36, 0.36, c(Color("f8f0d8")), 14)
		k.box(Vector3(0.09, 2.92, 0.652), Vector3(0.2, 0.045, 0.01), c(DARK))
		k.box(Vector3(0, 3.05, 0.654), Vector3(0.04, 0.27, 0.01), c(DARK))
		for j in 12:
			var a := j * TAU / 12.0
			k.box(Vector3(cos(a) * 0.3, 2.92 + sin(a) * 0.3, 0.65), Vector3.ONE * 0.035 * Vector3(1, 1, 0.3), c(DARK))
		k.box(Vector3(0, 1.1, 0.605), Vector3(0.28, 0.5, 0.02), c(Color("8a7a66")))
		k.box(Vector3(0, 3.62, 0.5), Vector3(0.42, 0.42, 0.02), c(Color("5a5048")))
		k.xform = keep
		glow.xform = glow_keep
	k.box(Vector3(0, 3.62, 0), Vector3(1.0, 0.7, 1.0), stone)
	var roof := k.xform
	k.xform = k.xform * Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.ZERO)
	k.cone(Vector3(0, 3.97, 0), Vector3(0, 5.0, 0), 0.82, c(Color("6f8fa0")), 4)
	k.xform = roof
	k.cylinder(Vector3(0, 4.95, 0), Vector3(0, 5.3, 0), 0.025, 0.015, c(GOLD), 4)
	k.sphere(Vector3(0, 5.0, 0), Vector3.ONE * 0.06, c(GOLD), 3, 6)
