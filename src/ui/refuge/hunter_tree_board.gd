class_name HunterTreeBoard
extends Control
## Plan lisible à 720p : le tronc et les cinq paliers restent visibles ensemble.
## Ramifications de voie et flèches de prérequis réels ; aucune règle de progression ajoutée.

signal node_selected(id: StringName)

const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]

var focus_branch: StringName = &""

var _profile: ProfileData
var _buttons: Dictionary = {}
var _headings: Array[Label] = []
var _tiers: Array[Label] = []
var _common: Label


func setup(p: ProfileData, selection: StringName) -> void:
	_profile = p
	custom_minimum_size = Vector2(752, 840 if focus_branch != &"" else 300)
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
	_draw_trunk()
	for column: int in 4:
		_draw_roots(HunterTreeSkin.PATHS[column], 28 + column * width, width, 79)
	for raw: StringName in _buttons:
		_draw_links(_buttons[raw])


func _draw_links(button: HunterTreeNode) -> void:
	for prereq: StringName in button.data.prerequisites:
		if not _buttons.has(prereq) or not (_buttons[prereq] as Control).visible:
			continue
		var parent: HunterTreeNode = _buttons[prereq]
		var parent_frame: Rect2 = _frame(parent)
		var child_frame: Rect2 = _frame(button)
		var direction: float = 1.0 if child_frame.get_center().x >= parent_frame.get_center().x else -1.0
		var start: Vector2 = parent_frame.get_center() + Vector2(direction * parent_frame.size.x * 0.5, 0)
		var end: Vector2 = Vector2(child_frame.get_center().x, child_frame.position.y - 2)
		var rail: float = clampf(start.x + direction * (26 if focus_branch != &"" else 7), 28, size.x - 8)
		if focus_branch != &"" and button.data.tier - parent.data.tier > 1:
			rail = size.x - 12
		var bend: float = end.y - (16 if focus_branch != &"" else 7)
		var ink: Color = HunterTreeSkin.accent(button.data.branch)
		var learned: bool = HunterTree.learned_rank(_profile, parent.data) > 0
		var selected: bool = button.picked or parent.picked
		var points := PackedVector2Array([start, Vector2(rail, start.y), Vector2(rail, bend),
			Vector2(end.x, bend), end])
		_wire(points, HunterTreeSkin.CYAN if selected else ink,
			3.2 if focus_branch != &"" else 1.5, 0.95 if learned or selected else 0.65)
		var arrow: float = 5 if focus_branch != &"" else 3
		draw_polyline(PackedVector2Array([end + Vector2(-arrow, -arrow), end, end + Vector2(arrow, -arrow)]),
			Color(ink, 0.95), 2, true)


func _layout_focus() -> void:
	var trunk: Array[SkillNodeData] = HunterTree.nodes_of_branch(&"trunk")
	_common.position = Vector2(12, 14)
	for i: int in trunk.size():
		var button: HunterTreeNode = _buttons[trunk[i].id]
		button.position = Vector2(146 + i * (size.x - 158) / trunk.size(), 0)
		button.size = Vector2((size.x - 158) / trunk.size(), 50)
	for column: int in 4:
		_headings[column].visible = HunterTreeSkin.PATHS[column] == focus_branch
		_headings[column].position = Vector2(28, 60)
		_headings[column].size = Vector2(size.x - 28, 24)
	for tier: int in 5:
		_tiers[tier].position = Vector2(5, 146 + tier * 148)
		var row: Array[SkillNodeData] = []
		for data: SkillNodeData in HunterTree.nodes_of_branch(focus_branch):
			if data.tier == tier:
				row.append(data)
		row.sort_custom(func(a: SkillNodeData, b: SkillNodeData) -> bool:
			if a.kind != b.kind:
				return a.kind < b.kind
			if a.kind == SkillNodeData.Kind.VARIANT:
				return HunterTreeSkin.variant_letter(a) < HunterTreeSkin.variant_letter(b)
			return String(a.id) < String(b.id))
		var cell: float = (size.x - 40) / maxi(1, row.size())
		for i: int in row.size():
			var button: HunterTreeNode = _buttons[row[i].id]
			button.position = Vector2(32 + i * cell, 110 + tier * 148)
			button.size = Vector2(cell - 8, 116)
	queue_redraw()


