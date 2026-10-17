extends RefugeTab
## C5 : arbre gravé du Refuge. Les règles et les sauvegardes restent exclusivement dans HunterTree.

var _selected: StringName = &"blade_cleaving_slash"
var _show_upgrades := false
var _focused_branch: StringName = &"blade"
var _tree_scroll := 0


func title_key() -> String:
	return "TAB_TREE"


func refresh() -> void:
	var previous: ScrollContainer = find_child("TreeScroll", true, false) as ScrollContainer
	if previous:
		_tree_scroll = previous.scroll_vertical
	UiKit.clear(self)
	var p: ProfileData = profile()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	root.add_child(_header(p))
	root.add_child(_spell_bar(p))
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	if _show_upgrades:
		split.add_child(_upgrades(p))
	else:
		split.add_child(_tree_area(p))
	split.add_child(_detail(p))
	root.add_child(_legend())


func _select(id: StringName) -> void:
	_selected = id
	var data: SkillNodeData = GameDB.skill_node(id)
	if data and _focused_branch != &"" and data.branch in HunterTreeSkin.PATHS:
		_focused_branch = data.branch
	refresh()
	var button: Control = find_child(str(id), true, false) as Control
	if button:
		_restore_focus.call_deferred(button)


func _restore_focus(button: Control) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()
		var scroll: ScrollContainer = find_child("TreeScroll", true, false) as ScrollContainer
		if scroll:
			scroll.ensure_control_visible(button)


