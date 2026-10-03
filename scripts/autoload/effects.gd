extends Node
## Particle effects, all from one cheap recipe: CPU particles drawn as camera-facing
## quads with procedural shapes (shaders/particle*.gdshader), so they work on the
## Compatibility renderer and on phones.
##
##   Effects.burst("sparkle", position)          a one-off puff that cleans itself up
##   var e := Effects.emitter("flame"); add it   a continuous effect (fires, smoke)
##
## Kinds are listed in KINDS. Colours are sRGB.

const SHAPES := {"dot": 0, "sparkle": 1, "leaf": 2, "heart": 3, "flame": 4, "puff": 5, "chip": 6, "ring": 7}

## Each kind: shape, glow (added light), amount, lifetime, size [min, max], colours
## (picked at random per particle), speed [min, max], direction, spread (degrees),
## gravity, box or radius to emit from, one_shot, grow (scale at end vs start), spin.
const KINDS := {
	# One-off bursts.
	"sparkle": {"shape": "sparkle", "glow": true, "amount": 14, "lifetime": 0.8, "size": [0.12, 0.24],
		"colours": ["fff3b0", "ffd6e8", "d8f3ff"], "speed": [1.2, 2.4], "direction": [0, 1, 0], "spread": 180.0,
		"gravity": -1.5, "radius": 0.2, "one_shot": true, "grow": 0.0},
	"confetti": {"shape": "chip", "amount": 24, "lifetime": 1.1, "size": [0.06, 0.1],
		"colours": ["f2a7a0", "f6d58c", "9fd3c7", "b9b3e6", "aadfc8"], "speed": [2.2, 3.4], "direction": [0, 1, 0],
		"spread": 40.0, "gravity": -6.0, "radius": 0.15, "one_shot": true, "grow": 1.0, "spin": 8.0},
	"leaves": {"shape": "leaf", "amount": 8, "lifetime": 1.8, "size": [0.12, 0.18],
		"colours": ["7fbf80", "9cd28f", "6aac72"], "speed": [0.3, 0.9], "direction": [0, -1, 0], "spread": 70.0,
		"gravity": -0.8, "box": [0.9, 0.3, 0.9], "one_shot": true, "grow": 1.0, "spin": 3.0},
	"chips": {"shape": "chip", "amount": 7, "lifetime": 0.6, "size": [0.05, 0.08], "colours": ["d4a77e", "f6dcb4"],
		"speed": [1.8, 2.8], "direction": [0, 1, 0], "spread": 60.0, "gravity": -9.0, "radius": 0.1,
		"one_shot": true, "grow": 1.0, "spin": 10.0},
	"pebbles": {"shape": "chip", "amount": 6, "lifetime": 0.5, "size": [0.05, 0.08], "colours": ["bdb8cc", "a8a2b8"],
		"speed": [1.6, 2.6], "direction": [0, 1, 0], "spread": 60.0, "gravity": -9.0, "radius": 0.1,
		"one_shot": true, "grow": 1.0, "spin": 10.0},
	"sparks": {"shape": "sparkle", "glow": true, "amount": 8, "lifetime": 0.35, "size": [0.06, 0.12],
		"colours": ["ffe08a", "ffb36b"], "speed": [2.0, 3.5], "direction": [0, 1, 0], "spread": 80.0,
		"gravity": -6.0, "radius": 0.05, "one_shot": true, "grow": 0.0},
	"dust": {"shape": "puff", "amount": 8, "lifetime": 0.55, "size": [0.18, 0.3], "colours": ["efe4d0", "e2d6c0"],
		"speed": [0.6, 1.2], "direction": [0, 0.3, 0], "spread": 90.0, "gravity": 0.0, "radius": 0.3,
		"one_shot": true, "grow": 1.6, "fade": true},
	"hearts": {"shape": "heart", "amount": 4, "lifetime": 1.3, "size": [0.14, 0.2], "colours": ["f48fa6", "f7b2c4"],
		"speed": [0.6, 0.9], "direction": [0, 1, 0], "spread": 25.0, "gravity": 0.2, "radius": 0.15,
		"one_shot": true, "grow": 0.6},
	"crumbs": {"shape": "chip", "amount": 8, "lifetime": 0.5, "size": [0.03, 0.05], "colours": ["f2d9a6", "e8c486"],
		"speed": [0.8, 1.6], "direction": [0, 0.5, 1], "spread": 50.0, "gravity": -7.0, "radius": 0.04,
		"one_shot": true, "grow": 1.0, "spin": 8.0},
	"splash": {"shape": "dot", "amount": 12, "lifetime": 0.6, "size": [0.06, 0.1], "colours": ["e4f6f2", "bfe6ec"],
		"speed": [1.5, 2.5], "direction": [0, 1, 0], "spread": 35.0, "gravity": -9.0, "radius": 0.15,
		"one_shot": true, "grow": 0.5},
	"zzz": {"shape": "ring", "amount": 3, "lifetime": 1.8, "size": [0.1, 0.16], "colours": ["c9d8f2"],
		"speed": [0.35, 0.5], "direction": [0.3, 1, 0], "spread": 10.0, "gravity": 0.0, "radius": 0.05,
		"one_shot": true, "grow": 1.8, "fade": true, "explosive": 0.0},
	# Continuous effects.
	"flame": {"shape": "flame", "glow": true, "amount": 18, "lifetime": 0.6, "size": [0.26, 0.4],
		"colours": ["ffb347", "ffd27a", "ff8f5a"], "speed": [0.5, 0.9], "direction": [0, 1, 0], "spread": 12.0,
		"gravity": 0.3, "radius": 0.13, "grow": 0.2},
	"embers": {"shape": "dot", "glow": true, "amount": 6, "lifetime": 1.8, "size": [0.04, 0.06],
		"colours": ["ffb36b", "ffd27a"], "speed": [0.7, 1.2], "direction": [0, 1, 0], "spread": 25.0,
		"gravity": 0.0, "radius": 0.15, "grow": 0.3},
	"smoke": {"shape": "puff", "amount": 7, "lifetime": 3.0, "size": [0.25, 0.35], "colours": ["f4f0ec", "e6e1df"],
		"speed": [0.4, 0.6], "direction": [0.15, 1, 0], "spread": 10.0, "gravity": 0.05, "radius": 0.08,
		"grow": 2.6, "fade": true, "alpha": 0.45},
	"candle": {"shape": "flame", "glow": true, "amount": 5, "lifetime": 0.4, "size": [0.05, 0.08],
		"colours": ["ffd27a", "ffb347"], "speed": [0.15, 0.3], "direction": [0, 1, 0], "spread": 5.0,
		"gravity": 0.0, "radius": 0.005, "grow": 0.3},
	"fireflies": {"shape": "dot", "glow": true, "amount": 40, "lifetime": 5.0, "size": [0.1, 0.16],
		"colours": ["eaff9a", "fff3a0"], "speed": [0.1, 0.35], "direction": [0, 0.2, 0], "spread": 180.0,
		"gravity": 0.0, "box": [14.0, 1.2, 11.0], "grow": 1.0, "fade": true},
	"spores": {"shape": "dot", "glow": true, "amount": 6, "lifetime": 4.0, "size": [0.05, 0.09],
		"colours": ["9ff0d8", "b6f7c2", "a9e4ff"], "speed": [0.15, 0.3], "direction": [0, 1, 0], "spread": 30.0,
		"gravity": 0.0, "box": [1.6, 0.1, 1.6], "grow": 1.0, "fade": true},
	"moss_glow": {"shape": "dot", "glow": true, "amount": 3, "lifetime": 3.0, "size": [0.5, 0.8],
		"colours": ["5fc9a8", "6ad6b8"], "speed": [0.0, 0.0], "direction": [0, 1, 0], "spread": 0.0,
		"gravity": 0.0, "box": [1.2, 0.0, 1.2], "grow": 1.0, "fade": true, "alpha": 0.22},
	"petals": {"shape": "leaf", "amount": 10, "lifetime": 7.0, "size": [0.08, 0.12],
		"colours": ["f7c6d4", "fbe3ea", "fff1c9"], "speed": [0.5, 0.9], "direction": [1, -0.25, 0.3], "spread": 20.0,
		"gravity": 0.0, "box": [16.0, 3.0, 12.0], "grow": 1.0, "spin": 2.0, "fade": true},
	"motes": {"shape": "dot", "glow": true, "amount": 14, "lifetime": 6.0, "size": [0.03, 0.05],
		"colours": ["fff3d6"], "speed": [0.05, 0.12], "direction": [0, 1, 0], "spread": 180.0,
		"gravity": 0.0, "box": [3.5, 1.2, 3.0], "grow": 1.0, "fade": true, "alpha": 0.6},
}

