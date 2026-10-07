class_name IslandPhone
extends Control
## The Island Phone: slides up from the bottom of the screen with a status bar and a
## home screen of apps. Some apps open a page on the phone (options, and from there
## time travel and the controls), others hand over to another screen (map, wardrobe).
## Cancel goes back a page, then puts the phone away.

signal app_chosen(app: String)

const APPS := [
	["journal", "Journal", "journal", "f6e3a1"],
	["map", "Map", "map", "c7e6c1"],
	["wardrobe", "Wardrobe", "wardrobe", "f6c9c0"],
	["recipes", "DIY Recipes", "hammer", "f6d8a8"],
	["options", "Options", "gear", "c9d8f2"],
	["save", "Save", "save", "d9cfee"],
	["sos", "SOS", "sos", "fbe3d6"],
	["title", "Title screen", "back", "cfe6e0"],
	["quit", "Save & quit", "door", "f2c6a8"],
]
const PHONE_SIZE := Vector2(360, 590)

var _body: PanelContainer
var _time: Label
var _date: Label
var _island: Label
var _acorns: Label
var _acorn_icon: TextureRect
var _pages: Dictionary = {}
var _page := "home"
var _speed_button: Button
var _travel_note: Label
var _controls_list: Label
var _first_app: Button
var _first_time_button: Button
var _music_button: Button
var _first_option: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_body = PanelContainer.new()
	var shell := UIStyle.panel(Color("f1d6ae"), 44)
	shell.set_content_margin_all(14)
	shell.shadow_size = 14
	_body.add_theme_stylebox_override("panel", shell)
	_body.custom_minimum_size = PHONE_SIZE
	_body.size = PHONE_SIZE
	add_child(_body)
	var screen := PanelContainer.new()
	var glass := UIStyle.panel(Color("fbf6ea"), 32)
	glass.shadow_size = 0
	glass.set_content_margin_all(16)
	screen.add_theme_stylebox_override("panel", glass)
	_body.add_child(screen)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	screen.add_child(stack)
	# The little speaker slot at the top.
	var slot := Panel.new()
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color("ead7b4")
	slot_style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", slot_style)
	slot.custom_minimum_size = Vector2(56, 7)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(slot)

	# Status bar: the time big, the date and island small.
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", -6)
	stack.add_child(status)
	_time = Label.new()
	_time.add_theme_font_size_override("font_size", 40)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_child(_time)
	_date = Label.new()
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	status.add_child(_date)
	_island = Label.new()
	_island.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_island.add_theme_font_size_override("font_size", 16)
	_island.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	status.add_child(_island)
	var pill := UIStyle.acorn_pill(17)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(pill)
	_acorns = pill.get_meta("label")
	_acorn_icon = pill.get_meta("icon")

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(pages)
	_pages["home"] = _build_home()
	_pages["options"] = _build_options()
	_pages["time"] = _build_time()
	_pages["controls"] = _build_controls()
	for p in _pages.values():
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.add_child(p)

	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	Prompts.bind_label(hint, "{ui_accept} open   {cancel} back")
	stack.add_child(hint)


func _build_home() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	for app: Array in APPS:
		var b := AppButton.new(app[1], app[2], Color(app[3]))
		b.pressed.connect(_open_app.bind(app[0]))
		grid.add_child(b)
		if _first_app == null:
			_first_app = b
	return grid


func _build_options() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_page_title("Options"))
	_music_button = Button.new()
	_music_button.pressed.connect(func():
		Music.muted = not Music.muted
		_update_options())
	box.add_child(_music_button)
	_first_option = _music_button
	for entry: Array in [["Time travel", "time"], ["Controls", "controls"]]:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(_show_page.bind(entry[1]))
		box.add_child(b)
	_update_options()
	return box


func _update_options() -> void:
	_music_button.text = "Music: %s" % ("off" if Music.muted else "on")


