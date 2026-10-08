class_name AmbientEffects
extends Node3D
## Effects in the air around the camera: rain and snow (Weather), fireflies on summer
## nights, petals drifting on the breeze in spring and summer, falling leaves in autumn,
## and dust motes in the light indoors. Follows the camera's focus. (Rainbows, clouds
## and shooting stars are in the sky: see shaders/sky.gdshader.)

var camera: CameraRig
var _fireflies: CPUParticles3D
var _petals: CPUParticles3D
var _leaves: CPUParticles3D
var _motes: CPUParticles3D
var _rain: CPUParticles3D
var _snow: CPUParticles3D
## How heavy the rain and snow emitters are set for (they restart when it changes).
var _rain_level := 0
var _snow_level := 0
var _check := 0.0
## Indoors, motes float about instead.
var indoors := false:
	set(value):
		indoors = value
		_check = 0.0


func _ready() -> void:
	_fireflies = _add("fireflies")
	_petals = _add("petals")
	_leaves = _add("falling_leaves")
	_motes = _add("motes")
	_rain = _add("rain")
	_rain.position = Vector3(0, 9.0, -2.0)
	_snow = _add("snowfall")
	_snow.position = Vector3(0, 7.0, -2.0)


func _add(kind: String) -> CPUParticles3D:
	var e := Effects.emitter(kind)
	e.emitting = false
	e.visible = false
	add_child(e)
	return e


func _process(delta: float) -> void:
	if camera:
		global_position = camera.focus + Vector3(0, 0.3, 0)
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var hour := GameClock.hour_float()
	var outside := not indoors
	var dry := Weather.rain < 0.05 and Weather.snow < 0.05
	_switch(_fireflies, outside and dry and Weather.season in ["spring", "summer"] and (hour >= 19.5 or hour < 4.5))
	_switch(_petals, outside and dry and (Weather.season == "summer" or Weather.blossom > 0.2) and hour >= 7.0 and hour < 17.5)
	_switch(_leaves, outside and Weather.autumn > 0.2 and Weather.snow < 0.05)
	_switch(_motes, indoors)
	_rain_level = _set_level(_rain, int(round(Weather.rain * 4.0)) if outside else 0, _rain_level, 340)
	_snow_level = _set_level(_snow, int(round(Weather.snow * 4.0)) if outside else 0, _snow_level, 170)
	# Storms blow the rain sideways.
	_rain.direction = Vector3(0.1 + Weather.storm * 0.35, -1.0, 0.04)


## Rain and snow come in four strengths; changing the amount restarts the emitter, so
## only do it when the strength changes.
func _set_level(e: CPUParticles3D, level: int, was: int, most: int) -> int:
	if level != was and level > 0:
		e.amount = maxi(8, most * level / 4)
	_switch(e, level > 0)
	return level


func _switch(e: CPUParticles3D, on: bool) -> void:
	if e.emitting != on:
		e.emitting = on
	if on:
		e.visible = true
	elif e.visible and not e.emitting:
		# Let the last ones fade out before hiding.
		get_tree().create_timer(e.lifetime).timeout.connect(func(): if not e.emitting: e.visible = false)

