extends RefugeTab
## Arbre du Chasseur v2 : tronc + 4 voies (apprendre avec les Éclats, activer avec les Points de Chasseur), 3 builds,
## sorts équipés sur A/E/R/F, améliorations du refuge. Visuels définitifs : lot C5 (Codex).

const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]
const ACTIVE_COLOR := Color(1.0, 0.85, 0.4)
const LEARNED_COLOR := Color(0.85, 0.92, 1.0)
const STATUS_COLORS := {
	HunterTree.Status.COMING_SOON: Color(0.4, 0.4, 0.48),
	HunterTree.Status.GATED: Color(0.45, 0.46, 0.55),
	HunterTree.Status.LOCKED: Color(0.45, 0.46, 0.55),
	HunterTree.Status.TOO_EXPENSIVE: Color(0.6, 0.65, 0.8),
	HunterTree.Status.LEARNABLE: Color(0.55, 0.95, 1.0),
	HunterTree.Status.LEARNED: LEARNED_COLOR,
}
const KIND_KEYS := {
	SkillNodeData.Kind.UTILITY: "TREE_KIND_UTILITY", SkillNodeData.Kind.PASSIVE: "TREE_KIND_PASSIVE",
	SkillNodeData.Kind.SPELL: "TREE_KIND_SPELL", SkillNodeData.Kind.VARIANT: "TREE_KIND_VARIANT",
	SkillNodeData.Kind.TRANSFORM: "TREE_KIND_TRANSFORM", SkillNodeData.Kind.KEYSTONE: "TREE_KIND_KEYSTONE",
}

var _selected: StringName = &""


func title_key() -> String:
	return "TAB_TREE"


## Mise en page : l'arbre défile à gauche, le détail du nœud choisi reste visible à droite. La position de
## défilement est conservée d'un rafraîchissement à l'autre (chaque action reconstruit l'onglet).
func refresh() -> void:
	var previous_scroll: int = 0
	for child: Node in get_children():
		var old: ScrollContainer = child.find_child("TreeScroll", true, false) as ScrollContainer
		if old:
			previous_scroll = old.scroll_vertical
	UiKit.clear(self)
	var p: ProfileData = profile()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.add_child(UiKit.wrapped(tr("TREE_INTRO_V2"), 15))
	root.add_child(_header(p))
	root.add_child(_spell_bar(p))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.name = "TreeScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	# Détail dans sa propre zone défilante : sa hauteur ne doit jamais agrandir la page.
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.custom_minimum_size.x = 300
	split.add_child(detail_scroll)
	var detail: PanelContainer = _detail(p)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 6)
	box.add_child(columns)
	for branch: SkillBranchData in _branches(false):
		columns.add_child(_branch_column(p, branch))
	box.add_child(UiKit.label(tr("TREE_UTILITIES"), 19, UiKit.ACCENT))
	var utilities := HFlowContainer.new()
	utilities.add_theme_constant_override("h_separation", 10)
	utilities.add_theme_constant_override("v_separation", 8)
	box.add_child(utilities)
	for branch: SkillBranchData in _branches(true):
		for node: SkillNodeData in HunterTree.nodes_of_branch(branch.id):
			utilities.add_child(_node_button(p, node))
	_restore_scroll.call_deferred(scroll, previous_scroll)


func _restore_scroll(scroll: ScrollContainer, value: int) -> void:
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value


func _branches(utility: bool) -> Array[SkillBranchData]:
	var list: Array[SkillBranchData] = []
	for branch: SkillBranchData in GameDB.skill_branches.values():
		if branch.utility == utility:
			list.append(branch)
	list.sort_custom(func(a: SkillBranchData, b: SkillBranchData) -> bool: return a.order < b.order)
	return list


