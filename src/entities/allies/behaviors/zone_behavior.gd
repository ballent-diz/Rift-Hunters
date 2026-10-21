class_name ZoneBehavior
extends AllyBehavior
## Plante des zones persistantes (ronces) au cœur des groupes d'ennemis. Ronceline et ses évolutions.
## params : duration (durée de la zone), count (zones par attaque), spread (écart entre zones).

func tick(ally: Ally, ctx: RunContext, delta: float) -> void:
	ally.attack_cd -= delta * ally.attack_speed_mult()
	ally.move_toward_point(ally.follow_point(), ally.data.move_speed, delta)
	ally.visual.face_velocity(ally.velocity.x)
	ally.visual.tick(delta, ally.velocity.length() > 5.0, ally.velocity.length())
	if ally.attack_cd > 0.0:
		return
	var target: Enemy = AllyBehavior.pick_target(ally, ctx, ally.attack_range())
	if target == null:
		return
	ally.attack_cd = ally.attack.cooldown
	ally.visual.play_action(&"attack")
	var params: Dictionary = ally.attack.params
	var count: int = int(params.get("count", 1))
	var spread: float = float(params.get("spread", 60.0))
	var info: DamageInfo = ally.make_info(ally.attack.damage, [DamageInfo.TAG_ATTACK])
	var duration: float = float(params.get("duration", 4.0))
	ctx.allies.vfx.play(ally.data.id, &"attack", target.global_position, target.global_position - ally.global_position,
		{"radius": ally.attack.radius, "travel_distance": 0.0, "visual_duration": 0.6})
	for i: int in count:
		var offset: Vector2 = Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(TAU * i / maxf(count - 1, 1)) * spread
		ctx.hazards.add_zone(target.global_position + offset, ally.attack.radius, duration,
			info.amount, ally.data.id, ally.attack.statuses, ally.data.visual.secondary)
		ctx.allies.vfx.status_at(ally.data.id, target.global_position + offset, ally.attack.radius, duration)
	ctx.fx.line(ally.global_position, target.global_position, Color(0.5, 0.9, 0.4, 0.6), 2.0, 0.2)
