extends TestCase
## Lot M2 (docs/design/MODES.md) : épreuves de survie (piste à part, montées de niveau) et carte bonus à vagues
## infinies, débloquée à la fin des épreuves.

var profile: ProfileData
var run: RunController


func before_each() -> void:
	profile = ProfileData.new()


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _win(arena: StringName) -> void:
	var result := {"victory": true, "time": 500.0, "level": 20, "kills": 400, "arena": String(arena),
		"difficulty": "normal", "difficulty_level": 0, "reward_mult": 1.0, "shard_gain": 1.0, "boss_shards": 0,
		"boss_essence": 0, "team": [], "evolutions": [], "relics": [], "synergies": [], "modifiers": [],
		"stats": {"counters": {"victories": 1.0}}}
	MetaProgression.apply_run_result(profile, result)


func _unlocked(id: StringName) -> bool:
	return profile.is_arena_unlocked(GameDB.arena(id))


func test_trials_are_a_separate_track_with_levels() -> void:
	var maps: Array[CampaignMapData] = Campaign.maps_in_order(Campaign.SURVIVAL)
	check_eq(maps.size(), 6, "cinq épreuves et la carte bonus")
	check_eq(maps.back().arena_id, &"endless_rift", "la Faille sans fin ferme la piste")
	for map: CampaignMapData in maps:
		check_eq(GameDB.arena(map.arena_id).progression, &"levels", "%s : montées de niveau" % map.arena_id)
	var hp: float = 0.0
	for map: CampaignMapData in maps.slice(0, 5):
		var arena: ArenaData = GameDB.arena(map.arena_id)
		check(arena.enemy_hp_mult >= hp, "%s : de plus en plus dure" % map.arena_id)
		hp = arena.enemy_hp_mult
	check(GameDB.arena(&"endless_rift").endless, "carte bonus à vagues infinies")
	check_eq(Campaign.final_map().arena_id, Campaign.maps_in_order().back().arena_id, "le jeu finit en campagne")


func test_trials_unlock_one_after_another_then_the_bonus() -> void:
	check(_unlocked(&"fractured_plain") and _unlocked(&"three_rifts"), "première épreuve et première carte ouvertes")
	check(not _unlocked(&"survival_ruins"), "deuxième épreuve fermée")
	_win(&"fractured_plain")
	check(_unlocked(&"survival_ruins"), "victoire : l'épreuve suivante s'ouvre")
	check(not _unlocked(&"storm_highlands"), "la campagne principale ne bouge pas")
	for id: StringName in [&"survival_ruins", &"survival_highlands", &"survival_woods"]:
		_win(id)
	check(not _unlocked(&"endless_rift"), "bonus fermé avant la dernière épreuve")
	_win(&"survival_ford")
	check(_unlocked(&"endless_rift"), "cinq épreuves finies : Faille sans fin ouverte")


func test_endless_waves_never_bring_a_boss_and_grow() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"endless_rift"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	setup.run_seed = 3
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	var ctx: RunContext = run.ctx
	check_eq(ctx.endless_wave(), 1, "vague 1 au départ")
	ctx.time = 2000.0
	run.spawner.step(0.5)
	check(ctx.boss == null, "jamais de boss")
	check_eq(ctx.endless_wave(), 34, "une vague par minute")
	check_eq(int(ctx.stats.get_value(&"endless_wave")), 34, "vague atteinte comptée")
	check_eq(int(run.build_result()["endless_wave"]), 34, "score de la partie")
	var result: Dictionary = run.build_result()
	result["stats"] = {"counters": {}}
	MetaProgression.apply_run_result(profile, result)
	check_eq(int(profile.data["records"]["endless_best_wave"]), 34, "record gardé au profil")


func test_trial_enemies_are_tougher() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"survival_ford"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	var enemy: Enemy = run.ctx.enemies.spawn(GameDB.enemy(&"husk"), run.ctx.player.global_position + Vector2(300, 0))
	check_near(enemy.max_hp, GameDB.enemy(&"husk").max_hp * run.ctx.arena.enemy_hp_mult * run.ctx.difficulty.enemy_hp_mult,
		0.01, "PV multipliés par la force de la carte")
