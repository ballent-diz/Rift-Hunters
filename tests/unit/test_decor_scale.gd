extends TestCase
## Échelle du décor par carte (decor_scale, docs/maps/ECHELLE_CHAPITRES_4_5.md) : GameDB charge une copie réduite,
## le .tres reste en coordonnées peintes.


func test_scaled_copy_shrinks_every_position() -> void:
	var raw: ArenaData = load("res://data/arenas/storm_lake.tres")
	var arena: ArenaData = GameDB.arena(&"storm_lake")
	var k: float = raw.decor_scale
	check(k < 1.0, "le Lac gelé est réduit")
	check(arena != raw, "GameDB tient une copie")
	check_near(arena.size.x, raw.size.x * k, 0.01, "taille de l'arène réduite")
	check_near(arena.finale_center.y, raw.finale_center.y * k, 0.01, "finale réduite")
	check_near(arena.zones[0].anchor.y, raw.zones[0].anchor.y * k, 0.01, "ancre de zone réduite")
	check_near(arena.zones[0].exit_walls[0].size.x, raw.zones[0].exit_walls[0].size.x * k, 0.01, "barrière réduite")
	check_near(arena.firefly_glades[0].x, raw.firefly_glades[0].x * k, 0.01, "refuge du vent réduit")
	check_near(raw.size.x, 3344.0, 0.01, "le .tres garde ses coordonnées peintes")
	check_eq(arena.zones[0].waves, raw.zones[0].waves, "vagues inchangées")


func test_unscaled_arena_is_untouched() -> void:
	var raw: ArenaData = load("res://data/arenas/brazier_pass.tres")
	check_eq(GameDB.arena(&"brazier_pass"), raw, "échelle 1 : aucune copie")


func test_ground_scales_start_and_collisions() -> void:
	var arena: ArenaData = GameDB.arena(&"storm_lake")
	var ground := ArenaGround.new()
	ground.setup(arena, 1)
	var env: EnvironmentSet = ground.environment
	check(env != null and env.is_map(), "décor peint chargé")
	if env != null:
		check(ground.player_start().is_equal_approx(env.start * arena.decor_scale), "départ réduit")
		var field: ObstacleField = ground.obstacle_field()
		check(not field.blocks(ground.player_start(), 20.0), "départ réduit toujours praticable")
		for zone: LevelZoneData in arena.zones:
			check(not field.blocks(zone.anchor, 30.0, false), "ancre réduite praticable : %s" % zone.anchor)
	ground.free()
