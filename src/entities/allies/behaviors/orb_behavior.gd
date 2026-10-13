class_name OrbBehavior
extends AllyBehavior
## Plane près du Chasseur et tire des orbes à tête chercheuse (Lucivelle et ses évolutions).

func tick(ally: Ally, ctx: RunContext, delta: float) -> void:
	ally.attack_cd -= delta * ally.attack_speed_mult()
	var hover: Vector2 = ally.follow_point() + Vector2(0, sin(ctx.time * 3.0 + ally.slot_index) * 10.0)
	ally.move_toward_point(hover, ally.data.move_speed, delta)
	ally.visual.tick(delta, true)
	if ally.attack_cd > 0.0:
		return
	var target: Enemy = AllyBehavior.pick_target(ally, ctx, ally.attack_range())
	if target == null:
		return
	ally.attack_cd = ally.attack.cooldown
	ally.visual.set_facing_left(target.global_position.x < ally.global_position.x)
	ally.visual.play_action(&"attack")
	var tags: Array[StringName] = [DamageInfo.TAG_ATTACK]
	var count: int = maxi(ally.attack.projectile_count, 1)
	for i: int in count:
		var info: DamageInfo = ally.make_info(ally.attack.damage, tags)
		info.statuses = ally.attack.statuses
		var dir: Vector2 = (target.global_position - ally.global_position).normalized().rotated((i - (count - 1) * 0.5) * 0.4)
		ctx.projectiles.spawn_friendly(ally.global_position, dir, ally.attack.projectile_speed, info, {
			"homing": ally.attack.homing, "split": ally.attack.split, "chain": ally.attack.chain,
			"pierce": ally.attack.pierce, "radius": 7.0, "life": 2.2, "target": target,
			"color": ally.data.visual.primary.lightened(0.3),
		})
