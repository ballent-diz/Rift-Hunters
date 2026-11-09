extends TestCase
## Carte 24, Panthéon brisé (docs/maps/PANTHEON_BRISE.md) : fermeture de quatre failles, statues qui s'éveillent sur
## leurs socles (B8, StatueDirector), Échos piégés à libérer (B10, EchoCageDirector) et Gardienne du Panthéon.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"shattered_pantheon"
	setup.starter_id = &"ashblade"
	setup.run_seed = 8
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"shattered_pantheon")
	check_eq(arena.rift_points.size(), 4, "quatre failles")
	check(arena.has_finale(), "gardien sur la place centrale")
	check_eq(arena.statue_plinths.size(), 11, "onze socles")
	check_eq(arena.echo_cages.size(), 3, "trois cages d'Échos")
	check_eq(GameDB.boss(arena.boss_id).signature, &"pantheon_wake", "gardien : Réveil du Panthéon")
	check_eq(GameDB.chapters.get(&"rift_city").maps[2].arena_id, &"shattered_pantheon", "troisième carte du chapitre 5")


func test_points_stand_on_open_ground_and_connect() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ dégagé")
	for point: Vector2 in arena.rift_points:
		check(not ctx.obstacles.blocks(point, 60.0, false), "cour de faille dégagée : %s" % point)
	for cage: Vector2 in arena.echo_cages:
		check(not ctx.obstacles.blocks(cage, 30.0, false), "cage praticable : %s" % cage)
	check(not ctx.obstacles.blocks(arena.finale_center, 120.0, false), "place centrale dégagée")
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "le départ mène à la place")
	for point: Vector2 in arena.rift_points + arena.echo_cages:
		check(field.cost_at(point) < FlowField.UNREACHED, "%s sur le parcours" % point)
	for plinth: Vector2 in arena.statue_plinths:
		var foot: Vector2 = ctx.obstacles.push_out(plinth + Vector2(0, 100), 38.0)
		check(foot.distance_to(plinth) < 400.0 and field.cost_at(foot) < FlowField.UNREACHED,
			"la statue du socle %s descend sur le parcours" % plinth)


func test_statue_awakens_when_the_hunter_passes() -> void:
	var ctx: RunContext = _start()
	var statues: StatueDirector = ctx.statues
	var plinth: Vector2 = ctx.arena.statue_plinths[10]
	check_eq(statues.dormant_count(), 11, "toutes endormies")
	ctx.player.global_position = ctx.obstacles.push_out(plinth + Vector2(0, 200), 14.0)
	statues.step(0.1)
	check_eq(statues.states[10], 1, "la statue tremble")
	statues.step(ctx.arena.statue_warning + 0.1)
	check_eq(statues.states[10], 2, "elle descend de son socle")
	var awake: int = 0
	for enemy: Enemy in ctx.enemies.list:
		if enemy.alive and enemy.data.id == &"awakened_statue":
			awake += 1
	check_eq(awake, 1, "une Statue éveillée")
	check(statues.nearest_dormant(plinth, 100.0) < 0, "le socle reste vide")


func test_freeing_a_cage_heals_and_drops_a_chest() -> void:
	var ctx: RunContext = _start()
	var cages: EchoCageDirector = ctx.cages
	ctx.player.global_position = ctx.arena.echo_cages[0]
	ctx.player.hp = ctx.player.max_hp * 0.5
	var chests: int = ctx.pickups.items.size()
	var before: int = ctx.enemies.count()
	cages.step(0.1)
	check(ctx.enemies.count() > before, "embuscade à l'ouverture")
	for i: int in int(ctx.arena.echo_cage_time / 0.25) + 2:
		cages.step(0.25)
	check_eq(cages.freed(), 1, "cage brisée")
	check(ctx.player.hp > ctx.player.max_hp * 0.5, "l'Écho libéré soigne")
	check(ctx.pickups.items.size() > chests, "un coffre tombe")
	check_eq(ctx.stats.counters.get(&"echoes_freed", 0.0), 1.0, "compté pour l'objectif")
