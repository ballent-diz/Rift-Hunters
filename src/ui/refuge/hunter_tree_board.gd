class_name HunterTreeBoard
extends Control
## Une voie de l'arbre du Chasseur lue de gauche à droite, comme une progression : tronc commun, passifs, 1er, 2e et
## 3e sort (chacun avec ses variantes A ou B dessous), clé de voûte. Les talents transformants courent en bas.
## Chaque case encore scellée est voilée et dit combien de boss il faut vaincre ; les liens montrent ce qui débloque
## quoi ; les cases vides accueillent la légende et des repères. Positions calculées depuis la taille ; aucune règle ici.

signal node_selected(id: StringName)

const COLUMNS := 6
## Largeur relative des colonnes : tronc, passifs, sorts 1 à 3, clé de voûte.
const WEIGHTS: Array[float] = [0.85, 0.95, 1.08, 1.08, 1.08, 0.96]
const HEADER := 38.0
const TOP_GAP := 6.0
## Couloir (y) des piles : tronc et passifs occupent toute la hauteur de leur colonne.
const STACK := -1
const SPELL_LANE := 0
const VARIANT_LANE := 1
const TALENT_LANE := 2
## Taille maximale des icônes (grands écrans) : les sorts en premier plan, passifs et variantes plus discrets.
const ICON_CAPS := {STACK: 76.0, SPELL_LANE: 100.0, VARIANT_LANE: 80.0, TALENT_LANE: 90.0}

var focus_branch: StringName = &"blade"

var _profile: ProfileData
var _buttons: Dictionary = {}
## Case (colonne, couloir) de chaque nœud affiché.
var _slots: Dictionary = {}
## Boss à vaincre pour ouvrir chaque case occupée (Vector2i → int).
var _gates: Dictionary = {}
var _columns: Array[Rect2] = []
var _lane_tops: Array[float] = []
var _lane_height: float = 0.0
var _titles: Array[Label] = []
var _subtitles: Array[Label] = []
## Repères posés dans les cases vides : {cell: Vector2i, node: Control}.
var _notes: Array[Dictionary] = []


func setup(p: ProfileData, selection: StringName) -> void:
	_profile = p
	custom_minimum_size = Vector2(620, 290)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for branch_id: StringName in [&"trunk", focus_branch]:
		for data: SkillNodeData in HunterTree.nodes_of_branch(branch_id):
			var button := HunterTreeNode.new()
			button.setup(p, data, selection)
			button.pressed.connect(func() -> void: node_selected.emit(data.id))
			add_child(button)
			_buttons[data.id] = button
			var cell: Vector2i = slot_of(data)
			_slots[data.id] = cell
			_gates[cell] = maxi(int(_gates.get(cell, 0)), data.required_wins)
	for c: int in COLUMNS:
		var title: Label = UiKit.caption(_column_title(c), 11, HunterTreeSkin.PAPER if c > 0 else HunterTreeSkin.MUTED)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title)
		_titles.append(title)
		var gate: int = column_gate(c)
		var subtitle: Label = UiKit.label(_gate_text(gate) if c > 0 else tr("TREE_COLUMN_TRUNK_SUB"), 11,
			HunterTreeSkin.MUTED if _open(gate) else HunterTreeSkin.SHORT, HORIZONTAL_ALIGNMENT_CENTER)
		subtitle.add_theme_font_override("font", UiKit.font(&"numbers"))
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(subtitle)
		_subtitles.append(subtitle)
	_add_notes()
	resized.connect(_layout)
	_layout.call_deferred()


## Case d'un nœud : sorts en haut (le niveau donne la colonne), leurs variantes juste dessous, talents en bas.
static func slot_of(data: SkillNodeData) -> Vector2i:
	if data.branch == &"trunk":
		return Vector2i(0, STACK)
	var column: int = clampi(data.tier + 1, 2, COLUMNS - 1)
	match data.kind:
		SkillNodeData.Kind.SPELL, SkillNodeData.Kind.KEYSTONE:
			return Vector2i(column, SPELL_LANE)
		SkillNodeData.Kind.VARIANT:
			var spell: SkillNodeData = HunterTree.spell_node(data.spell_id)
			return Vector2i(slot_of(spell).x if spell else column, VARIANT_LANE)
		SkillNodeData.Kind.TRANSFORM:
			return Vector2i(column, TALENT_LANE)
	return Vector2i(1, STACK) if data.tier == 0 else Vector2i(column, TALENT_LANE)


