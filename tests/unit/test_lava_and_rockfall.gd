extends TestCase
## Cartes 9 et 10 (docs/design/CARTES.md) : débordements de lave (crues habillées en lave, plaques brûlantes après
## le débordement) et pluie de roches magmatiques (chutes annoncées, dégâts à tous, cadence qui augmente).

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(configure: Callable) -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"ashblade"
	setup.run_seed = 6
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


func test_lava_overflow_burns_then_leaves_plates() -> void:
	var ctx: RunContext = _start(func(arena: ArenaData) -> void:
		arena.flood_lanes = [Rect2(-200, -60, 600, 120)]
		arena.flood_dirs = [Vector2.RIGHT]
		arena.flood_style = &"lava"
		arena.flood_push = 0.0
		arena.flood_damage = 12.0
		arena.flood_first = 0.5
		arena.flood_afterburn = 5.0)
	check(ctx.flood.is_lava(), "habillage lave")
	ctx.player.global_position = Vector2(100, 0)
	var hp: float = ctx.player.hp
	var plates: int = ctx.burn.plates.size()
	var t: float = 0.0
	while t < ctx.arena.flood_first + ctx.arena.flood_warning + ctx.arena.flood_duration + 0.3:
		ctx.flood.step(0.05)
		t += 0.05
	check(ctx.player.hp < hp, "la lave blesse le Chasseur resté sur la croûte")
	check_eq(ctx.flood.drift(Vector2(100, 0)), Vector2.ZERO, "la lave ne pousse pas")
	check(ctx.burn.plates.size() > plates, "plaques brûlantes laissées dans le lit")


func test_rockfall_hits_everyone_and_leaves_a_plate() -> void:
	var ctx: RunContext = _start(func(arena: ArenaData) -> void:
		arena.rockfall_interval = 6.0)
	check(ctx.rockfall != null, "pluie de roches active")
	var pos: Vector2 = ctx.player.global_position + Vector2(300, 0)
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"husk"), pos)
	var hp: float = enemy.hp
	var plates: int = ctx.burn.plates.size()
	ctx.rockfall.drop(pos)
	for i: int in int((ctx.arena.rockfall_warning + 0.2) / 0.05):
		ctx.rockfall.step(0.05)
	check(enemy.hp < hp, "la roche écrase aussi les Corrompus")
	check(ctx.burn.plates.size() > plates, "plaque brûlante à l'impact")
	check_eq(ctx.rockfall.impacts, 1, "un impact")


func test_rockfall_gets_faster_with_zones_and_boss() -> void:
	var ctx: RunContext = _start(func(arena: ArenaData) -> void:
		arena.rockfall_interval = 6.0)
	var base: float = ctx.rockfall.interval()
	ctx.boss = ctx.enemies.spawn_boss(GameDB.boss(&"nebulorax"), Vector2(600, 0))
	check(ctx.rockfall.interval() < base, "plus fréquente pendant le combat final")
	for i: int in 3:
		ctx.rockfall._timer = 0.0
		ctx.rockfall.step(0.01)
	check(ctx.hazards.hazards.size() >= 3, "des chutes annoncées au sol")
