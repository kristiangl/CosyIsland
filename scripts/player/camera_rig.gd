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
	var pitch := deg_to_rad(52.0 if indoors else pitch_degrees)
	camera.position = focus + Vector3(0, sin(pitch), cos(pitch)) * (13.5 if indoors else distance)
	camera.look_at(focus)
	RenderingServer.global_shader_parameter_set("curve_origin", focus)


func _goal() -> Vector3:
	var goal := target.global_position + Vector3(0, 0.6, 0)
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
