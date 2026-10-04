class_name AnimalParts
extends RefCounted
## Extra pieces for animal characters, in head space (centred on the head, facing +Z)
## or tail space. Like CharacterParts, vertices are PLAIN (the material's first colour)
## or TRIM (its second colour), so one mesh can carry, say, an ear and its pink inside.

const P = preload("res://scripts/character/character_parts.gd")
const PLAIN := P.PLAIN
const TRIM := P.TRIM


## A person-shaped head without the human ears.
static func head() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(Vector3.ZERO, P.HEAD_RADIUS, PLAIN, 18, 28)
	return k.commit()


## Ears for "cat" (upright, pink inside, with tufts; small and rounded if `short`), "dog" (folded button ears),
## "rabbit" (long and upright, or hanging down the sides if `lop`), "ferret" (small and
## round, pale rimmed) or "mouse" (big round ones). Birds have none.
## Material colours: fur, inner ear.
static func ears(kind: String, lop := false, short := false) -> ArrayMesh:
	var k := MeshKit.new()
	for s: float in [-1.0, 1.0]:
		match kind:
			"cat" when short:
				# A British Shorthair's: small, round-tipped and set wide.
				var base := Vector3(s * 0.25, 0.22, 0.0)
				var tip := Vector3(s * 0.33, 0.4, 0.02)
				_flap(k, base, tip, 0.26, 0.05, Vector3(0, 0.1, 1).normalized(), PLAIN)
				_flap(k, base + Vector3(0, 0.02, 0.03), tip.lerp(base, 0.3) + Vector3(0, 0, 0.03), 0.15, 0.01, Vector3(0, 0.1, 1).normalized(), TRIM)
			"cat":
				var base := Vector3(s * 0.21, 0.25, 0.0)
				var tip := Vector3(s * 0.33, 0.52, 0.03)
				_flap(k, base, tip, 0.25, 0.05, Vector3(0, 0.1, 1).normalized(), PLAIN)
				_flap(k, base + Vector3(0, 0.02, 0.03), tip.lerp(base, 0.22) + Vector3(0, 0, 0.03), 0.15, 0.01, Vector3(0, 0.1, 1).normalized(), TRIM)
				# Long-haired tufts at the tips and a wisp inside.
				k.cone(tip - Vector3(s * 0.01, 0.03, 0), tip + Vector3(s * 0.02, 0.07, 0), 0.025, PLAIN, 5)
				k.cone(base + Vector3(-s * 0.02, 0.04, 0.05), base + Vector3(s * 0.04, 0.16, 0.08), 0.03, PLAIN, 5)
			"rabbit":
				if lop:
					# Hanging down beside the face, fur side out.
					k.xform = Transform3D(Basis(Vector3.BACK, -s * (PI - 0.22)) * Basis(Vector3.RIGHT, 0.3), Vector3(s * 0.3, 0.24, 0.02))
					k.sphere(Vector3(0, 0.16, 0), Vector3(0.09, 0.2, 0.05), PLAIN, 6, 10)
					k.sphere(Vector3(0, 0.33, 0), Vector3(0.12, 0.13, 0.055), PLAIN, 6, 10)
				else:
					# Long and upright, leaning out a little, pink inside.
					k.xform = Transform3D(Basis(Vector3.BACK, -s * 0.22) * Basis(Vector3.RIGHT, -0.08), Vector3(s * 0.12, 0.28, -0.02))
					k.sphere(Vector3(0, 0.22, 0), Vector3(0.085, 0.25, 0.045), PLAIN, 6, 10)
					k.sphere(Vector3(0, 0.22, 0.026), Vector3(0.05, 0.2, 0.024), TRIM, 5, 8)
				k.xform = Transform3D.IDENTITY
			"ferret":
				var at := Vector3(s * 0.27, 0.2, -0.02)
				k.xform = Transform3D(Basis(Vector3.BACK, -s * 0.7), at)
				k.sphere(Vector3.ZERO, Vector3(0.085, 0.075, 0.035), TRIM, 5, 10)
				k.sphere(Vector3(0, -0.005, 0.012), Vector3(0.06, 0.052, 0.03), PLAIN, 5, 10)
				k.xform = Transform3D.IDENTITY
			"mouse":
				var at := Vector3(s * 0.25, 0.3, -0.04)
				k.xform = Transform3D(Basis(Vector3.BACK, -s * 0.55) * Basis(Vector3.RIGHT, -0.15), at)
				k.sphere(Vector3(0, 0.1, 0), Vector3(0.17, 0.16, 0.035), PLAIN, 6, 14)
				k.sphere(Vector3(0, 0.1, 0.02), Vector3(0.12, 0.115, 0.022), TRIM, 5, 12)
				k.xform = Transform3D.IDENTITY
			"dog":
				# Button ears: up from the head, then folded forward and down.
				var base := Vector3(s * 0.25, 0.24, 0.02)
				var fold := Vector3(s * 0.3, 0.33, 0.1)
				var tip := Vector3(s * 0.33, 0.15, 0.25)
				_flap(k, base, fold, 0.2, 0.05, Vector3(s * 0.4, 0.3, 1).normalized(), PLAIN)
				_flap(k, fold + Vector3(0, 0.0, -0.02), tip, 0.2, 0.045, Vector3(s * 0.3, 1.0, 0.3).normalized(), PLAIN)
	return k.commit()


