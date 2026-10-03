class_name JournalMenu
extends PanelContainer
## Poppy's Island Journal, from the phone. Four tabs (L/R, Q/E or click): Today's five
## tasks, Milestones, the stamp Exchange where A buys, and the Critters you've caught
## (and given to the museum). B closes.

const TABS := ["today", "milestones", "exchange", "critters"]

var _tab := "today"
var _tabs: Array[Button] = []
var _list: VBoxContainer
var _icon: TextureRect
var _name: Label
var _desc: Label
var _detail: Label
var _stamps: Label
var _hint: Label
var _hint_template := ""
var _rows: Array[JournalRow] = []
var _selected: JournalRow
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(980, 560)
	_rng.randomize()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(500, 0)
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	left.add_child(title_row)
	var title := Label.new()
	title.text = "Island Journal"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	for tab: String in TABS:
		var b := Button.new()
		b.text = tab.capitalize()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.pressed.connect(_set_tab.bind(tab))
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
	_stamps = Label.new()
	_stamps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stamps.add_theme_font_size_override("font_size", 22)
	right.add_child(_stamps)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(150, 150)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(_icon)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 26)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_name)
	_desc = Label.new()
	_desc.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.custom_minimum_size = Vector2(400, 0)
	right.add_child(_desc)
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 22)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", UIStyle.BROWN_LIGHT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_hint)
	Prompts.method_changed.connect(func(): _hint.text = Prompts.fill(_hint_template))

	Icons.icon_ready.connect(func(_id): _refresh())
	Journal.stamps_changed.connect(func(_s): _refresh())


func open(tab: String = "today") -> void:
	visible = true
	Game.mode = Game.Mode.MENU
	_set_tab(tab)


func close() -> void:
	visible = false
	Game.mode = Game.Mode.PLAY


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		close()
	elif event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next"):
		var step := -1 if event.is_action_pressed("tab_prev") else 1
		_set_tab(TABS[posmod(TABS.find(_tab) + step, TABS.size())])
	else:
		return
	get_viewport().set_input_as_handled()


func _set_tab(tab: String) -> void:
	_tab = tab
	for i in TABS.size():
		_tabs[i].button_pressed = TABS[i] == tab
	_hint_template = "{ui_accept} trade   {tab_prev} {tab_next} pages   {ui_cancel} close" if tab == "exchange" \
		else "{tab_prev} {tab_next} pages   {ui_cancel} close"
	_hint.text = Prompts.fill(_hint_template)
	for r in _rows:
		_list.remove_child(r)
		r.queue_free()
	_rows.clear()
	match tab:
		"today":
			for task: Dictionary in Journal.tasks_today():
				_add_row(JournalRow.new("today", task))
		"milestones":
			for m: Dictionary in Journal.milestones:
				_add_row(JournalRow.new("milestones", m))
		"exchange":
			for offer: Dictionary in Journal.exchange:
				_add_row(JournalRow.new("exchange", offer))
		"critters":
			for c: Dictionary in ItemDB.fish.values() + ItemDB.bugs.values():
				_add_row(JournalRow.new("critters", c))
	if not _rows.is_empty():
		var first: WeakRef = weakref(_rows[0])
		(func():
			var row: JournalRow = first.get_ref()
			if row and row.is_inside_tree():
				row.grab_focus()).call_deferred()
		_show(_rows[0])


func _add_row(row: JournalRow) -> void:
	row.focus_entered.connect(_show.bind(row))
	row.pressed.connect(_activate.bind(row))
	_list.add_child(row)
	_rows.append(row)


func _refresh() -> void:
	if visible and _selected and is_instance_valid(_selected):
		_show(_selected)


func _show(row: JournalRow) -> void:
	_selected = row
	_stamps.text = "%d stamps" % Journal.stamps
	var d := row.data
	_icon.texture = null
	match row.kind:
		"today":
			var have := mini(int(Journal.today_stats.get(d["stat"], 0)), int(d["n"]))
			_name.text = d["text"]
			_desc.text = "One of today's little things. New ones every morning."
			_detail.text = "Done! +%d stamps" % int(d["stamps"]) if d["id"] in Journal.today_done \
				else "%d / %d     +%d stamps" % [have, int(d["n"]), int(d["stamps"])]
		"milestones":
			var p := Journal.progress(d)
			_name.text = d["name"]
			_desc.text = String(d["text"]).replace("{n}", str(p["goal"]))
			if p["done"]:
				_detail.text = "All done! %d so far." % p["count"]
			else:
				_detail.text = "%d / %d     +%d stamps" % [p["count"], p["goal"], int(d["stamps"][p["tier"]])]
				var recipe: String = d.get("recipes", {}).get(str(p["tier"]), "")
				if recipe != "":
					_detail.text += "\nand a recipe: %s" % ItemDB.display_name(recipe)
		"exchange":
			_icon.texture = Icons.get_icon(d.get("icon", ""))
			_name.text = d["name"]
			_desc.text = d["desc"]
			var why := Journal.can_buy(d)
			_detail.text = "%d stamps" % int(d["cost"]) + ("" if why == "" else "\n" + why)
		"critters":
			var seen: bool = d["id"] in Journal.caught
			_icon.texture = Icons.get_icon(d["id"]) if seen else null
			_name.text = d["name"] if seen else "Not caught yet"
			_desc.text = "%s %s" % [ItemDB.WHERE_TEXT.get(d["where"], ""), hours_text(d["hours"])]
			_detail.text = ("In the museum" if d["id"] in Journal.donated else ("Sells for %d acorns" % int(d["price"]) if seen else ""))
	for r in _rows:
		r.queue_redraw()


