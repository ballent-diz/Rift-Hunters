class_name PausePanel
extends Control
## Menu pause : reprendre, options (langue, chiffres de dégâts, secousses), abandonner.

signal abandon_requested

var ctx: RunContext
var blocked: bool = false
var _box: VBoxContainer


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UiKit.dimmer(0.8))
	_box = MenuSkin.modal_box(self, 12, Vector2(680, 640))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not blocked:
		if visible:
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	_build()


func close() -> void:
	visible = false
	get_tree().paused = false


func _build() -> void:
	UiKit.clear(_box)
	_box.add_child(UiKit.title(tr("PAUSE_TITLE"), 36, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var resume: Button = UiKit.button(tr("PAUSE_RESUME"), close, 320)
	_box.add_child(resume)
	resume.grab_focus.call_deferred()
	_box.add_child(UiKit.button(tr("OPTIONS_LANGUAGE") % tr("LANGUAGE_NAME"), _toggle_language, 320))
	var numbers: String = tr("OPTIONS_ON") if Settings.damage_numbers else tr("OPTIONS_OFF")
	_box.add_child(UiKit.button(tr("OPTIONS_DAMAGE_NUMBERS") % numbers, _toggle_numbers, 320))
	var shake: String = tr("OPTIONS_ON") if Settings.screen_shake else tr("OPTIONS_OFF")
	_box.add_child(UiKit.button(tr("OPTIONS_SCREEN_SHAKE") % shake, _toggle_shake, 320))
	var flashes: String = tr("OPTIONS_ON") if Settings.reduce_flashes else tr("OPTIONS_OFF")
	_box.add_child(UiKit.button(tr("OPTIONS_REDUCE_FLASHES") % flashes, func() -> void:
		Settings.reduce_flashes = not Settings.reduce_flashes
		Settings.save_settings()
		_build(), 320))
	_box.add_child(UiKit.button(tr("PAUSE_ABANDON"), func() -> void:
		close()
		abandon_requested.emit(), 320))
	var controls: Label = UiKit.wrapped(tr("PAUSE_CONTROLS"), 14, UiKit.MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(controls)


func _toggle_language() -> void:
	Settings.set_locale("en" if Settings.locale == "fr" else "fr")
	_build()


func _toggle_numbers() -> void:
	Settings.damage_numbers = not Settings.damage_numbers
	Settings.save_settings()
	_build()


func _toggle_shake() -> void:
	Settings.screen_shake = not Settings.screen_shake
	Settings.save_settings()
	_build()
