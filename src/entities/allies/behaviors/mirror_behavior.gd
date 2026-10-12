class_name MirrorBehavior
extends AllyBehavior
## Reste au contact du Chasseur et renvoie les projectiles ennemis proches ; sinon tire un éclat perçant.
## Mirelle et ses évolutions. params : reflect_mult (dégâts des renvois), shard_pierce.

func tick(ally: Ally, ctx: RunContext, delta: float) -> void:
	ally.attack_cd -= delta * ally.attack_speed_mult()
	var hover: Vector2 = ctx.player.global_position + Vector2(-34, -30)
	ally.move_toward_point(hover, ally.data.move_speed, delta)
	ally.visual.tick(delta, true)
	var shielding: bool = ctx.time < float(ally.memory.get("reflect_until", -1.0))
	if shielding:
		reflect(ally, ctx, float(ally.memory.get("reflect_radius", 180.0)))
	if ally.attack_cd > 0.0:
		return
	ally.attack_cd = ally.attack.cooldown
	if reflect(ally, ctx, ally.attack.radius) > 0:
		return
	var target: Enemy = AllyBehavior.pick_target(ally, ctx, ally.attack_range())
	if target == null:
		return
	var info: DamageInfo = ally.make_info(ally.attack.damage, [DamageInfo.TAG_ATTACK])
	info.statuses = ally.attack.statuses
	ally.visual.play_action(&"attack")
	ctx.projectiles.spawn_friendly(ally.global_position, target.global_position - ally.global_position,
		ally.attack.projectile_speed, info, {"pierce": int(ally.attack.params.get("shard_pierce", 3)), "radius": 6.0,
		"life": 1.6, "color": ally.data.visual.accent})


## Renvoie les projectiles ennemis autour du Chasseur. Retourne le nombre de projectiles renvoyés.
static func reflect(ally: Ally, ctx: RunContext, radius: float) -> int:
	var mult: float = float(ally.attack.params.get("reflect_mult", 2.0))
	var info: DamageInfo = ally.make_info(ally.attack.damage * mult, [DamageInfo.TAG_ATTACK, &"reflect"])
	info.statuses = ally.attack.statuses
	var count: int = ctx.projectiles.reflect_hostiles(ctx.player.global_position, radius, info, ally.data.visual.accent)
	if count > 0:
		ctx.stats.add(StringName(String(ally.data.id) + "_reflected"), count)
		ctx.fx.ring(ctx.player.global_position, radius, Color(ally.data.visual.accent, 0.6), 0.25)
	return count
