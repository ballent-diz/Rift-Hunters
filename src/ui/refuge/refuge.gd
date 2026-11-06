class_name Refuge
extends Control
## Refuge : espace central entre les parties. Les onglets sont enregistrés dans TAB_SCRIPTS (modulaire).

const TAB_SCRIPTS: Array[String] = [
	"res://src/ui/refuge/expedition_tab.gd",
	"res://src/ui/refuge/shop_tab.gd",
	"res://src/ui/refuge/tree_tab.gd",
	"res://src/ui/refuge/echo_tab.gd",
	"res://src/ui/refuge/bestiary_tab.gd",
	"res://src/ui/refuge/lab_tab.gd",
	"res://src/ui/refuge/objectives_tab.gd",
	"res://src/ui/refuge/stats_tab.gd",
	"res://src/ui/refuge/options_tab.gd",
	"res://src/ui/refuge/journal_tab.gd",
]

## Navigation à deux niveaux (lot 3 des menus) : cinq groupes, puis leurs onglets. Les onglets restent dans `tabs`
## (même ordre que TAB_SCRIPTS) ; sa barre d'origine est masquée.
const GROUPS: Array = [
	["REFUGE_GROUP_EXPEDITION", ["expedition_tab"]],
	["REFUGE_GROUP_PROGRESSION", ["tree_tab", "echo_tab"]],
	["REFUGE_GROUP_COLLECTION", ["bestiary_tab", "journal_tab", "objectives_tab", "stats_tab"]],
	["REFUGE_GROUP_MARKET", ["shop_tab", "lab_tab"]],
	["REFUGE_GROUP_OPTIONS", ["options_tab"]],
]

## Le bandeau « Prochaine étape » accompagne les premières parties.
const GUIDE_RUNS := 5

## Marge du cadre et largeur maximale du refuge (centré au-delà).
const MARGIN := 28
const MAX_WIDTH := 1800.0
var tabs: TabContainer
var _currencies: HBoxContainer
var _warning: Label
var _next_step: PanelContainer
var _groups_row: HBoxContainer
var _subtabs_row: HBoxContainer
var _tab_nodes: Array[RefugeTab] = []
var _group_buttons: Array[Button] = []
var _sub_buttons: Array[Button] = []
## Dernier onglet ouvert dans chaque groupe (on y revient en recliquant le groupe).
var _last_in_group: Dictionary = {}


func _ready() -> void:
	theme = MenuSkin.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	MenuSkin.background(self)
	var margin := MarginContainer.new()
	margin.name = "Frame"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	resized.connect(_center_frame.bind(margin))
	_center_frame(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.045, 0.025, 0.08, 0.92), MenuSkin.LANTERN))
	root.add_child(banner)
	banner.add_child(header)
	header.add_child(UiKit.title(tr("REFUGE_TITLE"), 32, MenuSkin.PAPER))
	_currencies = HBoxContainer.new()
	_currencies.add_theme_constant_override("separation", 22)
	_currencies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_currencies)
	header.add_child(UiKit.button(tr("REFUGE_MAIN_MENU"), func() -> void: Router.goto_main_menu(), 200))
	_warning = UiKit.label("", 15, UiKit.DANGER)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_warning)
	_next_step = PanelContainer.new()
	_next_step.name = "NextStep"
	root.add_child(_next_step)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	root.add_child(nav)
	_groups_row = HBoxContainer.new()
	_groups_row.name = "Groups"
	_groups_row.add_theme_constant_override("separation", 8)
	nav.add_child(_groups_row)
	_subtabs_row = HBoxContainer.new()
	_subtabs_row.name = "SubTabs"
	_subtabs_row.add_theme_constant_override("separation", 6)
	nav.add_child(_subtabs_row)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tabs_visible = false
	root.add_child(tabs)
	for path: String in TAB_SCRIPTS:
		var tab: RefugeTab = (load(path) as GDScript).new()
		tabs.add_child(tab)
		tab.setup(self)
		_tab_nodes.append(tab)
	_build_nav()
	tabs.tab_changed.connect(func(_index: int) -> void:
		_refresh_nav()
		refresh_current())
	Profile.changed.connect(refresh_all)
	Settings.changed.connect(refresh_all)
	refresh_all()
	Audio.play_context("refuge")


