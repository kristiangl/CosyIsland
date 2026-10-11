class_name CharacterThumbs
extends Node
## Little pictures of character options for the creator: a character dressed in each
## option, rendered one per frame in the background and cached by look. get_thumb()
## returns null until it's ready, then thumb_ready fires.

signal thumb_ready(cache_key: String)

const SIZE := 96
## Camera eye and target for each view, in character space.
const VIEWS := {
	"face": [Vector3(0, 1.08, 1.45), Vector3(0, 1.03, 0)],
	"head": [Vector3(0, 1.25, 2.1), Vector3(0, 1.08, 0)],
	# The whole character, head and hair too (not cut off at the chin).
	"body": [Vector3(0, 0.86, 2.75), Vector3(0, 0.7, 0)],
	"feet": [Vector3(0, 0.45, 1.7), Vector3(0, 0.15, 0)],
}

var _thumbs: Dictionary = {}
var _queue: Array = []
var _busy := false
var _enabled := true
var _viewport: SubViewport
var _camera: Camera3D
var _model: CharacterModel


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-35, 20, 0)
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_camera.current = true
	_model = CharacterModel.new()
	_model.curved = false
	_model.fixed_light = true
	_viewport.add_child(_model)


static func cache_key(look: Dictionary, view: String) -> String:
	return view + JSON.stringify(look)


## The picture of this look from this view, or null while it's being drawn.
func get_thumb(look: Dictionary, view: String) -> Texture2D:
	var key := cache_key(look, view)
	if _thumbs.has(key):
		return _thumbs[key]
	if _enabled and not _queue.any(func(q): return q[0] == key):
		_queue.append([key, look.duplicate(), view])
		if not _busy:
			_render_queue()
	return null


## Drops anything not yet drawn (the creator moved to another tab).
func clear_queue() -> void:
	_queue.clear()


func _render_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		_model.set_look(job[1])
		_model.animate(0.0, 0.0)
		var view: Array = VIEWS[job[2]]
		_camera.transform = Transform3D(Basis.looking_at(view[1] - view[0]), view[0])
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if not is_inside_tree():
			return
		var image := _viewport.get_texture().get_image()
		if image.is_invisible() and job.size() < 4:
			# The first picture of a session can come back empty: draw it again.
			job.append(true)
			_queue.push_front(job)
			continue
		_thumbs[job[0]] = ImageTexture.create_from_image(image)
		thumb_ready.emit(job[0])
	_busy = false