var _materials: Dictionary = {}
var _quad: QuadMesh


func _ready() -> void:
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE


## A one-off effect at a world position; it frees itself when done.
func burst(kind: String, at: Vector3, parent: Node = null) -> void:
	var host := parent if parent else get_tree().current_scene
	if host == null:
		return
	var p := emitter(kind)
	# Placed before it joins the tree: particles in world space start from wherever the
	# emitter was when it entered.
	var origin: Transform3D = host.global_transform if host is Node3D else Transform3D.IDENTITY
	p.position = origin.affine_inverse() * at
	host.add_child(p)
	p.emitting = true
	var life: float = p.lifetime * (1.0 + p.randomness) + 0.2
	get_tree().create_timer(life).timeout.connect(p.queue_free)


## A ready-made particle node for a kind (continuous unless the kind is one_shot).
func emitter(kind: String) -> CPUParticles3D:
	var cfg: Dictionary = KINDS[kind]
	var p := CPUParticles3D.new()
	p.name = kind.capitalize().replace(" ", "")
	p.mesh = _quad
	p.material_override = _material(cfg)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = cfg["amount"]
	p.lifetime = cfg["lifetime"]
	p.one_shot = cfg.get("one_shot", false)
	p.explosiveness = cfg.get("explosive", 1.0 if p.one_shot else 0.0)
	p.randomness = 0.3
	p.local_coords = false
	p.fixed_fps = 30
	var dir: Array = cfg["direction"]
	p.direction = Vector3(dir[0], dir[1], dir[2])
	p.spread = cfg["spread"]
	p.gravity = Vector3(0, cfg["gravity"], 0)
	p.initial_velocity_min = cfg["speed"][0]
	p.initial_velocity_max = cfg["speed"][1]
	p.scale_amount_min = cfg["size"][0]
	p.scale_amount_max = cfg["size"][1]
	var spin: float = cfg.get("spin", 0.0)
	if spin > 0.0:
		p.angular_velocity_min = -spin * 57.3
		p.angular_velocity_max = spin * 57.3
		p.angle_max = 360.0
	if cfg.has("box"):
		var b: Array = cfg["box"]
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(b[0], b[1], b[2]) * 0.5
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = cfg.get("radius", 0.1)
	# Size over life: from full size to `grow` times it.
	var curve := Curve.new()
	curve.max_value = maxf(1.0, cfg.get("grow", 1.0))
	curve.add_point(Vector2(0, 1.0 if cfg.get("grow", 1.0) <= 1.0 else 0.6))
	curve.add_point(Vector2(1, cfg.get("grow", 1.0)))
	p.scale_amount_curve = curve
	# Colours: picked per particle; fading in and out over its life.
	var picks := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	var colours: Array = cfg["colours"]
	for i in colours.size():
		offsets.append(float(i) / colours.size())
		cols.append(Color(colours[i]))
	picks.offsets = offsets
	picks.colors = cols
	picks.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = picks
	var alpha: float = cfg.get("alpha", 1.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0 if cfg.get("fade", false) else alpha))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	if cfg.get("fade", false) or not p.one_shot:
		fade.add_point(0.2, Color(1, 1, 1, alpha))
		fade.add_point(0.7, Color(1, 1, 1, alpha))
	p.color_ramp = fade
	return p


func _material(cfg: Dictionary) -> ShaderMaterial:
	var key := "%s:%s" % [cfg["shape"], cfg.get("glow", false)]
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/particle_glow.gdshader" if cfg.get("glow", false) else "res://shaders/particle.gdshader")
		mat.set_shader_parameter("shape", SHAPES[cfg["shape"]])
		mat.set_shader_parameter("glow", 0.6 if cfg.get("glow", false) else 0.0)
		_materials[key] = mat
	return _materials[key]
