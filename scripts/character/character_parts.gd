class_name CharacterParts
extends RefCounted
## Meshes for the modular chibi character, built from simple shapes.
##
## Layout (metres, character faces +Z, feet at y = 0):
##   legs pivot at the hips (y = HIP_Y), arms pivot at the shoulders, the head pivots at
##   the neck and its mesh is centred HEAD_CENTRE above that.
## Parts that belong to a pivot (sleeves, trouser legs, shoes) are built in that pivot's
## local space. Arms and legs come in two pieces each, upper (from the shoulder or hip)
## and lower (from the elbow or knee), so they can bend. Head-mounted parts (hair, hats, glasses) are built around the head centre.
##
## Vertex colour: red = brightness, green = 0 for trim (which takes the second colour).

const HIP_Y := 0.4
const LEG_X := 0.085
const LEG_LENGTH := 0.3
## Hip to knee, and knee to the ankle (the foot sits just below it).
const LEG_UPPER := 0.13
const LEG_LOWER := 0.17
const SHOULDER := Vector3(0.19, 0.67, 0.0)
const ARM_LENGTH := 0.24
## Shoulder to elbow, and elbow to the middle of the hand.
const ARM_UPPER := 0.12
const ARM_LOWER := 0.12
const NECK_Y := 0.74
const HEAD_CENTRE := Vector3(0, 0.32, 0)
const HEAD_RADIUS := Vector3(0.38, 0.35, 0.36)
const TORSO_CENTRE := Vector3(0, 0.56, 0)
const TORSO_RADIUS := Vector3(0.19, 0.2, 0.16)

## Set while building hair under a hat (see hair()).
static var _hat_on := false

const PLAIN := Color(1, 1, 1, 0)
const SHADED := Color(0.9, 1, 1, 0)
const TRIM := Color(1, 0, 1, 0)


# --- Skin --------------------------------------------------------------------------

static func head() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(Vector3.ZERO, HEAD_RADIUS, PLAIN, 18, 28)
	for s: float in [-1.0, 1.0]:
		k.sphere(Vector3(s * 0.37, -0.03, -0.01), Vector3(0.05, 0.07, 0.045), PLAIN, 5, 8)
	return k.commit()


static func torso_skin() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(TORSO_CENTRE, TORSO_RADIUS, PLAIN, 10, 16)
	k.cylinder(Vector3(0, 0.7, 0), Vector3(0, 0.8, 0), 0.07, 0.07, PLAIN, 10, false)
	return k.commit()


## {"upper": shoulder to elbow, "lower": forearm and hand}.
static func arm_skin() -> Dictionary:
	var upper := MeshKit.new()
	upper.sphere(Vector3.ZERO, Vector3.ONE * 0.058, PLAIN, 6, 10)
	upper.cylinder(Vector3.ZERO, Vector3(0, -ARM_UPPER, 0), 0.056, 0.053, PLAIN, 10, false)
	var lower := MeshKit.new()
	lower.sphere(Vector3.ZERO, Vector3.ONE * 0.053, PLAIN, 5, 10)
	lower.cylinder(Vector3.ZERO, Vector3(0, -ARM_LOWER + 0.03, 0), 0.053, 0.05, PLAIN, 10, false)
	# A round mitten of a hand with a thumb.
	lower.sphere(Vector3(0, -ARM_LOWER, 0), Vector3(0.07, 0.074, 0.068), PLAIN, 6, 10)
	lower.sphere(Vector3(0, -ARM_LOWER + 0.015, 0.05), Vector3(0.026, 0.03, 0.026), PLAIN, 4, 6)
	return {"upper": upper.commit(), "lower": lower.commit()}


## {"upper": thigh, "lower": shin (and a bare foot)}.
static func leg_skin(barefoot: bool) -> Dictionary:
	var upper := MeshKit.new()
	upper.cylinder(Vector3(0, 0.02, 0), Vector3(0, -LEG_UPPER, 0), 0.066, 0.062, PLAIN, 10, false)
	var lower := MeshKit.new()
	lower.sphere(Vector3.ZERO, Vector3.ONE * 0.062, PLAIN, 5, 10)
	lower.cylinder(Vector3.ZERO, Vector3(0, -LEG_LOWER + 0.02, 0), 0.062, 0.058, PLAIN, 10, false)
	if barefoot:
		lower.sphere(Vector3(0, -LEG_LOWER - 0.005, 0.025), Vector3(0.065, 0.05, 0.095), PLAIN, 6, 10)
	return {"upper": upper.commit(), "lower": lower.commit()}


# --- Tops --------------------------------------------------------------------------

