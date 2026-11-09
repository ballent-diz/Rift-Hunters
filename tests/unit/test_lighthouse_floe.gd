extends TestCase
## Carte 19, Banquise du phare (docs/maps/BANQUISE_DU_PHARE.md) : défense du phare peint, banquise qui se fend
## (brique B4, FloeDirector) et Colosse de la banquise.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"lighthouse_floe"
	setup.starter_id = &"ashblade"
	setup.run_seed = 5
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


## Pied du phare, sur la glace praticable (là où surgit le gardien).
func _foot(ctx: RunContext) -> Vector2:
	return ctx.obstacles.push_out(ctx.arena.altar_point + Vector2(0.0, ctx.arena.altar_radius + 90.0), 70.0)


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"lighthouse_floe")
	check(arena.altar_waves > 0 and arena.altar_painted, "défense du phare peint")
	check_eq(arena.floe_plates.size(), 14, "quatorze plaques de banquise")
	check_eq(arena.floe_access.size(), 4, "quatre plaques d'accès")
	check_eq(arena.floe_overlays.size(), 14, "une image d'eau ouverte par plaque")
	for path: String in arena.floe_overlays:
		check(ResourceLoader.exists(path), "image d'eau ouverte : %s" % path)
	check_eq(GameDB.boss(arena.boss_id).signature, &"floe_quake", "gardien : Séisme de banquise")
	check_eq(GameDB.chapters.get(&"silent_glacier").maps[3].arena_id, &"lighthouse_floe", "quatrième carte du chapitre 4")


func test_points_stand_on_open_ground_and_connect() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ dégagé")
	for point: Vector2 in arena.altar_spawn_points:
		check(not ctx.obstacles.blocks(point, 30.0, false), "arrivée des vagues praticable : %s" % point)
	for i: int in arena.floe_plates.size():
		var center: Vector2 = FloeDirector._bounds_of(arena.floe_plates[i]).get_center()
		check(not ctx.obstacles.blocks(center, 20.0), "plaque %d praticable tant qu'elle tient" % (i + 1))
	check(ctx.altar.position.distance_to(arena.altar_point) < 1.0, "le phare peint reste l'autel")
	var foot: Vector2 = _foot(ctx)
	check(foot.distance_to(arena.altar_point) < 400.0, "pied du phare proche")
	# Pire cas : deux plaques d'accès (le double du maximum) et toutes les autres plaques ouvertes.
	var floe: FloeDirector = ctx.floe
	for i: int in floe.plate_count():
		if not arena.floe_access.has(i):
			floe._open(i)
	for a: int in arena.floe_access.size():
		var b: int = (a + 1) % arena.floe_access.size()
		floe._open(arena.floe_access[a])
		floe._open(arena.floe_access[b])
		var field := FlowField.new()
		field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
		field.apply_walls(ctx.obstacles)
		field.update(foot)
		check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "départ relié au phare (%d, %d)" % [a, b])
		for point: Vector2 in arena.altar_spawn_points:
			check(field.cost_at(point) < FlowField.UNREACHED, "arrivée %s reliée au phare" % point)
		floe._close(arena.floe_access[a])
		floe._close(arena.floe_access[b])


func test_strips_cover_each_plate() -> void:
	var arena: ArenaData = GameDB.arena(&"lighthouse_floe")
	for poly: PackedVector2Array in arena.floe_plates:
		var strips: Array[Rect2] = FloeDirector.strips(poly)
		check(strips.size() >= 4, "bandes de collision")
		var box: Rect2 = FloeDirector._bounds_of(poly)
		var inside: int = 0
		var covered: int = 0
		for gx: int in 12:
			for gy: int in 12:
				var p: Vector2 = box.position + box.size * Vector2((gx + 0.5) / 12.0, (gy + 0.5) / 12.0)
				if not Geometry2D.is_point_in_polygon(p, poly):
					continue
				inside += 1
				for r: Rect2 in strips:
					if r.has_point(p):
						covered += 1
						break
		check(covered >= inside * 0.95, "la plaque est couverte (%d / %d)" % [covered, inside])


## Un cycle : alerte, ouverture (infranchissable, les Corrompus sombrent), regel ; jamais trop d'accès ouverts.
func test_cycle_cracks_opens_and_refreezes() -> void:
	var ctx: RunContext = _start()
	var floe: FloeDirector = ctx.floe
	var arena: ArenaData = ctx.arena
	floe.step(arena.floe_first + 0.01)
	var picked: Array[int] = floe.open_plates()
	check(picked.size() >= 2 and picked.size() <= arena.floe_access_max + arena.floe_ring_count, "plaques choisies")
	var access: int = 0
	var quarters: Array[int] = []
	for index: int in picked:
		check(floe.is_cracking(index), "alerte avant l'ouverture")
		if arena.floe_access.has(index):
			access += 1
		var quarter: int = floe._quarter(floe._centers[index])
		check(not quarters.has(quarter), "une plaque par quart")
		quarters.append(quarter)
	check(access <= arena.floe_access_max, "au plus %d accès fermé" % arena.floe_access_max)
	var target: int = picked[0]
	var center: Vector2 = floe._centers[target]
	var spot: Vector2 = center
	if not Geometry2D.is_point_in_polygon(spot, arena.floe_plates[target]):
		spot = arena.floe_plates[target][0].lerp(center, 0.6)
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"ice_knight"), spot)
	var before: float = enemy.hp
	floe.step(arena.floe_warning + 0.01)
	check(floe.is_open(target), "plaque ouverte après l'alerte")
	check(ctx.obstacles.blocks(spot, 4.0), "eau noire infranchissable")
	check(not enemy.alive or enemy.hp < before * 0.5, "le Corrompu sombre")
	check(ctx.stats.counters.get(&"floe_sunk", 0.0) >= 1.0, "compté pour l'objectif")
	floe.step(arena.floe_open + 0.01)
	check(not floe.is_open(target), "la plaque regèle")
	check(not ctx.obstacles.blocks(spot, 4.0), "de nouveau praticable")


func test_guardian_quake_cracks_nearest_plates() -> void:
	var ctx: RunContext = _start()
	var near: Array[int] = ctx.floe.nearest_closed(ctx.player.global_position, 2)
	check_eq(near.size(), 2, "deux plaques proches")
	for index: int in near:
		ctx.floe.crack(index, 1.0)
		check(ctx.floe.is_cracking(index), "séisme : la plaque se fend")
