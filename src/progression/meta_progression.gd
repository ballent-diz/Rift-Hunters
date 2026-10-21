class_name MetaProgression
extends RefCounted
## Application d'une fin de partie au profil : monnaies, statistiques, records, découvertes,
## maîtrise, objectifs et déblocages. Fonction pure (testable sans scène).

## Retourne {shards, essence, lines}.
static func apply_run_result(profile: ProfileData, result: Dictionary) -> Dictionary:
	var arena_id := StringName(str(result.get("arena", "")))
	var mode: StringName = Campaign.mode_of(StringName(str(result.get("difficulty", ""))))
	var repeat_mult: float = Campaign.reward_mult(profile, arena_id, mode, (result.get("modifiers", []) as Array).size())
	var scaled: Dictionary = result.duplicate()
	scaled["reward_mult"] = float(result.get("reward_mult", 1.0)) * repeat_mult
	var rewards: Dictionary = RunRewards.compute(scaled, GameDB.balance)
	var lines: PackedStringArray = []
	if repeat_mult < 1.0:
		lines.append(TranslationServer.translate("REPORT_REPEAT_REWARD") % int(round(repeat_mult * 100.0)))
	var counters: Dictionary = result.get("stats", {}).get("counters", {})
	var victory: bool = result.get("victory", false)
	profile.data["flags"]["tutorial_done"] = true
	profile.add_currency("shards", int(rewards["shards"]))
	profile.add_currency("essence", int(rewards["essence"]))
	_update_lifetime(profile, counters, victory)
	_update_records(profile, result, victory)
	lines.append_array(_update_discoveries(profile, result, counters))
	var synergy_members: Array[String] = []
	for synergy_id: String in result.get("synergies", []):
		var synergy: SynergyData = GameDB.synergies.get(StringName(synergy_id))
		if synergy:
			for member: StringName in synergy.required_monsters:
				synergy_members.append(String(member))
	for monster_id: String in result.get("team", []):
		var monster: MonsterData = GameDB.monster(StringName(monster_id))
		if monster:
			lines.append_array(Mastery.apply_run(profile, monster, counters, victory, synergy_members.has(monster_id)))
	for id: String in result.get("captures", []):
		var captured: MonsterData = GameDB.monster(StringName(id))
		if captured and not profile.is_monster_unlocked(captured):
			profile.unlock("monster:" + id)
			lines.append(TranslationServer.translate("REPORT_CAPTURE_UNLOCK") % TranslationServer.translate(captured.name_key))
		profile.discover("monsters", id)
	lines.append_array(Objectives.evaluate(profile, result))
	var campaign: Dictionary = Campaign.apply_result(profile, result)
	rewards["shards"] = int(rewards["shards"]) + int(campaign["shards"])
	lines.append_array(campaign["lines"])
	if victory:
		# Première victoire sur une carte (puis en Cauchemar) : +1 Point de Chasseur.
		var key: String = ("nightmare:" if mode == Campaign.NIGHTMARE else "") + String(arena_id)
		if arena_id != &"" and HunterTree.record_victory(profile, key):
			lines.append(TranslationServer.translate("REPORT_HUNTER_POINT"))
	rewards["lines"] = lines
	return rewards


static func _update_lifetime(profile: ProfileData, counters: Dictionary, victory: bool) -> void:
	var lifetime: Dictionary = profile.data["lifetime"]
	for key: String in counters:
		var value: float = float(counters[key])
		if key.begins_with("max_") or key.ends_with("_max_pulled") or key.ends_with("_max_detonated") or key.ends_with("_evolved"):
			lifetime[key] = maxf(float(lifetime.get(key, 0.0)), value)
		else:
			lifetime[key] = float(lifetime.get(key, 0.0)) + value
	lifetime["runs"] = float(lifetime.get("runs", 0.0)) + 1.0
	if victory:
		lifetime["victories"] = float(lifetime.get("victories", 0.0)) + 1.0
	profile.data["runs"]["played"] = int(profile.data["runs"]["played"]) + 1
	if victory:
		profile.data["runs"]["won"] = int(profile.data["runs"]["won"]) + 1


static func _update_records(profile: ProfileData, result: Dictionary, victory: bool) -> void:
	var records: Dictionary = profile.data["records"]
	records["best_time"] = maxf(float(records["best_time"]), float(result.get("time", 0.0)))
	records["best_level"] = maxi(int(records["best_level"]), int(result.get("level", 0)))
	records["best_kills"] = maxi(int(records["best_kills"]), int(result.get("kills", 0)))
	# Carte bonus à vagues infinies : meilleure vague atteinte.
	records["endless_best_wave"] = maxi(int(records.get("endless_best_wave", 0)), int(result.get("endless_wave", 0)))
	if victory:
		records["highest_tension_won"] = maxi(int(records["highest_tension_won"]), int(result.get("difficulty_level", 0)))


static func _update_discoveries(profile: ProfileData, result: Dictionary, counters: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for id: String in result.get("team", []):
		profile.discover("monsters", id)
	for id: String in result.get("evolutions", []):
		if profile.discover("evolutions", id):
			lines.append(TranslationServer.translate("REPORT_NEW_EVOLUTION") % TranslationServer.translate(_evolution_name(id)))
	for id: String in result.get("relics", []):
		profile.discover("relics", id)
	for id: String in result.get("synergies", []):
		if profile.discover("synergies", id):
			var synergy: SynergyData = GameDB.synergies.get(StringName(id))
			if synergy:
				lines.append(TranslationServer.translate("REPORT_NEW_SYNERGY") % TranslationServer.translate(synergy.name_key))
	for key: String in counters:
		if key.begins_with("kills_"):
			profile.discover("enemies", key.trim_prefix("kills_"))
	return lines


static func _evolution_name(evolution_id: String) -> String:
	for id: StringName in GameDB.monsters:
		for evo: EvolutionData in (GameDB.monsters[id] as MonsterData).evolutions:
			if String(evo.id) == evolution_id:
				return evo.name_key
	return evolution_id

