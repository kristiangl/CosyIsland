class_name CharacterCreator
extends Control
## Make your villager (at a new game) or change their look later (the wardrobe).
##
## Left: a 3D preview that leans in on the face for face tabs. Right: a row of tabs with
## icons (switch with L/R or Q/E, or click), and for each tab a grid of styles drawn as
## little pictures, colour swatches, and Mii-style adjustments (move, space, size, tilt).
## Moving the focus over a style or colour tries it on straight away.

signal finished(look: Dictionary, player_name: String, island_name: String)

## Each tab: icon, title, the camera view, and what it holds. "styles"/"colours" name
## appearance keys; "adjust" lists [key, label]; "patterns" adds the top's pattern rows.
const TABS := [
	{"icon": "you", "title": "You", "view": "head", "colours": "skin", "colour_title": "Skin"},
	{"icon": "hair", "title": "Hair", "view": "head", "styles": "hair", "colours": "hair_color"},
	{"icon": "eyes", "title": "Eyes", "view": "face", "styles": "eyes", "colours": "eye_color",
		"adjust": [["eye_y", "Up and down"], ["eye_gap", "Spacing"], ["eye_size", "Size"], ["eye_tilt", "Tilt"]]},
	{"icon": "brows", "title": "Eyebrows", "view": "face", "styles": "brows",
		"adjust": [["brow_y", "Up and down"], ["brow_gap", "Spacing"], ["brow_tilt", "Tilt"]]},
	{"icon": "nose", "title": "Nose", "view": "face", "styles": "nose",
		"adjust": [["nose_y", "Up and down"], ["nose_size", "Size"]]},
	{"icon": "mouth", "title": "Mouth", "view": "face", "styles": "mouth",
		"adjust": [["mouth_y", "Up and down"], ["mouth_size", "Size"]]},
	{"icon": "cheeks", "title": "Cheeks", "view": "face", "styles": "cheeks", "adjust": [["cheek_y", "Up and down"]]},
	{"icon": "top", "title": "Top", "view": "body", "styles": "top", "colours": "top_color", "patterns": true},
	{"icon": "bottom", "title": "Bottoms", "view": "body", "styles": "bottom", "colours": "bottom_color"},
	{"icon": "shoes", "title": "Shoes", "view": "feet", "styles": "shoes", "colours": "shoe_color"},
	{"icon": "hat", "title": "Hats and bows", "view": "head", "styles": "hat", "colours": "hat_color", "positions": true},
	{"icon": "glasses", "title": "Glasses", "view": "face", "styles": "glasses",
		"adjust": [["glasses_y", "Up and down"], ["glasses_size", "Size"]]},
]
## Preview camera [eye, target] for each view.
const VIEWS := {
	"face": [Vector3(0, 1.12, 2.7), Vector3(0, 1.0, 0)],
	"head": [Vector3(0, 1.25, 3.0), Vector3(0, 0.92, 0)],
	"body": [Vector3(0, 0.98, 3.6), Vector3(0, 0.64, 0)],
	"feet": [Vector3(0, 0.9, 3.2), Vector3(0, 0.38, 0)],
}
const NAMES := ["Kit", "Robin", "Sam", "Juniper", "Ash", "Wren", "Mika", "Sunny", "Pip", "Rowan"]

