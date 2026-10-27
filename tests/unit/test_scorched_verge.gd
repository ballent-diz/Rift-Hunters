extends TestCase
## Carte 6 « Lisière calcinée » (chapitre 2) : sol brûlant, Brute du bûcher (Bûcher écrasé, Rage), gardien, chapitre.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"scorched_verge"
	setup.starter_id = &"ashblade"
	setup.run_seed = 3
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _step(ctx: RunContext, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		ctx.burn.step(0.05)
		ctx.enemies.step(0.05)
		ctx.hazards.step(0.05)
		t += 0.05


func test_chapter_two_follows_the_vale() -> void:
	var chapter: ChapterData = GameDB.chapters.get(&"devastated_lands")
	check(chapter != null and chapter.maps[0].arena_id == &"scorched_verge", "chapitre 2 : Lisière calcinée en carte 1")
	var profile := ProfileData.new()
	check(not Campaign.is_map_unlocked(profile, GameDB.arena(&"scorched_verge")), "verrouillée au départ")
	Campaign._mode_entry(profile, &"cascade_source", Campaign.NORMAL)["wins"] = 1
	check(Campaign.is_map_unlocked(profile, GameDB.arena(&"scorched_verge")), "ouverte après la Source des Cascades")
	check_eq(GameDB.monster(&"stormshell").discovery_arena, &"scorched_verge", "Égidor : récompense de la carte 6")


func test_plates_are_walkable_and_away_from_start() -> void:
	var ctx: RunContext = _start()
	check_eq(ctx.burn.plates.size(), 10, "dix plaques de la carte")
	for plate: Dictionary in ctx.burn.plates:
		check(ctx.obstacles.distance(plate["pos"]) > 0.0, "plaque praticable en %s" % str(plate["pos"]))
		check(ctx.player.global_position.distance_to(plate["pos"]) > 250.0, "aucune plaque près du départ")


func test_plates_burn_hunter_and_corrupted() -> void:
	var ctx: RunContext = _start()
	var plate: Dictionary = ctx.burn.plates[4]
	ctx.player.global_position = plate["pos"]
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"char_golem"), (plate["pos"] as Vector2) + Vector2(20, 0))
	var hp: float = ctx.player.hp
	var enemy_hp: float = enemy.hp
	ctx.burn.step(0.6)
	check(ctx.player.hp < hp, "le Chasseur brûle sur la plaque")
	check(enemy.hp < enemy_hp, "les Corrompus aussi")


func test_pyre_brute_slams_a_burning_plate_then_rages() -> void:
	var ctx: RunContext = _start()
	ctx.time = 10.0
	var brute: Enemy = ctx.enemies.spawn(GameDB.enemy(&"pyre_brute"), ctx.player.global_position + Vector2(200, 0))
	brute.spawn_time = 0.0
	var before: int = ctx.burn.plates.size()
	ctx.enemies.step(0.05)
	check(brute.technique_busy > 0.0, "Bûcher écrasé lancé à portée")
	check_eq(brute.visual._current, &"pyre_slam", "animation du bûcher")
	_step(ctx, 1.2)
	check_eq(ctx.burn.plates.size(), before + 1, "une plaque brûlante à l'impact")
	brute.hp = brute.max_hp * 0.4
	var speed: float = brute.move_speed
	_step(ctx, 1.0)
	check(brute.raged and brute.move_speed > speed, "rage sous la moitié des PV")


func test_guardian_slam_leaves_a_plate() -> void:
	var ctx: RunContext = _start()
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"pyre_guardian"), ctx.player.global_position + Vector2(250, 0))
	var brain := BossController.new(ctx, boss)
	var slam: BossPatternData = GameDB.boss(&"pyre_guardian").phases[0].patterns[1]
	var before: int = ctx.burn.plates.size()
	brain._pattern_slam(slam)
	for i: int in 30:
		ctx.time += 0.05
		brain._run_scheduled()
	check_eq(ctx.burn.plates.size(), before + 1, "le Bûcher écrasé du gardien embrase le sol")
