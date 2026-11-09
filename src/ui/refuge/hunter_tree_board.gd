class_name HunterTreeBoard
extends Control
## Arbre du Chasseur en grille, toutes les voies côte à côte : une colonne par voie (tronc commun, Lame, Prisme, Abîme,
## Lien), une ligne par niveau (I à V), lue de haut en bas. Dans chaque voie : les passifs en haut, les sorts à gauche
## (chacun sous le précédent), leurs variantes A et B à côté du sort suivant, les talents à droite, la clé de voûte en
## bas. En-tête de colonne : la voie et ses points actifs ; à gauche : le niveau et les victoires qu'il demande.
## Les flèches disent ce qui débloque quoi. Aucune règle ici : tout est lu dans HunterTree.

signal node_selected(id: StringName)

const BRANCHES: Array[StringName] = [&"trunk", &"blade", &"prism", &"abyss", &"bond"]
## Cases par ligne : 2 pour le tronc commun, 4 pour chaque voie.
const TRUNK_UNITS := 2
const PATH_UNITS := 4
const ROWS := 5
const GUTTER := 50.0
const HEADER := 38.0
const GAP := 8.0
const ICON_MAX := 60.0
## Plein écran (bouton « Agrandir » de l'onglet) : marges serrées, icônes, en-têtes et chiffres plus grands.
const LARGE_GUTTER := 40.0
const LARGE_HEADER := 50.0
const LARGE_GAP := 6.0
const LARGE_ICON_MAX := 110.0
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]

## Voie de la compétence sélectionnée (colonne mise en avant).
var focus_branch: StringName = &"blade"
## Plein écran : à régler avant setup().
var large := false

var _profile: ProfileData
var _buttons: Dictionary = {}
## Case de chaque nœud : (case dans la ligne, niveau).
var _cells: Dictionary = {}
var _columns: Dictionary = {}
var _heads: Dictionary = {}
var _rows: Array[Label] = []
var _legend: Control
var _unit: float = 0.0
var _row_height: float = 0.0
var _edge: float = 0.0
var _gutter: float = GUTTER
var _header: float = HEADER
var _gap: float = GAP


