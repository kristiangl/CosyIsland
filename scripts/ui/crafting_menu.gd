class_name CraftingMenu
extends PanelContainer
## The DIY workbench, with two tabs (switch with L/R, Q/E or by clicking). Make: known
## recipes on the left, the selected one's materials on the right; A crafts; left and
## right show one kind of thing at a time (GROUPS). Customise:
## furniture and clothes in your pockets that come in other colourways; left/right picks
## one and A remakes it with a customisation kit. B closes. Opened from the phone
## (open_book) it's just the recipe book: the recipes you know and what they need.

var _mode := "make"
## The kinds of thing the recipe list can show, one at a time: [id, name].
const GROUPS := [["all", "All"], ["furniture", "Furniture"], ["outdoor", "Outdoor"], ["interior", "Walls & floors"],
	["clothing", "Clothes"], ["tool", "Tools"]]
var _group := 0
var _group_buttons: Array[Button] = []
var _group_row: HBoxContainer
## The phone's recipe book: look, don't make.
var browsing := false
var _title: Label
var _tabs: Array[Button] = []
var _list: VBoxContainer
var _icon: TextureRect
var _name: Label
var _desc: Label
var _materials: VBoxContainer
var _hint: Label
var _hint_template := ""
var _rows: Array[RecipeRow] = []
var _selected: RecipeRow


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(980, 560)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(450, 0)
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	left.add_child(title_row)
	_title = Label.new()
	_title.text = "Workbench"
	_title.add_theme_font_size_override("font_size", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title)
	for mode: String in ["make", "customise"]:
		var b := Button.new()
		b.text = mode.capitalize()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.pressed.connect(_set_mode.bind(mode))
		title_row.add_child(b)
		_tabs.append(b)
	_group_row = HBoxContainer.new()
	_group_row.add_theme_constant_override("separation", 4)
	left.add_child(_group_row)
	for i in GROUPS.size():
		var g := Button.new()
		g.text = GROUPS[i][1]
		g.toggle_mode = true
		g.focus_mode = Control.FOCUS_NONE
		g.add_theme_font_size_override("font_size", 14)
		g.pressed.connect(_set_group.bind(i))
		_group_row.add_child(g)
		_group_buttons.append(g)
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
	_desc.custom_minimum_size = Vector2(460, 0)
	right.add_child(_desc)
	_materials = VBoxContainer.new()
	_materials.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_materials)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_hint)
	Prompts.method_changed.connect(func(): _hint.text = Prompts.fill(_hint_template))

	Icons.icon_ready.connect(func(_id): _refresh())
	Events.inventory_changed.connect(_refresh)


func open(mode: String = "make") -> void:
	Sfx.play("page")
	browsing = false
	_title.text = "Workbench"
	for tab in _tabs:
		tab.visible = true
	visible = true
	Game.mode = Game.Mode.MENU
	_set_mode(mode)


## The recipe book, from the phone: every recipe you know and what it takes.
func open_book() -> void:
	open("make")
	browsing = true
	_title.text = "DIY Recipes"
	for tab in _tabs:
		tab.visible = false
	_hint_template = "%d recipes   Left/right sort   Make them at a workbench   {ui_cancel} close" % Recipes.known.size()
	_hint.text = Prompts.fill(_hint_template)


func close() -> void:
	visible = false
	Game.mode = Game.Mode.PLAY


