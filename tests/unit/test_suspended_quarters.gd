extends TestCase
## Carte 23, Quartiers suspendus (docs/maps/QUARTIERS_SUSPENDUS.md) : vagues par zone d'îlot en îlot, téléporteurs de
## faille (B6, PortalDirector) qui s'allument avec la progression, refuge accessible par eux seuls, Grand Héraldiste.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"suspended_quarters"
	setup.starter_id = &"ashblade"
	setup.run_seed = 9
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"suspended_quarters")
	check(arena.zones.size() == 2 and arena.has_finale(), "deux zones puis la place des quartiers hauts")
	check_eq(arena.portal_pairs.size(), 6, "trois paires de téléporteurs")
	check(arena.portal_painted, "socles peints")
	check_eq(GameDB.boss(arena.boss_id).signature, &"soul_chain", "gardien : Chaîne d'âmes")
	check_eq(GameDB.chapters.get(&"rift_city").maps[2].arena_id, &"suspended_quarters", "troisième carte du chapitre 5")


func test_points_bridges_and_refuge() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ dégagé")
	for zone: LevelZoneData in arena.zones:
		check(not ctx.obstacles.blocks(zone.anchor, 40.0, false), "centre de zone praticable : %s" % zone.anchor)
	for portal: Dictionary in ctx.portals.portals:
		check(not ctx.obstacles.blocks(portal["pos"], 30.0, false), "socle praticable : %s" % portal["pos"])
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.apply_walls(ctx.obstacles)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) >= FlowField.UNREACHED, "barrières étanches")
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	field.apply_walls(ctx.obstacles)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "les trois ponts mènent à la finale")
	check(field.cost_at(ctx.portals.portals[5]["pos"]) >= FlowField.UNREACHED, "le refuge n'a pas d'accès à pied")


## Les paires s'allument avec la progression : aucune ne permet de sauter une zone.
func test_teleporters_follow_progress() -> void:
	var ctx: RunContext = _start()
	var portals: PortalDirector = ctx.portals
	check(not portals.pair_unlocked(0) and not portals.pair_unlocked(1) and not portals.pair_unlocked(2), "éteints au départ")
	ctx.zones.zone_index = 1
	check(portals.pair_unlocked(0) and portals.pair_unlocked(2), "A et C allumés dans la deuxième zone")
	check(not portals.pair_unlocked(1), "B attend la finale")
	ctx.zones.zone_index = 2
	check(portals.pair_unlocked(1), "B allumé à la finale")
	ctx.zones.zone_index = 1
	ctx.player.global_position = portals.portals[4]["pos"]
	portals.step(0.1)
	check(ctx.player.global_position.distance_to(portals.portals[5]["pos"]) < 200.0, "C mène au refuge")