## Returns {"torso": ArrayMesh, "sleeve": ArrayMesh or null, "cuff": ArrayMesh or null}:
## the sleeve sits on the upper arm, the cuff (long sleeves) on the forearm.
static func top(style: String) -> Dictionary:
	var k := MeshKit.new()
	var sleeve := MeshKit.new()
	var cuff := MeshKit.new()
	var shell := TORSO_RADIUS + Vector3(0.016, 0.014, 0.016)
	# A pinafore's body is the blouse underneath, in the second colour.
	k.sphere(TORSO_CENTRE, shell, TRIM if style == "pinafore" else PLAIN, 10, 18)
	match style:
		"tee":
			_hem(k, 0.4, 0.205)
			_short_sleeve(sleeve)
		"long_tee":
			_hem(k, 0.4, 0.205)
			_long_sleeve(sleeve, cuff, 0.064, false)
		"tank":
			_hem(k, 0.4, 0.205)
			for s: float in [-1.0, 1.0]:
				k.cylinder(Vector3(s * 0.1, 0.62, 0.12), Vector3(s * 0.12, 0.76, 0.0), 0.022, 0.022, PLAIN, 6, false)
			sleeve = null
		"collared":
			_hem(k, 0.4, 0.205)
			_collar(k)
			for i in 3:
				k.sphere(Vector3(0, 0.66 - i * 0.07, 0.17), Vector3.ONE * 0.013, TRIM, 3, 6)
			_short_sleeve(sleeve)
		"hoodie":
			_hem(k, 0.39, 0.212, SHADED)
			k.sphere(Vector3(0, 0.75, -0.11), Vector3(0.17, 0.09, 0.1), SHADED, 6, 12)
			k.sphere(Vector3(0, 0.47, 0.14), Vector3(0.12, 0.05, 0.035), SHADED, 4, 10)
			for s: float in [-1.0, 1.0]:
				k.cylinder(Vector3(s * 0.045, 0.72, 0.15), Vector3(s * 0.05, 0.6, 0.175), 0.008, 0.008, TRIM, 4, true)
			_long_sleeve(sleeve, cuff, 0.07, true)
		"sweater":
			_hem(k, 0.39, 0.212, SHADED)
			k.cylinder(Vector3(0, 0.72, 0), Vector3(0, 0.78, 0), 0.085, 0.08, SHADED, 14, false)
			_long_sleeve(sleeve, cuff, 0.072, true)
		"coat":
			k.cylinder(Vector3(0, 0.46, 0), Vector3(0, 0.22, 0), 0.205, 0.25, PLAIN, 16, true)
			_collar(k)
			for i in 4:
				k.sphere(Vector3(0.05, 0.64 - i * 0.1, 0.18 if i < 2 else 0.2), Vector3.ONE * 0.016, TRIM, 3, 6)
			_long_sleeve(sleeve, cuff, 0.072, true)
		"dress":
			k.cylinder(Vector3(0, 0.47, 0), Vector3(0, 0.17, 0), 0.2, 0.3, PLAIN, 18, true)
			_hem(k, 0.18, 0.3, TRIM)
			sleeve.sphere(Vector3(0, -0.02, 0), Vector3(0.085, 0.08, 0.085), PLAIN, 6, 10)
		"sundress":
			k.cylinder(Vector3(0, 0.47, 0), Vector3(0, 0.17, 0), 0.2, 0.3, PLAIN, 18, true)
			for s: float in [-1.0, 1.0]:
				k.cylinder(Vector3(s * 0.1, 0.62, 0.12), Vector3(s * 0.12, 0.76, 0.0), 0.02, 0.02, TRIM, 6, false)
			sleeve = null
		"knit_jumper":
			_hem(k, 0.39, 0.212, SHADED)
			_ribs(k, 0.39, 0.44, 0.205)
			k.cylinder(Vector3(0, 0.72, 0), Vector3(0, 0.775, 0), 0.09, 0.085, SHADED, 14, false)
			# A knitted heart on the chest.
			var front := TORSO_RADIUS.z + 0.012
			for sx: float in [-1.0, 1.0]:
				k.sphere(Vector3(sx * 0.03, 0.62, front), Vector3(0.036, 0.032, 0.012), TRIM, 4, 8)
			k.cone(Vector3(0, 0.61, front - 0.002), Vector3(0, 0.55, front + 0.004), 0.05, TRIM, 4)
			_long_sleeve(sleeve, cuff, 0.072, true)
		"cardigan":
			_hem(k, 0.39, 0.212, SHADED)
			# Open at the front over a top in the second colour, with buttons down one side.
			var front := TORSO_RADIUS.z + 0.014
			k.box(Vector3(0, 0.58, front - 0.004), Vector3(0.07, 0.28, 0.012), TRIM)
			for sx: float in [-1.0, 1.0]:
				k.box(Vector3(sx * 0.045, 0.57, front + 0.002), Vector3(0.022, 0.32, 0.014), SHADED)
			for i in 4:
				k.sphere(Vector3(0.045, 0.66 - i * 0.065, front + 0.012), Vector3.ONE * 0.013, SHADED, 3, 6)
			_long_sleeve(sleeve, cuff, 0.072, true)
		"turtleneck":
			_hem(k, 0.39, 0.212)
			# The rolled collar shows under the chin.
			k.cylinder(Vector3(0, 0.7, 0), Vector3(0, 0.8, 0), 0.1, 0.095, SHADED, 16, false)
			k.sphere(Vector3(0, 0.765, 0.0), Vector3(0.135, 0.045, 0.125), SHADED, 5, 16)
			_long_sleeve(sleeve, cuff, 0.068, true)
		"raincoat":
			# A long coat with a hood down the back, toggles and pocket flaps.
			k.cylinder(Vector3(0, 0.47, 0), Vector3(0, 0.24, 0), 0.208, 0.25, PLAIN, 18, true)
			k.sphere(Vector3(0, 0.79, -0.14), Vector3(0.2, 0.13, 0.12), PLAIN, 6, 12)
			k.sphere(Vector3(0, 0.8, -0.1), Vector3(0.15, 0.08, 0.08), SHADED, 5, 10)
			var front := TORSO_RADIUS.z + 0.02
			for i in 3:
				k.cylinder(Vector3(-0.03, 0.66 - i * 0.09, front), Vector3(0.03, 0.66 - i * 0.09, front), 0.012, 0.012, TRIM, 5, true)
			for sx: float in [-1.0, 1.0]:
				k.box(Vector3(sx * 0.12, 0.36, 0.2), Vector3(0.09, 0.03, 0.03), SHADED)
			_long_sleeve(sleeve, cuff, 0.075, true)
		"sailor_top":
			_hem(k, 0.4, 0.205)
			# The big square collar at the back, a V at the front and a little tie.
			k.box(Vector3(0, 0.7, -0.165), Vector3(0.3, 0.16, 0.018), TRIM)
			k.box(Vector3(0, 0.625, -0.172), Vector3(0.3, 0.012, 0.012), PLAIN)
			for sx: float in [-1.0, 1.0]:
				k.leaf(Vector3(sx * 0.09, 0.77, 0.08), Vector3(-sx * 0.55, -0.75, 0.6), 0.17, 0.07, TRIM, 0.0)
			k.sphere(Vector3(0, 0.63, 0.18), Vector3(0.035, 0.025, 0.018), TRIM, 4, 6)
			for sx: float in [-1.0, 1.0]:
				k.leaf(Vector3(0, 0.62, 0.185), Vector3(sx * 0.4, -1.0, 0.1), 0.08, 0.04, TRIM, 0.0)
			_short_sleeve(sleeve)
			sleeve.cylinder(Vector3(0, -0.095, 0), Vector3(0, -0.11, 0), 0.073, 0.072, TRIM, 10, false)
		"flannel_shirt":
			_hem(k, 0.4, 0.207)
			_collar(k)
			var front := TORSO_RADIUS.z + 0.014
			for i in 4:
				k.sphere(Vector3(0, 0.67 - i * 0.07, front + 0.006), Vector3.ONE * 0.012, TRIM, 3, 6)
			for sx: float in [-1.0, 1.0]:
				k.box(Vector3(sx * 0.085, 0.62, front - 0.004), Vector3(0.07, 0.07, 0.016), SHADED)
			_long_sleeve(sleeve, cuff, 0.07, true)
		"puffer_jacket":
			# Quilted bands, each a little puffy, a high collar and a zip.
			for i in 5:
				var y := 0.41 + i * 0.075
				var r := 0.215 - absf(i - 2.0) * 0.012
				k.sphere(Vector3(0, y, 0), Vector3(r, 0.05, r * 0.88), PLAIN, 5, 16)
				if i > 0:
					k.cylinder(Vector3(0, y - 0.042, 0), Vector3(0, y - 0.034, 0), r * 0.92, r * 0.92, SHADED, 16, false)
			k.cylinder(Vector3(0, 0.71, 0), Vector3(0, 0.8, 0), 0.11, 0.105, SHADED, 14, false)
			k.box(Vector3(0, 0.56, TORSO_RADIUS.z + 0.035), Vector3(0.012, 0.36, 0.01), TRIM)
			_long_sleeve(sleeve, cuff, 0.085, true)
			for i in 2:
				sleeve.sphere(Vector3(0, -0.04 - i * 0.05, 0), Vector3(0.09, 0.03, 0.09), PLAIN, 4, 10)
		"denim_jacket":
			_hem(k, 0.4, 0.212, SHADED)
			_collar(k)
			var front := TORSO_RADIUS.z + 0.014
			for sx: float in [-1.0, 1.0]:
				k.box(Vector3(sx * 0.085, 0.63, front), Vector3(0.075, 0.06, 0.016), SHADED)
				k.sphere(Vector3(sx * 0.085, 0.61, front + 0.01), Vector3.ONE * 0.01, TRIM, 3, 6)
			for i in 4:
				k.sphere(Vector3(0.012, 0.66 - i * 0.07, front + 0.006), Vector3.ONE * 0.012, TRIM, 3, 6)
			k.box(Vector3(0, 0.5, front - 0.006), Vector3(0.3, 0.008, 0.012), SHADED)
			_long_sleeve(sleeve, cuff, 0.072, true)
		"pinafore":
			# A blouse (second colour) under a bibbed pinafore dress.
			k.cylinder(Vector3(0, 0.47, 0), Vector3(0, 0.17, 0), 0.205, 0.3, PLAIN, 18, true)
			_hem(k, 0.18, 0.3, SHADED)
			var front := TORSO_RADIUS.z + 0.02
			k.box(Vector3(0, 0.56, front - 0.008), Vector3(0.2, 0.17, 0.03), PLAIN)
			k.box(Vector3(0, 0.55, front + 0.01), Vector3(0.08, 0.06, 0.01), SHADED)
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * 0.08, 0.64, front - 0.006), Vector3(sx * 0.1, 0.77, 0.02), 0.022, 0.022, PLAIN, 6, true)
				k.cylinder(Vector3(sx * 0.1, 0.77, 0.02), Vector3(sx * 0.085, 0.5, -TORSO_RADIUS.z - 0.02), 0.022, 0.022, PLAIN, 6, true)
			_short_sleeve(sleeve)
			_recolour(sleeve, TRIM)
		"pyjama_top":
			# Piped collar and cuffs, buttons and a chest pocket.
			_hem(k, 0.39, 0.214)
			_collar(k)
			var front := TORSO_RADIUS.z + 0.014
			for i in 4:
				k.sphere(Vector3(0, 0.67 - i * 0.07, front + 0.006), Vector3.ONE * 0.013, TRIM, 3, 6)
			k.box(Vector3(-0.09, 0.62, front - 0.002), Vector3(0.07, 0.065, 0.014), PLAIN)
			k.box(Vector3(-0.09, 0.652, front + 0.004), Vector3(0.072, 0.01, 0.01), TRIM)
			k.cylinder(Vector3(0, 0.395, 0), Vector3(0, 0.385, 0), 0.215, 0.215, TRIM, 18, false)
			_long_sleeve(sleeve, cuff, 0.074, false)
			cuff.cylinder(Vector3(0, -ARM_LOWER + 0.045, 0), Vector3(0, -ARM_LOWER + 0.035, 0), 0.08, 0.08, TRIM, 10, false)
		"nightgown":
			# Long and loose to the ankles, with puffed sleeves and a frilled hem.
			k.cylinder(Vector3(0, 0.47, 0), Vector3(0, 0.08, 0), 0.2, 0.31, PLAIN, 20, true)
			for i in 18:
				var a := TAU * i / 18.0
				k.sphere(Vector3(cos(a) * 0.31, 0.085, sin(a) * 0.31), Vector3(0.06, 0.035, 0.06), TRIM, 3, 6)
			k.cylinder(Vector3(0, 0.735, 0), Vector3(0, 0.72, 0), 0.12, 0.13, TRIM, 14, false)
			sleeve.sphere(Vector3(0, -0.025, 0), Vector3(0.09, 0.085, 0.09), PLAIN, 6, 10)
			sleeve.cylinder(Vector3(0, -0.085, 0), Vector3(0, -0.1, 0), 0.07, 0.068, TRIM, 10, false)
		"folk_blouse":
			# Puffed sleeves and a square neck stitched with little flowers.
			_hem(k, 0.4, 0.207)
			var front := TORSO_RADIUS.z + 0.012
			k.box(Vector3(0, 0.7, front - 0.03), Vector3(0.2, 0.012, 0.03), TRIM)
			for i in 7:
				var x := -0.09 + i * 0.03
				k.sphere(Vector3(x, 0.665 - absf(i - 3.0) * 0.006, front + 0.003), Vector3(0.012, 0.012, 0.006), TRIM, 3, 6)
			for i in 5:
				k.sphere(Vector3(-0.06 + i * 0.03, 0.635, front + 0.004), Vector3.ONE * 0.008, SHADED, 2, 5)
			sleeve.sphere(Vector3(0, -0.03, 0), Vector3(0.095, 0.09, 0.095), PLAIN, 6, 10)
			sleeve.cylinder(Vector3(0, -0.1, 0), Vector3(0, -0.115, 0), 0.066, 0.064, TRIM, 10, false)
		"waistcoat":
			# A sleeveless waistcoat over a shirt in the second colour.
			_hem(k, 0.39, 0.214)
			var front := TORSO_RADIUS.z + 0.016
			k.box(Vector3(0, 0.62, front - 0.004), Vector3(0.06, 0.24, 0.012), TRIM)
			for sx: float in [-1.0, 1.0]:
				k.leaf(Vector3(sx * 0.03, 0.76, 0.13), Vector3(sx * 0.7, -0.7, 0.45), 0.09, 0.06, TRIM, 0.0)
			for i in 3:
				k.sphere(Vector3(0.04, 0.6 - i * 0.06, front + 0.008), Vector3.ONE * 0.012, SHADED, 3, 6)
			_long_sleeve(sleeve, cuff, 0.068, false)
			_recolour(sleeve, TRIM)
			_recolour(cuff, TRIM)
		"swimsuit":
			k.sphere(Vector3(0, 0.37, 0), Vector3(0.185, 0.09, 0.156), PLAIN, 6, 16)
			# A little frilled skirt.
			k.cylinder(Vector3(0, 0.38, 0), Vector3(0, 0.3, 0), 0.188, 0.218, TRIM, 18, false)
			for sx: float in [-1.0, 1.0]:
				k.cylinder(Vector3(sx * 0.1, 0.62, 0.12), Vector3(sx * 0.12, 0.76, 0.0), 0.02, 0.02, PLAIN, 6, false)
			sleeve = null
	return {"torso": k.commit(), "sleeve": sleeve.commit() if sleeve else null,
		"cuff": cuff.commit() if not cuff.is_empty() else null}


