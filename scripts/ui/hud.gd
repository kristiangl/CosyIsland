class_name Hud
extends CanvasLayer
## On-screen interface: clock, equipped tool, toasts, the pockets and the pause menu.

signal place_requested(slot: int)
signal save_requested
signal quit_requested
signal title_requested
signal sos_requested
signal wardrobe_requested

var _time_label: Label
var _date_label: Label
var _tool_label: Label
var _play_hints: Label
var _landscape_hints: Label
var _tool_panel: PanelContainer
var _hint_panel: PanelContainer
var _toast_panel: PanelContainer
var _tour_border: ColorRect
var _landscape_border: ColorRect
## What A does with each landscaping tool, for the hints.
const LANDSCAPE_USES := {"cliff": "raise or lower", "water": "dig or fill in water", "slope": "lay or take away a slope",
	"trees": "chop down or dig up", "move": "dig up and move", "path": "lay or lift the path"}
var _toast_label: Label
## Journal stamps earned slide down at the top of the screen, clear of conversations.
var _stamp_panel: PanelContainer
var _stamp_text: Label
var _stamp_count: Label
var _stamp_queue: Array[Dictionary] = []
var _stamp_timer := 0.0
const STAMP_TIME := 3.2
## The sunrise shown when the island moves on to another day.
var sunrise: SunriseSplash
## A game with a neighbour: how it's going, top middle (`show_game`), and big words in the
## middle of the screen for the start of a race (`big_note`).
var _game_panel: PanelContainer
var _game_label: Label
var _big_note: Label
## Notes waiting their turn: {"text", "count"}. The same note again joins its twin.
var _toast_queue: Array[Dictionary] = []
var _toast_timer := 0.0
## The note showing now, and how many times it's been said.
var _toast_text := ""
var _toast_count := 0
var _pockets: Pockets
var creator: CharacterCreator
var crafting: CraftingMenu
var journal: JournalMenu
var shop: ShopMenu
var storage: StorageMenu
var phone: IslandPhone
var _minimap: PanelContainer
var _map: PanelContainer
var _map_title: Label
var _fade: ColorRect
var dialogue: DialogueBox
## Indoors there's no minimap.
var indoors := false:
	set(value):
		indoors = value
		_update_minimap()


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	# A sandy border round the screen while off on a tour island.
	_tour_border = ColorRect.new()
	_tour_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tour_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_mat := ShaderMaterial.new()
	border_mat.shader = load("res://shaders/tour_border.gdshader")
	_tour_border.material = border_mat
	_tour_border.visible = false
	root.add_child(_tour_border)
	_tour_border.resized.connect(func(): border_mat.set_shader_parameter("screen", _tour_border.size))
	# And a grassy one while a landscaping tool is out.
	_landscape_border = ColorRect.new()
	_landscape_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_landscape_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/landscape_border.gdshader")
	_landscape_border.material = grass_mat
	_landscape_border.visible = false
	root.add_child(_landscape_border)
	_landscape_border.resized.connect(func(): grass_mat.set_shader_parameter("screen", _landscape_border.size))

	# Clock, top left.
	var clock := PanelContainer.new()
	clock.position = Vector2(24, 20)
	root.add_child(clock)
	var clock_box := VBoxContainer.new()
	clock_box.add_theme_constant_override("separation", -4)
	clock.add_child(clock_box)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 34)
	clock_box.add_child(_time_label)
	_date_label = Label.new()
	_date_label.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	clock_box.add_child(_date_label)

	# Equipped tool, bottom left.
	var tool_panel := PanelContainer.new()
	_tool_panel = tool_panel
	tool_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tool_panel.position = Vector2(24, -80)
	tool_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(tool_panel)
	_tool_label = Label.new()
	tool_panel.add_child(_tool_label)

	# Control hints, bottom right.
	var hint_panel := PanelContainer.new()
	_hint_panel = hint_panel
	var hint_style := UIStyle.panel(Color(UIStyle.CREAM, 0.8), 16)
	hint_style.content_margin_top = 6
	hint_style.content_margin_bottom = 6
	hint_style.shadow_size = 0
	hint_panel.add_theme_stylebox_override("panel", hint_style)
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.position += Vector2(-20, -16)
	root.add_child(hint_panel)
	var hints := Label.new()
	Prompts.bind_label(hints, "{use} use   {pickup} pick up   {pockets} pockets   {tools} tools   {map} map   {pause} phone")
	hints.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	hints.add_theme_font_size_override("font_size", 16)
	hint_panel.add_child(hints)
	_play_hints = hints
	_landscape_hints = Label.new()
	Prompts.method_changed.connect(_fill_landscape_hints)
	Events.mode_changed.connect(func(_m): if Game.player and Game.player.landscaping != "": _fill_landscape_hints())
	_landscape_hints.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_landscape_hints.add_theme_font_size_override("font_size", 16)
	_landscape_hints.visible = false
	hint_panel.add_child(_landscape_hints)

	# Toast, bottom centre.
	# (placed each frame: bottom middle, or the top over a conversation)
	_toast_panel = PanelContainer.new()
	_toast_panel.modulate.a = 0.0
	root.add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	_build_stamp_banner(root)

	_game_panel = PanelContainer.new()
	_game_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_game_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_panel.position.y += 24
	_game_panel.visible = false
	root.add_child(_game_panel)
	_game_label = Label.new()
	_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_label.add_theme_font_size_override("font_size", 22)
	_game_panel.add_child(_game_label)
	_big_note = Label.new()
	_big_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_big_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_big_note.grow_vertical = Control.GROW_DIRECTION_BOTH
	_big_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_note.add_theme_font_override("font", UIStyle.font(700))
	_big_note.add_theme_font_size_override("font_size", 140)
	_big_note.add_theme_color_override("font_color", Color("e0794a"))
	_big_note.add_theme_color_override("font_outline_color", UIStyle.CREAM)
	_big_note.add_theme_constant_override("outline_size", 28)
	_big_note.modulate.a = 0.0
	_big_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_big_note)

	_build_maps(root)

	_pockets = Pockets.new()
	_pockets.place_requested.connect(func(slot): place_requested.emit(slot))
	root.add_child(_pockets)

	phone = IslandPhone.new()
	root.add_child(phone)
	phone.app_chosen.connect(_on_phone_app)

	creator = CharacterCreator.new()
	root.add_child(creator)
	Game.creator = creator

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)
	crafting = CraftingMenu.new()
	centre.add_child(crafting)
	shop = ShopMenu.new()
	centre.add_child(shop)
	journal = JournalMenu.new()
	centre.add_child(journal)
	Game.shop = shop
	storage = StorageMenu.new()
	root.add_child(storage)
	Events.storage_opened.connect(storage.open)
	var paint := HousePaint.new()
	centre.add_child(paint)
	Game.house_paint = paint
	Events.workbench_opened.connect(crafting.open)

	dialogue = DialogueBox.new()
	root.add_child(dialogue)
	Game.dialogue = dialogue

	# Fades to and from black when going through doors.
	_fade = ColorRect.new()
	_fade.color = Color("2e2530")
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	root.add_child(_fade)

	# Toasts go in front of everything, menus included (so a sale shows over the shop).
	root.move_child(_toast_panel, -1)
	root.move_child(_stamp_panel, -1)
	# And the sunrise in front of those.
	sunrise = SunriseSplash.new()
	root.add_child(sunrise)
	Journal.completed.connect(_on_stamped)
	Events.toast.connect(_on_toast)
	Events.equipped_changed.connect(_on_equipped)
	Events.landscaping_changed.connect(_on_landscaping)
	_on_equipped(Inventory.equipped_id())


