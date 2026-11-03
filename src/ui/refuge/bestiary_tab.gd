extends RefugeTab
## Bestiaire / collection : Échos, Corrompus, reliques, synergies. Le non-découvert reste mystérieux.

## Trois rubriques (lot 4 des menus) : Échos en vignettes (silhouettes pour ceux à découvrir), Corrompus et gardiens,
## Reliques et synergies. La fiche d'un Écho montre ses chiffres en pastilles et sa maîtrise en barre.
const SECTIONS: Array[String] = ["echoes", "enemies", "lore"]

var _selection: String = ""
var _section: String = "echoes"
var _detail: RichTextLabel
var _portrait_host: PanelContainer
var _chips: HFlowContainer
var _mastery: VBoxContainer


func title_key() -> String:
	return "TAB_BESTIARY"


func refresh() -> void:
	UiKit.clear(self)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var sections := HBoxContainer.new()
	sections.name = "Sections"
	sections.add_theme_constant_override("separation", 8)
	root.add_child(sections)
	var p: ProfileData = profile()
	for section: String in SECTIONS:
		var text: String = tr("BESTIARY_SECTION_" + section.to_upper())
		if section == "echoes":
			text = tr("BESTIARY_ECHOES_COLLECTION") % [EchoCollection.owned_count(p), GameDB.monsters.size()]
		var button: Button = HunterTreeSkin.button(text, _open_section.bind(section), section == _section)
		button.name = "Section_" + section
		button.custom_minimum_size = Vector2(150, 38)
		sections.add_child(button)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 300 if _section == "echoes" else 240
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 8)
	split.add_child(detail_box)
	_portrait_host = PanelContainer.new()
	detail_box.add_child(_portrait_host)
	_chips = HFlowContainer.new()
	_chips.name = "StatChips"
	_chips.add_theme_constant_override("h_separation", 8)
	_chips.add_theme_constant_override("v_separation", 6)
	detail_box.add_child(_chips)
	_mastery = VBoxContainer.new()
	_mastery.name = "MasteryBar"
	detail_box.add_child(_mastery)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 16)
	_detail.add_theme_font_size_override("bold_font_size", 18)
	detail_box.add_child(_detail)
	var first: String = ""
	match _section:
		"echoes":
			var grid := GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 8)
			grid.add_theme_constant_override("v_separation", 8)
			list.add_child(grid)
			for id: StringName in GameDB.sorted_ids(GameDB.monsters):
				grid.add_child(_echo_tile(p, GameDB.monster(id)))
			first = "monster:" + String(GameDB.sorted_ids(GameDB.monsters)[0])
		"enemies":
			list.add_child(UiKit.title(tr("BESTIARY_ENEMIES"), 16, UiKit.ACCENT))
			for id: StringName in GameDB.sorted_ids(GameDB.enemies):
				if not GameDB.enemy(id).in_bestiary:
					continue
				_entry(list, "enemy:" + String(id), tr(GameDB.enemy(id).name_key) if p.is_discovered("enemies", id) else "???")
			for id: StringName in GameDB.sorted_ids(GameDB.bosses):
				var boss_known: bool = p.lifetime("bosses_killed") > 0 or p.data["records"]["best_time"] >= 420.0
				_entry(list, "boss:" + String(id), tr(GameDB.boss(id).name_key) if boss_known else "???")
			first = "enemy:" + String(GameDB.sorted_ids(GameDB.enemies)[0])
		_:
			if GameDB.balance.feature_enabled(&"relics"):
				list.add_child(UiKit.title(tr("BESTIARY_RELICS"), 16, UiKit.ACCENT))
				for id: StringName in GameDB.sorted_ids(GameDB.relics):
					_entry(list, "relic:" + String(id), tr(GameDB.relic(id).name_key) if p.is_discovered("relics", id)
						else "???")
			list.add_child(UiKit.title(tr("BESTIARY_SYNERGIES"), 16, UiKit.ACCENT))
			for id: StringName in GameDB.sorted_ids(GameDB.synergies):
				_entry(list, "synergy:" + String(id), tr(GameDB.synergies[id].name_key) if p.is_discovered("synergies", id)
					else "???")
			first = "synergy:" + String(GameDB.sorted_ids(GameDB.synergies)[0])
	if _selection == "" or _section_of(_selection) != _section:
		_selection = first
	_show(_selection)


func _open_section(section: String) -> void:
	_section = section
	refresh()


static func _section_of(key: String) -> String:
	match key.get_slice(":", 0):
		"monster":
			return "echoes"
		"enemy", "boss":
			return "enemies"
	return "lore"