## Knitted ribbing: fine vertical ridges round a band.
static func _ribs(k: MeshKit, y0: float, y1: float, r: float) -> void:
	for i in 24:
		var a := TAU * i / 24.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		k.cylinder(p + Vector3(0, y0, 0), p + Vector3(0, y1, 0), 0.005, 0.005, SHADED, 3, false)


## Paints every vertex built so far one colour code (PLAIN, SHADED or TRIM).
static func _recolour(k: MeshKit, c: Color) -> void:
	for i in k.colours.size():
		k.colours[i] = c


static func _hem(k: MeshKit, y: float, r: float, c: Color = PLAIN) -> void:
	# A skirt of fabric from inside the body down to the hem, so there's no gap between
	# the body and the hem for trousers to show through.
	k.cylinder(Vector3(0, y + 0.15, 0), Vector3(0, y + 0.05, 0), 0.15, r - 0.01, PLAIN, 18, false)
	k.cylinder(Vector3(0, y + 0.05, 0), Vector3(0, y, 0), r - 0.01, r, c, 18, false)


static func _collar(k: MeshKit) -> void:
	for s: float in [-1.0, 1.0]:
		k.leaf(Vector3(s * 0.02, 0.76, 0.12), Vector3(s * 0.8, -0.6, 0.5), 0.12, 0.08, TRIM, 0.0)