## "All day", or the hours a creature is about, like "4am to 9pm".
static func hours_text(hours: Array) -> String:
	if int(hours[0]) == 0 and int(hours[1]) == 24:
		return "About all day."
	var h := func(x: int) -> String:
		var x12 := x % 12
		return "%d%s" % [12 if x12 == 0 else x12, "am" if x % 24 < 12 else "pm"]
	return "About from %s to %s." % [h.call(int(hours[0])), h.call(int(hours[1]))]


func _activate(row: JournalRow) -> void:
	if row.kind != "exchange":
		return
	var why := Journal.can_buy(row.data)
	if why != "":
		Events.toast.emit(why)
		return
	var got := Journal.buy(row.data, _rng)
	Events.toast.emit("Poppy sent you %s!" % got)
	if Game.player:
		Effects.burst("confetti", Game.player.position + Vector3(0, 1.0, 0))
	_show(row)


## One line of the journal: a task, a milestone with its progress, or an offer.
class JournalRow:
	extends Button
	var kind: String
	var data: Dictionary

	func _init(row_kind: String, row_data: Dictionary) -> void:
		kind = row_kind
		data = row_data
		custom_minimum_size = Vector2(480, 54)
		focus_mode = Control.FOCUS_ALL

	func _draw() -> void:
		var font := get_theme_default_font()
		var x := 16.0
		if kind == "critters":
			var seen: bool = data["id"] in Journal.caught
			var tex := Icons.get_icon(data["id"]) if seen else null
			if tex:
				draw_texture_rect(tex, Rect2(8, 3, 48, 48), false)
			else:
				draw_circle(Vector2(32, 27), 16, UIStyle.BROWN_LIGHT * Color(1, 1, 1, 0.3))
				draw_string(font, Vector2(24, 34), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.BROWN_LIGHT)
			draw_string(font, Vector2(66, 34), data["name"] if seen else "???", HORIZONTAL_ALIGNMENT_LEFT, size.x - 190, 20,
				UIStyle.BROWN if seen else UIStyle.BROWN_LIGHT)
			if data["id"] in Journal.donated:
				draw_string(font, Vector2(size.x - 130, 34), "Museum", HORIZONTAL_ALIGNMENT_RIGHT, 110, 16, UIStyle.GREEN)
			return
		if kind == "exchange":
			var tex := Icons.get_icon(data.get("icon", ""))
			if tex:
				draw_texture_rect(tex, Rect2(8, 3, 48, 48), false)
			x = 66.0
			var dim := Journal.can_buy(data) != ""
			draw_string(font, Vector2(x, 34), data["name"], HORIZONTAL_ALIGNMENT_LEFT, size.x - 190, 20, UIStyle.BROWN_LIGHT if dim else UIStyle.BROWN)
			draw_string(font, Vector2(size.x - 130, 34), "%d" % int(data["cost"]), HORIZONTAL_ALIGNMENT_RIGHT, 110, 20, UIStyle.BROWN_LIGHT if dim else UIStyle.BROWN)
			return
		var label: String
		var fraction: float
		var done: bool
		if kind == "today":
			done = data["id"] in Journal.today_done
			label = data["text"]
			fraction = float(Journal.today_stats.get(data["stat"], 0)) / float(data["n"])
		else:
			var p := Journal.progress(data)
			done = p["done"]
			label = data["name"]
			var tier: int = p["tier"]
			var before := 0 if tier == 0 else int(data["goals"][tier - 1])
			fraction = 1.0 if done else float(p["count"] - before) / float(p["goal"] - before)
			# A star for each goal reached.
			for i in data["goals"].size():
				var c := Vector2(size.x - 24 - (data["goals"].size() - 1 - i) * 18, 16)
				draw_circle(c, 6.0, UIStyle.ACCENT if i < tier else UIStyle.BROWN_LIGHT * Color(1, 1, 1, 0.35))
		draw_string(font, Vector2(x, 26), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 120, 19, UIStyle.BROWN)
		# Progress bar.
		var bar := Rect2(x, 36, size.x - 140, 8)
		draw_rect(bar, UIStyle.BROWN_LIGHT * Color(1, 1, 1, 0.25))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fraction, 0.0, 1.0), bar.size.y)), UIStyle.GREEN if done else UIStyle.ACCENT)
		if done:
			draw_string(font, Vector2(size.x - 110, 44), "Done!", HORIZONTAL_ALIGNMENT_RIGHT, 96, 16, UIStyle.GREEN)
