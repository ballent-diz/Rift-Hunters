extends TestCase
## Abris posés par le jeu (ArenaData.cover_rocks, docs/design/DIFFICULTE.md) : sur chaque carte qui en a, chaque rocher
## arrête les tirs, laisse passer autour de lui, et l'arène du gardien reste accessible depuis le départ.

const ARENAS: Array[StringName] = [&"root_mangrove", &"tide_temple", &"crystal_gardens", &"reflection_wells",
	&"marsh_heart"]


func _start(arena_id: StringName) -> RunController:
	var setup := RunSetup.new()
	setup.arena_id = arena_id
	setup.starter_id = &"ashblade"
	setup.run_seed = 3
	setup.autopilot = true
	var run: RunController = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run


func test_cover_rocks_shelter_without_closing_the_way() -> void:
	for arena_id: StringName in ARENAS:
		var run: RunController = _start(arena_id)
		var ctx: RunContext = run.ctx
		var arena: ArenaData = ctx.arena
		check(not arena.cover_rocks.is_empty(), "%s : des abris" % arena_id)
		for pos: Vector2 in arena.cover_rocks:
			check(ctx.obstacles.blocks_shot(pos), "%s : l'abri en %s arrête les tirs" % [arena_id, pos])
			var free: int = 0
			for k: int in 12:
				var around: Vector2 = pos + Vector2.RIGHT.rotated(TAU * k / 12.0) * (arena.cover_radius + 45.0)
				free += 0 if ctx.obstacles.blocks(around, 16.0, false) else 1
			check(free >= 6, "%s : on passe autour de l'abri en %s (%d/12)" % [arena_id, pos, free])
		# Barrières de zone ouvertes : l'arène du gardien reste atteignable depuis le départ.
		for i: int in ctx.obstacles.walls.size():
			ctx.obstacles.set_wall_enabled(i, false)
		# Défense d'autel : un point de la place, à côté du sceau (son corps occupe le centre).
		var goal: Vector2 = arena.finale_center if arena.has_finale() else arena.altar_point + Vector2(320, 0)
		var field := FlowField.new()
		field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
		field.update(goal)
		check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "%s : arène du gardien atteignable" % arena_id)
		RunFixture.dispose(run)
		await host.get_tree().process_frame
