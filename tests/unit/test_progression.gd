extends TestCase
## Progression permanente : arbre, maîtrise, objectifs, recherche, application d'une fin de partie.

var profile: ProfileData


func before_each() -> void:
	profile = ProfileData.new()


func _result(overrides: Dictionary = {}, counters: Dictionary = {}) -> Dictionary:
	var result := {"victory": false, "time": 120.0, "level": 5, "kills": 50, "difficulty_level": 0, "reward_mult": 1.0,
		"shard_gain": 1.0, "boss_shards": 150, "boss_essence": 10, "team": ["mossback"], "evolutions": [], "relics": [],
		"synergies": [], "stats": {"counters": counters}}
	result.merge(overrides, true)
	return result


func test_tree_prerequisites_and_costs() -> void:
	var training: SkillNodeData = GameDB.skill_node(&"combat_training")
	var phantom: SkillNodeData = GameDB.skill_node(&"combat_phantom_step")
	check_eq(SkillTree.status(profile, training), SkillTree.Status.TOO_EXPENSIVE, "trop cher sans Éclats")
	profile.add_currency("shards", 1000)
	check_eq(SkillTree.status(profile, phantom), SkillTree.Status.LOCKED, "prérequis manquant")
	check(SkillTree.buy(profile, training), "achat du rang 1")
	check_eq(profile.shards(), 1000 - training.costs[0], "coût débité")
	check_eq(SkillTree.status(profile, phantom), SkillTree.Status.AVAILABLE, "prérequis rempli")


func test_tree_exclusive_nodes() -> void:
	profile.add_currency("shards", 5000)
	SkillTree.buy(profile, GameDB.skill_node(&"combat_training"))
	check(SkillTree.buy(profile, GameDB.skill_node(&"combat_marksman")), "Tireur acquis")
	var brawler: SkillNodeData = GameDB.skill_node(&"combat_rift_brawler")
	check_eq(SkillTree.status(profile, brawler), SkillTree.Status.EXCLUDED, "Cogneur exclu")
	check(not SkillTree.buy(profile, brawler), "achat refusé")


func test_tree_respec_rules() -> void:
	profile.add_currency("shards", 1000)
	SkillTree.buy(profile, GameDB.skill_node(&"combat_training"))
	SkillTree.buy(profile, GameDB.skill_node(&"combat_training"))
	check_eq(SkillTree.respec_cost(profile), 0, "première réinitialisation gratuite")
	check(SkillTree.respec(profile), "réinitialisation")
	check_eq(profile.shards(), 1000, "100 % des Éclats remboursés")
	check_eq(profile.tree_rank(&"combat_training"), 0, "arbre vidé")
	SkillTree.buy(profile, GameDB.skill_node(&"combat_training"))
	check_eq(SkillTree.respec_cost(profile), SkillTree.RESPEC_ESSENCE_PER_RESET, "la suivante coûte de l'Essence")
	check(not SkillTree.respec(profile), "refusée sans Essence")


func test_tree_effects_scale_with_rank() -> void:
	profile.add_currency("shards", 1000)
	var training: SkillNodeData = GameDB.skill_node(&"combat_training")
	SkillTree.buy(profile, training)
	SkillTree.buy(profile, training)
	check_eq(SkillTree.effects_for(profile).size(), training.effects.size() * 2, "effets installés une fois par rang")


func test_tree_effects_apply_in_run() -> void:
	profile.add_currency("shards", 5000)
	for id: StringName in [&"echoes_bonds", &"echoes_veteran", &"echoes_third_seal"]:
		check(SkillTree.buy(profile, GameDB.skill_node(id)), "achat %s" % id)
	var setup: RunSetup = _setup_from(profile)
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	setup.autopilot = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	check_eq(run.ctx.allies.team_slots(), 3, "Troisième sceau : 3 emplacements")
	check_eq(run.ctx.player.stats.get_int(StatKeys.RECRUIT_RANK), 2, "Recrues aguerries : rang 2")
	RunFixture.dispose(run)


func test_glimmerwing_locked_then_unlocked_by_objective() -> void:
	check(not _setup_from(profile).unlocked_monsters.has(&"glimmerwing"), "Lucivelle verrouillée au départ")
	var report: Dictionary = MetaProgression.apply_run_result(profile, _result({}, {"time_survived": 200.0}))
	check(Objectives.is_completed(profile, &"first_steps"), "Premiers pas accompli")
	check(profile.has_unlock("monsters", &"glimmerwing"), "Lucivelle débloquée")
	check(_setup_from(profile).unlocked_monsters.has(&"glimmerwing"), "disponible dans les expéditions")
	check(not (report["lines"] as PackedStringArray).is_empty(), "rapport de fin de partie renseigné")