func setup(p: ProfileData, selection: StringName) -> void:
	_profile = p
	if large:
		_gutter = LARGE_GUTTER
		_header = LARGE_HEADER
		_gap = LARGE_GAP
	custom_minimum_size = Vector2(560, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for branch: StringName in BRANCHES:
		var points: int = 0
		for data: SkillNodeData in HunterTree.nodes_of_branch(branch):
			var button := HunterTreeNode.new()
			button.compact = true
			button.badge_size = 14 if large else 11
			button.setup(p, data, selection)
			button.pressed.connect(func() -> void: node_selected.emit(data.id))
			add_child(button)
			_buttons[data.id] = button
			_cells[data.id] = cell_of(data)
			points += HunterTree.active_rank(p, data) * data.point_cost
		var title: Label = UiKit.label(_branch_name(branch), 18 if large else 13, HunterTreeSkin.accent(branch),
			HORIZONTAL_ALIGNMENT_CENTER)
		title.add_theme_font_override("font", UiKit.font(&"strong"))
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.clip_text = true
		var spent: Label = UiKit.label(tr("TREE_BRANCH_POINTS") % points, 14 if large else 11,
			HunterTreeSkin.GOLD if points > 0 else HunterTreeSkin.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		spent.add_theme_font_override("font", UiKit.font(&"numbers"))
		title.tooltip_text = tr("TREE_COLUMN_TRUNK") + " : " + tr("TREE_COLUMN_TRUNK_SUB") if branch == &"trunk" \
			else tr((GameDB.skill_branches[branch] as SkillBranchData).desc_key)
		title.mouse_filter = Control.MOUSE_FILTER_PASS
		spent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title)
		add_child(spent)
		_heads[branch] = [title, spent]
	for row: int in ROWS:
		var gate: int = row_gate(row)
		var label: Label = UiKit.label(tr("TREE_ROW_TIER") % ROMAN[row], 15 if large else 11, HunterTreeSkin.PAPER,
			HORIZONTAL_ALIGNMENT_CENTER)
		label.add_theme_font_override("font", UiKit.font(&"strong"))
		if not _open(gate):
			label.text += "\n%d/%d" % [HunterTree.boss_wins(p), gate]
			label.add_theme_color_override("font_color", HunterTreeSkin.SHORT)
			label.tooltip_text = tr("TREE_GATE") % [gate, HunterTree.boss_wins(p)]
			label.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_rows.append(label)
	_legend = _make_legend()
	add_child(_legend)
	resized.connect(_layout)
	_layout.call_deferred()


## Case d'un nœud : (position dans la ligne, niveau). Sorts et clé de voûte à gauche, variantes A et B au milieu,
## talents à droite ; les passifs du niveau I centrés ; le tronc commun sur deux cases.
static func cell_of(data: SkillNodeData) -> Vector2:
	if data.branch == &"trunk":
		return Vector2(_index_among(data, func(other: SkillNodeData) -> bool: return other.tier == data.tier), data.tier)
	match data.kind:
		SkillNodeData.Kind.SPELL, SkillNodeData.Kind.KEYSTONE:
			return Vector2(0, data.tier)
		SkillNodeData.Kind.VARIANT:
			return Vector2(1 if HunterTreeSkin.variant_letter(data) == "A" else 2, data.tier)
		SkillNodeData.Kind.TRANSFORM:
			return Vector2(3, data.tier)
	var same: Callable = func(other: SkillNodeData) -> bool: return other.tier == data.tier \
		and other.kind == SkillNodeData.Kind.PASSIVE
	var count: int = 0
	for other: SkillNodeData in HunterTree.nodes_of_branch(data.branch):
		if same.call(other):
			count += 1
	return Vector2((PATH_UNITS - count) * 0.5 + _index_among(data, same), data.tier)


static func _index_among(data: SkillNodeData, keep: Callable) -> int:
	var ids: Array[String] = []
	for other: SkillNodeData in HunterTree.nodes_of_branch(data.branch):
		if keep.call(other):
			ids.append(String(other.id))
	ids.sort()
	return ids.find(String(data.id))


## Victoires contre un boss demandées par un niveau (le plus exigeant de ses nœuds, toutes voies).
func row_gate(row: int) -> int:
	var gate: int = 0
	for data: SkillNodeData in GameDB.skill_nodes.values():
		if data.tier == row and data.branch in BRANCHES:
			gate = maxi(gate, data.required_wins)
	return gate


func _open(gate: int) -> bool:
	return HunterTree.boss_wins(_profile) >= gate


func _branch_name(branch: StringName) -> String:
	if branch == &"trunk":
		return tr("TREE_COLUMN_TRUNK_SHORT")
	return tr((GameDB.skill_branches[branch] as SkillBranchData).name_key)


static func units(branch: StringName) -> int:
	return TRUNK_UNITS if branch == &"trunk" else PATH_UNITS


## Légende sous le tronc commun (ses niveaux III à V sont vides) : formes des cadres (sort en hexagone doré, passif en
## cercle), puis les états ; en plein écran, la façon de lire la grille.
func _make_legend() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "BoardLegend"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5 if large else 3)
	var side: float = 24.0 if large else 16.0
	var text_size: int = 13 if large else 10
	var shapes := HFlowContainer.new()
	shapes.name = "LegendShapes"
	shapes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shapes.add_theme_constant_override("h_separation", 6)
	for kind: String in ["spell", "passive"]:
		var shape := HBoxContainer.new()
		shape.add_theme_constant_override("separation", 3)
		shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape.add_child(_legend_frame(HunterTreeSkin.state_frame("learned", kind), side))
		var label: Label = UiKit.label(tr("TREE_KIND_SPELL" if kind == "spell" else "TREE_KIND_PASSIVE"), text_size,
			HunterTreeSkin.GOLD if kind == "spell" else HunterTreeSkin.PAPER)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		shape.add_child(label)
		shapes.add_child(shape)
	box.add_child(shapes)
	for state: String in HunterTreeSkin.LEGEND:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_legend_frame(HunterTreeSkin.state_frame(state), side))
		var label: Label = UiKit.label(tr(HunterTreeSkin.LEGEND_KEYS[state]), text_size, HunterTreeSkin.STATE_COLORS[state])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		box.add_child(row)
	if large:
		var hint: Label = UiKit.wrapped(tr("TREE_GRID_HINT"), 12, HunterTreeSkin.MUTED)
		hint.custom_minimum_size.x = 0
		box.add_child(hint)
	return box


func _legend_frame(texture: Texture2D, side: float) -> TextureRect:
	var frame := TextureRect.new()
	frame.texture = texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.custom_minimum_size = Vector2(side, side)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