func is_customising() -> bool:
	return _mode == "customise"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pockets"):
		close()
	elif (event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next")) and not browsing:
		_set_mode("customise" if _mode == "make" else "make")
	elif _mode == "make" and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		# (With a recipe picked, its row takes these; this is for an empty list.)
		cycle_group(-1 if event.is_action_pressed("ui_left") else 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _set_mode(mode: String) -> void:
	_mode = mode
	_tabs[0].button_pressed = mode == "make"
	_tabs[1].button_pressed = mode == "customise"
	var hint := "{ui_accept} craft   Left/right sort   {tab_prev} {tab_next} customise   {ui_cancel} close" if mode == "make" \
		else "Left/right colour   {ui_accept} customise   {tab_prev} {tab_next} make   {ui_cancel} close"
	_hint_template = hint
	_hint.text = Prompts.fill(hint)
	_rebuild()


func _rebuild() -> void:
	# Rows go after this frame: one of them may be mid-press.
	for r in _rows:
		_list.remove_child(r)
		r.queue_free()
	_rows.clear()
	_selected = null
	_group_row.visible = _mode == "make"
	for i in _group_buttons.size():
		_group_buttons[i].button_pressed = i == _group
	if _mode == "make":
		var ids := Recipes.known.filter(func(id): return _in_group(id))
		# Craftable things first, then alphabetical.
		ids.sort_custom(func(a, b):
			var ca := Recipes.can_craft(a)
			var cb := Recipes.can_craft(b)
			if ca != cb:
				return ca
			return ItemDB.display_name(a) < ItemDB.display_name(b))
		for id in ids:
			_add_row(RecipeRow.new(id, -1, self))
	else:
		for i in Inventory.slots.size():
			var slot := Inventory.slots[i]
			if not slot.is_empty() and not ItemDB.variants_of(slot["id"]).is_empty():
				_add_row(RecipeRow.new(slot["id"], i, self))
	if _rows.is_empty():
		_icon.texture = null
		_name.text = "Nothing to customise" if _mode == "customise" else ("No recipes yet" if _group == 0 else "None of these yet")
		_desc.text = "Bring furniture or clothes that come in other colours." if _mode == "customise" \
			else "Message bottles wash up with recipes."
		for child in _materials.get_children():
			child.queue_free()
		return
	var first: WeakRef = weakref(_rows[0])
	(func():
		var row: RecipeRow = first.get_ref()
		if row and row.is_inside_tree():
			row.grab_focus()).call_deferred()
	_show(_rows[0])


## Shows one kind of recipe (an index into GROUPS).
func _set_group(i: int) -> void:
	_group = posmod(i, GROUPS.size())
	Sfx.play("ui_move", -4.0, 1.0, 0.03)
	_rebuild()


func cycle_group(direction: int) -> void:
	_set_group(_group + direction)


func _in_group(id: String) -> bool:
	return GROUPS[_group][0] == "all" or GROUPS[_group][0] == group_of(id)


## Which of GROUPS a recipe's item belongs to.
static func group_of(id: String) -> String:
	var def := ItemDB.get_item(id)
	if ItemDB.placeable(id).get("outdoor", false):
		return "outdoor"
	match def.get("category", ""):
		"interior":
			return "interior"
		"clothing":
			return "clothing"
		"tool":
			return "tool"
	return "furniture"


func _add_row(row: RecipeRow) -> void:
	row.focus_entered.connect(_show.bind(row))
	row.pressed.connect(_activate.bind(row))
	_list.add_child(row)
	_rows.append(row)


func _refresh() -> void:
	if visible and _selected and is_instance_valid(_selected):
		_show(_selected)


func _show(row: RecipeRow) -> void:
	_selected = row
	var id := row.choice
	_icon.texture = Icons.get_icon(id)
	for child in _materials.get_children():
		child.queue_free()
	if _mode == "make":
		var makes := Recipes.makes(id)
		_name.text = ItemDB.display_name(id) + (" x%d" % makes if makes > 1 else "")
		_desc.text = ItemDB.get_item(id).get("desc", "")
		var mats := Recipes.materials(id)
		for mat in mats:
			_material_line(mat, int(mats[mat]))
	else:
		var options := ItemDB.variants_of(row.item_id)
		_name.text = ItemDB.display_name(id)
		_desc.text = "Colourway %d of %d. %s" % [options.find(id) + 1, options.size(),
			"This is how it is now." if id == row.item_id else "Customise to remake it like this."]
		_material_line(Recipes.KIT, 1)
	for r in _rows:
		r.queue_redraw()


func _material_line(mat: String, need: int) -> void:
	var have := Inventory.count_of(mat)
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


## Left/right on a customise row: look at the next colourway.
func cycle(row: RecipeRow, direction: int) -> void:
	var options := ItemDB.variants_of(row.item_id)
	if options.is_empty():
		return
	row.choice = options[posmod(options.find(row.choice) + direction, options.size())]
	_show(row)


func _activate(row: RecipeRow) -> void:
	if browsing:
		Events.toast.emit("Make it at a workbench.")
		return
	if _mode == "make":
		_craft(row)
	else:
		_customise(row)


func _craft(row: RecipeRow) -> void:
	var id := row.item_id
	if not Recipes.can_craft(id):
		Events.toast.emit("You need more materials for that.")
		return
	if Recipes.craft(id):
		await _hammer()
		Events.toast.emit("You made %s!" % ItemDB.display_name(id).to_lower())
		row.grab_focus()
	else:
		Events.toast.emit("Your pockets are too full to hold it.")


func _customise(row: RecipeRow) -> void:
	if row.choice == row.item_id:
		Events.toast.emit("Pick a new colourway with left and right first.")
		return
	var problem := Recipes.customise(row.slot, row.choice)
	if problem != "":
		Events.toast.emit(problem)
		return
	var before := ItemDB.display_name(row.item_id)
	row.item_id = row.choice
	await _hammer()
	Events.toast.emit("Your %s is now %s!" % [before.to_lower(), ItemDB.variant_name(row.item_id).to_lower()])
	_show(row)
	row.grab_focus()


## Steps away from the menu to watch the hammering, then comes back to it.
func _hammer() -> void:
	visible = false
	if Game.player:
		await Game.player.craft_animation()
	visible = true


## One line: icon and name; in Customise, the colourways as dots on the right.
class RecipeRow:
	extends Button
	var item_id: String
	## The colourway being looked at (Customise), else the item itself.
	var choice: String
	## Pocket slot (Customise), or -1.
	var slot: int
	var menu: CraftingMenu

	func _init(id: String, pocket_slot: int, owner_menu: CraftingMenu) -> void:
		item_id = id
		choice = id
		slot = pocket_slot
		menu = owner_menu
		custom_minimum_size = Vector2(430, 54)
		focus_mode = Control.FOCUS_ALL

	func _gui_input(event: InputEvent) -> void:
		if slot < 0:
			# Making: left and right show another kind of thing.
			for step: Array in [["ui_left", -1], ["ui_right", 1]]:
				if event.is_action_pressed(step[0]):
					menu.cycle_group(step[1])
					accept_event()
			return
		if event.is_action_pressed("ui_left"):
			menu.cycle(self, -1)
			accept_event()
		elif event.is_action_pressed("ui_right"):
			menu.cycle(self, 1)
			accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Clicking a dot picks that colourway.
			var options := ItemDB.variants_of(item_id)
			var i := floori((event.position.x - _dots_x(options.size())) / 22.0)
			if i >= 0 and i < options.size():
				choice = options[i]
				menu._show(self)
				grab_focus()
				accept_event()

	func _dots_x(count: int) -> float:
		return size.x - 16 - count * 22

	func _draw() -> void:
		var tex := Icons.get_icon(choice)
		if tex:
			draw_texture_rect(tex, Rect2(8, 3, 48, 48), false)
		var font := get_theme_default_font()
		if slot < 0:
			var craftable := Recipes.can_craft(item_id)
			draw_string(font, Vector2(66, 34), ItemDB.display_name(item_id), HORIZONTAL_ALIGNMENT_LEFT, size.x - 100, 20,
				UIStyle.BROWN if craftable else UIStyle.BROWN_LIGHT)
			if craftable:
				draw_circle(Vector2(size.x - 22, size.y * 0.5), 8, UIStyle.GREEN)
			return
		var options := ItemDB.variants_of(item_id)
		var x0 := _dots_x(options.size())
		draw_string(font, Vector2(66, 34), ItemDB.display_name(choice), HORIZONTAL_ALIGNMENT_LEFT, x0 - 76, 19, UIStyle.BROWN)
		for i in options.size():
			var centre := Vector2(x0 + 11 + i * 22, size.y * 0.5)
			var id: String = options[i]
			if id == choice:
				draw_circle(centre, 10, UIStyle.BROWN)
			# Half and half: wood and fabric, or a garment's two colours.
			var sw := ItemDB.swatch(id)
			draw_circle(centre, 7, sw[0])
			var half := PackedVector2Array()
			for j in 9:
				var a := -PI * 0.5 + PI * j / 8.0
				half.append(centre + Vector2(cos(a), sin(a)) * 7.0)
			draw_colored_polygon(half, sw[1])
			draw_arc(centre, 7.5, 0.0, TAU, 20, UIStyle.BROWN_LIGHT, 1.5, true)
			if id == item_id:
				draw_circle(centre + Vector2(0, 14), 2.5, UIStyle.BROWN)
