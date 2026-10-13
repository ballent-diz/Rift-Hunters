extends TestCase
## Niveau rectangulaire : chargement, routes connexes et intégration en partie.


func test_level_and_original_panels_load() -> void:
	var arena: ArenaData = GameDB.arena(&"three_rifts")
	check(arena != null and arena.unlocked_by_default, "niveau disponible sans progression")
	check_eq(arena.size, Vector2(3762, 1254), "trois panneaux carrés sans déformation")
	var env: EnvironmentSet = Assets.environment(arena.environment_id)
	check(env != null and env.is_map(), "décor chargé")
	check_eq(env.map_tiles.size(), 3, "trois images dans leur ordre")
	for tile: Texture2D in env.map_tiles:
		check_eq(tile.get_size(), Vector2(1254, 1254), "résolution originale")
	check_eq(env.field_image.get_size(), Vector2i(1881, 627), "champ rectangulaire")


func test_routes_connect_all_three_maps_with_enemy_clearance() -> void:
	var arena: ArenaData = GameDB.arena(&"three_rifts")
	var ground := ArenaGround.new()
	ground.setup(arena, 7)
	var field: ObstacleField = ground.obstacle_field()
	check(field.distance(ground.player_start()) >= 36, "départ sûr dans la première image")
	check(ground.player_start().x < -627, "départ dans L1")
	var flow := FlowField.new()
	flow.setup(field, ground.arena_rect())
	flow.update(ground.player_start())
	for pixel: Vector2 in [Vector2(1254, 620), Vector2(1900, 650), Vector2(2508, 588), Vector2(3420, 600)]:
		var point: Vector2 = pixel - arena.size * 0.5
		check(field.distance(point) >= 12, "point de passage praticable %s" % pixel)
		check(flow.cost_at(point) < FlowField.UNREACHED, "route continue jusqu’à %s" % pixel)
	check(field.distance(Vector2(1100, 850) - arena.size * 0.5) < 0, "eau infranchissable")
	check(field.distance(Vector2(3520, 80) - arena.size * 0.5) < 0, "vide hors plateforme infranchissable")
	ground.free()


func test_level_starts_with_camera_and_existing_combat() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	check(run.ctx.obstacles.distance(run.ctx.player.global_position) >= run.ctx.player.radius, "départ hors obstacle")
	check_eq(run.camera.limit_left, -1881, "caméra limitée au début")
	check_eq(run.camera.limit_right, 1881, "caméra limitée à la fin")
	check(run.ctx.flow != null and run.spawner.current_wave() != null, "navigation et vagues existantes actives")
	RunFixture.dispose(run)


func test_missing_panel_falls_back_and_is_reported() -> void:
	var e: Dictionary = Assets.manifest["environment.three_rifts"].duplicate(true)
	e["map_tiles"][1] = "res://missing-panel.png"
	check(EnvironmentSet.from_entry(&"environment.invalid", e) == null, "décor incomplet rejeté")
	check_eq(AssetValidator.validate_environment("environment.invalid", e)["status"], "ERROR", "asset manquant signalé")
