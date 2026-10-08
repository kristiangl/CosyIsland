class_name CameraRig
extends Node3D
## Fixed-angle follow camera, looking north over the player like a diorama.
## Also feeds the focus point to the world-curvature shaders.

@export var pitch_degrees := 42.0
@export var distance := 18.0
@export var fov := 30.0

var target: Node3D
var camera: Camera3D
var focus := Vector3.ZERO
## When true the camera frames the whole island from high up (used for screenshots).
var overview := false
var island_size := Vector2(96, 80)
## Indoors: the room's floor in tiles. The camera leans in closer and only drifts a
## little with the player so the room stays framed.
var room := Rect2()
## While talking, the camera leans in on the player and this character.
var talk_with: Node3D
var _zoom := 1.0
## Looking up at the sky (held "look_up" outdoors), 0 to 1.
var _look := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = fov
	camera.near = 0.3
	camera.far = 600.0
	add_child(camera)
	camera.make_current()
	add_outline_pass(camera)
	if target:
		focus = target.global_position


func _process(delta: float) -> void:
	if overview:
		_frame_island()
		return
	if target:
		focus = focus.lerp(_goal(), 1.0 - exp(-delta * 6.0))
	var indoors := room.has_area()
	_zoom = lerpf(_zoom, 0.7 if talk_with else 1.0, 1.0 - exp(-delta * 4.0))
	var pitch := deg_to_rad(52.0 if indoors else pitch_degrees)
	# Bigger rooms need the camera further back to fit in.
	var indoor_distance := 13.5 * maxf(1.0, maxf(room.size.x / 6.5, room.size.y / 6.0))
	var wants := 0.0
	if not indoors and Game.mode == Game.Mode.PLAY:
		wants = 1.0 if Game.args.has("look") else Input.get_action_strength("look_up")
	_look = move_toward(_look, wants, delta * 2.5)
	var tilt := smoothstep(0.0, 1.0, _look)
	camera.position = focus + Vector3(0, sin(pitch), cos(pitch)) * (indoor_distance if indoors else distance) * _zoom
	# Looking up: the camera drops behind the player's shoulder and tips up at the sky.
	camera.position = camera.position.lerp(focus + Vector3(0, 1.4, 6.0), tilt)
	camera.look_at(focus.lerp(focus + Vector3(0, 9.0, -24.0), tilt))
	RenderingServer.global_shader_parameter_set("curve_origin", focus)


func _goal() -> Vector3:
	var goal := target.global_position + Vector3(0, 0.6, 0)
	if talk_with:
		goal = (goal + talk_with.global_position + Vector3(0, 0.6, 0)) * 0.5
	if room.has_area():
		var centre := room.get_center()
		goal.x = lerpf(centre.x, goal.x, 0.3)
		goal.z = lerpf(centre.y, goal.z, 0.25)
	return goal


## Jumps straight to the player, e.g. after going through a door.
func snap() -> void:
	if target:
		focus = _goal()


## Adds the full-screen ink outline pass (see shaders/outline_post.gdshader) to a camera.
static func add_outline_pass(camera: Camera3D) -> void:
	var quad := MeshInstance3D.new()
	quad.name = "OutlinePass"
	var mesh := QuadMesh.new()
	quad.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/outline_post.gdshader")
	quad.material_override = mat
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(quad)


func _frame_island() -> void:
	var centre := Vector3(island_size.x * 0.5, 0, island_size.y * 0.52)
	camera.fov = 40.0
	camera.position = centre + Vector3(0, 95, 62)
	camera.look_at(centre)
	RenderingServer.global_shader_parameter_set("curve_origin", centre)
	RenderingServer.global_shader_parameter_set("curve_amount", 0.0)