func refresh_all() -> void:
	for i: int in _tab_nodes.size():
		tabs.set_tab_title(i, tr(_tab_nodes[i].title_key()) + ("  ●" if _tab_nodes[i].needs_attention() else ""))
	_refresh_currencies()
	_warning.text = Profile.status_message()
	_warning.visible = _warning.text != ""
	_refresh_nav()
	_refresh_next_step()
	refresh_current()


## Index de l'onglet d'un script (« tree_tab »), -1 s'il manque.
func tab_index(script_name: String) -> int:
	for i: int in TAB_SCRIPTS.size():
		if TAB_SCRIPTS[i].get_file().get_basename() == script_name:
			return i
	return -1


## Onglets ouverts, dans l'ordre de la navigation (groupe après groupe).
func visible_order() -> Array[int]:
	var order: Array[int] = []
	for group: Array in GROUPS:
		for script_name: String in group[1]:
			var index: int = tab_index(script_name)
			if index >= 0 and _tab_nodes[index].unlocked():
				order.append(index)
	return order


func select_tab(index: int) -> void:
	if index >= 0 and index < _tab_nodes.size() and _tab_nodes[index].unlocked():
		tabs.current_tab = index
	_refresh_nav()


func group_of(index: int) -> int:
	for g: int in GROUPS.size():
		if (GROUPS[g][1] as Array).has(TAB_SCRIPTS[index].get_file().get_basename()):
			return g
	return 0


## Boutons construits une fois (le focus de la manette tient d'un clic à l'autre) ; refresh n'ajuste que l'état.
## Écran très large (ultra-large) : le refuge garde au plus MAX_WIDTH de large, centré (retour de test).
func _center_frame(margin: MarginContainer) -> void:
	var side: int = maxi(MARGIN, int((size.x - MAX_WIDTH) * 0.5))
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)


func _build_nav() -> void:
	for g: int in GROUPS.size():
		var group_button: Button = _nav_button(20)
		group_button.name = "Group_%d" % g
		group_button.tooltip_text = tr("REFUGE_TAB_SHORTCUTS")
		group_button.pressed.connect(_open_group.bind(g))
		_groups_row.add_child(group_button)
		_group_buttons.append(group_button)
	for i: int in _tab_nodes.size():
		var sub: Button = _nav_button(16)
		sub.name = "Tab_%d" % i
		sub.pressed.connect(func() -> void:
			Audio.play_sfx(&"ui_click")
			select_tab(i))
		_subtabs_row.add_child(sub)
		_sub_buttons.append(sub)
	# Sous-onglets dans l'ordre de leur groupe.
	var order: int = 0
	for group: Array in GROUPS:
		for script_name: String in group[1]:
			_subtabs_row.move_child(_sub_buttons[tab_index(script_name)], order)
			order += 1


func _open_group(g: int) -> void:
	Audio.play_sfx(&"ui_click")
	var target: int = int(_last_in_group.get(g, -1))
	if target < 0 or not _tab_nodes[target].unlocked():
		var members: Array[int] = _members(g)
		target = members[0] if not members.is_empty() else 0
	select_tab(target)


## Onglets ouverts d'un groupe.
func _members(g: int) -> Array[int]:
	var members: Array[int] = []
	for script_name: String in GROUPS[g][1]:
		var index: int = tab_index(script_name)
		if index >= 0 and _tab_nodes[index].unlocked():
			members.append(index)
	return members


func _refresh_nav() -> void:
	if _group_buttons.is_empty():
		return
	var current_group: int = group_of(tabs.current_tab)
	_last_in_group[current_group] = tabs.current_tab
	for g: int in GROUPS.size():
		var members: Array[int] = _members(g)
		var attention: bool = members.any(func(index: int) -> bool: return _tab_nodes[index].needs_attention())
		_group_buttons[g].visible = not members.is_empty()
		_group_buttons[g].text = tr(GROUPS[g][0]) + ("  ●" if attention else "")
		_group_buttons[g].set_pressed_no_signal(g == current_group)
	var current_members: Array[int] = _members(current_group)
	for i: int in _sub_buttons.size():
		_sub_buttons[i].visible = current_members.size() > 1 and current_members.has(i)
		_sub_buttons[i].text = tabs.get_tab_title(i)
		_sub_buttons[i].set_pressed_no_signal(i == tabs.current_tab)
	_subtabs_row.visible = current_members.size() > 1


