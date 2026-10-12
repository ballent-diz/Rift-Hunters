extends RefugeTab
## Préparation de l'expédition : Écho de départ (variante, palette), Tension, arène.

func title_key() -> String:
	return "TAB_EXPEDITION"


func refresh() -> void:
	var box: VBoxContainer = scroll_box(12)
	var p: ProfileData = profile()
	var selected := StringName(p.preference("starter", "mossback"))
	box.add_child(UiKit.label(tr("EXPEDITION_STARTER"), 22, UiKit.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var monster: MonsterData = GameDB.monster(id)
		if p.is_monster_unlocked(monster):
			var title: String = tr(monster.name_key) + ("  ✔" if id == selected else "")
			var desc: String = tr(monster.desc_key) + "\n" + tr("EXPEDITION_MASTERY") % Mastery.level(p, monster)
			var accent: Color = UiKit.GOLD if id == selected else monster.visual.primary.lightened(0.3)
			var card: Button = UiKit.card(tr("ROLE_%d" % monster.role), title, desc, accent, _select_starter.bind(id))
			card.custom_minimum_size = Vector2(230, 190)
			row.add_child(card)
		else:
			var locked: Button = UiKit.card(tr("EXPEDITION_LOCKED"), "???", _unlock_hint("monster:" + String(id)),
				Color(0.4, 0.4, 0.45), func() -> void: pass)
			locked.custom_minimum_size = Vector2(230, 190)
			locked.disabled = true
			row.add_child(locked)
	var starter: MonsterData = GameDB.monster(selected)
	if starter:
		var options := HBoxContainer.new()
		options.add_theme_constant_override("separation", 12)
		box.add_child(options)
		var entry: Dictionary = p.mastery_entry(selected)
		if Mastery.variant_unlocked(p, starter):
			var on: bool = bool(entry.get("use_variant", false))
			options.add_child(UiKit.button(tr(starter.variant.name_key) + (" ✔" if on else ""), _toggle.bind(selected,
					"use_variant"), 320))
			options.add_child(UiKit.wrapped(tr(starter.variant.desc_key), 14))
		if not Mastery.palette(p, starter).is_empty():
			var palette_on: bool = bool(entry.get("use_palette", false))
			options.add_child(UiKit.button(tr("EXPEDITION_PALETTE") + (" ✔" if palette_on else ""), _toggle.bind(selected,
					"use_palette"), 240))
	box.add_child(UiKit.label(tr("EXPEDITION_TENSION"), 22, UiKit.TEXT))
	var tension_row := HBoxContainer.new()
	tension_row.add_theme_constant_override("separation", 10)
	box.add_child(tension_row)
	var current_difficulty: String = p.preference("difficulty", "tension_0")
	for difficulty: DifficultyData in GameDB.difficulties_by_level():
		var unlocked: bool = p.is_difficulty_unlocked(difficulty)
		var label: String = tr(difficulty.name_key) + (" ✔" if String(difficulty.id) == current_difficulty else "")
		var button: Button = UiKit.button(label if unlocked else tr(difficulty.name_key) + " — " + tr("EXPEDITION_LOCKED"),
				_set_pref.bind("difficulty", String(difficulty.id)), 170)
		button.disabled = not unlocked
		button.tooltip_text = tr(difficulty.desc_key)
		tension_row.add_child(button)
	var difficulty_data: DifficultyData = GameDB.difficulty(StringName(current_difficulty))
	if difficulty_data:
		box.add_child(UiKit.wrapped(tr(difficulty_data.desc_key), 15))
	_add_modifiers(box, difficulty_data)
	box.add_child(UiKit.label(tr("EXPEDITION_ARENA"), 22, UiKit.TEXT))
	var arena_row := HBoxContainer.new()
	box.add_child(arena_row)
	var current_arena: String = p.preference("arena", "fractured_plain")
	for arena: ArenaData in Profile.unlocked_arenas():
		var arena_label: String = tr(arena.name_key) + (" ✔" if String(arena.id) == current_arena else "")
		var arena_button: Button = UiKit.button(arena_label, _set_pref.bind("arena", String(arena.id)), 260)
		arena_button.tooltip_text = tr(arena.desc_key)
		arena_row.add_child(arena_button)
	var go: Button = UiKit.button(tr("EXPEDITION_DEPART"), _depart, 420)
	go.custom_minimum_size.y = 60
	go.add_theme_font_size_override("font_size", 24)
	box.add_child(go)


## Pactes de risque : modificateurs cumulables, disponibles à partir d'une certaine Tension.
func _add_modifiers(box: VBoxContainer, difficulty: DifficultyData) -> void:
	if GameDB.modifiers.is_empty():
		return
	box.add_child(UiKit.label(tr("EXPEDITION_MODIFIERS"), 22, UiKit.TEXT))
	var chosen: PackedStringArray = profile().preference("modifiers", "").split(",", false)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 8)
	box.add_child(flow)
	var bonus: float = 0.0
	for id: StringName in GameDB.sorted_ids(GameDB.modifiers):
		var modifier: RunModifierData = GameDB.modifier(id)
		var allowed: bool = difficulty != null and difficulty.level >= modifier.min_difficulty
		var on: bool = chosen.has(String(id)) and allowed
		if on:
			bonus += modifier.reward_bonus
		var text: String = "%s%s (+%d %%)" % [tr(modifier.name_key), " ✔" if on else "", int(round(modifier.reward_bonus * 100.0))]
		var button: Button = UiKit.button(text, _toggle_modifier.bind(String(id)), 230)
		button.tooltip_text = tr(modifier.desc_key) + "\n" + tr("EXPEDITION_MODIFIER_MIN") % modifier.min_difficulty
		button.disabled = not allowed
		flow.add_child(button)
	box.add_child(UiKit.label(tr("EXPEDITION_MODIFIERS_BONUS") % int(round(bonus * 100.0)), 15, UiKit.GOLD))


func _toggle_modifier(id: String) -> void:
	var chosen: PackedStringArray = profile().preference("modifiers", "").split(",", false)
	if chosen.has(id):
		chosen.remove_at(chosen.find(id))
	else:
		chosen.append(id)
	_set_pref("modifiers", ",".join(chosen))


func _unlock_hint(entry: String) -> String:
	for id: StringName in GameDB.sorted_ids(GameDB.objectives):
		var objective: ObjectiveData = GameDB.objectives[id]
		if objective.reward_unlocks.has(entry):
			return tr("EXPEDITION_UNLOCK_BY") % tr(objective.desc_key)
	return tr("EXPEDITION_LOCKED")


func _select_starter(id: StringName) -> void:
	_set_pref("starter", String(id))


func _set_pref(key: String, value: String) -> void:
	profile().set_preference(key, value)
	refuge.commit()


func _toggle(id: StringName, key: String) -> void:
	var entry: Dictionary = profile().mastery_entry(id)
	entry[key] = not bool(entry.get(key, false))
	refuge.commit()


func _depart() -> void:
	Audio.play_sfx(&"ui_click")
	Router.start_run(Profile.make_run_setup(StringName(profile().preference("starter", "mossback"))))
