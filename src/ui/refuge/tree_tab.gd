extends RefugeTab
## Arbre du Chasseur au refuge, pensé pour comprendre d'un coup d'œil comment faire un build :
## - en-tête : voies, améliorations du refuge, Éclats (pour apprendre), Points libres (pour activer), builds, guide ;
## - bandeau des trois étapes (apprendre → activer → équiper) et légende des états des nœuds ;
## - la voie choisie, de gauche à droite (HunterTreeBoard), et la fiche de la compétence avec son parcours pas à pas ;
## - la barre des sorts équipés en bas ; un guide en cinq pages à la première visite (TreeGuide).
## Les règles et les sauvegardes restent exclusivement dans HunterTree.

## Préférence du profil : guide déjà vu.
const GUIDE_SEEN := "tree_guide_seen"
const STEP_KEYS: Array[String] = ["TREE_STEP_LEARN", "TREE_STEP_ACTIVATE", "TREE_STEP_EQUIP"]
const STEP_HINT_KEYS: Array[String] = ["TREE_STEP_LEARN_HINT", "TREE_STEP_ACTIVATE_HINT", "TREE_STEP_EQUIP_HINT"]
const STEP_NUMBERS: Array[String] = ["①", "②", "③"]

var _selected: StringName = &"blade_cleaving_slash"
var _show_upgrades := false
var _focused_branch: StringName = &"blade"
## Page du guide affichée (-1 : fermé).
var _guide_page: int = -1


func title_key() -> String:
	return "TAB_TREE"


func refresh() -> void:
	UiKit.clear(self)
	var p: ProfileData = profile()
	if _guide_page < 0 and p.preference(GUIDE_SEEN, "") != "1":
		_guide_page = 0
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.add_child(_header(p))
	root.add_child(_steps_strip())
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	if _show_upgrades:
		split.add_child(_upgrades(p))
	else:
		split.add_child(_tree_area(p))
	split.add_child(_detail(p))
	root.add_child(_spell_bar(p))
	if _guide_page >= 0:
		var guide := TreeGuide.new()
		add_child(guide)
		guide.page_changed.connect(func(page: int) -> void: _guide_page = page)
		guide.closed.connect(_close_guide)
		guide.open(_guide_page)


## Ouvre le guide (bouton « Guide » de l'en-tête).
func open_guide() -> void:
	_guide_page = 0
	refresh()


func _close_guide() -> void:
	_guide_page = -1
	profile().set_preference(GUIDE_SEEN, "1")
	refuge.commit()
	if Profile.read_only:
		refresh()


func _select(id: StringName) -> void:
	_selected = id
	var data: SkillNodeData = GameDB.skill_node(id)
	if data and data.branch in HunterTreeSkin.PATHS:
		_focused_branch = data.branch
	refresh()
	var button: Control = find_child(str(id), true, false) as Control
	if button:
		_restore_focus.call_deferred(button)


func _restore_focus(button: Control) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


## Une ligne : voies à gauche ; Éclats, Points, builds et guide à droite.
func _header(p: ProfileData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for branch: StringName in HunterTreeSkin.PATHS:
		var data: SkillBranchData = GameDB.skill_branches[branch]
		var b: Button = HunterTreeSkin.button(tr(data.name_key), func() -> void:
			_focused_branch = branch
			_show_upgrades = false
			refresh(), branch == _focused_branch and not _show_upgrades)
		b.name = "Path_" + String(branch)
		b.custom_minimum_size.x = 92
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = tr(data.desc_key)
		if branch == _focused_branch and not _show_upgrades:
			b.add_theme_color_override("font_color", HunterTreeSkin.accent(branch))
		row.add_child(b)
	var upgrades: Button = HunterTreeSkin.button(tr("TREE_SKIN_REFUGE"), func() -> void:
		_show_upgrades = true
		refresh(), _show_upgrades)
	upgrades.name = "UpgradesToggle"
	upgrades.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	upgrades.tooltip_text = tr("TREE_UTILITIES")
	row.add_child(upgrades)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_chip("ShardsChip", "◆", HunterTreeSkin.CYAN, tr("TREE_CHIP_SHARDS"), str(p.shards()),
		tr("TREE_CHIP_SHARDS_HINT")))
	var left: int = HunterTree.points_left(p)
	row.add_child(_chip("PointsChip", "●", HunterTreeSkin.GOLD if left > 0 else HunterTreeSkin.MUTED,
		tr("TREE_CHIP_POINTS"), "%d / %d" % [left, HunterTree.points_total(p)], tr("TREE_CHIP_POINTS_HINT")))
	var build_label: Label = UiKit.caption(tr("TREE_BUILD_LABEL"), 10, HunterTreeSkin.MUTED)
	build_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(build_label)
	for i: int in HunterTree.BUILD_COUNT:
		var b: Button = HunterTreeSkin.button(str(i + 1), func() -> void:
			HunterTree.set_active_index(p, i)
			refuge.commit(), i == HunterTree.active_index(p))
		b.name = "BuildSelect%d" % i
		b.custom_minimum_size.x = 38
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = tr("TREE_BUILD_HINT") % (i + 1)
		if i == HunterTree.active_index(p):
			b.add_theme_color_override("font_color", HunterTreeSkin.GOLD)
		row.add_child(b)
	var guide: Button = HunterTreeSkin.button(tr("TREE_GUIDE_BUTTON"), open_guide)
	guide.name = "GuideButton"
	guide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	guide.tooltip_text = tr("TREE_GUIDE_HINT")
	row.add_child(guide)
	return row