static func _short_sleeve(k: MeshKit) -> void:
	k.sphere(Vector3(0, 0.0, 0), Vector3.ONE * 0.074, PLAIN, 6, 10)
	k.cylinder(Vector3(0, 0.0, 0), Vector3(0, -0.11, 0), 0.074, 0.07, PLAIN, 10, true)


static func _long_sleeve(k: MeshKit, lower: MeshKit, r: float, cuff_shaded: bool) -> void:
	k.sphere(Vector3(0, 0.0, 0), Vector3.ONE * (r + 0.005), PLAIN, 6, 10)
	k.cylinder(Vector3(0, 0.0, 0), Vector3(0, -ARM_UPPER, 0), r, r - 0.003, PLAIN, 10, false)
	lower.sphere(Vector3.ZERO, Vector3.ONE * (r - 0.003), PLAIN, 5, 10)
	lower.cylinder(Vector3.ZERO, Vector3(0, -ARM_LOWER + 0.05, 0), r - 0.003, r - 0.006, PLAIN, 10, false)
	lower.cylinder(Vector3(0, -ARM_LOWER + 0.07, 0), Vector3(0, -ARM_LOWER + 0.035, 0), r + 0.004, r + 0.004, SHADED if cuff_shaded else PLAIN, 10, true)


# --- Bottoms -----------------------------------------------------------------------

