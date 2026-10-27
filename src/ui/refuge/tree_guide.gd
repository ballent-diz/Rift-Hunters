class_name TreeGuide
extends Control
## Guide de l'arbre du Chasseur, ouvert à la première visite de l'onglet puis par le bouton « Guide » : cinq pages
## courtes (les voies, apprendre, activer, équiper, choisir). Illustrations provisoires faites des vrais éléments de
## l'écran (cadres d'état, icônes de sorts, touches), en attendant des visuels dédiés. La 6e page présente les arbres
## des Échos (l'onglet Échos ouvre le guide sur elle). Aucune règle de jeu.

signal page_changed(page: int)
signal closed

const PAGES := 6
## Page des arbres des Échos.
const ECHO_PAGE := 5
const WIDTH := 760.0

var page: int = 0


func _init() -> void:
	name = "TreeGuide"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Échap (ou B à la manette) ferme le guide, comme « Passer ».
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func open(p_page: int = 0) -> void:
	page = clampi(p_page, 0, PAGES - 1)
	_build()


func _go(p_page: int) -> void:
	page = clampi(p_page, 0, PAGES - 1)
	page_changed.emit(page)
	_build()


func _build() -> void:
	UiKit.clear(self)
	add_child(UiKit.dimmer(0.8))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "GuidePanel"
	panel.custom_minimum_size.x = WIDTH
	panel.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.05, 0.04, 0.1, 0.98), MenuSkin.LANTERN))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var where: Label = UiKit.caption(tr("TREE_GUIDE_PAGE") % [page + 1, PAGES], 11, HunterTreeSkin.MUTED)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(where)
	top.add_child(_dots())
	box.add_child(UiKit.title(tr("TREE_GUIDE_TITLE_%d" % (page + 1)), 24, HunterTreeSkin.GOLD))
	var art: Control = _illustration()
	art.name = "GuideArt"
	box.add_child(art)
	var body: Label = UiKit.wrapped(tr("TREE_GUIDE_BODY_%d" % (page + 1)), 15, MenuSkin.PAPER)
	body.custom_minimum_size.x = WIDTH - 40
	box.add_child(body)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	box.add_child(nav)
	if page < PAGES - 1:
		var skip: Button = UiKit.button(tr("TREE_GUIDE_SKIP"), func() -> void: closed.emit(), 120)
		skip.name = "GuideSkip"
		nav.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	if page > 0:
		var back: Button = UiKit.button(tr("TREE_GUIDE_PREV"), func() -> void: _go(page - 1), 140)
		back.name = "GuidePrev"
		nav.add_child(back)
	var last: bool = page == PAGES - 1
	var next: Button = UiKit.button(tr("TREE_GUIDE_DONE" if last else "TREE_GUIDE_NEXT"), func() -> void:
		if last:
			closed.emit()
		else:
			_go(page + 1), 170)
	next.name = "GuideNext"
	next.add_theme_stylebox_override("normal", MenuSkin.frame(Color(0.26, 0.1, 0.12), MenuSkin.LANTERN))
	next.set_meta(MenuSkin.KEEP_STYLE, true)
	nav.add_child(next)
	MenuSkin.finish(self)
	_focus.call_deferred(next)


