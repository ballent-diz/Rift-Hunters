class_name DiveBehavior
extends AllyBehavior
## Vole près du Chasseur puis pique à travers sa cible : dégâts sur toute la ligne (attack.radius = demi-largeur)
## et traînée de feu au sol. Pyraile. params : overshoot (prolongement du piqué), trail_count, trail_radius,
## trail_duration, trail_damage (part des dégâts de l'attaque par demi-seconde).

const DIVE_TIME := 0.2


func tick(ally: Ally, ctx: RunContext, delta: float) -> void:
	ally.attack_cd -= delta * ally.attack_speed_mult()
	var m: Dictionary = ally.memory
	if m.get("diving", false):
		m["t"] = float(m["t"]) + delta
		var k: float = clampf(float(m["t"]) / DIVE_TIME, 0.0, 1.0)
		ally.global_position = (m["from"] as Vector2).lerp(m["to"], k)
		ally.visual.tick(delta, true, 600.0)
		if k >= 1.0:
			_finish_dive(ally, ctx)
		return
	var hover: Vector2 = ally.follow_point() + Vector2(0, -18 + sin(ctx.time * 2.5 + ally.slot_index) * 8.0)
	ally.move_toward_point(hover, ally.data.move_speed, delta)
	ally.visual.set_facing_left(ally.velocity.x < -1.0)
	ally.visual.tick(delta, true, ally.velocity.length())
	if ally.attack_cd > 0.0:
		return
	var target: Enemy = AllyBehavior.pick_target(ally, ctx, ally.attack_range())
	if target == null:
		return
	var from: Vector2 = ally.global_position
	var dir: Vector2 = (target.global_position - from).normalized()
	var to: Vector2 = target.global_position + dir * float(ally.attack.params.get("overshoot", 70.0))
	m["diving"] = true
	m["t"] = 0.0
	m["from"] = from
	m["to"] = ctx.obstacles.push_out(to, Ally.BODY_RADIUS)
	ally.visual.set_facing_left(dir.x < 0.0)
	ally.visual.play_action(&"attack")
	ctx.allies.vfx.attack(ally, from, m["to"], 0.4)


func _finish_dive(ally: Ally, ctx: RunContext) -> void:
	var m: Dictionary = ally.memory
	m["diving"] = false
	ally.attack_cd = ally.attack.cooldown
	var from: Vector2 = m["from"]
	var to: Vector2 = m["to"]
	var half_width: float = maxf(ally.attack.radius, 12.0)
	var middle: Vector2 = (from + to) * 0.5
	for enemy: Enemy in ctx.enemies.query_radius(middle, from.distance_to(to) * 0.5 + half_width):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
		if closest.distance_to(enemy.global_position) > half_width + enemy.radius:
			continue
		var info: DamageInfo = ally.make_info(ally.attack.damage, [DamageInfo.TAG_ATTACK])
		info.statuses = ally.attack.statuses
		info.knockback = ally.attack.knockback
		info.direction = (to - from).normalized()
		ctx.combat.deal_damage(enemy, info)
	var params: Dictionary = ally.attack.params
	var count: int = int(params.get("trail_count", 3))
	if count <= 0:
		return
	var trail: DamageInfo = ally.make_info(ally.attack.damage * float(params.get("trail_damage", 0.2)),
		[DamageInfo.TAG_ATTACK])
	for i: int in count:
		var pos: Vector2 = from.lerp(to, (i + 1.0) / (count + 1.0))
		ctx.hazards.add_zone(pos, float(params.get("trail_radius", 30.0)), float(params.get("trail_duration", 2.0)),
			trail.amount, ally.data.id, ally.attack.statuses, ally.data.visual.primary)
