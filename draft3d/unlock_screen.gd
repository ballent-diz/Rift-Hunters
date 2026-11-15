class_name DraftUnlockScreen
extends Control
## Écran « Déblocages » de la version 3D (docs/design/DEBLOCAGE_V2.md) : Fragments de faille disponibles, sorts et
## leurs variantes à débloquer, choix des 2 sorts de départ. Aucune règle ici : tout passe par `DraftUnlocks`
## (draft3d/unlocks.gd, session « Gameplay »), chargé dynamiquement pour que l'écran compile avant son arrivée.
## Navigable à la souris, au clavier et à la manette ; Échap ou B ferme.

signal closed

const UNLOCKS_SCRIPT := "res://draft3d/unlocks.gd"
const ICON_SIZE := 44.0

## Objet `DraftUnlocks` (ou un double dans les essais) : appels par nom, sans dépendance de compilation.
var unlocks: Object
var back_button: Button
var _list: VBoxContainer
var _currency: Label
var _starting: Label
var _focus_id: String = ""


## État des déblocages, ou null tant que `DraftUnlocks` n'existe pas dans le dépôt.
static func load_unlocks() -> Object:
	if not ResourceLoader.exists(UNLOCKS_SCRIPT):
		return null
	var script: GDScript = load(UNLOCKS_SCRIPT)
	return script.call(&"load") if script != null and script.can_instantiate() else null


## Fragments gagnés à la dernière partie (écran de fin) ; -1 sans système de déblocage.
static func last_gain() -> int:
	var state: Object = load_unlocks()
	return int(state.call(&"last_gain")) if state != null else -1


