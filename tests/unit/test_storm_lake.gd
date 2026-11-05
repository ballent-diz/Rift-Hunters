extends TestCase
## Carte 18, Lac gelé des tempêtes (docs/maps/LAC_GELE_DES_TEMPETES.md) : vagues par zone autour d'un lac gelé, du
## nord au sud-est puis l'amphithéâtre en croissant ; blizzard (variante de la brique B2) et Loup alpha des tempêtes.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"storm_lake"
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
	var arena: ArenaData = GameDB.arena(&"storm_lake")
	check(arena.zones.size() == 3 and arena.has_finale(), "trois zones puis l'amphithéâtre")
	check(arena.blizzard and arena.night > 0.0, "blizzard")
	check_eq(arena.firefly_glades.size(), 7, "sept refuges du vent")
	check_eq(GameDB.boss(&"blizzard_alpha").signature, &"storm_hunt", "gardien : Chasse dans la tempête")
	check_eq(GameDB.chapters.get(&"silent_glacier").maps[2].arena_id, &"storm_lake", "troisième carte du chapitre 4")


func test_points_stand_on_open_ground_and_connect() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ dégagé au camp nord")
	for zone: LevelZoneData in arena.zones:
		check(not ctx.obstacles.blocks(zone.anchor, 40.0, false), "centre de zone praticable : %s" % zone.anchor)
	for glade: Vector2 in arena.firefly_glades:
		check(not ctx.obstacles.blocks(glade, 20.0, false), "refuge du vent praticable : %s" % glade)
	check(not ctx.obstacles.blocks(arena.finale_center, 200.0, false), "amphithéâtre dégagé")
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "le camp mène à l'amphithéâtre")
	for zone: LevelZoneData in arena.zones:
		check(field.cost_at(zone.anchor) < FlowField.UNREACHED, "zone %s sur le parcours" % zone.anchor)


## Blizzard : au calme, cibles libres et pas de vent ; en rafale, le vent pousse, sauf dans un refuge du vent.
func test_blizzard_gusts_and_shelters() -> void:
	var ctx: RunContext = _start()
	var night: NightDirector = ctx.night
	check(night != null, "blizzard actif")
	ctx.time = 1.0
	check_eq(night.gust_strength(), 0.0, "calme au début du cycle")
	check_eq(night.wind(Vector2(500, 0)), Vector2.ZERO, "pas de vent au calme")
	ctx.time = ctx.arena.blizzard_period - 1.5
	night.step(0.0)
	check(night.gust_strength() > 0.9, "rafale en fin de cycle")
	check(night.wind(ctx.arena.zones[1].anchor).length() > 1.0, "le vent pousse en terrain ouvert")
	check_eq(night.wind(ctx.arena.firefly_glades[0]), Vector2.ZERO, "abrité dans un refuge du vent")
