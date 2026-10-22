extends TestCase
## Dévoreur des Sources, finale du chapitre 1 (docs/art/DEVOREUR_SOURCES_EFFETS.md) : attaques réelles, effets peints
## qui suivent le combat, souffle arrêté par les rochers-abris, deux phases, invocations plafonnées.

var run: RunController
var boss: Enemy
var brain: BossController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _fight(offset := Vector2(-300, 0)) -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"cascade_source"
	setup.starter_id = &"ashblade"
	setup.run_seed = 5
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	boss = run.ctx.enemies.spawn_boss(GameDB.boss(&"source_devourer"), run.ctx.arena.finale_center)
	run.ctx.player.global_position = boss.position - offset
	brain = BossController.new(run.ctx, boss)


func _advance(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		run.ctx.time += 0.05
		brain._run_scheduled()
		run.ctx.hazards.step(0.05)
		t += 0.05


func _pattern(kind: StringName, phase: int = 0) -> BossPatternData:
	for pattern: BossPatternData in GameDB.boss(&"source_devourer").phases[phase].patterns:
		if pattern.kind == kind:
			return pattern
	return null


func _effects(scene: String) -> int:
	var count: int = 0
	for child: Node in run.ctx.world.get_children():
		if child.scene_file_path.ends_with("/" + scene + ".tscn"):
			count += 1
	return count


func test_data_animations_and_effects_exist() -> void:
	var data: BossData = GameDB.boss(&"source_devourer")
	check(data != null, "boss chargé")
	check_eq(GameDB.arena(&"cascade_source").boss_id, &"source_devourer", "Dévoreur de la Source des Cascades")
	check_eq(data.phases.size(), 2, "deux phases")
	var entry: Dictionary = Assets.entry(data.visual.visual_id)
	var anims: Dictionary = entry.get("animations", {})
	for phase: BossPhaseData in data.phases:
		for pattern: BossPatternData in phase.patterns:
			check(anims.has(String(pattern.params.get("anim", ""))), "%s : animation" % pattern.name_key)
			var scene: String = data.vfx_dir.path_join(String(pattern.params.get("vfx", "")) + ".tscn")
			check(ResourceLoader.exists(scene), "%s : effet %s" % [pattern.name_key, scene])
			check(tr(pattern.name_key) != pattern.name_key, "%s : traduit" % pattern.name_key)
	for anim: String in ["roar", "transform", "phase2_idle", "hurt", "death"]:
		check(anims.has(anim), "animation " + anim)


func test_claw_hits_in_front_only() -> void:
	_fight(Vector2(-150, 0))
	brain._pattern_sweep(_pattern(&"sweep"))
	check_eq(_effects("indicator"), 1, "télégraphe peint pendant la préparation")
	var hp: float = run.ctx.player.hp
	_advance(1.0)
	check(run.ctx.player.hp < hp, "griffes : le Chasseur devant est touché")
	check(_effects("claw") >= 1, "effet des griffes au contact")
	run.ctx.player.hp = run.ctx.player.max_hp
	brain._pattern_sweep(_pattern(&"sweep"))
	# Le Chasseur passe derrière le boss pendant la préparation : le secteur reste orienté vers l'ancienne position.
	run.ctx.player.global_position = boss.position + Vector2(-160, 0)
	hp = run.ctx.player.hp
	_advance(1.0)
	check_eq(run.ctx.player.hp, hp, "esquivé en passant derrière")


func test_double_slam_strikes_two_fists() -> void:
	_fight()
	var before: int = run.ctx.hazards.hazards.size()
	brain._pattern_slam(_pattern(&"slam"))
	check_eq(run.ctx.hazards.hazards.size() - before, 2, "deux impacts télégraphiés")
	_advance(1.2)
	check_eq(_effects("heavy_slam"), 2, "un effet par poing, au point d'impact")


func test_breath_stops_at_the_cover_rocks() -> void:
	_fight()
	# Rocher-abri est de la cour (plan de la carte : 71 %, 18 %) : centre = point le plus bloqué du voisinage.
	var rock := Vector2(1053, -1605)
	for x: int in range(850, 1260, 10):
		for y: int in range(-1800, -1400, 10):
			if run.ctx.obstacles.distance(Vector2(x, y)) < run.ctx.obstacles.distance(rock):
				rock = Vector2(x, y)
	var depth: float = -run.ctx.obstacles.distance(rock)
	check(depth > 40.0, "rocher-abri bloquant (%d)" % int(depth))
	var from: Vector2 = rock + Vector2(-380, 0)
	check(run.ctx.obstacles.distance(from) > 0.0 and run.ctx.obstacles.distance(rock + Vector2(380, 0)) > 0.0,
		"cour praticable de part et d'autre")
	var length: float = brain.clear_length(from, Vector2.RIGHT, 700.0)
	check(length < 380.0 - depth and length > 60.0, "le souffle s'arrête au rocher (%d)" % int(length))
	run.ctx.player.global_position = rock + Vector2(380, 0)
	var hp: float = run.ctx.player.hp
	run.ctx.hazards.add_beam(from, Vector2.RIGHT, length, 80.0, 0.1, 0.5, 30.0, &"source_devourer")
	_advance(0.8)
	check_eq(run.ctx.player.hp, hp, "abrité derrière le rocher : aucun dégât")


func test_phase_two_switches_idle_and_clears_telegraphs() -> void:
	_fight()
	brain._pattern_breath(_pattern(&"breath"))
	check_eq(_effects("indicator"), 1, "télégraphe du souffle")
	boss.hp = boss.max_hp * 0.4
	brain._check_phase()
	check_eq(brain.phase_index, 1, "phase 2 à mi-vie")
	check_eq(boss.visual.idle_animation, &"phase2_idle", "repos de phase 2")
	check(brain._indicators.is_empty(), "télégraphes retirés au changement de phase")
	check_eq(_effects("transform"), 1, "effet de transformation")


func test_summons_are_capped_and_death_cleans_up() -> void:
	_fight()
	var summon: BossPatternData = _pattern(&"summon")
	for i: int in 4:
		brain._pattern_summon(summon)
		_advance(1.2)
	check(brain._summons.size() <= int(summon.params["max_active"]), "invocations plafonnées")
	for enemy: Enemy in brain._summons:
		check(run.ctx.obstacles.distance(enemy.position) >= 0.0, "invocation sur sol praticable")
	brain._pattern_sweep(_pattern(&"sweep"))
	boss.alive = false
	brain.step(0.05)
	check(brain._indicators.is_empty(), "mort : télégraphes retirés")
	check_eq(_effects("death"), 1, "effet de mort")
