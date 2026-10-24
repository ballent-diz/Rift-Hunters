extends RefugeTab
## Arbre du Chasseur au refuge : une voie à la fois, entière à l'écran ; fiche de la compétence choisie à droite,
## sorts équipés en bas. Les règles et les sauvegardes restent exclusivement dans HunterTree.

var _selected: StringName = &"blade_cleaving_slash"
var _show_upgrades := false
var _focused_branch: StringName = &"blade"


func title_key() -> String:
	return "TAB_TREE"


func refresh() -> void:
	UiKit.clear(self)
	var p: ProfileData = profile()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(_header(p))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	if _show_upgrades:
		split.add_child(_upgrades(p))
	else:
		split.add_child(_tree_area(p))
	split.add_child(_detail(p))
	root.add_child(_spell_bar(p))


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


## Une seule ligne : voies à gauche, points et builds à droite.
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
		b.custom_minimum_size.x = 104
		b.tooltip_text = tr(data.desc_key)
		if branch == _focused_branch and not _show_upgrades:
			b.add_theme_color_override("font_color", HunterTreeSkin.accent(branch))
		row.add_child(b)
	var upgrades: Button = HunterTreeSkin.button(tr("TREE_SKIN_REFUGE"), func() -> void:
		_show_upgrades = true
		refresh(), _show_upgrades)
	upgrades.name = "UpgradesToggle"
	upgrades.custom_minimum_size.x = 150
	row.add_child(upgrades)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var points := PanelContainer.new()
	var points_frame: StyleBoxTexture = HunterTreeSkin.panel("points", 8)
	points_frame.set_content_margin(SIDE_LEFT, 40)
	points_frame.set_content_margin(SIDE_RIGHT, 24)
	points.add_theme_stylebox_override("panel", points_frame)
	points.tooltip_text = tr("TREE_SKIN_POINTS_HINT")
	points.mouse_filter = Control.MOUSE_FILTER_STOP
	var left: int = HunterTree.points_left(p)
	var points_label: Label = UiKit.label(tr("TREE_POINTS") % [HunterTree.points_used(p), HunterTree.points_total(p)],
		14, HunterTreeSkin.GOLD if left > 0 else HunterTreeSkin.PAPER)
	points_label.add_theme_font_override("font", UiKit.font(&"numbers"))
	points.add_child(points_label)
	row.add_child(points)
	for i: int in HunterTree.BUILD_COUNT:
		var b: Button = HunterTreeSkin.button(tr("TREE_BUILD") % (i + 1), func() -> void:
			HunterTree.set_active_index(p, i)
			refuge.commit(), i == HunterTree.active_index(p))
		b.name = "BuildSelect%d" % i
		b.custom_minimum_size.x = 76
		b.tooltip_text = tr("C5_FREE_CHANGE")
		row.add_child(b)
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


## Fiche compacte : l'essentiel sans défiler, l'action conseillée en premier.
func _detail(p: ProfileData) -> SkillCard:
	var card := SkillCard.new()
	card.name = "TreeDetail"
	var node: SkillNodeData = GameDB.skill_node(_selected)
	if node == null:
		card.show_hint(tr("TREE_SELECT_HINT"))
		return card
	var state: String = HunterTreeSkin.state(p, node)
	var facts: PackedStringArray = [tr("TREE_RANK") % [HunterTree.learned_rank(p, node), node.max_rank()]]
	if not node.is_utility():
		facts.append(tr("TREE_POINT_COST") % node.point_cost)
	card.show_entry({
		"title": tr(node.name_key),
		"accent": HunterTreeSkin.accent(node.branch),
		"icon": HunterTreeSkin.icon(node),
		"kind": tr(HunterTreeSkin.KIND_KEYS[node.kind]),
		"state": HunterTreeSkin.state_text(p, node),
		"state_color": HunterTreeSkin.GOLD if state == "active" else HunterTreeSkin.CYAN,
		"body": tr(node.desc_key),
		"facts": "  ·  ".join(facts),
		"notes": _notes(p, node),
	})
	_actions(card, p, node)
	return card


## Seulement ce qui change la décision du joueur : choix exclusifs, conditions manquantes.
func _notes(p: ProfileData, node: SkillNodeData) -> PackedStringArray:
	var notes: PackedStringArray = []
	if node.kind == SkillNodeData.Kind.KEYSTONE:
		notes.append(tr("C5_ONE_KEYSTONE"))
	elif node.kind == SkillNodeData.Kind.VARIANT:
		notes.append(tr("C5_ONE_VARIANT"))
	elif node.exclusive_group != &"":
		notes.append(tr("TREE_EXCLUSIVE_ACTIVE"))
	if not node.implemented:
		notes.append(tr("TREE_COMING_SOON"))
	if node.required_wins > HunterTree.boss_wins(p):
		notes.append(tr("TREE_GATE") % [node.required_wins, HunterTree.boss_wins(p)])
	if not HunterTree.prerequisites_met(p, node):
		var names: PackedStringArray = []
		for prereq: StringName in node.prerequisites:
			var other: SkillNodeData = GameDB.skill_node(prereq)
			if other:
				names.append(tr(other.name_key))
		notes.append(tr("TREE_REQUIRES") % (tr("TREE_OR") if node.prerequisites_any else ", ").join(names))
	if node.kind == SkillNodeData.Kind.SPELL and HunterTree.active_rank(p, node) > 0:
		notes.append(tr("TREE_EQUIP_READY"))
	return notes


func _actions(card: SkillCard, p: ProfileData, node: SkillNodeData) -> void:
	if not node.implemented:
		return
	var learned: int = HunterTree.learned_rank(p, node)
	var active: int = HunterTree.active_rank(p, node)
	var cost: int = HunterTree.next_cost(p, node)
	var status: HunterTree.Status = HunterTree.status(p, node)
	if not node.is_utility() and learned > active:
		var error: String = HunterTree.activation_error(p, node)
		card.add_action("ActivateNode", tr("TREE_ACTIVATE") % node.point_cost, func() -> void:
			if HunterTree.activate(profile(), node):
				refuge.commit(), error == "", true)
		if error != "" and error != "TREE_ERR_MAX_ACTIVE":
			card.add_reason(tr(error))
	if cost >= 0:
		card.add_action("LearnNode", tr("TREE_LEARN") % cost, func() -> void:
			if HunterTree.learn(profile(), node):
				refuge.commit(), status == HunterTree.Status.LEARNABLE, learned == 0)
		if status == HunterTree.Status.TOO_EXPENSIVE:
			card.add_reason(tr("TREE_SKIN_NEED_SHARDS"))
	if not node.is_utility() and active > 0:
		card.add_action("DeactivateNode", tr("TREE_DEACTIVATE"), func() -> void:
			if HunterTree.deactivate(profile(), node):
				refuge.commit(), true)


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


## Barre des sorts équipés (→ ↑ ← ↓) : cliquer un emplacement y équipe le sort sélectionné s'il est actif.
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
		var key_label: Label = UiKit.label(InputSetup.key_label(StringName("spell_%d" % (i + 1))), 16, HunterTreeSkin.GOLD)
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
		var label: Label = HunterTreeSkin.trimmed(tr(spell.name_key) if spell else tr("TREE_SKIN_EMPTY"), 14,
			HunterTreeSkin.PAPER if spell else HunterTreeSkin.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(label)
		for child: Control in content.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row
