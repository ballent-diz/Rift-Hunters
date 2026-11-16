class_name DraftChoicePanel
extends Control
## Petite fenêtre de choix (remplacement d'une mutation) : un titre, une aide, une ligne par option et un bouton
## d'annulation. `picked` renvoie l'indice choisi, -1 pour annuler. Clavier, souris, manette.

signal picked(index: int)


func setup(title: String, hint: String, options: Array[String], cancel: String) -> DraftChoicePanel:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color("8a6a9e"), Color(0.05, 0.045, 0.09, 0.97)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(UiKit.title(title, 24, DraftArsenalPanel.GOLD))
	var help: Label = UiKit.label(hint, 15, DraftArsenalPanel.DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 560
	box.add_child(help)
	var buttons: Array[Button] = []
	for i: int in options.size():
		var index: int = i
		var button: Button = UiKit.button(options[i], func() -> void: picked.emit(index), 560)
		button.name = "Option%d" % (i + 1)
		button.mouse_entered.connect(button.grab_focus)
		box.add_child(button)
		buttons.append(button)
	var back: Button = UiKit.button(cancel, func() -> void: picked.emit(-1), 320)
	back.name = "Cancel"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	buttons.append(back)
	DraftMenu._chain_focus(buttons)
	buttons[0].grab_focus.call_deferred()
	return self


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		picked.emit(-1)
