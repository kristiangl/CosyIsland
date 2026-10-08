class_name StorageMenu
extends PanelContainer
## Home storage: your pockets on the left, what's put away on the right. A on a pocket
## slot puts it away, A on a stored stack takes it out. L/R (Q/E) show one kind of thing
## at a time. B closes.

const GROUPS := [
	["all", "All"],
	["furniture", "Furniture"],
	["clothing", "Clothes"],
	["nature", "Nature"],
	["tool", "Tools"],
	["other", "Other"],
]
const POCKET_COLUMNS := 6
const STORE_COLUMNS := 9

var _group := 0
var _tabs: Array[Button] = []
var _count: Label
var _name: Label
var _desc: Label
var _pocket_grid: GridContainer
var _pocket_buttons: Array[Pockets.SlotButton] = []
var _store_grid: GridContainer
var _store_buttons: Array[StoredButton] = []
## Indices into Inventory.storage for the stacks shown in the current group.
var _shown: Array[int] = []
## Where focus was, to put it back after a move: ["pocket" or "store", index].
var _focus := ["pocket", 0]


func _ready() -> void:
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	var title := Label.new()
	title.text = "Storage"
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	for i in GROUPS.size():
		var b := Button.new()
		b.text = GROUPS[i][1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_set_group.bind(i))
		header.add_child(b)
		_tabs.append(b)
	_count = Label.new()
	_count.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_count.custom_minimum_size = Vector2(110, 0)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_count)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	box.add_child(columns)
	var left := VBoxContainer.new()
	columns.add_child(left)
	left.add_child(_heading("Pockets"))
	_pocket_grid = GridContainer.new()
	_pocket_grid.columns = POCKET_COLUMNS
	_pocket_grid.add_theme_constant_override("h_separation", 6)
	_pocket_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_pocket_grid)
	var right := VBoxContainer.new()
	columns.add_child(right)
	right.add_child(_heading("Put away at home"))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(STORE_COLUMNS * 64 + 14, 64 * 6)
	right.add_child(scroll)
	_store_grid = GridContainer.new()
	_store_grid.columns = STORE_COLUMNS
	_store_grid.add_theme_constant_override("h_separation", 6)
	_store_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_store_grid)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(info)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 22)
	info.add_child(_name)
	_desc = Label.new()
	_desc.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_desc.add_theme_font_size_override("font_size", 16)
	_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desc.custom_minimum_size = Vector2(420, 0)
	info.add_child(_desc)
	var hint := Label.new()
	Prompts.bind_label(hint, "{ui_accept} put away / take out   {tab_prev} {tab_next} sort   {ui_cancel} close")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	footer.add_child(hint)
	Events.inventory_changed.connect(func(): if visible: _refresh())
	Events.pockets_resized.connect(_add_pocket_slots)
	Icons.icon_ready.connect(func(_id): if visible: _redraw())
	_add_pocket_slots()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	return l


func _add_pocket_slots() -> void:
	for i in range(_pocket_buttons.size(), Inventory.slots.size()):
		var b := Pockets.SlotButton.new()
		b.index = i
		b.focus_entered.connect(_on_focus.bind("pocket", i))
		b.pressed.connect(_put_away.bind(i))
		_pocket_grid.add_child(b)
		_pocket_buttons.append(b)


func open() -> void:
	Game.mode = Game.Mode.MENU
	visible = true
	Sfx.play("door_open", -6.0, 1.3)
	_focus = ["pocket", 0]
	_set_group(_group)
	reset_size()
	position = (get_parent_area_size() - size) * 0.5


func close() -> void:
	visible = false
	Game.mode = Game.Mode.PLAY


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		close()
	elif event.is_action_pressed("tab_prev"):
		_set_group(posmod(_group - 1, GROUPS.size()))
	elif event.is_action_pressed("tab_next"):
		_set_group(posmod(_group + 1, GROUPS.size()))
	else:
		return
	get_viewport().set_input_as_handled()


