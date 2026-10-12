class_name ProjectileManager
extends Node2D
## Projectiles alliés et ennemis. Dessin groupé : projectiles ennemis au-dessus de tout (lisibilité).

const HOSTILE_CORE := Color(1.0, 0.75, 1.0)
const HOSTILE_BODY := Color(0.95, 0.2, 0.75)
const HOSTILE_OUTLINE := Color(0.08, 0.0, 0.1)

var ctx: RunContext
var friendly: Array[Projectile] = []
var hostile: Array[Projectile] = []
var _pool: Array[Projectile] = []
var _buffer: Array = []
var _friendly_canvas: Node2D
var _hostile_canvas: Node2D


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	_friendly_canvas = Node2D.new()
	_friendly_canvas.z_index = 5
	_friendly_canvas.draw.connect(_draw_friendly)
	add_child(_friendly_canvas)
	_hostile_canvas = Node2D.new()
	_hostile_canvas.z_index = 30
	_hostile_canvas.draw.connect(_draw_hostile)
	add_child(_hostile_canvas)


func _acquire() -> Projectile:
	var p: Projectile = _pool.pop_back() if not _pool.is_empty() else Projectile.new()
	p.hit_ids.clear()
	p.target = null
	p.split = 0
	p.chain = 0
	p.pierce_left = 0
	p.homing = 0.0
	return p


## options : pierce, split, chain, homing, radius, life, color, target.
func spawn_friendly(pos: Vector2, dir: Vector2, speed: float, info: DamageInfo, options: Dictionary = {}) -> Projectile:
	var p: Projectile = _acquire()
	p.friendly = true
	p.position = pos
	p.velocity = dir.normalized() * speed
	p.info = info
	p.source_id = info.source_id
	p.pierce_left = int(options.get("pierce", 0))
	p.split = int(options.get("split", 0))
	p.chain = int(options.get("chain", 0))
	p.homing = float(options.get("homing", 0.0))
	p.radius = float(options.get("radius", 6.0))
	p.life = float(options.get("life", 1.5))
	p.color = options.get("color", Color.WHITE)
	p.target = options.get("target", null)
	friendly.append(p)
	ctx.stats.add(&"projectiles_fired")
	return p


func spawn_hostile(pos: Vector2, dir: Vector2, speed: float, damage: float, source_id: StringName,
		radius: float = 8.0, life: float = 5.0) -> Projectile:
	var p: Projectile = _acquire()
	p.friendly = false
	p.position = pos
	p.velocity = dir.normalized() * speed
	p.hostile_damage = damage
	p.source_id = source_id
	p.radius = radius
	p.life = life
	hostile.append(p)
	return p


func step(delta: float) -> void:
	var rect: Rect2 = ctx.arena_rect().grow(60.0)
	var i: int = friendly.size() - 1
	while i >= 0:
		var p: Projectile = friendly[i]
		if not _step_friendly(p, delta, rect):
			friendly[i] = friendly[friendly.size() - 1]
			friendly.pop_back()
			_pool.append(p)
		i -= 1
	i = hostile.size() - 1
	while i >= 0:
		var p: Projectile = hostile[i]
		if not _step_hostile(p, delta, rect):
			hostile[i] = hostile[hostile.size() - 1]
			hostile.pop_back()
			_pool.append(p)
		i -= 1
	_friendly_canvas.queue_redraw()
	_hostile_canvas.queue_redraw()


