class_name CreatureModels
extends RefCounted
## Fish and bugs (data/creatures.json), for icons, holding up and the bugs about the
## island. Fish face +X; bugs face +Z with their wings along X.

const SIZES := {"tiny": 0.14, "small": 0.2, "medium": 0.27, "large": 0.35, "huge": 0.48}
const EYE := Color("2a2430")


static func build(k: MeshKit, id: String) -> void:
	if ItemDB.fish.has(id):
		_fish(k, ItemDB.fish[id])
	elif ItemDB.bugs.has(id):
		_bug(k, ItemDB.bugs[id])


static func _c(hex: String, sway: float = 0.0) -> Color:
	return MeshKit.lin(Color(hex), sway)


# --- Fish ----------------------------------------------------------------------------

static func _fish(k: MeshKit, f: Dictionary) -> void:
	var length: float = SIZES.get(f.get("size", "small"), 0.2)
	var a := _c(f["colors"][0])
	var b := _c(f["colors"][1])
	var half := length * 0.5
	match f.get("shape", ""):
		"squid":
			k.cylinder(Vector3(-half, half * 0.35, 0), Vector3(half * 0.8, half * 0.35, 0), half * 0.28, half * 0.05, a, 8)
			k.leaf(Vector3(half * 0.6, half * 0.35, 0), Vector3(1, 0, 0.8), half * 0.4, half * 0.3, a)
			k.leaf(Vector3(half * 0.6, half * 0.35, 0), Vector3(1, 0, -0.8), half * 0.4, half * 0.3, a)
			for i in 6:
				var ang := TAU * i / 6.0
				k.cylinder(Vector3(-half, half * 0.35, 0), Vector3(-half * 1.6, half * 0.35 + sin(ang) * half * 0.2, cos(ang) * half * 0.2), half * 0.05, half * 0.02, b, 4)
			_eyes(k, Vector3(-half * 0.8, half * 0.45, 0), half * 0.25, half * 0.09)
		"octopus":
			k.sphere(Vector3(0, half * 0.9, 0), Vector3(half * 0.6, half * 0.7, half * 0.6), a, 6, 10)
			for i in 8:
				var ang := TAU * i / 8.0
				var dir := Vector3(cos(ang), 0, sin(ang))
				k.cylinder(Vector3(0, half * 0.35, 0) + dir * half * 0.3, dir * half * 1.1 + Vector3(0, half * 0.08, 0), half * 0.12, half * 0.04, a, 5)
				k.sphere(dir * half * 1.1 + Vector3(0, half * 0.1, 0), Vector3.ONE * half * 0.06, b, 2, 4)
			_eyes(k, Vector3(half * 0.45, half * 0.85, 0), half * 0.25, half * 0.12)
		"frog":
			k.sphere(Vector3(0, half * 0.45, 0), Vector3(half * 0.7, half * 0.42, half * 0.55), a, 6, 10)
			k.sphere(Vector3(half * 0.1, half * 0.32, 0), Vector3(half * 0.55, half * 0.25, half * 0.45), b, 5, 9)
			for sz: float in [-1.0, 1.0]:
				k.sphere(Vector3(half * 0.35, half * 0.85, sz * half * 0.28), Vector3.ONE * half * 0.2, a, 4, 7)
				k.sphere(Vector3(half * 0.48, half * 0.88, sz * half * 0.28), Vector3.ONE * half * 0.1, MeshKit.lin(EYE), 3, 5)
				k.sphere(Vector3(-half * 0.45, half * 0.2, sz * half * 0.55), Vector3(half * 0.4, half * 0.15, half * 0.2), a, 4, 7)
		"tadpole":
			k.sphere(Vector3(half * 0.35, half * 0.3, 0), Vector3(half * 0.45, half * 0.35, half * 0.38), a, 5, 9)
			k.leaf(Vector3(0, half * 0.3, 0), Vector3(-1, 0.05, 0), half * 1.2, half * 0.35, b)
			_eyes(k, Vector3(half * 0.62, half * 0.4, 0), half * 0.22, half * 0.08)
		"round":
			k.sphere(Vector3(0, half * 0.7, 0), Vector3.ONE * half * 0.7, a, 7, 12, 0.4)
			for i in 10:
				var dir := Vector3(cos(i * 2.4), sin(i * 1.7) * 0.8, sin(i * 2.4)).normalized()
				k.cone(Vector3(0, half * 0.7, 0) + dir * half * 0.62, Vector3(0, half * 0.7, 0) + dir * half * 0.85, half * 0.06, b, 4)
			k.leaf(Vector3(-half * 0.65, half * 0.7, 0), Vector3(-1, 0.1, 0), half * 0.4, half * 0.5, b)
			_eyes(k, Vector3(half * 0.45, half * 0.85, 0), half * 0.4, half * 0.1)
		"flat":
			k.sphere(Vector3(0, half * 0.18, 0), Vector3(half, half * 0.16, half * 0.62), a, 5, 12)
			k.sphere(Vector3(0, half * 0.12, 0), Vector3(half * 1.05, half * 0.08, half * 0.7), b, 3, 12)
			k.leaf(Vector3(-half * 0.9, half * 0.18, 0), Vector3(-1, 0, 0), half * 0.4, half * 0.5, a)
			for sz: float in [-1.0, 1.0]:
				k.sphere(Vector3(half * 0.5, half * 0.33, sz * half * 0.12), Vector3.ONE * half * 0.08, MeshKit.lin(EYE), 3, 5)
		_:
			# A plain fish: body, pale belly, tail, fins and an eye each side.
			var h := half * 0.42
			k.sphere(Vector3(0, h, 0), Vector3(half, h, half * 0.32), a, 7, 12, 0.3)
			k.sphere(Vector3(half * 0.05, h * 0.8, 0), Vector3(half * 0.85, h * 0.7, half * 0.28), b, 5, 10)
			k.leaf(Vector3(-half * 0.9, h, 0), Vector3(-1, 0.5, 0), half * 0.55, half * 0.4, a)
			k.leaf(Vector3(-half * 0.9, h, 0), Vector3(-1, -0.5, 0), half * 0.55, half * 0.4, a)
			k.leaf(Vector3(0, h * 1.8, 0), Vector3(-0.6, 1, 0), half * 0.45, half * 0.18, a)
			if f.get("shape", "") == "stripy":
				for x: float in [0.35, -0.2]:
					k.cylinder(Vector3(half * x - half * 0.06, h, 0), Vector3(half * x + half * 0.06, h, 0), h * 1.02, h * 1.02, b, 10, false)
			_eyes(k, Vector3(half * 0.62, h * 1.15, 0), half * 0.55, half * 0.08)


