class_name DayNight
extends Node3D
## Sun, moon, ambient light and sky colours driven by the game clock, and the weather
## (Weather) on top: grey, flat light under cloud, darker storms with lightning, morning
## mist, and the weather's shader globals (wet ground, snow, autumn leaves...).

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
## Lightning: how bright the current flash is, and when the next one comes.
var _flash := 0.0
var _next_flash := 4.0
var _second_flash := -1.0
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


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 7.0)
	if Weather.storm > 0.5 and not indoors:
		_next_flash -= delta
		if _second_flash > 0.0:
			_second_flash -= delta
			if _second_flash <= 0.0:
				_flash = 0.8
		if _next_flash <= 0.0:
			_flash = 1.0
			# The rumble follows the flash, closer storms sooner.
			Sfx.play_later("thunder", randf_range(0.4, 2.5), randf_range(-6.0, 0.0), randf_range(0.85, 1.1))
			_second_flash = 0.12 if randf() < 0.6 else -1.0
			_next_flash = randf_range(5.0, 14.0)
	_apply(_hour())


func _hour() -> float:
	return fixed_hour if fixed_hour >= 0.0 else GameClock.hour_float()


## How strongly glowing things glow: 0 by day, 1 at night (fading at dusk and dawn).
static func glow_at(hour: float) -> float:
	return maxf(smoothstep(17.5, 19.5, hour), 1.0 - smoothstep(5.0, 6.5, hour))


func _apply(hour: float) -> void:
	# Indoors the lamps are always on, so glowing things keep a little glow by day too.
	var glow := glow_at(hour)
	RenderingServer.global_shader_parameter_set("night", glow)
	RenderingServer.global_shader_parameter_set("night_glow", 0.5 + glow * 0.5 if indoors else glow)
	if indoors:
		# Warm and steady, a little dimmer and cosier once it's dark outside.
		var lit := Vector3(1.0, 0.96, 0.9).lerp(Vector3(0.9, 0.83, 0.8), glow)
		var shade := Vector3(0.8, 0.73, 0.82).lerp(Vector3(0.66, 0.58, 0.72), glow)
		RenderingServer.global_shader_parameter_set("cel_lit", lit)
		RenderingServer.global_shader_parameter_set("cel_shadow", shade)
		sun.rotation_degrees = Vector3(-60, -24, 0)
		_weather_globals(false)
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
	var top := Color(a[3]).lerp(Color(b[3]), t)
	# Under cloud the light goes flat and grey: the sun barely shows, and the shade lifts
	# towards the lit colour. Storms darken it more, and lightning flashes it white.
	var dull := (smoothstep(0.4, 1.0, Weather.clouds) * 0.85 + Weather.storm * 0.15) * (1.0 - glow * 0.5)
	var l := lit.get_luminance()
	var grey := Color(l, l, l * 1.04)
	lit = lit.lerp(shade.lerp(grey, 0.7), dull)
	shade = shade.lerp(Color(l * 0.86, l * 0.87, l * 0.9), dull * 0.9)
	lit = lit.darkened(Weather.storm * 0.16)
	shade = shade.darkened(Weather.storm * 0.14)
	if _flash > 0.0:
		lit = lit.lerp(Color(0.97, 0.97, 1.0), _flash * 0.6)
		shade = shade.lerp(Color(0.86, 0.88, 0.98), _flash * 0.6)
	horizon = horizon.lerp(grey.lerp(horizon, 0.3), dull)
	top = top.lerp(grey.darkened(0.15), dull)
	RenderingServer.global_shader_parameter_set("cel_lit", Vector3(lit.r, lit.g, lit.b))
	RenderingServer.global_shader_parameter_set("cel_shadow", Vector3(shade.r, shade.g, shade.b))
	# Morning mist: a pale haze that thickens with distance.
	env.fog_enabled = Weather.mist > 0.02
	env.fog_light_color = horizon.lerp(Color(0.95, 0.95, 0.97), 0.5)
	env.fog_density = Weather.mist * 0.5
	env.fog_depth_begin = 16.0
	env.fog_depth_end = 60.0
	_weather_globals(true)
	sky_material.set_shader_parameter("top_colour", top)
	sky_material.set_shader_parameter("horizon_colour", horizon)
	var cloud := Color(1.0, 0.99, 0.97).lerp(grey.darkened(0.08), dull).lerp(top.lightened(0.15), glow * 0.7)
	sky_material.set_shader_parameter("cloud_colour", cloud)
	sky_material.set_shader_parameter("rainbow", Weather.rainbow)
	sky_material.set_shader_parameter("meteors", Weather.meteors * glow)
	sky_material.set_shader_parameter("sun_colour", lit)

	# The sun (or moon) arcs from east to west, always from the south so shadows fall
	# away from the camera and never get too long.
	var daytime := hour >= 5.0 and hour < 20.0
	var progress := inverse_lerp(5.0, 20.0, hour) if daytime else fposmod(hour - 20.0, 24.0) / 9.0
	var azimuth := lerpf(-65.0, 65.0, progress)
	var elevation := lerpf(30.0, 62.0, sin(progress * PI))
	sun.rotation_degrees = Vector3(-elevation, azimuth, 0)
	sky_material.set_shader_parameter("sun_direction", sun.global_transform.basis.z)


## The weather's shader globals; indoors there's no weather (and no snow on the furniture).
func _weather_globals(outside: bool) -> void:
	var w := 1.0 if outside else 0.0
	RenderingServer.global_shader_parameter_set("cloud_cover", Weather.clouds * w)
	RenderingServer.global_shader_parameter_set("wetness", Weather.wetness * w)
	RenderingServer.global_shader_parameter_set("rain", Weather.rain * w)
	RenderingServer.global_shader_parameter_set("snow_cover", Weather.snow_cover * w)
	RenderingServer.global_shader_parameter_set("foliage", Vector4(Weather.autumn, Weather.blossom, 0.0, 0.0))
	var tint := Vector3.ONE
	match Weather.season:
		"summer":
			tint = Vector3(1.02, 1.02, 0.94)
		"autumn":
			tint = Vector3.ONE.lerp(Vector3(1.08, 0.97, 0.78), Weather.autumn)
		"winter":
			tint = Vector3(0.93, 0.96, 1.0)
	RenderingServer.global_shader_parameter_set("grass_tint", tint)
	if outside:
		RenderingServer.global_shader_parameter_set("wind_strength", Weather.wind)
