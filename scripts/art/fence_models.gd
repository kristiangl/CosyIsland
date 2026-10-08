class_name FenceModels
extends RefCounted
## Fences that join up. A fence fills one tile and is built from arms reaching out from
## the middle of the tile to the sides it joins (World.fence_key works them out from the
## fences beside it): two opposite arms make a straight run, two at right angles a corner
## (the arms meet in a post, or overlap in the corner for the solid styles, like a mitre),
## three a T and four a crossing. An arm with nothing beside it is a free end, finished
## off with a post. Posts also stand in the middle of every other tile of a straight run.
## Gates are always straight: a gateway with its two leaves swung open, to walk through.
##
## Styles: "picket" (white-wood pickets on two rails), "palisade" (pointed stakes, like
## KayKit's wooden fence), "stone" (a low wall of rounded stones with a capstone) and
## "iron" (black railings on a stone footing, with stone pillars).

const N := 1
const E := 2
const S := 4
const W := 8
const SIDES := [N, E, S, W]
## Where the repeated parts (pickets, stakes, bars) sit along an arm: the middles of
## eighth-tiles, so runs keep the same spacing from one tile to the next.
const SPOTS := [0.0625, 0.1875, 0.3125, 0.4375]

const PICKET := Color("eccaa2")
const RAIL := Color("b08463")
const POST := Color("d4a77e")
const STAKE := Color("a8604a")
const STAKE_DARK := Color("8f4f3c")
const STONE := Color("98a0a3")
const STONE_DARK := Color("7f888c")
const CAPSTONE := Color("aeb5b7")
const IRON := Color("2e2e36")
const PILLAR := Color("8a9397")
const PILLAR_TOP := Color("a3abae")


## Adds a fence tile. `arms`: the sides it reaches across to (N, E, S, W bits); `links`:
## those with a fence beside them (the rest are free ends); `post`: a post in the middle
## of a straight run.
static func build(k: MeshKit, style: String, arms: int, links: int, post: bool, gate: bool) -> void:
	if gate:
		_gate(k, style, arms)
		return
	var straight := arms == (E | W) or arms == (N | S)
	var centre := has_centre(style, straight, post)
	for side: int in SIDES:
		if arms & side:
			k.xform = Transform3D(arm_basis(side), Vector3.ZERO)
			_arm(k, style, links & side == 0, centre, side == E or side == S)
	k.xform = Transform3D.IDENTITY
	if centre:
		_centre(k, style, Vector3.ZERO, straight)


## Points an arm built along +x towards a side. West and south arms are mirror images
## rather than turned round, so a straight run's two halves keep their backs on the same
## side (north for east-west runs, west for north-south ones).
static func arm_basis(side: int) -> Basis:
	match side:
		N:
			return Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
		S:
			return Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(1, 0, 0))
		W:
			return Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, 1))
	return Basis.IDENTITY


## Whether a style puts something in the middle of the tile: a post where the fence turns
## or meets another, and on every other tile of a straight run if it has posts at all.
static func has_centre(style: String, straight: bool, post: bool) -> bool:
	if not straight or style == "stone":
		return true
	return post and style in ["picket", "iron"]


