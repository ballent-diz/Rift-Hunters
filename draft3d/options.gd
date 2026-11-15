class_name DraftOptions
extends Control
## Fenêtre d'options de la version 3D (menu principal et pause) : langue, volumes, plein écran, synchronisation
## verticale, rappel des commandes. Lit et écrit `Settings` (user://settings.json), aucune règle de jeu.
## Navigable au clavier et à la manette : haut/bas entre les lignes, gauche/droite sur les curseurs, Échap ou B ferme.

signal closed
signal language_changed

var first: Control
var close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dimmer(0.6))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color("8a6a9e"), Color(0.05, 0.045, 0.09, 0.97)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(UiKit.title(tr("MENU_OPTIONS"), 32, DraftMenu.GOLD))
	var rows: Array[Control] = []
	var language: Button = UiKit.button(tr("OPTIONS_LANGUAGE") % tr("LANGUAGE_NAME"), _next_language, 560)
	language.name = "Language"
	rows.append(language)
	rows.append(_slider("Master", tr("OPTIONS_MASTER_VOLUME"), Settings.master_volume,
		func(v: float) -> void: Settings.master_volume = v))
	rows.append(_slider("Music", tr("OPTIONS_MUSIC_VOLUME"), Settings.music_volume,
		func(v: float) -> void: Settings.music_volume = v))
	rows.append(_slider("Sfx", tr("OPTIONS_SFX_VOLUME"), Settings.sfx_volume,
		func(v: float) -> void: Settings.sfx_volume = v))
	rows.append(_toggle("Fullscreen", tr("OPTIONS_FULLSCREEN"), Settings.fullscreen,
		func(on: bool) -> void: Settings.fullscreen = on))
	rows.append(_toggle("Vsync", tr("OPTIONS_VSYNC"), Settings.vsync, func(on: bool) -> void: Settings.vsync = on))
	var keys: Button = UiKit.button(tr("OPTIONS3D_CONTROLS"), _open_controls, 560)
	keys.name = "Keys"
	rows.append(keys)
	for row: Control in rows:
		box.add_child(row.get_parent() if row.get_parent() != null else row)
	box.add_child(UiKit.title(tr("MENU3D_CONTROLS_TITLE"), 20, DraftMenu.GOLD))
	var controls: Label = UiKit.label(tr("MENU3D_CONTROLS_LIST"), 16, UiKit.MUTED)
	controls.name = "Controls"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.custom_minimum_size.x = 560
	box.add_child(controls)
	close_button = UiKit.button(tr("MENU_CLOSE"), func() -> void: closed.emit(), 220)
	close_button.name = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(close_button)
	rows.append(close_button)
	for index: int in rows.size():
		var previous: Control = rows[posmod(index - 1, rows.size())]
		var next: Control = rows[(index + 1) % rows.size()]
		rows[index].focus_neighbor_top = rows[index].get_path_to(previous)
		rows[index].focus_previous = rows[index].get_path_to(previous)
		rows[index].focus_neighbor_bottom = rows[index].get_path_to(next)
		rows[index].focus_next = rows[index].get_path_to(next)
	first = language
	first.grab_focus.call_deferred()


## Touches et visée (DraftControls) par-dessus les options ; le focus revient au bouton à la fermeture.
func _open_controls() -> void:
	var controls := DraftControls.new()
	controls.name = "ControlsWindow"
	add_child(controls)
	controls.closed.connect(func() -> void:
		controls.queue_free()
		(find_child("Keys", true, false) as Control).grab_focus.call_deferred())


func _unhandled_input(event: InputEvent) -> void:
	if get_node_or_null("ControlsWindow") is DraftControls:
		return
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _next_language() -> void:
	var locales: Array[String] = Settings.SUPPORTED_LOCALES
	Settings.set_locale(locales[(locales.find(Settings.locale) + 1) % locales.size()])
	language_changed.emit()


## Ligne « libellé + curseur » ; le curseur est renvoyé (c'est lui qui prend le focus).
func _slider(id: String, text: String, value: float, setter: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label: Label = UiKit.label(text, 17)
	label.custom_minimum_size.x = 240
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = id
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		Settings.apply()
		Settings.save_settings())
	row.add_child(slider)
	return slider


func _toggle(id: String, text: String, value: bool, setter: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.name = id
	check.text = text
	check.button_pressed = value
	check.add_theme_font_size_override("font_size", 17)
	check.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		Settings.apply()
		Settings.save_settings())
	return check
