class_name Pockets
extends PanelContainer
## The pockets screen: a grid of item slots. A uses the selected item (equip a tool,
## place a kit, eat fruit), Y drops it, X or B closes.

signal place_requested(slot: int)

const COLUMNS := 10

var _grid: GridContainer
var _name_label: Label
var _desc_label: Label
var _currency_label: Label
var _buttons: Array[SlotButton] = []
var _selected := 0


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Pockets"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_currency_label = Label.new()
	header.add_child(_currency_label)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_name_label)
	_desc_label = Label.new()
	_desc_label.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(700, 52)
	box.add_child(_desc_label)
	var hint := Label.new()
	hint.text = "A use   Y drop   X close"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	box.add_child(hint)
	for i in Inventory.slots.size():
		var b := SlotButton.new()
		b.index = i
		b.focus_entered.connect(_on_focus.bind(i))
		b.pressed.connect(_use_slot.bind(i))
		_grid.add_child(b)
		_buttons.append(b)
	Events.inventory_changed.connect(_refresh)
	Events.equipped_changed.connect(func(_id): _refresh())
	Events.currency_changed.connect(func(_c): _refresh())


func open() -> void:
	Game.mode = Game.Mode.MENU
	visible = true
	_refresh()
	reset_size()
	position = (get_parent_area_size() - size) * 0.5
	_buttons[clampi(_selected, 0, _buttons.size() - 1)].grab_focus()


func close() -> void:
	visible = false
	if Game.mode == Game.Mode.MENU:
		Game.mode = Game.Mode.PLAY


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pickup"):
		_drop_slot(_selected)
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_currency_label.text = "%d %s" % [Inventory.currency, Game.CURRENCY_NAME]
	for b in _buttons:
		b.queue_redraw()
	_on_focus(_selected)


func _on_focus(i: int) -> void:
	_selected = i
	var slot := Inventory.slots[i]
	if slot.is_empty():
		_name_label.text = ""
		_desc_label.text = ""
		return
	var def := ItemDB.get_item(slot["id"])
	_name_label.text = def.get("name", slot["id"])
	var extra := ""
	if slot.has("durability"):
		extra = "  (Durability %d)" % slot["durability"]
	if i == Inventory.equipped_slot:
		extra += "  - holding"
	_desc_label.text = def.get("desc", "") + extra


func _use_slot(i: int) -> void:
	var slot := Inventory.slots[i]
	if slot.is_empty():
		return
	var id: String = slot["id"]
	var def := ItemDB.get_item(id)
	if ItemDB.is_tool(id):
		Inventory.equip(-1 if Inventory.equipped_slot == i else i)
	elif not ItemDB.placeable(id).is_empty():
		close()
		place_requested.emit(i)
	elif def.get("category", "") == "fruit":
		Inventory.remove_from_slot(i)
		Events.toast.emit("Mmm, delicious!")
	else:
		_drop_slot(i)


func _drop_slot(i: int) -> void:
	var slot := Inventory.slots[i]
	if slot.is_empty() or Game.world == null:
		return
	if Game.world.drop_from_pockets(Game.player.tile(), Game.player.target_tile(), slot["id"], slot["count"]):
		Inventory.remove_from_slot(i, slot["count"])
	else:
		Events.toast.emit("There's no room to drop that here.")


class SlotButton:
	extends Button
	var index := 0

	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var slot := Inventory.slots[index]
		var c := size * 0.5
		if index == Inventory.equipped_slot:
			draw_circle(c, 28, UIStyle.GREEN)
		if slot.is_empty():
			draw_circle(c, 6, UIStyle.BROWN_LIGHT * Color(1, 1, 1, 0.35))
			return
		var col := ItemDB.color_of(slot["id"])
		draw_circle(c + Vector2(0, 2), 22, col.darkened(0.25))
		draw_circle(c, 22, col)
		draw_circle(c + Vector2(-7, -8), 6, col.lightened(0.35))
		var font := get_theme_default_font()
		var initials := ItemDB.display_name(slot["id"]).substr(0, 2)
		draw_string(font, c + Vector2(-12, 7), initials, HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color.WHITE)
		if slot["count"] > 1:
			draw_string(font, Vector2(size.x - 24, size.y - 6), str(slot["count"]), HORIZONTAL_ALIGNMENT_RIGHT, 22, 16, UIStyle.BROWN)