## Pastille de ressource : symbole, rubrique (à quoi elle sert), valeur.
func _chip(chip_name: String, glyph: String, color: Color, caption_text: String, value: String, hint: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = chip_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.1, 0.95)
	style.border_color = color.darkened(0.4)
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", style)
	chip.tooltip_text = hint
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var icon: Label = UiKit.label(glyph, 18, color)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -3)
	row.add_child(text)
	text.add_child(UiKit.caption(caption_text, 9, HunterTreeSkin.MUTED))
	var amount: Label = UiKit.label(value, 15, color)
	amount.add_theme_font_override("font", UiKit.font(&"numbers"))
	text.add_child(amount)
	for child: Node in chip.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


## Les trois étapes d'un build, toujours sous les yeux (la légende des états est sur le plateau).
func _steps_strip() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TreeSteps"
	row.add_theme_constant_override("separation", 6)
	var colors: Array[Color] = [HunterTreeSkin.CYAN, HunterTreeSkin.GOLD, HunterTreeSkin.PAPER]
	for i: int in STEP_KEYS.size():
		var step := HBoxContainer.new()
		step.add_theme_constant_override("separation", 6)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i > 0:
			step.add_child(UiKit.label("›", 16, HunterTreeSkin.MUTED))
		step.add_child(UiKit.label(STEP_NUMBERS[i], 15, colors[i]))
		var title: Label = UiKit.caption(tr(STEP_KEYS[i]), 12, colors[i])
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step.add_child(title)
		var hint: Label = HunterTreeSkin.trimmed(tr(STEP_HINT_KEYS[i]), 13, HunterTreeSkin.MUTED)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step.add_child(hint)
		row.add_child(step)
	return row


func _tree_area(p: ProfileData) -> HunterTreeBoard:
	var board := HunterTreeBoard.new()
	board.name = "TreeBoard"
	board.focus_branch = _focused_branch
	board.setup(p, _selected)
	board.node_selected.connect(_select)
	return board


