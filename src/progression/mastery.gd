class_name Mastery
extends RefCounted
## Maîtrise des Échos : XP selon la façon de jouer, défis, récompenses par palier.

static func level(profile: ProfileData, monster: MonsterData) -> int:
	if monster.mastery == null:
		return 0
	return monster.mastery.level_for_xp(int(profile.mastery_entry(monster.id)["xp"]))


static func rewards_unlocked(profile: ProfileData, monster: MonsterData) -> Array[MasteryRewardData]:
	var result: Array[MasteryRewardData] = []
	if monster.mastery == null:
		return result
	var lvl: int = level(profile, monster)
	for reward: MasteryRewardData in monster.mastery.rewards:
		if reward.level <= lvl:
			result.append(reward)
	return result


static func _reward(profile: ProfileData, monster: MonsterData, kind: MasteryRewardData.Kind) -> MasteryRewardData:
	for reward: MasteryRewardData in rewards_unlocked(profile, monster):
		if reward.kind == kind:
			return reward
	return null


## Effets installés quand l'Écho rejoint l'équipe (bonus de maîtrise).
static func effects_for(profile: ProfileData, monster: MonsterData) -> Array[GameplayEffect]:
	var effects: Array[GameplayEffect] = []
	for reward: MasteryRewardData in rewards_unlocked(profile, monster):
		if reward.kind == MasteryRewardData.Kind.STAT_BONUS:
			effects.append_array(reward.effects)
	return effects


static func variant_unlocked(profile: ProfileData, monster: MonsterData) -> bool:
	return monster.variant != null and _reward(profile, monster, MasteryRewardData.Kind.VARIANT) != null


static func palette(profile: ProfileData, monster: MonsterData) -> Array:
	var reward: MasteryRewardData = _reward(profile, monster, MasteryRewardData.Kind.PALETTE)
	return [reward.palette_primary, reward.palette_secondary] if reward else []


static func start_rank(profile: ProfileData, monster: MonsterData) -> int:
	var reward: MasteryRewardData = _reward(profile, monster, MasteryRewardData.Kind.START_RANK)
	return reward.start_rank if reward else 1


static func has_title(profile: ProfileData, monster: MonsterData) -> bool:
	return _reward(profile, monster, MasteryRewardData.Kind.TITLE) != null


## Applique une partie. Retourne les lignes de rapport (déjà traduites).
static func apply_run(profile: ProfileData, monster: MonsterData, counters: Dictionary, victory: bool,
		in_synergy: bool) -> PackedStringArray:
	var lines: PackedStringArray = []
	var mastery: MasteryData = monster.mastery
	if mastery == null:
		return lines
	var entry: Dictionary = profile.mastery_entry(monster.id)
	var before: int = level(profile, monster)
	var techniques: float = float(counters.get(String(monster.id) + "_techniques", 0.0))
	var procs: float = float(counters.get("synergy_procs", 0.0)) if in_synergy else 0.0
	var play_xp: int = mini(int(techniques * mastery.xp_per_technique + procs * mastery.xp_per_synergy_proc) + 5,
		mastery.max_xp_per_run_from_play)
	entry["xp"] = int(entry["xp"]) + play_xp
	var done: Array = entry["challenges"]
	for challenge: MasteryChallengeData in mastery.challenges:
		if done.has(String(challenge.id)):
			continue
		if challenge.requires_victory and not victory:
			continue
		var value: float = profile.lifetime(String(challenge.stat_key)) if challenge.lifetime \
			else float(counters.get(String(challenge.stat_key), 0.0))
		if value >= challenge.threshold:
			done.append(String(challenge.id))
			entry["xp"] = int(entry["xp"]) + challenge.xp
			lines.append(TranslationServer.translate("REPORT_MASTERY_CHALLENGE") % [
				TranslationServer.translate(monster.name_key), TranslationServer.translate(challenge.desc_key)])
	var after: int = level(profile, monster)
	if after > before:
		lines.append(TranslationServer.translate("REPORT_MASTERY_LEVEL") % [TranslationServer.translate(monster.name_key), after])
	return lines
