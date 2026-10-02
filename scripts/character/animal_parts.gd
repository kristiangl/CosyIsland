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


## Ears for "cat" (upright, pink inside, with tufts) or "dog" (folded button ears).
## Material colours: fur, inner ear.
static func ears(kind: String) -> ArrayMesh:
	var k := MeshKit.new()
	for s: float in [-1.0, 1.0]:
		if kind == "cat":
			var base := Vector3(s * 0.21, 0.25, 0.0)
			var tip := Vector3(s * 0.33, 0.52, 0.03)
			_flap(k, base, tip, 0.25, 0.05, Vector3(0, 0.1, 1).normalized(), PLAIN)
			_flap(k, base + Vector3(0, 0.02, 0.03), tip.lerp(base, 0.22) + Vector3(0, 0, 0.03), 0.15, 0.01, Vector3(0, 0.1, 1).normalized(), TRIM)
			# Long-haired tufts at the tips and a wisp inside.
			k.cone(tip - Vector3(s * 0.01, 0.03, 0), tip + Vector3(s * 0.02, 0.07, 0), 0.025, PLAIN, 5)
			k.cone(base + Vector3(-s * 0.02, 0.04, 0.05), base + Vector3(s * 0.04, 0.16, 0.08), 0.03, PLAIN, 5)
		else:
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


## Dog's snout with its nose. Colours: muzzle fur, nose.
static func snout() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(Vector3(0, -0.085, 0.29), Vector3(0.12, 0.085, 0.11), PLAIN, 8, 12)
	k.sphere(Vector3(0, -0.05, 0.395), Vector3(0.05, 0.036, 0.034), TRIM, 5, 8)
	return k.commit()


## Tails, built from the tail pivot (at the back of the hips) backwards and up.
## "cat": long and fluffy with a tip in the second colour. "dog": short and perky.
static func tail(kind: String) -> ArrayMesh:
	var k := MeshKit.new()
	if kind == "cat":
		var count := 9
		for i in count:
			var t := float(i) / (count - 1)
			# Out behind, then up with a curl to one side.
			var p := Vector3(sin(t * 2.6) * 0.13, 0.02 + t * 0.36, -0.06 - sin(t * 2.0) * 0.16)
			var r := 0.055 + sin(t * PI) * 0.035
			k.sphere(p, Vector3.ONE * r, PLAIN, 5, 8)
	else:
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
