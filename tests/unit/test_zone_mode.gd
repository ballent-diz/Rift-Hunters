extends TestCase
## Mode « vagues par zone » (Ruines des Cascades) : zones séparées par des barrières, apparitions dans la zone
## active, ouverture des barrières après la dernière vague, puis finale du boss.

var run: RunController


func before_each() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	setup.run_seed = 3
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)


func after_each() -> void:
	RunFixture.dispose(run)


func _kill_all() -> void:
	for enemy: Enemy in run.ctx.enemies.list.duplicate():
		if enemy.alive:
			run.ctx.combat.deal_damage(enemy, RunFixture.info(1e9))
	run.ctx.combat.flush_queue()
	run.ctx.enemies.step(0.0)


## Joue la zone en cours : élimine les Corrompus au fur et à mesure de leur apparition.
func _clear_current_zone(zones: ZoneDirector) -> void:
	var start_zone: int = zones.zone_index
	for guard: int in 4000:
		zones.step(0.25)
		if zones.zone_index != start_zone:
			return
		if zones.phase == ZoneDirector.Phase.WAVE:
			_kill_all()
	check(false, "la zone %d n'a pas pu être nettoyée (phase %d, vague %d, restants %d, présents %d)" % [start_zone,
		zones.phase, zones.wave_index, zones.remaining(), run.ctx.enemies.count()])


func test_zones_are_separated_by_walls() -> void:
	var zones: ZoneDirector = run.ctx.zones
	check(zones != null, "mode vagues par zone actif sur les Ruines des Cascades")
	check_eq(zones.zone_count(), 2, "deux zones avant l'arène")
	var arena: ArenaData = run.ctx.arena
	var regions: Array[int] = [zones.region_of(arena.zones[0].anchor), zones.region_of(arena.zones[1].anchor),
		zones.region_of(arena.finale_center)]
	check_eq(regions, [0, 1, 2], "zone 1, zone 2 et arène séparées par les barrières")
	check_eq(zones.region_of(run.ctx.player.global_position), 0, "départ dans la zone 1")
	check(run.spawner.current_cap() >= 0 and run.ctx.boss == null, "pas de boss au chrono")


func test_walls_block_everyone_and_the_dash() -> void:
	var obstacles: ObstacleField = run.ctx.obstacles
	var top: Rect2 = run.ctx.arena.zones[0].exit_walls[0]
	check(obstacles.blocks(top.get_center(), 10.0), "barrière fermée infranchissable")
	var player: Player = run.ctx.player
	player.global_position = Vector2(top.position.x - 30.0, top.get_center().y)
	player._start_dash(Vector2.RIGHT)
	for i: int in 14:
		player.step(1.0 / 60.0)
	check(player.global_position.x < top.position.x, "la ruée ne traverse pas la barrière")


## Pas plus long que l'épaisseur d'une barrière (Ruée, image lente, poussée du décor) : jamais de l'autre côté.
func test_fast_moves_never_cross_a_thin_wall() -> void:
	var obstacles: ObstacleField = run.ctx.obstacles
	var player: Player = run.ctx.player
	var thin := Rect2(player.global_position + Vector2(40, -150), Vector2(8, 300))
	obstacles.add_wall(thin)
	check(obstacles.crosses_wall(player.global_position, player.global_position + Vector2(120, 0), player.radius),
		"trajet à travers la barrière détecté")
	var along: Vector2 = Vector2(thin.position.x - player.radius - 0.5, thin.position.y + 20.0)
	check(not obstacles.crosses_wall(along, along + Vector2(0, 80), player.radius), "longer la barrière reste permis")
	player._start_dash(Vector2.RIGHT)
	player.step(0.12)
	check(player.global_position.x < thin.position.x, "une Ruée en une seule image ne traverse pas")


func test_spawns_stay_in_active_zone() -> void:
	var zones: ZoneDirector = run.ctx.zones
	for i: int in 40:
		var pos: Vector2 = zones.spawn_position()
		check_eq(zones.region_of(pos), 0, "apparition dans la zone active")
		check(pos.distance_to(run.ctx.player.global_position) >= ZoneDirector.SPAWN_SAFE, "jamais sur le Chasseur")
	zones.step(ZoneDirector.START_DELAY + 0.1)
	for i: int in 20:
		zones.step(0.5)
	check(run.ctx.enemies.count() > 0, "la première vague apparaît")
	for enemy: Enemy in run.ctx.enemies.list:
		check_eq(zones.region_of(enemy.position), 0, "Corrompu dans la zone 1")


func test_full_progression_opens_walls_then_finale() -> void:
	var ctx: RunContext = run.ctx
	var zones: ZoneDirector = ctx.zones
	var top: Rect2 = ctx.arena.zones[0].exit_walls[0]
	_clear_current_zone(zones)
	check_eq(zones.zone_index, 1, "zone 1 terminée après 3 vagues")
	check(not ctx.obstacles.blocks(top.get_center(), 10.0), "barrières de la zone 1 ouvertes")
	check_eq(zones.phase, ZoneDirector.Phase.ENTER, "attente de l'entrée en zone 2")
	check(zones.objective_direction(ctx.player.global_position) != Vector2.ZERO, "flèche vers la zone 2")
	zones.step(5.0)
	check_eq(zones.phase, ZoneDirector.Phase.ENTER, "la zone 2 ne démarre pas sans le Chasseur")
	ctx.player.global_position = ctx.arena.zones[1].anchor
	zones.step(0.1)
	zones.step(ZoneDirector.START_DELAY + 0.1)
	for i: int in 4:
		zones.step(0.25)
	var elites: int = 0
	for enemy: Enemy in ctx.enemies.list:
		elites += 1 if enemy.is_elite else 0
	check(elites >= 1, "élites dès la première vague de la zone 2")
	_clear_current_zone(zones)
	check_eq(zones.phase, ZoneDirector.Phase.DONE, "toutes les zones nettoyées")
	check_eq(ctx.finale.state, ArenaFinale.State.TRAVEL, "la finale appelle vers l'arène")
	check(not ctx.obstacles.blocks(ctx.arena.zones[1].exit_walls[1].get_center(), 10.0), "accès à l'arène ouvert")
	check(ctx.boss == null, "le boss attend le Chasseur")


func test_last_enemies_are_hunted_and_never_block() -> void:
	var zones: ZoneDirector = run.ctx.zones
	zones.step(ZoneDirector.START_DELAY + 0.1)
	# Faire apparaître toute la vague (la limite de présents oblige à en éliminer au fur et à mesure).
	for i: int in 400:
		zones.step(0.25)
		if zones._queue.is_empty():
			break
		if run.ctx.enemies.count() >= zones.zone().waves[0].max_alive:
			_kill_all()
	var keep: Array[Enemy] = []
	for enemy: Enemy in run.ctx.enemies.list:
		if keep.size() < 2:
			keep.append(enemy)
		elif enemy.alive:
			run.ctx.combat.deal_damage(enemy, RunFixture.info(1e9))
	run.ctx.combat.flush_queue()
	run.ctx.enemies.step(0.0)
	zones.step(0.1)
	check(zones.hunting, "traque des derniers Corrompus")
	check(run.ctx.enemies.hunt_speed_mult > 1.0, "ils accélèrent")
	var far := Vector2(-2400, 500)
	for enemy: Enemy in keep:
		enemy.position = far
	zones.step(ZoneDirector.STALL_TIME + 0.5)
	for enemy: Enemy in keep:
		check(enemy.position.distance_to(run.ctx.player.global_position) < ZoneDirector.SPAWN_MIN + 260.0,
			"un Corrompu coincé réapparaît près du Chasseur")
