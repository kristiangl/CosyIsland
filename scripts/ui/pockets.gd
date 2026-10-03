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
	# Compact and at the top of the screen, so you can watch yourself eat and craft.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	var title := Label.new()
	title.text = "Pockets"
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_name_label)
	_currency_label = Label.new()
	header.add_child(_currency_label)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_grid)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_desc_label = Label.new()
	_desc_label.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_desc_label.add_theme_font_size_override("font_size", 17)
	_desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc_label.custom_minimum_size = Vector2(380, 0)
	footer.add_child(_desc_label)
	var hint := Label.new()
	Prompts.bind_label(hint, "{ui_accept} use   {pickup} drop   {pockets} close")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	footer.add_child(hint)
	_add_slots()
	Events.pockets_resized.connect(_add_slots)
	Events.inventory_changed.connect(_refresh)
	Events.equipped_changed.connect(func(_id): _refresh())
	Events.currency_changed.connect(func(_c): _refresh())
	Icons.icon_ready.connect(func(_id): if visible: _refresh())


## A button for every pocket slot (more appear when the pockets grow).
func _add_slots() -> void:
	for i in range(_buttons.size(), Inventory.slots.size()):
		var b := SlotButton.new()
		b.index = i
		b.focus_entered.connect(_on_focus.bind(i))
		b.pressed.connect(_use_slot.bind(i))
		_grid.add_child(b)
		_buttons.append(b)


func open() -> void:
	Game.mode = Game.Mode.MENU
	visible = true
	_refresh()
	reset_size()
	position = Vector2((get_parent_area_size().x - size.x) * 0.5, 14)
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
		_name_label.text += "  (%d uses left)" % slot["durability"]
	if i == Inventory.equipped_slot:
		extra += "  - holding"
	_desc_label.text = def.get("desc", "") + extra


func _use_slot(i: int) -> void:
	var slot := Inventory.slots[i]
	if slot.is_empty():
		return
	var id: String = slot["id"]
	var def := ItemDB.get_item(id)
	if def.get("category", "") == "flower":
		_use_flower(i)
		return
	if def.get("category", "") == "flower_plant":
		var here: World = Game.world
		var front := Game.player.target_tile()
		if not here.can_plant(front):
			Events.toast.emit("Flowers need open ground outdoors. Try facing a clear spot.")
			return
		here.plant_flower(id, front)
		Inventory.remove_from_slot(i)
		close()
		Game.player.model.play("pickup")
		Events.toast.emit("Planted! It'll flower every day.")
		return
	if ItemDB.is_tool(id):
		Inventory.equip(-1 if Inventory.equipped_slot == i else i)
	elif not ItemDB.placeable(id).is_empty():
		close()
		place_requested.emit(i)
	elif def.get("category", "") == "clothing":
		var player := Game.player
		player.model.set_look(Inventory.wear_from_slot(i, player.model.look))
		Journal.add("clothes_worn")
		player.model.play("cheer")
		Effects.burst("sparkle", player.position + Vector3(0, 0.9, 0))
		Events.toast.emit("You put on the %s. It's in your wardrobe now." % ItemDB.display_name(id).to_lower())
	elif def.get("category", "") == "interior":
		var here: World = Game.world
		if not here.interior:
			Events.toast.emit("That's for decorating inside your home.")
			return
		Inventory.remove_from_slot(i)
		var old := here.set_room_look(id)
		if old != "":
			Inventory.add_item(old)
		Events.toast.emit("The room looks lovely!")
		_refresh()
	elif def.get("category", "") == "fruit":
		Inventory.remove_from_slot(i)
		close()
		Game.player.eat(id)
		Events.toast.emit("Mmm, delicious!")
	else:
		_drop_slot(i)


## A picked flower: wear it in your hair, or stand it in a vase somewhere.
func _use_flower(i: int) -> void:
	var id: String = Inventory.slots[i]["id"]
	var player := Game.player
	close()
	var options := ["Wear it in my hair", "Put it in a vase", "Never mind"]
	var wearing: String = player.model.look.get("hair_flower", "")
	if wearing != "":
		options.insert(2, "Take out my hair flower")
	Game.mode = Game.Mode.MENU
	Game.dialogue.ask("", "What shall I do with the %s?" % ItemDB.display_name(id).to_lower(), options)
	var pick: String = options[await Game.dialogue.picked]
	Game.mode = Game.Mode.PLAY
	match pick:
		"Wear it in my hair":
			var look: Dictionary = player.model.look.duplicate()
			look["hair_flower"] = id
			Inventory.remove_from_slot(i)
			if wearing != "":
				Inventory.add_item(wearing)
			player.model.set_look(look)
			player.model.play("cheer")
			Effects.burst("sparkle", player.position + Vector3(0, 1.0, 0))
		"Put it in a vase":
			place_requested.emit(i)
		"Take out my hair flower":
			var look: Dictionary = player.model.look.duplicate()
			look["hair_flower"] = ""
			player.model.set_look(look)
			if Inventory.add_item(wearing) > 0:
				Events.toast.emit("Your pockets are full, so it's on the ground.")
				Game.world.drop_from_pockets(player.tile(), player.target_tile(), wearing, 1)


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
		custom_minimum_size = Vector2(58, 58)
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var slot := Inventory.slots[index]
		var c := size * 0.5
		if index == Inventory.equipped_slot:
			draw_circle(c, 26, UIStyle.GREEN)
		if slot.is_empty():
			draw_circle(c, 6, UIStyle.BROWN_LIGHT * Color(1, 1, 1, 0.35))
			return
		var font := get_theme_default_font()
		var tex := Icons.get_icon(slot["id"])
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(25, 25), Vector2(50, 50)), false)
		else:
			var col := ItemDB.color_of(slot["id"])
			draw_circle(c, 20, col)
		if slot["count"] > 1:
			draw_string(font, Vector2(size.x - 24, size.y - 6), str(slot["count"]), HORIZONTAL_ALIGNMENT_RIGHT, 22, 16, UIStyle.BROWN)
