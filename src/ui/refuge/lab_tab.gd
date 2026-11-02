extends RefugeTab
## Laboratoire : recherches payées en Essence.

func title_key() -> String:
	return "TAB_LAB"


func unlocked() -> bool:
	return profile().essence() > 0 or not (profile().data["research"] as Array).is_empty()


## Une recherche payable tout de suite.
func needs_attention() -> bool:
	for item: ResearchData in Research.sorted():
		if Research.can_research(profile(), item):
			return true
	return false


## Vue en arbre (lot 4 des menus) : chaque recherche de base en tête de ligne, ses suites à droite, reliées par un trait.
func refresh() -> void:
	var box: VBoxContainer = scroll_box(14)
	var p: ProfileData = profile()
	box.add_child(UiKit.wrapped(tr("LAB_INTRO"), 15))
	var items: Array[ResearchData] = Research.sorted()
	for root: ResearchData in items:
		if not root.prerequisites.is_empty():
			continue
		var children: Array[ResearchData] = []
		for item: ResearchData in items:
			if item.prerequisites.has(root.id):
				children.append(item)
		var row := HBoxContainer.new()
		row.name = "Branch_" + String(root.id)
		row.add_theme_constant_override("separation", 0)
		box.add_child(row)
		var root_card: PanelContainer = _card(p, root)
		root_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(root_card)
		if children.is_empty():
			continue
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		row.add_child(_connector(column, Research.is_done(p, root.id)))
		row.add_child(column)
		for child: ResearchData in children:
			column.add_child(_card(p, child))


## Trait de la recherche de base vers chacune de ses suites (doré quand la base est faite).
func _connector(column: VBoxContainer, lit: bool) -> Control:
	var link := Control.new()
	link.custom_minimum_size = Vector2(44, 0)
	link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.draw.connect(func() -> void:
		var color: Color = UiKit.GOLD if lit else Color(UiKit.MUTED, 0.5)
		var mid_y: float = link.size.y * 0.5
		link.draw_line(Vector2(0, mid_y), Vector2(18, mid_y), color, 2.0)
		var ys: Array[float] = []
		for card: Node in column.get_children():
			var c: Control = card
			ys.append(c.position.y + c.size.y * 0.5 + column.position.y - link.position.y)
		if ys.is_empty():
			return
		link.draw_line(Vector2(18, minf(ys.min(), mid_y)), Vector2(18, maxf(ys.max(), mid_y)), color, 2.0)
		for y: float in ys:
			link.draw_line(Vector2(18, y), Vector2(44, y), color, 2.0))
	column.resized.connect(link.queue_redraw)
	return link


func _card(p: ProfileData, item: ResearchData) -> PanelContainer:
	var done: bool = Research.is_done(p, item.id)
	var ready: bool = Research.prerequisites_met(p, item)
	var accent: Color = UiKit.GOLD if done else (UiKit.ACCENT if ready else Color(0.35, 0.35, 0.42))
	var card := PanelContainer.new()
	card.name = "Research_" + String(item.id)
	card.custom_minimum_size = Vector2(430, 0)
	card.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.06, 0.045, 0.1, 0.92), Color(accent, 0.7)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	for unlock: String in item.unlocks:
		var kind: String = unlock.get_slice(":", 0)
		var id := StringName(unlock.get_slice(":", 1))
		if kind in ["relic", "upgrade"] and ItemArt.texture(kind, id):
			var art: PanelContainer = ItemArt.portrait(kind, id, accent, 56)
			art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			art.custom_minimum_size.x = 76
			art.modulate = Color.WHITE if ready else Color(0.45, 0.45, 0.5)
			h.add_child(art)
			break
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	h.add_child(texts)
	texts.add_child(UiKit.label(("✓ " if done else "") + tr(item.name_key), 17, UiKit.GOLD if done else
		(UiKit.TEXT if ready else UiKit.MUTED)))
	texts.add_child(UiKit.wrapped(tr(item.desc_key), 13, UiKit.MUTED))
	if not ready:
		var names: PackedStringArray = []
		for prereq: StringName in item.prerequisites:
			names.append(tr(GameDB.research_item(prereq).name_key))
		texts.add_child(UiKit.label(tr("TREE_REQUIRES") % ", ".join(names), 12, UiKit.DANGER))
	elif not done and not p.can_afford("essence", item.cost_essence):
		texts.add_child(UiKit.label(tr("LAB_MISSING") % (item.cost_essence - p.essence()), 12, UiKit.DANGER))
	var button: Button = UiKit.button(tr("LAB_DONE") if done else tr("LAB_RESEARCH") % item.cost_essence,
		_research.bind(item.id), 170)
	button.name = "Research"
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = not Research.can_research(p, item)
	h.add_child(button)
	return card


func _research(id: StringName) -> void:
	if Research.perform(profile(), GameDB.research_item(id)):
		refuge.commit()