## Long-haired cat's fluffy cheeks and chest ruff. Colours: fur, second fur.
static func ruff() -> ArrayMesh:
	var k := MeshKit.new()
	var tufts := [[Vector3(0.31, -0.1, 0.06), 0.1], [Vector3(0.3, -0.18, 0.09), 0.11], [Vector3(0.25, -0.25, 0.12), 0.09]]
	for s: float in [-1.0, 1.0]:
		for tuft: Array in tufts:
			var root: Vector3 = tuft[0] * Vector3(s, 1, 1)
			var length: float = tuft[1]
			k.sphere(root, Vector3.ONE * 0.06, PLAIN, 4, 8)
			k.cone(root, root + Vector3(s * length, -length * 0.45, 0.02), 0.06, PLAIN, 7)
	# A soft bib under the chin.
	k.sphere(Vector3(0, -0.31, 0.13), Vector3(0.15, 0.07, 0.08), TRIM, 5, 10)
	for i in 4:
		var x := (i - 1.5) * 0.065
		var root := Vector3(x, -0.33, 0.15 - absf(x) * 0.3)
		k.cone(root, root + Vector3(x * 0.2, -0.1, 0.05), 0.05, TRIM, 6)
	return k.commit()


## A snout with its nose: a dog's, or a ferret's or mouse's smaller pointed one.
## Colours: muzzle fur, nose.
static func snout(kind: String = "dog") -> ArrayMesh:
	var k := MeshKit.new()
	match kind:
		"ferret":
			k.sphere(Vector3(0, -0.1, 0.27), Vector3(0.1, 0.07, 0.1), PLAIN, 7, 12)
			k.sphere(Vector3(0, -0.075, 0.36), Vector3(0.036, 0.026, 0.026), TRIM, 5, 8)
		"mouse":
			k.sphere(Vector3(0, -0.1, 0.27), Vector3(0.095, 0.075, 0.12), PLAIN, 7, 12)
			k.sphere(Vector3(0, -0.085, 0.39), Vector3.ONE * 0.03, TRIM, 5, 8)
		_:
			k.sphere(Vector3(0, -0.085, 0.29), Vector3(0.12, 0.085, 0.11), PLAIN, 8, 12)
			k.sphere(Vector3(0, -0.05, 0.395), Vector3(0.05, 0.036, 0.034), TRIM, 5, 8)
	return k.commit()


## A bird's short beak, a little hooked, and a tuft of crest feathers on top.
## Colours: beak, crest.
static func beak() -> ArrayMesh:
	var k := MeshKit.new()
	k.xform = Transform3D(Basis.from_scale(Vector3(1.0, 0.75, 1.0)), Vector3(0, -0.07, 0.3))
	k.sphere(Vector3.ZERO, Vector3(0.075, 0.07, 0.06), PLAIN, 6, 10)
	k.cone(Vector3(0, 0.0, 0.03), Vector3(0, -0.035, 0.15), 0.06, PLAIN, 10)
	k.xform = Transform3D.IDENTITY
	for f: Array in [[Vector3(0, 0.33, 0.06), Vector3(0, 1.0, 0.55), 0.17], [Vector3(-0.05, 0.32, 0.02), Vector3(-0.35, 1.0, 0.2), 0.13],
			[Vector3(0.05, 0.32, 0.02), Vector3(0.35, 1.0, 0.2), 0.13], [Vector3(0, 0.33, -0.03), Vector3(0, 1.0, -0.1), 0.12]]:
		k.leaf(f[0], f[1], f[2], 0.07, TRIM, 0.04)
	return k.commit()


