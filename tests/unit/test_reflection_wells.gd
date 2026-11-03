extends TestCase
## Carte 14, Puits des reflets (docs/design/CARTES.md) : défense d'autel, miroirs-portails (brique B6) et gardienne
## Dame des portails, piégée quand le Chasseur tient le portail par lequel elle ressort (docs/design/MONSTRES.md).

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"reflection_wells"
	setup.starter_id = &"ashblade"
	setup.run_seed = 3
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func _tick(ctx: RunContext, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		ctx.time += 0.05
		ctx.portals.step(0.05)
		t += 0.05


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"reflection_wells")
	check(arena != null and arena.altar_waves > 0, "défense d'autel")
	check_eq(arena.portal_pairs.size(), 8, "quatre paires de portails")
	check_eq(arena.boss_id, &"portal_lady", "gardienne : la Dame des portails")
	var marshes: ChapterData = GameDB.chapters.get(&"sunken_marshes")
	check_eq(marshes.maps[3].arena_id, &"reflection_wells", "quatrième carte du chapitre 3")
	check_eq(GameDB.monster(&"mossback").discovery_arena, &"reflection_wells", "Mousseroc s'y découvre")


func test_map_points_stand_on_open_ground() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = GameDB.arena(&"reflection_wells")
	for pos: Vector2 in arena.portal_pairs:
		check(not ctx.obstacles.blocks(pos, arena.portal_radius), "portail en %s : sol praticable" % pos)
	for pos: Vector2 in arena.altar_spawn_points:
		check(not ctx.obstacles.blocks(pos, 30.0), "arrivée des Corrompus en %s : sol praticable" % pos)
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ sur la boucle sud")
	# Les quatre coins de la boucle mènent à l'autel : la navigation passe par les ponts.
	for i: int in range(0, arena.portal_pairs.size(), 2):
		check(ctx.altar.guide.cost_at(arena.portal_pairs[i]) < FlowField.UNREACHED, "coin %d relié à l'autel" % i)


func test_portal_sends_the_hunter_to_its_twin_then_recharges() -> void:
	var ctx: RunContext = _start()
	var portal: Dictionary = ctx.portals.portals[0]
	var twin: Dictionary = ctx.portals.portals[1]
	ctx.player.global_position = portal["pos"]
	_tick(ctx, 0.05)
	check(ctx.player.global_position.distance_to(twin["pos"]) < ctx.arena.portal_radius * 2.0, "ressort par le jumeau")
	check(not ctx.portals.ready_for_player(1), "la paire se recharge")
	ctx.player.global_position = twin["pos"]
	_tick(ctx, 0.05)
	check(ctx.player.global_position.distance_to(twin["pos"]) < ctx.arena.portal_radius * 2.0, "pas de retour immédiat")
	_tick(ctx, ctx.arena.portal_cooldown + 0.1)
	check(ctx.portals.ready_for_player(1), "puis la paire est de nouveau prête")
	check_eq(int(ctx.stats.get_value(&"portal_jumps")), 1, "passage compté (objectif de carte)")


func test_corrupted_use_portals_at_a_limited_rate() -> void:
	var ctx: RunContext = _start()
	var portal: Dictionary = ctx.portals.portals[2]
	ctx.player.global_position = Vector2(0, 1856)
	var crowd: Array[Enemy] = []
	for i: int in 6:
		crowd.append(ctx.enemies.spawn(GameDB.enemy(&"wandering_shard"), portal["pos"] + Vector2(i * 4.0, 0)))
	_tick(ctx, 0.15)
	var sent: int = crowd.filter(func(e: Enemy) -> bool: return e.position.distance_to(portal["pos"]) > 300.0).size()
	check(sent >= 1 and sent <= 2, "débit limité : %d passé(s) d'un coup" % sent)


func test_shortcut_points_to_a_portal_when_far_from_the_altar() -> void:
	var ctx: RunContext = _start()
	var corner: Vector2 = ctx.portals.portals[0]["pos"]
	var shortcut: Vector2 = ctx.portals.shortcut(corner + Vector2(0, 150), ctx.altar.guide)
	check(shortcut != Vector2.INF, "depuis un coin de la boucle, le portail est le plus court vers l'autel")
	check(ctx.portals.shortcut(ctx.altar.position + Vector2(300, 0), ctx.altar.guide) == Vector2.INF,
		"près de l'autel : aucun détour par un portail")


func test_portal_lady_is_trapped_by_the_hunter_in_her_exit_portal() -> void:
	var ctx: RunContext = _start()
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"portal_lady"), ctx.altar.position + Vector2(0, 300))
	ctx.boss = boss
	var brain := BossController.new(ctx, boss)
	var lady: PortalGuardian = brain.portal_lady()
	var hop: BossPatternData = brain.data.phases[0].patterns[1]
	check_eq(hop.kind, &"portal_hop", "son saut de portail")
	lady.portal_hop(hop)
	var exit: Vector2 = lady.exit_position()
	check(exit != Vector2.INF, "un portail de sortie est annoncé")
	ctx.player.global_position = exit
	ctx.time = float(lady.hop["at"]) + 0.01
	brain.step(0.01)
	check(boss.position.distance_to(exit) < 120.0, "elle ressort par ce portail")
	check(brain.stunned_time > 0.0 and brain.heart_time > 0.0, "piégée : sonnée, dégâts doublés")
	check_eq(int(ctx.stats.get_value(&"boss_portal_trapped")), 1, "piège compté (objectif Cauchemar)")
