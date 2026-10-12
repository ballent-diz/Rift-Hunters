class_name SlamBehavior
extends AllyBehavior
## Se place près de la mêlée et frappe le sol (zone + statuts + recul).
## params : windup, taunt_radius/taunt_duration (Monolithe), shockwave_radius (Tremblecroc).


func tick(ally: Ally, ctx: RunContext, delta: float) -> void:
	ally.attack_cd -= delta * ally.attack_speed_mult()
	var m: Dictionary = ally.memory
	var params: Dictionary = ally.attack.params
	if float(m.get("windup", 0.0)) > 0.0:
		m["windup"] = float(m["windup"]) - delta
		if float(m["windup"]) <= 0.0:
			_slam(ally, ctx)
		ally.visual.tick(delta, false)
		return
	var target: Enemy = AllyBehavior.pick_target(ally, ctx, 300.0)
	var goal: Vector2 = ally.follow_point()
	if target:
		goal = target.global_position
	ally.move_toward_point(goal, ally.data.move_speed, delta)
	ally.visual.set_facing_left(ally.velocity.x < -1.0)
	ally.visual.tick(delta, ally.velocity.length() > 5.0)
	if ally.attack_cd <= 0.0 and not ctx.enemies.query_radius(ally.global_position, ally.attack.radius * 0.8).is_empty():
		m["windup"] = float(params.get("windup", 0.25))
		ally.visual.flash()


func _slam(ally: Ally, ctx: RunContext) -> void:
	ally.attack_cd = ally.attack.cooldown
	var params: Dictionary = ally.attack.params
	var center: Vector2 = ally.global_position
	var radius: float = ally.attack.radius * ally.stats.get_value(StatKeys.ALLY_RANGE)
	var tags: Array[StringName] = [DamageInfo.TAG_ATTACK]
	for enemy: Enemy in ctx.enemies.query_radius(center, radius):
		var info: DamageInfo = ally.make_info(ally.attack.damage, tags)
		info.statuses = ally.attack.statuses
		info.knockback = ally.attack.knockback
		info.direction = (enemy.global_position - center).normalized()
		ctx.combat.deal_damage(enemy, info)
	ctx.fx.burst(center, radius, Color(0.55, 1.0, 0.6, 0.35))
	var taunt_radius: float = float(params.get("taunt_radius", 0.0))
	if taunt_radius > 0.0:
		for enemy: Enemy in ctx.enemies.query_radius(center, taunt_radius):
			if not enemy.is_boss:
				enemy.taunt_target = ally
				enemy.taunt_time = float(params.get("taunt_duration", 2.5))
		ctx.fx.ring(center, taunt_radius, Color(1.0, 0.85, 0.4, 0.5), 0.4)
	var shockwave: float = float(params.get("shockwave_radius", 0.0))
	if shockwave > 0.0:
		var wave_info: DamageInfo = ally.make_info(ally.attack.damage * 0.6, tags)
		ctx.hazards.add_ring(center, 420.0, shockwave, 22.0, wave_info.amount, false, ally.data.id, [], 0.0,
			ally.attack.statuses, 0.0)
