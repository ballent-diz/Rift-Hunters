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


func _node(id: StringName) -> SkillNodeData:
	return GameDB.skill_node(id)


func test_tree_learning_costs_and_ranks() -> void:
	var training: SkillNodeData = _node(&"combat_training")
	check_eq(HunterTree.status(profile, training), HunterTree.Status.TOO_EXPENSIVE, "trop cher sans Éclats")
	profile.add_currency("shards", 1000)
	check_eq(HunterTree.status(profile, training), HunterTree.Status.LEARNABLE, "apprenable")
	check(HunterTree.learn(profile, training), "rang 1 appris")
	check_eq(profile.shards(), 1000 - training.costs[0], "coût débité")
	HunterTree.learn(profile, training)
	HunterTree.learn(profile, training)
	check_eq(HunterTree.status(profile, training), HunterTree.Status.LEARNED, "rangs au maximum")
	check(not HunterTree.learn(profile, training), "plus rien à apprendre")


func test_tree_gates_prerequisites_and_coming_soon() -> void:
	profile.add_currency("shards", 5000)
	var whirlwind: SkillNodeData = _node(&"blade_slash_whirlwind")
	check_eq(HunterTree.learned_rank(profile, _node(&"blade_cleaving_slash")), 1, "sort de départ connu")
	check_eq(HunterTree.status(profile, whirlwind), HunterTree.Status.GATED, "palier : 1 victoire contre un boss")
	profile.data["runs"]["won"] = 1
	check_eq(HunterTree.status(profile, whirlwind), HunterTree.Status.LEARNABLE, "palier atteint")
	check_eq(HunterTree.status(profile, _node(&"abyss_singularity")), HunterTree.Status.COMING_SOON, "sort à venir")
	check(not HunterTree.learn(profile, _node(&"abyss_singularity")), "à venir : non apprenable")
	check_eq(HunterTree.status(profile, _node(&"blade_counter_cut")), HunterTree.Status.COMING_SOON, "transformant à venir")


func test_tree_activation_spends_points() -> void:
	profile.add_currency("shards", 1000)
	check_eq(HunterTree.points_used(profile), 4, "les 2 sorts de départ sont actifs (2 + 2)")
	check_eq(HunterTree.points_total(profile), HunterTree.BASE_POINTS, "points de départ")
	var training: SkillNodeData = _node(&"combat_training")
	check_eq(HunterTree.activation_error(profile, training), "TREE_ERR_NOT_LEARNED", "apprendre avant d'activer")
	for i: int in 3:
		HunterTree.learn(profile, training)
	check(HunterTree.activate(profile, training), "rang 1 actif")
	check(HunterTree.activate(profile, training), "rang 2 actif")
	check_eq(HunterTree.activation_error(profile, training), "TREE_ERR_POINTS", "plus de points")
	HunterTree.record_victory(profile, "three_rifts")
	check(not HunterTree.record_victory(profile, "three_rifts"), "un seul point par carte")
	check(HunterTree.activate(profile, training), "rang 3 actif avec le point de la victoire")
	check(HunterTree.deactivate(profile, training), "désactivation gratuite")
	check_eq(HunterTree.active_rank(profile, training), 2, "un rang de moins")


func test_tree_variants_are_exclusive_and_need_their_spell() -> void:
	profile.add_currency("shards", 5000)
	profile.data["runs"]["won"] = 1
	var slash: SkillNodeData = _node(&"blade_cleaving_slash")
	var whirlwind: SkillNodeData = _node(&"blade_slash_whirlwind")
	var thrust: SkillNodeData = _node(&"blade_slash_thrust")
	HunterTree.learn(profile, whirlwind)
	HunterTree.learn(profile, thrust)
	check(HunterTree.activate(profile, whirlwind), "Tourbillon actif")
	check(HunterTree.activate(profile, thrust), "Estoc remplace Tourbillon")
	check_eq(HunterTree.active_rank(profile, whirlwind), 0, "Tourbillon désactivé")
	check_eq(HunterTree.loadout(profile)["variants"], {&"cleaving_slash": &"thrust"}, "variante transmise à la partie")
	check(HunterTree.deactivate(profile, slash), "sort désactivé")
	check_eq(HunterTree.active_rank(profile, thrust), 0, "ses variantes aussi")
	check_eq(HunterTree.slot_of(profile, &"cleaving_slash"), -1, "et il quitte son emplacement")
	check_eq(HunterTree.activation_error(profile, thrust), "TREE_ERR_NEEDS_SPELL", "variante sans son sort")
	check(HunterTree.activate(profile, slash), "sort réactivé")
	check_eq(HunterTree.slot_of(profile, &"cleaving_slash"), 0, "rééquipé sur le premier emplacement libre")