func _process(delta: float) -> void:
	if Game.outdoors():
		# Collects the map painting as soon as it's ready, even with the minimap hidden.
		IslandMap.terrain_texture(Game.outdoors().data)
	# Conversations get the bottom of the screen to themselves.
	_tool_panel.visible = not dialogue.visible
	_hint_panel.visible = not dialogue.visible
	_time_label.text = GameClock.time_string()
	_date_label.text = GameClock.date_string()
	_update_toast(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pockets"):
		if Game.mode == Game.Mode.PLAY:
			_pockets.open()
			get_viewport().set_input_as_handled()
		elif _pockets.visible:
			_pockets.close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		if Game.mode == Game.Mode.PLAY:
			open_map()
			get_viewport().set_input_as_handled()
		elif _map.visible:
			_close_map()
			get_viewport().set_input_as_handled()
	elif _map.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_close_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if Game.mode == Game.Mode.PLAY:
			phone.open()
			get_viewport().set_input_as_handled()


# --- Maps --------------------------------------------------------------------------

func _build_maps(root: Control) -> void:
	# Corner minimap, top right. Shown while walking about and placing things.
	_minimap = PanelContainer.new()
	var frame := UIStyle.panel(UIStyle.CREAM, 18)
	frame.set_content_margin_all(7)
	_minimap.add_theme_stylebox_override("panel", frame)
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_minimap.position += Vector2(-24, 20)
	root.add_child(_minimap)
	var mini := IslandMap.new()
	mini.custom_minimum_size = Vector2(204, 170)
	mini.margin = 1.5
	_minimap.add_child(mini)
	Events.mode_changed.connect(func(_mode: int): _update_minimap())

	# Full map, opened with the map button.
	_map = PanelContainer.new()
	_map.visible = false
	root.add_child(_map)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_map.add_child(box)
	_map_title = Label.new()
	_map_title.add_theme_font_size_override("font_size", 28)
	_map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_map_title)
	var big := IslandMap.new()
	big.detailed = true
	big.custom_minimum_size = Vector2(576, 480)
	box.add_child(big)
	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	hint.add_theme_font_size_override("font_size", 16)
	Prompts.bind_label(hint, "{map} close")
	box.add_child(hint)