func _nav_button(font_size: int) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size = Vector2(150 if font_size >= 20 else 120, 46 if font_size >= 20 else 36)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


## Monnaies : icône, montant et, au survol, où les gagner.
func _refresh_currencies() -> void:
	UiKit.clear(_currencies)
	for entry: Array in [["◆", Profile.profile.shards(), "REFUGE_SHARDS", "REFUGE_SHARDS_HINT", UiKit.GOLD],
			["✦", Profile.profile.essence(), "REFUGE_ESSENCE", "REFUGE_ESSENCE_HINT", Color(0.75, 0.6, 1.0)]]:
		var label: Label = UiKit.label("%s %s : %d" % [entry[0], tr(entry[2]), entry[1]], 20, entry[4])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.tooltip_text = tr(entry[3])
		_currencies.add_child(label)


## Premiers retours au refuge : ce qu'il y a de plus utile à faire maintenant ([texte, onglet]), vide ensuite.
func next_step() -> Dictionary:
	var played: int = int(Profile.profile.data["runs"].get("played", 0))
	if played >= GUIDE_RUNS:
		return {}
	if played == 0:
		return {"text": tr("REFUGE_STEP_FIRST_RUN"), "tab": "expedition_tab"}
	if _tab_nodes[tab_index("tree_tab")].needs_attention():
		var learnable: bool = GameDB.skill_nodes.values().any(func(node: SkillNodeData) -> bool:
			return node.implemented and HunterTree.status(Profile.profile, node) == HunterTree.Status.LEARNABLE)
		return {"text": tr("REFUGE_STEP_LEARN" if learnable else "REFUGE_STEP_ACTIVATE"), "tab": "tree_tab"}
	if _tab_nodes[tab_index("echo_tab")].needs_attention():
		return {"text": tr("REFUGE_STEP_ECHO"), "tab": "echo_tab"}
	return {"text": tr("REFUGE_STEP_READY"), "tab": "expedition_tab"}


## Bandeau « Prochaine étape », avec un bouton pour y aller.
func _refresh_next_step() -> void:
	UiKit.clear(_next_step)
	var step: Dictionary = next_step()
	_next_step.visible = not step.is_empty()
	if step.is_empty():
		return
	_next_step.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.06, 0.05, 0.1, 0.9), UiKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_next_step.add_child(row)
	row.add_child(UiKit.label(tr("REFUGE_NEXT_STEP"), 16, UiKit.ACCENT))
	var text: Label = UiKit.label(str(step["text"]), 16, MenuSkin.PAPER)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text)
	var target: int = tab_index(str(step["tab"]))
	if target >= 0 and target != tabs.current_tab:
		var go: Button = UiKit.button(tr("REFUGE_GO"), func() -> void: select_tab(target), 140)
		go.name = "GoNextStep"
		row.add_child(go)


func refresh_current() -> void:
	if tabs.current_tab >= 0 and tabs.current_tab < _tab_nodes.size():
		_tab_nodes[tabs.current_tab].refresh()
		MenuSkin.finish(_tab_nodes[tabs.current_tab])


## Changer d'onglet sans la souris : gâchettes LB / RB de la manette, Page précédente / suivante, Ctrl+Tab.
func _unhandled_input(event: InputEvent) -> void:
	var step: int = 0
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_LEFT_SHOULDER: step = -1
			JOY_BUTTON_RIGHT_SHOULDER: step = 1
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event
		match key.keycode:
			KEY_PAGEUP: step = -1
			KEY_PAGEDOWN: step = 1
			KEY_TAB:
				if key.ctrl_pressed:
					step = -1 if key.shift_pressed else 1
	if step != 0:
		get_viewport().set_input_as_handled()
		switch_tab(step)


func switch_tab(step: int) -> void:
	var order: Array[int] = visible_order()
	var at: int = maxi(order.find(tabs.current_tab), 0)
	select_tab(order[posmod(at + step, order.size())])
	Audio.play_sfx(&"ui_click")


## Sauvegarde puis rafraîchit (après un achat, un réglage...).
func commit() -> void:
	Audio.play_sfx(&"ui_click")
	Profile.save()