static func _eyes(k: MeshKit, at: Vector3, apart: float, r: float) -> void:
	for sz: float in [-1.0, 1.0]:
		k.sphere(at + Vector3(0, 0, sz * apart * 0.5), Vector3.ONE * r, MeshKit.lin(EYE), 3, 5)


## The dark shape of a fish seen through the water, for each size. Lies flat, length
## along X.
## A fish's shadow seen through the water: a pointed oval along +x (the way it swims),
## fuller towards the nose and tapering to a point at the tail. Flat, for
## shaders/blob_shadow.gdshader: vertex alpha is 1 along the middle and 0 at the edges
## (a soft outline), UV.x runs from the tail (0) to the nose (1) and UV.y is the fish's
## length (for its wiggle).
static func shadow(k: MeshKit, size: String) -> void:
	var half: float = SIZES.get(size, 0.2) * 1.3
	var tail := -half * 1.15
	var nose := half * 0.95
	var width := half * 0.44
	var steps := 14
	var up := Vector3.UP
	var prev: Array[int] = []
	for i in steps + 1:
		var s := float(i) / steps
		var x := lerpf(tail, nose, s)
		# Widest a little forward of the middle.
		var w := width * pow(sin(PI * pow(1.0 - s, 0.8)), 0.75)
		var uv := Vector2(s, half * 2.0)
		var row: Array[int] = [
			k.vertex(Vector3(x, 0, -w), up, Color(1, 1, 1, 0), uv),
			k.vertex(Vector3(x, 0, 0), up, Color(1, 1, 1, 1), uv),
			k.vertex(Vector3(x, 0, w), up, Color(1, 1, 1, 0), uv),
		]
		if not prev.is_empty():
			k.quad(prev[0], prev[1], row[1], row[0], up)
			k.quad(prev[1], prev[2], row[2], row[1], up)
		prev = row