## Tails, built from the tail pivot (at the back of the hips) backwards and up.
## "cat": long and fluffy with a tip in the second colour. "dog": short and perky.
## "rabbit": a pom-pom. "ferret": long and bushy, in the third colour. "mouse": long,
## thin and curling, in the second colour. "bird": a fan of feathers.
static func tail(kind: String) -> ArrayMesh:
	var k := MeshKit.new()
	match kind:
		"cat":
			var count := 9
			for i in count:
				var t := float(i) / (count - 1)
				# Out behind, then up with a curl to one side.
				var p := Vector3(sin(t * 2.6) * 0.13, 0.02 + t * 0.36, -0.06 - sin(t * 2.0) * 0.16)
				var r := 0.055 + sin(t * PI) * 0.035
				k.sphere(p, Vector3.ONE * r, PLAIN, 5, 8)
		"rabbit":
			for p: Vector3 in [Vector3(0, 0.04, -0.06), Vector3(0.03, 0.07, -0.08), Vector3(-0.03, 0.06, -0.09), Vector3(0, 0.02, -0.1)]:
				k.sphere(p, Vector3.ONE * 0.065, TRIM, 4, 8)
		"ferret":
			var count := 8
			for i in count:
				var t := float(i) / (count - 1)
				var p := Vector3(sin(t * 2.0) * 0.06, 0.03 + t * 0.12 - t * t * 0.08, -0.05 - t * 0.36)
				k.sphere(p, Vector3.ONE * (0.065 - t * 0.03), TRIM, 5, 8)
		"mouse":
			var count := 12
			var last := Vector3.ZERO
			for i in count:
				var t := float(i + 1) / count
				var p := Vector3(sin(t * 3.2) * 0.14, 0.04 + sin(t * 2.4) * 0.2, -0.04 - t * 0.3)
				k.cylinder(last, p, 0.022 - t * 0.008, 0.02 - t * 0.008, TRIM, 6, false)
				k.sphere(p, Vector3.ONE * (0.02 - t * 0.008), TRIM, 3, 6)
				last = p
		"bird":
			for i in 5:
				var a := (i - 2) * 0.32
				k.leaf(Vector3(0, 0.0, -0.04), Vector3(sin(a) * 0.5, 0.35 - absf(a) * 0.2, -1.0), 0.24 - absf(i - 2) * 0.03, 0.08, TRIM if i % 2 == 0 else PLAIN, -0.03)
		_:
			k.cylinder(Vector3.ZERO, Vector3(0, 0.16, -0.07), 0.04, 0.03, PLAIN, 8)
			k.sphere(Vector3(0, 0.17, -0.075), Vector3.ONE * 0.034, TRIM, 4, 8)
	return k.commit()


## A flat triangular flap from a base (centre of its wide end) to a tip, `width` across,
## `thick` deep, with its face towards `facing`.
static func _flap(k: MeshKit, base: Vector3, tip: Vector3, width: float, thick: float, facing: Vector3, c: Color) -> void:
	var along := (tip - base).normalized()
	var side := along.cross(facing).normalized()
	var front := side.cross(along).normalized()
	if front.dot(facing) < 0.0:
		front = -front
	var a := base + side * width * 0.5
	var b := base - side * width * 0.5
	var f := front * thick * 0.5
	for n: Vector3 in [front, -front]:
		var o := f if n == front else -f
		var ia := k.vertex(a + o, n, c)
		var ib := k.vertex(b + o, n, c)
		var it := k.vertex(tip + o * 0.3, n, c)
		k.tri(ia, ib, it, n)
	# Edges.
	for edge: Array in [[a, b], [b, tip], [tip, a]]:
		var e0: Vector3 = edge[0]
		var e1: Vector3 = edge[1]
		var mid := (e0 + e1) * 0.5
		var n := (mid - (a + b + tip) / 3.0).normalized()
		k.flat_quad(e0 + f, e1 + f, e1 - f, e0 - f, n, c)
