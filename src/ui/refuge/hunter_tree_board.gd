class_name HunterTreeBoard
extends Control
## Plan lisible à 720p : le tronc et les cinq paliers restent visibles ensemble.
## Les traits fins représentent uniquement les prérequis réels des ressources.

signal node_selected(id: StringName)

const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]

var _profile: ProfileData
var _buttons: Dictionary = {}
var _headings: Array[Label] = []
var _tiers: Array[Label] = []
var _common: Label


func setup(p: ProfileData, selection: StringName) -> void:
	_profile = p
	custom_minimum_size = Vector2(752, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_common = UiKit.label(tr("C5_COMMON"), 12, HunterTreeSkin.MUTED)
	add_child(_common)
	for branch_id: StringName in [&"trunk"] + HunterTreeSkin.PATHS:
		for data: SkillNodeData in HunterTree.nodes_of_branch(branch_id):
			var button := HunterTreeNode.new()
			button.setup(p, data, selection)
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
	resized.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
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
	if _buttons.is_empty():
		return
	var width: float = (size.x - 28) / 4
	var row_height: float = (size.y - 82) / 5
	for column: int in 4:
		var left: float = 28 + column * width
		var ink: Color = HunterTreeSkin.accent(HunterTreeSkin.PATHS[column])
		draw_rect(Rect2(left + 3, 56, width - 6, size.y - 56), Color(ink, 0.035))
		draw_line(Vector2(left + 12, 79), Vector2(left + width - 12, 79), Color(ink, 0.6), 1)
		draw_line(Vector2(left + width * 0.5, 50), Vector2(left + width * 0.5, 56), Color(ink, 0.5), 1)
	for tier: int in 5:
		var y: float = 82 + (tier + 1) * row_height
		draw_line(Vector2(28, y), Vector2(size.x - 4, y), Color(0.7, 0.65, 0.7, 0.07), 1)
	draw_line(Vector2(28 + width * 0.5, 52), Vector2(size.x - width * 0.5, 52), Color(HunterTreeSkin.MUTED, 0.3), 1)
	for raw: StringName in _buttons:
		_draw_links(_buttons[raw])


func _draw_links(button: HunterTreeNode) -> void:
	for prereq: StringName in button.data.prerequisites:
		if not _buttons.has(prereq):
			continue
		var parent: HunterTreeNode = _buttons[prereq]
		var start: Vector2 = parent.position + Vector2(parent.size.x * 0.5, parent.size.y - 13)
		var end: Vector2 = button.position + Vector2(button.size.x * 0.5, 0)
		var bend: float = end.y - 2 if end.y > start.y else start.y + 2
		var ink: Color = HunterTreeSkin.accent(button.data.branch)
		var learned: bool = HunterTree.learned_rank(_profile, parent.data) > 0
		draw_polyline(PackedVector2Array([start, Vector2(start.x, bend), Vector2(end.x, bend), end]),
			Color(ink, 0.55 if learned else 0.16), 1.5 if learned else 1.0, true)
		if button.data.kind == SkillNodeData.Kind.VARIANT:
			draw_circle(end - Vector2(0, 2), 1.5, Color(ink, 0.6))