## Boss à vaincre pour la case principale d'une colonne (pile ou sort).
func column_gate(column: int) -> int:
	return int(_gates.get(Vector2i(column, STACK), _gates.get(Vector2i(column, SPELL_LANE), 0)))


func cell_gate(cell: Vector2i) -> int:
	return int(_gates.get(cell, 0))


func _open(gate: int) -> bool:
	return HunterTree.boss_wins(_profile) >= gate


func _gate_text(gate: int) -> String:
	return tr("TREE_GATE_OPEN") if _open(gate) else tr("TREE_GATE_BOSSES") % [HunterTree.boss_wins(_profile), gate]


func _column_title(column: int) -> String:
	match column:
		0: return tr("TREE_COLUMN_TRUNK")
		1: return tr("TREE_COLUMN_PASSIVES")
		COLUMNS - 1: return tr("TREE_COLUMN_KEYSTONE")
	return tr("TREE_COLUMN_SPELL") % (column - 1)


## Cases vides sous la clé de voûte : un repère sur les variantes, puis la légende des états.
func _add_notes() -> void:
	var variants := Vector2i(COLUMNS - 1, VARIANT_LANE)
	var legend := Vector2i(COLUMNS - 1, TALENT_LANE)
	if not variants in _slots.values():
		_notes.append({"cell": variants, "node": _note(tr("TREE_NOTE_VARIANTS"), tr("TREE_NOTE_VARIANTS_HINT"))})
	if not legend in _slots.values():
		_notes.append({"cell": legend, "node": _legend()})
	for note: Dictionary in _notes:
		add_child(note["node"])


