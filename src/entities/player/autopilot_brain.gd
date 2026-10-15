class_name AutopilotBrain
extends PlayerBrain
## Bot de test : esquive les ennemis, ramasse l'XP, utilise Ruée et Techniques.
## Sert aux smoke tests (partie complète sans intervention) et à l'équilibrage.

var _dash_wanted: bool = false
var _wander := Vector2.RIGHT
var _cached := Vector2.ZERO
var _frame: int = 0


func move_vector() -> Vector2:
	_frame += 1
	if _frame % 2 == 0:
		return _cached
	_cached = _compute_move()
	return _cached


func _compute_move() -> Vector2:
	var player: Player = ctx.player
	var pos: Vector2 = player.global_position
	var flee := Vector2.ZERO
	var closest: float = INF
	for enemy: Enemy in ctx.enemies.query_radius(pos, 230.0):
		var offset: Vector2 = pos - enemy.global_position
		var dist: float = maxf(offset.length(), 1.0)
		closest = minf(closest, dist - enemy.radius)
		var weight: float = (3.0 if enemy.is_boss or enemy.is_elite else 1.0) / (dist * dist)
		flee += offset.normalized() * weight * 4000.0
	flee += ctx.hazards.danger_vector(pos) * 3.0
	for obstacle: Enemy in ctx.enemies.obstacles:
		var away: Vector2 = pos - obstacle.position
		var gap: float = away.length() - obstacle.radius
		if gap < 90.0:
			flee += away.normalized() * (90.0 - gap) / 30.0
	# Obstacles du décor : comme un joueur, ne pas se laisser coincer contre un rocher ou l'eau.
	flee += ctx.obstacles.repulsion(pos, 90.0)
	var threat: Vector2 = _projectile_threat(pos) + _charge_threat(pos)
	flee += threat * 3.0
	var gem: Vector2 = ctx.pickups.nearest_position(pos, 400.0)
	var seek := Vector2.ZERO
	if gem != Vector2.INF:
		seek = (gem - pos).normalized() * 0.7
	# Rester loin des bords de l'arène.
	var rect: Rect2 = ctx.arena_rect().grow(-260.0)
	var home := Vector2.ZERO
	if not rect.has_point(pos):
		home = (rect.get_center() - pos).normalized() * 1.5
	if ctx.rng.randf() < 0.01:
		_wander = _wander.rotated(ctx.rng.randf_range(-1.2, 1.2))
	_dash_wanted = closest < 22.0 or ctx.hazards.danger_vector(pos).length() > 0.5 or threat.length() > 1.5
	# Mode « vagues par zone » : suivre la route vers la zone suivante ou l'arène.
	var route := Vector2.ZERO
	if ctx.zones:
		route = ctx.zones.objective_direction(pos) * 1.6
		if route != Vector2.ZERO:
			home = Vector2.ZERO
	var result: Vector2 = flee + seek + home + route + _wander * 0.25
	return result.normalized() if result.length() > 0.05 else Vector2.ZERO


## Esquive latérale des projectiles qui se dirigent vers le Chasseur.
func _projectile_threat(pos: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for p: Projectile in ctx.projectiles.hostile:
		var to_player: Vector2 = pos - p.position
		var dist: float = to_player.length()
		if dist > 200.0 or p.velocity.dot(to_player) <= 0.0:
			continue
		var dir: Vector2 = p.velocity.normalized()
		var side: Vector2 = to_player - dir * to_player.dot(dir)
		if side.length() < 40.0:
			var away: Vector2 = side.normalized() if side.length() > 0.5 else dir.orthogonal()
			result += away * (1.0 + (200.0 - dist) / 100.0)
	return result


## Sort de la trajectoire des Bondisseurs qui se préparent à charger.
func _charge_threat(pos: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for enemy: Enemy in ctx.enemies.query_radius(pos, 420.0):
		if enemy.data == null or enemy.data.brain != EnemyData.Brain.CHARGER:
			continue
		if enemy.state != Enemy.State.WINDUP and enemy.state != Enemy.State.CHARGE:
			continue
		var to_player: Vector2 = pos - enemy.position
		var side: Vector2 = to_player - enemy.aim_dir * to_player.dot(enemy.aim_dir)
		if to_player.dot(enemy.aim_dir) > 0.0 and side.length() < 50.0:
			result += (side.normalized() if side.length() > 0.5 else enemy.aim_dir.orthogonal()) * 2.0
	return result


func wants_dash() -> bool:
	return _dash_wanted


func technique_pressed(_index: int) -> bool:
	return ctx.enemies.count() > 8 or ctx.boss != null


## Comme un joueur : ordonne aux Échos de cibler le boss (ordre de focus).
func focus_requested() -> bool:
	return ctx.boss != null and ctx.boss.alive and ctx.allies.focus_time <= 0.0


func aim_point() -> Vector2:
	if ctx.boss and ctx.boss.is_alive():
		return ctx.boss.global_position
	var target: Enemy = ctx.enemies.find_nearest(ctx.player.global_position, 400.0)
	return target.global_position if target else ctx.player.global_position