## Returns {"hips": ArrayMesh, "leg": thigh piece or null, "shin": lower piece or null}.
static func bottom(style: String) -> Dictionary:
	var k := MeshKit.new()
	var leg := MeshKit.new()
	var shin := MeshKit.new()
	if style != "overalls":
		# Tucked inside the top's hem so nothing pokes out above it.
		k.sphere(Vector3(0, 0.37, 0), Vector3(0.18, 0.085, 0.152), PLAIN, 6, 16)
	match style:
		"shorts":
			leg.cylinder(Vector3(0, 0.03, 0), Vector3(0, -0.1, 0), 0.08, 0.078, PLAIN, 10, true)
		"trousers":
			_trouser_leg(leg, shin, 0.078, 0.072, 0.04)
		"leggings":
			_trouser_leg(leg, shin, 0.07, 0.065, 0.05)
		"skirt":
			k.cylinder(Vector3(0, 0.44, 0), Vector3(0, 0.28, 0), 0.185, 0.27, PLAIN, 18, true)
			leg = null
		"long_skirt":
			k.cylinder(Vector3(0, 0.44, 0), Vector3(0, 0.12, 0), 0.185, 0.3, PLAIN, 18, true)
			leg = null
		"overalls":
			# Worn over the top: a waistband wider than any hem, a bib and straps.
			k.cylinder(Vector3(0, 0.5, 0), Vector3(0, 0.35, 0), 0.222, 0.215, PLAIN, 20, true)
			k.sphere(Vector3(0, 0.36, 0), Vector3(0.215, 0.07, 0.185), PLAIN, 5, 20)
			var front := TORSO_RADIUS.z + 0.03
			k.box(Vector3(0, 0.58, front - 0.01), Vector3(0.22, 0.2, 0.035), PLAIN)
			k.box(Vector3(0, 0.6, front + 0.012), Vector3(0.1, 0.07, 0.01), SHADED)
			for s: float in [-1.0, 1.0]:
				k.cylinder(Vector3(s * 0.085, 0.67, front - 0.005), Vector3(s * 0.11, 0.775, 0.02), 0.022, 0.022, PLAIN, 6, true)
				k.cylinder(Vector3(s * 0.11, 0.775, 0.02), Vector3(s * 0.09, 0.56, -TORSO_RADIUS.z - 0.025), 0.022, 0.022, PLAIN, 6, true)
				k.sphere(Vector3(s * 0.085, 0.66, front + 0.012), Vector3.ONE * 0.017, TRIM, 3, 6)
			_trouser_leg(leg, shin, 0.08, 0.075, 0.04)
		"pleated_skirt":
			k.cylinder(Vector3(0, 0.44, 0), Vector3(0, 0.27, 0), 0.185, 0.275, PLAIN, 24, true)
			for i in 16:
				var a := TAU * i / 16.0
				var top := Vector3(cos(a) * 0.188, 0.43, sin(a) * 0.188)
				var bottom := Vector3(cos(a) * 0.278, 0.275, sin(a) * 0.278)
				k.cylinder(top, bottom, 0.004, 0.007, SHADED, 3, false)
			k.cylinder(Vector3(0, 0.44, 0), Vector3(0, 0.41, 0), 0.19, 0.192, TRIM, 20, false)
			leg = null
		"board_shorts":
			leg.cylinder(Vector3(0, 0.03, 0), Vector3(0, -LEG_UPPER - 0.02, 0), 0.085, 0.084, PLAIN, 10, true)
			# A stripe down the outside of each leg.
			leg.box(Vector3(0.0, -0.05, 0), Vector3(0.175, 0.15, 0.03), TRIM)
			k.cylinder(Vector3(0, 0.42, 0.155), Vector3(0, 0.36, 0.165), 0.008, 0.008, TRIM, 4, true)
		"pyjama_bottoms":
			_trouser_leg(leg, shin, 0.084, 0.08, 0.035)
			shin.cylinder(Vector3(0, -LEG_LOWER + 0.05, 0), Vector3(0, -LEG_LOWER + 0.035, 0), 0.082, 0.082, TRIM, 10, false)
			k.cylinder(Vector3(0, 0.43, 0), Vector3(0, 0.41, 0), 0.185, 0.185, TRIM, 18, false)
		"folk_skirt":
			# Full and swishy, with two ribbon bands near the hem.
			k.cylinder(Vector3(0, 0.44, 0), Vector3(0, 0.2, 0), 0.185, 0.31, PLAIN, 24, true)
			for y: float in [0.26, 0.3]:
				var r := lerpf(0.185, 0.31, (0.44 - y) / 0.24) + 0.004
				k.cylinder(Vector3(0, y + 0.01, 0), Vector3(0, y - 0.01, 0), r - 0.002, r + 0.002, TRIM, 24, false)
			leg = null
		"cargo_shorts":
			leg.cylinder(Vector3(0, 0.03, 0), Vector3(0, -0.11, 0), 0.083, 0.082, PLAIN, 10, true)
			leg.cylinder(Vector3(0, -0.095, 0), Vector3(0, -0.12, 0), 0.088, 0.088, SHADED, 10, true)
			for sx: float in [-1.0, 1.0]:
				leg.box(Vector3(sx * 0.085, -0.04, 0), Vector3(0.02, 0.07, 0.07), SHADED)
	return {"hips": k.commit(), "leg": leg.commit() if leg else null,
		"shin": shin.commit() if not shin.is_empty() else null}


static func _trouser_leg(upper: MeshKit, lower: MeshKit, r_top: float, r_bottom: float, hem: float) -> void:
	upper.cylinder(Vector3(0, 0.03, 0), Vector3(0, -LEG_UPPER, 0), r_top, r_top - 0.002, PLAIN, 10, false)
	lower.sphere(Vector3.ZERO, Vector3.ONE * (r_top - 0.002), PLAIN, 5, 10)
	lower.cylinder(Vector3.ZERO, Vector3(0, -LEG_LOWER + hem, 0), r_top - 0.002, r_bottom, PLAIN, 10, true)


# --- Shoes -------------------------------------------------------------------------

