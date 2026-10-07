class_name HousePaint
extends PanelContainer
## Choosing the colours of your house: rows of swatches for the roof, the walls and the
## door, and the house swaying gently in a preview as you pick. A picks a colour, B (or
## Cancel) leaves it as it was, Done keeps the new paint. Emits closed with the paint
## ({"wall", "roof", "door"} as hex) or {} if nothing changed.

signal closed(paint: Dictionary)

## The colours on offer for each part, as hex.
const COLOURS := {
	"roof": ["e0857a", "c8564a", "b0603a", "8a5a44", "d8a050", "7ea03a", "4f8a6a", "3a7a9a", "3a5a8a", "7a5a9a", "5a5a66", "f2c14e"],
	"wall": ["fbf0d9", "ffffff", "f6e3c8", "fbe7c6", "f6d8d0", "f2e2ea", "e6e0f2", "dcecf4", "dff0e2", "eef0d0", "d9cfc0", "c9bfb0"],
	"door": ["9fd3c7", "8fc58a", "f2d68a", "f2a65a", "e0656b", "f2b8c8", "b9a6e6", "6a9ac8", "3a5a8a", "b08463", "6b4f3a", "fbf3dc"],
}
const PARTS := [["roof", "Roof"], ["wall", "Walls"], ["door", "Door"]]

var paint: Dictionary = {}
var _start: Dictionary = {}
var _tall := false
var _preview: MeshInstance3D
var _pivot: Node3D
var _camera: Camera3D
var _swatches: Dictionary = {}
var _done: Button
var _time := 0.0


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(980, 540)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	add_child(columns)
	columns.add_child(_build_preview())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	var title := Label.new()
	title.text = "Paint your house"
	title.add_theme_font_size_override("font_size", 30)
	right.add_child(title)
	for part: Array in PARTS:
		var label := Label.new()
		label.text = part[1]
		label.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
		right.add_child(label)
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		right.add_child(grid)
		var row: Array[Button] = []
		for hex: String in COLOURS[part[0]]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(52, 44)
			b.pressed.connect(_pick.bind(part[0], hex))
			grid.add_child(b)
			b.set_meta("hex", hex)
			row.append(b)
		_swatches[part[0]] = row
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): _finish(false))
	buttons.add_child(cancel)
	_done = Button.new()
	_done.text = "Done"
	_done.pressed.connect(func(): _finish(true))
	buttons.add_child(_done)


func _build_preview() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(420, 500)
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("dcefe0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	# Shadows on: the cel lighting maths assumes a shadow-casting sun.
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, 35, 0)
	viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	viewport.add_child(_camera)
	CameraRig.add_outline_pass(_camera)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_preview = MeshInstance3D.new()
	var mat: ShaderMaterial = Models.material().duplicate()
	mat.set_shader_parameter("curved", false)
	mat.set_shader_parameter("fixed_tints", true)
	_preview.material_override = mat
	_pivot.add_child(_preview)
	return container


## Opens on the house's paint now (`paint`, empty for the original colours). `tall`
## shows the big house.
func open(current: Dictionary, tall: bool) -> void:
	_tall = tall
	paint = {
		"wall": current.get("wall", Models.HOUSE_WALL.to_html(false)),
		"roof": current.get("roof", Models.HOUSE_ROOF.to_html(false)),
		"door": current.get("door", Models.HOUSE_DOOR.to_html(false)),
	}
	_start = paint.duplicate()
	var top := 4.0 if tall else 3.0
	_camera.position = Vector3(0, top * 0.62, 7.6 + top * 0.6)
	_camera.look_at(Vector3(0, top * 0.42, 0))
	_time = 0.0
	_refresh()
	visible = true
	Game.mode = Game.Mode.MENU
	(_swatches["roof"][maxi(0, COLOURS["roof"].find(paint["roof"]))] as Button).grab_focus()


## The house sways gently from side to side, always showing its front.
func _process(delta: float) -> void:
	if visible:
		_time += delta
		_pivot.rotation.y = sin(_time * 0.6) * 0.55 - 0.15


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		_finish(false)
		get_viewport().set_input_as_handled()


func _pick(part: String, hex: String) -> void:
	paint[part] = hex
	_refresh()


func _refresh() -> void:
	_preview.mesh = Models.get_mesh("%s:%s:%s:%s" % ["big_house" if _tall else "house", paint["wall"], paint["roof"], paint["door"]])
	for part: String in _swatches:
		for b: Button in _swatches[part]:
			var hex: String = b.get_meta("hex")
			var chosen: bool = paint[part] == hex
			var normal := UIStyle.panel(Color(hex), 12)
			normal.set_border_width_all(4 if chosen else 2)
			normal.border_color = UIStyle.BROWN if chosen else Color(hex).darkened(0.25)
			var focus := normal.duplicate() as StyleBoxFlat
			focus.set_border_width_all(5)
			focus.border_color = UIStyle.ACCENT
			b.add_theme_stylebox_override("normal", normal)
			b.add_theme_stylebox_override("hover", focus)
			b.add_theme_stylebox_override("pressed", normal)
			b.add_theme_stylebox_override("focus", focus)


func _finish(keep: bool) -> void:
	visible = false
	Game.mode = Game.Mode.PLAY
	closed.emit(paint.duplicate() if keep and paint != _start else {})
