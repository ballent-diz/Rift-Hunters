class_name InputSetup
extends RefCounted
## Actions d'entrée créées au démarrage (touches physiques : AZERTY et QWERTY).

const ACTIONS := {
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"dash": [KEY_SPACE, KEY_SHIFT],
	&"technique_1": [KEY_1, KEY_KP_1],
	&"technique_2": [KEY_2, KEY_KP_2],
	&"technique_3": [KEY_3, KEY_KP_3],
	&"pause": [KEY_ESCAPE, KEY_P],
}


const JOY_BUTTONS := {
	&"dash": [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER],
	&"technique_1": [JOY_BUTTON_X],
	&"technique_2": [JOY_BUTTON_Y],
	&"technique_3": [JOY_BUTTON_B],
	&"focus_order": [JOY_BUTTON_LEFT_SHOULDER],
	&"pause": [JOY_BUTTON_START],
}
const JOY_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}


static func ensure_actions() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for keycode: int in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)
	if not InputMap.has_action(&"focus_order"):
		InputMap.add_action(&"focus_order")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(&"focus_order", mouse)
	for action: StringName in JOY_BUTTONS:
		for button: int in JOY_BUTTONS[action]:
			var joy := InputEventJoypadButton.new()
			joy.button_index = button as JoyButton
			InputMap.action_add_event(action, joy)
	for action: StringName in JOY_AXES:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXES[action][0] as JoyAxis
		motion.axis_value = float(JOY_AXES[action][1])
		InputMap.action_add_event(action, motion)
