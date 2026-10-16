class_name KeyBindButton
extends Button
## Bouton d'options : affiche la touche d'une action ; un clic attend la prochaine touche pressée (Échap annule).

var action: StringName
var _waiting: bool = false


func setup(p_action: StringName) -> KeyBindButton:
	action = p_action
	custom_minimum_size = Vector2(150, 34)
	add_theme_font_size_override("font_size", 16)
	pressed.connect(func() -> void:
		_waiting = true
		_refresh())
	_refresh()
	return self


func _refresh() -> void:
	text = tr("OPTIONS_PRESS_KEY") if _waiting else InputSetup.key_label(action)


func _input(event: InputEvent) -> void:
	if not _waiting or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	get_viewport().set_input_as_handled()
	_waiting = false
	if key.physical_keycode != KEY_ESCAPE and key.physical_keycode != KEY_NONE:
		Settings.bind_key(action, int(key.physical_keycode))
	_refresh()
