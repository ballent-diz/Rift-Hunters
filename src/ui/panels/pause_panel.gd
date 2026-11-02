class_name PausePanel
extends Control
## Menu pause : reprendre, options (langue, chiffres de dégâts, secousses), abandonner.

signal abandon_requested

var ctx: RunContext
var blocked: bool = false
## Aide-mémoire des touches affiché (F1 l'ouvre directement).
var show_keys: bool = false
var _box: VBoxContainer


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UiKit.dimmer(0.8))
	_box = MenuSkin.modal_box(self, 12, Vector2(720, 860))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F1 \
			and not blocked:
		show_keys = not (visible and show_keys)
		if visible:
			_build()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
		return
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
	show_keys = false
	get_tree().paused = false


func _build() -> void:
	UiKit.clear(_box)
	_box.add_child(UiKit.title(tr("KEY_GUIDE_TITLE") if show_keys else tr("PAUSE_TITLE"), 36, UiKit.ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER))
	var resume: Button = UiKit.button(tr("PAUSE_RESUME"), close, 320)
	_box.add_child(resume)
	resume.grab_focus.call_deferred()
	# Aide-mémoire : il remplace les réglages, pour tenir sans défilement.
	if show_keys:
		var guide: GridContainer = KeyGuide.build()
		guide.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(guide)
		_box.add_child(_keys_button())
		return
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
	_box.add_child(UiKit.button(tr("OPTIONS_MINIMAP") % tr("MINIMAP_SIZE_%d" % Settings.minimap_size), func() -> void:
		Settings.minimap_size = (Settings.minimap_size + 1) % 4
		Settings.save_settings()
		_build(), 320))
	_box.add_child(UiKit.button(tr("PAUSE_ABANDON"), func() -> void:
		close()
		abandon_requested.emit(), 320))
	_box.add_child(_keys_button())


func _keys_button() -> Button:
	var keys: Button = UiKit.button(tr("KEY_GUIDE_HIDE") if show_keys else tr("KEY_GUIDE_OPEN"), func() -> void:
		show_keys = not show_keys
		_build(), 320)
	keys.name = "KeyGuideButton"
	return keys


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