var look: Dictionary
var thumbs: CharacterThumbs
var _preview: CharacterModel
var _preview_cam: Camera3D
var _cam_eye := Vector3(0, 1.0, 4.4)
var _cam_target := Vector3(0, 0.78, 0)
var _tab := 0
var _tab_buttons: Array[TabIcon] = []
var _tab_title: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _name_box: VBoxContainer
var _name_edit: LineEdit
var _island_edit: LineEdit
var _title: Label
var _naming := true
var _spin := 0.0
## While true, moving the focus doesn't try things on.
var quiet := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	visible = false
	thumbs = CharacterThumbs.new()
	add_child(thumbs)
	var dim := ColorRect.new()
	dim.color = Color(0.98, 0.95, 0.88, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 660)
	centre.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	panel.add_child(columns)
	columns.add_child(_build_preview())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	right.add_child(_title)

	# Tabs, with the shoulder buttons that switch them at either end.
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	right.add_child(tab_row)
	tab_row.add_child(_shoulder_hint("{tab_prev}"))
	for i in TABS.size():
		var t := TabIcon.new(TABS[i]["icon"])
		t.pressed.connect(_select_tab.bind(i))
		tab_row.add_child(t)
		_tab_buttons.append(t)
	tab_row.add_child(_shoulder_hint("{tab_next}"))
	_tab_title = Label.new()
	_tab_title.add_theme_font_size_override("font_size", 22)
	_tab_title.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	right.add_child(_tab_title)

	_scroll = ScrollContainer.new()
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_scroll)
	var scroll_box := VBoxContainer.new()
	scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(scroll_box)
	_name_box = VBoxContainer.new()
	_name_box.add_theme_constant_override("separation", 6)
	scroll_box.add_child(_name_box)
	_name_edit = _text_row(_name_box, "Your name")
	_island_edit = _text_row(_name_box, "Island name")
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	scroll_box.add_child(_content)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	right.add_child(buttons)
	var shuffle := Button.new()
	shuffle.text = "Surprise me"
	shuffle.pressed.connect(_randomise)
	buttons.add_child(shuffle)
	var done := Button.new()
	done.text = "All done!"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(_done)
	buttons.add_child(done)
	var hint := Label.new()
	Prompts.bind_label(hint, "{tab_prev} {tab_next} tabs   Move to try things on   Left/right to adjust   {pause} done")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	right.add_child(hint)
	thumbs.thumb_ready.connect(func(_key): get_tree().call_group("creator_tiles", "queue_redraw"))


func _shoulder_hint(template: String) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(30, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	Prompts.bind_label(l, template)
	return l


func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(400, 620)
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("dcefe0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	# Shadows on: the cel lighting maths assumes a shadow-casting sun.
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, 30, 0)
	viewport.add_child(sun)
	_preview_cam = Camera3D.new()
	_preview_cam.fov = 30.0
	viewport.add_child(_preview_cam)
	CameraRig.add_outline_pass(_preview_cam)
	_preview = CharacterModel.new()
	_preview.curved = false
	_preview.fixed_light = true
	viewport.add_child(_preview)
	# Drag with the mouse to turn the preview round.
	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_spin += event.relative.x * 0.01)
	return container


