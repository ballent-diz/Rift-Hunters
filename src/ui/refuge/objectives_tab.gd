extends RefugeTab
## Objectifs : missions, succès, défis de build, collection, secrets. Condition et récompense explicites.

func title_key() -> String:
	return "TAB_OBJECTIVES"


func refresh() -> void:
	var box: VBoxContainer = scroll_box(6)
	var p: ProfileData = profile()
	var total: int = GameDB.objectives.size()
	var done: int = (p.data["objectives"]["completed"] as Array).size()
	box.add_child(UiKit.title(tr("OBJECTIVES_PROGRESS") % [done, total], 20, MenuSkin.PAPER))
	for category: int in ObjectiveData.Category.values():
		var header_added: bool = false
		for id: StringName in GameDB.sorted_ids(GameDB.objectives):
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
		texts.add_child(UiKit.label(tr("OBJECTIVE_PROGRESS") % [_fmt(value), _fmt(objective.threshold)], 13, UiKit.MUTED))
	h.add_child(UiKit.wrapped("???" if hidden else _reward_text(objective), 14, UiKit.ACCENT))
	return panel


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
