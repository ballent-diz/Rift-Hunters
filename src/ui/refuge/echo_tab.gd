extends RefugeTab
## Arbres des Échos (docs/design/ARBRES_DES_ECHOS.md), même lecture que l'arbre du Chasseur : bandeau des trois étapes
## en haut, liste des Échos à gauche ; au centre l'Écho choisi (Points d'Écho, maîtrise) et son arbre ; à droite la
## fiche de la compétence avec son parcours pas à pas. Guide à la première visite. Les règles restent dans EchoTree.

## Préférence du profil : page Échos du guide déjà vue.
const GUIDE_SEEN := "echo_guide_seen"

var _monster: StringName = &""
var _selected: StringName = &""
## Page du guide affichée (-1 : fermé).
var _guide_page: int = -1


func title_key() -> String:
	return "TAB_ECHOES"


## Un Écho débloqué avec un nœud à apprendre ou des Points d'Écho à placer.
func needs_attention() -> bool:
	var p: ProfileData = profile()
	for id: StringName in GameDB.monsters:
		if p.is_monster_unlocked(GameDB.monsters[id]) and _has_work(p, id):
			return true
	return false


static func _has_work(p: ProfileData, monster_id: StringName) -> bool:
	for n: SkillNodeData in EchoTree.nodes_of(monster_id):
		if EchoTree.status(p, n) == HunterTree.Status.LEARNABLE:
			return true
		if n.kind != SkillNodeData.Kind.SPELL and EchoTree.learned_rank(p, n) > EchoTree.active_rank(p, n) \
				and EchoTree.activation_error(p, n) == "" and EchoTree.rivals(p, n).is_empty():
			return true
	return false


func refresh() -> void:
	UiKit.clear(self)
	var p: ProfileData = profile()
	if _guide_page < 0 and p.preference(GUIDE_SEEN, "") != "1":
		_guide_page = TreeGuide.ECHO_PAGE
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	add_child(page)
	var steps: HBoxContainer = HunterTreeSkin.steps_strip(["ECHO_STEP_LEARN_HINT", "ECHO_STEP_ACTIVATE_HINT",
		"ECHO_STEP_EQUIP_HINT"])
	var guide: Button = HunterTreeSkin.button(tr("TREE_GUIDE_BUTTON"), open_guide)
	guide.name = "GuideButton"
	guide.tooltip_text = tr("TREE_GUIDE_HINT")
	steps.add_child(guide)
	page.add_child(steps)
	var root := HBoxContainer.new()
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	page.add_child(root)
	root.add_child(_list(p))
	if _monster != &"":
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
		root.add_child(_detail(p, monster))
	if _guide_page >= 0:
		var overlay := TreeGuide.new()
		add_child(overlay)
		overlay.page_changed.connect(func(index: int) -> void: _guide_page = index)
		overlay.closed.connect(_close_guide)
		overlay.open(_guide_page)


func open_guide() -> void:
	_guide_page = TreeGuide.ECHO_PAGE
	refresh()


func _close_guide() -> void:
	_guide_page = -1
	profile().set_preference(GUIDE_SEEN, "1")
	refuge.commit()
	if Profile.read_only:
		refresh()


## Liste compacte : nom et maîtrise de chaque Écho ; l'Écho affiché est mis en avant.
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
		else:
			b.tooltip_text = tr("ECHO_LIST_HINT") % [EchoTree.mastery_level(p, id),
				EchoTree.points_left(p, id), EchoTree.points_total(p, id)]
			# Quelque chose à apprendre ou à activer : un repère invite à revenir sur cet Écho.
			if _has_work(p, id):
				b.text += "  ●"
		list.add_child(b)
	return scroll


