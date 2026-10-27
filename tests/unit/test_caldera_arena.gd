extends TestCase
## Carte 10, grande arène (docs/design/CARTES.md) : paliers sur toute la carte, gardiens (élites en version boss) qui
## ne finissent pas la carte, Pyrevorn au palier 3, roches lancées depuis les cratères.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"caldera_arena"
	setup.starter_id = &"ashblade"
	setup.run_seed = 5
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _end_tier(ctx: RunContext) -> void:
	ctx.zones.wave_index = ctx.zones.zone().waves.size() - 1
	ctx.enemies.clear_all()
	ctx.zones._end_wave()
	var t: float = 0.0
	while t < ZoneDirector.GUARDIAN_DELAY + 0.2:
		ctx.zones.step(0.1)
		t += 0.1


func test_tiers_share_the_whole_arena_and_end_with_guardians() -> void:
	var ctx: RunContext = _start()
	check(ctx.arena.open_arena and ctx.zones != null, "grande arène en paliers")
	check_eq(ctx.zones.zone_count(), 3, "trois paliers")
	check_eq(ctx.zones.region_of(ctx.player.global_position + Vector2(1500, 1500)), 0, "tout le terrain appartient au palier")
	_end_tier(ctx)
	check(ctx.mini_boss != null and ctx.mini_boss.alive, "gardien du palier 1")
	check_eq(ctx.mini_boss.data.id, &"caldera_titan", "le Titan de caldeira")
	check(ctx.mini_boss.max_hp > GameDB.enemy(&"caldera_titan").max_hp * 8.0, "version boss : bien plus de PV")
	check_eq(ctx.zones.zone_index, 0, "le palier attend sa mort")
	ctx.combat.deal_damage(ctx.mini_boss, RunFixture.info(9999999.0))
	ctx.zones.step(0.1)
	check_eq(ctx.zones.zone_index, 1, "palier 2 après le Titan")
	check(not ctx.finished and ctx.boss == null, "un gardien ne finit pas la carte")
	ctx.zones.step(3.0)
	_end_tier(ctx)
	check_eq(ctx.mini_boss.data.id, &"flame_wyrmling", "la Wyvernette au palier 2")
	ctx.combat.deal_damage(ctx.mini_boss, RunFixture.info(9999999.0))
	ctx.zones.step(0.1)
	check_eq(ctx.zones.zone_index, 2, "palier 3")
	ctx.zones.step(3.0)
	_end_tier(ctx)
	check(ctx.boss != null and ctx.boss.is_boss, "Pyrevorn au palier 3")
	check_eq(ctx.boss.boss_data.id, &"pyrevorn", "le Dévoreur du chapitre")


func test_pyrevorn_patterns_run() -> void:
	var ctx: RunContext = _start()
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"pyrevorn"), ctx.player.global_position + Vector2(400, 0))
	var controller := BossController.new(ctx, boss)
	for phase: BossPhaseData in GameDB.boss(&"pyrevorn").phases:
		for pattern: BossPatternData in phase.patterns:
			controller.call("_pattern_" + String(pattern.kind), pattern)
	var hazards: int = ctx.hazards.hazards.size()
	check(hazards > 0, "les attaques posent leurs dangers")
	for i: int in 60:
		ctx.time += 0.1
		controller.step(0.1)
		ctx.hazards.step(0.1)
	check(boss.visual.visible, "Pyrevorn revient au sol après l'envol")
	check(ctx.burn.plates.size() > 0, "la pluie du cratère et la chute laissent du sol brûlant")


func test_rocks_arc_from_the_vents() -> void:
	var ctx: RunContext = _start()
	check(ctx.rockfall != null, "pluie de roches active")
	var target: Vector2 = Vector2(-1800, -1700)
	ctx.rockfall.drop(target)
	check_eq(ctx.rockfall.falling.back()["from"], Vector2(-2200, -2100), "la roche part du cratère le plus proche")
