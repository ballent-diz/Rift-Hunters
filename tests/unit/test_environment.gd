extends TestCase
## Décor des arènes : chargement depuis le manifeste, placement déterministe, bordure, repli sans décor.


## Décor en tuiles (pack) : toujours disponible pour les arènes sans map dessinée.
func _plain() -> EnvironmentSet:
	return Assets.environment(&"environment.fractured_plain")


func test_fractured_plain_environment_loads() -> void:
	var env: EnvironmentSet = _plain()
	check(env != null, "décor de la Plaine fracturée chargé")
	if env == null:
		return
	check(env.ground != null and env.atlas != null, "sol et atlas présents")
	for layer: StringName in EnvironmentSet.LAYERS:
		check(not env.decals_in(layer).is_empty(), "couche %s non vide" % layer)
	var bounds := Rect2(Vector2.ZERO, env.atlas.get_size())
	for decal: Dictionary in env.decals:
		check(bounds.encloses(decal["region"]), "%s dans l'atlas" % decal["name"])


func test_layout_is_deterministic_and_respects_rules() -> void:
	var env: EnvironmentSet = _plain()
	if env == null:
		check(false, "décor absent")
		return
	var rect := Rect2(-1000, -1000, 2000, 2000)
	var a: Array[Dictionary] = DecorLayout.generate(env, rect, 42)
	var b: Array[Dictionary] = DecorLayout.generate(env, rect, 42)
	var c: Array[Dictionary] = DecorLayout.generate(env, rect, 43)
	check_eq(a.size(), b.size(), "même graine, même nombre d'éléments")
	check(a == b, "même graine, même décor")
	check(a != c, "graine différente, décor différent")
	var inside: int = 0
	var outside: int = 0
	var last_pass: int = -1
	var last_y: float = -INF
	for item: Dictionary in a:
		var pos: Vector2 = item["position"]
		var decal: Dictionary = env.decals[int(item["decal"])]
		if item["pass"] != last_pass:
			last_pass = item["pass"]
			last_y = -INF
		check(pos.y >= last_y, "ordre d'affichage du haut vers le bas")
		last_y = pos.y
		if item["outside"]:
			outside += 1
			check_eq(decal["layer"], &"border", "seule la bordure est hors de l'arène")
			check(not rect.has_point(pos), "arbre de bordure hors de l'arène")
		else:
			inside += 1
			check(rect.has_point(pos), "élément intérieur dans l'arène")
			if decal["layer"] == &"prop":
				check(pos.length() >= env.clear_radius, "zone de départ dégagée")
	check(inside > 100, "intérieur garni (%d éléments)" % inside)
	check(outside > 100, "forêt de bordure (%d éléments)" % outside)


func test_density_multiplier_scales_interior() -> void:
	var env: EnvironmentSet = _plain()
	if env == null:
		check(false, "décor absent")
		return
	var rect := Rect2(-800, -800, 1600, 1600)
	var normal: int = _interior(DecorLayout.generate(env, rect, 7, 1.0))
	var sparse: int = _interior(DecorLayout.generate(env, rect, 7, 0.25))
	check(sparse < normal * 0.5, "densité réduite (%d < %d)" % [sparse, normal])


func test_border_sprites_never_cover_the_arena() -> void:
	var env: EnvironmentSet = _plain()
	if env == null:
		check(false, "décor absent")
		return
	var rect := Rect2(-600, -600, 1200, 1200)
	var overlaps: int = 0
	for item: Dictionary in DecorLayout.generate(env, rect, 3):
		if not item["outside"]:
			continue
		var decal: Dictionary = env.decals[int(item["decal"])]
		var sprite := Rect2((item["position"] as Vector2) - (decal["anchor"] as Vector2) * env.pixel_scale,
			(decal["region"] as Rect2).size * env.pixel_scale)
		if sprite.grow(-1.0).intersects(rect):
			overlaps += 1
	check_eq(overlaps, 0, "aucun arbre de bordure ne recouvre l'aire de jeu")


func test_ground_falls_back_without_environment() -> void:
	var arena: ArenaData = GameDB.arena(&"fractured_plain").duplicate()
	arena.environment_id = &"environment.missing"
	var ground := ArenaGround.new()
	ground.setup(arena, 1)
	check(ground.uses_placeholder(), "sol de remplacement sans décor")
	ground.free()
	var tiled: ArenaData = GameDB.arena(&"fractured_plain").duplicate()
	tiled.environment_id = &"environment.fractured_plain"
	var real := ArenaGround.new()
	real.setup(tiled, 1)
	check(not real.uses_placeholder(), "décor en tuiles utilisé")
	check(real.get_child_count() > 4, "blocs de décor créés")
	real.free()


