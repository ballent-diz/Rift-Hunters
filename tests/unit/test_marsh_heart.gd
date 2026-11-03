extends TestCase
## Carte 15, Cœur des marais (docs/design/CARTES.md) : finale du chapitre 3. Vagues par zone du sud au nord, vase,
## marée sur les chaussées hautes, cristaux-miroirs et abris sur la terrasse, Glauquemire.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"marsh_heart"
	setup.starter_id = &"ashblade"
	setup.run_seed = 3
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"marsh_heart")
	check(arena != null and arena.zones.size() == 2 and arena.has_finale(), "deux zones puis la terrasse")
	check_eq(arena.boss_id, &"glauquemire", "finale : Glauquemire, Dévoreur du chapitre 3")
	check(not arena.mud_zones.is_empty() and not arena.tide_causeways.is_empty(), "vase et marée")
	check_eq(arena.crystal_mirrors.size(), 4, "quatre cristaux-miroirs sur la terrasse")
	var marshes: ChapterData = GameDB.chapters.get(&"sunken_marshes")
	check_eq(marshes.maps.size(), 5, "chapitre 3 complet : cinq cartes")
	check_eq(marshes.maps[4].arena_id, &"marsh_heart", "le Cœur des marais ferme le chapitre")
	check_eq(GameDB.monster(&"gloommaw").discovery_arena, &"marsh_heart", "Gueule-d'ombre s'y découvre")


func test_map_points_stand_on_open_ground() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ au sud, sur un sol praticable")
	for zone: LevelZoneData in arena.zones:
		check(not ctx.obstacles.blocks(zone.anchor, 40.0, false), "centre de zone praticable : %s" % zone.anchor)
	for pos: Vector2 in arena.crystal_mirrors:
		check(not ctx.obstacles.blocks(pos, 40.0, false), "cristal en %s : sol praticable" % pos)
	for rect: Rect2 in arena.mud_zones:
		check(not ctx.obstacles.blocks(rect.get_center(), 30.0, false), "vase praticable en %s" % rect.get_center())
	check(not ctx.obstacles.blocks(arena.finale_center, 200.0, false), "centre de la terrasse dégagé")


func test_cover_rocks_block_shots_on_the_terrace() -> void:
	var ctx: RunContext = _start()
	for pos: Vector2 in ctx.arena.cover_rocks:
		var inside: bool = (pos - ctx.arena.finale_center).length() < ctx.arena.finale_radii.x
		check(inside, "abri dans l'arène de la terrasse : %s" % pos)
		check(ctx.obstacles.blocks_shot(pos), "l'abri arrête les tirs : %s" % pos)
		var before: Vector2 = pos + Vector2(-200, 0)
		var after: Vector2 = pos + Vector2(200, 0)
		check(not ctx.obstacles.line_clear(before, after), "pas de ligne de vue à travers l'abri")


func test_terrace_is_reachable_from_the_start() -> void:
	var ctx: RunContext = _start()
	# Barrières de zone ouvertes (elles tombent une fois chaque zone nettoyée).
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.update(ctx.arena.finale_center + Vector2(0, 300))
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "le départ mène à la terrasse")
	check(field.cost_at(ctx.arena.zones[1].anchor) < FlowField.UNREACHED, "en passant par le temple")
