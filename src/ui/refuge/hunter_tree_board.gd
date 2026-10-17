class_name HunterTreeBoard
extends Control
## Une voie de l'arbre du Chasseur, entière à l'écran sans défiler : tronc commun, trois sorts et leurs variantes
## A / B, puis passifs, transformants et clé de voûte. Positions calculées depuis la taille disponible ;
## aucune règle de progression ici.

signal node_selected(id: StringName)

const TRUNK_HEIGHT := 58.0
const TRUNK_CAPTION := 16.0
## Hauteur fixe hors icônes : bande du tronc, libellés, légendes et marges.
const FIXED_HEIGHT := 250.0
const SMALL_RATIO := 0.86
const SECTION_GAP := 22.0

var focus_branch: StringName = &"blade"

var _profile: ProfileData
var _buttons: Dictionary = {}
var _sections: Dictionary = {}
var _groups: Array[Rect2] = []


func setup(p: ProfileData, selection: StringName) -> void:
	_profile = p
	custom_minimum_size = Vector2(640, 360)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for branch_id: StringName in [&"trunk", focus_branch]:
		for data: SkillNodeData in HunterTree.nodes_of_branch(branch_id):
			var button := HunterTreeNode.new()
			button.setup(p, data, selection)
			button.pressed.connect(func() -> void: node_selected.emit(data.id))
			add_child(button)
			_buttons[data.id] = button
	for key: String in ["TREE_SECTION_COMMON", "TREE_SECTION_SPELLS", "TREE_SECTION_PASSIVES",
			"TREE_SECTION_TRANSFORMS", "TREE_SECTION_KEYSTONE"]:
		var label: Label = UiKit.caption(tr(key), 11, HunterTreeSkin.MUTED)
		add_child(label)
		_sections[key] = label
	resized.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	_groups.clear()
	var w: float = size.x
	# Taille des icônes selon la hauteur disponible : grand écran = grandes icônes, 720p = tout reste visible.
	var spell_icon: float = clampf((size.y - FIXED_HEIGHT) / (1.0 + 2.0 * SMALL_RATIO), 40, 76)
	var small_icon: float = spell_icon * SMALL_RATIO
	var caption: float = HunterTreeNode.CAPTION_HEIGHT
	# Tronc commun : une bande compacte, libellé à gauche.
	var trunk: Array[SkillNodeData] = HunterTree.nodes_of_branch(&"trunk")
	_label("TREE_SECTION_COMMON", Vector2(8, 12))
	var trunk_cell: float = (w - 150) / maxf(1, trunk.size())
	for i: int in trunk.size():
		(_buttons[trunk[i].id] as HunterTreeNode).caption_height = TRUNK_CAPTION
		_place(trunk[i], Vector2(150 + i * trunk_cell + (trunk_cell - 130) * 0.5, 0), Vector2(130, TRUNK_HEIGHT))
	# Sorts et variantes : trois colonnes.
	var top: float = TRUNK_HEIGHT + 6
	_label("TREE_SECTION_SPELLS", Vector2(8, top))
	var column: float = w / 3.0
	var spells: Array[SkillNodeData] = _kind(SkillNodeData.Kind.SPELL)
	var spell_y: float = top + 26
	var variant_y: float = spell_y + spell_icon + caption + 12
	for i: int in spells.size():
		var x: float = i * column
		_groups.append(Rect2(x + 4, spell_y - 6, column - 8, variant_y + small_icon + caption + 4 - (spell_y - 6)))
		_place(spells[i], Vector2(x + column * 0.5 - 60, spell_y), Vector2(120, spell_icon + caption))
		var variants: Array[SkillNodeData] = _variants_of(spells[i])
		for j: int in variants.size():
			var step: float = minf(132, column * 0.5)
			var vx: float = x + column * 0.5 + (j - variants.size() * 0.5) * step + (step - minf(120, step - 6)) * 0.5
			_place(variants[j], Vector2(vx, variant_y), Vector2(minf(120, step - 6), small_icon + caption))
	# Passifs, transformants, clé de voûte.
	var bottom: float = variant_y + small_icon + caption + SECTION_GAP
	var node_y: float = bottom + 24
	var passives: Array[SkillNodeData] = _kind(SkillNodeData.Kind.PASSIVE)
	var transforms: Array[SkillNodeData] = _kind(SkillNodeData.Kind.TRANSFORM)
	var keystones: Array[SkillNodeData] = _kind(SkillNodeData.Kind.KEYSTONE)
	var spans: Array[float] = [0.0, w * 0.5, w * 0.8, w]
	var groups: Array = [passives, transforms, keystones]
	var keys: Array[String] = ["TREE_SECTION_PASSIVES", "TREE_SECTION_TRANSFORMS", "TREE_SECTION_KEYSTONE"]
	for g: int in 3:
		var nodes: Array = groups[g]
		var left: float = spans[g]
		var width: float = spans[g + 1] - spans[g]
		_label(keys[g], Vector2(left + 8, bottom))
		_groups.append(Rect2(left + 4, node_y - 6, width - 8, small_icon + caption + 10))
		var cell: float = width / maxf(1, nodes.size())
		for i: int in nodes.size():
			var cell_width: float = minf(cell - 4, 120)
			_place(nodes[i], Vector2(left + i * cell + (cell - cell_width) * 0.5, node_y), Vector2(cell_width, small_icon + caption))
	queue_redraw()