func test_objective_conditions() -> void:
	var lone: ObjectiveData = GameDB.objective(&"lone_wolf")
	check(not Objectives.is_met(profile, lone, _result({"victory": false}, {"victories": 1.0, "max_team_size": 1.0})),
			"victoire requise")
	check(not Objectives.is_met(profile, lone, _result({"victory": true}, {"victories": 1.0, "max_team_size": 2.0})),
			"équipe trop grande")
	check(Objectives.is_met(profile, lone, _result({"victory": true}, {"victories": 1.0, "max_team_size": 1.0})),
			"condition remplie")
	var tension: ObjectiveData = GameDB.objective(&"tension_two")
	check(not Objectives.is_met(profile, tension, _result({"victory": true, "difficulty_level": 1}, {"victories": 1.0})),
			"Tension trop basse")


func test_lifetime_objective_accumulates() -> void:
	MetaProgression.apply_run_result(profile, _result({}, {"elites_killed": 6.0}))
	check(not Objectives.is_completed(profile, &"elite_hunter"), "6 élites : pas encore")
	MetaProgression.apply_run_result(profile, _result({}, {"elites_killed": 5.0}))
	check(Objectives.is_completed(profile, &"elite_hunter"), "11 élites cumulées : accompli")


func test_victory_unlocks_next_tension_and_rewards() -> void:
	var report: Dictionary = MetaProgression.apply_run_result(profile, _result({"victory": true, "time": 500.0},
		{"bosses_killed": 1.0, "victories": 1.0, "shards_earned_raw": 50.0, "essence_earned_raw": 3.0}))
	check(profile.has_unlock("difficulties", &"tension_1"), "Tension I débloquée")
	check(int(report["shards"]) > 150, "Éclats du boss inclus")
	check_eq(int(profile.data["runs"]["won"]), 1, "victoire comptée")
	check_near(float(profile.data["records"]["best_time"]), 500.0, 0.01, "record de temps")


func test_mastery_rewards_play_style() -> void:
	var mossback: MonsterData = GameDB.monster(&"mossback")
	MetaProgression.apply_run_result(profile, _result({}, {"mossback_techniques": 10.0}))
	var xp: int = int(profile.mastery_entry(&"mossback")["xp"])
	check(xp >= 15, "XP de maîtrise selon les Techniques utilisées (%d)" % xp)
	MetaProgression.apply_run_result(profile, _result({}, {"mossback_max_pulled": 30.0}))
	check((profile.mastery_entry(&"mossback")["challenges"] as Array).has("mossback_singularity"), "défi Singularité accompli")
	check(Mastery.level(profile, mossback) >= 1, "niveau de maîtrise atteint")


func test_mastery_level_rewards() -> void:
	var ash: MonsterData = GameDB.monster(&"ashblade")
	profile.mastery_entry(&"ashblade")["xp"] = 10000
	check_eq(Mastery.level(profile, ash), 5, "niveau maximal")
	check(Mastery.variant_unlocked(profile, ash), "variante débloquée")
	check_eq(Mastery.palette(profile, ash).size(), 2, "palette débloquée")
	check_eq(Mastery.start_rank(profile, ash), 2, "rang de départ 2")
	check(not Mastery.effects_for(profile, ash).is_empty(), "bonus de maîtrise installé en partie")
	profile.mastery_entry(&"ashblade")["use_variant"] = true
	var setup: RunSetup = _setup_from(profile, &"ashblade")
	check(setup.starter_variant and setup.starter_rank == 2, "variante et rang appliqués au départ")


func test_research_spends_essence_and_unlocks() -> void:
	var prism: ResearchData = GameDB.research_item(&"cracked_prism")
	profile.add_currency("essence", 100)
	check(not Research.can_research(profile, prism), "prérequis manquant")
	check(Research.perform(profile, GameDB.research_item(&"corrupted_study")), "Étude des Corrompus")
	check(Research.perform(profile, prism), "Prisme fêlé recherché")
	check(profile.has_unlock("relics", &"cracked_prism"), "relique débloquée")
	check_eq(profile.essence(), 100 - 4 - prism.cost_essence, "Essence dépensée")
	check(_setup_from(profile).unlocked_relics.has(&"cracked_prism"), "relique présente dans les coffres")


func test_discoveries_recorded() -> void:
	MetaProgression.apply_run_result(profile, _result({"evolutions": ["monolith"], "relics": ["hunters_eye"],
		"synergies": ["breach_and_blade"]}, {"kills_husk": 3.0}))
	check(profile.is_discovered("evolutions", &"monolith"), "évolution découverte")
	check(profile.is_discovered("relics", &"hunters_eye"), "relique découverte")
	check(profile.is_discovered("synergies", &"breach_and_blade"), "synergie découverte")
	check(profile.is_discovered("enemies", &"husk"), "ennemi découvert")


func _setup_from(p: ProfileData, starter: StringName = &"") -> RunSetup:
	var original: ProfileData = Profile.profile
	Profile.profile = p
	var setup: RunSetup = Profile.make_run_setup(starter)
	Profile.profile = original
	return setup
