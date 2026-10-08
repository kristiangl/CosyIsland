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
var _toast_label: Label
var _toast_queue: Array[String] = []
var _toast_timer := 0.0
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
	Prompts.bind_label(_landscape_hints, "{use} landscape   {tools} change tool   {pause} phone (to put away)")
	_landscape_hints.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_landscape_hints.add_theme_font_size_override("font_size", 16)
	_landscape_hints.visible = false
	hint_panel.add_child(_landscape_hints)

	# Toast, bottom centre.
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_panel.position.y -= 60
	_toast_panel.modulate.a = 0.0
	root.add_child(_toast_panel)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)

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


# --- Toasts --------------------------------------------------------------------------

func _on_toast(text: String) -> void:
	if _toast_queue.size() < 4:
		_toast_queue.append(text)


func _update_toast(delta: float) -> void:
	_tour_border.visible = Game.tour != null
	_toast_timer -= delta
	if _toast_timer > 0.3:
		_toast_panel.modulate.a = minf(1.0, _toast_panel.modulate.a + delta * 6.0)
	else:
		_toast_panel.modulate.a = maxf(0.0, _toast_panel.modulate.a - delta * 4.0)
		if _toast_timer <= 0.0 and not _toast_queue.is_empty():
			_toast_label.text = _toast_queue.pop_front()
			_toast_timer = 2.2


func _on_landscaping(what: String) -> void:
	_play_hints.visible = what == ""
	_landscape_hints.visible = what != ""
	if what == "":
		_on_equipped(Inventory.equipped_id())
	else:
		_tool_label.text = "Landscaping: " + Player.landscape_name(what)


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