## One arm, built along +x from the middle (0) to the edge of the tile (0.5). `lead`: it
## points east or south, so it lays anything shared with the next tile.
static func _arm(k: MeshKit, style: String, free: bool, centre: bool, lead: bool) -> void:
	var reach := 0.46 if free else 0.5
	match style:
		"palisade":
			var heights := [0.82, 0.88, 0.79, 0.85]
			for i in SPOTS.size():
				var t: float = SPOTS[i]
				var h: float = heights[i]
				var col := MeshKit.lin(STAKE if i % 2 == 0 else STAKE_DARK)
				k.box(Vector3(t, h * 0.5, 0), Vector3(0.118, h, 0.09), col)
				_point(k, Vector3(t, h, 0), 0.059, 0.045, 0.11, col)
			# A batten along the back, holding the stakes together.
			k.box(Vector3(reach * 0.5, 0.3, -0.055), Vector3(reach, 0.06, 0.025), MeshKit.lin(STAKE_DARK))
		"stone":
			# Two courses of rounded stones, the top one sitting across the joints below.
			for i in 2:
				var t := 0.125 + i * 0.25
				k.rounded_box(Vector3(t, 0.11, 0), Vector3(0.25, 0.22, 0.3), MeshKit.lin(STONE if i == 0 else STONE_DARK), 0.5)
			k.rounded_box(Vector3(0.25, 0.3, 0), Vector3(0.25, 0.17, 0.26), MeshKit.lin(CAPSTONE), 0.6)
			# The stone over the joint with the next tile: laid by the east or south one.
			if lead and not free:
				k.rounded_box(Vector3(0.5, 0.3, 0), Vector3(0.25, 0.17, 0.26), MeshKit.lin(STONE), 0.6)
		"iron":
			k.box(Vector3(reach * 0.5, 0.05, 0), Vector3(reach, 0.1, 0.17), MeshKit.lin(PILLAR))
			for y: float in [0.22, 0.7]:
				k.box(Vector3(reach * 0.5, y, 0), Vector3(reach, 0.03, 0.025), MeshKit.lin(IRON))
			for t: float in SPOTS:
				if (centre and t < 0.12) or (free and t > 0.33):
					continue
				k.cylinder(Vector3(t, 0.1, 0), Vector3(t, 0.78, 0), 0.013, 0.013, MeshKit.lin(IRON), 5, false)
				k.cone(Vector3(t, 0.78, 0), Vector3(t, 0.86, 0), 0.03, MeshKit.lin(IRON), 4)
			if free:
				_centre(k, style, Vector3(0.41, 0, 0))
		_:
			for y: float in [0.2, 0.47]:
				k.box(Vector3(reach * 0.5, y, 0), Vector3(reach, 0.055, 0.03), MeshKit.lin(RAIL))
			for t: float in SPOTS:
				if (centre and t < 0.1) or (free and t > 0.4):
					continue
				k.box(Vector3(t, 0.3, 0), Vector3(0.075, 0.6, 0.04), MeshKit.lin(PICKET))
				_point(k, Vector3(t, 0.6, 0), 0.0375, 0.02, 0.08, MeshKit.lin(PICKET))
			if free:
				_centre(k, style, Vector3(0.44, 0, 0))


## The post (or corner stake, or stones) at `at`; `straight` if the fence runs on
## through it.
static func _centre(k: MeshKit, style: String, at: Vector3, straight := false) -> void:
	match style:
		"palisade":
			k.box(at + Vector3(0, 0.45, 0), Vector3(0.13, 0.9, 0.13), MeshKit.lin(STAKE_DARK))
			_point(k, at + Vector3(0, 0.9, 0), 0.065, 0.065, 0.12, MeshKit.lin(STAKE_DARK))
		"stone":
			# On a straight run just the top-course stone over the middle joint; where the
			# wall turns, a corner block.
			if not straight:
				k.rounded_box(at + Vector3(0, 0.12, 0), Vector3(0.3, 0.24, 0.3), MeshKit.lin(STONE_DARK), 0.5)
			k.rounded_box(at + Vector3(0, 0.3, 0), Vector3(0.25, 0.17, 0.26), MeshKit.lin(STONE), 0.6)
		"iron":
			k.box(at + Vector3(0, 0.48, 0), Vector3(0.17, 0.96, 0.17), MeshKit.lin(PILLAR))
			k.box(at + Vector3(0, 0.99, 0), Vector3(0.21, 0.06, 0.21), MeshKit.lin(PILLAR_TOP))
		_:
			k.box(at + Vector3(0, 0.37, 0), Vector3(0.1, 0.74, 0.1), MeshKit.lin(POST))
			_point(k, at + Vector3(0, 0.74, 0), 0.05, 0.05, 0.1, MeshKit.lin(POST))


