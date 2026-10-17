extends RefugeTab
## Arbres des Échos (docs/design/ARBRES_DES_ECHOS.md) : liste des Échos à gauche, arbre de l'Écho choisi au centre,
## fiche de la compétence à droite. Les règles restent dans EchoTree.

var _monster: StringName = &""
var _selected: StringName = &""


func title_key() -> String:
	return "TAB_ECHOES"


func refresh() -> void:
	UiKit.clear(self)
	var p: ProfileData = profile()
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	root.add_child(_list(p))
	if _monster == &"":
		return
	var monster: MonsterData = GameDB.monster(_monster)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	root.add_child(center)
	center.add_child(_header(p, monster))
	var board := EchoTreeBoard.new()
	board.name = "EchoBoard"
	board.setup(p, monster, _selected)
	board.node_selected.connect(func(id: StringName) -> void:
		_selected = id
		refresh())
	center.add_child(board)
	center.add_child(UiKit.wrapped(tr("ECHO_TREE_HINT"), 13, UiKit.MUTED))
	root.add_child(_detail(p, monster))


## Liste compacte : nom et points de chaque Écho ; l'Écho affiché est mis en avant.
func _list(p: ProfileData) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 200
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	list.add_child(UiKit.caption(tr("TAB_ECHOES"), 11, UiKit.MUTED))
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var monster: MonsterData = GameDB.monsters[id]
		if EchoTree.nodes_of(id).is_empty():
			continue
		if _monster == &"":
			_monster = id
		var unlocked: bool = p.is_monster_unlocked(monster)
		var b: Button = HunterTreeSkin.button(tr(monster.name_key), func() -> void:
			_monster = id
			_selected = &""
			refresh(), id == _monster)
		b.name = "Echo_" + String(id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 40
		if not unlocked:
			b.add_theme_color_override("font_color", HunterTreeSkin.MUTED.darkened(0.2))
			b.tooltip_text = tr("ECHO_TREE_LOCKED")
		elif EchoTree.points_used(p, id) < EchoTree.points_total(p, id):
			b.tooltip_text = tr("ECHO_TREE_POINTS") % [EchoTree.points_used(p, id), EchoTree.points_total(p, id)]
		list.add_child(b)
	return scroll


func _header(p: ProfileData, monster: MonsterData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var portrait := EchoPortrait.new()
	portrait.setup(monster, EchoPortrait.profile_palette(monster))
	portrait.custom_minimum_size = Vector2(76, 76)
	row.add_child(portrait)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 2)
	row.add_child(names)
	names.add_child(UiKit.title(tr(monster.name_key), 24, monster.visual.primary.lightened(0.4)))
	var tags: PackedStringArray = [tr("ROLE_%d" % monster.role)]
	for affinity: Variant in monster.affinities:
		tags.append(tr("AFFINITY_%s_NAME" % str(affinity).to_upper()))
	var role: String = "  ·  ".join(tags)
	names.add_child(UiKit.caption(role, 11, UiKit.MUTED))
	var technique: TechniqueData = EchoTree.chosen_technique(p, monster.id)
	if technique == null:
		technique = monster.technique
	names.add_child(UiKit.label(tr("ECHO_TREE_EQUIPPED") % tr(technique.name_key), 14, HunterTreeSkin.CYAN))
	if not p.is_monster_unlocked(monster):
		names.add_child(UiKit.label(tr("ECHO_TREE_LOCKED"), 13, UiKit.DANGER))
	var points := PanelContainer.new()
	var frame: StyleBoxTexture = HunterTreeSkin.panel("points", 8)
	frame.set_content_margin(SIDE_LEFT, 40)
	frame.set_content_margin(SIDE_RIGHT, 24)
	points.add_theme_stylebox_override("panel", frame)
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	points.tooltip_text = tr("ECHO_TREE_POINTS_HINT")
	points.mouse_filter = Control.MOUSE_FILTER_STOP
	var label: Label = UiKit.label(tr("ECHO_TREE_POINTS") % [EchoTree.points_used(p, monster.id),
		EchoTree.points_total(p, monster.id)], 14, HunterTreeSkin.GOLD)
	label.add_theme_font_override("font", UiKit.font(&"numbers"))
	points.add_child(label)
	row.add_child(points)
	return row


func _detail(p: ProfileData, monster: MonsterData) -> SkillCard:
	var card := SkillCard.new()
	card.name = "EchoDetail"
	var n: SkillNodeData = EchoTree.node(_selected)
	if n == null or n.branch != monster.id:
		card.show_hint(tr("TREE_SELECT_HINT"))
		return card
	var state: String = EchoTreeBoard.state_of(p, n)
	var facts: PackedStringArray = [tr("TREE_RANK") % [EchoTree.learned_rank(p, n), n.max_rank()]]
	if n.point_cost > 0:
		facts.append(tr("TREE_POINT_COST") % n.point_cost)
	var notes: PackedStringArray = []
	if n.kind == SkillNodeData.Kind.SPELL:
		notes.append(tr("ECHO_TREE_ONE_SPELL"))
	if not EchoTree.prerequisites_met(p, n):
		notes.append(tr("ECHO_TREE_NEEDS_PASSIVE"))
	card.show_entry({
		"title": EchoTreeBoard.display_name(n, monster),
		"accent": monster.visual.primary.lightened(0.4),
		"icon": EchoTreeBoard.node_icon(n),
		"kind": tr(HunterTreeSkin.KIND_KEYS[n.kind]),
		"state": EchoTreeBoard.state_text(p, n),
		"state_color": HunterTreeSkin.GOLD if state == "active" else HunterTreeSkin.CYAN,
		"body": EchoTreeBoard.description(n, monster),
		"facts": "  ·  ".join(facts),
		"notes": notes,
	})
	_actions(card, p, n)
	return card


func _actions(card: SkillCard, p: ProfileData, n: SkillNodeData) -> void:
	var learned: int = EchoTree.learned_rank(p, n)
	var active: int = EchoTree.active_rank(p, n)
	var cost: int = EchoTree.next_cost(p, n)
	var default_spell: bool = n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default
	if learned > active:
		var error: String = EchoTree.activation_error(p, n)
		var key: String = "ECHO_TREE_EQUIP" if n.kind == SkillNodeData.Kind.SPELL else "TREE_ACTIVATE"
		var text: String = tr(key) if n.kind == SkillNodeData.Kind.SPELL else tr(key) % n.point_cost
		card.add_action("ActivateNode", text, func() -> void:
			if EchoTree.activate(profile(), n):
				refuge.commit(), error == "", true)
		if error != "" and error != "TREE_ERR_MAX_ACTIVE":
			card.add_reason(tr(error))
	if cost >= 0:
		var status: HunterTree.Status = EchoTree.status(p, n)
		card.add_action("LearnNode", tr("TREE_LEARN") % cost, func() -> void:
			if EchoTree.learn(profile(), n):
				refuge.commit(), status == HunterTree.Status.LEARNABLE, learned == 0)
		if status == HunterTree.Status.TOO_EXPENSIVE:
			card.add_reason(tr("TREE_SKIN_NEED_SHARDS"))
	if active > 0 and not default_spell:
		card.add_action("DeactivateNode", tr("TREE_DEACTIVATE"), func() -> void:
			if EchoTree.deactivate(profile(), n):
				refuge.commit(), true)
