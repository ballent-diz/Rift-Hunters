extends TestCase
## Abris (règle de tous les chapitres) : personne ne tire à travers le décor. Les tirs s'arrêtent sur les rochers, les
## souffles et rayons sont coupés ; les attaques au sol ne le sont pas. Les cibles en vue sont préférées.

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host)


func after_each() -> void:
	RunFixture.dispose(run)


## Rocher de 40 unités de rayon entre le Chasseur et un point à 300 unités à droite.
func _rock() -> Vector2:
	var center: Vector2 = run.ctx.player.global_position + Vector2(150, 0)
	run.ctx.obstacles.add(center, 40.0)
	return center


func _step_projectiles(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		run.ctx.projectiles.step(0.05)
		t += 0.05


func test_enemy_shot_stops_on_a_rock() -> void:
	_rock()
	var player: Player = run.ctx.player
	var hp: float = player.hp
	run.ctx.projectiles.spawn_hostile(player.global_position + Vector2(300, 0), Vector2.LEFT, 300.0, 20.0, &"spitter")
	_step_projectiles(1.5)
	check_eq(player.hp, hp, "abrité derrière le rocher")
	check(run.ctx.projectiles.hostile.is_empty(), "le tir s'est arrêté")


func test_hunter_shots_stop_too_unless_ghost() -> void:
	_rock()
	var enemy: Enemy = RunFixture.spawn(run, &"husk", Vector2(300, 0))
	var hp: float = enemy.hp
	var pos: Vector2 = run.ctx.player.global_position
	run.ctx.projectiles.spawn_friendly(pos, Vector2.RIGHT, 500.0, RunFixture.info(10.0), {"life": 2.0})
	_step_projectiles(1.0)
	check_eq(enemy.hp, hp, "le tir du Chasseur ne traverse pas le rocher")
	run.ctx.projectiles.spawn_friendly(pos, Vector2.RIGHT, 500.0, RunFixture.info(10.0), {"life": 2.0, "ghost": true})
	_step_projectiles(1.0)
	check(enemy.hp < hp, "un tir « fantôme » (en cloche, volant) passe")


func test_breath_cone_is_blocked_but_ground_strikes_are_not() -> void:
	_rock()
	var player: Player = run.ctx.player
	var source: Vector2 = player.global_position + Vector2(300, 0)
	var hp: float = player.hp
	run.ctx.hazards.add_cone(source, Vector2.LEFT, 400.0, 0.5, 0.1, 20.0, &"flame_wyrmling")
	for i: int in 6:
		run.ctx.hazards.step(0.05)
	check_eq(player.hp, hp, "souffle coupé par le rocher")
	run.ctx.hazards.add_circle(player.global_position, 60.0, 0.1, 20.0, true, &"caldera_titan")
	for i: int in 6:
		run.ctx.hazards.step(0.05)
	check(player.hp < hp, "un geyser au sol touche quand même")


func test_beam_is_cut_at_the_rock() -> void:
	var rock: Vector2 = _rock()
	var source: Vector2 = run.ctx.player.global_position + Vector2(300, 0)
	run.ctx.hazards.add_beam(source, Vector2.LEFT, 600.0, 30.0, 0.5, 1.0, 10.0, &"boss")
	var length: float = run.ctx.hazards.hazards.back()["length"]
	check(length < source.distance_to(rock), "rayon arrêté au rocher (%d)" % int(length))


func test_targets_in_sight_are_preferred() -> void:
	_rock()
	var pos: Vector2 = run.ctx.player.global_position
	var hidden: Enemy = RunFixture.spawn(run, &"husk", Vector2(220, 0))
	var visible: Enemy = RunFixture.spawn(run, &"husk", Vector2(0, 260))
	check_eq(run.ctx.enemies.find_nearest(pos, 400.0), hidden, "le plus proche est caché")
	check_eq(run.ctx.enemies.find_nearest_visible(pos, 400.0), visible, "on vise celui qui est en vue")
