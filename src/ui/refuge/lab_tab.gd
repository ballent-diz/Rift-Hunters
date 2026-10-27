extends RefugeTab
## Laboratoire : recherches payées en Essence.

func title_key() -> String:
	return "TAB_LAB"


## Une recherche payable tout de suite.
func needs_attention() -> bool:
	for item: ResearchData in Research.sorted():
		if Research.can_research(profile(), item):
			return true
	return false


func refresh() -> void:
	var box: VBoxContainer = scroll_box(10)
	var p: ProfileData = profile()
	box.add_child(UiKit.wrapped(tr("LAB_INTRO"), 15))
	for item: ResearchData in Research.sorted():
		var row := PanelContainer.new()
		box.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		row.add_child(h)
		for unlock: String in item.unlocks:
			var kind: String = unlock.get_slice(":", 0)
			var id := StringName(unlock.get_slice(":", 1))
			if kind in ["relic", "upgrade"] and ItemArt.texture(kind, id):
				var art: PanelContainer = ItemArt.portrait(kind, id, UiKit.GOLD, 72)
				art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				art.custom_minimum_size.x = 112
				h.add_child(art)
				break
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(texts)
		var done: bool = Research.is_done(p, item.id)
		texts.add_child(UiKit.label(("✓ " if done else "") + tr(item.name_key), 19, UiKit.GOLD if done else UiKit.TEXT))
		texts.add_child(UiKit.wrapped(tr(item.desc_key), 15))
		if not Research.prerequisites_met(p, item):
			var names: PackedStringArray = []
			for prereq: StringName in item.prerequisites:
				names.append(tr(GameDB.research_item(prereq).name_key))
			texts.add_child(UiKit.label(tr("TREE_REQUIRES") % ", ".join(names), 14, UiKit.DANGER))
		var button: Button = UiKit.button(tr("LAB_DONE") if done else tr("LAB_RESEARCH") % item.cost_essence,
			_research.bind(item.id), 240)
		button.disabled = not Research.can_research(p, item)
		h.add_child(button)


func _research(id: StringName) -> void:
	if Research.perform(profile(), GameDB.research_item(id)):
		refuge.commit()
