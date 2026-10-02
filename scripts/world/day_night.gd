class_name DayNight
extends Node3D
## Sun, moon, ambient light and sky colours driven by the game clock.

## [hour, sun colour, sun energy, ambient colour, ambient energy, sky top, sky horizon]
const KEYS := [
	[0.0, "8fa6e0", 0.35, "3d4f86", 0.75, "0f1c3d", "2b3d6b"],
	[4.5, "8fa6e0", 0.3, "4a4f86", 0.75, "1d2a55", "4b4f7d"],
	[6.0, "f0a59a", 0.6, "8e86b8", 0.8, "4f6fb0", "f2b8a2"],
	[8.0, "ffe2b8", 1.05, "a7bde0", 0.65, "5d9fe0", "f3e1c6"],
	[11.0, "fff4dd", 1.25, "aecbec", 0.68, "4d97e0", "d6ecf4"],
	[15.5, "fff0d0", 1.2, "abc6e6", 0.68, "4f95dc", "dcecf0"],
	[17.5, "ffc583", 1.05, "b5a3c4", 0.7, "6582c6", "f6c08a"],
	[19.0, "e5898a", 0.6, "7d6aa6", 0.8, "3f4886", "d88c8e"],
	[20.5, "8fa6e0", 0.35, "44518c", 0.75, "15224a", "34406f"],
	[24.0, "8fa6e0", 0.35, "3d4f86", 0.75, "0f1c3d", "2b3d6b"],
]

var sun: DirectionalLight3D
var env: Environment
var sky_material: ShaderMaterial
## Overrides the clock when >= 0 (used for screenshots).
var fixed_hour := -1.0


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
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
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.tonemap_exposure = 1.0
	env.fog_enabled = Game.args.get("view", "") != "overview"
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 220.0
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_apply(_hour())


func _process(_delta: float) -> void:
	_apply(_hour())


func _hour() -> float:
	return fixed_hour if fixed_hour >= 0.0 else GameClock.hour_float()


func _apply(hour: float) -> void:
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if hour >= KEYS[i][0] and hour <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := inverse_lerp(a[0], b[0], hour)
	var sun_colour := Color(a[1]).lerp(Color(b[1]), t)
	var horizon := Color(a[6]).lerp(Color(b[6]), t)
	sun.light_color = sun_colour
	sun.light_energy = lerpf(a[2], b[2], t)
	env.ambient_light_color = Color(a[3]).lerp(Color(b[3]), t)
	env.ambient_light_energy = lerpf(a[4], b[4], t)
	env.fog_light_color = horizon
	sky_material.set_shader_parameter("top_colour", Color(a[5]).lerp(Color(b[5]), t))
	sky_material.set_shader_parameter("horizon_colour", horizon)
	sky_material.set_shader_parameter("sun_colour", sun_colour)

	# The sun (or moon) arcs from east to west, always from the south so shadows fall
	# away from the camera and never get too long.
	var daytime := hour >= 5.0 and hour < 20.0
	var progress := inverse_lerp(5.0, 20.0, hour) if daytime else fposmod(hour - 20.0, 24.0) / 9.0
	var azimuth := lerpf(-65.0, 65.0, progress)
	var elevation := lerpf(30.0, 62.0, sin(progress * PI))
	sun.rotation_degrees = Vector3(-elevation, azimuth, 0)
	sky_material.set_shader_parameter("sun_direction", sun.global_transform.basis.z)
