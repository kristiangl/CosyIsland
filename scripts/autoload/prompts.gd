extends Node
## Tracks whether the player is using a keyboard or a controller and names buttons to
## match, so on-screen hints read "E use" on a keyboard and "A use" on a Switch pad.
##
## UI text uses placeholders like "{use} use   {pickup} pick up" and calls fill(), or
## binds a label with bind_label() so it updates when the method changes.

signal method_changed

enum Method { KEYBOARD, CONTROLLER }

var method: Method = Method.KEYBOARD
## "nintendo", "xbox" or "playstation", from the connected pad's name.
var pad_family := "nintendo"

## Face buttons by Godot's (Xbox-position) index, named per controller family.
const FACE_NAMES := {
	"nintendo": {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X"},
	"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y"},
	"playstation": {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle"},
}
const OTHER_BUTTONS := {
	JOY_BUTTON_START: "+", JOY_BUTTON_BACK: "-",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
}


func _ready() -> void:
	if not Input.get_connected_joypads().is_empty():
		_set_family(Input.get_connected_joypads()[0])


func _input(event: InputEvent) -> void:
	var now := method
	if event is InputEventKey or event is InputEventMouseButton:
		now = Method.KEYBOARD
	elif event is InputEventJoypadButton:
		now = Method.CONTROLLER
		_set_family(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		now = Method.CONTROLLER
		_set_family(event.device)
	if now != method:
		method = now
		method_changed.emit()


func _set_family(device: int) -> void:
	var joy := Input.get_joy_name(device).to_lower()
	if "xbox" in joy or "xinput" in joy:
		pad_family = "xbox"
	elif "playstation" in joy or "dualshock" in joy or "dualsense" in joy or "ps4" in joy or "ps5" in joy:
		pad_family = "playstation"
	else:
		pad_family = "nintendo"


## The button or key for an action on the current input method. "tools" names the
## pair of tool-switch buttons.
func label(action: String) -> String:
	if action == "tools":
		return "%s / %s" % [label("tool_prev"), label("tool_next")] if method == Method.KEYBOARD else "D-pad"
	for ev in InputMap.action_get_events(action):
		if method == Method.KEYBOARD and ev is InputEventKey:
			return _key_name(ev)
		if method == Method.CONTROLLER and ev is InputEventJoypadMotion:
			return "R stick" if ev.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y] else "L stick"
		if method == Method.CONTROLLER and ev is InputEventJoypadButton:
			var names: Dictionary = FACE_NAMES[pad_family]
			return names.get(ev.button_index, OTHER_BUTTONS.get(ev.button_index, "?"))
	return "?"


## Replaces {action} placeholders with button names.
func fill(template: String) -> String:
	var out := template
	var start := out.find("{")
	while start >= 0:
		var end := out.find("}", start)
		if end < 0:
			break
		var action := out.substr(start + 1, end - start - 1)
		var name := label(action) if InputMap.has_action(action) or action == "tools" else action
		out = out.substr(0, start) + name + out.substr(end + 1)
		start = out.find("{", start + name.length())
	return out


func _key_name(ev: InputEventKey) -> String:
	var code := ev.physical_keycode
	if code == KEY_NONE:
		code = ev.keycode
	# The key printed on this keyboard layout (headless runs can't ask).
	var local := KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(code)
	var name := OS.get_keycode_string(local if local != KEY_NONE else code)
	return {"Escape": "Esc", "Shift": "Shift", "Space": "Space", "BackSpace": "Backspace"}.get(name, name)


## Keeps a label's text filled in from a template, now and whenever the method changes.
func bind_label(target: Label, template: String) -> void:
	target.text = fill(template)
	method_changed.connect(func(): if is_instance_valid(target): target.text = fill(template))
