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
	["landscape", "Landscaping", "landscape", "cfe6c0"],
	["options", "Options", "gear", "c9d8f2"],
	["save", "Save", "save", "d9cfee"],
	["sos", "SOS", "sos", "fbe3d6"],
	["quit", "Save & quit", "door", "f2c6a8"],
]
const PHONE_SIZE := Vector2(360, 590)

var _body: PanelContainer
var _time: Label
var _date: Label
var _island: Label
var _hemisphere_button: Button
var _sounds_button: Button
var _weather_button: Button
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
## Only there once Poppy's sold you the permit.
var _landscape_app: Button
var _landscape_buttons: Array[Button] = []
var _put_away: Button
var _tool_info: Label


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
	_island.add_theme_font_size_override("font_size", 15)
	_island.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_island.custom_minimum_size = Vector2(290, 0)
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
	_pages["landscape"] = _build_landscape()
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
		if app[0] == "landscape":
			_landscape_app = b
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
	_sounds_button = Button.new()
	_sounds_button.pressed.connect(func():
		Sfx.muted = not Sfx.muted
		_update_options())
	box.add_child(_sounds_button)
	_hemisphere_button = Button.new()
	_hemisphere_button.pressed.connect(func():
		Story.flags["hemisphere"] = "north" if Weather.hemisphere() == "south" else "south"
		Weather.update(GameClock.hour_float())
		_update_options())
	box.add_child(_hemisphere_button)
	for entry: Array in [["Time travel", "time"], ["Controls", "controls"]]:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(_show_page.bind(entry[1]))
		box.add_child(b)
	var title := Button.new()
	title.text = "Back to the title screen"
	title.pressed.connect(_open_app.bind("title"))
	box.add_child(title)
	_update_options()
	return box


func _update_options() -> void:
	_music_button.text = "Music: %s" % ("off" if Music.muted else "on")
	_sounds_button.text = "Sounds: %s" % ("off" if Sfx.muted else "on")
	_hemisphere_button.text = "Seasons: %s hemisphere" % Weather.hemisphere().capitalize()


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
	_weather_button = Button.new()
	_weather_button.text = "Weather: as forecast"
	_weather_button.pressed.connect(func():
		Weather.force = Weather.FORCES[(Weather.FORCES.find(Weather.force) + 1) % Weather.FORCES.size()]
		Weather.update(GameClock.hour_float())
		_weather_button.text = "Weather: %s" % (Weather.force if Weather.force != "" else "as forecast"))
	box.add_child(_weather_button)
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
	Prompts.bind_label(_controls_list, "{use}  use, talk, sit, sleep\n{pickup}  pick up\n{run}  run\n{pockets}  pockets\n{tools}  switch tool\n{rotate}  turn while placing\n{look_up}  (hold) look up at the sky\n{map}  map\n{pause}  phone")
	box.add_child(_controls_list)
	return box


## The landscaping tools: pick one to take it out, or put them away. The tools for
## shaping the land and its trees sit in a row of tiles, the paths in a row of swatches
## under them, and a line at the bottom says what the one picked out does.
func _build_landscape() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_page_title("Landscaping"))
	box.add_child(_small_heading("The land and its trees"))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	box.add_child(tools)
	box.add_child(_small_heading("Paths"))
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 6)
	box.add_child(swatches)
	for what: String in Player.LANDSCAPE_TOOLS:
		var b := ToolTile.new(what)
		b.pressed.connect(_open_app.bind("landscape:" + what))
		b.focus_entered.connect(_describe_tool.bind(what))
		(swatches if what.begins_with("path:") else tools).add_child(b)
		_landscape_buttons.append(b)
	_tool_info = Label.new()
	_tool_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_info.custom_minimum_size = Vector2(0, 66)
	_tool_info.add_theme_font_size_override("font_size", 15)
	_tool_info.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	box.add_child(_tool_info)
	_put_away = Button.new()
	_put_away.text = "Put the tools away"
	_put_away.pressed.connect(_open_app.bind("landscape:"))
	box.add_child(_put_away)
	return box


## What each landscaping tool does, for the line under the tools.
const TOOL_INFO := {
	"cliff": "Build the ground up a level, or dig a cliff back down.",
	"water": "Dig out a river or a pond, or fill water back in.",
	"slope": "Lay a slope up a cliff, or take one away.",
	"trees": "Chop trees down (three chops leave a stump), and dig up stumps, bushes and young trees.",
	"move": "Dig up a tree, bush, rock or stump and set it down somewhere else.",
}


func _describe_tool(what: String) -> void:
	var name := Player.landscape_name(what)
	var info: String = TOOL_INFO.get(what, "")
	if what.begins_with("path:"):
		info = "Lay it on grassy ground, or again to lift it." \
			+ (" On a slope it makes stairs." if what.get_slice(":", 1) in World.STAIR_KINDS else "")
	_tool_info.text = "%s: %s" % [name, info]


func _small_heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	return l


func _page_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	return l


func open() -> void:
	Game.mode = Game.Mode.MENU
	# The season and today's weather, where the island's name was.
	_island.text = "%s: %s" % [Weather.season.capitalize(), Weather.forecast()]
	_acorns.text = UIStyle.acorns(Inventory.currency)
	if _acorn_icon.texture == null:
		_acorn_icon.texture = Icons.get_icon("acorn_pouch")
	visible = true
	Sfx.play("ui_open")
	_landscape_app.visible = Story.flags.get("landscaping", false)
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
	Sfx.play("ui_close")
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
		"landscape":
			var holding: String = Game.player.landscaping if Game.player else ""
			_put_away.visible = holding != ""
			for b in _landscape_buttons:
				(b as ToolTile).held = (b as ToolTile).what == holding
				b.queue_redraw()
			var at := maxi(0, Player.LANDSCAPE_TOOLS.find(holding))
			_landscape_buttons[at].grab_focus.call_deferred()
			_describe_tool(Player.LANDSCAPE_TOOLS[at])