func test_tree_equip_swaps_slots_and_builds_are_independent() -> void:
	check(HunterTree.equip(profile, &"prismatic_lance", 0), "Lance sur A")
	check_eq(HunterTree.loadout(profile)["spells"], [&"prismatic_lance", &"cleaving_slash", &"", &""] as Array[StringName],
		"emplacements échangés")
	HunterTree.set_active_index(profile, 1)
	check_eq(HunterTree.slot_of(profile, &"cleaving_slash"), 0, "le build 2 garde sa propre disposition")
	check(not HunterTree.equip(profile, &"singularity", 2), "un sort inactif ne s'équipe pas")


func test_tree_effects_use_active_nodes_and_utilities() -> void:
	profile.add_currency("shards", 5000)
	var training: SkillNodeData = _node(&"combat_training")
	HunterTree.learn(profile, training)
	HunterTree.learn(profile, training)
	check_eq(HunterTree.effects_for(profile).size(), 0, "appris mais inactif : aucun effet")
	HunterTree.activate(profile, training)
	HunterTree.activate(profile, training)
	check_eq(HunterTree.effects_for(profile).size(), training.effects.size() * 2, "effets installés une fois par rang actif")
	var seal: SkillNodeData = _node(&"echoes_veteran")
	HunterTree.learn(profile, seal)
	check_eq(HunterTree.effects_for(profile).size(), training.effects.size() * 2 + seal.effects.size(),
		"amélioration du refuge active dès qu'apprise")


func test_tree_effects_apply_in_run() -> void:
	profile.add_currency("shards", 5000)
	profile.data["runs"]["won"] = 1
	for id: StringName in [&"echoes_veteran", &"echoes_third_seal", &"prism_lance_fan"]:
		check(HunterTree.learn(profile, _node(id)), "apprentissage %s" % id)
	check(HunterTree.activate(profile, _node(&"prism_lance_fan")), "Éventail actif")
	var setup: RunSetup = _setup_from(profile)
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	setup.autopilot = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	check_eq(run.ctx.allies.team_slots(), 3, "Troisième sceau : 3 emplacements")
	check_eq(run.ctx.player.stats.get_int(StatKeys.RECRUIT_RANK), 2, "Recrues aguerries : rang 2")
	check_eq(run.ctx.spells.slots[1].id, &"prismatic_lance", "sorts du build équipés")
	check_eq(run.ctx.spells.variants[1], &"fan", "variante du build appliquée")
	RunFixture.dispose(run)


func test_save_v1_migrates_to_tree_v2() -> void:
	var old := ProfileData.default_data()
	old["format_version"] = 1
	old.erase("hunter")
	old["tree"] = {"combat_training": 2, "explore_prospector": 1}
	var migrated: Dictionary = SaveMigrations.migrate(old)
	check_eq(migrated["error"], "", "migration sans erreur")
	check_eq(int(migrated["to"]), SaveMigrations.CURRENT_VERSION, "version à jour")
	var p := ProfileData.new(migrated["data"])
	check_eq(p.tree_rank(&"combat_training"), 2, "rangs appris conservés")
	check_eq(HunterTree.active_rank(p, _node(&"combat_training")), 2, "passifs appris activés dans le premier build")
	check_eq(HunterTree.active_rank(p, _node(&"explore_prospector")), 1, "amélioration du refuge toujours active")
	check_eq(HunterTree.loadout(p)["spells"][0], &"cleaving_slash", "sorts de départ équipés")


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
