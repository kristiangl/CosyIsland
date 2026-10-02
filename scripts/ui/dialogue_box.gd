class_name DialogueBox
extends Control
## Speech at the bottom of the screen: a name tag, text that types itself out, and a
## bobbing arrow when it's done. Press use (or accept) to finish the line or move on.
##
##   dialogue.say("poppy", ["Hello!", "Welcome!"]); await dialogue.finished
##   dialogue.ask("poppy", "Any questions?", ["Yes", "No"]); var pick: int = await dialogue.picked
##
## (Callers await these signals rather than coroutines here, so a conversation cut off
## by quitting the game doesn't leave a chain of coroutines across freed objects.)

signal finished
signal picked(index: int)

const CHARS_PER_SECOND := 42.0
## Extra pause after punctuation, in characters' worth of time.
const PAUSES := {".": 6.0, "!": 6.0, "?": 6.0, ",": 3.0, "…": 8.0}

var _panel: PanelContainer
var _tag: PanelContainer
var _tag_label: Label
var _text: Label
var _arrow: Control
var _choices: VBoxContainer
var _typing := false
var _lines: Array = []
var _options: Array = []
var _shown := 0.0
var _opened_at := 0
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = PanelContainer.new()
	var style := UIStyle.panel(UIStyle.CREAM, 34)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 30
	style.content_margin_bottom = 26
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.custom_minimum_size = Vector2(780, 150)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.position.y -= 28
	add_child(_panel)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 25)
	_text.custom_minimum_size = Vector2(700, 0)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_panel.add_child(_text)

	_tag = PanelContainer.new()
	_tag_label = Label.new()
	_tag_label.add_theme_font_size_override("font_size", 22)
	_tag.add_child(_tag_label)
	_panel.add_child(_tag)
	_tag.top_level = true

	_arrow = Control.new()
	_arrow.custom_minimum_size = Vector2(22, 16)
	_arrow.draw.connect(func():
		_arrow.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(22, 0), Vector2(11, 14)]), UIStyle.ACCENT))
	_arrow.top_level = true
	_panel.add_child(_arrow)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	_choices.visible = false
	add_child(_choices)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _typing:
		_shown += delta * CHARS_PER_SECOND
		var whole := mini(int(_shown), _text.text.length())
		while _text.visible_characters < whole:
			_text.visible_characters += 1
			# Linger a moment after punctuation.
			var ch := _text.text[_text.visible_characters - 1]
			if PAUSES.has(ch) and _text.visible_characters < _text.text.length():
				_shown = _text.visible_characters - PAUSES[ch]
				break
		if _text.visible_characters >= _text.text.length():
			_typing = false
	if not _typing and not _options.is_empty() and not _choices.visible:
		_show_choices()
	# Keep the tag on the panel's top-left corner and the arrow at its bottom-right.
	var rect := _panel.get_global_rect()
	_tag.global_position = rect.position + Vector2(34, -_tag.size.y * 0.6)
	_arrow.global_position = rect.end - Vector2(52, 34 - sin(_time * 6.0) * 3.0)
	_arrow.visible = not _typing and not _choices.visible
	_choices.global_position = Vector2(rect.end.x - _choices.size.x - 10, rect.position.y - _choices.size.y - 22)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _choices.visible:
		return
	var pressed: bool = event.is_action_pressed("use") or event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	# Ignore the press that started the conversation.
	if Time.get_ticks_msec() - _opened_at < 150:
		return
	if _typing:
		_text.visible_characters = -1
		_typing = false
	elif not _options.is_empty():
		return
	elif _lines.is_empty():
		visible = false
		finished.emit()
	else:
		_show(_lines.pop_front())


## Shows each line in turn, waiting for the player between them, then emits finished.
func say(speaker: String, lines: Array) -> void:
	_open(speaker)
	_lines = lines.duplicate()
	_show(_lines.pop_front())


## Shows a question, then the options once it's typed out; emits picked with the index.
func ask(speaker: String, question: String, options: Array) -> void:
	_open(speaker)
	_lines.clear()
	_options = options.duplicate()
	_show(question)


func _show_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()
	var first: Button = null
	for i in _options.size():
		var b := Button.new()
		b.text = Story.fill(_options[i])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_choose.bind(i))
		_choices.add_child(b)
		if first == null:
			first = b
	_choices.visible = true
	_choices.reset_size()
	first.grab_focus.call_deferred()


func _choose(i: int) -> void:
	_choices.visible = false
	_options.clear()
	visible = false
	picked.emit(i)


func _open(speaker: String) -> void:
	var def := NpcData.get_character(speaker)
	_tag_label.text = def.get("name", speaker.capitalize())
	var tag_style := UIStyle.panel(Color(def.get("tag", "#f0b65a")), 18)
	tag_style.content_margin_top = 4
	tag_style.content_margin_bottom = 4
	tag_style.shadow_size = 0
	_tag.add_theme_stylebox_override("panel", tag_style)
	if not visible:
		_opened_at = Time.get_ticks_msec()
	visible = true


func _show(line: String) -> void:
	_text.text = Story.fill(line)
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