## Vignette d'Écho : portrait s'il est connu, silhouette sombre sinon.
func _echo_tile(p: ProfileData, monster: MonsterData) -> Button:
	var known: bool = p.is_discovered("monsters", monster.id) or p.is_monster_unlocked(monster)
	var key: String = "monster:" + String(monster.id)
	var tile := Button.new()
	tile.name = "Echo_" + String(monster.id)
	tile.custom_minimum_size = Vector2(88, 96)
	tile.toggle_mode = true
	tile.button_pressed = key == _selection
	tile.tooltip_text = tr(monster.name_key) if known else "???"
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 6
	box.offset_bottom = -4
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	var portrait := EchoPortrait.new()
	portrait.setup(monster, EchoPortrait.profile_palette(monster) if known else [])
	portrait.custom_minimum_size = Vector2(0, 56)
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not known:
		portrait.modulate = Color(0.0, 0.0, 0.02, 0.85)
	box.add_child(portrait)
	var label: Label = UiKit.caption(tr(monster.name_key) if known else "???", 10,
		MenuSkin.PAPER if known else UiKit.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	tile.pressed.connect(func() -> void:
		_selection = key
		refresh())
	return tile


func _entry(list: VBoxContainer, key: String, text: String) -> void:
	var b: Button = UiKit.button(text, func() -> void:
		_selection = key
		_show(key), 220)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(b)


## Pastille « valeur + libellé ».
func _chip(label: String, value: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var frame: StyleBoxFlat = MenuSkin.frame(Color(color, 0.12), Color(color, 0.6))
	frame.set_border_width_all(1)
	frame.content_margin_left = 10
	frame.content_margin_right = 10
	frame.content_margin_top = 4
	frame.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	row.add_child(UiKit.label(value, 18, color))
	row.add_child(UiKit.caption(label, 11, UiKit.MUTED))
	return chip


func _monster_extras(monster: MonsterData) -> void:
	var p: ProfileData = profile()
	var rate: String = "%.1f" % (1.0 / maxf(monster.attack.cooldown, 0.01))
	if TranslationServer.get_locale().begins_with("fr"):
		rate = rate.replace(".", ",")
	_chips.add_child(_chip(tr("BESTIARY_CHIP_DAMAGE"), str(int(monster.attack.damage)), Color(1.0, 0.55, 0.45)))
	_chips.add_child(_chip(tr("BESTIARY_CHIP_RATE"), rate, Color(1.0, 0.85, 0.4)))
	_chips.add_child(_chip(tr("BESTIARY_CHIP_RANGE"), str(int(monster.get_range())), Color(0.5, 0.85, 1.0)))
	_chips.add_child(_chip(tr("BESTIARY_CHIP_ROLE"), tr("ROLE_%d" % monster.role), Color(0.75, 0.6, 1.0)))
	if monster.mastery == null:
		return
	var level: int = Mastery.level(p, monster)
	var thresholds: Array = monster.mastery.level_thresholds
	var xp: int = int(p.mastery_entry(monster.id)["xp"])
	var low: int = int(thresholds[level - 1]) if level > 0 and level - 1 < thresholds.size() else 0
	var high: int = int(thresholds[level]) if level < thresholds.size() else xp
	_mastery.add_child(UiKit.caption(tr("BESTIARY_MASTERY_BAR") % [level, xp, high] if level < thresholds.size()
		else tr("BESTIARY_MASTERY_MAX") % level, 12, UiKit.GOLD))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.min_value = low
	bar.max_value = maxi(high, low + 1)
	bar.value = clampi(xp, low, high)
	var back: StyleBoxFlat = MenuSkin.frame(Color(0.1, 0.08, 0.16), Color(UiKit.GOLD, 0.35))
	back.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.GOLD
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	_mastery.add_child(bar)


func _show(key: String) -> void:
	UiKit.clear(_portrait_host)
	UiKit.clear(_chips)
	UiKit.clear(_mastery)
	_portrait_host.visible = false
	var kind: String = key.get_slice(":", 0)
	var id := StringName(key.get_slice(":", 1))
	match kind:
		"monster":
			var monster: MonsterData = GameDB.monster(id)
			_detail.text = _monster_text(monster)
			if profile().is_discovered("monsters", id) or profile().is_monster_unlocked(monster):
				var portrait := EchoPortrait.new()
				portrait.custom_minimum_size.y = 130
				_portrait_host.add_child(portrait)
				portrait.setup(monster, EchoPortrait.profile_palette(monster))
				portrait.custom_minimum_size.y = 130
				_portrait_host.visible = true
				_monster_extras(monster)
		"enemy":
			_detail.text = _enemy_text(GameDB.enemy(id))
		"boss":
			var boss: BossData = GameDB.boss(id)
			_detail.text = "[b]%s[/b] — %s\n\n%s" % [tr(boss.name_key), tr(boss.title_key),
					tr("BESTIARY_BOSS_LORE_" + String(id).to_upper())]
		"relic":
			var relic: RelicData = GameDB.relic(id)
			var known: bool = profile().is_discovered("relics", id)
			_detail.text = "[b]%s[/b]\n\n%s" % [tr(relic.name_key), tr(relic.desc_key)] if known else tr("BESTIARY_UNKNOWN")
			if known and ItemArt.texture("relic", id):
				_portrait_host.add_child(ItemArt.portrait("relic", id, relic.color, 180))
				_portrait_host.visible = true
		"synergy":
			var synergy: SynergyData = GameDB.synergies[id]
			var names: PackedStringArray = []
			for m: StringName in synergy.required_monsters:
				names.append(tr(GameDB.monster(m).name_key))
			for affinity: Variant in synergy.required_affinities:
				names.append(tr("BESTIARY_SYNERGY_AFFINITY") % [int(synergy.required_affinities[affinity]),
					affinity_names([StringName(str(affinity))])])
			var body: String = tr(synergy.desc_key) if profile().is_discovered("synergies", id) else tr("BESTIARY_SYNERGY_HINT")
			_detail.text = "[b]%s[/b]\n%s\n\n%s" % [tr(synergy.name_key) if profile().is_discovered("synergies", id) else "???",
				" + ".join(names), body]


## Noms traduits des affinités (« Braise · Prédateur »).
static func affinity_names(affinities: Array) -> String:
	var names: PackedStringArray = []
	for affinity: Variant in affinities:
		names.append(TranslationServer.translate("AFFINITY_%s_NAME" % str(affinity).to_upper()))
	return " · ".join(names)


func _monster_text(m: MonsterData) -> String:
	var p: ProfileData = profile()
	if not (p.is_discovered("monsters", m.id) or p.is_monster_unlocked(m)):
		return tr("BESTIARY_UNKNOWN") + "\n\n" + EchoCollection.source_text(m)
	var lines: PackedStringArray = []
	var title: String = " ★ " + tr("MASTERY_REWARD_TITLE_NAME") if Mastery.has_title(p, m) else ""
	lines.append("[b]%s[/b] — %s%s" % [tr(m.name_key), tr("ROLE_%d" % m.role), title])
	lines.append("[i]%s[/i]" % tr(m.lore_key))
	lines.append(tr("BESTIARY_AFFINITIES") % affinity_names(m.affinities))
	# Dégâts, cadence et portée : en pastilles au-dessus. Les Échos sont invulnérables, d'où l'absence de PV.
	lines.append("[color=#8899bb]%s[/color]" % tr("BESTIARY_NEVER_FALLS"))
	lines.append("[color=#ffd966]%s[/color] : %s" % [tr(m.passive_name_key), tr(m.passive_desc_key)])
	lines.append("[color=#8ce6ff]%s[/color] : %s" % [tr(m.technique.name_key), tr(m.technique.desc_key)])
	if GameDB.balance.feature_enabled(&"evolutions"):
		lines.append("\n[b]%s[/b]" % tr("BESTIARY_EVOLUTIONS"))
	for evo: EvolutionData in m.evolutions if GameDB.balance.feature_enabled(&"evolutions") else []:
		if evo.secret and not p.is_discovered("evolutions", evo.id):
			lines.append("• ??? — [i]%s[/i]" % tr(evo.hint_key))
		else:
			var seen: String = "" if p.is_discovered("evolutions", evo.id) else " (" + tr("BESTIARY_NOT_SEEN") + ")"
			lines.append("• %s%s : %s" % [tr(evo.name_key), seen, tr(evo.desc_key)])
	var entry: Dictionary = p.mastery_entry(m.id)
	var lvl: int = Mastery.level(p, m)
	var next: String = str(m.mastery.level_thresholds[lvl]) if lvl < m.mastery.level_thresholds.size() else "—"
	lines.append("\n[b]%s[/b] %s" % [tr("BESTIARY_MASTERY"), tr("BESTIARY_MASTERY_LEVEL") % [lvl, int(entry["xp"]), next]])
	for challenge: MasteryChallengeData in m.mastery.challenges:
		var done: bool = (entry["challenges"] as Array).has(String(challenge.id))
		var progress: float = p.lifetime(String(challenge.stat_key)) if challenge.lifetime else 0.0
		var progress_text: String = " (%d/%d)" % [int(progress),
				int(challenge.threshold)] if challenge.lifetime and not done else ""
		lines.append("%s %s%s  [color=#8899bb]+%d XP[/color]" % ["✓" if done else "○", tr(challenge.desc_key), progress_text,
				challenge.xp])
	for reward: MasteryRewardData in m.mastery.rewards:
		var unlocked: bool = reward.level <= lvl
		lines.append("%s %s %d — %s : %s" % ["★" if unlocked else "☆", tr("BESTIARY_LEVEL"), reward.level,
				tr(reward.name_key), tr(reward.desc_key)])
	return "\n".join(lines)


func _enemy_text(e: EnemyData) -> String:
	var p: ProfileData = profile()
	if not p.is_discovered("enemies", e.id):
		return tr("BESTIARY_UNKNOWN")
	var text: String = "[b]%s[/b]\n\n%s\n\n%s" % [tr(e.name_key), tr(e.desc_key),
			tr("BESTIARY_KILLS") % int(p.lifetime("kills_" + String(e.id)))]
	if p.has_unlock("info", &"enemies"):
		text += "\n" + tr("BESTIARY_ENEMY_STATS") % [int(e.max_hp), int(e.damage), int(e.defense), int(e.move_speed)]
	else:
		text += "\n[i]" + tr("BESTIARY_RESEARCH_HINT") + "[/i]"
	return text
