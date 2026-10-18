extends TestCase

func make_run(arena_id: StringName = &"three_rifts") -> RunController:
	var setup := RunSetup.new()
	setup.arena_id = arena_id
	setup.starter_id = &"mossback"
	setup.autopilot = true
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run

func test_finale_requires_clear_then_arrival_and_keeps_echoes() -> void:
	var run: RunController = make_run()
	var ctx: RunContext = run.ctx
	check(ctx.finale.walled(), "Ruines des Cascades : arène murée, sans cercle d'énergie")
	# Mode « vagues par zone » : la finale démarre quand la dernière zone est nettoyée (test_zone_mode).
	ctx.time = ctx.arena.boss_time
	ctx.finale.step(0.1)
	check_eq(ctx.finale.state, ArenaFinale.State.WAVES, "pas de finale au chrono en mode zones")
	var count: int = ctx.enemies.count()
	run.spawner.step(100)
	check_eq(ctx.enemies.count(), count, "aucune vague au chrono")
	check(ctx.boss == null, "pas de boss chronométré")
	for id: int in ctx.finale._wall_ids:
		check(not ctx.obstacles.wall_enabled[id], "entrées de l'arène ouvertes avant la finale")
	ctx.finale.start_travel()
	check_eq(ctx.finale.state, ArenaFinale.State.TRAVEL, "appel vers l'arène")
	ctx.player.position = Vector2(1100, 0)
	ctx.finale.step(10)
	check(not ctx.finale.closed(), "devant l'arène : rien ne se ferme")
	ctx.player.position = ctx.arena.finale_center - Vector2(200, 0)
	ctx.finale.step(0.1)
	check(ctx.finale.closed(), "entrées scellées dès l'arrivée dans l'arène")
	for id: int in ctx.finale._wall_ids:
		check(ctx.obstacles.wall_enabled[id], "barrière d'entrée fermée : %d" % id)
	check_eq(ctx.allies.team_size(), 1, "Écho conservé")
	check(ctx.boss == null, "animation avant apparition")
	ctx.finale.step(ctx.arena.finale_opening_duration)
	check(ctx.boss != null and ctx.boss.boss_data.id == &"nebulorax", "Nébulorax sort de la faille")
	var boss: Enemy = ctx.boss
	ctx.finale.step(5)
	check(ctx.boss == boss, "un seul boss")
	var outside := Vector2(1100, 0)
	check(not ctx.finale.contains(outside), "l'approche de l'arène n'en fait pas partie")
	ctx.time += 42.0
	ctx.events.boss_defeated.emit(boss)
	check(not ctx.finale.closed(), "combat terminé")
	check_near(ctx.stats.get_value(&"boss_fight_time"), 42.0, 0.01, "durée du combat mesurée (objectifs de carte)")
	RunFixture.dispose(run)


func test_arena_walls_seal_the_arena() -> void:
	var run: RunController = make_run()
	var ctx: RunContext = run.ctx
	# Zones nettoyées (leurs barrières ouvertes), entrées de l'arène fermées.
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, i in ctx.finale._wall_ids)
	ctx.flow.apply_walls(ctx.obstacles)
	var seeds: Array[Vector2] = [ctx.arena.finale_center, ctx.arena.zones[1].anchor]
	var labels: PackedInt32Array = ctx.flow.label_regions(seeds)
	check(ctx.flow.region_at(labels, ctx.arena.zones[1].anchor) != ctx.flow.region_at(labels, ctx.arena.finale_center),
		"barrières d'entrée : l'arène est isolée du reste de la carte")
	RunFixture.dispose(run)


func test_other_arenas_keep_timed_boss() -> void:
	var run: RunController = make_run(&"fractured_plain")
	check(run.ctx.finale == null, "autres arènes inchangées")
	run.ctx.time = run.ctx.arena.boss_time
	run.spawner.step(0.1)
	check(run.ctx.boss != null, "boss classique au temps prévu")
	RunFixture.dispose(run)