func _text_row(list: VBoxContainer, label_text: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.max_length = 14
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_stylebox_override("normal", UIStyle.panel(UIStyle.CREAM_DARK, 14))
	edit.add_theme_stylebox_override("focus", UIStyle.panel(UIStyle.ACCENT, 14))
	edit.add_theme_color_override("font_color", UIStyle.BROWN)
	row.add_child(edit)
	list.add_child(row)
	return edit


## Opens the creator. With naming off it's the wardrobe (no name fields).
func open(current: Dictionary, naming: bool, player_name: String = "", island_name: String = "") -> void:
	look = Appearance.sanitise(current)
	_naming = naming
	_name_edit.text = player_name if player_name != "" else NAMES[randi() % NAMES.size()]
	_island_edit.text = island_name if island_name != "" else "Driftwood"
	_title.text = "Let's make you!" if naming else "Wardrobe"
	_preview.set_look(look)
	visible = true
	Game.mode = Game.Mode.MENU
	_select_tab(0)
	var view: Array = VIEWS[TABS[0]["view"]]
	_cam_eye = view[0]
	_cam_target = view[1]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("tab_prev"):
		_select_tab(posmod(_tab - 1, TABS.size()))
	elif event.is_action_pressed("tab_next"):
		_select_tab(posmod(_tab + 1, TABS.size()))
	elif event.is_action_pressed("pause"):
		_done()
	else:
		return
	get_viewport().set_input_as_handled()


func _select_tab(i: int) -> void:
	_tab = i
	thumbs.clear_queue()
	for t in _tab_buttons.size():
		_tab_buttons[t].selected = t == i
		_tab_buttons[t].queue_redraw()
	var tab: Dictionary = TABS[i]
	_tab_title.text = tab["title"]
	_name_box.visible = _naming and i == 0
	for child in _content.get_children():
		child.free()
	var first: Control = null
	var designed := false
	if tab.has("styles"):
		first = _style_grid(tab["styles"], tab["view"])
		# Clothes you own sit under the everyday styles; they come in their own colours.
		if ItemDB.SLOT_KEYS.has(tab["styles"]):
			_closet_grid(tab["styles"], tab["view"])
			designed = Appearance.option(look, tab["styles"]).get("designed", false)
	if tab.has("positions"):
		var row := AdjustRow.new(self, "hat_pos", "Wear it")
		row.visible = not Appearance.hat_positions(look).is_empty()
		row.name = "HatPos"
		_content.add_child(row)
	if tab.has("colours") and not designed:
		var colour_first := _swatches(tab["colours"], tab.get("colour_title", "Colour"))
		first = first if first else colour_first
	if tab.get("patterns", false) and not designed:
		_style_grid("top_pattern", "body", "Pattern")
		_swatches("top_color2", "Pattern colour")
	if tab.has("adjust"):
		_section("Adjust")
		for entry: Array in tab["adjust"]:
			_content.add_child(AdjustRow.new(self, entry[0], entry[1]))
	if _naming and i == 0:
		_name_edit.grab_focus.call_deferred()
	elif first:
		_focus_quietly.call_deferred(_focus_selected(first))
	_scroll.scroll_vertical = 0


## Moves the focus without trying anything on.
func _focus_quietly(target: Control) -> void:
	if not is_instance_valid(target):
		return
	quiet = true
	target.grab_focus()
	quiet = false


## The selected tile anywhere on the tab (or the grid's first), to start the focus on.
func _focus_selected(grid: Control) -> Control:
	for child in _content.find_children("*", "", true, false):
		if child is OptionTile and child.is_selected() and not child.swatch:
			return child
	return grid.get_child(0)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_content.add_child(l)


func _style_grid(key: String, view: String, title: String = "Style") -> GridContainer:
	_section(title)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for opt in Appearance.options(key):
		if not opt.get("designed", false):
			grid.add_child(OptionTile.new(self, key, opt["id"], view, false))
	return grid


## Owned clothes for a slot, from the closet.
func _closet_grid(slot: String, view: String) -> void:
	var owned := Inventory.closet.filter(func(id): return ItemDB.get_item(id).get("slot", "") == slot)
	if owned.is_empty():
		return
	_section("Your clothes")
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for id: String in owned:
		grid.add_child(OptionTile.new(self, "item", id, view, false))


func _swatches(key: String, title: String) -> GridContainer:
	_section(title)
	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for opt in Appearance.options(key):
		grid.add_child(OptionTile.new(self, key, opt["id"], "", true))
	return grid


## Tries an option on.
func choose(key: String, id: String) -> void:
	if key == "item":
		_wear_item(id)
		return
	if look.get(key, "") == id:
		return
	var was_designed := _designed(key)
	look[key] = id
	if _designed(key) != was_designed:
		# Colour choices come and go with everyday styles.
		_select_tab.call_deferred(_tab)
	if key == "hat":
		look["hat_pos"] = 0
		var row := _content.get_node_or_null("HatPos")
		if row:
			row.visible = not Appearance.hat_positions(look).is_empty()
	changed()


func _designed(key: String) -> bool:
	return ItemDB.SLOT_KEYS.has(key) and Appearance.option(look, key).get("designed", false)


func _wear_item(id: String) -> void:
	var wear: Dictionary = ItemDB.get_item(id).get("wear", {})
	var same := true
	for k in wear:
		same = same and look.get(k, "") == wear[k]
	if same:
		return
	var key: String = ItemDB.SLOT_KEYS[ItemDB.get_item(id)["slot"]][0]
	var was_designed := _designed(key)
	look.merge(wear, true)
	if key == "hat":
		look["hat_pos"] = 0
	changed()
	if not was_designed:
		_select_tab.call_deferred(_tab)


func changed() -> void:
	_preview.set_look(look)
	get_tree().call_group("creator_tiles", "queue_redraw")


## How an option's picture is drawn: the current look wearing it, simplified so the
## part shows (no hat over the hair, short hair for faces).
func thumb_look(key: String, id: String, view: String) -> Dictionary:
	var l := look.duplicate()
	l[key] = id
	if key != "hat":
		l["hat"] = "none"
	if view == "face":
		l["hair"] = "buzz"
		if key != "glasses":
			l["glasses"] = "none"
	return l


func _process(delta: float) -> void:
	if not visible or _preview == null:
		return
	var view: Array = VIEWS[TABS[_tab]["view"]]
	var k := 1.0 - exp(-delta * 6.0)
	_cam_eye = _cam_eye.lerp(view[0], k)
	_cam_target = _cam_target.lerp(view[1], k)
	_preview_cam.transform = Transform3D(Basis.looking_at(_cam_target - _cam_eye), _cam_eye)
	# Faces stay facing the camera; outfits sway round so you see them from the side too.
	var sway := 0.15 if TABS[_tab]["view"] == "face" else 0.6
	_preview.rotation.y = _spin + sin(Time.get_ticks_msec() / 1600.0) * sway
	_preview.animate(delta, 0.0)


func _randomise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	look = Appearance.random(rng)
	changed()
	_select_tab(_tab)


func _done() -> void:
	visible = false
	thumbs.clear_queue()
	Game.mode = Game.Mode.PLAY
	var player_name := _name_edit.text.strip_edges()
	var island_name := _island_edit.text.strip_edges()
	finished.emit(look.duplicate(), player_name if player_name != "" else "Kit", island_name if island_name != "" else "Driftwood")


## A tab: an icon on a rounded square, highlighted when selected.
class TabIcon:
	extends Button
	var icon_id: String
	var selected := false

	func _init(id: String) -> void:
		icon_id = id
		custom_minimum_size = Vector2(52, 52)
		focus_mode = Control.FOCUS_NONE
		flat = true

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		sb.bg_color = UIStyle.ACCENT if selected else UIStyle.CREAM_DARK
		draw_style_box(sb, r)
		UIIcons.draw(self, icon_id, size * 0.5, size.x * 0.62, UIStyle.BROWN if selected else UIStyle.BROWN_LIGHT)


## One option: a style shown as a picture of the character wearing it, or a colour
## swatch. Focusing it (moving onto it) tries it on.
class OptionTile:
	extends Button
	var creator: CharacterCreator
	var key: String
	var id: String
	var view: String
	var swatch: bool

	func _init(owner_creator: CharacterCreator, look_key: String, option_id: String, thumb_view: String, is_swatch: bool) -> void:
		creator = owner_creator
		key = look_key
		id = option_id
		view = thumb_view
		swatch = is_swatch
		custom_minimum_size = Vector2(40, 40) if swatch else Vector2(76, 76)
		focus_mode = Control.FOCUS_ALL
		flat = true
		tooltip_text = _name()
		add_to_group("creator_tiles")
		focus_entered.connect(func(): if not creator.quiet: creator.choose(key, id))
		pressed.connect(func(): creator.choose(key, id))

	func is_selected() -> bool:
		if key == "item":
			var wear: Dictionary = ItemDB.get_item(id).get("wear", {})
			for k in wear:
				if creator.look.get(k, "") != wear[k]:
					return false
			return true
		return creator.look.get(key, "") == id

	func _name() -> String:
		if key == "item":
			return ItemDB.display_name(id)
		for opt in Appearance.options(key):
			if opt["id"] == id:
				return opt.get("name", id.capitalize())
		return id

	func _draw() -> void:
		var selected := is_selected()
		var focused := has_focus()
		var r := Rect2(Vector2.ZERO, size)
		if swatch:
			var colour := Color("#ff00ff")
			for opt in Appearance.options(key):
				if opt["id"] == id:
					colour = Color(opt.get("color", "#ff00ff"))
			var c := size * 0.5
			if selected or focused:
				draw_circle(c, size.x * 0.5, UIStyle.ACCENT if focused else UIStyle.BROWN_LIGHT)
			draw_circle(c, size.x * 0.5 - 4, Color.WHITE)
			draw_circle(c, size.x * 0.5 - 6, colour)
			return
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.bg_color = Color("f3ead2") if not selected else Color("fbe3b0")
		sb.border_color = UIStyle.ACCENT if focused else (UIStyle.BROWN_LIGHT if selected else Color(0, 0, 0, 0))
		sb.set_border_width_all(4 if focused else 3)
		draw_style_box(sb, r)
		if id == "none" or id == "plain":
			# "None": an empty circle with a line through it.
			if id == "none":
				draw_arc(size * 0.5, size.x * 0.22, 0, TAU, 24, UIStyle.BROWN_LIGHT, 3, true)
				draw_line(size * 0.5 + Vector2(-0.15, 0.15) * size.x, size * 0.5 + Vector2(0.15, -0.15) * size.x, UIStyle.BROWN_LIGHT, 3)
				return
		var tex: Texture2D
		if key == "item":
			var l := creator.look.duplicate()
			l.merge(ItemDB.get_item(id).get("wear", {}), true)
			if not ItemDB.get_item(id).get("slot", "") == "hat":
				l["hat"] = "none"
			tex = creator.thumbs.get_thumb(l, view)
		else:
			tex = creator.thumbs.get_thumb(creator.thumb_look(key, id, view), view)
		if tex:
			draw_texture_rect(tex, r.grow(-4), false)
		else:
			var font := get_theme_default_font()
			draw_string(font, Vector2(4, size.y * 0.5 + 6), _name(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 13, UIStyle.BROWN)


## An adjustment: "Label   - ●●●○●●●●● +". Left/right (or clicking either end) changes it.
class AdjustRow:
	extends Button
	var creator: CharacterCreator
	var key: String
	var label_text: String

	func _init(owner_creator: CharacterCreator, look_key: String, text_label: String) -> void:
		creator = owner_creator
		key = look_key
		label_text = text_label
		custom_minimum_size = Vector2(560, 42)
		focus_mode = Control.FOCUS_ALL
		flat = true
		add_to_group("creator_tiles")
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			_step(-1)
			accept_event()
		elif event.is_action_pressed("ui_right"):
			_step(1)
			accept_event()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_step(-1 if event.position.x < size.x * 0.62 else 1)
			accept_event()

	func _step(direction: int) -> void:
		Appearance.adjust(creator.look, key, direction)
		creator.changed()

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.bg_color = UIStyle.ACCENT if has_focus() else UIStyle.CREAM_DARK
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var y := size.y * 0.5 + 7
		draw_string(font, Vector2(18, y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UIStyle.BROWN)
		var x0 := size.x * 0.42
		draw_string(font, Vector2(x0 - 26, y), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.BROWN_LIGHT)
		draw_string(font, Vector2(size.x - 28, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.BROWN_LIGHT)
		var value := int(creator.look.get(key, 0))
		if key == "hat_pos":
			var ways := Appearance.hat_positions(creator.look)
			var name: String = ways[clampi(value, 0, ways.size() - 1)]["name"] if not ways.is_empty() else "-"
			draw_string(font, Vector2(x0, y), name, HORIZONTAL_ALIGNMENT_CENTER, size.x - x0 - 40, 19, UIStyle.BROWN)
			return
		var lo: int = Appearance.ADJUST[key][0]
		var hi: int = Appearance.ADJUST[key][1]
		var width := size.x - x0 - 44
		for v in range(lo, hi + 1):
			var cx := x0 + 6 + width * float(v - lo) / float(hi - lo)
			var on := v == value
			draw_circle(Vector2(cx, size.y * 0.5), 8.0 if on else (5.0 if v == 0 else 4.0), UIStyle.BROWN if on else UIStyle.BROWN_LIGHT)
