class_name DevourBehavior
extends AllyBehavior
## Mord les ennemis et dévore les plus faibles (non élites) : chaque dévoration augmente ses dégâts
## pour la partie et soigne le Chasseur. Gueule-d'ombre et ses évolutions.
## params : devour_threshold (ratio de PV), max_stacks, stack_bonus, heal, bite_radius.

func tick(ally: Ally, ctx: RunContext, delta: float) -> void:
	ally.attack_cd -= delta * ally.attack_speed_mult()
	var target: Enemy = _weakest_nearby(ally, ctx)
	var goal: Vector2 = target.global_position if target else ally.follow_point()
	ally.move_toward_point(goal, ally.data.move_speed, delta)
	ally.visual.set_facing_left(ally.velocity.x < -1.0)
	ally.visual.tick(delta, ally.velocity.length() > 5.0)
	if target == null or ally.attack_cd > 0.0:
		return
	if target.global_position.distance_to(ally.global_position) > target.radius + 28.0:
		return
	ally.attack_cd = ally.attack.cooldown
	ally.visual.play_action(&"attack")
	if not try_devour(ally, ctx, target):
		var bite_radius: float = float(ally.attack.params.get("bite_radius", 0.0))
		var victims: Array[Enemy] = [target]
		if bite_radius > 0.0:
			victims = ctx.enemies.query_radius(target.global_position, bite_radius)
		for enemy: Enemy in victims:
			var info: DamageInfo = ally.make_info(ally.attack.damage, [DamageInfo.TAG_ATTACK])
			info.statuses = ally.attack.statuses
			ctx.combat.deal_damage(enemy, info)
		ctx.fx.spark(target.global_position, Color(0.8, 0.3, 0.9), 16.0)


## Dévore la cible si elle est assez affaiblie et n'est ni élite ni boss. Retourne true si dévorée.
static func try_devour(ally: Ally, ctx: RunContext, target: Enemy, threshold_override: float = -1.0) -> bool:
	var params: Dictionary = ally.attack.params
	var threshold: float = threshold_override if threshold_override >= 0.0 else float(params.get("devour_threshold", 0.35))
	if target.is_elite or target.is_boss or target.is_obstacle or target.hp > target.max_hp * threshold:
		return false
	var tags: Array[StringName] = [DamageInfo.TAG_ATTACK, &"devour"]
	var info: DamageInfo = DamageInfo.make(target.hp * 10.0 + 9999.0, DamageInfo.SourceKind.ALLY, ally.data.id, tags)
	ctx.combat.deal_damage(target, info)
	var stacks: int = int(ally.memory.get("devour_stacks", 0))
	if stacks < int(params.get("max_stacks", 25)):
		ally.memory["devour_stacks"] = stacks + 1
		ally.stats.add_modifier(StatKeys.DAMAGE, 0.0, float(params.get("stack_bonus", 0.02)))
	ctx.player.heal(float(params.get("heal", 1.0)), false)
	ctx.stats.add(StringName(String(ally.data.id) + "_devoured"))
	ctx.fx.burst(target.global_position, 22.0, Color(0.7, 0.2, 0.8, 0.5))
	return true


func _weakest_nearby(ally: Ally, ctx: RunContext) -> Enemy:
	if ctx.allies.focus_time > 0.0:
		var focused: Enemy = ctx.enemies.find_nearest(ctx.allies.focus_point, ctx.balance.focus_radius)
		if focused:
			return focused
	var best: Enemy = null
	var best_score: float = INF
	for enemy: Enemy in ctx.enemies.query_radius(ally.global_position, ally.attack_range()):
		if enemy.is_obstacle or enemy.global_position.distance_to(ctx.player.global_position) > 420.0:
			continue
		var score: float = enemy.hp / enemy.max_hp * 200.0 + enemy.global_position.distance_to(ally.global_position)
		if score < best_score:
			best_score = score
			best = enemy
	return best
