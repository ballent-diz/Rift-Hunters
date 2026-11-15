class_name DraftControls
extends Control
## Fenêtre « Touches et visée » de la version 3D (ouverte depuis les options) : mode de contrôle (clavier seul ou
## clavier + souris), aperçu des sorts, touches reconfigurables du déplacement, de la Ruée et des quatre sorts
## (`KeyBindButton`, `Settings.bindings`), retour aux touches par défaut. Aucune règle de jeu.

signal closed

const ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right", &"dash",
	&"spell_1", &"spell_2", &"spell_3", &"spell_4"]

var _box: VBoxContainer


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
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	margin.add_child(_box)
	_fill()


func _fill() -> void:
	for child: Node in _box.get_children():
		child.queue_free()
	_box.add_child(UiKit.title(tr("OPTIONS3D_CONTROLS"), 28, DraftMenu.GOLD))
	var scheme: Button = UiKit.button(tr("OPTIONS_CONTROL_SCHEME") % tr("CONTROL_SCHEME_" + Settings.control_scheme.to_upper()),
		func() -> void:
			Settings.set_control_scheme("keyboard" if Settings.control_scheme == "mouse" else "mouse")
			_fill(), 520)
	scheme.name = "ControlScheme"
	_box.add_child(scheme)
	var hint: Label = UiKit.label(tr("CONTROLS3D_%s_HINT" % Settings.control_scheme.to_upper()), 14, UiKit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 520
	_box.add_child(hint)
	var preview := CheckButton.new()
	preview.name = "SpellPreview"
	preview.text = tr("OPTIONS_SPELL_PREVIEW")
	preview.button_pressed = Settings.spell_preview
	preview.toggled.connect(func(on: bool) -> void:
		Settings.spell_preview = on
		Settings.save_settings())
	_box.add_child(preview)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for action: StringName in ACTIONS:
		var label: Label = UiKit.label(tr("ACTION_" + String(action).to_upper()), 16)
		label.custom_minimum_size.x = 200
		grid.add_child(label)
		var bind: KeyBindButton = KeyBindButton.new().setup(action)
		bind.name = String(action)
		grid.add_child(bind)
	_box.add_child(grid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.button(tr("OPTIONS_RESET_KEYS"), func() -> void:
		Settings.reset_bindings()
		_fill(), 250))
	var close: Button = UiKit.button(tr("MENU_CLOSE"), func() -> void: closed.emit(), 200)
	close.name = "Close"
	row.add_child(close)
	_box.add_child(row)
	scheme.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
