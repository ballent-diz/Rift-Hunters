class_name EchoTreeBoard
extends Control
## Arbre d'un Écho (docs/design/ARBRES_DES_ECHOS.md), lu de gauche à droite comme celui du Chasseur : fondations
## (Puissance, Concentration), sort d'origine, second sort (« ou » : un seul équipé), apogée (signatures). Sous chaque
## sort : ses variantes A ou B, puis un talent. Chaque colonne dit si la maîtrise l'a ouverte ; les cases encore
## scellées sont voilées. Seuls les couloirs qui ont des nœuds sont affichés. Affichage seul : états lus dans EchoTree.

signal node_selected(id: StringName)

const ROLES := {"_might": &"might", "_focus": &"focus", "_spell_base": &"spell", "_spell_alt": &"spell",
	"_signature": &"signature"}
const COLUMNS := 4
const WEIGHTS: Array[float] = [0.9, 1.1, 1.1, 0.9]
const COLUMN_KEYS: Array[String] = ["ECHO_COLUMN_BASE", "ECHO_COLUMN_ORIGIN", "ECHO_COLUMN_SECOND", "ECHO_COLUMN_APEX"]
const HEADER := 38.0
const STACK := -1
const SPELL_LANE := 0
const VARIANT_LANE := 1
const TALENT_LANE := 2
const ICON_CAPS := {STACK: 76.0, SPELL_LANE: 96.0, VARIANT_LANE: 76.0, TALENT_LANE: 84.0}

var _profile: ProfileData
var _monster: MonsterData
## Nœuds affichés, par identifiant.
var _buttons: Dictionary = {}
var _slots: Dictionary = {}
var _gates: Dictionary = {}
var _lanes: Array[int] = []
var _columns: Array[Rect2] = []
var _lane_tops: Dictionary = {}
var _lane_height: float = 0.0
var _titles: Array[Label] = []
var _subtitles: Array[Label] = []
var _or_label: Label


func setup(p: ProfileData, monster: MonsterData, selected: StringName) -> void:
	_profile = p
	_monster = monster
	custom_minimum_size = Vector2(380, 260)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for n: SkillNodeData in EchoTree.nodes_of(monster.id):
		var button := HunterTreeNode.new()
		button.symbol = role(n)
		button.configure(n, state_of(p, n), EchoTree.active_rank(p, n) if EchoTree.active_rank(p, n) > 0
			else EchoTree.learned_rank(p, n), n.id == selected, node_icon(n), display_name(n, monster), MenuSkin.PAPER)
		button.set_tip(display_name(n, monster), tr(HunterTreeSkin.KIND_KEYS[n.kind]), state_text(p, n),
			description(n, monster))
		var status: HunterTree.Status = EchoTree.status(p, n)
		if status in [HunterTree.Status.LEARNABLE, HunterTree.Status.TOO_EXPENSIVE]:
			button.tag = "◆ %d" % EchoTree.next_cost(p, n)
			button.tag_color = HunterTreeSkin.CYAN if status == HunterTree.Status.LEARNABLE else HunterTreeSkin.SHORT
		button.pressed.connect(func() -> void: node_selected.emit(n.id))
		add_child(button)
		_buttons[n.id] = button
		var cell: Vector2i = slot_of(n)
		_slots[n.id] = cell
		_gates[cell] = maxi(int(_gates.get(cell, 0)), n.required_mastery)
		if cell.y != STACK and not cell.y in _lanes:
			_lanes.append(cell.y)
	_lanes.sort()
	if _lanes.is_empty():
		_lanes.append(SPELL_LANE)
	for c: int in COLUMNS:
		var title: Label = UiKit.caption(tr(COLUMN_KEYS[c]), 11, HunterTreeSkin.PAPER)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title)
		_titles.append(title)
		var gate: int = column_gate(c)
		var subtitle: Label = UiKit.label(_gate_text(gate), 11, HunterTreeSkin.MUTED if _open(gate) else HunterTreeSkin.SHORT,
			HORIZONTAL_ALIGNMENT_CENTER)
		subtitle.add_theme_font_override("font", UiKit.font(&"numbers"))
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(subtitle)
		_subtitles.append(subtitle)
	_or_label = UiKit.title(tr("ECHO_TREE_OR"), 16, HunterTreeSkin.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_or_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_or_label)
	resized.connect(_layout)
	_layout.call_deferred()


## Case d'un nœud : fondations et apogée en piles, les sorts en haut de leur colonne, variantes et talents dessous.
static func slot_of(n: SkillNodeData) -> Vector2i:
	match n.kind:
		SkillNodeData.Kind.SPELL:
			return Vector2i(1 if n.learned_by_default else 2, SPELL_LANE)
		SkillNodeData.Kind.VARIANT:
			var spell: SkillNodeData = EchoTree.spell_of(n)
			return Vector2i(slot_of(spell).x if spell else 1, VARIANT_LANE)
		SkillNodeData.Kind.TRANSFORM:
			return Vector2i(1 if n.tier <= 1 else 2, TALENT_LANE)
	return Vector2i(0 if n.tier == 0 else COLUMNS - 1, STACK)


