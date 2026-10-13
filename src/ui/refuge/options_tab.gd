extends RefugeTab
## Options : langue, volumes, plein écran, lisibilité. Informations de sauvegarde.

func title_key() -> String:
	return "TAB_OPTIONS"


func refresh() -> void:
	var box: VBoxContainer = scroll_box(10)
	box.add_child(UiKit.button(tr("OPTIONS_LANGUAGE") % tr("LANGUAGE_NAME"), func() -> void:
		Settings.set_locale("en" if Settings.locale == "fr" else "fr"), 360))
	box.add_child(_slider(tr("OPTIONS_MASTER_VOLUME"), Settings.master_volume,
			func(v: float) -> void: Settings.master_volume = v))
	box.add_child(_slider(tr("OPTIONS_MUSIC_VOLUME"), Settings.music_volume, func(v: float) -> void: Settings.music_volume = v))
	box.add_child(_slider(tr("OPTIONS_SFX_VOLUME"), Settings.sfx_volume, func(v: float) -> void: Settings.sfx_volume = v))
	box.add_child(_toggle(tr("OPTIONS_FULLSCREEN"), Settings.fullscreen, func(on: bool) -> void: Settings.fullscreen = on))
	box.add_child(_toggle(tr("OPTIONS_DAMAGE_NUMBERS") % "", Settings.damage_numbers,
			func(on: bool) -> void: Settings.damage_numbers = on))
	box.add_child(_toggle(tr("OPTIONS_SCREEN_SHAKE") % "", Settings.screen_shake,
			func(on: bool) -> void: Settings.screen_shake = on))
	box.add_child(_toggle(tr("OPTIONS_VSYNC"), Settings.vsync, func(on: bool) -> void: Settings.vsync = on))
	box.add_child(_toggle(tr("OPTIONS_REDUCE_FLASHES") % "", Settings.reduce_flashes, func(on: bool) -> void:
		Settings.reduce_flashes = on))
	box.add_child(_toggle(tr("OPTIONS_SHOW_FPS"), Settings.show_fps, func(on: bool) -> void: Settings.show_fps = on))
	box.add_child(UiKit.wrapped(tr("OPTIONS_CONTROLS"), 14, UiKit.MUTED))
	box.add_child(UiKit.wrapped(tr("OPTIONS_SAVE_INFO") % [ProjectSettings.globalize_path(Profile.path),
		SaveMigrations.CURRENT_VERSION], 13, UiKit.MUTED))


func _slider(text: String, value: float, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label: Label = UiKit.label(text, 17)
	label.custom_minimum_size.x = 260
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size.x = 320
	slider.drag_ended.connect(func(_changed: bool) -> void:
		setter.call(slider.value)
		Settings.apply()
		Settings.save_settings())
	row.add_child(slider)
	return row


func _toggle(text: String, value: bool, setter: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text.trim_suffix(" : ").trim_suffix(": ")
	check.button_pressed = value
	check.add_theme_font_size_override("font_size", 17)
	check.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		Settings.apply()
		Settings.save_settings())
	return check