func _build_time() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_page_title("Time travel"))
	_travel_note = Label.new()
	_travel_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_travel_note.add_theme_font_size_override("font_size", 15)
	_travel_note.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	box.add_child(_travel_note)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for entry: Array in [["-1 day", -86400], ["+1 day", 86400], ["-1 hour", -3600], ["+1 hour", 3600]]:
		var b := Button.new()
		b.text = entry[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var secs: int = entry[1]
		b.pressed.connect(func(): GameClock.travel(secs))
		grid.add_child(b)
		if _first_time_button == null:
			_first_time_button = b
	var back := Button.new()
	back.text = "Back to real time"
	back.pressed.connect(GameClock.reset_travel)
	box.add_child(back)
	_speed_button = Button.new()
	_speed_button.text = "Clock speed: x1"
	_speed_button.pressed.connect(func():
		GameClock.time_scale = 60.0 if GameClock.time_scale == 1.0 else (600.0 if GameClock.time_scale == 60.0 else 1.0)
		_speed_button.text = "Clock speed: x%d" % int(GameClock.time_scale))
	box.add_child(_speed_button)
	return box


func _build_controls() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_page_title("Controls"))
	_controls_list = Label.new()
	_controls_list.add_theme_font_size_override("font_size", 17)
	Prompts.bind_label(_controls_list, "{use}  use, talk, sit, sleep\n{pickup}  pick up\n{run}  run\n{pockets}  pockets\n{tools}  switch tool\n{rotate}  turn while placing\n{map}  map\n{pause}  phone")
	box.add_child(_controls_list)
	return box


func _page_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	return l


func open() -> void:
	Game.mode = Game.Mode.MENU
	_island.text = "%s Island" % Game.island_name if Game.island_name != "" else "Island Phone"
	_acorns.text = UIStyle.acorns(Inventory.currency)
	if _acorn_icon.texture == null:
		_acorn_icon.texture = Icons.get_icon("acorn_pouch")
	visible = true
	_show_page("home")
	# Slide up from below the screen.
	var area := get_parent_area_size()
	var rest := Vector2((area.x - PHONE_SIZE.x) * 0.5, (area.y - PHONE_SIZE.y) * 0.5)
	_body.position = rest + Vector2(0, area.y)
	var tw := create_tween()
	tw.tween_property(_body, "position", rest, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	Game.mode = Game.Mode.PLAY
	var tw := create_tween()
	tw.tween_property(_body, "position:y", get_parent_area_size().y, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): visible = false)


## Back a page (time travel and controls are in the options), or away if already home.
func back() -> void:
	if _page in ["time", "controls"]:
		_show_page("options")
	elif _page != "home":
		_show_page("home")
	else:
		close()


func _show_page(page: String) -> void:
	_page = page
	for p in _pages:
		_pages[p].visible = p == page
	match page:
		"home":
			_first_app.grab_focus.call_deferred()
		"time":
			_first_time_button.grab_focus.call_deferred()
		"options":
			_first_option.grab_focus.call_deferred()


func _open_app(app: String) -> void:
	match app:
		"options":
			_show_page(app)
		_:
			# Apps that leave the phone.
			visible = false
			Game.mode = Game.Mode.PLAY
			app_chosen.emit(app)


func _process(_delta: float) -> void:
	if not visible:
		return
	_time.text = GameClock.time_string()
	_date.text = GameClock.date_string()
	if _acorn_icon.texture == null:
		_acorn_icon.texture = Icons.get_icon("acorn_pouch")
	if _page == "time":
		_travel_note.text = "For trying things out. In the game proper, a good sleep in bed moves time along." \
			+ ("" if GameClock.offset_seconds == 0 else "\nYou've travelled %+.1f hours." % (GameClock.offset_seconds / 3600.0))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if event.is_action_pressed("pause"):
			close()
		else:
			back()
		get_viewport().set_input_as_handled()


## A rounded app icon with its name underneath.
class AppButton:
	extends Button
	var label_text: String
	var icon_id: String
	var tint: Color

	func _init(text_label: String, icon: String, colour: Color) -> void:
		label_text = text_label
		icon_id = icon
		tint = colour
		custom_minimum_size = Vector2(92, 104)
		flat = true
		focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var tile := Rect2(Vector2((size.x - 70) * 0.5, 4), Vector2(70, 70))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(22)
		sb.bg_color = tint
		if has_focus():
			sb.border_color = UIStyle.ACCENT
			sb.set_border_width_all(4)
			sb.expand_margin_left = 3
			sb.expand_margin_right = 3
			sb.expand_margin_top = 3
			sb.expand_margin_bottom = 3
		draw_style_box(sb, tile)
		UIIcons.draw(self, icon_id, tile.get_center(), 44, UIStyle.BROWN)
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, size.y - 6), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, UIStyle.BROWN)