func _draw_focus() -> void:
	var ink: Color = HunterTreeSkin.accent(focus_branch)
	draw_rect(Rect2(28, 56, size.x - 32, size.y - 56), Color(ink, 0.025))
	_draw_trunk()
	_draw_roots(focus_branch, 28, size.x - 28, 84)
	for button: HunterTreeNode in _buttons.values():
		if button.visible:
			_draw_links(button)


func _frame(button: HunterTreeNode) -> Rect2:
	var rect: Rect2 = button.emblem_rect()
	rect.position += button.position
	return rect


func _wire(points: PackedVector2Array, color: Color, width: float, alpha: float = 0.8) -> void:
	draw_polyline(points, Color(0.025, 0.025, 0.055, 0.95), width + 4, true)
	draw_polyline(points, Color(color, alpha), width, true)


func _draw_trunk() -> void:
	var centers: Array[float] = []
	for data: SkillNodeData in HunterTree.nodes_of_branch(&"trunk"):
		var frame: Rect2 = _frame(_buttons[data.id])
		var x: float = frame.get_center().x
		centers.append(x)
		_wire(PackedVector2Array([Vector2(x, frame.end.y), Vector2(x, 54)]), HunterTreeSkin.PAPER, 2, 0.65)
	if centers.is_empty():
		return
	var bus_left: float = minf(centers.min(), 28 + (size.x - 28) / 8)
	var bus_right: float = maxf(centers.max(), size.x - (size.x - 28) / 8)
	_wire(PackedVector2Array([Vector2(bus_left, 54), Vector2(bus_right, 54)]), HunterTreeSkin.PAPER, 2, 0.65)
	var width: float = (size.x - 28) / 4
	for i: int in 1 if focus_branch != &"" else 4:
		var x: float = size.x * 0.5 if focus_branch != &"" else 28 + (i + 0.5) * width
		var ink: Color = HunterTreeSkin.accent(focus_branch if focus_branch != &"" else HunterTreeSkin.PATHS[i])
		_wire(PackedVector2Array([Vector2(x, 54), Vector2(x, 59)]), ink, 2.5)
		draw_circle(Vector2(x, 54), 3.5, ink)


func _draw_roots(branch: StringName, left: float, width: float, header_bottom: float) -> void:
	var ink: Color = HunterTreeSkin.accent(branch)
	var roots: Array[HunterTreeNode] = []
	var rail: float = left + (14 if focus_branch != &"" else 5)
	var bottom: float = header_bottom
	for data: SkillNodeData in HunterTree.nodes_of_branch(branch):
		if data.prerequisites.is_empty():
			var button: HunterTreeNode = _buttons[data.id]
			roots.append(button)
			bottom = maxf(bottom, _frame(button).position.y - 12)
	_wire(PackedVector2Array([Vector2(left + width * 0.5, header_bottom),
		Vector2(left + width * 0.5, header_bottom + 5), Vector2(rail, header_bottom + 5),
		Vector2(rail, bottom)]), ink, 2.3 if focus_branch != &"" else 1.5, 0.65)
	for button: HunterTreeNode in roots:
		var rect: Rect2 = _frame(button)
		var end := Vector2(rect.get_center().x, rect.position.y - 2)
		var bend: float = rect.position.y - 12
		_wire(PackedVector2Array([Vector2(rail, bend), Vector2(end.x, bend), end]), ink,
			2.3 if focus_branch != &"" else 1.5, 0.75)
		draw_circle(Vector2(rail, bend), 3, ink)