func _upgrades(p: ProfileData) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiKit.title(tr("TREE_SKIN_REFUGE"), 20, HunterTreeSkin.GOLD))
	box.add_child(UiKit.wrapped(tr("TREE_UTILITIES"), 14, HunterTreeSkin.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for raw: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
		var node: SkillNodeData = GameDB.skill_nodes[raw]
		if not node.is_utility() or not GameDB.balance.feature_enabled(node.feature):
			continue
		var b: Button = HunterTreeSkin.button("%s\n%s" % [tr(node.name_key), HunterTreeSkin.state_text(p, node)],
			func() -> void: _select(node.id), node.id == _selected)
		b.name = str(node.id)
		b.custom_minimum_size = Vector2(220, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = tr(node.desc_key)
		grid.add_child(b)
	return box


## Fiche : l'effet, puis le parcours pas à pas (apprendre, activer, équiper) et l'action conseillée en premier.
func _detail(p: ProfileData) -> SkillCard:
	var card := SkillCard.new()
	card.name = "TreeDetail"
	var node: SkillNodeData = GameDB.skill_node(_selected)
	if node == null:
		card.show_hint(tr("TREE_SELECT_HINT"))
		return card
	var state: String = HunterTreeSkin.state(p, node)
	card.show_entry({
		"title": tr(node.name_key),
		"accent": HunterTreeSkin.accent(node.branch),
		"icon": HunterTreeSkin.icon(node),
		"kind": tr(HunterTreeSkin.KIND_KEYS[node.kind]),
		"state": HunterTreeSkin.state_text(p, node),
		"state_color": HunterTreeSkin.GOLD if state == "active" else HunterTreeSkin.CYAN,
		"body": tr(node.desc_key),
		"steps_title": tr("TREE_STEPS_TITLE"),
		"steps": steps_of(p, node),
	})
	_actions(card, p, node)
	return card


## Parcours d'une compétence : où en est-on, que faire ensuite, ce qui manque.
func steps_of(p: ProfileData, node: SkillNodeData) -> Array:
	var steps: Array = [_learn_step(p, node)]
	if node.is_utility():
		steps.append({"state": "done" if HunterTree.learned_rank(p, node) > 0 else "todo", "number": 2,
			"title": tr("TREE_TITLE_EFFECT"), "detail": tr("TREE_UTILITY_ALWAYS")})
		return steps
	steps.append(_activate_step(p, node))
	steps.append(_effect_step(p, node))
	return steps


func _learn_step(p: ProfileData, node: SkillNodeData) -> Dictionary:
	var learned: int = HunterTree.learned_rank(p, node)
	var top: int = node.max_rank()
	var cost: int = HunterTree.next_cost(p, node)
	var step: Dictionary = {"number": 1, "title": tr("TREE_STEP_LEARN"), "state": "blocked"}
	match HunterTree.status(p, node):
		HunterTree.Status.LEARNED:
			step["state"] = "done"
			step["detail"] = tr("C5_KNOWN") if node.learned_by_default else (tr("TREE_DONE_LEARNED") if top == 1
				else tr("TREE_DONE_LEARNED_RANK") % [learned, top])
		HunterTree.Status.LEARNABLE:
			step["state"] = "next"
			step["detail"] = tr("TREE_NEXT_LEARN") % [cost, p.shards()] if top == 1 \
				else tr("TREE_NEXT_LEARN_RANK") % [learned + 1, top, cost, p.shards()]
		HunterTree.Status.TOO_EXPENSIVE:
			step["detail"] = tr("TREE_BLOCK_SHARDS") % [cost - p.shards(), cost]
		HunterTree.Status.GATED:
			step["detail"] = tr("TREE_BLOCK_GATE") % [node.required_wins, HunterTree.boss_wins(p), node.required_wins]
		HunterTree.Status.LOCKED:
			var names: PackedStringArray = []
			for prereq: StringName in node.prerequisites:
				var other: SkillNodeData = GameDB.skill_node(prereq)
				if other:
					names.append(tr(other.name_key))
			step["detail"] = tr("TREE_REQUIRES") % (tr("TREE_OR") if node.prerequisites_any else ", ").join(names)
		HunterTree.Status.COMING_SOON:
			step["detail"] = tr("TREE_COMING_SOON")
	return step


func _activate_step(p: ProfileData, node: SkillNodeData) -> Dictionary:
	var learned: int = HunterTree.learned_rank(p, node)
	var active: int = HunterTree.active_rank(p, node)
	var step: Dictionary = {"number": 2, "title": tr("TREE_TITLE_ACTIVATE") % (HunterTree.active_index(p) + 1)}
	if learned == 0:
		step["state"] = "todo"
		step["detail"] = tr("TREE_TODO_ACTIVATE") % node.point_cost
	elif active >= learned:
		step["state"] = "done"
		step["detail"] = tr("TREE_DONE_ACTIVE") % (active * node.point_cost)
	else:
		var error: String = HunterTree.activation_error(p, node)
		step["state"] = "next" if error == "" else "blocked"
		match error:
			"":
				step["detail"] = tr("TREE_NEXT_ACTIVATE") % [node.point_cost, HunterTree.points_left(p)]
				var rivals: PackedStringArray = []
				for rival: SkillNodeData in HunterTree.rivals(p, node):
					rivals.append(tr(rival.name_key))
				if not rivals.is_empty():
					step["detail"] += "\n" + tr("TREE_REPLACES") % ", ".join(rivals)
			"TREE_ERR_POINTS":
				step["detail"] = tr("TREE_BLOCK_POINTS") % [node.point_cost, HunterTree.points_left(p)]
			"TREE_ERR_NEEDS_SPELL":
				var spell: SkillNodeData = HunterTree.spell_node(node.spell_id)
				step["detail"] = tr("TREE_BLOCK_NEEDS_SPELL") % (tr(spell.name_key) if spell else "?")
			_:
				step["detail"] = tr(error)
	return step


## Troisième étape : équiper un sort ; pour le reste, ce que fait le nœud une fois actif.
func _effect_step(p: ProfileData, node: SkillNodeData) -> Dictionary:
	var active: int = HunterTree.active_rank(p, node)
	if node.kind == SkillNodeData.Kind.SPELL:
		var step: Dictionary = {"number": 3, "title": tr("TREE_TITLE_EQUIP")}
		var slot: int = HunterTree.slot_of(p, node.spell_id)
		if active == 0:
			step["state"] = "todo"
			step["detail"] = tr("TREE_TODO_EQUIP")
		elif slot >= 0 and HunterTree.slot_unlocked(p, slot):
			step["state"] = "done"
			step["detail"] = tr("TREE_DONE_EQUIPPED") % _key(slot)
		else:
			step["state"] = "next"
			step["detail"] = tr("TREE_NEXT_EQUIP")
		return step
	var detail: String = tr("TREE_EFFECT_AUTO")
	match node.kind:
		SkillNodeData.Kind.VARIANT:
			var spell: SkillNodeData = HunterTree.spell_node(node.spell_id)
			detail = tr("TREE_EFFECT_VARIANT") % (tr(spell.name_key) if spell else "?")
		SkillNodeData.Kind.KEYSTONE:
			detail = tr("TREE_EFFECT_KEYSTONE")
		_:
			if node.exclusive_group != &"":
				detail = tr("TREE_EXCLUSIVE_ACTIVE")
	return {"number": 3, "title": tr("TREE_TITLE_EFFECT"), "state": "done" if active > 0 else "todo", "detail": detail}


## Actions de la fiche : l'étape suivante en premier (mise en avant), puis les autres.
func _actions(card: SkillCard, p: ProfileData, node: SkillNodeData) -> void:
	if not node.implemented:
		return
	var learned: int = HunterTree.learned_rank(p, node)
	var active: int = HunterTree.active_rank(p, node)
	var cost: int = HunterTree.next_cost(p, node)
	var free: int = _free_slot(p)
	var learn: Callable = func() -> void:
		if HunterTree.learn(profile(), node):
			refuge.commit()
	var activate: Callable = func() -> void:
		if HunterTree.activate(profile(), node):
			refuge.commit()
	var equip: Callable = func() -> void:
		if HunterTree.equip(profile(), node.spell_id, free):
			refuge.commit()
	var remove: Callable = func() -> void:
		if HunterTree.deactivate(profile(), node):
			refuge.commit()
	var actions: Array[Dictionary] = []
	if cost >= 0:
		actions.append({"name": "LearnNode", "text": tr("TREE_ACTION_LEARN") % cost, "call": learn,
			"enabled": HunterTree.status(p, node) == HunterTree.Status.LEARNABLE})
	if not node.is_utility() and learned > active:
		actions.append({"name": "ActivateNode", "text": tr("TREE_ACTION_ACTIVATE") % node.point_cost, "call": activate,
			"enabled": HunterTree.activation_error(p, node) == ""})
	if node.kind == SkillNodeData.Kind.SPELL and active > 0 and HunterTree.slot_of(p, node.spell_id) < 0 and free >= 0:
		actions.append({"name": "EquipNode", "text": tr("TREE_ACTION_EQUIP") % _key(free), "call": equip, "enabled": true})
	if not node.is_utility() and active > 0:
		actions.append({"name": "DeactivateNode", "text": tr("TREE_ACTION_REMOVE"), "call": remove, "enabled": true})
	# Action conseillée : apprendre d'abord, puis activer, puis équiper ; sinon le rang suivant.
	var names: Array[String] = []
	for action: Dictionary in actions:
		names.append(action["name"])
	var primary: String = "LearnNode"
	if learned > 0:
		for candidate: String in ["ActivateNode", "EquipNode"]:
			if candidate in names:
				primary = candidate
				break
	for first: bool in [true, false]:
		for action: Dictionary in actions:
			if (action["name"] == primary) == first:
				card.add_action(action["name"], action["text"], action["call"], action["enabled"], first)


func _free_slot(p: ProfileData) -> int:
	var spells: Array = HunterTree.active_build(p)["spells"]
	for i: int in spells.size():
		if str(spells[i]) == "" and HunterTree.slot_unlocked(p, i):
			return i
	return -1


func _key(slot: int) -> String:
	return InputSetup.key_label(StringName("spell_%d" % (slot + 1)))


## Emplacement encore fermé : la carte à gagner pour l'ouvrir.
func _locked_slot(slot: int) -> Button:
	var arena: ArenaData = GameDB.arena(HunterTree.slot_unlock_arena(slot))
	var where: String = tr(arena.name_key) if arena else "?"
	# L'emplacement s'ouvre en arrivant sur la carte qui suit celle à gagner : [niveau, chapitre] de cette carte.
	var places: Array[Vector2i] = []
	var found: int = -1
	var chapters: Array[ChapterData] = Campaign.chapters_of(Campaign.MAIN)
	for c: int in chapters.size():
		for m: int in chapters[c].maps.size():
			if arena and chapters[c].maps[m].arena_id == arena.id:
				found = places.size()
			places.append(Vector2i(m + 1, c + 1))
	var place: Vector2i = places[mini(found + 1, places.size() - 1)] if found >= 0 else Vector2i.ZERO
	var b: Button = HunterTreeSkin.button(tr("TREE_SLOT_LOCKED_SHORT") % [place.x, place.y], func() -> void: pass)
	b.name = "SpellSlot%d" % slot
	b.disabled = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 42
	b.add_theme_stylebox_override("disabled", HunterTreeSkin.panel("slot_empty", 4))
	b.tooltip_text = tr("TREE_SLOT_LOCKED") % where
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	return b


## Barre des sorts équipés : cliquer un emplacement y équipe le sort sélectionné s'il est actif.
func _spell_bar(p: ProfileData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title: Label = UiKit.caption(tr("C5_EQUIPPED"), 11, HunterTreeSkin.MUTED)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = 110
	row.add_child(title)
	var spells: Array = HunterTree.active_build(p)["spells"]
	var selected: SkillNodeData = GameDB.skill_node(_selected)
	var can_equip: bool = selected != null and selected.kind == SkillNodeData.Kind.SPELL \
		and HunterTree.active_rank(p, selected) > 0
	for i: int in HunterTree.SPELL_SLOTS:
		if not HunterTree.slot_unlocked(p, i):
			row.add_child(_locked_slot(i))
			continue
		var spell: SpellData = GameDB.spells.get(StringName(str(spells[i])))
		var data: SkillNodeData = HunterTree.spell_node(spell.id) if spell else null
		var b: Button = HunterTreeSkin.button("", func() -> void:
			if can_equip and HunterTree.equip(p, selected.spell_id, i):
				refuge.commit()
			elif data:
				_show_upgrades = false
				_select(data.id))
		b.name = "SpellSlot%d" % i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 42
		b.add_theme_stylebox_override("normal", HunterTreeSkin.panel(
			"slot_focus" if can_equip else ("slot_equipped" if spell else "slot_empty"), 4))
		b.tooltip_text = tr("TREE_EQUIP_HINT")
		row.add_child(b)
		var content := HBoxContainer.new()
		b.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12
		content.offset_right = -12
		content.add_theme_constant_override("separation", 10)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_label: Label = UiKit.label(_key(i), 16, HunterTreeSkin.GOLD)
		key_label.add_theme_font_override("font", UiKit.font(&"numbers"))
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.custom_minimum_size.x = 22
		content.add_child(key_label)
		if data and HunterTreeSkin.icon(data):
			var image := TextureRect.new()
			image.texture = HunterTreeSkin.icon(data)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.custom_minimum_size.x = 30
			image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			content.add_child(image)
		var text: String = tr(spell.name_key) if spell else (tr("TREE_SLOT_PICK") if can_equip else tr("TREE_SKIN_EMPTY"))
		var label: Label = HunterTreeSkin.trimmed(text, 14, HunterTreeSkin.PAPER if spell else
			(HunterTreeSkin.CYAN if can_equip else HunterTreeSkin.MUTED))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(label)
		for child: Control in content.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row