func _layout() -> void:
	var total_units: int = 0
	for branch: StringName in BRANCHES:
		total_units += units(branch)
	_unit = (size.x - _gutter - _gap * (BRANCHES.size() - 1)) / total_units
	_row_height = (size.y - _header) / ROWS
	_edge = clampf(minf(_unit * (0.94 if large else 0.92), _row_height * 0.84), 24.0,
		LARGE_ICON_MAX if large else ICON_MAX)
	var x: float = _gutter
	for branch: StringName in BRANCHES:
		var width: float = units(branch) * _unit
		_columns[branch] = Rect2(x, 0, width, size.y)
		var labels: Array = _heads[branch]
		var line: float = (_header - 2.0) * 0.5
		(labels[0] as Label).position = Vector2(x, 1)
		(labels[0] as Label).size = Vector2(width, line + 1)
		(labels[1] as Label).position = Vector2(x, line)
		(labels[1] as Label).size = Vector2(width, line)
		x += width + _gap
	for id: StringName in _buttons:
		var button: HunterTreeNode = _buttons[id]
		button.position = center_of(id) - Vector2.ONE * _edge * 0.5
		button.size = Vector2.ONE * _edge
		button.layout_caption()
	for row: int in ROWS:
		_rows[row].position = Vector2(0, _header + row * _row_height)
		_rows[row].size = Vector2(_gutter - 4, _row_height)
		_rows[row].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var trunk: Rect2 = _columns[&"trunk"]
	_legend.position = Vector2(trunk.position.x + 6, _header + 2 * _row_height + 6)
	_legend.size = Vector2(trunk.size.x - 12, 0)
	_legend.custom_minimum_size.x = trunk.size.x - 12
	queue_redraw()


## Centre de l'icône d'un nœud dans la grille.
func center_of(id: StringName) -> Vector2:
	var data: SkillNodeData = GameDB.skill_node(id)
	var column: Rect2 = _columns[data.branch]
	var cell: Vector2 = _cells[id]
	return Vector2(column.position.x + (cell.x + 0.5) * _unit, _header + (cell.y + 0.5) * _row_height)


func _draw() -> void:
	if _columns.size() < BRANCHES.size():
		return
	for branch: StringName in BRANCHES:
		var rect: Rect2 = _columns[branch]
		var accent: Color = HunterTreeSkin.accent(branch)
		draw_rect(rect, Color(0.045, 0.04, 0.09, 0.86))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, _header - 2)), Color(accent, 0.1))
		draw_line(Vector2(rect.position.x, _header - 2), Vector2(rect.end.x, _header - 2), Color(accent, 0.6), 2.0)
		var focused: bool = branch == focus_branch
		draw_rect(rect, Color(accent, 0.55 if focused else 0.18), false, 2.0 if focused else 1.0)
	for row: int in range(1, ROWS):
		var y: float = _header + row * _row_height
		draw_dashed_line(Vector2(_gutter, y), Vector2(size.x, y), Color(HunterTreeSkin.PAPER, 0.07), 1.0, 6.0)
	# Niveaux encore scellés : voile sur toute la ligne, cadenas dans la marge.
	for row: int in ROWS:
		if not _open(row_gate(row)):
			var band := Rect2(_gutter, _header + row * _row_height + 1, size.x - _gutter, _row_height - 2)
			HunterTreeSkin.draw_veil(self, band)
	for id: StringName in _buttons:
		var data: SkillNodeData = (_buttons[id] as HunterTreeNode).data
		for prereq: StringName in data.prerequisites:
			if _buttons.has(prereq) and (_buttons[prereq] as HunterTreeNode).data.branch == data.branch:
				_link(_buttons[prereq], _buttons[id])


## Flèche d'un prérequis vers ce qu'il débloque : tout droit dans la même case, sinon par l'espace entre les deux
## lignes. Pointillés tant que le prérequis n'est pas appris ; allumée ensuite ; dorée quand les deux sont actifs.
func _link(parent: HunterTreeNode, child: HunterTreeNode) -> void:
	var a: Vector2 = center_of(parent.data.id) + Vector2(0, _edge * 0.5 + 2)
	var b: Vector2 = center_of(child.data.id) - Vector2(0, _edge * 0.5 + 3)
	var points := PackedVector2Array([a, b])
	if absf(a.x - b.x) > 1.0:
		var bend: float = _header + (int((_cells[parent.data.id] as Vector2).y) + 1) * _row_height
		points = PackedVector2Array([a, Vector2(a.x, bend), Vector2(b.x, bend), b])
	var lit: bool = HunterTree.learned_rank(_profile, parent.data) > 0
	var active: bool = parent.current == "active" and child.current == "active"
	var color: Color = HunterTreeSkin.accent(parent.data.branch)
	if parent.picked or child.picked:
		color = HunterTreeSkin.CYAN
	elif active:
		color = HunterTreeSkin.GOLD
	if lit:
		draw_polyline(points, Color(0.025, 0.025, 0.055, 0.9), 4.5, true)
		draw_polyline(points, Color(color, 0.95), 2.0, true)
	else:
		for i: int in points.size() - 1:
			draw_dashed_line(points[i], points[i + 1], Color(color, 0.35), 1.5, 4.0)
	var tip: Vector2 = points[points.size() - 1]
	var side := Vector2(4, 0)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 2), tip - Vector2(0, 5) + side, tip - Vector2(0, 5) - side]),
		Color(color, 0.95 if lit else 0.45))