# --- Bugs ----------------------------------------------------------------------------

static func _bug(k: MeshKit, bug: Dictionary) -> void:
	var a := _c(bug["colors"][0])
	var b := _c(bug["colors"][1])
	match bug.get("shape", ""):
		"butterfly", "moth":
			var moth: bool = bug["shape"] == "moth"
			k.cylinder(Vector3(0, 0.0, -0.06), Vector3(0, 0.0, 0.06), 0.012, 0.01, MeshKit.lin(Color("3a3030")), 5)
			for sx: float in [-1.0, 1.0]:
				k.leaf(Vector3(sx * 0.005, 0, 0.01), Vector3(sx, 0.1, 0.55), 0.13 if not moth else 0.12, 0.11 if not moth else 0.12, a)
				k.leaf(Vector3(sx * 0.005, 0, -0.01), Vector3(sx, 0.1, -0.6), 0.09, 0.08, a.darkened(0.08) if moth else a)
				k.sphere(Vector3(sx * 0.07, 0.006, 0.05), Vector3(0.018, 0.004, 0.018), b, 2, 6)
				k.cylinder(Vector3(sx * 0.005, 0, 0.06), Vector3(sx * 0.03, 0.02, 0.1), 0.003, 0.003, b, 3, false)
		"bee":
			k.sphere(Vector3(0, 0, 0), Vector3(0.035, 0.032, 0.05), a, 5, 8)
			for z: float in [-0.015, 0.012]:
				k.cylinder(Vector3(0, 0, z - 0.006), Vector3(0, 0, z + 0.006), 0.034, 0.034, b, 8, false)
			k.sphere(Vector3(0, 0.005, 0.055), Vector3.ONE * 0.02, b, 3, 6)
			for sx: float in [-1.0, 1.0]:
				k.leaf(Vector3(sx * 0.01, 0.03, 0.0), Vector3(sx, 0.4, -0.2), 0.05, 0.035, MeshKit.lin(Color("eef6fb")))
		"ladybug":
			k.sphere(Vector3(0, 0.012, 0), Vector3(0.04, 0.03, 0.045), a, 5, 10)
			k.sphere(Vector3(0, 0.01, 0.045), Vector3(0.022, 0.018, 0.016), b, 3, 6)
			for spot: Vector3 in [Vector3(0.018, 0.035, 0.01), Vector3(-0.018, 0.035, 0.01), Vector3(0.02, 0.03, -0.02), Vector3(-0.02, 0.03, -0.02)]:
				k.sphere(spot, Vector3(0.009, 0.004, 0.009), b, 2, 5)
		"dragonfly":
			k.cylinder(Vector3(0, 0, -0.1), Vector3(0, 0, 0.04), 0.008, 0.012, a, 5)
			k.sphere(Vector3(0, 0, 0.055), Vector3.ONE * 0.02, a, 3, 6)
			for sx: float in [-1.0, 1.0]:
				for z: float in [0.02, -0.01]:
					k.leaf(Vector3(0, 0.01, z), Vector3(sx, 0.05, z * 4.0), 0.11, 0.025, b)
		"firefly":
			k.sphere(Vector3(0, 0, 0.01), Vector3(0.022, 0.018, 0.035), a, 4, 7)
			k.sphere(Vector3(0, 0, -0.03), Vector3(0.02, 0.018, 0.024), b, 4, 7)
		"hopper":
			k.sphere(Vector3(0, 0.025, 0), Vector3(0.022, 0.022, 0.06), a, 4, 8)
			k.sphere(Vector3(0, 0.03, 0.06), Vector3(0.02, 0.022, 0.02), a, 3, 6)
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * 0.02, 0.03, -0.01), Vector3(sx * 0.035, 0.06, -0.04), 0.006, 0.005, b, 3, false)
				k.cylinder(Vector3(sx * 0.035, 0.06, -0.04), Vector3(sx * 0.035, 0.0, -0.07), 0.005, 0.004, b, 3, false)
				k.cylinder(Vector3(sx * 0.008, 0.045, 0.075), Vector3(sx * 0.03, 0.09, 0.12), 0.002, 0.002, b, 3, false)
		"cicada":
			k.sphere(Vector3(0, 0.0, 0), Vector3(0.03, 0.026, 0.05), a, 5, 8)
			k.sphere(Vector3(0, 0.0, 0.045), Vector3(0.032, 0.022, 0.018), a, 4, 7)
			for sx: float in [-1.0, 1.0]:
				k.leaf(Vector3(sx * 0.01, 0.022, 0.03), Vector3(sx * 0.3, 0.1, -1), 0.09, 0.035, b)
		"rhino", "stag":
			k.sphere(Vector3(0, 0.022, -0.01), Vector3(0.04, 0.026, 0.055), a, 6, 10)
			k.sphere(Vector3(0, 0.02, 0.05), Vector3(0.026, 0.02, 0.02), b, 3, 7)
			if bug["shape"] == "rhino":
				k.cylinder(Vector3(0, 0.025, 0.06), Vector3(0, 0.07, 0.1), 0.008, 0.004, b, 4, true)
			else:
				for sx: float in [-1.0, 1.0]:
					k.cylinder(Vector3(sx * 0.012, 0.02, 0.065), Vector3(sx * 0.006, 0.025, 0.11), 0.006, 0.004, b, 4, true)
			for sx: float in [-1.0, 1.0]:
				for z: float in [-0.03, 0.0, 0.03]:
					k.cylinder(Vector3(sx * 0.03, 0.01, z), Vector3(sx * 0.055, 0.0, z * 1.3), 0.004, 0.003, b, 3, false)
		"snail":
			k.sphere(Vector3(0, 0.012, 0.01), Vector3(0.02, 0.012, 0.055), b, 4, 7)
			k.sphere(Vector3(0, 0.04, -0.01), Vector3(0.022, 0.035, 0.035), a, 5, 8)
			k.cylinder(Vector3(-0.023, 0.04, -0.01), Vector3(-0.024, 0.04, -0.01), 0.022, 0.022, MeshKit.lin(Color(bug["colors"][0]).darkened(0.25)), 10, true)
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * 0.006, 0.02, 0.055), Vector3(sx * 0.01, 0.045, 0.07), 0.002, 0.002, b, 3, true)
		"crab":
			k.cone(Vector3(0, 0.0, -0.01), Vector3(0, 0.07, -0.02), 0.04, b, 8)
			k.sphere(Vector3(0, 0.012, 0.03), Vector3(0.025, 0.014, 0.018), a, 4, 7)
			for sx: float in [-1.0, 1.0]:
				k.sphere(Vector3(sx * 0.028, 0.018, 0.05), Vector3(0.016, 0.012, 0.012), a, 3, 6)
				for z: float in [0.0, 0.02]:
					k.cylinder(Vector3(sx * 0.02, 0.01, z + 0.02), Vector3(sx * 0.045, 0.0, z + 0.015), 0.003, 0.003, a, 3, false)
				k.sphere(Vector3(sx * 0.01, 0.03, 0.045), Vector3.ONE * 0.006, MeshKit.lin(EYE), 2, 4)
		_:
			k.sphere(Vector3.ZERO, Vector3.ONE * 0.03, a, 4, 6)


## The red and white float on the end of a fishing line.
static func bobber(k: MeshKit) -> void:
	k.sphere(Vector3(0, 0.03, 0), Vector3.ONE * 0.05, MeshKit.lin(Color("e0453a")), 4, 8)
	k.cylinder(Vector3(0, 0.0, 0), Vector3(0, 0.03, 0), 0.05, 0.05, MeshKit.lin(Color("fbf8f0")), 8, false)
	k.sphere(Vector3(0, -0.005, 0), Vector3(0.05, 0.03, 0.05), MeshKit.lin(Color("fbf8f0")), 3, 8)
	k.cylinder(Vector3(0, 0.07, 0), Vector3(0, 0.11, 0), 0.008, 0.008, MeshKit.lin(Color("3a3030")), 4, true)
