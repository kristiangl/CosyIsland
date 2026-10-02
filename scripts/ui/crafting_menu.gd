class_name CraftingMenu
extends PanelContainer
## The DIY workbench: known recipes on the left, the selected one's materials on the
## right. A crafts, B closes.

var _list: VBoxContainer
var _icon: TextureRect
var _name: Label
var _desc: Label
var _materials: VBoxContainer
var _craft_button: Button
var _rows: Array[RecipeRow] = []
var _selected := ""


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(980, 560)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	columns.add_child(left)
	var title := Label.new()
	title.text = "DIY Recipes"
	title.add_theme_font_size_override("font_size", 30)
	left.add_child(title)
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
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(180, 180)
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
	_desc.custom_minimum_size = Vector2(480, 0)
	right.add_child(_desc)
	_materials = VBoxContainer.new()
	_materials.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_materials)
	var hint := Label.new()
	Prompts.bind_label(hint, "{ui_accept} craft   {ui_cancel} close")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(hint)

	Icons.icon_ready.connect(func(_id): _refresh_icons())
	Events.inventory_changed.connect(func(): if visible: _show(_selected))


func open() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	var ids := Recipes.known.duplicate()
	# Craftable things first, then alphabetical.
	ids.sort_custom(func(a, b):
		var ca := Recipes.can_craft(a)
		var cb := Recipes.can_craft(b)
		if ca != cb:
			return ca
		return ItemDB.display_name(a) < ItemDB.display_name(b))
	for id in ids:
		var row := RecipeRow.new(id)
		row.focus_entered.connect(_show.bind(id))
		row.pressed.connect(_craft.bind(id))
		_list.add_child(row)
		_rows.append(row)
	visible = true
	Game.mode = Game.Mode.MENU
	if not _rows.is_empty():
		_rows[0].grab_focus()
		_show(_rows[0].item_id)


func close() -> void:
	visible = false
	Game.mode = Game.Mode.PLAY


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pockets")):
		close()
		get_viewport().set_input_as_handled()


func _show(id: String) -> void:
	_selected = id
	_icon.texture = Icons.get_icon(id)
	var makes := Recipes.makes(id)
	_name.text = ItemDB.display_name(id) + (" x%d" % makes if makes > 1 else "")
	_desc.text = ItemDB.get_item(id).get("desc", "")
	for child in _materials.get_children():
		child.queue_free()
	var mats := Recipes.materials(id)
	for mat in mats:
		var have := Inventory.count_of(mat)
		var need := int(mats[mat])
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = Icons.get_icon(mat)
		line.add_child(icon)
		var label := Label.new()
		label.text = "%s   %d / %d" % [ItemDB.display_name(mat), have, need]
		label.add_theme_color_override("font_color", UIStyle.BROWN if have >= need else Color("d0706a"))
		line.add_child(label)
		_materials.add_child(line)
	for r in _rows:
		r.queue_redraw()


func _craft(id: String) -> void:
	if not Recipes.can_craft(id):
		Events.toast.emit("You need more materials for that.")
		return
	if Recipes.craft(id):
		Events.toast.emit("You made %s!" % ItemDB.display_name(id).to_lower())
		_show(id)
	else:
		Events.toast.emit("Your pockets are too full to hold it.")


func _refresh_icons() -> void:
	if visible:
		_show(_selected)


class RecipeRow:
	extends Button
	var item_id: String

	func _init(id: String) -> void:
		item_id = id
		custom_minimum_size = Vector2(410, 54)
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var tex := Icons.get_icon(item_id)
		if tex:
			draw_texture_rect(tex, Rect2(8, 3, 48, 48), false)
		var craftable := Recipes.can_craft(item_id)
		var colour := UIStyle.BROWN if craftable else UIStyle.BROWN_LIGHT
		draw_string(get_theme_default_font(), Vector2(66, 34), ItemDB.display_name(item_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, colour)
		if craftable:
			draw_circle(Vector2(size.x - 22, size.y * 0.5), 8, UIStyle.GREEN)
