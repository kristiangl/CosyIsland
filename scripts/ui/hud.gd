class_name Hud
extends CanvasLayer
## On-screen interface: clock, equipped tool, toasts, the pockets and the pause menu.

signal place_requested(slot: int)
signal save_requested
signal quit_requested
signal wardrobe_requested

var _time_label: Label
var _date_label: Label
var _tool_label: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_queue: Array[String] = []
var _toast_timer := 0.0
var _pockets: Pockets
var creator: CharacterCreator
var crafting: CraftingMenu
var _pause: PanelContainer
var _pause_title: Label
var _pause_time: Label
var _pause_first: Button


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

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
	tool_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tool_panel.position = Vector2(24, -80)
	tool_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(tool_panel)
	_tool_label = Label.new()
	tool_panel.add_child(_tool_label)

	# Control hints, bottom right.
	var hints := Label.new()
	hints.text = "A use   Y pick up   X pockets   D-pad tools   + menu"
	hints.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hints.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	hints.add_theme_font_size_override("font_size", 16)
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints.position += Vector2(-24, -16)
	root.add_child(hints)

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

	_pockets = Pockets.new()
	_pockets.place_requested.connect(func(slot): place_requested.emit(slot))
	root.add_child(_pockets)

	_build_pause(root)

	creator = CharacterCreator.new()
	root.add_child(creator)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(centre)
	crafting = CraftingMenu.new()
	centre.add_child(crafting)
	Events.workbench_opened.connect(crafting.open)

	Events.toast.connect(_on_toast)
	Events.equipped_changed.connect(_on_equipped)
	_on_equipped(Inventory.equipped_id())


func _process(delta: float) -> void:
	_time_label.text = GameClock.time_string()
	_date_label.text = GameClock.date_string()
	_update_toast(delta)
	if _pause.visible:
		_pause_time.text = "%s, %s%s" % [GameClock.date_string(), GameClock.time_string(),
			"" if GameClock.offset_seconds == 0 else "  (time travelled)"]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pockets"):
		if Game.mode == Game.Mode.PLAY:
			_pockets.open()
			get_viewport().set_input_as_handled()
		elif _pockets.visible:
			_pockets.close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if Game.mode == Game.Mode.PLAY:
			_open_pause()
			get_viewport().set_input_as_handled()
		elif _pause.visible:
			_close_pause()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _pause.visible:
		_close_pause()
		get_viewport().set_input_as_handled()


# --- Toasts --------------------------------------------------------------------------

func _on_toast(text: String) -> void:
	if _toast_queue.size() < 4:
		_toast_queue.append(text)


func _update_toast(delta: float) -> void:
	_toast_timer -= delta
	if _toast_timer > 0.3:
		_toast_panel.modulate.a = minf(1.0, _toast_panel.modulate.a + delta * 6.0)
	else:
		_toast_panel.modulate.a = maxf(0.0, _toast_panel.modulate.a - delta * 4.0)
		if _toast_timer <= 0.0 and not _toast_queue.is_empty():
			_toast_label.text = _toast_queue.pop_front()
			_toast_timer = 2.2


func _on_equipped(item_id: String) -> void:
	_tool_label.text = "Empty hands" if item_id == "" else "Holding: " + ItemDB.display_name(item_id)


# --- Pause menu with time travel -----------------------------------------------------

func _build_pause(root: Control) -> void:
	_pause = PanelContainer.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.visible = false
	root.add_child(_pause)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_pause.add_child(box)
	var title := Label.new()
	_pause_title = title
	title.text = "Island Phone"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_pause_time = Label.new()
	_pause_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_pause_time)

	var travel_title := Label.new()
	travel_title.text = "Time travel"
	travel_title.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	box.add_child(travel_title)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	box.add_child(row1)
	for entry in [["-1 day", -86400], ["-1 hour", -3600], ["+1 hour", 3600], ["+1 day", 86400]]:
		var b := Button.new()
		b.text = entry[0]
		var secs: int = entry[1]
		b.pressed.connect(func(): GameClock.travel(secs))
		row1.add_child(b)
		if _pause_first == null:
			_pause_first = b
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	box.add_child(row2)
	var back := Button.new()
	back.text = "Back to real time"
	back.pressed.connect(GameClock.reset_travel)
	row2.add_child(back)
	var speed := Button.new()
	speed.text = "Clock speed: x1"
	speed.pressed.connect(func():
		GameClock.time_scale = 60.0 if GameClock.time_scale == 1.0 else (600.0 if GameClock.time_scale == 60.0 else 1.0)
		speed.text = "Clock speed: x%d" % int(GameClock.time_scale))
	row2.add_child(speed)

	for entry in [["Resume", _close_pause], ["Wardrobe", func(): _close_pause(); wardrobe_requested.emit()], ["Save", func(): save_requested.emit(); Events.toast.emit("Game saved.")],
			["Save and quit", func(): quit_requested.emit()]]:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(entry[1])
		box.add_child(b)


func _open_pause() -> void:
	Game.mode = Game.Mode.MENU
	_pause_title.text = "%s Island" % Game.island_name if Game.island_name != "" else "Island Phone"
	_pause.visible = true
	_pause.reset_size()
	_pause.position = (_pause.get_parent_area_size() - _pause.size) * 0.5
	_pause_first.grab_focus()


func _close_pause() -> void:
	_pause.visible = false
	Game.mode = Game.Mode.PLAY
