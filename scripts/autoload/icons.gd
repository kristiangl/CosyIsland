extends Node
## Item icons rendered from the items' own 3D models, one per frame in the background,
## and cached. UI asks for an icon with get_icon(); it returns null until it's ready and
## icon_ready fires when it is.

signal icon_ready(item_id: String)

const SIZE := 128

var _icons: Dictionary = {}
var _queue: Array[String] = []
var _busy := false
var _viewport: SubViewport
var _mesh: MeshInstance3D
var _camera: Camera3D
var _material: ShaderMaterial
var _enabled := true


func _ready() -> void:
	# Nothing gets drawn in headless runs (tests), so don't try.
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
	sun.rotation_degrees = Vector3(-50, 30, 0)
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 26.0
	_viewport.add_child(_camera)
	_camera.current = true
	_mesh = MeshInstance3D.new()
	_material = Models.material().duplicate()
	_material.set_shader_parameter("fixed_tints", true)
	_material.set_shader_parameter("curved", false)
	_mesh.material_override = _material
	_viewport.add_child(_mesh)


func get_icon(item_id: String) -> Texture2D:
	if _icons.has(item_id):
		return _icons[item_id]
	if _enabled and not _queue.has(item_id):
		_queue.append(item_id)
		if not _busy:
			_render_queue()
	return null


func _render_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var id: String = _queue.pop_front()
		_frame(Models.get_mesh(model_key(id)))
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		# Wait for a frame that has actually drawn the viewport.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		_icons[id] = ImageTexture.create_from_image(image)
		icon_ready.emit(id)
	_busy = false


## Which model shows an item: its placed model, the tool in hand, or its dropped look.
static func model_key(item_id: String) -> String:
	var def := ItemDB.get_item(item_id)
	if def.has("placeable"):
		# A building kit shows the building it'll become.
		if def["placeable"].has("ghost"):
			return ItemDB.placeable(def["placeable"]["ghost"])["model"]
		return def["placeable"]["model"]
	if def.has("build"):
		return "series:" + item_id
	if def.get("category", "") == "clothing":
		return "clothing:" + item_id
	if def.get("category", "") == "tool":
		return "tool:" + item_id
	return "drop:" + item_id


## Points the camera so the mesh fills the icon, seen from the front and a little above.
func _frame(mesh: ArrayMesh) -> void:
	_mesh.mesh = mesh
	Models.dress(_mesh, _material, true)
	var box := mesh.get_aabb()
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.05)
	var dir := Vector3(0.45, 0.65, 1.0).normalized()
	var distance := radius / sin(deg_to_rad(_camera.fov * 0.5)) * 1.02
	var eye := centre + dir * distance
	_camera.transform = Transform3D(Basis.looking_at(centre - eye), eye)