func _focus(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func _dots() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for i: int in PAGES:
		row.add_child(UiKit.label("●" if i == page else "○", 12, HunterTreeSkin.GOLD if i == page else HunterTreeSkin.MUTED))
	return row


## Illustration de la page, centrée, hauteur fixe.
func _illustration() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.y = 118
	match page:
		0:
			for branch: StringName in HunterTreeSkin.PATHS:
				row.add_child(_path_card(branch))
		1:
			_chain(row, [_sample(&"blade_rift_leap", "locked", tr("TREE_STATE_LOCKED")),
				_sample(&"blade_rift_leap", "learnable", tr("C5_LEARNABLE"), "◆ 200"),
				_sample(&"blade_rift_leap", "learned", tr("TREE_STATE_LEARNED"))])
			row.add_child(_chip("◆", HunterTreeSkin.CYAN, tr("TREE_CHIP_SHARDS")))
		2:
			_chain(row, [_sample(&"blade_rift_leap", "learned", tr("TREE_STATE_LEARNED")),
				_sample(&"blade_rift_leap", "active", tr("TREE_LEGEND_ACTIVE"))])
			row.add_child(_chip("●", HunterTreeSkin.GOLD, tr("TREE_CHIP_POINTS")))
			row.add_child(_chip("1 2 3", HunterTreeSkin.PAPER, tr("TREE_BUILD_LABEL")))
		3:
			var spells: Array[StringName] = [&"blade_cleaving_slash", &"prism_prismatic_lance", &"blade_rift_leap", &""]
			for i: int in HunterTree.SPELL_SLOTS:
				row.add_child(_keycap(i, spells[i]))
		4:
			_chain(row, [_sample(&"blade_slash_whirlwind", "active", tr("C5_WHIRLWIND")),
				_sample(&"blade_slash_thrust", "learned", tr("C5_THRUST"))], tr("C5_EXCLUSIVE_AB"))
			var gap := Control.new()
			gap.custom_minimum_size.x = 24
			row.add_child(gap)
			row.add_child(_sample(&"blade_master", "learnable", tr("TREE_KIND_KEYSTONE")))
		5:
			_chain(row, [_echo_sample(&"ashblade_spell_base", "active"), _echo_sample(&"ashblade_spell_alt", "learned")],
				tr("ECHO_TREE_OR"))
			row.add_child(_chip("★", MenuSkin.PAPER, tr("ECHO_CHIP_MASTERY")))
			row.add_child(_chip("●", HunterTreeSkin.GOLD, tr("ECHO_CHIP_POINTS")))
	return row


## Nœuds d'exemple reliés par une flèche (ou par un mot, pour un choix exclusif).
func _chain(row: HBoxContainer, nodes: Array, joint: String = "→") -> void:
	for i: int in nodes.size():
		if i > 0:
			var arrow: Label = UiKit.label(joint, 20 if joint == "→" else 14, HunterTreeSkin.MUTED)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(arrow)
		row.add_child(nodes[i] as HunterTreeNode)


## Vrai nœud de l'arbre, figé dans un état donné.
func _sample(id: StringName, state: String, caption_text: String, tag_text: String = "") -> HunterTreeNode:
	var data: SkillNodeData = GameDB.skill_node(id)
	var node := HunterTreeNode.new()
	node.configure(data, state, 0, false, HunterTreeSkin.icon(data), caption_text)
	node.name = "GuideSample"
	node.tag = tag_text
	node.custom_minimum_size = Vector2(96, 108)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	return node


## Nœud d'un arbre d'Écho, figé dans un état donné.
func _echo_sample(id: StringName, state: String) -> HunterTreeNode:
	var data: SkillNodeData = EchoTree.node(id)
	var monster: MonsterData = GameDB.monster(data.branch)
	var node := HunterTreeNode.new()
	node.configure(data, state, 0, false, EchoTreeBoard.node_icon(data), EchoTreeBoard.display_name(data, monster),
		MenuSkin.PAPER)
	node.name = "GuideSample"
	node.custom_minimum_size = Vector2(110, 108)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	return node


func _path_card(branch: StringName) -> VBoxContainer:
	var data: SkillBranchData = GameDB.skill_branches[branch]
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 160
	card.add_theme_constant_override("separation", 4)
	var spell: SkillNodeData = null
	for node: SkillNodeData in HunterTree.nodes_of_branch(branch):
		if node.kind == SkillNodeData.Kind.SPELL:
			spell = node
			break
	var image := TextureRect.new()
	image.texture = HunterTreeSkin.icon(spell) if spell else null
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(56, 56)
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card.add_child(image)
	card.add_child(UiKit.title(tr(data.name_key), 17, HunterTreeSkin.accent(branch), HORIZONTAL_ALIGNMENT_CENTER))
	var desc: Label = UiKit.wrapped(tr(data.desc_key), 12, HunterTreeSkin.MUTED)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(desc)
	return card


func _chip(glyph: String, color: Color, caption_text: String) -> VBoxContainer:
	var chip := VBoxContainer.new()
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_theme_constant_override("separation", 2)
	chip.add_child(UiKit.label(glyph, 26, color, HORIZONTAL_ALIGNMENT_CENTER))
	var label: Label = UiKit.caption(caption_text, 10, HunterTreeSkin.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(label)
	return chip


## Touche de sort : la touche réelle, l'icône du sort ou un cadenas pour les emplacements à gagner.
func _keycap(slot: int, node_id: StringName) -> VBoxContainer:
	var cap := VBoxContainer.new()
	cap.add_theme_constant_override("separation", 4)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(84, 84)
	frame.add_theme_stylebox_override("panel", HunterTreeSkin.panel("slot_equipped" if slot < 2 else "slot_empty", 6))
	cap.add_child(frame)
	var data: SkillNodeData = GameDB.skill_node(node_id) if node_id != &"" else null
	if data and slot < 2:
		var image := TextureRect.new()
		image.texture = HunterTreeSkin.icon(data)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		frame.add_child(image)
	else:
		frame.add_child(UiKit.label(tr("TREE_GUIDE_LATER"), 11, HunterTreeSkin.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var key: Label = UiKit.label(InputSetup.key_label(StringName("spell_%d" % (slot + 1))), 16, HunterTreeSkin.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER)
	key.add_theme_font_override("font", UiKit.font(&"numbers"))
	cap.add_child(key)
	return cap
