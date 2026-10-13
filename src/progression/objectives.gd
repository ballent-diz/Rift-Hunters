class_name Objectives
extends RefCounted
## Objectifs : conditions explicites évaluées en fin de partie, récompenses appliquées au profil.

static func value_for(profile: ProfileData, objective: ObjectiveData, counters: Dictionary) -> float:
	if objective.scope == ObjectiveData.Scope.LIFETIME:
		return profile.lifetime(String(objective.stat_key))
	return float(counters.get(String(objective.stat_key), 0.0))


static func is_met(profile: ProfileData, objective: ObjectiveData, result: Dictionary) -> bool:
	var counters: Dictionary = result.get("stats", {}).get("counters", {})
	if objective.requires_victory and not result.get("victory", false):
		return false
	if int(result.get("difficulty_level", 0)) < objective.min_difficulty:
		return false
	if objective.max_team_size >= 0 and float(counters.get("max_team_size", 0.0)) > objective.max_team_size:
		return false
	return value_for(profile, objective, counters) >= objective.threshold


static func is_completed(profile: ProfileData, id: StringName) -> bool:
	return (profile.data["objectives"]["completed"] as Array).has(String(id))


## Meilleure valeur connue pour l'affichage de la progression.
static func progress(profile: ProfileData, objective: ObjectiveData) -> float:
	if objective.scope == ObjectiveData.Scope.LIFETIME:
		return profile.lifetime(String(objective.stat_key))
	return float(profile.data["objectives"]["best"].get(String(objective.id), 0.0))


## Évalue tous les objectifs non accomplis. Retourne les lignes de rapport.
static func evaluate(profile: ProfileData, result: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var counters: Dictionary = result.get("stats", {}).get("counters", {})
	for id: StringName in GameDB.sorted_ids(GameDB.objectives):
		var objective: ObjectiveData = GameDB.objectives[id]
		if is_completed(profile, id):
			continue
		var best: Dictionary = profile.data["objectives"]["best"]
		if objective.scope == ObjectiveData.Scope.RUN:
			var eligible: bool = (not objective.requires_victory or result.get("victory", false)) \
				and int(result.get("difficulty_level", 0)) >= objective.min_difficulty
			if eligible:
				best[String(id)] = maxf(float(best.get(String(id), 0.0)), value_for(profile, objective, counters))
		if is_met(profile, objective, result):
			(profile.data["objectives"]["completed"] as Array).append(String(id))
			PlatformServices.unlock_achievement(String(id))
			lines.append(TranslationServer.translate("REPORT_OBJECTIVE") % TranslationServer.translate(objective.name_key))
			lines.append_array(grant(profile, objective.reward_shards, objective.reward_essence, objective.reward_unlocks))
	return lines


static func grant(profile: ProfileData, shards: int, essence: int, unlocks: Array[String]) -> PackedStringArray:
	var lines: PackedStringArray = []
	profile.add_currency("shards", shards)
	profile.add_currency("essence", essence)
	for entry: String in unlocks:
		if profile.unlock(entry):
			lines.append(TranslationServer.translate("REPORT_UNLOCK") % unlock_label(entry))
	return lines


## Libellé lisible d'un déblocage « type:id ».
static func unlock_label(entry: String) -> String:
	var kind: String = entry.get_slice(":", 0)
	var id := StringName(entry.get_slice(":", 1))
	var key: String = ""
	match kind:
		"monster":
			key = GameDB.monster(id).name_key if GameDB.monster(id) else ""
		"relic":
			key = GameDB.relic(id).name_key if GameDB.relic(id) else ""
		"upgrade":
			key = GameDB.upgrade(id).name_key if GameDB.upgrade(id) else ""
		"difficulty":
			key = GameDB.difficulty(id).name_key if GameDB.difficulty(id) else ""
		"arena":
			key = GameDB.arena(id).name_key if GameDB.arena(id) else ""
		_:
			key = ("UNLOCK_" + kind + "_" + String(id)).to_upper()
	return TranslationServer.translate(key) if key != "" else entry