func _header(p: ProfileData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var points := UiKit.label(tr("TREE_POINTS") % [HunterTree.points_used(p), HunterTree.points_total(p)], 18,
		UiKit.GOLD)
	points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(points)
	for i: int in HunterTree.BUILD_COUNT:
		var button: Button = UiKit.button(tr("TREE_BUILD") % (i + 1), func() -> void:
			HunterTree.set_active_index(p, i)
			refuge.commit(), 130)
		button.disabled = i == HunterTree.active_index(p)
		row.add_child(button)
	return row


## Sorts équipés : un clic sur un emplacement y équipe le sort sélectionné dans l'arbre.
func _spell_bar(p: ProfileData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.label(tr("TREE_SPELL_SLOTS"), 17))
	var selected: SkillNodeData = GameDB.skill_node(_selected)
	var spells: Array = HunterTree.active_build(p)["spells"]
	for i: int in HunterTree.SPELL_SLOTS:
		var spell: SpellData = GameDB.spells.get(StringName(str(spells[i])))
		var key: String = InputSetup.key_label(StringName("spell_%d" % (i + 1)))
		var text: String = "%s : %s" % [key, tr(spell.name_key) if spell else tr("TREE_SLOT_EMPTY")]
		var button: Button = UiKit.button(text, func() -> void:
			if selected and selected.kind == SkillNodeData.Kind.SPELL and HunterTree.equip(p, selected.spell_id, i):
				refuge.commit(), 190)
		button.tooltip_text = tr("TREE_EQUIP_HINT")
		row.add_child(button)
	return row


func _branch_column(p: ProfileData, branch: SkillBranchData) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 150
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 5)
	col.add_child(UiKit.label(tr(branch.name_key), 19, branch.color, HORIZONTAL_ALIGNMENT_CENTER))
	var tier: int = -1
	for node: SkillNodeData in HunterTree.nodes_of_branch(branch.id):
		if node.tier != tier:
			tier = node.tier
			var title: String = tr("TREE_TIER") % ROMAN[clampi(tier, 0, ROMAN.size() - 1)]
			if node.required_wins > HunterTree.boss_wins(p):
				title += " · " + tr("TREE_GATE_SHORT") % node.required_wins
			col.add_child(UiKit.label(title, 13, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		col.add_child(_node_button(p, node))
	return col


func _state_text(p: ProfileData, node: SkillNodeData) -> String:
	var active: int = HunterTree.active_rank(p, node)
	if active > 0 and not node.is_utility():
		return tr("TREE_STATE_ACTIVE") % [active, node.max_rank()]
	match HunterTree.status(p, node):
		HunterTree.Status.COMING_SOON:
			return tr("TREE_COMING_SOON")
		HunterTree.Status.GATED, HunterTree.Status.LOCKED:
			return tr("TREE_STATE_LOCKED")
		HunterTree.Status.LEARNED:
			return tr("TREE_STATE_LEARNED")
	var learned: int = HunterTree.learned_rank(p, node)
	var cost: String = tr("TREE_COST") % HunterTree.next_cost(p, node)
	return cost if learned == 0 else "%d/%d · %s" % [learned, node.max_rank(), cost]


func _node_button(p: ProfileData, node: SkillNodeData) -> Button:
	var status: HunterTree.Status = HunterTree.status(p, node)
	var active: bool = HunterTree.active_rank(p, node) > 0 and not node.is_utility()
	var color: Color = ACTIVE_COLOR if active else STATUS_COLORS[status]
	var b := Button.new()
	b.text = "%s\n%s" % [tr(node.name_key), _state_text(p, node)]
	b.custom_minimum_size = Vector2(148, 50)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", color)
	var border: Color = Color.WHITE if node.id == _selected else color.darkened(0.25)
	var style: StyleBoxFlat = UiKit.panel_box(border, Color(0.16, 0.14, 0.08) if active else Color(0.1, 0.11, 0.18))
	style.set_border_width_all(3 if node.id == _selected else 2)
	style.border_width_left = 6 if node.exclusive_group != &"" else style.border_width_left
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
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var node: SkillNodeData = GameDB.skill_node(_selected)
	if node == null:
		box.add_child(UiKit.wrapped(tr("TREE_SELECT_HINT"), 16, UiKit.MUTED))
		return panel
	box.add_child(UiKit.wrapped(tr(node.name_key), 21, UiKit.ACCENT))
	box.add_child(UiKit.label(tr(KIND_KEYS[node.kind]), 14, UiKit.MUTED))
	box.add_child(UiKit.wrapped(tr(node.desc_key), 16, UiKit.TEXT))
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	box.add_child(actions)
	var cost: int = HunterTree.next_cost(p, node)
	if cost >= 0 and node.implemented:
		var learn: Button = UiKit.button(tr("TREE_LEARN") % cost, func() -> void:
			if HunterTree.learn(profile(), node):
				refuge.commit(), 230)
		learn.disabled = HunterTree.status(p, node) != HunterTree.Status.LEARNABLE
		actions.add_child(learn)
	if not node.is_utility() and node.implemented:
		var error: String = HunterTree.activation_error(p, node)
		var activate: Button = UiKit.button(tr("TREE_ACTIVATE") % node.point_cost, func() -> void:
			if HunterTree.activate(profile(), node):
				refuge.commit(), 220)
		activate.disabled = error != ""
		actions.add_child(activate)
		var deactivate: Button = UiKit.button(tr("TREE_DEACTIVATE"), func() -> void:
			if HunterTree.deactivate(profile(), node):
				refuge.commit(), 180)
		deactivate.disabled = HunterTree.active_rank(p, node) == 0
		actions.add_child(deactivate)
		if error != "" and error != "TREE_ERR_MAX_ACTIVE":
			box.add_child(UiKit.wrapped(tr(error), 14, UiKit.MUTED))
	if node.kind == SkillNodeData.Kind.SPELL and HunterTree.active_rank(p, node) > 0:
		box.add_child(UiKit.wrapped(tr("TREE_EQUIP_HINT"), 14, UiKit.MUTED))
	box.add_child(UiKit.wrapped(" · ".join(_infos(p, node)), 14))
	return panel


func _infos(p: ProfileData, node: SkillNodeData) -> PackedStringArray:
	var info: PackedStringArray = []
	info.append(tr("TREE_RANK") % [HunterTree.learned_rank(p, node), node.max_rank()])
	if not node.is_utility():
		info.append(tr("TREE_POINT_COST") % node.point_cost)
	if not node.implemented:
		info.append(tr("TREE_COMING_SOON"))
	if node.required_wins > 0:
		info.append(tr("TREE_GATE") % [node.required_wins, HunterTree.boss_wins(p)])
	if not node.prerequisites.is_empty():
		var names: PackedStringArray = []
		for prereq: StringName in node.prerequisites:
			var other: SkillNodeData = GameDB.skill_node(prereq)
			if other:
				names.append(tr(other.name_key))
		var joiner: String = tr("TREE_OR") if node.prerequisites_any else ", "
		info.append(tr("TREE_REQUIRES") % joiner.join(names))
	if node.exclusive_group != &"":
		info.append(tr("TREE_EXCLUSIVE_ACTIVE"))
	return info
