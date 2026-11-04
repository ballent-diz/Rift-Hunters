extends TestCase
## Carte 16, Entrée du Glacier (docs/maps/ENTREE_DU_GLACIER.md) : première carte du chapitre 4. Vagues par zone de
## gauche à droite sur trois plateaux, glace qui fait glisser (brique B1), Patriarche des cimes sur la terrasse.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start(autopilot: bool = true) -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"glacier_entry"
	setup.starter_id = &"ashblade"
	setup.run_seed = 3
	setup.autopilot = autopilot
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"glacier_entry")
	check(arena != null and arena.zones.size() == 2 and arena.has_finale(), "deux plateaux puis la terrasse")
	check_eq(arena.boss_id, &"peak_patriarch", "gardien : le Patriarche des cimes")
	check_eq(GameDB.boss(&"peak_patriarch").signature, &"avalanche", "mécanique phare : l'avalanche")
	check_eq(arena.ice_patches.size(), 6, "six plaques de glace")
	var glacier: ChapterData = GameDB.chapters.get(&"silent_glacier")
	check(glacier != null and glacier.order == 4, "chapitre 4 dans la campagne")
	check_eq(glacier.maps[0].arena_id, &"glacier_entry", "l'Entrée du Glacier ouvre le chapitre")


func test_map_points_stand_on_open_ground() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ sur la neige libre")
	for zone: LevelZoneData in arena.zones:
		check(not ctx.obstacles.blocks(zone.anchor, 40.0, false), "centre de zone praticable : %s" % zone.anchor)
	for rect: Rect2 in arena.ice_patches:
		check(not ctx.obstacles.blocks(rect.get_center(), 30.0, false), "glace praticable en %s" % rect.get_center())
	check(not ctx.obstacles.blocks(arena.finale_center, 150.0, false), "centre de la terrasse dégagé")


func test_terrace_is_reachable_through_both_passes() -> void:
	var ctx: RunContext = _start()
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.update(ctx.arena.finale_center)
	check(field.cost_at(ctx.player.global_position) >= FlowField.UNREACHED, "barrières fermées : terrasse coupée")
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	field.apply_walls(ctx.obstacles)
	field.update(ctx.arena.finale_center)
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "le départ mène à la terrasse")
	check(field.cost_at(ctx.arena.zones[1].anchor) < FlowField.UNREACHED, "en passant par le plateau des glaces")


## Brique B1 : sur la glace, on garde son élan et on glisse ; hors de la glace, l'arrêt est immédiat.
func test_ice_keeps_momentum() -> void:
	# Sans bot : aucune direction tenue.
	var ctx: RunContext = _start(false)
	var ice: IceDirector = ctx.ice
	check(ice != null, "la carte a sa glace")
	var center: Vector2 = ctx.arena.ice_patches[2].get_center()
	check(ice.on_ice(center), "centre d'une plaque : glace")
	check(not ice.on_ice(ctx.arena.ice_patches[2].position), "coin du rectangle : hors de l'ellipse")
	var top: float = 200.0
	var v: Vector2 = ice.glide(Vector2.ZERO, Vector2.RIGHT * top, top, 0.1)
	check(v.length() < top * 0.25, "élan : la pleine vitesse n'est pas atteinte d'un coup")
	var still: Vector2 = Vector2.RIGHT * top
	for i: int in 30:
		still = ice.glide(still, Vector2.ZERO, top, 1.0 / 60.0)
	check(still.length() > top * 0.5, "glissade : une demi-seconde après, on glisse encore")
	for i: int in 90:
		still = ice.glide(still, Vector2.ZERO, top, 1.0 / 60.0)
	check(still.length() < 1.0, "arrêt au bout d'environ 1,5 s")
	# Le Chasseur posé sur la glace dérive après avoir lâché la direction.
	var player: Player = ctx.player
	player.global_position = center
	player.velocity = Vector2.RIGHT * 180.0
	var before: Vector2 = player.global_position
	player.step(1.0 / 60.0)
	check(player.global_position.x > before.x + 1.0, "le Chasseur glisse sans direction")
