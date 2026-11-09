class_name CorruptionDirector
extends Node2D
## Brique B9 « sol corrompu » (carte 21, docs/maps/FAUBOURGS_BRISES.md) : les nappes violettes peintes renforcent qui y
## reste. Le Chasseur s'y charge peu à peu (jusqu'à +corruption_power de dégâts infligés, la charge retombe dehors)
## mais y subit plus de dégâts ; les Corrompus qui s'y tiennent frappent plus fort et vont plus vite.

const COLOR := Color(0.8, 0.3, 0.95)
## Les Corrompus sont réévalués à ce rythme (coût borné pour les grandes hordes).
const ENEMY_CHECK := 0.25

var ctx: RunContext
## Charge du Chasseur (0 à 1).
var charge: float = 0.0
var player_inside: bool = false
## Corrompus renforcés : {Enemy: [vitesse ajoutée, dégâts ajoutés]}.
var empowered: Dictionary = {}
var _bounds: Array[Rect2] = []
var _all := Rect2()
var _check: float = 0.0
var _time: float = 0.0
var _announced: bool = false


static func uses_corruption(arena: ArenaData) -> bool:
	return not arena.corrupted_patches.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Corruption"
	z_index = 3
	for poly: PackedVector2Array in ctx.arena.corrupted_patches:
		var box := Rect2(poly[0], Vector2.ZERO)
		for p: Vector2 in poly:
			box = box.expand(p)
		_bounds.append(box)
		_all = box if _all.size == Vector2.ZERO else _all.merge(box)
	ctx.combat.add_damage_modifier(func(_enemy: Enemy, info: DamageInfo) -> float:
		return 1.0 + ctx.arena.corruption_power * charge if info.is_friendly() else 1.0)
	ctx.combat.add_player_damage_modifier(func(_amount: float) -> float:
		return ctx.arena.corruption_taken_mult if player_inside else 1.0)


func inside(pos: Vector2) -> bool:
	if not _all.has_point(pos):
		return false
	for i: int in _bounds.size():
		if _bounds[i].has_point(pos) and Geometry2D.is_point_in_polygon(pos, ctx.arena.corrupted_patches[i]):
			return true
	return false


func step(delta: float) -> void:
	_time += delta
	player_inside = ctx.player.alive and inside(ctx.player.global_position)
	if player_inside:
		charge = minf(charge + delta / maxf(ctx.arena.corruption_build, 0.1), 1.0)
		if not _announced:
			_announced = true
			ctx.events.event_started.emit("CORRUPTION_INTRO")
		ctx.stats.add(&"corruption_time", delta)
	else:
		charge = maxf(charge - delta / maxf(ctx.arena.corruption_fade, 0.1), 0.0)
	_check -= delta
	if _check <= 0.0:
		_check = ENEMY_CHECK
		_step_enemies()
	queue_redraw()


func _step_enemies() -> void:
	for enemy: Variant in empowered.keys():
		if not is_instance_valid(enemy) or not (enemy as Enemy).alive or not inside((enemy as Enemy).position):
			_release(enemy)
	var mult: float = ctx.arena.corruption_enemy_mult
	for enemy: Enemy in ctx.enemies.list:
		if not enemy.alive or enemy.is_boss or enemy.is_obstacle or empowered.has(enemy) or not inside(enemy.position):
			continue
		var bonus: Array[float] = [enemy.move_speed * (ctx.arena.corruption_enemy_speed - 1.0),
			enemy.contact_damage * (mult - 1.0)]
		enemy.move_speed += bonus[0]
		enemy.contact_damage += bonus[1]
		empowered[enemy] = bonus


func _release(enemy: Variant) -> void:
	var bonus: Array = empowered[enemy]
	empowered.erase(enemy)
	if is_instance_valid(enemy):
		(enemy as Enemy).move_speed -= float(bonus[0])
		(enemy as Enemy).contact_damage -= float(bonus[1])


func _draw() -> void:
	if ctx == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
	if charge > 0.02:
		var pos: Vector2 = ctx.player.global_position
		draw_arc(pos, 30.0 + 6.0 * pulse, -PI / 2.0, -PI / 2.0 + TAU * charge, 32, Color(COLOR, 0.75), 3.0)
	for enemy: Variant in empowered:
		if is_instance_valid(enemy):
			draw_arc((enemy as Enemy).position, (enemy as Enemy).radius + 4.0, 0.0, TAU, 16, Color(COLOR, 0.35 + 0.3 * pulse),
				2.0)
