class_name DayNight
extends Node3D
## Sun, moon, ambient light and sky colours driven by the game clock.

## [hour, lit tint, shadow tint, sky top, sky horizon]
## Lit and shadow tints multiply the palette colours (see shaders/include/toon_light),
## so by day sunlit things show their true colour and shadows go soft lavender.
const KEYS := [
	[0.0, "9eaae0", "6b72a8", "27346b", "4d5a92"],
	[4.5, "a2a6dc", "7070a6", "34407a", "6e6d9e"],
	[6.0, "ffd9cf", "b9aed6", "7f9bd6", "f7c8bc"],
	[8.0, "fff6ea", "c0b8e6", "86bdf0", "f5e6dc"],
	[11.0, "fffcf4", "c3bce8", "8cc4f2", "eef0f6"],
	[15.5, "fffaf0", "c2bae6", "8cc2f0", "f2eef2"],
	[17.5, "ffe2c4", "c0a6d2", "93a6e0", "f8d0b4"],
	[19.0, "f0bcc4", "a194c4", "5f68aa", "e6a8b4"],
	[20.5, "a4b0e2", "6e76aa", "2e3b76", "5a6398"],
	[24.0, "9eaae0", "6b72a8", "27346b", "4d5a92"],
]

var sun: DirectionalLight3D
var env: Environment
var sky_material: ShaderMaterial
## Overrides the clock when >= 0 (used for screenshots).
var fixed_hour := -1.0
## Inside a home the light is warm and steady whatever the time.
var indoors := false:
	set(value):
		indoors = value
		env.background_mode = Environment.BG_COLOR if value else Environment.BG_SKY
		_apply(_hour())


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	sun.shadow_blur = 0.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)

	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Ambient comes from cel_shadow in the shaders instead.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 60.0
	env.fog_depth_end = 260.0
	env.fog_sky_affect = 0.0
	env.background_color = Color("2e2530")
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_apply(_hour())


func _process(_delta: float) -> void:
	_apply(_hour())


func _hour() -> float:
	return fixed_hour if fixed_hour >= 0.0 else GameClock.hour_float()


func _apply(hour: float) -> void:
	if indoors:
		RenderingServer.global_shader_parameter_set("cel_lit", Vector3(1.0, 0.96, 0.9))
		RenderingServer.global_shader_parameter_set("cel_shadow", Vector3(0.8, 0.73, 0.82))
		sun.rotation_degrees = Vector3(-60, -24, 0)
		return
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if hour >= KEYS[i][0] and hour <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := inverse_lerp(a[0], b[0], hour)
	var lit := Color(a[1]).lerp(Color(b[1]), t)
	var shade := Color(a[2]).lerp(Color(b[2]), t)
	var horizon := Color(a[4]).lerp(Color(b[4]), t)
	RenderingServer.global_shader_parameter_set("cel_lit", Vector3(lit.r, lit.g, lit.b))
	RenderingServer.global_shader_parameter_set("cel_shadow", Vector3(shade.r, shade.g, shade.b))
	env.fog_light_color = horizon
	sky_material.set_shader_parameter("top_colour", Color(a[3]).lerp(Color(b[3]), t))
	sky_material.set_shader_parameter("horizon_colour", horizon)
	sky_material.set_shader_parameter("sun_colour", lit)

	# The sun (or moon) arcs from east to west, always from the south so shadows fall
	# away from the camera and never get too long.
	var daytime := hour >= 5.0 and hour < 20.0
	var progress := inverse_lerp(5.0, 20.0, hour) if daytime else fposmod(hour - 20.0, 24.0) / 9.0
	var azimuth := lerpf(-65.0, 65.0, progress)
	var elevation := lerpf(30.0, 62.0, sin(progress * PI))
	sun.rotation_degrees = Vector3(-elevation, azimuth, 0)
	sky_material.set_shader_parameter("sun_direction", sun.global_transform.basis.z)