## Built on the shin, so the foot is LEG_LOWER below the knee.
static func shoe(style: String) -> ArrayMesh:
	var k := MeshKit.new()
	var y := -LEG_LOWER
	match style:
		"sneakers":
			k.sphere(Vector3(0, y + 0.01, 0.03), Vector3(0.078, 0.06, 0.115), PLAIN, 6, 12)
			k.sphere(Vector3(0, y - 0.03, 0.03), Vector3(0.082, 0.025, 0.12), TRIM, 4, 12)
		"boots":
			k.cylinder(Vector3(0, y + 0.13, 0), Vector3(0, y, 0), 0.074, 0.078, PLAIN, 10, true)
			k.sphere(Vector3(0, y, 0.035), Vector3(0.078, 0.055, 0.11), PLAIN, 6, 12)
			k.sphere(Vector3(0, y - 0.035, 0.03), Vector3(0.08, 0.022, 0.115), SHADED, 4, 12)
		"flats":
			k.sphere(Vector3(0, y - 0.005, 0.03), Vector3(0.07, 0.045, 0.105), PLAIN, 6, 12)
			k.sphere(Vector3(0, y + 0.02, 0.1), Vector3(0.03, 0.015, 0.012), TRIM, 3, 6)
		"wellies":
			k.cylinder(Vector3(0, y + 0.22, 0), Vector3(0, y, 0), 0.082, 0.08, PLAIN, 10, true)
			k.sphere(Vector3(0, y, 0.035), Vector3(0.08, 0.058, 0.115), PLAIN, 6, 12)
		"sandals":
			# A sole under the bare foot and two straps over it.
			k.sphere(Vector3(0, y - 0.045, 0.025), Vector3(0.075, 0.016, 0.11), TRIM, 4, 12)
			for z: float in [-0.01, 0.07]:
				k.sphere(Vector3(0, y + 0.005, z), Vector3(0.072, 0.03, 0.026), PLAIN, 4, 10)
		"slippers":
			# Fluffy bunny slippers.
			k.sphere(Vector3(0, y + 0.005, 0.035), Vector3(0.085, 0.06, 0.12), PLAIN, 6, 12)
			k.sphere(Vector3(0, y - 0.035, 0.03), Vector3(0.088, 0.02, 0.122), TRIM, 4, 12)
			for sx: float in [-1.0, 1.0]:
				k.sphere(Vector3(sx * 0.03, y + 0.08, 0.06), Vector3(0.018, 0.05, 0.012), PLAIN, 4, 6)
			k.sphere(Vector3(0, y + 0.04, 0.15), Vector3.ONE * 0.012, TRIM, 3, 5)
		"clogs":
			# Painted wooden clogs with an upturned toe.
			k.sphere(Vector3(0, y, 0.035), Vector3(0.08, 0.06, 0.125), PLAIN, 6, 12)
			k.sphere(Vector3(0, y + 0.02, 0.135), Vector3(0.045, 0.035, 0.035), PLAIN, 4, 8)
			k.sphere(Vector3(0, y - 0.04, 0.03), Vector3(0.082, 0.02, 0.12), SHADED, 4, 12)
			k.sphere(Vector3(0, y + 0.045, 0.08), Vector3(0.022, 0.014, 0.012), TRIM, 3, 6)
		"work_boots":
			k.cylinder(Vector3(0, y + 0.14, 0), Vector3(0, y, 0), 0.08, 0.084, PLAIN, 10, true)
			k.sphere(Vector3(0, y - 0.005, 0.04), Vector3(0.088, 0.064, 0.125), PLAIN, 6, 12)
			k.sphere(Vector3(0, y - 0.045, 0.035), Vector3(0.092, 0.028, 0.13), SHADED, 4, 12)
			for i in 3:
				k.cylinder(Vector3(-0.04, y + 0.03 + i * 0.035, 0.07 - i * 0.01), Vector3(0.04, y + 0.03 + i * 0.035, 0.07 - i * 0.01), 0.007, 0.007, TRIM, 4, true)
	return k.commit()


# --- Hair --------------------------------------------------------------------------

## Hair around the head centre. Under a hat (`hat_on`) the hair is pulled in and the
## fringe sits low; with anything on top of the head (`hat_on` or `topped`), tufts and
## buns up there are left off so they don't poke through.
static func hair(style: String, hat_on: bool, topped: bool = false) -> ArrayMesh:
	var k := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(style)
	# Under a hat the hair is pulled in tight and the fringe sits low, so the hat
	# covers everything above its band.
	_hat_on = hat_on
	var covered := hat_on or topped
	var cap_radius := Vector3(0.405, 0.31, 0.39) * (0.93 if hat_on else 1.0)
	var cap_centre := Vector3(0, 0.06 if hat_on else 0.075, -0.035)
	if style == "buzz":
		k.sphere(Vector3(0, 0.06, -0.03), Vector3(0.388, 0.29, 0.372), PLAIN, 12, 20)
		k.sphere(Vector3(0, -0.03, -0.09), Vector3(0.37, 0.27, 0.29), PLAIN, 10, 18)
		return k.commit()
	if style != "afro":
		k.sphere(cap_centre, cap_radius, PLAIN, 12, 22)
		# Covers the back of the head down to the nape.
		k.sphere(Vector3(0, -0.04, -0.1), Vector3(0.375, 0.28, 0.29), PLAIN, 10, 18)
	match style:
		"short":
			_bangs(k, 4, 0.085)
		"messy":
			_bangs(k, 5, 0.09)
			if not covered:
				for i in 7:
					var a := rng.randf() * TAU
					var base := Vector3(cos(a) * 0.18, 0.3, sin(a) * 0.15 - 0.06)
					k.cone(base, base + Vector3(cos(a) * 0.12, 0.14, sin(a) * 0.1), 0.07, PLAIN, 6)
		"side_part":
			_bangs(k, 3, 0.08, -0.12)
			if covered:
				return k.commit()
			k.xform = Transform3D(Basis(Vector3.FORWARD, 0.5), Vector3(0.12, 0.2, 0.25))
			k.sphere(Vector3.ZERO, Vector3(0.2, 0.08, 0.12), PLAIN, 6, 12)
			k.xform = Transform3D.IDENTITY
		"spiky":
			_bangs(k, 4, 0.07)
			if not covered:
				for i in 9:
					var a := TAU * i / 9.0
					var base := Vector3(cos(a) * 0.2, 0.22, sin(a) * 0.2 - 0.05)
					var tip := base + Vector3(cos(a) * 0.14, 0.2, sin(a) * 0.14 - 0.06)
					k.cone(base, tip, 0.085, PLAIN, 6)
		"bob":
			_bangs(k, 5, 0.1)
			_side_volume(k, -0.16, 0.13)
		"long":
			_bangs(k, 5, 0.1)
			_side_volume(k, -0.42, 0.12)
			k.sphere(Vector3(0, -0.2, -0.2), Vector3(0.33, 0.4, 0.16), PLAIN, 8, 14)
		"ponytail":
			_bangs(k, 4, 0.09)
			k.sphere(Vector3(0, 0.08, -0.4), Vector3.ONE * 0.05, TRIM, 4, 8)
			_tail(k, Vector3(0, 0.08, -0.44), Vector3(0, -0.12, -0.06), 4, 0.1)
		"pigtails":
			_bangs(k, 4, 0.09)
			for s: float in [-1.0, 1.0]:
				k.sphere(Vector3(s * 0.38, 0.02, -0.12), Vector3.ONE * 0.045, TRIM, 4, 8)
				_tail(k, Vector3(s * 0.42, 0.0, -0.13), Vector3(s * 0.04, -0.11, -0.01), 4, 0.085)
		"bun":
			_bangs(k, 4, 0.09)
			if not covered:
				k.sphere(Vector3(0, 0.36, -0.12), Vector3(0.15, 0.13, 0.15), PLAIN, 8, 12)
		"space_buns":
			_bangs(k, 4, 0.09)
			if not covered:
				for s: float in [-1.0, 1.0]:
					k.sphere(Vector3(s * 0.24, 0.3, -0.06), Vector3.ONE * 0.12, PLAIN, 8, 12)
		"braid":
			_bangs(k, 4, 0.09)
			_tail(k, Vector3(0, -0.08, -0.38), Vector3(0, -0.085, -0.015), 6, 0.075)
		"curly":
			_bangs(k, 5, 0.1)
			_lumps(k, rng, 26, 0.42, 0.1, covered)
		"afro":
			k.sphere(Vector3(0, 0.12, -0.06) if not hat_on else Vector3(0, 0.04, -0.06), Vector3(0.5, 0.42, 0.48) if not hat_on else Vector3(0.43, 0.28, 0.42), PLAIN, 12, 20, 0.0, 0.06, 3)
			_lumps(k, rng, 40, 0.5 if not hat_on else 0.44, 0.12, covered)
	return k.commit()


