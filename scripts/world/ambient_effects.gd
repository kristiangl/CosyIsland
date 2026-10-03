class_name AmbientEffects
extends Node3D
## Effects in the air around the camera: fireflies on summer nights, petals drifting on
## the breeze by day, and dust motes in the light indoors. Follows the camera's focus.

var camera: CameraRig
var _fireflies: CPUParticles3D
var _petals: CPUParticles3D
var _motes: CPUParticles3D
var _check := 0.0
## Indoors, motes float about instead.
var indoors := false:
	set(value):
		indoors = value
		_check = 0.0


func _ready() -> void:
	_fireflies = _add("fireflies")
	_petals = _add("petals")
	_motes = _add("motes")


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
	_switch(_fireflies, not indoors and (hour >= 19.5 or hour < 4.5))
	_switch(_petals, not indoors and hour >= 7.0 and hour < 17.5)
	_switch(_motes, indoors)


func _switch(e: CPUParticles3D, on: bool) -> void:
	if e.emitting != on:
		e.emitting = on
	if on:
		e.visible = true
	elif e.visible and not e.emitting:
		# Let the last ones fade out before hiding.
		get_tree().create_timer(e.lifetime).timeout.connect(func(): if not e.emitting: e.visible = false)
