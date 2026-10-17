extends TestCase
## Lot B1 : campagne en chapitres, déblocage en avançant, objectifs de carte, récompenses dégressives, Cauchemar.

var profile: ProfileData


func before_each() -> void:
	profile = ProfileData.new()


func _win(arena: StringName, difficulty: StringName = &"normal", counters: Dictionary = {},
		modifiers: Array = []) -> Dictionary:
	var all_counters: Dictionary = {"victories": 1.0, "bosses_killed": 1.0, "damage_taken": 900.0, "boss_fight_time": 300.0}
	all_counters.merge(counters, true)
	var result := {"victory": true, "time": 600.0, "level": 10, "kills": 300, "arena": String(arena),
		"difficulty": String(difficulty), "difficulty_level": GameDB.difficulty(difficulty).level,
		"reward_mult": GameDB.difficulty(difficulty).reward_mult, "shard_gain": 1.0, "boss_shards": 100, "boss_essence": 0,
		"team": [], "evolutions": [], "relics": [], "synergies": [], "modifiers": modifiers,
		"stats": {"counters": all_counters}}
	return MetaProgression.apply_run_result(profile, result)


func test_chapters_are_valid() -> void:
	var chapters: Array[ChapterData] = GameDB.chapters_in_order()
	check(chapters.size() >= 2, "au moins deux chapitres")
	var seen: Array[StringName] = []
	for chapter: ChapterData in chapters:
		check(not chapter.maps.is_empty(), "%s : au moins une carte" % chapter.id)
		for map: CampaignMapData in chapter.maps:
			check(GameDB.arena(map.arena_id) != null, "%s : arène connue" % map.arena_id)
			check(not seen.has(map.arena_id), "%s : une seule fois dans la campagne" % map.arena_id)
			seen.append(map.arena_id)
			check_eq(map.objectives.size(), 3, "%s : 3 objectifs Normal" % map.arena_id)
			check_eq(map.nightmare_objectives.size(), 3, "%s : 3 objectifs Cauchemar" % map.arena_id)
			for objective: MapObjectiveData in map.objectives + map.nightmare_objectives:
				check(Campaign.objective_text(objective) != "", "%s/%s : texte" % [map.arena_id, objective.id])
	check(not Campaign.is_campaign_map(&"fractured_plain"), "la Plaine fracturée reste hors campagne (Survie)")


func test_maps_unlock_by_progressing() -> void:
	var maps: Array[CampaignMapData] = Campaign.maps_in_order()
	var first: ArenaData = GameDB.arena(maps[0].arena_id)
	var second: ArenaData = GameDB.arena(maps[1].arena_id)
	check(profile.is_arena_unlocked(first), "première carte ouverte")
	check(not profile.is_arena_unlocked(second), "carte suivante verrouillée")
	check(profile.is_arena_unlocked(GameDB.arena(&"fractured_plain")), "Survie toujours accessible")
	MetaProgression.apply_run_result(profile, {"victory": false, "arena": String(first.id), "difficulty": "normal",
		"stats": {"counters": {}}})
	check(not profile.is_arena_unlocked(second), "une défaite ne débloque rien")
	var report: Dictionary = _win(first.id)
	check(profile.is_arena_unlocked(second), "finir la carte débloque la suivante")
	var text: String = "\n".join(report["lines"] as PackedStringArray)
	check(text.contains(tr(GameDB.arena(second.id).name_key)), "nouvelle carte annoncée")
	check(text.contains(tr(Campaign.chapter_of(second.id).name_key)), "nouveau chapitre annoncé")


func test_nightmare_unlocks_when_campaign_is_finished() -> void:
	var nightmare: DifficultyData = GameDB.difficulty(&"nightmare")
	check(not profile.is_difficulty_unlocked(nightmare), "Cauchemar verrouillé au départ")
	var maps: Array[CampaignMapData] = Campaign.maps_in_order()
	for i: int in maps.size() - 1:
		_win(maps[i].arena_id)
	check(not profile.is_difficulty_unlocked(nightmare), "pas avant la dernière carte")
	var report: Dictionary = _win(maps.back().arena_id)
	check(profile.is_difficulty_unlocked(nightmare), "Cauchemar débloqué en finissant le jeu")
	check(bool(profile.data["campaign"]["nightmare_unlocked"]), "enregistré dans la sauvegarde")
	check("\n".join(report["lines"] as PackedStringArray).contains(tr("REPORT_NIGHTMARE_UNLOCKED")), "annoncé")