## A row of fringe lumps across the forehead, hugging the head.
static func _bangs(k: MeshKit, count: int, size: float, shift: float = 0.0) -> void:
	if _hat_on:
		size *= 0.75
	for i in count:
		var t := (i + 0.5) / count
		var x := lerpf(-0.25, 0.25, t) + shift
		var y := (0.085 if _hat_on else 0.15) + 0.03 * sin(t * PI)
		var z := _head_front(x, y) + 0.015
		k.sphere(Vector3(x, y, z - 0.03), Vector3(size, size * 0.85, size * 0.7), PLAIN, 5, 8)


## Hair falling at the sides of the face down to `bottom`.
static func _side_volume(k: MeshKit, bottom: float, thickness: float) -> void:
	for s: float in [-1.0, 1.0]:
		var top := 0.1
		var centre := Vector3(s * 0.33, (top + bottom) * 0.5, -0.04)
		k.sphere(centre, Vector3(thickness, (top - bottom) * 0.5 + 0.06, 0.27), PLAIN, 8, 12)


## A chain of shrinking lumps (ponytails, pigtails, braids).
static func _tail(k: MeshKit, start: Vector3, step: Vector3, count: int, size: float) -> void:
	for i in count:
		var r := size * lerpf(1.0, 0.65, float(i) / count)
		k.sphere(start + step * i, Vector3(r, r * 1.1, r), PLAIN, 6, 10)


## Curly lumps over the top and back of the head, avoiding the face.
static func _lumps(k: MeshKit, rng: RandomNumberGenerator, count: int, radius: float, size: float, hat_on: bool) -> void:
	for i in count:
		# Fibonacci sphere for even spacing.
		var y := 1.0 - (i + 0.5) / count * 1.6
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var a := i * 2.39996
		var dir := Vector3(cos(a) * r, y, sin(a) * r)
		if dir.z > 0.45 and dir.y < 0.55:
			continue
		if hat_on and dir.y > 0.35:
			continue
		var pos := Vector3(0, 0.08, -0.05) + dir * radius * Vector3(1.0, 0.85, 0.95)
		k.sphere(pos, Vector3.ONE * size * rng.randf_range(0.85, 1.15), PLAIN, 5, 8)


## Z of the front of the head at (x, y), relative to the head centre.
static func _head_front(x: float, y: float) -> float:
	var q := 1.0 - pow(x / HEAD_RADIUS.x, 2) - pow(y / HEAD_RADIUS.y, 2)
	return HEAD_RADIUS.z * sqrt(maxf(q, 0.0))


# --- Hats and glasses --------------------------------------------------------------

