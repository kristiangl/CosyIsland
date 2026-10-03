class_name InputSetup
extends RefCounted
## Registers input actions in code so bindings are readable and versioned.
##
## Controller layout follows the Switch: A (right face) uses tools, B (bottom) runs and
## cancels, Y (left) picks up, X (top) opens the pockets. Godot names buttons by Xbox
## position, so Switch A is JOY_BUTTON_B and so on.

const NINTENDO_A := JOY_BUTTON_B
const NINTENDO_B := JOY_BUTTON_A
const NINTENDO_X := JOY_BUTTON_Y
const NINTENDO_Y := JOY_BUTTON_X


static func register() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("use", [KEY_E, KEY_SPACE], [NINTENDO_A])
	_action("run", [KEY_SHIFT], [NINTENDO_B])
	_action("pickup", [KEY_F], [NINTENDO_Y])
	_action("pockets", [KEY_TAB, KEY_I], [NINTENDO_X])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_action("tool_prev", [KEY_Z], [JOY_BUTTON_DPAD_LEFT])
	_action("tool_next", [KEY_C], [JOY_BUTTON_DPAD_RIGHT])
	_action("rotate", [KEY_R], [JOY_BUTTON_RIGHT_SHOULDER])
	_action("cancel", [KEY_ESCAPE, KEY_BACKSPACE], [NINTENDO_B])
	_action("map", [KEY_M], [JOY_BUTTON_BACK])
	# Menus with tabs (character creator, phone apps).
	_action("tab_prev", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER])
	_action("tab_next", [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER])

	# Menus use Nintendo confirm/back positions too.
	_replace_joy_button("ui_accept", JOY_BUTTON_A, NINTENDO_A)
	_replace_joy_button("ui_cancel", JOY_BUTTON_B, NINTENDO_B)


static func _action(name: String, keys: Array, buttons: Array, axes: Array = []) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(name, ev)
	for button in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		InputMap.action_add_event(name, ev)
	for axis in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axis[0]
		ev.axis_value = axis[1]
		InputMap.action_add_event(name, ev)


static func _replace_joy_button(action: String, old_button: JoyButton, new_button: JoyButton) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == old_button:
			InputMap.action_erase_event(action, ev)
	var added := InputEventJoypadButton.new()
	added.button_index = new_button
	InputMap.action_add_event(action, added)