func _update_minimap() -> void:
	if _minimap:
		_minimap.visible = Game.mode != Game.Mode.MENU and not indoors


func open_map() -> void:
	Game.mode = Game.Mode.MENU
	Sfx.play("page")
	_map_title.text = "A little island" if Game.tour else ("%s Island" % Game.island_name if Game.island_name != "" else "Island Map")
	_map.visible = true
	_map.reset_size()
	_map.position = (_map.get_parent_area_size() - _map.size) * 0.5


func _close_map() -> void:
	Sfx.play("page", -3.0, 1.2)
	_map.visible = false
	Game.mode = Game.Mode.PLAY


func fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.25)
	await tw.finished


func fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.3)
	await tw.finished


## Out of the dark of a fade straight into the sunrise, and back to the game after it.
func sunrise_from_dark(title: String, date: String) -> void:
	sunrise.play_from_dark(title, date)
	_fade.modulate.a = 0.0
	await sunrise.done


# --- Games with neighbours ------------------------------------------------------------

## Shows how a game's going ("Hide and seek   Found 1 of 3   1:42").
func show_game(text: String) -> void:
	if _game_label.text != text:
		_game_label.text = text
	_game_panel.visible = true


func hide_game() -> void:
	_game_panel.visible = false


## Big words in the middle of the screen for a moment ("3", "2", "1", "Go!").
func big_note(text: String) -> void:
	_big_note.text = text
	_big_note.pivot_offset = _big_note.size * 0.5
	_big_note.scale = Vector2.ONE * 1.4
	_big_note.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_big_note, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(_big_note, "modulate:a", 0.0, 0.2)


# --- Toasts --------------------------------------------------------------------------