func _header(p: ProfileData, monster: MonsterData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var portrait := EchoPortrait.new()
	portrait.setup(monster, EchoPortrait.profile_palette(monster))
	portrait.custom_minimum_size = Vector2(64, 64)
	row.add_child(portrait)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 2)
	row.add_child(names)
	var title: Label = UiKit.title(tr(monster.name_key), 22, monster.visual.primary.lightened(0.4))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(title)
	var tags: PackedStringArray = [tr("ROLE_%d" % monster.role)]
	for affinity: Variant in monster.affinities:
		tags.append(tr("AFFINITY_%s_NAME" % str(affinity).to_upper()))
	var role: Label = UiKit.caption("  ·  ".join(tags), 11, UiKit.MUTED)
	role.clip_text = true
	role.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(role)
	var technique: TechniqueData = EchoTree.chosen_technique(p, monster.id)
	if technique == null:
		technique = monster.technique
	var equipped: Label = HunterTreeSkin.trimmed(tr("ECHO_TREE_EQUIPPED") % tr(technique.name_key), 13,
		HunterTreeSkin.CYAN)
	names.add_child(equipped)
	if not p.is_monster_unlocked(monster):
		names.add_child(UiKit.label(tr("ECHO_TREE_LOCKED"), 13, UiKit.DANGER))
	var left: int = EchoTree.points_left(p, monster.id)
	row.add_child(HunterTreeSkin.chip("PointsChip", "●", HunterTreeSkin.GOLD if left > 0 else HunterTreeSkin.MUTED,
		tr("ECHO_CHIP_POINTS"), "%d / %d" % [left, EchoTree.points_total(p, monster.id)], tr("ECHO_TREE_POINTS_HINT")))
	var top: int = monster.mastery.level_thresholds.size() if monster.mastery else 0
	row.add_child(HunterTreeSkin.chip("MasteryChip", "★", MenuSkin.PAPER, tr("ECHO_CHIP_MASTERY"),
		"%d / %d" % [EchoTree.mastery_level(p, monster.id), top], tr("ECHO_CHIP_MASTERY_HINT")))
	return row


func _detail(p: ProfileData, monster: MonsterData) -> SkillCard:
	var card := SkillCard.new()
	card.name = "EchoDetail"
	var n: SkillNodeData = EchoTree.node(_selected)
	if n == null or n.branch != monster.id:
		card.show_hint(tr("TREE_SELECT_HINT"))
		return card
	var state: String = EchoTreeBoard.state_of(p, n)
	card.show_entry({
		"title": EchoTreeBoard.display_name(n, monster),
		"accent": monster.visual.primary.lightened(0.4),
		"icon": EchoTreeBoard.node_icon(n),
		"kind": tr(HunterTreeSkin.KIND_KEYS[n.kind]),
		"state": EchoTreeBoard.state_text(p, n),
		"state_color": HunterTreeSkin.GOLD if state == "active" else HunterTreeSkin.CYAN,
		"body": EchoTreeBoard.description(n, monster),
		"steps_title": tr("TREE_STEPS_TITLE"),
		"steps": steps_of(p, n, monster),
	})
	_actions(card, p, n)
	return card


## Parcours d'une compétence d'Écho : apprendre (maîtrise, prérequis, Éclats), activer ou équiper, effet en partie.
func steps_of(p: ProfileData, n: SkillNodeData, monster: MonsterData) -> Array:
	return [_learn_step(p, n), _activate_step(p, n, monster), _effect_step(p, n)]


func _learn_step(p: ProfileData, n: SkillNodeData) -> Dictionary:
	var learned: int = EchoTree.learned_rank(p, n)
	var top: int = n.max_rank()
	var cost: int = EchoTree.next_cost(p, n)
	var step: Dictionary = {"number": 1, "title": tr("TREE_STEP_LEARN"), "state": "blocked"}
	match EchoTree.status(p, n):
		HunterTree.Status.LEARNED:
			step["state"] = "done"
			step["detail"] = tr("C5_KNOWN") if n.learned_by_default else (tr("TREE_DONE_LEARNED") if top == 1
				else tr("TREE_DONE_LEARNED_RANK") % [learned, top])
		HunterTree.Status.LEARNABLE:
			step["state"] = "next"
			step["detail"] = tr("TREE_NEXT_LEARN") % [cost, p.shards()] if top == 1 \
				else tr("TREE_NEXT_LEARN_RANK") % [learned + 1, top, cost, p.shards()]
		HunterTree.Status.TOO_EXPENSIVE:
			step["detail"] = tr("TREE_BLOCK_SHARDS") % [cost - p.shards(), cost]
		HunterTree.Status.GATED:
			step["detail"] = tr("ECHO_BLOCK_MASTERY") % [n.required_mastery, EchoTree.mastery_level(p, n.branch)]
		HunterTree.Status.LOCKED:
			var names: PackedStringArray = []
			for prereq: StringName in n.prerequisites:
				var other: SkillNodeData = EchoTree.node(prereq)
				if other:
					names.append(tr(other.name_key))
			step["detail"] = tr("TREE_REQUIRES") % (tr("TREE_OR") if n.prerequisites_any else ", ").join(names)
	return step


