extends TestCase
## Niveau rectangulaire : chargement, routes connexes et intégration en partie.


func test_level_and_original_panels_load() -> void:
	var arena: ArenaData = GameDB.arena(&"three_rifts")
	check(arena != null and arena.unlocked_by_default, "niveau disponible sans progression")
	check_eq(arena.size, Vector2(5016, 1672), "trois panneaux carrés sans déformation")
	var env: EnvironmentSet = Assets.environment(arena.environment_id)
	check(env != null and env.is_map(), "décor chargé")
	check_eq(env.map_tiles.size(), 3, "une image continue répartie en trois textures contiguës")
	check(env.map_texture.get_width() * env.map_tiles.size() >= 11000, "texture agrandie pour le rendu en jeu")
	check_near(env.map_texture.get_width() * env.map_tiles.size() / float(env.map_texture.get_height()), 3, .001, "panorama sans déformation")
	check_eq(env.field_image.get_size(), Vector2i(2508, 836), "champ rectangulaire")


func test_routes_connect_all_three_maps_with_enemy_clearance() -> void:
	var arena: ArenaData = GameDB.arena(&"three_rifts")
	var ground := ArenaGround.new()
	ground.setup(arena, 7)
	var field: ObstacleField = ground.obstacle_field()
	check(field.distance(ground.player_start()) >= 36, "départ sûr dans la première image")
	check(ground.player_start().x < -1300 and ground.player_start().y < -300, "départ au nord-ouest")
	var flow := FlowField.new()
	flow.setup(field, ground.arena_rect(), arena.navigation_cell_size)
	flow.update(ground.player_start())
	for pixel: Vector2 in [Vector2(1280, 110), Vector2(1900, 332), Vector2(2600, 690), Vector2(3420, 700)]:
		var point: Vector2 = pixel * (4.0 / 3.0) - arena.size * 0.5
		check(field.distance(point) >= 12, "point de passage praticable %s" % pixel)
		check(flow.cost_at(point) < FlowField.UNREACHED, "route continue jusqu’à %s" % pixel)
	check(field.distance(Vector2(.35, .73) * arena.size - arena.size * 0.5) < 0, "eau infranchissable")
	check(field.distance(Vector2(3520, 80) * (4.0 / 3.0) - arena.size * 0.5) < 0, "vide hors plateforme infranchissable")
	ground.free()


func test_level_starts_with_camera_and_existing_combat() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	var run: RunController = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	check(run.ctx.obstacles.distance(run.ctx.player.global_position) >= run.ctx.player.radius, "départ hors obstacle")
	check_eq(run.camera.limit_left, -2508, "caméra limitée au début")
	check_eq(run.camera.limit_right, 2508, "caméra limitée à la fin")
	check(run.ctx.flow != null and run.spawner.current_wave() != null, "navigation et vagues existantes actives")
	RunFixture.dispose(run)


func test_missing_panel_falls_back_and_is_reported() -> void:
	var e: Dictionary = Assets.manifest["environment.cascade_ruins"].duplicate(true)
	e["map"] = "res://missing-map.png"
	check(EnvironmentSet.from_entry(&"environment.invalid", e) == null, "décor incomplet rejeté")
	check_eq(AssetValidator.validate_environment("environment.invalid", e)["status"], "ERROR", "asset manquant signalé")


func test_open_plazas_allow_turning_without_small_rock_collisions() -> void:
	var arena: ArenaData = GameDB.arena(&"three_rifts")
	var ground := ArenaGround.new()
	ground.setup(arena, 7)
	var field: ObstacleField = ground.obstacle_field()
	for uv: Vector2 in [Vector2(.15, .52), Vector2(.44, .56), Vector2(.615, .56)]:
		var center: Vector2 = uv * arena.size - arena.size * .5
		for i: int in 24:
			var point: Vector2 = center + Vector2.RIGHT.rotated(i * TAU / 24) * 60
			check(not field.blocks(point, 12), "tourner dans la place %s" % uv)
	for i: int in 40:
		var point := Vector2(lerpf(.655, .745, i / 39.0), .55) * arena.size - arena.size * .5
		check(not field.blocks(point, 12), "tablier du pont sans collision de détail")
	ground.free()


func test_broken_bridge_cannot_be_crossed_by_dashing() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.autopilot = true
	var run: RunController = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	var arena_size: Vector2 = run.ctx.arena.size
	var gap: Vector2 = Vector2(.35, .55) * arena_size - arena_size * .5
	check(run.ctx.obstacles.blocks(gap, run.ctx.player.radius), "pont cassé bloqué")
	run.ctx.player.global_position = Vector2(.318, .55) * arena_size - arena_size * .5
	run.ctx.player._start_dash(Vector2.RIGHT)
	for i: int in 12:
		run.ctx.player.step(1.0 / 60.0)
		check(run.ctx.player.global_position.x < gap.x, "la ruée ne traverse pas le pont")
	RunFixture.dispose(run)
