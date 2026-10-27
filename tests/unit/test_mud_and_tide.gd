extends TestCase
## Chapitre 3 (docs/design/CARTES.md) : vase qui colle (carte 11) et marée (carte 12).

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(configure: Callable) -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"ashblade"
	setup.run_seed = 4
	setup.autopilot = true
	var arena: ArenaData = GameDB.arena(&"fractured_plain").duplicate()
	configure.call(arena)
	setup.arena_override = arena
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_mud_slows_everyone_and_sticks() -> void:
	var ctx: RunContext = _start(func(arena: ArenaData) -> void:
		arena.mud_zones = [Rect2(200, -100, 300, 200)]
		arena.mud_mult = 0.4
		arena.mud_stick = 1.0)
	check(ctx.terrain != null, "terrain actif")
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), Vector2(300, 0))
	var id: int = enemy.get_instance_id()
	check_near(ctx.terrain_speed(Vector2(300, 0), id), 0.4, 0.001, "ralenti dans la vase")
	check_near(ctx.terrain_speed(Vector2(600, 0), id), 0.4, 0.05, "colle juste après la sortie")
	ctx.terrain.step(0.5)
	var half: float = ctx.terrain_speed(Vector2(600, 0), id)
	check(half > 0.45 and half < 0.95, "la vitesse revient progressivement (%.2f)" % half)
	ctx.terrain.step(0.6)
	check_near(ctx.terrain_speed(Vector2(600, 0), id), 1.0, 0.001, "décollé")
	check_near(ctx.terrain_speed(Vector2(600, 0), 0), 1.0, 0.001, "hors vase sans identité : vitesse normale")
	check(ctx.terrain.danger(Vector2(300, 0)).length() > 0.0, "le bot cherche à sortir de la vase")


func test_tide_floods_causeways_then_recedes() -> void:
	var causeway := Rect2(250, -60, 200, 120)
	var ctx: RunContext = _start(func(arena: ArenaData) -> void:
		arena.tide_causeways = [causeway]
		arena.tide_first = 1.0
		arena.tide_warning = 1.0
		arena.tide_high = 2.0
		arena.tide_low = 3.0)
	check(ctx.tide != null, "marée active")
	check(not ctx.obstacles._wall_blocks(Vector2(350, 0), 10.0), "marée basse : chaussée praticable")
	ctx.player.global_position = Vector2(340, 0)
	var t: float = 0.0
	while t < 1.5:
		ctx.tide.step(0.1)
		t += 0.1
	check_eq(ctx.tide.state, TideDirector.State.RISING, "alerte avant la marée haute")
	check(ctx.tide.danger(Vector2(340, 0)).length() > 0.0, "le bot quitte la chaussée pendant l'alerte")
	while t < 2.2:
		ctx.tide.step(0.1)
		t += 0.1
	check(ctx.tide.is_high(), "marée haute")
	check(ctx.obstacles._wall_blocks(Vector2(350, 0), 10.0), "chaussée noyée : infranchissable")
	check(not causeway.has_point(ctx.player.global_position), "le Chasseur est repoussé sur la rive")
	while t < 4.5:
		ctx.tide.step(0.1)
		t += 0.1
	check(not ctx.tide.is_high() and not ctx.obstacles._wall_blocks(Vector2(350, 0), 10.0), "marée basse : raccourci rouvert")