func test_validator_rejects_decal_outside_atlas() -> void:
	var entry: Dictionary = (Assets.entry(&"environment.fractured_plain") as Dictionary).duplicate(true)
	(entry["decals"] as Array).append({"name": "hors_atlas", "layer": "prop", "rect": [99999, 0, 16, 16]})
	var report: Dictionary = AssetValidator.validate_entry("environment.test", entry)
	check_eq(report["status"], "ERROR", "élément hors atlas détecté")


func _interior(items: Array[Dictionary]) -> int:
	var count: int = 0
	for item: Dictionary in items:
		if not item["outside"]:
			count += 1
	return count


func test_obstacle_field_pushes_out_and_slides() -> void:
	var field := ObstacleField.new()
	field.add(Vector2(100, 0), 30.0)
	var out: Vector2 = field.push_out(Vector2(80, 0), 10.0)
	check(out.distance_to(Vector2(100, 0)) >= 39.9, "repoussé hors de l'obstacle")
	check(absf(out.y) > 1.0, "glisse sur le côté (contournement)")
	check_eq(field.push_out(Vector2(-200, 0), 10.0), Vector2(-200, 0), "loin d'un obstacle : inchangé")
	check(field.blocks(Vector2(95, 5), 4.0), "blocage détecté")
	check(not field.blocks(Vector2(0, 0), 4.0), "pas de blocage au loin")


func test_obstacles_leave_paths_and_clear_start() -> void:
	var env: EnvironmentSet = _plain()
	if env == null:
		check(false, "décor absent")
		return
	var rect := Rect2(-1600, -1600, 3200, 3200)
	var circles: Array[Vector3] = []
	for item: Dictionary in DecorLayout.generate(env, rect, 11):
		circles.append_array(item["colliders"])
	check(circles.size() > 20, "obstacles placés (%d cercles)" % circles.size())
	for i: int in circles.size():
		var a: Vector3 = circles[i]
		check(Vector2(a.x, a.y).length() > env.clear_radius + a.z, "zone de départ libre")
	var groups: Array = []
	for item: Dictionary in DecorLayout.generate(env, rect, 11):
		if not (item["colliders"] as Array).is_empty():
			groups.append(item["colliders"])
	var squeezed: int = 0
	for i: int in groups.size():
		for j: int in range(i + 1, groups.size()):
			for a: Vector3 in groups[i]:
				for b: Vector3 in groups[j]:
					if Vector2(a.x - b.x, a.y - b.y).length() - a.z - b.z < DecorLayout.PATH_GAP - 1.0:
						squeezed += 1
	check_eq(squeezed, 0, "toujours un passage entre deux obstacles")


func test_map_arena_zones() -> void:
	var arena: ArenaData = GameDB.arena(&"fractured_plain")
	var env: EnvironmentSet = Assets.environment(arena.environment_id)
	check(env != null and env.is_map(), "la Plaine fracturée utilise la map dessinée")
	if env == null:
		return
	check_near(env.arena_size, arena.size.x, 0.5, "taille de l'arène = taille de la map")
	var half: Vector2 = arena.size * 0.5
	var field := ObstacleField.new()
	field.set_distance_field(env.field_image, Rect2(-half, arena.size), env.field_step)
	check(field.distance(env.start) > 40.0, "départ praticable et dégagé")
	check(env.start.length() < 400.0, "départ près du centre")
	check(field.distance(-half + Vector2(40, 40)) < 0.0, "coin de la map (forêt) infranchissable")
	var corner: Vector2 = -half + Vector2(300, 300)
	var out: Vector2 = field.push_out(corner, 12.0)
	check(field.distance(out) >= 0.0 or out.distance_to(corner) > 20.0, "repoussé vers le praticable")


func test_player_cannot_enter_obstacles() -> void:
	var run: RunController = RunFixture.create(host, &"ashblade", 7, true)
	check(not run.ctx.obstacles.is_empty(), "obstacles actifs en partie")
	var blocked := Vector2.ZERO
	for i: int in 400:
		var p := Vector2(randf_range(-1100, 1100), randf_range(-1100, 1100))
		if run.ctx.obstacles.distance(p) < -20.0:
			blocked = p
			break
	run.ctx.player.global_position = blocked
	for i: int in 6:
		run.ctx.player._constrain()
	check(run.ctx.obstacles.distance(run.ctx.player.global_position) > -run.ctx.player.radius,
		"le joueur est repoussé hors de la zone infranchissable")
	RunFixture.dispose(run)

