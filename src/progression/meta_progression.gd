class_name MetaProgression
extends RefCounted
## Application d'une fin de partie au profil : monnaies, statistiques, records, découvertes,
## maîtrise, objectifs et déblocages. Fonction pure (testable sans scène).

## Retourne {shards, essence, lines}.
static func apply_run_result(profile: ProfileData, result: Dictionary) -> Dictionary:
	var rewards: Dictionary = RunRewards.compute(result, GameDB.balance)
	var lines: PackedStringArray = []
	var counters: Dictionary = result.get("stats", {}).get("counters", {})
	var victory: bool = result.get("victory", false)
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
	lines.append_array(Objectives.evaluate(profile, result))
	if victory:
		lines.append_array(_unlock_next_tension(profile, int(result.get("difficulty_level", 0))))
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


static func _unlock_next_tension(profile: ProfileData, level: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for difficulty: DifficultyData in GameDB.difficulties_by_level():
		if difficulty.level == level + 1 and not profile.is_difficulty_unlocked(difficulty):
			profile.unlock("difficulty:" + String(difficulty.id))
			lines.append(TranslationServer.translate("REPORT_UNLOCK") % TranslationServer.translate(difficulty.name_key))
	return lines
