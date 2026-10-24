extends RefugeTab
## Bestiaire / collection : Échos, Corrompus, reliques, synergies. Le non-découvert reste mystérieux.

var _selection: String = ""
var _detail: RichTextLabel
var _portrait_host: PanelContainer


func title_key() -> String:
	return "TAB_BESTIARY"


func refresh() -> void:
	UiKit.clear(self)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	add_child(split)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 240
	split.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 16)
	_detail.add_theme_font_size_override("bold_font_size", 18)
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail_box)
	_portrait_host = PanelContainer.new()
	detail_box.add_child(_portrait_host)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(_detail)
	var p: ProfileData = profile()
	list.add_child(UiKit.title(tr("BESTIARY_ECHOES_COLLECTION") % [EchoCollection.owned_count(p), GameDB.monsters.size()],
		16, UiKit.ACCENT))
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var known: bool = p.is_discovered("monsters", id) or p.is_monster_unlocked(GameDB.monster(id))
		_entry(list, "monster:" + String(id), tr(GameDB.monster(id).name_key) if known else "???")
	list.add_child(UiKit.title(tr("BESTIARY_ENEMIES"), 16, UiKit.ACCENT))
	for id: StringName in GameDB.sorted_ids(GameDB.enemies):
		_entry(list, "enemy:" + String(id), tr(GameDB.enemy(id).name_key) if p.is_discovered("enemies", id) else "???")
	for id: StringName in GameDB.sorted_ids(GameDB.bosses):
		var boss_known: bool = p.lifetime("bosses_killed") > 0 or p.data["records"]["best_time"] >= 420.0
		_entry(list, "boss:" + String(id), tr(GameDB.boss(id).name_key) if boss_known else "???")
	if GameDB.balance.feature_enabled(&"relics"):
		list.add_child(UiKit.title(tr("BESTIARY_RELICS"), 16, UiKit.ACCENT))
	for id: StringName in GameDB.sorted_ids(GameDB.relics) if GameDB.balance.feature_enabled(&"relics") else []:
		_entry(list, "relic:" + String(id), tr(GameDB.relic(id).name_key) if p.is_discovered("relics", id) else "???")
	list.add_child(UiKit.title(tr("BESTIARY_SYNERGIES"), 16, UiKit.ACCENT))
	for id: StringName in GameDB.sorted_ids(GameDB.synergies):
		_entry(list, "synergy:" + String(id), tr(GameDB.synergies[id].name_key) if p.is_discovered("synergies", id) else "???")
	if _selection == "":
		_selection = "monster:" + String(GameDB.sorted_ids(GameDB.monsters)[0])
	_show(_selection)


func _entry(list: VBoxContainer, key: String, text: String) -> void:
	var b: Button = UiKit.button(text, func() -> void:
		_selection = key
		_show(key), 220)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(b)


func _show(key: String) -> void:
	UiKit.clear(_portrait_host)
	_portrait_host.visible = false
	var kind: String = key.get_slice(":", 0)
	var id := StringName(key.get_slice(":", 1))
	match kind:
		"monster":
			var monster: MonsterData = GameDB.monster(id)
			_detail.text = _monster_text(monster)
			if profile().is_discovered("monsters", id) or profile().is_monster_unlocked(monster):
				var portrait := EchoPortrait.new()
				portrait.custom_minimum_size.y = 170
				_portrait_host.add_child(portrait)
				portrait.setup(monster, EchoPortrait.profile_palette(monster))
				portrait.custom_minimum_size.y = 170
				_portrait_host.visible = true
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
	# Les Échos sont invulnérables : on montre ce qui compte en combat (dégâts, cadence, portée), pas des PV.
	var rate: String = "%.1f" % (1.0 / maxf(m.attack.cooldown, 0.01))
	if TranslationServer.get_locale().begins_with("fr"):
		rate = rate.replace(".", ",")
	lines.append(tr("BESTIARY_STATS") % [int(m.attack.damage), rate, int(m.get_range())])
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