## Shows a note. The same note again while it's up (buying fence after fence, say) counts
## up on the one showing ("x3") instead of queueing another; one already waiting counts
## up there. Notes waiting behind others show for less time.
func _on_toast(text: String) -> void:
	if _toast_timer > 0.0 and text == _toast_text:
		_toast_count += 1
		_toast_label.text = toast_line(text, _toast_count)
		_toast_panel.reset_size()
		_toast_timer = maxf(_toast_timer, TOAST_AGAIN)
		_toast_panel.pivot_offset = _toast_panel.size * 0.5
		_toast_panel.scale = Vector2.ONE * 1.06
		create_tween().tween_property(_toast_panel, "scale", Vector2.ONE, 0.15)
		return
	for waiting: Dictionary in _toast_queue:
		if waiting["text"] == text:
			waiting["count"] = int(waiting["count"]) + 1
			return
	if _toast_queue.size() < 4:
		_toast_queue.append({"text": text, "count": 1})


const TOAST_TIME := 2.2
const TOAST_HURRIED := 1.3
const TOAST_AGAIN := 1.8


## A note with how many times it's been said, if more than once.
static func toast_line(text: String, count: int) -> String:
	return text if count <= 1 else "%s  x%d" % [text, count]


func _update_toast(delta: float) -> void:
	_tour_border.visible = Game.tour != null
	# Notes wait for the sunrise to finish.
	if sunrise.playing:
		_toast_panel.modulate.a = 0.0
		return
	_update_stamps(delta)
	# Over a conversation they go at the top of the screen (under any stamp showing).
	var screen := get_viewport().get_visible_rect().size
	var y := screen.y - 60.0 - _toast_panel.size.y
	if dialogue.visible:
		y = 20.0 + (_stamp_panel.position.y + _stamp_panel.size.y if _stamp_panel.visible else 0.0)
	_toast_panel.position = Vector2((screen.x - _toast_panel.size.x) * 0.5, y)
	_toast_timer -= delta
	if _toast_timer > 0.3:
		_toast_panel.modulate.a = minf(1.0, _toast_panel.modulate.a + delta * 6.0)
	else:
		_toast_panel.modulate.a = maxf(0.0, _toast_panel.modulate.a - delta * 4.0)
		if _toast_timer <= 0.0:
			_toast_text = ""
			if not _toast_queue.is_empty():
				var next: Dictionary = _toast_queue.pop_front()
				_toast_text = next["text"]
				_toast_count = next["count"]
				_toast_label.text = toast_line(_toast_text, _toast_count)
				_toast_panel.reset_size()
				_toast_timer = TOAST_TIME if _toast_queue.is_empty() else TOAST_HURRIED


# --- Journal stamps ------------------------------------------------------------------

func _build_stamp_banner(root: Control) -> void:
	_stamp_panel = PanelContainer.new()
	var style := UIStyle.panel(UIStyle.CREAM, 24)
	style.border_color = UIStyle.ACCENT
	style.set_border_width_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_stamp_panel.add_theme_stylebox_override("panel", style)
	_stamp_panel.visible = false
	_stamp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stamp_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_stamp_panel.add_child(row)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(54, 54)
	badge.draw.connect(func(): stamp_badge(badge, Vector2(27, 27), 25.0))
	row.add_child(badge)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -4)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var head := Label.new()
	head.text = "Journal"
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	words.add_child(head)
	_stamp_text = Label.new()
	_stamp_text.add_theme_font_size_override("font_size", 22)
	words.add_child(_stamp_text)
	_stamp_count = Label.new()
	_stamp_count.add_theme_font_override("font", UIStyle.font(700))
	_stamp_count.add_theme_font_size_override("font_size", 26)
	_stamp_count.add_theme_color_override("font_color", Color("e0794a"))
	row.add_child(_stamp_count)


