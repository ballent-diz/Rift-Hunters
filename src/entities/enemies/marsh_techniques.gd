class_name MarshTechniques
extends RefCounted
## Techniques des Corrompus du chapitre 3 (docs/design/MONSTRES.md, E14 à E17 et traits), appelées par EnemyManager
## (_technique_<kind> absente du gestionnaire : technique_<kind> ici).

var ctx: RunContext
var m: EnemyManager


func _init(p_ctx: RunContext, manager: EnemyManager) -> void:
	ctx = p_ctx
	m = manager

## Spore-marque, marque de prisme (E14) : marque le Chasseur, qui explose après un délai ; la Ruée l'efface.
func technique_mark(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	if ctx.player.is_marked():
		return false
	enemy.technique_busy = technique.telegraph
	ctx.fx.danger_line(enemy.position, player_pos, 10.0, technique.telegraph)
	m._later(enemy, technique.telegraph, func() -> void:
		if ctx.player.alive and not ctx.player.is_marked():
			ctx.player.mark(float(technique.params.get("delay", 3.0)), m._scaled(enemy, technique.damage),
				float(technique.params.get("radius", 110.0)), enemy.data.id)
			ctx.fx.spark(ctx.player.global_position, Color(0.7, 1.0, 0.4), 14.0))
	return true


## Bouclier d'écorce (E15) : tant que l'élite tient le bouclier (immobile), les Corrompus proches ne prennent plus de
## dégâts. La tuer ou attendre la fin le fait tomber.
func technique_ally_shield(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	var radius: float = float(technique.params.get("radius", 220.0))
	var duration: float = float(technique.params.get("duration", 4.0))
	var shielded: int = 0
	for other: Enemy in m.query_radius(enemy.position, radius):
		if other != enemy and not other.is_boss and not other.is_obstacle:
			other.shield_source = enemy
			other.shield_until = ctx.time + duration
			shielded += 1
	if shielded == 0:
		return false
	enemy.technique_busy = duration
	ctx.fx.ring(enemy.position, radius, Color(0.55, 0.95, 0.6, 0.7), 0.5)
	return true


## Saut de reflet, saut en chaîne (E16) : disparaît et réapparaît sur un flanc du Chasseur (`hops` fois), puis frappe
## (`damage` > 0). `on_hits` : ne se déclenche que si l'ennemi vient d'encaisser autant de coups (fuite).
func technique_blink(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	var on_hits: int = int(technique.params.get("on_hits", 0))
	if on_hits > 0 and enemy.recent_hits < on_hits:
		return false
	enemy.recent_hits = 0
	var hops: int = int(technique.params.get("hops", 1))
	var gap: float = float(technique.params.get("gap", 0.45))
	var distance: float = float(technique.params.get("distance", 140.0))
	var area: Rect2 = ctx.arena_rect().grow(-enemy.radius - 20.0)
	enemy.technique_busy = hops * gap + technique.telegraph + 0.3
	for h: int in hops:
		m._later(enemy, h * gap, func() -> void:
			var around: Vector2 = ctx.player.global_position if on_hits == 0 else enemy.position
			var side: Vector2 = Vector2.RIGHT.rotated(ctx.rng.randf() * TAU)
			var target: Vector2 = ctx.obstacles.push_out((around + side * distance).clamp(area.position, area.end),
				enemy.radius)
			ctx.fx.burst(enemy.position, enemy.radius * 1.4, Color(0.75, 0.95, 1.0, 0.5))
			enemy.position = target
			enemy.invulnerable_time = 0.15
			ctx.fx.burst(target, enemy.radius * 1.4, Color(0.75, 0.95, 1.0, 0.5)))
	if technique.damage > 0.0:
		m._later(enemy, hops * gap, func() -> void:
			ctx.hazards.add_circle(enemy.position, float(technique.params.get("radius", 80.0)), technique.telegraph,
				m._scaled(enemy, technique.damage), true, enemy.data.id))
	return true


## Reflets (E17) : copies fragiles qui imitent l'élite (mêmes tirs, sans techniques) puis se dissipent.
func technique_clones(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	var count: int = int(technique.params.get("count", 2))
	enemy.technique_busy = technique.telegraph
	for i: int in count:
		var pos: Vector2 = ctx.obstacles.push_out(enemy.position + Vector2.RIGHT.rotated(TAU * i / count + 0.6) * 70.0,
			enemy.radius)
		ctx.fx.ring(pos, enemy.radius * 1.3, Color(0.75, 0.95, 1.0, 0.8), technique.telegraph)
		m._later(enemy, technique.telegraph, func() -> void:
			var clone: Enemy = m.spawn(enemy.data, pos)
			clone.is_clone = true
			clone.clone_until = ctx.time + float(technique.params.get("life", 10.0))
			clone.max_hp = enemy.max_hp * float(technique.params.get("hp_ratio", 0.08))
			clone.hp = clone.max_hp
			clone.xp_value = 0
			clone.contact_damage = enemy.contact_damage * 0.5
			clone.visual.modulate = Color(0.75, 0.95, 1.0, 0.6))
	return true


## Aura de soin (trait de la Mère-spore) : soigne les Corrompus proches d'une part de leurs PV max.
func technique_heal_aura(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	var radius: float = float(technique.params.get("radius", 240.0))
	var ratio: float = float(technique.params.get("ratio", 0.12))
	var healed: int = 0
	for other: Enemy in m.query_radius(enemy.position, radius):
		if other != enemy and not other.is_boss and not other.is_obstacle and other.hp < other.max_hp:
			other.hp = minf(other.max_hp, other.hp + other.max_hp * ratio)
			healed += 1
	if healed == 0:
		return false
	ctx.fx.ring(enemy.position, radius, Color(0.6, 1.0, 0.5, 0.6), 0.6)
	return true


## Miroir renvoyeur : bouclier frontal tenu `duration` secondes ; les tirs reçus de face repartent vers le Chasseur.
func technique_reflect(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	var duration: float = float(technique.params.get("duration", 2.5))
	enemy.reflect_until = ctx.time + duration
	enemy.reflect_dir = (player_pos - enemy.position).normalized()
	enemy.technique_busy = duration
	return true


## Tir allié renvoyé par un miroir : vrai si le tir est absorbé (et renvoyé).
func reflects(enemy: Enemy, projectile_pos: Vector2, damage: float) -> bool:
	if enemy.reflect_until <= ctx.time:
		return false
	var from: Vector2 = (projectile_pos - enemy.position).normalized()
	if from.dot(enemy.reflect_dir) < 0.25:
		return false
	var back: Vector2 = (ctx.player.global_position - enemy.position).normalized()
	ctx.projectiles.spawn_hostile(enemy.position + back * (enemy.radius + 6.0), back, 360.0,
		maxf(damage * 0.5, 4.0) * ctx.difficulty.enemy_damage_mult, enemy.data.id if enemy.data else &"mirror", 8.0, 2.5)
	ctx.fx.spark(projectile_pos, Color(0.75, 0.95, 1.0), 10.0)
	return true


## Furtif hors de portée du Chasseur : ni visible ni visé.
func hidden(enemy: Enemy) -> bool:
	return enemy.data != null and enemy.data.stealth_range > 0.0 \
		and enemy.position.distance_to(ctx.player.global_position) > enemy.data.stealth_range


func stealth_alpha(enemy: Enemy, player_pos: Vector2) -> float:
	var range_px: float = enemy.data.stealth_range
	return clampf(1.0 - (enemy.position.distance_to(player_pos) - range_px * 0.7) / (range_px * 0.3), 0.08, 1.0)


## Ombre des volants, bulle du bouclier d'écorce, arc du miroir renvoyeur.
func draw_traits(canvas: CanvasItem, enemy: Enemy, now: float) -> void:
	if enemy.data and enemy.data.flying:
		canvas.draw_circle(enemy.position + Vector2(0, 6), enemy.radius * 0.8, Color(0, 0, 0, 0.3))
	if enemy.is_shielded(now):
		canvas.draw_arc(enemy.position, enemy.radius + 8.0, 0.0, TAU, 28, Color(0.55, 0.95, 0.6, 0.8), 2.5)
	if enemy.reflect_until > now:
		var angle: float = enemy.reflect_dir.angle()
		canvas.draw_arc(enemy.position, enemy.radius + 14.0, angle - 1.1, angle + 1.1, 20, Color(0.75, 0.95, 1.0, 0.95), 5.0)


## Saut boueux (Crapaud-gonfle, E1 réhabillé) : bond, et la gerbe de vase à l'atterrissage ralentit le Chasseur.
func technique_mud_leap(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	if not m._technique_leap(enemy, technique, player_pos):
		return false
	var radius: float = float(technique.params.get("radius", 70.0)) + 30.0
	m._later(enemy, technique.telegraph + float(technique.params.get("flight", 0.45)), func() -> void:
		ctx.fx.burst(enemy.position, radius, Color(0.45, 0.35, 0.2, 0.6))
		if ctx.player.global_position.distance_to(enemy.position) <= radius:
			ctx.player.hinder(float(technique.params.get("slow_time", 1.5)), float(technique.params.get("slow_mult", 0.5))))
	return true


## Rayon qui balaie (Colosse de cristal, E13) : arc balayé par tronçons, coupé par le décor ; puis cœur à nu
## (`weak_time` secondes, dégâts reçus × `weak_mult`) : la fenêtre pour frapper.
func technique_sweep_beam(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	var arc: float = deg_to_rad(float(technique.params.get("arc", 100.0)))
	var steps: int = int(technique.params.get("steps", 8))
	var sweep_time: float = float(technique.params.get("sweep_time", 1.6))
	var length: float = float(technique.params.get("length", 620.0))
	var width: float = float(technique.params.get("width", 30.0))
	var side: float = 1.0 if ctx.rng.randf() < 0.5 else -1.0
	var start: Vector2 = (player_pos - enemy.position).normalized().rotated(-arc * 0.5 * side)
	ctx.fx.danger_line(enemy.position, enemy.position + start * length, width, technique.telegraph)
	for i: int in steps:
		var dir: Vector2 = start.rotated(arc * side * i / float(maxi(steps - 1, 1)))
		m._later(enemy, technique.telegraph + sweep_time * i / float(steps), func() -> void:
			ctx.hazards.add_beam(enemy.position, dir, ctx.obstacles.clear_distance(enemy.position, dir, length), width, 0.05,
				sweep_time / float(steps) + 0.05, m._scaled(enemy, technique.damage), enemy.data.id))
	var weak: float = float(technique.params.get("weak_time", 0.0))
	enemy.technique_busy = technique.telegraph + sweep_time + weak
	if weak > 0.0:
		m._later(enemy, technique.telegraph + sweep_time, func() -> void:
			enemy.extra_damage_taken = float(technique.params.get("weak_mult", 1.6))
			ctx.fx.text(enemy.position + Vector2(0, -enemy.radius - 24.0), tr("ENEMY_WEAK_POINT"), Color(0.75, 0.95, 1.0))
			m._later(enemy, weak, func() -> void: enemy.extra_damage_taken = 1.0))
	return true


## Gerbe d'éclats : éventail de projectiles vers le Chasseur (arrêtés par le décor).
func technique_shard_fan(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	var count: int = int(technique.params.get("count", 5))
	var spread: float = deg_to_rad(float(technique.params.get("spread", 50.0)))
	var dir: Vector2 = (player_pos - enemy.position).normalized()
	enemy.technique_busy = technique.telegraph + 0.2
	ctx.fx.danger_line(enemy.position, enemy.position + dir * 260.0, 30.0, technique.telegraph)
	m._later(enemy, technique.telegraph, func() -> void:
		for i: int in count:
			var angle: float = (i / float(maxi(count - 1, 1)) - 0.5) * spread
			ctx.projectiles.spawn_hostile(enemy.position, dir.rotated(angle), float(technique.params.get("speed", 300.0)),
				m._scaled(enemy, technique.damage), enemy.data.id, 9.0, 3.0))
	return true