## Les symboles existants restent visibles si une illustration manque.
static func node_icon(n: SkillNodeData) -> Texture2D:
	var id := StringName("icon.echo." + String(n.id))
	return Assets.icon(id) if not Assets.entry(id).is_empty() else null


static func role_key(n: SkillNodeData) -> String:
	for suffix: String in ROLES:
		if String(n.id).ends_with(suffix):
			return suffix
	return String(n.id)


static func role(n: SkillNodeData) -> StringName:
	return ROLES.get(role_key(n), &"")


## Le sort d'origine porte le nom et la description de la Technique de l'Écho.
static func display_name(n: SkillNodeData, monster: MonsterData) -> String:
	if n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default:
		return TranslationServer.translate(monster.technique.name_key)
	return TranslationServer.translate(n.name_key)


static func description(n: SkillNodeData, monster: MonsterData) -> String:
	if n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default:
		return TranslationServer.translate(monster.technique.desc_key)
	return TranslationServer.translate(n.desc_key)


static func state_of(p: ProfileData, n: SkillNodeData) -> String:
	if EchoTree.active_rank(p, n) > 0:
		return "active"
	match EchoTree.status(p, n):
		HunterTree.Status.LEARNED:
			return "learned"
		HunterTree.Status.LEARNABLE:
			return "learnable"
	return "learned" if EchoTree.learned_rank(p, n) > 0 else "locked"


static func state_text(p: ProfileData, n: SkillNodeData) -> String:
	var keys := {"active": "C5_ACTIVE", "learned": "TREE_STATE_LEARNED", "learnable": "C5_LEARNABLE",
		"locked": "TREE_STATE_LOCKED"}
	if EchoTree.status(p, n) == HunterTree.Status.TOO_EXPENSIVE and EchoTree.learned_rank(p, n) == 0:
		return TranslationServer.translate("TREE_SKIN_NEED_SHARDS")
	return TranslationServer.translate(keys[state_of(p, n)])


## Maîtrise nécessaire pour la case principale d'une colonne (pile ou sort).
func column_gate(column: int) -> int:
	return int(_gates.get(Vector2i(column, STACK), _gates.get(Vector2i(column, SPELL_LANE), 0)))


func _open(gate: int) -> bool:
	return EchoTree.mastery_level(_profile, _monster.id) >= gate


func _gate_text(gate: int) -> String:
	if _open(gate):
		return tr("TREE_GATE_OPEN")
	return tr("ECHO_GATE_MASTERY") % [EchoTree.mastery_level(_profile, _monster.id), gate]


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
	_lane_height = (size.y - HEADER) / _lanes.size()
	for i: int in _lanes.size():
		_lane_tops[_lanes[i]] = HEADER + i * _lane_height
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
			var step: float = (size.y - HEADER) / maxf(1, nodes.size())
			var stacked: float = minf(step - 6, ICON_CAPS[STACK] + HunterTreeNode.CAPTION_HEIGHT)
			for i: int in nodes.size():
				var node: HunterTreeNode = nodes[i]
				node.caption_height = HunterTreeNode.CAPTION_HEIGHT
				_place(node, Vector2(column.position.x + 6, HEADER + i * step + (step - stacked) * 0.5),
					Vector2(column.size.x - 12, stacked))
			continue
		var top: float = _lane_tops[slot.y] + 8
		var room: float = _lane_height - 12
		var height: float = minf(room, ICON_CAPS[slot.y] + HunterTreeNode.CAPTION_HEIGHT)
		var cell: float = column.size.x / nodes.size()
		for i: int in nodes.size():
			var node: HunterTreeNode = nodes[i]
			node.caption_height = HunterTreeNode.CAPTION_HEIGHT
			var width: float = minf(cell - 6, 132.0)
			_place(node, Vector2(column.position.x + i * cell + (cell - width) * 0.5, top + (room - height) * 0.5),
				Vector2(width, height))
	# « ou » entre les deux sorts, sur la frontière des colonnes.
	var spells: Array = cells.get(Vector2i(1, SPELL_LANE), [])
	var middle: float = _columns[2].position.x
	var y: float = _lane_tops.get(SPELL_LANE, HEADER) + 8.0
	if not spells.is_empty():
		var spell: HunterTreeNode = spells[0]
		y = spell.position.y + spell.emblem_rect().get_center().y - 12
	_or_label.position = Vector2(middle - 30, y)
	_or_label.size = Vector2(60, 24)
	queue_redraw()


