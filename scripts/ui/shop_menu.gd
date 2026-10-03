class_name ShopMenu
extends PanelContainer
## Lucy's shop counter. Two tabs (switch with L/R, Q/E or by clicking): Buy shows
## today's stock, Sell shows what's in your pockets. A buys or sells one, Y sells the
## whole stack, B leaves. Emits closed so Lucy can say goodbye.

signal closed

var _mode := "buy"
var _tabs: Array[Button] = []
var _list: VBoxContainer
var _icon: TextureRect
var _name: Label
var _desc: Label
var _price: Label
var _acorns: Label
var _hint: Label
var _rows: Array[ShopRow] = []
var _selected := -1


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(980, 560)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(460, 0)
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	left.add_child(title_row)
	var title := Label.new()
	title.text = "Lucy's Odds & Ends"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	for mode: String in ["buy", "sell"]:
		var b := Button.new()
		b.text = mode.capitalize()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.pressed.connect(_set_mode.bind(mode))
		title_row.add_child(b)
		_tabs.append(b)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	_acorns = Label.new()
	_acorns.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_acorns.add_theme_font_size_override("font_size", 22)
	right.add_child(_acorns)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(170, 170)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(_icon)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 28)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_name)
	_desc = Label.new()
	_desc.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(440, 0)
	right.add_child(_desc)
	_price = Label.new()
	_price.add_theme_font_size_override("font_size", 24)
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_price)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_hint)

	Icons.icon_ready.connect(func(_id): if visible: _show(_selected))
	Events.currency_changed.connect(func(_c): if visible: _show(_selected))


func open(mode: String) -> void:
	visible = true
	Game.mode = Game.Mode.MENU
	_set_mode(mode)


func close() -> void:
	visible = false
	Game.mode = Game.Mode.PLAY
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		close()
	elif event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next"):
		_set_mode("sell" if _mode == "buy" else "buy")
	elif event.is_action_pressed("pickup") and _mode == "sell" and _selected >= 0:
		_sell(_selected, 999)
	else:
		return
	get_viewport().set_input_as_handled()


func _set_mode(mode: String) -> void:
	_mode = mode
	_tabs[0].button_pressed = mode == "buy"
	_tabs[1].button_pressed = mode == "sell"
	var hint := "{ui_accept} buy   {tab_prev} {tab_next} sell   {ui_cancel} leave" if mode == "buy" \
		else "{ui_accept} sell one   {pickup} sell all   {tab_prev} {tab_next} buy   {ui_cancel} leave"
	_hint.text = Prompts.fill(hint)
	_rebuild(0)


func _day() -> int:
	return GameClock.day_key()


func _rebuild(focus_index: int) -> void:
	# Rows go after this frame: one of them may be mid-press.
	for r in _rows:
		_list.remove_child(r)
		r.queue_free()
	_rows.clear()
	if _mode == "buy":
		var seed_value: int = Game.island.data.seed_value if Game.island else 0
		for id in Shop.stock(seed_value, _day()):
			_add_row(ShopRow.new(id, -1, self))
	else:
		for i in Inventory.slots.size():
			var slot := Inventory.slots[i]
			if not slot.is_empty() and Shop.can_sell(slot["id"]):
				_add_row(ShopRow.new(slot["id"], i, self))
	if _rows.is_empty():
		_selected = -1
		_icon.texture = null
		_name.text = "Nothing to sell" if _mode == "sell" else "Sold out!"
		_desc.text = "Bring Lucy something she can sell on." if _mode == "sell" else "Come back tomorrow."
		_price.text = ""
		_update_acorns()
		return
	var row := _rows[clampi(focus_index, 0, _rows.size() - 1)]
	row.grab_focus.call_deferred()
	_show(_rows.find(row))


func _add_row(row: ShopRow) -> void:
	var index := _rows.size()
	row.focus_entered.connect(func(): _show(index))
	row.pressed.connect(func(): _activate(index))
	_list.add_child(row)
	_rows.append(row)


func _show(index: int) -> void:
	_update_acorns()
	if index < 0 or index >= _rows.size():
		return
	_selected = index
	var row := _rows[index]
	_icon.texture = Icons.get_icon(row.item_id)
	_name.text = ItemDB.display_name(row.item_id)
	_desc.text = ItemDB.get_item(row.item_id).get("desc", "")
	if _mode == "buy":
		_price.text = "Sold out" if Shop.is_sold_out(row.item_id, _day()) else "%d %s" % [Shop.buy_price(row.item_id), Game.CURRENCY_NAME]
	else:
		_price.text = "Lucy pays %d each" % Shop.sell_price(row.item_id)
	for r in _rows:
		r.queue_redraw()


func _update_acorns() -> void:
	_acorns.text = "%d %s" % [Inventory.currency, Game.CURRENCY_NAME]


func _activate(index: int) -> void:
	if _mode == "buy":
		var id := _rows[index].item_id
		var problem := Shop.buy(id, _day())
		if problem != "":
			Events.toast.emit(problem)
		else:
			Events.toast.emit("You bought %s!" % ItemDB.display_name(id).to_lower())
		_show(index)
	else:
		_sell(index, 1)


func _sell(index: int, count: int) -> void:
	var row := _rows[index]
	var earned := Shop.sell(row.slot, count)
	if earned > 0:
		Events.toast.emit("Lucy gave you %d %s." % [earned, Game.CURRENCY_NAME.to_lower()])
	# The slot may be empty now, so list the pockets again and stay about here.
	_rebuild(index if not Inventory.slots[row.slot].is_empty() else index)


func is_buying() -> bool:
	return _mode == "buy"


## One line: icon, name (and count when selling), price.
class ShopRow:
	extends Button
	var item_id: String
	var slot: int
	var menu: ShopMenu

	func _init(id: String, pocket_slot: int, owner_menu: ShopMenu) -> void:
		item_id = id
		slot = pocket_slot
		menu = owner_menu
		custom_minimum_size = Vector2(440, 54)
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var tex := Icons.get_icon(item_id)
		if tex:
			draw_texture_rect(tex, Rect2(8, 3, 48, 48), false)
		var font := get_theme_default_font()
		var day := GameClock.day_key()
		var label := ItemDB.display_name(item_id)
		var price := Shop.buy_price(item_id) if menu.is_buying() else Shop.sell_price(item_id)
		var dim := menu.is_buying() and (Shop.is_sold_out(item_id, day) or Inventory.currency < price)
		if slot >= 0:
			label += "  x%d" % int(Inventory.slots[slot].get("count", 1))
		draw_string(font, Vector2(66, 34), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 190, 20, UIStyle.BROWN_LIGHT if dim else UIStyle.BROWN)
		var price_text := "Sold out" if menu.is_buying() and Shop.is_sold_out(item_id, day) else str(price)
		draw_string(font, Vector2(size.x - 120, 34), price_text, HORIZONTAL_ALIGNMENT_RIGHT, 106, 20, UIStyle.BROWN_LIGHT if dim else UIStyle.BROWN)
