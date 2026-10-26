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
	var corner: Vector2 = -half + Vector2(150, 150)
	var out: Vector2 = field.push_out(corner, 12.0)
	check(field.distance(out) >= 0.0 or out.distance_to(corner) > 20.0, "repoussé vers le praticable")


func test_player_cannot_enter_obstacles() -> void:
	var run: RunController = RunFixture.create(host, &"ashblade", 7, true)
	check(not run.ctx.obstacles.is_empty(), "obstacles actifs en partie")
	# Enfoncement près d’une lisière, comme après un déplacement ; pas une téléportation au milieu d’un lac.
	var blocked := Vector2.ZERO
	var found: bool = false
	for y: int in range(-560, 561, 8):
		for x: int in range(-560, 561, 8):
			var p := Vector2(x, y)
			var depth: float = run.ctx.obstacles.distance(p)
			if depth < -20.0 and depth > -30.0:
				blocked = p
				found = true
				break
		if found:
			break
	check(found, "point de collision réel trouvé de façon déterministe")
	run.ctx.player.global_position = blocked
	for i: int in 6:
		run.ctx.player._constrain()
	check(run.ctx.obstacles.distance(run.ctx.player.global_position) > -run.ctx.player.radius,
		"le joueur est repoussé hors de la zone infranchissable")
	RunFixture.dispose(run)



func test_stuck_echo_blinks_back_to_hunter() -> void:
	var run: RunController = RunFixture.create(host, &"ashblade")
	var field := ObstacleField.new()
	var player_pos: Vector2 = run.ctx.player.global_position
	# Mur entre l'Écho et le Chasseur : l'Écho ne peut pas avancer.
	for i: int in 9:
		field.add(player_pos + Vector2(-120, (i - 4) * 40.0), 40.0)
	run.ctx.obstacles = field
	var ally: Ally = run.ctx.allies.get_ally(&"ashblade")
	ally.global_position = player_pos + Vector2(-200, 0)
	for i: int in 90:
		ally.move_toward_point(player_pos, ally.data.move_speed, 1.0 / 60.0)
	check(ally.global_position.distance_to(player_pos) < 120.0, "l'Écho bloqué rejoint le Chasseur par un saut de faille")
	ally.global_position = player_pos + Vector2(2000, 0)
	ally.move_toward_point(player_pos, ally.data.move_speed, 1.0 / 60.0)
	check(ally.global_position.distance_to(player_pos) < 120.0, "l'Écho trop loin revient près du Chasseur")
	RunFixture.dispose(run)


## Mur vertical (x = 0, de y = -300 à 300) : la seule brèche est au-dessus.
func _wall_field() -> ObstacleField:
	var field := ObstacleField.new()
	var y: float = -300.0
	while y <= 300.0:
		field.add(Vector2(0, y), 24.0)
		y += 30.0
	return field


func test_flow_field_goes_around_walls() -> void:
	var field: ObstacleField = _wall_field()
	var flow := FlowField.new()
	flow.setup(field, Rect2(-600, -600, 1200, 1200))
	var target := Vector2(200, 0)
	flow.update(target)
	var pos := Vector2(-200, 0)
	var first: Vector2 = flow.direction(pos, (target - pos).normalized())
	check(first.y < -0.3 or first.y > 0.3, "derrière le mur : on longe vers une extrémité (%s)" % first)
	for i: int in 600:
		var dir: Vector2 = flow.direction(pos, (target - pos).normalized())
		pos = field.push_out(pos + dir * 90.0 / 60.0, 10.0)
	check(pos.distance_to(target) < 40.0, "l'ennemi contourne le mur et rejoint la cible (%s)" % pos)
	var open: Vector2 = flow.direction(Vector2(400, 300), (target - Vector2(400, 300)).normalized())
	check(open.is_equal_approx((target - Vector2(400, 300)).normalized()), "terrain dégagé : ligne droite")


## Lisière calcinée : le Chasseur (rayon 15) se glissait dans un recoin plus étroit que la marge de navigation, et la
## ligne droite vers l'objectif le renvoyait contre le coin du rocher. Depuis un recoin, on suit la case de retour.
func test_flow_field_leaves_a_dead_end_by_the_way_back() -> void:
	var flow := FlowField.new()
	flow.setup(ObstacleField.new(), Rect2(-400, -400, 800, 800))
	var target := Vector2(300, -60)
	flow.update(target)
	var pos := Vector2(0, 0)
	var cell: Vector2i = flow.cell_of(pos)
	# Recoin : toutes les cases autour sont injoignables, sauf la sortie, en haut à gauche.
	for dy: int in range(-4, 5):
		for dx: int in range(-4, 5):
			flow._dist[(cell.y + dy) * flow.size.x + cell.x + dx] = FlowField.UNREACHED
	var exit := Vector2i(cell.x + 3, cell.y - 1)
	flow._dist[exit.y * flow.size.x + exit.x] = 100
	var direct: Vector2 = (target - pos).normalized()
	var dir: Vector2 = flow.direction(pos, direct)
	check(dir.is_equal_approx((flow.cell_center(exit) - pos).normalized()), "on rejoint la case de retour (%s)" % dir)


func test_flow_field_cost_on_map() -> void:
	var arena: ArenaData = GameDB.arena(&"fractured_plain")
	var ground := ArenaGround.new()
	ground.setup(arena, 1)
	var obstacles: ObstacleField = ground.obstacle_field()
	var flow := FlowField.new()
	var t0: int = Time.get_ticks_usec()
	flow.setup(obstacles, ground.arena_rect())
	var t1: int = Time.get_ticks_usec()
	for k: int in 10:
		flow.update(ground.player_start() + Vector2(k * 37, -k * 21))
	var t2: int = Time.get_ticks_usec()
	var walkable: int = 0
	var reached: int = 0
	for y: int in flow.size.y:
		for x: int in flow.size.x:
			walkable += 1 if flow.is_walkable(Vector2i(x, y)) else 0
			reached += 1 if flow.cost_at(flow.cell_center(Vector2i(x, y))) < FlowField.UNREACHED else 0
	print("    carte de flux : %d cases praticables, %d atteintes ; préparation %.1f ms, calcul %.2f ms" % [
		walkable, reached, (t1 - t0) / 1000.0, (t2 - t1) / 10000.0])
	check((t2 - t1) / 10000.0 < 40.0, "calcul de la carte de flux assez rapide")
	check(reached > walkable * 0.9, "presque toutes les cases praticables sont reliées")
	check(flow.cost_at(ground.player_start()) < FlowField.UNREACHED, "départ joignable")
	ground.free()
