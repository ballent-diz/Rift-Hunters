extends TestCase
## Carte 25, Œil de la Faille (docs/maps/OEIL_DE_LA_FAILLE.md) : spirale de cinq zones (une par monde du voyage, avec
## sa brique de terrain), puis l'Abyssarque sur la plateforme. Dernière carte : la gagner ouvre le Cauchemar.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"rift_eye"
	setup.starter_id = &"ashblade"
	setup.run_seed = 10
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"rift_eye")
	check(arena.zones.size() == 5 and arena.has_finale(), "cinq zones puis la plateforme")
	check(arena.decor_scale < 1.0, "décor réduit (ECHELLE_CHAPITRES_4_5)")
	check(not arena.slow_zones.is_empty() and not arena.burn_plates.is_empty() and not arena.mud_zones.is_empty()
		and not arena.ice_patches.is_empty() and not arena.corrupted_patches.is_empty(), "une brique par monde")
	check_eq(arena.boss_id, &"abyssarch", "Dévoreur final")
	check_eq(GameDB.boss(&"abyssarch").signature, &"abyss_echoes", "Échos des mondes")
	check_eq(Campaign.final_map().arena_id, &"rift_eye", "dernière carte du jeu")


func test_points_stand_on_open_ground_and_zones_are_sealed() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ dégagé")
	for zone: LevelZoneData in arena.zones:
		check(not ctx.obstacles.blocks(zone.anchor, 40.0, false), "centre de zone praticable : %s" % zone.anchor)
	check(not ctx.obstacles.blocks(arena.finale_center, 150.0, false), "centre de la plateforme dégagé")
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.apply_walls(ctx.obstacles)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) >= FlowField.UNREACHED, "barrières étanches")
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	field.apply_walls(ctx.obstacles)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "la spirale mène à la plateforme")
	for zone: LevelZoneData in arena.zones:
		check(field.cost_at(zone.anchor) < FlowField.UNREACHED, "zone %s sur le parcours" % zone.anchor)


func test_abyssarch_calls_the_worlds_in_turn() -> void:
	var ctx: RunContext = _start()
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"abyssarch"), ctx.player.global_position + Vector2(500, 0))
	var brain := BossController.new(ctx, boss)
	var pattern: BossPatternData = null
	for p: BossPatternData in GameDB.boss(&"abyssarch").phases[0].patterns:
		if p.kind == &"abyss_echoes":
			pattern = p
	var before: int = ctx.enemies.count()
	brain.call("_pattern_abyss_echoes", pattern)
	check_eq(brain._echo_world, 1, "premier monde rappelé")
	ctx.time += pattern.telegraph + 0.1
	brain.step(0.1)
	check(ctx.enemies.count() > before, "la horde du Val surgit")
