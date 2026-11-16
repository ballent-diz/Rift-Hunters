class_name DraftArsenalPanel
extends Control
## Arsenal de l'expédition (docs/design/GAMEPLAY_V2_ARCHITECTURE.md) : emplacements équipés et réserve.
## Deux usages :
## - `replace_for(id)` : un sort vient d'être acquis alors que les cases sont pleines ; le joueur choisit la case qu'il
##   remplace (l'ancien sort part en réserve) ou garde le nouveau en réserve ;
## - `manage()` : Pause → Arsenal ; choisir un sort (case ou réserve) puis la case où le placer (échange).
## Toute règle passe par `DraftSpells.equip` : recharges conservées par sort, aucun doublon. Clavier, souris, manette.

signal closed

const GOLD := Color("ffd9a0")
const INK := Color("f0e8d7")
const DIM := Color("b9bccb")

var spells: DraftSpells
## Sort à placer (mode remplacement, ou sort choisi en premier dans l'arsenal).
var selected: StringName = &""
var replacing: bool = false
var _box: VBoxContainer


func _ready() -> void:
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
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	margin.add_child(_box)


func replace_for(p_spells: DraftSpells, id: StringName) -> void:
	spells = p_spells
	selected = id
	replacing = true
	_fill.call_deferred()


func manage(p_spells: DraftSpells) -> void:
	spells = p_spells
	selected = &""
	replacing = false
	_fill.call_deferred()


func _fill() -> void:
	for child: Node in _box.get_children():
		child.queue_free()
	var buttons: Array[Button] = []
	var title: String = tr("ARSENAL3D_REPLACE_TITLE") % _name(selected) if replacing else tr("ARSENAL3D_TITLE")
	_box.add_child(UiKit.title(title, 26, GOLD))
	var hint: String = "ARSENAL3D_REPLACE_HINT" if replacing else (
		"ARSENAL3D_PLACE_HINT" if selected != &"" else "ARSENAL3D_PICK_HINT")
	var hint_label: Label = UiKit.label(tr(hint) % _name(selected) if selected != &"" else tr(hint), 15, DIM)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size.x = 620
	_box.add_child(hint_label)
	_box.add_child(UiKit.label(tr("ARSENAL3D_EQUIPPED"), 17, GOLD))
	for i: int in spells.slots.size():
		var data: SpellData = spells.slots[i]
		var text: String = "%s  ·  %s" % [InputSetup.key_label(DraftSpells.ACTIONS[i]),
			_describe(data.id) if data != null else tr("ARSENAL3D_EMPTY")]
		var slot: int = i
		var button: Button = _button("Slot%d" % (i + 1), text, data, func() -> void: _on_slot(slot))
		buttons.append(button)
	_box.add_child(UiKit.label(tr("ARSENAL3D_RESERVE"), 17, GOLD))
	var reserve: Array[StringName] = spells.reserve()
	if reserve.is_empty():
		_box.add_child(UiKit.label(tr("ARSENAL3D_RESERVE_EMPTY"), 14, DIM))
	for id: StringName in reserve:
		if replacing and id == selected:
			continue
		var reserved: StringName = id
		buttons.append(_button("Reserve_" + String(id), _describe(id), DraftSpells.spell(id),
			func() -> void: _on_reserve(reserved)))
	_combos()
	var close_key: String = "ARSENAL3D_KEEP_IN_RESERVE" if replacing else "MENU_CLOSE"
	var close: Button = UiKit.button(tr(close_key), func() -> void: closed.emit(), 320)
	close.name = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(close)
	buttons.append(close)
	DraftMenu._chain_focus(buttons)
	buttons[0].grab_focus.call_deferred()


## Combos dont les deux sorts sont possédés : actifs s'ils sont équipés tous les deux (docs/design/GAMEPLAY_COMBOS_2P5D.md).
func _combos() -> void:
	var lines: Array[String] = []
	for combo: StringName in DraftCombos.RECIPES:
		var recipe: Array = DraftCombos.RECIPES[combo]
		if not (spells.owns(recipe[0]) and spells.owns(recipe[1])):
			continue
		var active: bool = spells.has_spell(recipe[0]) and spells.has_spell(recipe[1])
		var key: String = DraftCombos.NAME_KEYS[combo]
		lines.append("%s %s : %s" % ["◆" if active else "◇", tr(key), tr(key.replace("_NAME", "_DESC"))])
	if lines.is_empty():
		return
	_box.add_child(UiKit.label(tr("ARSENAL3D_COMBOS"), 17, GOLD))
	var label: Label = UiKit.label("\n".join(lines), 13, INK)
	label.name = "Combos"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 640
	_box.add_child(label)


func _button(id: String, text: String, data: SpellData, callback: Callable) -> Button:
	var button: Button = UiKit.button(text, callback, 620)
	button.name = id
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = DraftSpellBar.icon_for(data)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 34)
	if data != null and data.id == selected:
		button.add_theme_color_override("font_color", GOLD)
	button.mouse_entered.connect(button.grab_focus)
	_box.add_child(button)
	return button


## Nom, mutations et recharge restante d'un sort possédé.
func _describe(id: StringName) -> String:
	var text: String = _name(id)
	var mutations: PackedStringArray = []
	for card_name: String in spells.mutation_names(id):
		mutations.append(tr(card_name))
	if not mutations.is_empty():
		text += "  (%s)" % ", ".join(mutations)
	var left: float = spells.cooldown_left(id)
	if left > 0.05:
		text += "  ·  %.1f s" % left
	return text


func _name(id: StringName) -> String:
	var data: SpellData = DraftSpells.spell(id)
	return tr(data.name_key) if data != null else ""


func _on_slot(slot: int) -> void:
	if selected != &"":
		spells.equip(selected, slot)
		if replacing:
			closed.emit()
			return
		selected = &""
	elif spells.slots[slot] != null:
		selected = spells.slots[slot].id
	_fill()


func _on_reserve(id: StringName) -> void:
	selected = id
	_fill()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if selected != &"" and not replacing:
			selected = &""
			_fill()
		else:
			closed.emit()
