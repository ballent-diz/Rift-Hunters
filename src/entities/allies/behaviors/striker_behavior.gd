class_name StrikerBehavior
extends AllyBehavior
## Bond sur une cible et frappe (mono-cible, en chaîne via attack.chain, ou en zone via attack.radius).
## Utilisé par Cendrelame et ses évolutions.

const LEAP_TIME := 0.12


func tick(ally: Ally, ctx: RunContext, delta: float) -> void:
	ally.attack_cd -= delta * ally.attack_speed_mult()
	var m: Dictionary = ally.memory
	if m.get("leaping", false):
		m["t"] = float(m["t"]) + delta
		var k: float = clampf(float(m["t"]) / LEAP_TIME, 0.0, 1.0)
		ally.global_position = (m["from"] as Vector2).lerp(m["to"], k)
		if k >= 1.0:
			_strike(ally, ctx)
		return
	var target: Enemy = AllyBehavior.pick_target(ally, ctx, ally.attack_range() + 120.0)
	if target and ally.attack_cd <= 0.0 and target.global_position.distance_to(ally.global_position) <= ally.attack_range():
		m["chain_left"] = ally.attack.chain
		m["hit"] = {}
		_leap(ally, target)
		return
	var goal: Vector2 = ally.follow_point()
	if target:
		goal = target.global_position + (ally.global_position - target.global_position).normalized() * 50.0
	ally.move_toward_point(goal, ally.data.move_speed, delta)
	ally.visual.set_facing_left(ally.velocity.x < -1.0)
	ally.visual.tick(delta, ally.velocity.length() > 5.0, ally.velocity.length())


func _leap(ally: Ally, target: Enemy) -> void:
	var m: Dictionary = ally.memory
	m["leaping"] = true
	m["t"] = 0.0
	m["from"] = ally.global_position
	m["to"] = target.global_position
	m["target"] = target
	ally.visual.set_facing_left(target.global_position.x < ally.global_position.x)
	ally.visual.play_action(&"attack")


func _strike(ally: Ally, ctx: RunContext) -> void:
	var m: Dictionary = ally.memory
	m["leaping"] = false
	var target_ref: Variant = m.get("target")
	var target: Enemy = target_ref if is_instance_valid(target_ref) else null
	var hit: Dictionary = m.get("hit", {})
	var center: Vector2 = m["to"]
	var tags: Array[StringName] = [DamageInfo.TAG_ATTACK]
	var victims: Array[Enemy] = []
	if ally.attack.radius > 0.0:
		victims = ctx.enemies.query_radius(center, ally.attack.radius)
		ctx.fx.burst(center, ally.attack.radius, Color(1.0, 0.55, 0.25, 0.4))
	elif target and target.alive:
		victims = [target]
	for enemy: Enemy in victims:
		if enemy.statuses.has(&"fracture"):
			ctx.stats.add(StringName(String(ally.data.id) + "_fractured_hits"))
		var info: DamageInfo = ally.make_info(ally.attack.damage, tags)
		info.statuses = ally.attack.statuses
		info.knockback = ally.attack.knockback
		info.direction = (enemy.global_position - (m["from"] as Vector2)).normalized()
		ctx.combat.deal_damage(enemy, info)
		hit[enemy.get_instance_id()] = true
	ctx.fx.line(m["from"], center, Color(1.0, 0.6, 0.3), 3.0, 0.12)
	var chain_left: int = int(m.get("chain_left", 0))
	if chain_left > 0:
		var next: Enemy = ctx.enemies.find_nearest(center, 170.0, hit)
		if next:
			m["chain_left"] = chain_left - 1
			_leap(ally, next)
			return
	ally.attack_cd = ally.attack.cooldown
