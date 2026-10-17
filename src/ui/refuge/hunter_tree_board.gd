class_name HunterTreeBoard
extends Control
## Voie détaillée : trois sorts sur un axe, bifurcations A/B locales et talents séparés.
## Index compact des quatre voies ; aucune règle de progression ajoutée.

signal node_selected(id: StringName)

const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]

var focus_branch: StringName = &""

var _profile: ProfileData
var _buttons: Dictionary = {}
var _headings: Array[Label] = []
var _tiers: Array[Label] = []
var _common: Label
var _sections: Array[Label] = []


func setup(p: ProfileData, selection: StringName) -> void:
	_profile = p
	custom_minimum_size = Vector2(752, 640 if focus_branch != &"" else 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_common = UiKit.label(tr("C5_COMMON"), 12, HunterTreeSkin.MUTED)
	add_child(_common)
	for branch_id: StringName in [&"trunk"] + HunterTreeSkin.PATHS:
		for data: SkillNodeData in HunterTree.nodes_of_branch(branch_id):
			var button := HunterTreeNode.new()
			button.setup(p, data, selection)
			button.visible = focus_branch == &"" or branch_id in [&"trunk", focus_branch]
			if focus_branch != &"" and branch_id != &"trunk":
				button.expanded = true
				button.caption.add_theme_font_size_override("font_size", 13)
				button.caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				button.caption.max_lines_visible = 2
			button.pressed.connect(func() -> void: node_selected.emit(data.id))
			add_child(button)
			_buttons[data.id] = button
	for branch_id: StringName in HunterTreeSkin.PATHS:
		var branch: SkillBranchData = GameDB.skill_branches[branch_id]
		var label: Label = UiKit.label(tr(branch.name_key).to_upper(), 15, HunterTreeSkin.accent(branch_id),
			HORIZONTAL_ALIGNMENT_CENTER)
		label.tooltip_text = tr(branch.desc_key)
		add_child(label)
		_headings.append(label)
	for tier: int in 5:
		var label: Label = UiKit.label(ROMAN[tier], 12, HunterTreeSkin.MUTED)
		label.tooltip_text = tr("TREE_TIER") % ROMAN[tier]
		add_child(label)
		_tiers.append(label)
	if focus_branch != &"":
		for key: String in ["C5_PASSIVES", "C5_TRANSFORMS", "C5_KEYSTONE", "C5_SPELL_CHOICES"]:
			var label := UiKit.label(tr(key), 12, HunterTreeSkin.MUTED)
			add_child(label)
			_sections.append(label)
	resized.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	if focus_branch != &"":
		_layout_focus()
		return
	var trunk: Array[SkillNodeData] = HunterTree.nodes_of_branch(&"trunk")
	_common.position = Vector2(12, 14)
	for i: int in trunk.size():
		var button: HunterTreeNode = _buttons[trunk[i].id]
		button.position = Vector2(146 + i * (size.x - 158) / trunk.size(), 0)
		button.size = Vector2((size.x - 158) / trunk.size(), 50)
	var width: float = (size.x - 28) / 4
	var row_height: float = (size.y - 82) / 5
	for column: int in 4:
		_headings[column].position = Vector2(28 + column * width, 57)
		_headings[column].size = Vector2(width, 22)
		for tier: int in 5:
			_place_row(column, tier, width, row_height)
	for tier: int in 5:
		_tiers[tier].position = Vector2(5, 92 + tier * row_height)
	queue_redraw()


func _place_row(column: int, tier: int, width: float, row_height: float) -> void:
	var nodes: Array[SkillNodeData] = []
	for data: SkillNodeData in HunterTree.nodes_of_branch(HunterTreeSkin.PATHS[column]):
		if data.tier == tier:
			nodes.append(data)
	# Les variantes restent côte à côte et A précède B, indépendamment des noms traduits.
	nodes.sort_custom(func(a: SkillNodeData, b: SkillNodeData) -> bool:
		if a.kind != b.kind:
			return a.kind < b.kind
		if a.kind == SkillNodeData.Kind.VARIANT and a.exclusive_group == b.exclusive_group:
			return HunterTreeSkin.variant_letter(a) < HunterTreeSkin.variant_letter(b)
		return String(a.id) < String(b.id))
	var cell: float = minf(84, (width - 12) / maxi(1, nodes.size()))
	for i: int in nodes.size():
		var button: HunterTreeNode = _buttons[nodes[i].id]
		button.position = Vector2(28 + column * width + (width - nodes.size() * cell) * 0.5 + i * cell,
			82 + tier * row_height)
		button.size = Vector2(cell, minf(54, row_height - 1))


func _draw() -> void:
	if focus_branch != &"":
		_draw_focus()
		return
	if _buttons.is_empty():
		return
	var width: float = (size.x - 28) / 4
	var row_height: float = (size.y - 82) / 5
	for column: int in 4:
		var left: float = 28 + column * width
		var ink: Color = HunterTreeSkin.accent(HunterTreeSkin.PATHS[column])
		draw_rect(Rect2(left + 3, 56, width - 6, size.y - 56), Color(ink, 0.035))
		draw_line(Vector2(left + 12, 79), Vector2(left + width - 12, 79), Color(ink, 0.6), 1)
	for tier: int in 5:
		var y: float = 82 + (tier + 1) * row_height
		draw_line(Vector2(28, y), Vector2(size.x - 4, y), Color(0.7, 0.65, 0.7, 0.07), 1)



func _layout_focus() -> void:
	_common.position = Vector2(12, 14)
	var trunk: Array[SkillNodeData] = HunterTree.nodes_of_branch(&"trunk")
	for i: int in trunk.size():
		_place(trunk[i], Vector2(146 + i * (size.x - 158) / trunk.size(), 0),
			Vector2((size.x - 158) / trunk.size(), 50))
	for i: int in 4:
		_headings[i].visible = HunterTreeSkin.PATHS[i] == focus_branch
		_headings[i].position = Vector2(16, 60)
		_headings[i].size = Vector2(size.x - 32, 24)
	for tier: Label in _tiers:
		tier.visible = false
	var spells: Array[SkillNodeData] = _kind(SkillNodeData.Kind.SPELL)
	var width: float = (size.x - 32) / 3
	for i: int in spells.size():
		var x: float = 16 + (i + 0.5) * width
		var parent: HunterTreeNode = _buttons[spells[i].id]
		parent.caption_above = true
		_place(spells[i], Vector2(x - 62, 98), Vector2(124, 116))
		var variants: Array[SkillNodeData] = []
		for data: SkillNodeData in _kind(SkillNodeData.Kind.VARIANT):
			if spells[i].id in data.prerequisites:
				variants.append(data)
		variants.sort_custom(func(a: SkillNodeData, b: SkillNodeData) -> bool:
			return HunterTreeSkin.variant_letter(a) < HunterTreeSkin.variant_letter(b))
		for j: int in variants.size():
			_place(variants[j], Vector2(x - 124 + j * 128, 268), Vector2(120, 116))
	var passives: Array[SkillNodeData] = _kind(SkillNodeData.Kind.PASSIVE)
	var passive_width: float = (size.x * 0.64 - 32) / maxi(1, passives.size())
	for i: int in passives.size():
		_place(passives[i], Vector2(16 + i * passive_width, 426), Vector2(passive_width, 90))
	var transforms: Array[SkillNodeData] = _kind(SkillNodeData.Kind.TRANSFORM)
	for i: int in transforms.size():
		_place(transforms[i], Vector2(48 + i * (size.x * 0.64 - 172), 544), Vector2(124, 90))
	for data: SkillNodeData in _kind(SkillNodeData.Kind.KEYSTONE):
		_place(data, Vector2(size.x * 0.82 - 62, 506), Vector2(124, 116))
	_sections[0].position = Vector2(24, 400)
	_sections[1].position = Vector2(24, 522)
	_sections[2].position = Vector2(size.x * 0.67, 468)
	_sections[3].position = Vector2(24, 88)
	queue_redraw()


func _kind(kind: int) -> Array[SkillNodeData]:
	var result: Array[SkillNodeData] = []
	for data: SkillNodeData in HunterTree.nodes_of_branch(focus_branch):
		if data.kind == kind:
			result.append(data)
	return result


func _place(data: SkillNodeData, at: Vector2, extent: Vector2) -> void:
	var button: HunterTreeNode = _buttons[data.id]
	button.position = at
	button.size = extent


func _draw_focus() -> void:
	var ink: Color = HunterTreeSkin.accent(focus_branch)
	var width: float = (size.x - 32) / 3
	for i: int in 3:
		var rect := Rect2(16 + i * width, 116, width - 8, 272)
		draw_style_box(_group_style(ink), rect)
	draw_style_box(_group_style(ink), Rect2(16, 396, size.x * 0.64 - 16, 240))
	draw_style_box(_group_style(ink), Rect2(size.x * 0.66, 396, size.x * 0.34 - 16, 240))
	for button: HunterTreeNode in _buttons.values():
		if button.visible and button.data.branch == focus_branch:
			_draw_links(button)


func _group_style(ink: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.10, 0.95)
	style.border_color = Color(ink, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _draw_links(button: HunterTreeNode) -> void:
	if focus_branch == &"":
		return
	for prereq: StringName in button.data.prerequisites:
		if not _buttons.has(prereq) or not (_buttons[prereq] as Control).visible:
			continue
		var parent: HunterTreeNode = _buttons[prereq]
		var a: Rect2 = _frame(parent)
		var b: Rect2 = _frame(button)
		var points: PackedVector2Array
		if button.data.kind == SkillNodeData.Kind.VARIANT:
			var start := Vector2(a.get_center().x, a.end.y)
			var end := Vector2(b.get_center().x, b.position.y)
			points = PackedVector2Array([start, Vector2(start.x, 244), Vector2(end.x, 244), end])
		elif button.data.kind == SkillNodeData.Kind.SPELL:
			points = PackedVector2Array([Vector2(a.end.x, a.get_center().y),
				Vector2(b.position.x, b.get_center().y)])
		elif button.data.kind == SkillNodeData.Kind.KEYSTONE:
			# Le dernier sort descend directement vers sa clé, sans traverser les variantes.
			var rail: float = size.x - 21
			points = PackedVector2Array([Vector2(a.end.x, a.get_center().y),
				Vector2(rail, a.get_center().y), Vector2(rail, b.get_center().y),
				Vector2(b.end.x, b.get_center().y)])
		elif parent.data.kind == SkillNodeData.Kind.TRANSFORM:
			points = PackedVector2Array([Vector2(a.end.x, a.get_center().y),
				Vector2(b.position.x, b.get_center().y)])
		else:
			# Les prérequis « un parmi plusieurs passifs » restent explicités dans le détail.
			# Aucun faisceau ambigu ne traverse ici les légendes des passifs.
			continue
		var selected: bool = button.picked or parent.picked
		var learned: bool = HunterTree.learned_rank(_profile, parent.data) > 0
		_wire(points, HunterTreeSkin.CYAN if selected else HunterTreeSkin.accent(focus_branch),
			2.0, 0.95 if selected or learned else 0.35)


func _frame(button: HunterTreeNode) -> Rect2:
	var rect: Rect2 = button.emblem_rect()
	rect.position += button.position
	return rect


func _wire(points: PackedVector2Array, color: Color, width: float, alpha: float = 0.8) -> void:
	draw_polyline(points, Color(0.025, 0.025, 0.055, 0.95), width + 4, true)
	draw_polyline(points, Color(color, alpha), width, true)
