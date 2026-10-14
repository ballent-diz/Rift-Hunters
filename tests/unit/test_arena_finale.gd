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
	ctx.time = ctx.arena.boss_time
	ctx.enemies.spawn(GameDB.enemy(&"skitterling"), ctx.player.position + Vector2(100, 0))
	ctx.finale.step(0.1)
	check_eq(ctx.finale.state, ArenaFinale.State.CLEARING, "attente du dernier ennemi")
	var count: int = ctx.enemies.count()
	run.spawner.step(100)
	check_eq(ctx.enemies.count(), count, "aucune nouvelle vague")
	check(ctx.boss == null, "pas de boss chronométré")
	ctx.enemies.clear_all()
	ctx.finale.step(0.1)
	check_eq(ctx.finale.state, ArenaFinale.State.TRAVEL, "appel vers le cercle")
	ctx.finale.step(10)
	check(ctx.boss == null, "attend la venue du Chasseur")
	ctx.player.position = ctx.arena.finale_center - Vector2(200, 0)
	ctx.finale.step(0.1)
	check(ctx.finale.closed(), "sorties fermées à l’entrée")
	check_eq(ctx.allies.team_size(), 1, "Écho conservé")
	check(ctx.boss == null, "animation avant apparition")
	ctx.finale.step(ctx.arena.finale_opening_duration)
	check(ctx.boss != null and ctx.boss.boss_data.id == &"nebulorax", "Nébulorax sort de la faille")
	var boss: Enemy = ctx.boss
	ctx.finale.step(5)
	check(ctx.boss == boss, "un seul boss")
	ctx.player.position = ctx.arena.finale_center + Vector2(-800, 0)
	ctx.finale.enforce_boundary()
	check(ctx.finale.contains(ctx.player.position, ctx.player.radius), "sortie infranchissable")
	ctx.events.boss_defeated.emit(boss)
	check(not ctx.finale.closed(), "barrière levée après victoire")
	RunFixture.dispose(run)

func test_other_arenas_keep_timed_boss() -> void:
	var run: RunController = make_run(&"fractured_plain")
	check(run.ctx.finale == null, "autres arènes inchangées")
	run.ctx.time = run.ctx.arena.boss_time
	run.spawner.step(0.1)
	check(run.ctx.boss != null, "boss classique au temps prévu")
	RunFixture.dispose(run)