func _before(a: HunterTreeNode, b: HunterTreeNode) -> bool:
	if a.data.kind == SkillNodeData.Kind.VARIANT and b.data.kind == SkillNodeData.Kind.VARIANT:
		return HunterTreeSkin.variant_letter(a.data) < HunterTreeSkin.variant_letter(b.data)
	if a.data.tier != b.data.tier:
		return a.data.tier < b.data.tier
	# Puissance avant Concentration, puis l'ordre des identifiants.
	var order: Array = ROLES.keys()
	var ra: int = order.find(role_key(a.data))
	var rb: int = order.find(role_key(b.data))
	if ra != rb:
		return ra < rb
	return String(a.data.id) < String(b.data.id)


func _place(button: HunterTreeNode, at: Vector2, extent: Vector2) -> void:
	button.position = at
	button.size = extent
	button.layout_caption()


func _cell_rect(cell: Vector2i) -> Rect2:
	var column: Rect2 = _columns[cell.x]
	if cell.y == STACK:
		return Rect2(column.position.x, HEADER, column.size.x, size.y - HEADER)
	return Rect2(column.position.x, _lane_tops[cell.y], column.size.x, _lane_height)


func _draw() -> void:
	if _columns.size() < COLUMNS:
		return
	var ink: Color = _monster.visual.primary.lightened(0.4)
	for c: int in COLUMNS:
		var rect: Rect2 = _columns[c].grow_individual(-2, 0, -2, 0)
		draw_rect(rect, Color(0.045, 0.04, 0.09, 0.82) if c % 2 == 0 else Color(0.06, 0.05, 0.11, 0.82))
		if not _open(column_gate(c)):
			var subtitle: Label = _subtitles[c]
			var width: float = subtitle.get_theme_font("font").get_string_size(subtitle.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, subtitle.get_theme_font_size("font_size")).x
			HunterTreeSkin.draw_lock(self, Vector2(rect.get_center().x - width * 0.5 - 9, 25))
	for cell: Vector2i in _gates:
		if not _open(_gates[cell]):
			HunterTreeSkin.draw_veil(self, _cell_rect(cell).grow_individual(-2, 0, -2, 0))
	draw_line(Vector2(0, HEADER - 2), Vector2(size.x, HEADER - 2), Color(ink, 0.25), 1.0)
	for lane: int in _lanes:
		if lane != _lanes[0]:
			var y: float = _lane_tops[lane]
			draw_dashed_line(Vector2(_columns[1].position.x + 6, y), Vector2(_columns[3].position.x - 6, y),
				Color(ink, 0.14), 1.0, 6.0)
	# Les deux sorts s'excluent : pointillés de part et d'autre du « ou ».
	var base: HunterTreeNode = null
	var alt: HunterTreeNode = null
	for button: HunterTreeNode in _buttons.values():
		if button.data.kind == SkillNodeData.Kind.SPELL:
			if button.data.learned_by_default:
				base = button
			else:
				alt = button
		for prereq: StringName in button.data.prerequisites:
			var parent: HunterTreeNode = _buttons.get(prereq)
			if parent and button.data.kind == SkillNodeData.Kind.VARIANT and parent.data.kind == SkillNodeData.Kind.SPELL:
				_fork(parent, button)
	if base and alt:
		var y: float = _or_label.position.y + 12
		var gold := Color(HunterTreeSkin.GOLD, 0.55)
		var a: Rect2 = _frame(base)
		var b: Rect2 = _frame(alt)
		draw_dashed_line(Vector2(a.end.x + 8, y), Vector2(_or_label.position.x, y), gold, 1.5, 6)
		draw_dashed_line(Vector2(_or_label.position.x + _or_label.size.x, y), Vector2(b.position.x - 8, y), gold, 1.5, 6)


func _fork(parent: HunterTreeNode, child: HunterTreeNode) -> void:
	var a: Rect2 = _frame(parent)
	var b: Rect2 = _frame(child)
	var bottom: float = parent.position.y + parent.size.y - 4
	var mid: float = (bottom + b.position.y - 8) * 0.5
	var points := PackedVector2Array([Vector2(a.get_center().x, bottom), Vector2(a.get_center().x, mid),
		Vector2(b.get_center().x, mid), Vector2(b.get_center().x, b.position.y - 9)])
	var lit: bool = EchoTree.learned_rank(_profile, parent.data) > 0
	var color: Color = HunterTreeSkin.CYAN if parent.picked or child.picked else MenuSkin.PAPER
	draw_polyline(points, Color(0.025, 0.025, 0.055, 0.95), 5, true)
	draw_polyline(points, Color(color, 0.9 if lit else 0.3), 2.0, true)


func _frame(button: HunterTreeNode) -> Rect2:
	var rect: Rect2 = button.emblem_rect()
	rect.position += button.position
	return rect