func setup(state: Object) -> void:
	unlocks = state


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(Color("8a6a9e"), Color(0.05, 0.045, 0.09, 0.97)))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.06
	panel.anchor_bottom = 0.94
	panel.offset_left = -470
	panel.offset_right = 470
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title: Label = UiKit.title(tr("MENU3D_UNLOCKS"), 32, DraftMenu.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_currency = UiKit.label("", 22, DraftMenu.GOLD)
	_currency.name = "Currency"
	header.add_child(_currency)
	_starting = UiKit.label("", 17, DraftMenu.INK)
	_starting.name = "Starting"
	_starting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_starting)
	box.add_child(UiKit.wrapped(tr("UNLOCK3D_HINT"), 14, UiKit.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	back_button = UiKit.button(tr("MENU3D_BACK"), func() -> void: closed.emit(), 220)
	back_button.name = "Back"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back_button)
	refresh()


## Reconstruit les lignes ; le focus revient sur l'élément qui l'avait (achat au clavier ou à la manette).
func refresh() -> void:
	UiKit.clear(_list)
	var focusable: Array[Control] = []
	if unlocks == null:
		_currency.text = ""
		_starting.text = ""
		_list.add_child(UiKit.wrapped(tr("UNLOCK3D_UNAVAILABLE"), 16, UiKit.MUTED))
	else:
		_currency.text = tr("UNLOCK3D_CURRENCY") % int(unlocks.call(&"currency"))
		var starting: Array = unlocks.call(&"starting_spells")
		var names: PackedStringArray = []
		for id: Variant in starting:
			var data: SpellData = DraftSpells.spell(StringName(id))
			names.append(tr(data.name_key) if data != null else str(id))
		_starting.text = tr("UNLOCK3D_STARTING") % " · ".join(names)
		for entry: Dictionary in unlocks.call(&"entries"):
			focusable.append_array(_row(entry, starting))
	focusable.append(back_button)
	for index: int in focusable.size():
		var previous: Control = focusable[posmod(index - 1, focusable.size())]
		var next: Control = focusable[(index + 1) % focusable.size()]
		focusable[index].focus_neighbor_top = focusable[index].get_path_to(previous)
		focusable[index].focus_previous = focusable[index].get_path_to(previous)
		focusable[index].focus_neighbor_bottom = focusable[index].get_path_to(next)
		focusable[index].focus_next = focusable[index].get_path_to(next)
	var target: Control = back_button
	for control: Control in focusable:
		if _focus_id != "" and control.name == _focus_id:
			target = control
	if _focus_id == "" and focusable.size() > 1:
		target = focusable[0]
	target.grab_focus.call_deferred()


## Une ligne : icône, nom, description, état ; boutons d'achat et de départ (renvoyés pour la navigation).
func _row(entry: Dictionary, starting: Array) -> Array[Control]:
	var buttons: Array[Control] = []
	var id: String = str(entry.get("id", ""))
	var variant: bool = str(entry.get("kind", "spell")) == "variant"
	var unlocked: bool = bool(entry.get("unlocked", false))
	var available: bool = bool(entry.get("available", true))
	var cost: int = int(entry.get("cost", 0))
	var card := PanelContainer.new()
	card.name = "Row_" + id
	var color: Color = Color(0.11, 0.12, 0.2, 0.95) if unlocked else Color(0.07, 0.07, 0.11, 0.95)
	card.add_theme_stylebox_override("panel", UiKit.panel_box(
		DraftMenu.GOLD.darkened(0.3) if unlocked else UiKit.BORDER.darkened(0.3), color))
	_list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	if variant:
		var indent := Control.new()
		indent.custom_minimum_size.x = 40
		row.add_child(indent)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2.ONE * (ICON_SIZE * (0.7 if variant else 1.0))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = spell_icon(StringName(str(entry.get("spell_id", id))))
	icon.modulate = Color.WHITE if unlocked else Color(0.6, 0.6, 0.7)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title: String = tr(str(entry.get("name_key", id)))
	text.add_child(UiKit.label(title, 17 if variant else 19, DraftMenu.INK if unlocked else UiKit.MUTED))
	var desc: Label = UiKit.wrapped(tr(str(entry.get("desc_key", ""))), 13, UiKit.MUTED)
	text.add_child(desc)
	if unlocked:
		var state: Label = UiKit.label(tr("UNLOCK3D_UNLOCKED"), 15, DraftMenu.GOLD)
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(state)
		if not variant:
			var chosen: bool = starting.has(StringName(id)) or starting.has(id)
			var start: Button = UiKit.button(tr("UNLOCK3D_AT_START") if chosen else tr("UNLOCK3D_SET_START"),
				func() -> void: _take_at_start(id), 200)
			start.name = "Start_" + id
			start.toggle_mode = true
			start.button_pressed = chosen
			start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(start)
			buttons.append(start)
	else:
		var label: String = tr("UNLOCK3D_BUY") % cost if available else tr("UNLOCK3D_NEEDS_SPELL")
		var buy: Button = UiKit.button(label, func() -> void: _buy(id), 200)
		buy.name = "Buy_" + id
		buy.disabled = not available or cost > int(unlocks.call(&"currency"))
		buy.focus_mode = Control.FOCUS_ALL
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(buy)
		buttons.append(buy)
	for button: Control in buttons:
		button.mouse_entered.connect(button.grab_focus)
	return buttons


func _buy(id: String) -> void:
	_focus_id = "Start_" + id
	if bool(unlocks.call(&"unlock", StringName(id))):
		Audio.play_sfx(&"ui_click")
	else:
		_focus_id = "Buy_" + id
	refresh()


## Prendre un sort au départ : il remplace le plus ancien des deux (sélection d'interface ; la règle des 2 sorts
## débloqués est vérifiée par `DraftUnlocks.set_starting_spells`).
func _take_at_start(id: String) -> void:
	_focus_id = "Start_" + id
	var current: Array = unlocks.call(&"starting_spells")
	if current.has(StringName(id)) or current.has(id):
		refresh()
		return
	var wanted: Array[StringName] = []
	if current.size() >= 2:
		wanted.append(StringName(current[1]))
	elif current.size() == 1:
		wanted.append(StringName(current[0]))
	wanted.append(StringName(id))
	unlocks.call(&"set_starting_spells", wanted)
	refresh()


## Icône du sort, la même que la barre de sorts et les cartes du choix de niveau (`DraftSpellBar.icon_for`).
static func spell_icon(spell_id: StringName) -> Texture2D:
	return DraftSpellBar.icon_for(DraftSpells.spell(spell_id))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