static func hat(style: String) -> ArrayMesh:
	var k := MeshKit.new()
	match style:
		"cap":
			k.sphere(Vector3(0, 0.16, -0.02), Vector3(0.405, 0.25, 0.4), PLAIN, 8, 18)
			k.sphere(Vector3(0, 0.15, 0.36), Vector3(0.22, 0.025, 0.2), PLAIN, 4, 14)
			k.sphere(Vector3(0, 0.41, -0.02), Vector3.ONE * 0.03, TRIM, 3, 6)
		"beanie":
			k.sphere(Vector3(0, 0.15, -0.03), Vector3(0.41, 0.3, 0.4), PLAIN, 8, 18)
			k.cylinder(Vector3(0, 0.06, -0.03), Vector3(0, 0.15, -0.03), 0.415, 0.41, SHADED, 20, false)
			k.sphere(Vector3(0, 0.46, -0.03), Vector3.ONE * 0.07, TRIM, 5, 8)
		"bucket":
			k.sphere(Vector3(0, 0.2, -0.02), Vector3(0.39, 0.22, 0.39), PLAIN, 8, 18)
			k.cylinder(Vector3(0, 0.15, -0.02), Vector3(0, 0.1, -0.02), 0.41, 0.53, PLAIN, 22, true)
		"straw":
			k.sphere(Vector3(0, 0.22, -0.02), Vector3(0.37, 0.2, 0.37), PLAIN, 8, 18)
			k.cylinder(Vector3(0, 0.16, -0.02), Vector3(0, 0.12, -0.02), 0.4, 0.66, PLAIN, 24, true)
			k.cylinder(Vector3(0, 0.15, -0.02), Vector3(0, 0.22, -0.02), 0.385, 0.375, TRIM, 20, false)
		"beret":
			k.xform = Transform3D(Basis(Vector3.FORWARD, -0.2), Vector3(0.05, 0.31, -0.02))
			k.sphere(Vector3.ZERO, Vector3(0.44, 0.13, 0.42), PLAIN, 6, 18)
			k.sphere(Vector3(0, 0.13, 0), Vector3.ONE * 0.03, PLAIN, 3, 6)
			k.xform = Transform3D.IDENTITY
		"bow":
			# Built round its knot, facing +z: the character model sets it on the hair
			# (Appearance "positions": "at" and "face").
			for s: float in [-1.0, 1.0]:
				k.sphere(Vector3(s * 0.08, 0, 0), Vector3(0.08, 0.06, 0.04), PLAIN, 5, 8)
			k.sphere(Vector3(0, 0, 0.01), Vector3.ONE * 0.035, TRIM, 4, 6)
		"flower_crown":
			for i in 11:
				var a := TAU * i / 11.0
				var centre := Vector3(cos(a) * 0.37, 0.2 + 0.02 * sin(a * 3.0), sin(a) * 0.36 - 0.02)
				for p in 5:
					var pa := TAU * p / 5.0
					k.sphere(centre + Vector3(cos(pa), sin(pa), 0.3).normalized() * 0.03, Vector3.ONE * 0.026, PLAIN, 3, 6)
				k.sphere(centre + Vector3(0, 0, 0.01), Vector3.ONE * 0.018, TRIM, 3, 6)
		"earmuffs":
			for i in 8:
				var a0 := PI * i / 8.0
				var a1 := PI * (i + 1) / 8.0
				k.cylinder(Vector3(cos(a0) * 0.46, sin(a0) * 0.45, -0.04), Vector3(cos(a1) * 0.46, sin(a1) * 0.45, -0.04), 0.025, 0.025, PLAIN, 5, false)
			for sx: float in [-1.0, 1.0]:
				# Fluffy muffs, outside any hairstyle.
				k.sphere(Vector3(sx * 0.46, -0.02, -0.02), Vector3(0.08, 0.13, 0.12), TRIM, 5, 10)
		"sou_wester":
			k.sphere(Vector3(0, 0.2, -0.02), Vector3(0.405, 0.25, 0.4), PLAIN, 8, 18)
			k.sphere(Vector3(0, 0.12, -0.1), Vector3(0.56, 0.035, 0.6), PLAIN, 5, 20)
			k.cylinder(Vector3(0, 0.12, -0.02), Vector3(0, 0.17, -0.02), 0.41, 0.405, SHADED, 20, false)
		"sun_hat":
			k.sphere(Vector3(0, 0.22, -0.02), Vector3(0.36, 0.2, 0.36), PLAIN, 8, 18)
			k.sphere(Vector3(0, 0.15, -0.02), Vector3(0.72, 0.03, 0.72), PLAIN, 5, 24)
			k.cylinder(Vector3(0, 0.15, -0.02), Vector3(0, 0.23, -0.02), 0.37, 0.36, TRIM, 20, false)
			k.sphere(Vector3(0.3, 0.2, 0.18), Vector3(0.07, 0.05, 0.03), TRIM, 4, 8)
		"headscarf":
			k.sphere(Vector3(0, 0.12, -0.03), Vector3(0.405, 0.27, 0.39), PLAIN, 8, 18)
			k.sphere(Vector3(0, 0.0, -0.37), Vector3(0.07, 0.06, 0.05), PLAIN, 4, 8)
			for sx: float in [-1.0, 1.0]:
				k.leaf(Vector3(sx * 0.03, -0.02, -0.39), Vector3(sx * 0.6, -1.0, -0.4), 0.16, 0.08, PLAIN, 0.0)
		"nightcap":
			# A long floppy cap drooping to one side, with a bobble.
			k.sphere(Vector3(0, 0.14, -0.03), Vector3(0.41, 0.28, 0.4), PLAIN, 8, 18)
			k.cylinder(Vector3(0, 0.05, -0.03), Vector3(0, 0.12, -0.03), 0.415, 0.41, TRIM, 20, false)
			var prev := Vector3(0, 0.38, -0.03)
			var r := 0.17
			for i in 5:
				var t := float(i + 1) / 5.0
				var p := Vector3(0.1 + t * 0.4, 0.42 + sin(t * PI) * 0.06 - t * t * 0.4, 0.0)
				k.cylinder(prev, p, r, r * 0.72, PLAIN, 10, false)
				k.sphere(p, Vector3.ONE * r * 0.72, PLAIN, 4, 8)
				prev = p
				r *= 0.72
			k.sphere(prev + Vector3(0.02, -0.04, 0), Vector3.ONE * 0.06, TRIM, 4, 8)
		"cat_ears":
			k.cylinder(Vector3(-0.36, 0.12, 0), Vector3(0.36, 0.12, 0), 0.015, 0.015, PLAIN, 6, false)
			for s: float in [-1.0, 1.0]:
				k.cone(Vector3(s * 0.2, 0.26, -0.03), Vector3(s * 0.26, 0.46, -0.04), 0.1, PLAIN, 8)
				k.cone(Vector3(s * 0.2, 0.27, 0.0), Vector3(s * 0.25, 0.42, -0.01), 0.055, TRIM, 6)
	return k.commit()


static func glasses(style: String) -> ArrayMesh:
	var k := MeshKit.new()
	var y := -0.035
	for s: float in [-1.0, 1.0]:
		var x := s * 0.125
		var z := _head_front(x, y) + 0.02
		var centre := Vector3(x, y, z)
		match style:
			"round", "sunnies":
				_ring(k, centre, 0.062, 0.062, 0.009)
				if style == "sunnies":
					k.sphere(centre - Vector3(0, 0, 0.005), Vector3(0.06, 0.06, 0.008), TRIM, 4, 12)
			"square":
				_ring(k, centre, 0.07, 0.052, 0.009)
	var bz := _head_front(0.0, y) + 0.02
	k.cylinder(Vector3(-0.065, y + 0.01, bz), Vector3(0.065, y + 0.01, bz), 0.008, 0.008, PLAIN, 4, false)
	return k.commit()


static func _ring(k: MeshKit, centre: Vector3, rx: float, ry: float, thick: float) -> void:
	var segments := 14
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := centre + Vector3(cos(a0) * rx, sin(a0) * ry, 0)
		var p1 := centre + Vector3(cos(a1) * rx, sin(a1) * ry, 0)
		k.cylinder(p0, p1, thick, thick, PLAIN, 4, false)