func _activate_step(p: ProfileData, n: SkillNodeData, monster: MonsterData) -> Dictionary:
	var learned: int = EchoTree.learned_rank(p, n)
	var active: int = EchoTree.active_rank(p, n)
	var spell: bool = n.kind == SkillNodeData.Kind.SPELL
	var step: Dictionary = {"number": 2, "title": tr("ECHO_TITLE_EQUIP" if spell else "ECHO_TITLE_ACTIVATE") % [
		tr(monster.name_key), HunterTree.active_index(p) + 1]}
	if learned == 0:
		step["state"] = "todo"
		step["detail"] = tr("ECHO_TODO_EQUIP") if spell else tr("ECHO_TODO_ACTIVATE") % n.point_cost
	elif active >= learned:
		step["state"] = "done"
		step["detail"] = tr("ECHO_DONE_EQUIPPED") if spell else tr("ECHO_DONE_ACTIVE") % (active * n.point_cost)
	else:
		var error: String = EchoTree.activation_error(p, n)
		step["state"] = "next" if error == "" else "blocked"
		match error:
			"":
				step["detail"] = tr("ECHO_NEXT_EQUIP") if spell else tr("ECHO_NEXT_ACTIVATE") % [n.point_cost,
					EchoTree.points_left(p, n.branch)]
				var rivals: PackedStringArray = []
				for rival: SkillNodeData in EchoTree.rivals(p, n):
					rivals.append(tr(rival.name_key))
				if not rivals.is_empty():
					step["detail"] += "\n" + tr("TREE_REPLACES") % ", ".join(rivals)
			"ECHO_TREE_ERR_POINTS":
				step["detail"] = tr("ECHO_BLOCK_POINTS") % [n.point_cost, EchoTree.points_left(p, n.branch)]
			_:
				step["detail"] = tr(error)
	return step


func _effect_step(p: ProfileData, n: SkillNodeData) -> Dictionary:
	var active: bool = EchoTree.active_rank(p, n) > 0
	var detail: String = tr("TREE_EFFECT_AUTO")
	match n.kind:
		SkillNodeData.Kind.SPELL:
			detail = tr("ECHO_EFFECT_SPELL")
		SkillNodeData.Kind.VARIANT:
			var spell: SkillNodeData = EchoTree.spell_of(n)
			detail = tr("TREE_EFFECT_VARIANT") % (EchoTreeBoard.display_name(spell, GameDB.monster(n.branch)) if spell
				else "?")
		_:
			if n.exclusive_group != &"":
				detail = tr("TREE_EXCLUSIVE_ACTIVE")
	return {"number": 3, "title": tr("TREE_TITLE_EFFECT"), "state": "done" if active else "todo", "detail": detail}


## Actions de la fiche : l'étape suivante en premier (mise en avant), puis les autres.
func _actions(card: SkillCard, p: ProfileData, n: SkillNodeData) -> void:
	var learned: int = EchoTree.learned_rank(p, n)
	var active: int = EchoTree.active_rank(p, n)
	var cost: int = EchoTree.next_cost(p, n)
	var default_spell: bool = n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default
	var learn: Callable = func() -> void:
		if EchoTree.learn(profile(), n):
			refuge.commit()
	var activate: Callable = func() -> void:
		if EchoTree.activate(profile(), n):
			refuge.commit()
	var remove: Callable = func() -> void:
		if EchoTree.deactivate(profile(), n):
			refuge.commit()
	var actions: Array[Dictionary] = []
	if cost >= 0:
		actions.append({"name": "LearnNode", "text": tr("TREE_ACTION_LEARN") % cost, "call": learn,
			"enabled": EchoTree.status(p, n) == HunterTree.Status.LEARNABLE})
	if learned > active:
		var text: String = tr("ECHO_TREE_EQUIP") if n.kind == SkillNodeData.Kind.SPELL \
			else tr("TREE_ACTION_ACTIVATE") % n.point_cost
		actions.append({"name": "ActivateNode", "text": text, "call": activate,
			"enabled": EchoTree.activation_error(p, n) == ""})
	if active > 0 and not default_spell:
		actions.append({"name": "DeactivateNode", "text": tr("TREE_ACTION_REMOVE"), "call": remove, "enabled": true})
	var primary: String = "ActivateNode" if learned > active else "LearnNode"
	for first: bool in [true, false]:
		for action: Dictionary in actions:
			if (action["name"] == primary) == first:
				card.add_action(action["name"], action["text"], action["call"], action["enabled"], first)
