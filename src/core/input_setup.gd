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
