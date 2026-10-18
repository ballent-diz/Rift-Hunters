extends TestCase
## Mode « fermeture de failles » (Hautes Terres d'Orage) : failles ciblables qui crachent des Corrompus, progression,
## puis place centrale murée et Astravorn.

var run: RunController


func before_each() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"storm_highlands"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)


func after_each() -> void:
	RunFixture.dispose(run)


func test_rifts_are_targetable_structures_that_spawn_enemies() -> void:
	var ctx: RunContext = run.ctx
	check(ctx.rifts != null, "Hautes Terres : mode failles")
	check_eq(ctx.rifts.total(), 4, "quatre failles")
	for rift: Enemy in ctx.rifts.rifts:
		check(rift.is_target(), "faille ciblée par les attaques automatiques")
		check(not ctx.obstacles.blocks(rift.position, 0.0), "faille posée sur un sol praticable")
	var rift: Enemy = ctx.rifts.rifts[0]
	ctx.player.global_position = rift.position + Vector2(120, 0)
	check_eq(ctx.enemies.find_nearest(ctx.player.global_position, 400.0), rift, "le Chasseur vise la faille proche")
	var before: int = ctx.enemies.count()
	for i: int in 20:
		ctx.rifts.step(0.5)
		run.spawner.step(0.5)
	check(ctx.enemies.count() > before, "des Corrompus sortent des failles ouvertes")
	check(ctx.time < ctx.arena.boss_time and ctx.boss == null, "pas de boss chronométré")


func test_closing_all_rifts_calls_to_the_walled_plaza() -> void:
	var ctx: RunContext = run.ctx
	check(ctx.finale.walled(), "place centrale murée")
	for i: int in ctx.rifts.rifts.size():
		var rift: Enemy = ctx.rifts.rifts[i]
		var info := DamageInfo.new()
		info.amount = rift.max_hp * 10.0
		ctx.combat.deal_damage(rift, info)
		ctx.combat.flush_queue()
		check_eq(ctx.rifts.closed, i + 1, "faille refermée : %d" % (i + 1))
		if i < 3:
			check_eq(ctx.finale.state, ArenaFinale.State.WAVES, "pas de finale avant la dernière faille")
	check_eq(ctx.finale.state, ArenaFinale.State.TRAVEL, "appel vers la place centrale")
	check_eq(ctx.stats.get_value(&"rifts_closed"), 4.0, "failles comptées")
	ctx.player.global_position = ctx.arena.finale_center + Vector2(150, 0)
	ctx.finale.step(0.1)
	check(ctx.finale.closed(), "entrées de la place scellées à l'arrivée")
	ctx.finale.step(ctx.arena.finale_opening_duration)
	check(ctx.boss != null and ctx.boss.boss_data.id == &"astravorn", "Astravorn sort de la faille")


func test_plaza_walls_seal_the_plaza() -> void:
	var ctx: RunContext = run.ctx
	for id: int in ctx.finale._wall_ids:
		ctx.obstacles.set_wall_enabled(id, true)
	ctx.flow.apply_walls(ctx.obstacles)
	var seeds: Array[Vector2] = [ctx.arena.finale_center, ctx.player.global_position]
	var labels: PackedInt32Array = ctx.flow.label_regions(seeds)
	check(ctx.flow.region_at(labels, ctx.player.global_position) != ctx.flow.region_at(labels, ctx.arena.finale_center),
		"barrières : la place est isolée du reste des landes")
	for point: Vector2 in ctx.arena.rift_points:
		check(ctx.flow.region_at(labels, point) != ctx.flow.region_at(labels, ctx.arena.finale_center),
			"faille hors de la place : %s" % point)
