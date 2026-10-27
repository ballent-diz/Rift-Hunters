extends TestCase
## Carte 8 (docs/design/CARTES.md, brique B8) : nids qui pondent tant qu'ils tiennent debout, petits hors des vagues.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(points: Array[Vector2]) -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"ashblade"
	setup.run_seed = 2
	setup.autopilot = true
	var arena: ArenaData = GameDB.arena(&"fractured_plain").duplicate()
	arena.nest_points = points
	arena.nest_interval = 1.0
	setup.arena_override = arena
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _advance(ctx: RunContext, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.1
		ctx.nests.step(0.1)
		ctx.enemies._step_pending_actions()
		t += 0.1


func test_nest_lays_until_destroyed() -> void:
	var ctx: RunContext = _start([Vector2(300, 0)] as Array[Vector2])
	check(ctx.nests != null and ctx.nests.standing() == 1, "un nid debout")
	var nest: Enemy = ctx.nests.nests[0]["enemy"]
	check(nest.is_obstacle and nest.is_target(), "structure qu'on peut viser")
	_advance(ctx, 3.0)
	check(ctx.nests.hatched >= 2, "il pond des Rampe-cendres")
	check(ctx.enemies.count_hostile() == 0, "ses petits ne comptent pas dans les vagues")
	ctx.combat.deal_damage(nest, RunFixture.info(99999.0))
	var before: int = ctx.nests.hatched
	_advance(ctx, 3.0)
	check_eq(ctx.nests.standing(), 0, "nid détruit")
	check(ctx.nests.hatched <= before + 2, "plus de ponte une fois détruit")


func test_far_nest_sleeps() -> void:
	var ctx: RunContext = _start([Vector2(2400, 0)] as Array[Vector2])
	_advance(ctx, 3.0)
	check_eq(ctx.nests.hatched, 0, "un nid loin du Chasseur ne pond pas")