func _label(key: String, at: Vector2) -> void:
	var label: Label = _sections[key]
	label.position = at
	label.size = Vector2(140, 14)


func _kind(kind: int) -> Array[SkillNodeData]:
	var result: Array[SkillNodeData] = []
	for data: SkillNodeData in HunterTree.nodes_of_branch(focus_branch):
		if data.kind == kind:
			result.append(data)
	return result


func _variants_of(spell: SkillNodeData) -> Array[SkillNodeData]:
	var variants: Array[SkillNodeData] = []
	for data: SkillNodeData in _kind(SkillNodeData.Kind.VARIANT):
		if spell.id in data.prerequisites:
			variants.append(data)
	variants.sort_custom(func(a: SkillNodeData, b: SkillNodeData) -> bool:
		return HunterTreeSkin.variant_letter(a) < HunterTreeSkin.variant_letter(b))
	return variants


func _place(data: SkillNodeData, at: Vector2, extent: Vector2) -> void:
	var button: HunterTreeNode = _buttons[data.id]
	button.position = at
	button.size = extent
	button.layout_caption()


func _draw() -> void:
	var ink: Color = HunterTreeSkin.accent(focus_branch)
	for rect: Rect2 in _groups:
		draw_style_box(_group_style(ink), rect)
	for button: HunterTreeNode in _buttons.values():
		if button.data.branch != focus_branch:
			continue
		for prereq: StringName in button.data.prerequisites:
			if _buttons.has(prereq):
				_link(_buttons[prereq], button)


## Liens lisibles seulement là où ils guident : sort → sort suivant, sort → ses variantes.
func _link(parent: HunterTreeNode, child: HunterTreeNode) -> void:
	var a: Rect2 = _frame(parent)
	var b: Rect2 = _frame(child)
	var points: PackedVector2Array
	if child.data.kind == SkillNodeData.Kind.VARIANT and parent.data.kind == SkillNodeData.Kind.SPELL:
		var mid: float = (a.end.y + b.position.y) * 0.5
		points = PackedVector2Array([Vector2(a.get_center().x, a.end.y + 16), Vector2(a.get_center().x, mid),
			Vector2(b.get_center().x, mid), Vector2(b.get_center().x, b.position.y - 2)])
	elif child.data.kind == SkillNodeData.Kind.SPELL and parent.data.kind == SkillNodeData.Kind.SPELL:
		points = PackedVector2Array([Vector2(a.end.x + 26, a.get_center().y), Vector2(b.position.x - 26, b.get_center().y)])
	else:
		return
	var lit: bool = HunterTree.learned_rank(_profile, parent.data) > 0
	var selected: bool = parent.picked or child.picked
	var color: Color = HunterTreeSkin.CYAN if selected else HunterTreeSkin.accent(focus_branch)
	draw_polyline(points, Color(0.025, 0.025, 0.055, 0.95), 5, true)
	draw_polyline(points, Color(color, 0.95 if lit or selected else 0.3), 2, true)


func _frame(button: HunterTreeNode) -> Rect2:
	var rect: Rect2 = button.emblem_rect()
	rect.position += button.position
	return rect


func _group_style(ink: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.09, 0.85)
	style.border_color = Color(ink, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