## A round postmark-style stamp with a star in it (the journal's stamps).
static func stamp_badge(c: CanvasItem, at: Vector2, r: float) -> void:
	var edge: PackedVector2Array = []
	for i in 48:
		var a := i * TAU / 48.0
		edge.append(at + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.9))
	c.draw_colored_polygon(edge, Color("e0794a"))
	c.draw_circle(at, r * 0.74, UIStyle.CREAM)
	c.draw_arc(at, r * 0.66, 0.0, TAU, 32, Color("e0794a"), 2.0, true)
	var star: PackedVector2Array = []
	for i in 10:
		star.append(at + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * (r * 0.5 if i % 2 == 0 else r * 0.22))
	c.draw_colored_polygon(star, UIStyle.ACCENT)


func _on_stamped(text: String, stamps: int) -> void:
	if _stamp_queue.size() < 6:
		_stamp_queue.append({"text": text, "stamps": stamps})


func _update_stamps(delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	var top := 18.0
	if _game_panel.visible:
		top = _game_panel.position.y + _game_panel.size.y + 10.0
	if _stamp_timer <= 0.0:
		if _stamp_queue.is_empty():
			_stamp_panel.visible = false
			return
		var next: Dictionary = _stamp_queue.pop_front()
		_stamp_text.text = next["text"]
		_stamp_count.text = "+%d" % int(next["stamps"])
		_stamp_panel.reset_size()
		_stamp_panel.visible = true
		_stamp_timer = STAMP_TIME
	_stamp_timer -= delta
	# Slides down from above, waits, and slides back up.
	var shown := STAMP_TIME - _stamp_timer
	var out := minf(clampf(shown / 0.3, 0.0, 1.0), clampf(_stamp_timer / 0.3, 0.0, 1.0))
	var eased := 1.0 - pow(1.0 - out, 3.0)
	var h := _stamp_panel.size.y
	_stamp_panel.position = Vector2((screen.x - _stamp_panel.size.x) * 0.5, lerpf(-h - 10.0, top, eased))


func _on_landscaping(what: String) -> void:
	_play_hints.visible = what == ""
	_landscape_hints.visible = what != ""
	_landscape_border.visible = what != ""
	if what == "":
		_on_equipped(Inventory.equipped_id())
	else:
		_tool_label.text = "Landscaping: " + Player.landscape_name(what)
		_fill_landscape_hints()


func _fill_landscape_hints() -> void:
	var what: String = Game.player.landscaping if Game.player else ""
	if Game.mode == Game.Mode.PLACING:
		# Carrying something with the Move tool.
		_landscape_hints.text = Prompts.fill("{use} set it down here   {cancel} put it in your pockets")
		return
	var use: String = LANDSCAPE_USES.get(what.get_slice(":", 0), "landscape")
	_landscape_hints.text = Prompts.fill("{use} %s   {tools} change tool   {pause} phone (to put away)" % use)


func _on_equipped(item_id: String) -> void:
	if Game.player and Game.player.landscaping != "":
		return
	_tool_label.text = "Empty hands" if item_id == "" else "Holding: " + ItemDB.display_name(item_id)


# --- Phone ---------------------------------------------------------------------------

func _on_phone_app(app: String) -> void:
	match app:
		"map":
			open_map()
		"wardrobe":
			wardrobe_requested.emit()
		"journal":
			journal.open()
		"recipes":
			crafting.open_book()
		"save":
			save_requested.emit()
			Events.toast.emit("Game saved.")
		"quit":
			quit_requested.emit()
		"title":
			title_requested.emit()
		"sos":
			sos_requested.emit()
		_ when app.begins_with("landscape:"):
			var what := app.get_slice(":", 1) + (":" + app.get_slice(":", 2) if app.get_slice_count(":") > 2 else "")
			if what != "" and (Game.world != Game.island or Game.world == null):
				Events.toast.emit("Landscaping is for outdoors on your own island.")
			elif Game.player:
				Game.player.set_landscaping(what)