## Retourne false si le projectile doit disparaître.
func _step_friendly(p: Projectile, delta: float, rect: Rect2) -> bool:
	if p.homing > 0.0:
		if p.target == null or not is_instance_valid(p.target) or not p.target.alive:
			p.target = ctx.enemies.find_nearest(p.position, 320.0, p.hit_ids)
		if p.target:
			var desired: float = (p.target.position - p.position).angle()
			var current: float = p.velocity.angle()
			var turn: float = clampf(wrapf(desired - current, -PI, PI), -p.homing * delta, p.homing * delta)
			p.velocity = p.velocity.rotated(turn)
	p.position += p.velocity * delta
	p.life -= delta
	if p.life <= 0.0 or not rect.has_point(p.position):
		return false
	var boss: Enemy = ctx.boss
	if boss and boss.alive and boss.absorb_radius > 0.0 and p.position.distance_to(boss.position) < boss.absorb_radius:
		boss.absorbed_count += 1
		ctx.fx.spark(p.position, Color(0.8, 0.4, 1.0), 8.0)
		return false
	_buffer.clear()
	# Rayon de recherche serré (ennemis ≤ 32 px) ; le boss, plus grand, est testé à part.
	ctx.enemies.grid.query(p.position, p.radius + 32.0, _buffer)
	if boss and boss.alive and not _buffer.has(boss):
		_buffer.append(boss)
	for item: Variant in _buffer:
		var enemy: Enemy = item
		if not enemy.alive:
			continue
		var reach: float = p.radius + enemy.radius
		if p.position.distance_squared_to(enemy.position) > reach * reach:
			continue
		var id: int = enemy.get_instance_id()
		if p.hit_ids.has(id):
			continue
		p.hit_ids[id] = true
		var hit: DamageInfo = p.info.duplicate_info()
		hit.direction = p.velocity.normalized()
		ctx.combat.deal_damage(enemy, hit)
		if p.split > 0:
			_spawn_shards(p, enemy)
		if p.chain > 0:
			p.chain -= 1
			var next: Enemy = ctx.enemies.find_nearest(p.position, 260.0, p.hit_ids)
			if next == null:
				return false
			p.target = next
			p.velocity = (next.position - p.position).normalized() * p.velocity.length()
			p.life = maxf(p.life, 0.8)
			return true
		if p.pierce_left > 0:
			p.pierce_left -= 1
			continue
		return false
	return true


func _spawn_shards(p: Projectile, enemy: Enemy) -> void:
	var base_angle: float = p.velocity.angle()
	for s: int in p.split:
		var shard_info: DamageInfo = p.info.duplicate_info()
		shard_info.amount *= 0.45
		shard_info.statuses = []
		var angle: float = base_angle + (s - (p.split - 1) * 0.5) * 0.7 + ctx.rng.randf_range(-0.15, 0.15)
		var shard: Projectile = spawn_friendly(enemy.position, Vector2.RIGHT.rotated(angle), p.velocity.length() * 0.8, shard_info, {
			"radius": p.radius * 0.7, "life": 0.45, "color": p.color.lightened(0.2),
		})
		shard.hit_ids[enemy.get_instance_id()] = true


func _step_hostile(p: Projectile, delta: float, rect: Rect2) -> bool:
	p.position += p.velocity * delta
	p.life -= delta
	if p.life <= 0.0 or not rect.has_point(p.position):
		return false
	var player: Player = ctx.player
	if player.alive and p.position.distance_to(player.position) < p.radius + player.radius * 0.8:
		if player.can_be_hurt():
			ctx.combat.damage_player(p.hostile_damage, p.source_id)
			return false
	return true


## Transforme les projectiles ennemis proches en projectiles alliés renvoyés vers les ennemis.
func reflect_hostiles(center: Vector2, radius: float, template: DamageInfo, color: Color) -> int:
	var count: int = 0
	var i: int = hostile.size() - 1
	while i >= 0:
		var p: Projectile = hostile[i]
		if p.position.distance_to(center) <= radius:
			hostile[i] = hostile[hostile.size() - 1]
			hostile.pop_back()
			var info: DamageInfo = template.duplicate_info()
			info.amount += p.hostile_damage
			var target: Enemy = ctx.enemies.find_nearest(p.position, 500.0)
			var dir: Vector2 = (target.position - p.position) if target else -p.velocity
			spawn_friendly(p.position, dir, maxf(p.velocity.length() * 2.0, 380.0), info,
				{"pierce": 1, "radius": p.radius, "life": 1.6, "color": color, "target": target})
			_pool.append(p)
			count += 1
		i -= 1
	return count


func clear_hostile() -> void:
	for p: Projectile in hostile:
		_pool.append(p)
	hostile.clear()


func _draw_friendly() -> void:
	for p: Projectile in friendly:
		_friendly_canvas.draw_circle(p.position, p.radius * 1.5, Color(p.color, 0.25))
		_friendly_canvas.draw_circle(p.position, p.radius, Color(p.color, 0.85))


func _draw_hostile() -> void:
	for p: Projectile in hostile:
		_hostile_canvas.draw_circle(p.position, p.radius + 2.0, HOSTILE_OUTLINE)
		_hostile_canvas.draw_circle(p.position, p.radius, HOSTILE_BODY)
		_hostile_canvas.draw_circle(p.position, p.radius * 0.45, HOSTILE_CORE)
