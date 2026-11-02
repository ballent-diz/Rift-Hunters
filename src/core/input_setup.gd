class_name InputSetup
extends RefCounted
## Actions d'entrée créées au démarrage (touches physiques : AZERTY et QWERTY). Les touches du clavier sont
## reconfigurables (Settings.bindings) ; la manette garde sa disposition.

## Version des touches par défaut : des touches enregistrées avec une version plus ancienne sont oubliées.
const BINDINGS_VERSION := 2
const ACTIONS := {
	# Les deux mains au clavier (décision du 24 octobre 2026) : ZQSD pour marcher, flèches pour les sorts du
	# Chasseur, A, E, F pour les Échos (touches physiques Q, E, F en AZERTY).
	&"move_up": [KEY_W],
	&"move_down": [KEY_S],
	&"move_left": [KEY_A],
	&"move_right": [KEY_D],
	&"dash": [KEY_SPACE, KEY_SHIFT],
	&"spell_1": [KEY_RIGHT],
	&"spell_2": [KEY_UP],
	&"spell_3": [KEY_LEFT],
	&"spell_4": [KEY_DOWN],
	&"technique_1": [KEY_Q, KEY_1],
	&"technique_2": [KEY_E, KEY_2],
	&"technique_3": [KEY_F, KEY_3],
	&"open_choices": [KEY_TAB],
	&"toggle_map": [KEY_M],
	&"pause": [KEY_ESCAPE, KEY_P],
}


## Second mode « clavier + souris » (Settings.control_scheme = "mouse") : visée au curseur, sorts sur A, E, R, F
## (touches physiques Q, E, R, F en AZERTY) et clic gauche, Échos sur 1, 2, 3, marche ZQSD ou flèches.
const MOUSE_ACTIONS := {
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"dash": [KEY_SPACE, KEY_SHIFT],
	&"spell_1": [KEY_Q],
	&"spell_2": [KEY_E],
	&"spell_3": [KEY_R],
	&"spell_4": [KEY_F],
	&"technique_1": [KEY_1, KEY_KP_1],
	&"technique_2": [KEY_2, KEY_KP_2],
	&"technique_3": [KEY_3, KEY_KP_3],
	&"open_choices": [KEY_TAB],
	&"toggle_map": [KEY_M],
	&"pause": [KEY_ESCAPE, KEY_P],
}

## Actions reconfigurables au clavier, dans l'ordre affiché par les options.
const REBINDABLE: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right", &"dash",
	&"spell_1", &"spell_2", &"spell_3", &"spell_4", &"technique_1", &"technique_2", &"technique_3",
	&"open_choices", &"toggle_map"]

## Libellés courts des flèches (sorts du Chasseur).
const ARROWS := {KEY_RIGHT: "→", KEY_UP: "↑", KEY_LEFT: "←", KEY_DOWN: "↓"}

const JOY_BUTTONS := {
	&"dash": [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER],
	&"technique_1": [JOY_BUTTON_X],
	&"technique_2": [JOY_BUTTON_Y],
	&"technique_3": [JOY_BUTTON_B],
	&"focus_order": [JOY_BUTTON_LEFT_SHOULDER],
	&"spell_3": [JOY_BUTTON_DPAD_UP],
	&"spell_4": [JOY_BUTTON_DPAD_RIGHT],
	&"open_choices": [JOY_BUTTON_BACK],
	&"pause": [JOY_BUTTON_START],
}
const JOY_AXES := {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	&"spell_1": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	&"spell_2": [JOY_AXIS_TRIGGER_LEFT, 1.0],
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


## Touches physiques du clavier d'une action (d'après InputMap).
static func keys_of(action: StringName) -> Array[int]:
	var keys: Array[int] = []
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append(int((event as InputEventKey).physical_keycode))
	return keys


## Remplace les touches du clavier d'une action (les événements manette et souris sont conservés).
static func set_keys(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for keycode: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode as Key
		InputMap.action_add_event(action, event)


## Touches par défaut du mode de contrôle (« keyboard » : tout au clavier ; « mouse » : clavier + souris).
static func defaults(scheme: String) -> Dictionary:
	return MOUSE_ACTIONS if scheme == "mouse" else ACTIONS


## Applique des touches personnalisées {action: [touches physiques]} ; les actions absentes reprennent les défauts du
## mode de contrôle. En mode souris, le clic gauche lance aussi le premier sort.
static func apply_bindings(bindings: Dictionary, scheme: String = "keyboard") -> void:
	var base: Dictionary = defaults(scheme)
	for action: StringName in REBINDABLE:
		var keys: Array[int] = []
		for value: Variant in bindings.get(String(action), base[action]):
			keys.append(int(value))
		set_keys(action, keys)
	_set_click(&"spell_1", MOUSE_BUTTON_LEFT, scheme == "mouse")


static func _set_click(action: StringName, button: MouseButton, enabled: bool) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			InputMap.action_erase_event(action, event)
	if enabled:
		var click := InputEventMouseButton.new()
		click.button_index = button
		InputMap.action_add_event(action, click)


## Nom affiché de la première touche d'une action, selon la disposition du clavier (« A » en AZERTY pour Q).
static func key_label(action: StringName) -> String:
	var keys: Array[int] = keys_of(action)
	if keys.is_empty():
		return "—"
	var label: Key = keys[0] as Key
	if ARROWS.has(label):
		return ARROWS[label]
	if DisplayServer.get_name() != "headless":
		var mapped: Key = DisplayServer.keyboard_get_keycode_from_physical(label)
		label = mapped if mapped != KEY_NONE else label
	return OS.get_keycode_string(label)
