extends TestCase
## Bot « joueur moyen » (docs/design/DIFFICULTE.md) : abris contre les tirs, œufs, bulbes, point faible.

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host)


func after_each() -> void:
	RunFixture.dispose(run)


func _brain() -> AutopilotBrain:
	return run.ctx.player.brain as AutopilotBrain


func test_finds_cover_behind_a_rock() -> void:
	var pos: Vector2 = run.ctx.player.global_position
	run.ctx.obstacles.add(pos + Vector2(110, 0), 45.0)
	var source: Vector2 = pos + Vector2(450, 0)
	var cover: Vector2 = _brain()._find_cover(pos, source)
	check(cover != Vector2.INF, "un abri trouvé")
	check(not run.ctx.obstacles.line_clear(source, cover), "le rocher est entre la menace et l'abri")
	check(cover.distance_to(pos) <= AutopilotBrain.COVER_SEARCH + 1.0, "à courte distance")


func test_threat_source_is_the_ranged_enemy() -> void:
	var spitter: Enemy = RunFixture.spawn(run, &"spitter", Vector2(300, 0))
	check_eq(_brain()._threat_source(run.ctx.player.global_position), spitter.position, "le tireur menace")


func test_aims_at_eggs_and_weak_points_first() -> void:
	var widow: Enemy = RunFixture.spawn(run, &"ashen_widow", Vector2(300, 0))
	RunFixture.spawn(run, &"husk", Vector2(60, 0))
	var egg: Enemy = run.ctx.enemies.spawn(GameDB.enemy(&"ash_egg"), run.ctx.player.global_position + Vector2(-200, 0))
	check_eq(_brain().aim_point(), egg.global_position, "l'œuf d'abord")
	widow.extra_damage_taken = 1.6
	check_eq(_brain().aim_point(), widow.global_position, "le point faible exposé avant tout")
	check(_brain().focus_requested(), "focus des Échos sur le point faible")
