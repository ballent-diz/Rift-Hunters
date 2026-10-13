extends RefugeTab
## Arbre permanent du Chasseur : 5 branches, paliers, prérequis, nœuds exclusifs, réinitialisation.

const STATUS_COLORS := {
	SkillTree.Status.OWNED_MAX: Color(1.0, 0.85, 0.4),
	SkillTree.Status.AVAILABLE: Color(0.55, 0.95, 1.0),
	SkillTree.Status.TOO_EXPENSIVE: Color(0.6, 0.65, 0.8),
	SkillTree.Status.LOCKED: Color(0.35, 0.36, 0.42),
	SkillTree.Status.EXCLUDED: Color(0.7, 0.3, 0.4),
}

var _selected: StringName = &""


func title_key() -> String:
	return "TAB_TREE"


func refresh() -> void:
	var box: VBoxContainer = scroll_box(10)
	var p: ProfileData = profile()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	var intro: Label = UiKit.wrapped(tr("TREE_INTRO"), 15)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(intro)
	var respec: Button = UiKit.button(tr("TREE_RESPEC") % SkillTree.respec_cost(p), _respec, 300)
	respec.disabled = SkillTree.spent_shards(p) == 0 or not p.can_afford("essence", SkillTree.respec_cost(p))
	top.add_child(respec)
	var columns := HFlowContainer.new()
	columns.add_theme_constant_override("h_separation", 10)
	columns.add_theme_constant_override("v_separation", 18)
	box.add_child(columns)
	var branches: Array = GameDB.skill_branches.values()
	branches.sort_custom(func(a: SkillBranchData, b: SkillBranchData) -> bool: return a.order < b.order)
	for branch: SkillBranchData in branches:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 205
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		columns.add_child(col)
		col.add_child(UiKit.label(tr(branch.name_key), 19, branch.color, HORIZONTAL_ALIGNMENT_CENTER))
		for node: SkillNodeData in SkillTree.nodes_of_branch(branch.id):
			col.add_child(_node_button(p, node))
	box.add_child(_detail(p))


func _node_button(p: ProfileData, node: SkillNodeData) -> Button:
	var status: SkillTree.Status = SkillTree.status(p, node)
	var color: Color = STATUS_COLORS[status]
	var cost: int = SkillTree.next_cost(p, node)
	var cost_text: String = tr("TREE_MAXED") if cost < 0 else tr("TREE_COST") % cost
	var b := Button.new()
	b.text = "%s\n%d/%d · %s" % [tr(node.name_key), p.tree_rank(node.id), node.max_rank(), cost_text]
	b.custom_minimum_size = Vector2(200, 58)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", color)
	var style: StyleBoxFlat = UiKit.panel_box(color.darkened(0.2) if node.id != _selected else Color.WHITE, Color(0.1, 0.11, 0.18))
	style.set_border_width_all(3 if node.id == _selected else 2)
	style.border_width_left = 6 if node.exclusive_group != &"" else 2
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", UiKit.panel_box(Color.WHITE, Color(0.16, 0.18, 0.28)))
	b.tooltip_text = tr(node.desc_key)
	b.pressed.connect(func() -> void:
		_selected = node.id
		refresh())
	return b


func _detail(p: ProfileData) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	panel.add_child(box)
	var node: SkillNodeData = GameDB.skill_node(_selected)
	if node == null:
		box.add_child(UiKit.label(tr("TREE_SELECT_HINT"), 16, UiKit.MUTED))
		return panel
	box.add_child(UiKit.label(tr(node.name_key), 22, UiKit.ACCENT))
	box.add_child(UiKit.wrapped(tr(node.desc_key), 16, UiKit.TEXT))
	var info: PackedStringArray = []
	info.append(tr("TREE_RANK") % [p.tree_rank(node.id), node.max_rank()])
	if not node.prerequisites.is_empty():
		var names: PackedStringArray = []
		for prereq: StringName in node.prerequisites:
			names.append(tr(GameDB.skill_node(prereq).name_key))
		var joiner: String = tr("TREE_OR") if node.prerequisites_any else ", "
		info.append(tr("TREE_REQUIRES") % joiner.join(names))
	if node.exclusive_group != &"":
		info.append(tr("TREE_EXCLUSIVE"))
	var excluded: StringName = SkillTree.excluded_by(p, node)
	if excluded != &"":
		info.append(tr("TREE_EXCLUDED_BY") % tr(GameDB.skill_node(excluded).name_key))
	box.add_child(UiKit.wrapped(" · ".join(info), 15))
	var status: SkillTree.Status = SkillTree.status(p, node)
	var cost: int = SkillTree.next_cost(p, node)
	var buy: Button = UiKit.button(tr("TREE_BUY") % cost if cost >= 0 else tr("TREE_MAXED"), _buy.bind(node.id), 280)
	buy.disabled = status != SkillTree.Status.AVAILABLE
	box.add_child(buy)
	return panel


func _buy(id: StringName) -> void:
	if SkillTree.buy(profile(), GameDB.skill_node(id)):
		refuge.commit()


func _respec() -> void:
	if SkillTree.respec(profile()):
		refuge.commit()