func _set_group(i: int) -> void:
	_group = i
	for t in _tabs.size():
		_tabs[t].button_pressed = t == i
	if _focus[0] == "store":
		_focus = ["store", 0]
	_refresh()


## Which group of the tabs an item belongs to.
static func group_of(id: String) -> String:
	match ItemDB.get_item(id).get("category", ""):
		"furniture", "interior":
			return "furniture"
		"clothing":
			return "clothing"
		"fruit", "flower", "flower_plant", "fish", "bug", "material":
			return "nature"
		"tool":
			return "tool"
	return "other"


func _refresh() -> void:
	_shown.clear()
	var group: String = GROUPS[_group][0]
	for i in Inventory.storage.size():
		if group == "all" or group_of(Inventory.storage[i]["id"]) == group:
			_shown.append(i)
	while _store_buttons.size() < maxi(_shown.size(), STORE_COLUMNS):
		var b := StoredButton.new()
		var n := _store_buttons.size()
		b.focus_entered.connect(_on_focus.bind("store", n))
		b.pressed.connect(_take_out.bind(n))
		_store_grid.add_child(b)
		_store_buttons.append(b)
	for n in _store_buttons.size():
		var b := _store_buttons[n]
		b.stored = _shown[n] if n < _shown.size() else -1
		b.visible = n < maxi(_shown.size(), 1)
	_count.text = "%d / %d" % [Inventory.storage.size(), Inventory.STORAGE_SIZE]
	_redraw()
	var target: Button
	if _focus[0] == "store" and not _shown.is_empty():
		target = _store_buttons[clampi(_focus[1], 0, _shown.size() - 1)]
	else:
		target = _pocket_buttons[clampi(_focus[1] if _focus[0] == "pocket" else 0, 0, _pocket_buttons.size() - 1)]
	target.grab_focus()
	_on_focus(_focus[0], _focus[1])


func _redraw() -> void:
	for b in _pocket_buttons:
		b.queue_redraw()
	for b in _store_buttons:
		b.queue_redraw()


func _on_focus(side: String, i: int) -> void:
	_focus = [side, i]
	var slot: Dictionary = {}
	if side == "pocket":
		slot = Inventory.slots[i] if i < Inventory.slots.size() else {}
	elif i < _shown.size():
		slot = Inventory.storage[_shown[i]]
	if slot.is_empty():
		_name.text = ""
		_desc.text = ""
		return
	_name.text = ItemDB.display_name(slot["id"]) + ("  x%d" % slot["count"] if slot["count"] > 1 else "")
	_desc.text = ItemDB.get_item(slot["id"]).get("desc", "")


func _put_away(i: int) -> void:
	if Inventory.slots[i].is_empty():
		return
	if not Inventory.store(i):
		Events.toast.emit("Your storage is full!")
	else:
		Sfx.play("cloth", -4.0)


func _take_out(n: int) -> void:
	if n >= _shown.size():
		return
	if not Inventory.retrieve(_shown[n]):
		Events.toast.emit("Your pockets are full!")
	else:
		Sfx.play("pop", -2.0)


class StoredButton:
	extends Button
	## Index into Inventory.storage, or -1 for an empty space.
	var stored := -1

	func _init() -> void:
		custom_minimum_size = Vector2(58, 58)
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var c := size * 0.5
		if stored < 0 or stored >= Inventory.storage.size():
			draw_circle(c, 6, UIStyle.BROWN_LIGHT * Color(1, 1, 1, 0.35))
			return
		var slot := Inventory.storage[stored]
		var tex := Icons.get_icon(slot["id"])
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(25, 25), Vector2(50, 50)), false)
		else:
			draw_circle(c, 20, ItemDB.color_of(slot["id"]))
		if slot["count"] > 1:
			draw_string(get_theme_default_font(), Vector2(size.x - 24, size.y - 6), str(slot["count"]), HORIZONTAL_ALIGNMENT_RIGHT, 22, 16, UIStyle.BROWN)
