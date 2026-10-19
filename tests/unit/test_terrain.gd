extends TestCase
## Brique B1 « terrain lent » (gués) : tout le monde y est ralenti, sauf la Ruée.

var run: RunController


func before_each() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	setup.arena_override = TestArena.build(&"fractured_plain", &"", ["shallows"])
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)


func after_each() -> void:
	RunFixture.dispose(run)


func test_shallows_slow_enemies_and_echoes() -> void:
	var ctx: RunContext = run.ctx
	check(ctx.terrain != null, "terrain lent actif")
	var water: Vector2 = ctx.arena.slow_zones[0].get_center()
	var dry: Vector2 = water + Vector2(0, -400)
	check_near(ctx.terrain_speed(water), ctx.arena.slow_zone_mult, 0.001, "dans le gué : ralenti")
	check_near(ctx.terrain_speed(dry), 1.0, 0.001, "hors du gué : vitesse normale")
	var wet: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), water)
	var normal: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), dry)
	ctx.enemies._tick_brain(wet, 0.05, water + Vector2(600, 0))
	ctx.enemies._tick_brain(normal, 0.05, dry + Vector2(600, 0))
	check_near(wet.velocity.length() / normal.velocity.length(), ctx.arena.slow_zone_mult, 0.05,
		"un Corrompu dans l'eau avance moins vite")
	var ally: Ally = ctx.allies.team[0]
	ally.global_position = water
	var from: Vector2 = ally.global_position
	ally.move_toward_point(water + Vector2(400, 0), 200.0, 0.1)
	check_near(ally.global_position.distance_to(from), 200.0 * 0.1 * ctx.arena.slow_zone_mult, 1.0,
		"un Écho dans l'eau avance moins vite")


func test_dash_keeps_its_speed_in_the_water() -> void:
	var ctx: RunContext = run.ctx
	var player: Player = ctx.player
	player.global_position = ctx.arena.slow_zones[0].get_center() - Vector2(300, 0)
	var from: Vector2 = player.global_position
	player._start_dash(Vector2.RIGHT)
	player.step(1.0 / 60.0)
	var expected: float = ctx.balance.dash_distance / ctx.balance.dash_duration / 60.0
	check_near(player.global_position.distance_to(from), expected, 1.0, "la Ruée traverse le gué à pleine vitesse")