func _open_app(app: String) -> void:
	match app:
		"options", "landscape":
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


## A landscaping tool on the phone: a tile with a little picture of what it does and its
## name (a path is a round swatch of its paving, named in the line below). The tool in
## hand has a green dot.
class ToolTile:
	extends Button
	const TINTS := {"cliff": "ecd9bb", "water": "cde6f2", "slope": "dcecc9", "trees": "cfe6c0", "move": "e6dfd6"}
	var what: String
	var held := false

	func _init(tool: String) -> void:
		what = tool
		var path := what.begins_with("path:")
		custom_minimum_size = Vector2(40, 40) if path else Vector2(56, 70)
		focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(grab_focus)

	func _draw() -> void:
		var path := what.begins_with("path:")
		var tile := Rect2(Vector2.ZERO, Vector2(size.x, size.x)) if not path else Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(tile.size.x * 0.5) if path else 16)
		sb.bg_color = IslandMap.PATH_COLOURS.get(what.get_slice(":", 1), Color.WHITE) if path else Color(TINTS.get(what, "eeeeee"))
		if has_focus():
			sb.border_color = UIStyle.ACCENT
			sb.set_border_width_all(3)
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				sb.set_expand_margin(side, 2)
		draw_style_box(sb, tile)
		var c := tile.get_center()
		if path:
			_paving(c, tile.size.x * 0.5)
		else:
			_picture(c)
			draw_string(get_theme_default_font(), Vector2(0, size.y - 3), Player.landscape_name(what), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UIStyle.BROWN)
		if held:
			var dot := tile.position + Vector2(tile.size.x - 6, 6)
			draw_circle(dot, 6.0, UIStyle.CREAM)
			draw_circle(dot, 4.0, Color("5fae5a"))

	## A few paving stones in a lighter shade of the path.
	func _paving(c: Vector2, r: float) -> void:
		var base: Color = IslandMap.PATH_COLOURS.get(what.get_slice(":", 1), Color.WHITE)
		var light := base.lightened(0.25)
		var dark := base.darkened(0.18)
		for spot: Vector2 in [Vector2(-0.3, -0.28), Vector2(0.28, -0.22), Vector2(-0.22, 0.3), Vector2(0.32, 0.32)]:
			var p := c + spot * r
			draw_rect(Rect2(p - Vector2(5, 4), Vector2(10, 8)), dark)
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 8)), light)

	## A little picture of the tool's job.
	func _picture(c: Vector2) -> void:
		var grass := Color("8cc76a")
		var earth := Color("b98a63")
		var earth_dark := Color("9a6f4c")
		match what:
			"cliff":
				# Two levels of ground, one stepped up on the other.
				draw_colored_polygon(PackedVector2Array([c + Vector2(-17, 13), c + Vector2(17, 13), c + Vector2(17, 1),
					c + Vector2(3, 1), c + Vector2(3, -10), c + Vector2(-17, -10)]), earth)
				draw_rect(Rect2(c + Vector2(-17, -13), Vector2(20, 5)), grass)
				draw_rect(Rect2(c + Vector2(3, -2), Vector2(14, 5)), grass)
				draw_line(c + Vector2(-17, 4), c + Vector2(3, 4), earth_dark, 1.5)
			"water":
				draw_circle(c, 15.0, Color("6fb6d8"))
				for y: float in [-4.0, 4.0]:
					var pts := PackedVector2Array()
					for i in 9:
						var x := -9.0 + i * 2.25
						pts.append(c + Vector2(x, y + sin(i * 1.4) * 1.6))
					draw_polyline(pts, Color("eef8fc"), 2.0, true)
			"slope":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-17, 13), c + Vector2(17, 13), c + Vector2(17, -11)]), earth)
				draw_line(c + Vector2(-17, 11), c + Vector2(17, -13), grass, 5.0)
			"trees":
				draw_rect(Rect2(c + Vector2(-3, 1), Vector2(6, 13)), Color("a87d62"))
				draw_circle(c + Vector2(0, -5), 11.0, Color("6faa5c"))
				draw_circle(c + Vector2(-3, -8), 5.0, Color("8cc76a"))
			"move":
				# A rock with an arrow hopping over it.
				var rock := PackedVector2Array()
				for i in 12:
					var a := TAU * i / 12.0
					rock.append(c + Vector2(cos(a) * 11.0, 7 + sin(a) * 7.0))
				draw_colored_polygon(rock, Color("a9a59e"))
				draw_circle(c + Vector2(-3, 4), 3.0, Color("c4c0b9"))
				draw_arc(c + Vector2(0, -3), 12.0, PI * 1.1, PI * 1.9, 10, UIStyle.BROWN, 2.5, true)
				var tip := c + Vector2(cos(PI * 1.9), sin(PI * 1.9)) * 12.0 + Vector2(0, -3)
				draw_colored_polygon(PackedVector2Array([tip + Vector2(-1, -5), tip + Vector2(5, 2), tip + Vector2(-4, 3)]), UIStyle.BROWN)
