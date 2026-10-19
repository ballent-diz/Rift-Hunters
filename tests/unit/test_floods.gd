extends TestCase
## Briques B3 « crues » et B6 « courants » (docs/design/CARTES.md, carte 5).

var run: RunController


func before_each() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"fractured_plain"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	setup.arena_override = TestArena.build(&"fractured_plain", &"", ["rivers"])
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	# Chasseur immobile : seuls les courants et les crues le déplacent.
	var idle := PlayerBrain.new()
	idle.ctx = run.ctx
	run.ctx.player.brain = idle


func after_each() -> void:
	RunFixture.dispose(run)


func _husk(pos: Vector2) -> Enemy:
	var enemy: Enemy = run.ctx.enemies.spawn(GameDB.enemy(&"husk"), pos)
	run.ctx.enemies.rebuild_grid()
	return enemy


## Point libre (loin du décor et des obstacles) le long de l'axe d'une bande.
func _free_spot(rect: Rect2, dir: Vector2) -> Vector2:
	for k: int in 120:
		var across: float = (k % 5 - 2) * 20.0
		var candidate: Vector2 = rect.get_center() + dir * (int(k / 5.0) * 40.0 - 480.0) + dir.orthogonal() * across
		if not rect.has_point(candidate):
			continue
		var clear: bool = true
		for ring: int in 3:
			for a: int in 8:
				var probe: Vector2 = candidate + Vector2.from_angle(TAU * a / 8.0) * 30.0 * ring
				clear = clear and run.ctx.obstacles.push_out(probe, 20.0) == probe
		for obstacle: Enemy in run.ctx.enemies.obstacles:
			clear = clear and obstacle.position.distance_to(candidate) > obstacle.radius + 120.0
		if clear:
			return candidate
	return Vector2.INF


func test_flood_is_telegraphed_then_carries_and_hurts() -> void:
	var ctx: RunContext = run.ctx
	var flood: FloodDirector = ctx.flood
	check(flood != null, "crues actives")
	var intro: Array[String] = []
	ctx.events.event_started.connect(func(key: String) -> void: intro.append(key))
	flood.step(ctx.arena.flood_first - 0.1)
	check_eq(flood.state, FloodDirector.State.CALM, "rien avant la première crue")
	flood.step(0.2)
	check_eq(flood.state, FloodDirector.State.WARNING, "alerte avant la crue")
	check(intro.has("FLOOD_INTRO"), "annonce de la première crue")
	var rect: Rect2 = flood.lane_rect()
	var inside: Vector2 = rect.get_center() + flood.lane_dir() * -200.0
	check_eq(ctx.terrain_drift(inside), Vector2.ZERO, "l'alerte ne pousse pas encore")
	check(ctx.danger_vector(inside).length() > 0.5, "le bot fuit le lit pendant l'alerte")
	check(absf(ctx.danger_vector(inside).dot(flood.lane_dir())) < 0.01, "on sort par le côté")
	ctx.player.global_position = inside
	var enemy: Enemy = _husk(inside + flood.lane_dir() * 80.0)
	var dry: Enemy = _husk(rect.get_center() + flood.lane_dir().orthogonal() * (rect.size.length() + 300.0))
	dry.global_position = ctx.obstacles.push_out(dry.global_position, dry.radius)
	ctx.enemies.rebuild_grid()
	var hp: float = ctx.player.hp
	flood.step(ctx.arena.flood_warning)
	flood.step(0.01)
	check_eq(flood.state, FloodDirector.State.FLOOD, "la crue déferle")
	check(ctx.player.hp < hp, "le Chasseur pris dans la crue est blessé")
	check(enemy.hp < enemy.max_hp * 0.95, "le Corrompu pris dans la crue perd une grosse part de ses PV")
	check_eq(dry.hp, dry.max_hp, "hors du lit : rien")
	check_near(ctx.terrain_drift(inside).length(), ctx.arena.flood_push, 0.1, "le flot emporte")
	check(ctx.terrain_drift(inside).dot(flood.lane_dir()) > 0.0, "dans le sens du flot")
	flood.step(ctx.arena.flood_duration)
	check_eq(flood.state, FloodDirector.State.CALM, "la crue se retire")
	check_eq(ctx.terrain_drift(inside), Vector2.ZERO, "plus de poussée après la crue")
	flood.step(ctx.arena.flood_interval + 0.1)
	check_eq(flood.state, FloodDirector.State.WARNING, "crue suivante")
	check(flood.lane_rect() != rect, "les lits débordent à tour de rôle")


func test_dash_escapes_the_flood() -> void:
	var ctx: RunContext = run.ctx
	var flood: FloodDirector = ctx.flood
	flood._next = 0
	flood.step(ctx.arena.flood_first + 0.01)
	flood.step(ctx.arena.flood_warning)
	check_eq(flood.state, FloodDirector.State.FLOOD, "crue en cours")
	ctx.player.global_position = _free_spot(flood.lane_rect(), flood.lane_dir())
	ctx.player._start_dash(flood.lane_dir().orthogonal())
	var hp: float = ctx.player.hp
	flood._strike()
	check_eq(ctx.player.hp, hp, "la Ruée (invulnérable) traverse la crue sans dégâts")
	var from: Vector2 = ctx.player.global_position
	ctx.player.step(1.0 / 60.0)
	var moved: Vector2 = ctx.player.global_position - from
	check(absf(moved.dot(flood.lane_dir())) < 0.5, "la Ruée ne dérive pas")


func test_currents_carry_the_hunter_and_the_corrupted() -> void:
	var ctx: RunContext = run.ctx
	check(ctx.terrain != null, "courants actifs")
	var rect: Rect2 = ctx.arena.currents[0]
	var dir: Vector2 = ctx.terrain.current_dir(0)
	var spot: Vector2 = _free_spot(rect, dir)
	check(spot != Vector2.INF, "point de test dans le courant")
	check_near(ctx.terrain_drift(spot).length(), ctx.arena.current_speed, 0.1, "dérive dans le courant")
	check_eq(ctx.terrain_drift(rect.get_center() - Vector2(0, rect.size.y)), Vector2.ZERO, "pas de dérive ailleurs")
	ctx.player.global_position = spot
	ctx.player.step(0.1)
	var carried: Vector2 = ctx.player.global_position - spot
	check(carried.dot(dir) > ctx.arena.current_speed * 0.1 * 0.8, "le Chasseur immobile est emporté")
	# Corrompu loin du Chasseur : son déplacement = sa marche + la dérive (atténuée par sa résistance au recul).
	ctx.player.global_position = spot - dir * 400.0
	var enemy: Enemy = _husk(spot)
	var before: Vector2 = enemy.position
	ctx.enemies.step(0.1)
	var drift: Vector2 = (enemy.position - before) - enemy.velocity * 0.1
	var expected: float = ctx.arena.current_speed * (1.0 - enemy.data_knockback_resist() * 0.5) * 0.1
	check_near(drift.dot(dir), expected, 1.0, "le Corrompu dérive aussi")