## A gateway across the tile, its two leaves swung open towards the south (or east).
static func _gate(k: MeshKit, style: String, arms: int) -> void:
	var turn := PI * 0.5 if arms == (N | S) else 0.0
	var base := Transform3D(Basis(Vector3.UP, turn), Vector3.ZERO)
	k.xform = base
	var iron := style == "iron"
	if iron:
		for x: float in [-0.41, 0.41]:
			_centre(k, "iron", Vector3(x, 0, 0))
		# An arch of iron over the top.
		var prev := Vector3(-0.33, 0.86, 0)
		for i in range(1, 9):
			var x := -0.33 + 0.66 * i / 8.0
			var p := Vector3(x, 0.86 + 0.16 * (1.0 - pow(x / 0.33, 2.0)), 0)
			k.cylinder(prev, p, 0.016, 0.016, MeshKit.lin(IRON), 5, false)
			prev = p
	else:
		for x: float in [-0.44, 0.44]:
			k.box(Vector3(x, 0.46, 0), Vector3(0.11, 0.92, 0.11), MeshKit.lin(POST))
			_point(k, Vector3(x, 0.92, 0), 0.055, 0.055, 0.1, MeshKit.lin(POST))
		k.box(Vector3(0, 0.86, 0), Vector3(0.78, 0.07, 0.06), MeshKit.lin(RAIL))
	for side: float in [-1.0, 1.0]:
		# Each leaf hangs from the post on its side, swung open a little past square.
		var hinge := Vector3(side * (0.33 if iron else 0.385), 0, 0.02)
		k.xform = base * Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0 + 22.0 * side)), hinge)
		_leaf(k, iron)
	k.xform = Transform3D.IDENTITY


## A gate leaf, built along +x from its hinge.
static func _leaf(k: MeshKit, iron: bool) -> void:
	var width := 0.32 if iron else 0.36
	if iron:
		for y: float in [0.12, 0.72]:
			k.box(Vector3(width * 0.5, y, 0), Vector3(width, 0.03, 0.025), MeshKit.lin(IRON))
		for i in 4:
			var x := 0.03 + i * (width - 0.06) / 3.0
			k.cylinder(Vector3(x, 0.08, 0), Vector3(x, 0.8, 0), 0.012, 0.012, MeshKit.lin(IRON), 5, false)
			k.cone(Vector3(x, 0.8, 0), Vector3(x, 0.87, 0), 0.026, MeshKit.lin(IRON), 4)
		return
	for y: float in [0.18, 0.45]:
		k.box(Vector3(width * 0.5, y, 0), Vector3(width, 0.05, 0.03), MeshKit.lin(RAIL))
	for i in 3:
		var x := 0.06 + i * (width - 0.12) / 2.0
		k.box(Vector3(x, 0.29, 0), Vector3(0.07, 0.54, 0.035), MeshKit.lin(PICKET))
		_point(k, Vector3(x, 0.54, 0), 0.035, 0.0175, 0.07, MeshKit.lin(PICKET))


## A four-sided point on top of a post or picket: `hx` by `hz` at its base, `h` tall.
static func _point(k: MeshKit, base: Vector3, hx: float, hz: float, h: float, col: Color) -> void:
	var apex := base + Vector3(0, h, 0)
	var corners: Array[Vector3] = [base + Vector3(-hx, 0, -hz), base + Vector3(hx, 0, -hz),
		base + Vector3(hx, 0, hz), base + Vector3(-hx, 0, hz)]
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var mid := (a + b) * 0.5 - base
		var n := (mid.normalized() * h + Vector3(0, mid.length(), 0)).normalized()
		k.tri(k.vertex(a, n, col), k.vertex(b, n, col), k.vertex(apex, n, col), k.xform.basis * n)
