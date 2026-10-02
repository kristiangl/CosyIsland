class_name CharacterCreator
extends Control
## Make your villager (at a new game) or change their look later (the wardrobe).
## Left: a turning 3D preview. Right: a scrolling list of options; up/down picks a row,
## left/right changes it. Works with a controller, keyboard or mouse.

signal finished(look: Dictionary, player_name: String, island_name: String)

const ROWS := [
	["Skin", "skin"], ["Hairstyle", "hair"], ["Hair colour", "hair_color"],
	["Eyes", "eyes"], ["Eye colour", "eye_color"], ["Eyebrows", "brows"],
	["Mouth", "mouth"], ["Cheeks", "cheeks"],
	["Top", "top"], ["Top colour", "top_color"], ["Pattern", "top_pattern"],
	["Pattern colour", "top_color2"], ["Bottoms", "bottom"], ["Bottoms colour", "bottom_color"],
	["Shoes", "shoes"], ["Shoe colour", "shoe_color"], ["Hat", "hat"], ["Hat colour", "hat_color"],
	["Glasses", "glasses"],
]
const NAMES := ["Kit", "Robin", "Sam", "Juniper", "Ash", "Wren", "Mika", "Sunny", "Pip", "Rowan"]

var look: Dictionary
var _preview: CharacterModel
var _rows: Array[OptionRow] = []
var _name_edit: LineEdit
var _island_edit: LineEdit
var _title: Label
var _first_focus: Control
var _naming := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.98, 0.95, 0.88, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 640)
	centre.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	panel.add_child(columns)

	columns.add_child(_build_preview())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	right.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	_name_edit = _text_row(list, "Your name")
	_island_edit = _text_row(list, "Island name")
	for row in ROWS:
		var r := OptionRow.new(row[0], row[1], self)
		list.add_child(r)
		_rows.append(r)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	list.add_child(buttons)
	var shuffle := Button.new()
	shuffle.text = "Surprise me"
	shuffle.pressed.connect(_randomise)
	buttons.add_child(shuffle)
	var done := Button.new()
	done.text = "All done!"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(_done)
	buttons.add_child(done)
	var hint := Label.new()
	hint.text = "Up/down to choose   Left/right to change"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	right.add_child(hint)


func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(420, 600)
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
	sun.rotation_degrees = Vector3(-40, 30, 0)
	viewport.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	var eye := Vector3(0, 1.0, 4.4)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.78, 0) - eye), eye)
	viewport.add_child(cam)
	CameraRig.add_outline_pass(cam)
	_preview = CharacterModel.new()
	_preview.curved = false
	viewport.add_child(_preview)
	return container


func _text_row(list: VBoxContainer, label_text: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.max_length = 14
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_stylebox_override("normal", UIStyle.panel(UIStyle.CREAM_DARK, 14))
	edit.add_theme_stylebox_override("focus", UIStyle.panel(UIStyle.ACCENT, 14))
	edit.add_theme_color_override("font_color", UIStyle.BROWN)
	row.add_child(edit)
	list.add_child(row)
	return edit


## Opens the creator. With naming off it's the wardrobe (no name fields).
func open(current: Dictionary, naming: bool, player_name: String = "", island_name: String = "") -> void:
	look = Appearance.sanitise(current)
	_naming = naming
	_name_edit.get_parent().visible = naming
	_island_edit.get_parent().visible = naming
	_name_edit.text = player_name if player_name != "" else NAMES[randi() % NAMES.size()]
	_island_edit.text = island_name if island_name != "" else "Driftwood"
	_title.text = "Let's make you!" if naming else "Wardrobe"
	_refresh()
	visible = true
	Game.mode = Game.Mode.MENU
	(_name_edit if naming else _rows[0]).grab_focus()


func changed() -> void:
	_refresh()


func _refresh() -> void:
	_preview.set_look(look)
	for r in _rows:
		r.queue_redraw()


func _process(delta: float) -> void:
	if visible and _preview:
		_preview.rotation.y = sin(Time.get_ticks_msec() / 1600.0) * 0.6
		_preview.animate(delta, 0.0)


func _randomise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	look = Appearance.random(rng)
	_refresh()


func _done() -> void:
	visible = false
	Game.mode = Game.Mode.PLAY
	var player_name := _name_edit.text.strip_edges()
	var island_name := _island_edit.text.strip_edges()
	finished.emit(look.duplicate(), player_name if player_name != "" else "Kit", island_name if island_name != "" else "Driftwood")


## One "Label   < value >" line. Left/right (or clicking the arrows) changes the value.
class OptionRow:
	extends Button
	var label_text: String
	var key: String
	var creator: CharacterCreator

	func _init(text_label: String, look_key: String, owner_creator: CharacterCreator) -> void:
		label_text = text_label
		key = look_key
		creator = owner_creator
		custom_minimum_size = Vector2(560, 42)
		focus_mode = Control.FOCUS_ALL

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			_step(-1)
			accept_event()
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
			_step(1)
			accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_step(-1 if event.position.x < size.x * 0.62 else 1)
			accept_event()

	func _step(direction: int) -> void:
		Appearance.step(creator.look, key, direction)
		creator.changed()

	func _draw() -> void:
		var font := get_theme_default_font()
		var y := size.y * 0.5 + 7
		draw_string(font, Vector2(18, y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.BROWN)
		var value := Appearance.display_name(creator.look, key)
		var opt := Appearance.option(creator.look, key)
		var x := size.x * 0.5
		draw_string(font, Vector2(x - 30, y), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.BROWN_LIGHT)
		if opt.has("color"):
			draw_circle(Vector2(x + 2, size.y * 0.5), 11, Color(opt["color"]).darkened(0.2))
			draw_circle(Vector2(x + 2, size.y * 0.5), 9, Color(opt["color"]))
			x += 22
		draw_string(font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5 - 60, 20, UIStyle.BROWN)
		draw_string(font, Vector2(size.x - 30, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.BROWN_LIGHT)