func test_map_objectives_and_first_victory() -> void:
	var map: CampaignMapData = Campaign.map_data(&"three_rifts")
	var before_points: int = HunterTree.points_total(profile)
	var report: Dictionary = _win(&"three_rifts", &"normal", {"damage_taken": 100.0, "boss_fight_time": 60.0})
	for objective: MapObjectiveData in map.objectives:
		check(Campaign.objective_done(profile, &"three_rifts", Campaign.NORMAL, objective.id), "%s obtenu" % objective.id)
	check_eq(Campaign.objectives_completed(profile), 3, "3 objectifs de carte")
	check(HunterTree.points_total(profile) >= before_points + 2, "+1 point (carte) et +1 point (3 objectifs)")
	var bonus: int = map.first_victory_shards
	for objective: MapObjectiveData in map.objectives:
		bonus += objective.reward_shards
	check(int(report["shards"]) >= bonus, "prime de première victoire et objectifs inclus (%d)" % int(report["shards"]))
	var again: Dictionary = _win(&"three_rifts")
	check(int(again["shards"]) < int(report["shards"]) - bonus, "la deuxième victoire rapporte moins")
	check_eq(Campaign.wins(profile, &"three_rifts"), 2, "victoires comptées")


func test_objective_comparisons() -> void:
	var map: CampaignMapData = Campaign.map_data(&"three_rifts")
	var damage: MapObjectiveData = null
	for objective: MapObjectiveData in map.objectives:
		if objective.stat_key == &"damage_taken":
			damage = objective
	var ok := {"victory": true, "stats": {"counters": {"damage_taken": damage.threshold}}}
	var too_much := {"victory": true, "stats": {"counters": {"damage_taken": damage.threshold + 1.0}}}
	var lost := {"victory": false, "stats": {"counters": {"damage_taken": 0.0}}}
	check(Campaign.is_objective_met(damage, ok), "au plus : seuil compris")
	check(not Campaign.is_objective_met(damage, too_much), "au plus : dépassé")
	check(not Campaign.is_objective_met(damage, lost), "victoire requise")


func test_repeat_rewards_decrease_with_a_floor() -> void:
	check_near(Campaign.reward_mult(profile, &"three_rifts", Campaign.NORMAL, 0), 1.0, 0.001, "première fois : plein tarif")
	for i: int in 10:
		Campaign._mode_entry(profile, &"three_rifts", Campaign.NORMAL)["wins"] = i + 1
		var mult: float = Campaign.reward_mult(profile, &"three_rifts", Campaign.NORMAL, 0)
		check(mult < 1.0 and mult >= GameDB.balance.map_repeat_floor - 0.001, "dégressif avec plancher (%.2f)" % mult)
	check_near(Campaign.reward_mult(profile, &"fractured_plain", Campaign.NORMAL, 0), 1.0, 0.001, "Survie non concernée")
	Campaign._mode_entry(profile, &"three_rifts", Campaign.NIGHTMARE)["wins"] = 3
	check(Campaign.reward_mult(profile, &"three_rifts", Campaign.NIGHTMARE, 0) < 1.0, "Cauchemar répété : dégressif")
	check_near(Campaign.reward_mult(profile, &"three_rifts", Campaign.NIGHTMARE, 2), 1.0, 0.001,
		"Cauchemar avec un meilleur score de Pacte : plein tarif")


func test_nightmare_records_pact_and_hunter_point() -> void:
	Campaign.unlock_all_for_testing(profile)
	var before: int = HunterTree.points_total(profile)
	_win(&"three_rifts", &"nightmare", {}, ["horde", "heavy_rift"])
	check_eq(Campaign.wins(profile, &"three_rifts", Campaign.NIGHTMARE), 1, "victoire en Cauchemar comptée à part")
	check_eq(Campaign.wins(profile, &"three_rifts", Campaign.NORMAL), 0, "le Normal n'est pas touché")
	check_eq(Campaign.best_pact(profile, &"three_rifts"), 2, "meilleur score de Pacte retenu")
	check(HunterTree.points_total(profile) >= before + 1, "+1 Point de Chasseur à la première victoire en Cauchemar")


func test_run_setup_falls_back_to_unlocked_choices() -> void:
	profile.set_preference("difficulty", "nightmare")
	profile.set_preference("arena", "storm_highlands")
	var saved: ProfileData = Profile.profile
	Profile.profile = profile
	var setup: RunSetup = Profile.make_run_setup(&"")
	Profile.profile = saved
	check_eq(setup.difficulty_id, &"normal", "Cauchemar verrouillé : Normal")
	check(setup.arena_id != &"storm_highlands", "carte verrouillée : remplacée")
	check(setup.modifier_ids.is_empty(), "pas de pacte en Normal")