func _header(p: ProfileData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := HunterTreeSkin.trimmed(tr("C5_TITLE"), 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var points := PanelContainer.new()
	var points_frame: StyleBoxTexture = HunterTreeSkin.panel("points", 10)
	points_frame.set_content_margin(SIDE_LEFT, 34)
	points.add_theme_stylebox_override("panel", points_frame)
	points.tooltip_text = tr("TREE_SKIN_POINTS_HINT")
	points.add_child(UiKit.label(tr("TREE_POINTS") % [HunterTree.points_used(p), HunterTree.points_total(p)],
		14, HunterTreeSkin.GOLD))
	row.add_child(points)
	for i: int in HunterTree.BUILD_COUNT:
		var b: Button = HunterTreeSkin.button(tr("TREE_BUILD") % (i + 1), func() -> void:
			HunterTree.set_active_index(p, i)
			refuge.commit(), i == HunterTree.active_index(p))
		b.name = "BuildSelect%d" % i
		b.custom_minimum_size.x = 82
		b.tooltip_text = tr("C5_FREE_CHANGE")
		row.add_child(b)
	var toggle: Button = HunterTreeSkin.button(tr("TREE_SKIN_TREE") if _show_upgrades else tr("TREE_SKIN_REFUGE"),
		func() -> void:
			_show_upgrades = not _show_upgrades
			refresh(), _show_upgrades)
	toggle.custom_minimum_size.x = 156
	row.add_child(toggle)
	return row


func _spell_bar(p: ProfileData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var spells: Array = HunterTree.active_build(p)["spells"]
	var selected: SkillNodeData = GameDB.skill_node(_selected)
	for i: int in HunterTree.SPELL_SLOTS:
		var spell: SpellData = GameDB.spells.get(StringName(str(spells[i])))
		var data: SkillNodeData = HunterTree.spell_node(spell.id) if spell else null
		var b: Button = HunterTreeSkin.button("", func() -> void:
			if selected and selected.kind == SkillNodeData.Kind.SPELL and HunterTree.equip(p, selected.spell_id, i):
				refuge.commit()
			elif data:
				_show_upgrades = false
				_select(data.id))
		b.name = "SpellSlot%d" % i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 42
		b.add_theme_stylebox_override("normal", HunterTreeSkin.panel("slot_equipped" if spell else "slot_empty", 4))
		b.tooltip_text = tr("TREE_EQUIP_HINT")
		row.add_child(b)
		var content := HBoxContainer.new()
		b.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 14
		content.offset_right = -14
		content.add_theme_constant_override("separation", 12)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key: String = InputSetup.key_label(StringName("spell_%d" % (i + 1)))
		var key_label: Label = UiKit.label(key, 17, HunterTreeSkin.GOLD)
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.custom_minimum_size.x = 24
		content.add_child(key_label)
		if data and HunterTreeSkin.icon(data):
			var image := TextureRect.new()
			image.texture = HunterTreeSkin.icon(data)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.custom_minimum_size.x = 30
			image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			content.add_child(image)
		var label: Label = HunterTreeSkin.trimmed(tr(spell.name_key) if spell else tr("TREE_SKIN_EMPTY"), 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(label)
		for child: Control in content.get_children():
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _upgrades(p: ProfileData) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(752, 300)
	box.add_child(UiKit.label(tr("TREE_SKIN_REFUGE"), 20, HunterTreeSkin.GOLD))
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
		if not node.is_utility():
			continue
		var b: Button = HunterTreeSkin.button("%s\n%s" % [tr(node.name_key), HunterTreeSkin.state_text(p, node)],
			func() -> void: _select(node.id), node.id == _selected)
		b.name = str(node.id)
		b.custom_minimum_size = Vector2(220, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = tr(node.desc_key)
		grid.add_child(b)
	return box


func _detail(p: ProfileData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TreeDetail"
	panel.custom_minimum_size.x = 300
	panel.add_theme_stylebox_override("panel", HunterTreeSkin.panel())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var node: SkillNodeData = GameDB.skill_node(_selected)
	if node == null:
		box.add_child(UiKit.wrapped(tr("TREE_SELECT_HINT"), 16, HunterTreeSkin.MUTED))
		return panel
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var emblem := HunterTreeNode.new()
	emblem.setup(p, node, &"")
	emblem.large = true
	emblem.custom_minimum_size = Vector2(144, 144)
	emblem.disabled = true
	emblem.caption.visible = false
	var illustration := CenterContainer.new()
	illustration.add_child(emblem)
	var title: Label = UiKit.wrapped(tr(node.name_key), 20, HunterTreeSkin.accent(node.branch))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	box.add_child(UiKit.label(tr(HunterTreeSkin.KIND_KEYS[node.kind]), 12, HunterTreeSkin.MUTED))
	box.add_child(UiKit.wrapped(HunterTreeSkin.state_text(p, node), 13, HunterTreeSkin.CYAN))
	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 10)
	scroll.add_child(text)
	if HunterTreeSkin.icon(node):
		text.add_child(illustration)
	else:
		illustration.queue_free()
	text.add_child(UiKit.wrapped(tr(node.desc_key), 15, HunterTreeSkin.PAPER))
	if node.kind == SkillNodeData.Kind.KEYSTONE:
		text.add_child(UiKit.wrapped(tr("C5_ONE_KEYSTONE"), 13, HunterTreeSkin.GOLD))
	elif node.kind == SkillNodeData.Kind.VARIANT:
		text.add_child(UiKit.wrapped(tr("C5_EXCLUSIVE_AB") + " · " + tr("C5_ONE_VARIANT"), 13, HunterTreeSkin.GOLD))
	for info: String in _infos(p, node):
		text.add_child(UiKit.wrapped(info, 12, HunterTreeSkin.MUTED))
	if not node.is_utility() and node.implemented:
		var error: String = HunterTree.activation_error(p, node)
		if error != "" and error != "TREE_ERR_MAX_ACTIVE":
			text.add_child(UiKit.wrapped(tr(error), 13, HunterTreeSkin.GOLD))
	if node.kind == SkillNodeData.Kind.SPELL and HunterTree.active_rank(p, node) > 0:
		text.add_child(UiKit.wrapped(tr("TREE_EQUIP_HINT"), 13, HunterTreeSkin.CYAN))
	_actions(box, p, node)
	return panel


func _actions(box: VBoxContainer, p: ProfileData, node: SkillNodeData) -> void:
	var cost: int = HunterTree.next_cost(p, node)
	if cost >= 0 and node.implemented:
		var learn: Button = HunterTreeSkin.button(tr("TREE_LEARN") % cost, func() -> void:
			if HunterTree.learn(profile(), node):
				refuge.commit())
		learn.name = "LearnNode"
		learn.disabled = HunterTree.status(p, node) != HunterTree.Status.LEARNABLE
		box.add_child(learn)
	if not node.is_utility() and node.implemented:
		var activate: Button = HunterTreeSkin.button(tr("TREE_ACTIVATE") % node.point_cost, func() -> void:
			if HunterTree.activate(profile(), node):
				refuge.commit())
		activate.name = "ActivateNode"
		activate.disabled = HunterTree.activation_error(p, node) != ""
		box.add_child(activate)
		var deactivate: Button = HunterTreeSkin.button(tr("TREE_DEACTIVATE"), func() -> void:
			if HunterTree.deactivate(profile(), node):
				refuge.commit())
		deactivate.name = "DeactivateNode"
		deactivate.disabled = HunterTree.active_rank(p, node) == 0
		box.add_child(deactivate)


func _legend() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for item: Array in [["…", "TREE_COMING_SOON"], ["▣", "TREE_STATE_LOCKED"], ["+", "C5_LEARNABLE"],
		["✓", "TREE_STATE_LEARNED"], ["◆", "C5_ACTIVE"]]:
		row.add_child(UiKit.label(item[0] + " " + tr(item[1]), 11, HunterTreeSkin.MUTED))
	var exclusive := HunterTreeSkin.trimmed(tr("C5_EXCLUSIVE_AB") + " · " + tr("C5_ONE_KEYSTONE"), 11)
	exclusive.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exclusive.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(exclusive)
	return row


func _infos(p: ProfileData, node: SkillNodeData) -> PackedStringArray:
	var info: PackedStringArray = []
	info.append(tr("TREE_RANK") % [HunterTree.learned_rank(p, node), node.max_rank()])
	if not node.is_utility():
		info.append(tr("TREE_POINT_COST") % node.point_cost)
	if not node.implemented:
		info.append(tr("TREE_COMING_SOON"))
	if node.required_wins > 0:
		info.append(tr("TREE_GATE") % [node.required_wins, HunterTree.boss_wins(p)])
	if not node.prerequisites.is_empty():
		var names: PackedStringArray = []
		for prereq: StringName in node.prerequisites:
			var other: SkillNodeData = GameDB.skill_node(prereq)
			if other:
				names.append(tr(other.name_key))
		var joiner: String = tr("TREE_OR") if node.prerequisites_any else ", "
		info.append(tr("TREE_REQUIRES") % joiner.join(names))
	if node.exclusive_group != &"":
		info.append(tr("TREE_EXCLUSIVE_ACTIVE"))
	return info


func _tree_area(p: ProfileData) -> VBoxContainer:
	var area := VBoxContainer.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(752, 300)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 6)
	area.add_child(navigation)
	for branch: StringName in [&""] + HunterTreeSkin.PATHS:
		var label_key: String = "TREE_SKIN_OVERVIEW" if branch == &"" else (GameDB.skill_branches[branch] as SkillBranchData).name_key
		var b: Button = HunterTreeSkin.button(tr(label_key), func() -> void:
			_focused_branch = branch
			_tree_scroll = 0
			var old: ScrollContainer = find_child("TreeScroll", true, false) as ScrollContainer
			if old:
				old.scroll_vertical = 0
			refresh(), branch == _focused_branch)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.name = "TreeScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area.add_child(scroll)
	var board := HunterTreeBoard.new()
	board.name = "TreeBoard"
	board.focus_branch = _focused_branch
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL if _focused_branch == &"" else Control.SIZE_FILL
	board.setup(p, _selected)
	board.node_selected.connect(_select)
	scroll.add_child(board)
	_restore_tree_scroll.call_deferred(scroll, _tree_scroll)
	return area


func _restore_tree_scroll(scroll: ScrollContainer, value: int) -> void:
	if is_instance_valid(scroll) and scroll.is_inside_tree():
		scroll.scroll_vertical = value
