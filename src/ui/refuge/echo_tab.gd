extends RefugeTab
## Arbres des Échos (docs/design/ARBRES_DES_ECHOS.md) : choix de l'Écho, apprendre / activer ses nœuds, sort équipé.
## Habillage provisoire (lot C5 : Codex).

var _monster: StringName = &""
var _selected: StringName = &""


func title_key() -> String:
	return "TAB_ECHOES"


func refresh() -> void:
	var box: VBoxContainer = scroll_box(10)
	var p: ProfileData = profile()
	box.add_child(UiKit.wrapped(tr("ECHO_TREE_INTRO"), 15))
	var picker := HFlowContainer.new()
	picker.add_theme_constant_override("h_separation", 8)
	box.add_child(picker)
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var monster: MonsterData = GameDB.monsters[id]
		if EchoTree.nodes_of(id).is_empty():
			continue
		if _monster == &"":
			_monster = id
		var button: Button = UiKit.button(tr(monster.name_key), func() -> void:
			_monster = id
			_selected = &""
			refresh(), 150)
		button.disabled = id == _monster
		picker.add_child(button)
	if _monster == &"":
		return
	var monster: MonsterData = GameDB.monster(_monster)
	if not p.is_monster_unlocked(monster):
		box.add_child(UiKit.label(tr("ECHO_TREE_LOCKED"), 16, UiKit.MUTED))
	box.add_child(UiKit.label(tr("ECHO_TREE_POINTS") % [EchoTree.points_used(p, _monster),
		EchoTree.points_total(p, _monster)], 18, UiKit.GOLD))
	var technique: TechniqueData = EchoTree.chosen_technique(p, _monster)
	if technique == null:
		technique = monster.technique
	box.add_child(UiKit.label(tr("ECHO_TREE_EQUIPPED") % tr(technique.name_key), 16, UiKit.ACCENT))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	box.add_child(row)
	for n: SkillNodeData in EchoTree.nodes_of(_monster):
		row.add_child(_node_button(p, n, monster))
	box.add_child(_detail(p, monster))


func _node_name(n: SkillNodeData, monster: MonsterData) -> String:
	# Sort d'origine : le nom de la Technique de l'Écho.
	if n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default:
		return tr(monster.technique.name_key)
	return tr(n.name_key)


func _node_button(p: ProfileData, n: SkillNodeData, monster: MonsterData) -> Button:
	var active: int = EchoTree.active_rank(p, n)
	var learned: int = EchoTree.learned_rank(p, n)
	var state: String = tr("TREE_STATE_ACTIVE") % [active, n.max_rank()] if active > 0 else (
		tr("TREE_STATE_LEARNED") if learned >= n.max_rank() else tr("TREE_COST") % EchoTree.next_cost(p, n))
	var b := Button.new()
	b.text = "%s\n%s" % [_node_name(n, monster), state]
	b.custom_minimum_size = Vector2(190, 54)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if active > 0 else UiKit.TEXT)
	b.tooltip_text = tr(n.desc_key)
	b.pressed.connect(func() -> void:
		_selected = n.id
		refresh())
	return b


func _detail(p: ProfileData, monster: MonsterData) -> Control:
	var box := VBoxContainer.new()
	var n: SkillNodeData = EchoTree.node(_selected)
	if n == null:
		box.add_child(UiKit.label(tr("TREE_SELECT_HINT"), 15, UiKit.MUTED))
		return box
	box.add_child(UiKit.label(_node_name(n, monster), 20, UiKit.ACCENT))
	var desc: String = tr(monster.technique.desc_key) if n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default \
		else tr(n.desc_key)
	box.add_child(UiKit.wrapped(desc, 15, UiKit.TEXT))
	box.add_child(UiKit.wrapped(tr("TREE_POINT_COST") % n.point_cost, 13))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	var cost: int = EchoTree.next_cost(p, n)
	if cost >= 0:
		var learn: Button = UiKit.button(tr("TREE_LEARN") % cost, func() -> void:
			if EchoTree.learn(profile(), n):
				refuge.commit(), 230)
		learn.disabled = EchoTree.status(p, n) != HunterTree.Status.LEARNABLE
		actions.add_child(learn)
	var error: String = EchoTree.activation_error(p, n)
	var activate: Button = UiKit.button(tr("TREE_ACTIVATE") % n.point_cost, func() -> void:
		if EchoTree.activate(profile(), n):
			refuge.commit(), 220)
	activate.disabled = error != ""
	actions.add_child(activate)
	var deactivate: Button = UiKit.button(tr("TREE_DEACTIVATE"), func() -> void:
		if EchoTree.deactivate(profile(), n):
			refuge.commit(), 180)
	deactivate.disabled = EchoTree.active_rank(p, n) == 0 or (n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default)
	actions.add_child(deactivate)
	if error != "" and error != "TREE_ERR_MAX_ACTIVE":
		box.add_child(UiKit.wrapped(tr(error), 14, UiKit.MUTED))
	return box