func _note(title: String, body: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "BoardNote"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	box.add_child(UiKit.caption(title, 10, Color(HunterTreeSkin.accent(focus_branch), 0.9)))
	var text: Label = UiKit.wrapped(body, 11, HunterTreeSkin.MUTED)
	text.custom_minimum_size.x = 0
	box.add_child(text)
	return box


## Légende : le cadre de chaque état, comme sur les nœuds.
func _legend() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "BoardLegend"
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	for state: String in HunterTreeSkin.LEGEND:
		var frame := TextureRect.new()
		frame.texture = HunterTreeSkin.state_frame(state)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.custom_minimum_size = Vector2(18, 18)
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		grid.add_child(frame)
		var label: Label = UiKit.label(tr(HunterTreeSkin.LEGEND_KEYS[state]), 11,
			HunterTreeSkin.GOLD if state == "active" else HunterTreeSkin.PAPER.darkened(0.15))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(label)
	return grid


func _layout() -> void:
	_columns.clear()
	_lane_tops.clear()
	var total: float = 0.0
	for weight: float in WEIGHTS:
		total += weight
	var x: float = 0.0
	for c: int in COLUMNS:
		var width: float = size.x * WEIGHTS[c] / total
		_columns.append(Rect2(x, 0, width, size.y))
		_titles[c].position = Vector2(x, 4)
		_titles[c].size = Vector2(width, 14)
		_subtitles[c].position = Vector2(x, 19)
		_subtitles[c].size = Vector2(width, 14)
		x += width
	_lane_height = (size.y - HEADER) / 3.0
	for lane: int in 3:
		_lane_tops.append(HEADER + lane * _lane_height)
	var cells: Dictionary = {}
	for id: StringName in _slots:
		var slot: Vector2i = _slots[id]
		if not cells.has(slot):
			cells[slot] = []
		(cells[slot] as Array).append(_buttons[id])
	for slot: Vector2i in cells:
		var nodes: Array = cells[slot]
		nodes.sort_custom(_before)
		var column: Rect2 = _columns[slot.x]
		if slot.y == STACK:
			# Pile verticale : une ligne de légende, icônes plus petites, centrées dans leur part de hauteur.
			var step: float = (size.y - HEADER) / maxf(1, nodes.size())
			var stacked: float = minf(step - 6, ICON_CAPS[STACK] + 16.0)
			for i: int in nodes.size():
				var node: HunterTreeNode = nodes[i]
				node.caption_height = 16.0
				_place(node, Vector2(column.position.x + 6, HEADER + i * step + (step - stacked) * 0.5),
					Vector2(column.size.x - 12, stacked))
			continue
		var top: float = _lane_tops[slot.y] + TOP_GAP + (6.0 if slot.y == VARIANT_LANE else 0.0)
		var room: float = _lane_height - TOP_GAP - 4 - (6.0 if slot.y == VARIANT_LANE else 0.0)
		var height: float = minf(room, ICON_CAPS[slot.y] + HunterTreeNode.CAPTION_HEIGHT)
		var cell: float = column.size.x / nodes.size()
		for i: int in nodes.size():
			var node: HunterTreeNode = nodes[i]
			node.caption_height = HunterTreeNode.CAPTION_HEIGHT
			var width: float = minf(cell - 6, 132.0)
			_place(node, Vector2(column.position.x + i * cell + (cell - width) * 0.5, top + (room - height) * 0.5),
				Vector2(width, height))
	for note: Dictionary in _notes:
		var rect: Rect2 = cell_rect(note["cell"]).grow(-8)
		var control: Control = note["node"]
		control.position = rect.position
		control.size = Vector2(rect.size.x, 0)
		control.custom_minimum_size.x = rect.size.x
	queue_redraw()


## Rectangle d'une case (colonne, couloir) ; une pile occupe toute la hauteur sous l'en-tête.
func cell_rect(cell: Vector2i) -> Rect2:
	var column: Rect2 = _columns[cell.x]
	if cell.y == STACK:
		return Rect2(column.position.x, HEADER, column.size.x, size.y - HEADER)
	return Rect2(column.position.x, _lane_tops[cell.y], column.size.x, _lane_height)


## Ordre dans une case : variante A avant B, puis par niveau et nom.
func _before(a: HunterTreeNode, b: HunterTreeNode) -> bool:
	if a.data.kind == SkillNodeData.Kind.VARIANT and b.data.kind == SkillNodeData.Kind.VARIANT:
		return HunterTreeSkin.variant_letter(a.data) < HunterTreeSkin.variant_letter(b.data)
	if a.data.tier != b.data.tier:
		return a.data.tier < b.data.tier
	return String(a.data.id) < String(b.data.id)


func _place(button: HunterTreeNode, at: Vector2, extent: Vector2) -> void:
	button.position = at
	button.size = extent
	button.layout_caption()


func _draw() -> void:
	if _columns.size() < COLUMNS:
		return
	var ink: Color = HunterTreeSkin.accent(focus_branch)
	for c: int in COLUMNS:
		var rect: Rect2 = _columns[c].grow_individual(-2, 0, -2, 0)
		draw_rect(rect, Color(0.045, 0.04, 0.09, 0.82) if c % 2 == 0 else Color(0.06, 0.05, 0.11, 0.82))
		if not _open(column_gate(c)):
			# Cadenas juste à gauche du texte centré « Boss vaincus x/y ».
			var subtitle: Label = _subtitles[c]
			var width: float = subtitle.get_theme_font("font").get_string_size(subtitle.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, subtitle.get_theme_font_size("font_size")).x
			_lock(Vector2(rect.get_center().x - width * 0.5 - 9, 25))
	# Cases scellées : voile et hachures.
	for cell: Vector2i in _gates:
		if not _open(_gates[cell]):
			_veil(cell_rect(cell).grow_individual(-2, 0, -2, 0))
	# Le tronc commun à part : un trait à la couleur de la voie marque son départ.
	var start: float = _columns[1].position.x
	draw_line(Vector2(start, 6), Vector2(start, size.y - 6), Color(ink, 0.45), 2.0)
	draw_line(Vector2(0, HEADER - 2), Vector2(size.x, HEADER - 2), Color(ink, 0.25), 1.0)
	var left: float = _columns[2].position.x
	for lane: int in range(1, 3):
		draw_dashed_line(Vector2(left + 6, _lane_tops[lane]), Vector2(size.x - 6, _lane_tops[lane]), Color(ink, 0.14), 1.0,
			6.0)
	for button: HunterTreeNode in _buttons.values():
		if button.data.branch != focus_branch:
			continue
		for prereq: StringName in button.data.prerequisites:
			if _buttons.has(prereq):
				_link(_buttons[prereq], button)


## Case scellée : voile assombri et hachures.
func _veil(rect: Rect2) -> void:
	draw_rect(rect, Color(0.01, 0.01, 0.03, 0.42))
	var y: float = rect.position.y - rect.size.x
	while y < rect.end.y:
		var a := Vector2(rect.position.x, y)
		var b := Vector2(rect.end.x, y + rect.size.x)
		# Hachure coupée aux bords de la case.
		var from: Vector2 = a if a.y >= rect.position.y else a + (b - a) * ((rect.position.y - a.y) / (b.y - a.y))
		var to: Vector2 = b if b.y <= rect.end.y else a + (b - a) * ((rect.end.y - a.y) / (b.y - a.y))
		draw_line(from, to, Color(1, 1, 1, 0.025), 2.0)
		y += 14.0


func _lock(center: Vector2) -> void:
	draw_rect(Rect2(center - Vector2(5, 1), Vector2(10, 8)), HunterTreeSkin.SHORT)
	draw_arc(center - Vector2(0, 1), 3.5, PI, TAU, 10, HunterTreeSkin.SHORT, 1.6, true)


## Liens : ce qui débloque quoi. Allumés quand le prérequis est appris, dorés quand les deux sont actifs,
## en pointillés tant que rien n'est appris.
func _link(parent: HunterTreeNode, child: HunterTreeNode) -> void:
	var a: Rect2 = _frame(parent)
	var b: Rect2 = _frame(child)
	var from_slot: Vector2i = _slots[parent.data.id]
	var to_slot: Vector2i = _slots[child.data.id]
	var points := PackedVector2Array()
	if to_slot.y == VARIANT_LANE and from_slot.y == SPELL_LANE:
		# Sort → ses variantes, juste dessous : sous la légende du sort, puis au-dessus de chaque variante.
		var bottom: float = parent.position.y + parent.size.y - 4
		var mid: float = (bottom + b.position.y - 8) * 0.5
		points = PackedVector2Array([Vector2(a.get_center().x, bottom), Vector2(a.get_center().x, mid),
			Vector2(b.get_center().x, mid), Vector2(b.get_center().x, b.position.y - 9)])
	elif to_slot.y == from_slot.y:
		points = PackedVector2Array([Vector2(a.end.x + 6, a.get_center().y), Vector2(b.position.x - 6, b.get_center().y)])
	else:
		# Coude par le bord de la colonne (les passifs du niveau I se rejoignent en un seul faisceau).
		var bus: float = _columns[to_slot.x].position.x + 5
		points = PackedVector2Array([Vector2(a.end.x + 4, a.get_center().y), Vector2(bus, a.get_center().y),
			Vector2(bus, b.get_center().y), Vector2(b.position.x - 6, b.get_center().y)])
	var lit: bool = HunterTree.learned_rank(_profile, parent.data) > 0
	var active: bool = parent.current == "active" and child.current == "active"
	var color: Color = HunterTreeSkin.accent(focus_branch)
	if parent.picked or child.picked:
		color = HunterTreeSkin.CYAN
	elif active:
		color = HunterTreeSkin.GOLD
	if not lit:
		for i: int in points.size() - 1:
			draw_dashed_line(points[i], points[i + 1], Color(color, 0.35), 1.5, 5.0)
	else:
		draw_polyline(points, Color(0.025, 0.025, 0.055, 0.95), 5, true)
		draw_polyline(points, Color(color, 0.95), 2.5 if active else 2.0, true)
	_arrow(points[points.size() - 2], points[points.size() - 1], Color(color, 0.95 if lit else 0.4))
	# Variantes scellées plus longtemps que leur sort : un sceau sur l'embranchement dit combien de boss vaincre.
	var gate: int = cell_gate(to_slot)
	if to_slot.y == VARIANT_LANE and not _open(gate) and gate != column_gate(to_slot.x):
		_seal(Vector2(a.get_center().x, points[1].y), gate)


func _seal(center: Vector2, gate: int) -> void:
	var font: Font = UiKit.font(&"numbers")
	var text: String = "%d/%d" % [HunterTree.boss_wins(_profile), gate]
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 24
	var box := Rect2(center - Vector2(width * 0.5, 8), Vector2(width, 16))
	draw_rect(box, HunterTreeSkin.NIGHT)
	draw_rect(box, Color(HunterTreeSkin.SHORT, 0.7), false, 1.0)
	_lock(box.position + Vector2(9, 7))
	draw_string(font, box.position + Vector2(18, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HunterTreeSkin.SHORT)


func _arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var direction: Vector2 = (to - from).normalized()
	if direction == Vector2.ZERO:
		return
	var side: Vector2 = direction.orthogonal() * 4.0
	draw_colored_polygon(PackedVector2Array([to, to - direction * 7.0 + side, to - direction * 7.0 - side]), color)


func _frame(button: HunterTreeNode) -> Rect2:
	var rect: Rect2 = button.emblem_rect()
	rect.position += button.position
	return rect
