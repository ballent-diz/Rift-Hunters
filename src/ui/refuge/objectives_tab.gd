extends RefugeTab
## Objectifs : missions, succès, défis de build, collection, secrets. Condition et récompense explicites.

func title_key() -> String:
	return "TAB_OBJECTIVES"


func refresh() -> void:
	var box: VBoxContainer = scroll_box(6)
	var p: ProfileData = profile()
	var ids: Array[StringName] = Objectives.active_ids()
	var total: int = ids.size()
	var done: int = 0
	for id: StringName in ids:
		if Objectives.is_completed(p, id):
			done += 1
	box.add_child(UiKit.title(tr("OBJECTIVES_PROGRESS") % [done, total], 20, MenuSkin.PAPER))
	# En cours d'abord (les plus avancés en tête), accomplis en fin de liste.
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var done_a: bool = Objectives.is_completed(p, a)
		var done_b: bool = Objectives.is_completed(p, b)
		if done_a != done_b:
			return not done_a
		return _ratio(p, GameDB.objectives[a]) > _ratio(p, GameDB.objectives[b]))
	for category: int in ObjectiveData.Category.values():
		var header_added: bool = false
		for id: StringName in ids:
			var objective: ObjectiveData = GameDB.objectives[id]
			if objective.category != category:
				continue
			if not header_added:
				box.add_child(UiKit.title(tr("OBJECTIVE_CATEGORY_%d" % category), 17, UiKit.GOLD))
				header_added = true
			box.add_child(_row(p, objective))


func _row(p: ProfileData, objective: ObjectiveData) -> PanelContainer:
	var panel := PanelContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var completed: bool = Objectives.is_completed(p, objective.id)
	var hidden: bool = objective.hidden and not completed
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	texts.add_child(UiKit.label(("✓ " if completed else "○ ") + (tr("OBJECTIVE_SECRET") if hidden else tr(objective.name_key)), 17,
		UiKit.GOLD if completed else UiKit.TEXT))
	texts.add_child(UiKit.wrapped("???" if hidden else tr(objective.desc_key), 14))
	if not completed and not hidden:
		var value: float = Objectives.progress(p, objective)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		texts.add_child(line)
		var bar := ProgressBar.new()
		bar.name = "ObjectiveBar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = maxf(objective.threshold, 1.0)
		bar.value = minf(value, bar.max_value)
		bar.add_theme_stylebox_override("background", _bar_style(Color(0.12, 0.1, 0.18)))
		bar.add_theme_stylebox_override("fill", _bar_style(UiKit.GOLD.darkened(0.15)))
		line.add_child(bar)
		line.add_child(UiKit.label(tr("OBJECTIVE_PROGRESS") % [_fmt(value), _fmt(objective.threshold)], 13, UiKit.MUTED))
	h.add_child(UiKit.wrapped("???" if hidden else _reward_text(objective), 14, UiKit.ACCENT))
	if completed:
		panel.modulate = Color(1, 1, 1, 0.6)
	return panel


static func _ratio(p: ProfileData, objective: ObjectiveData) -> float:
	if objective.hidden:
		return -1.0
	return Objectives.progress(p, objective) / maxf(objective.threshold, 1.0)


static func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


func _reward_text(objective: ObjectiveData) -> String:
	var parts: PackedStringArray = []
	if objective.reward_shards > 0:
		parts.append(tr("REWARD_SHARDS") % objective.reward_shards)
	if objective.reward_essence > 0:
		parts.append(tr("REWARD_ESSENCE") % objective.reward_essence)
	for entry: String in objective.reward_unlocks:
		parts.append(Objectives.unlock_label(entry))
	return "\n".join(parts)


static func _fmt(value: float) -> String:
	return str(int(value)) if absf(value - round(value)) < 0.01 else "%.1f" % value
