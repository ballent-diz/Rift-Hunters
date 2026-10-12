class_name Techniques
extends RefCounted
## Techniques actives (touches 1-2-3). technique_kind (données) → fonction de code.

static func cast(ally: Ally, ctx: RunContext, aim: Vector2) -> bool:
	var tech: TechniqueData = ally.technique
	if tech == null:
		return false
	var ok: bool = false
	match tech.technique_kind:
		&"ash_dance":
			ok = _ash_dance(ally, ctx, tech, aim)
		&"gravity_well":
			ok = _gravity_well(ally, ctx, tech, aim)
		&"prism_flare":
			ok = _prism_flare(ally, ctx, tech)
		_:
			push_error("Technique inconnue : %s" % tech.technique_kind)
	if ok:
		ally.technique_cd = ally.technique_cooldown()
		ctx.stats.add(StringName(String(ally.data.id) + "_techniques"))
		ctx.stats.add(&"techniques_cast")
		ctx.events.technique_cast.emit(ally.data.id, tech.technique_kind)
	return ok


## Danse des cendres : enchaîne des frappes sur les ennemis autour du point visé.
static func _ash_dance(ally: Ally, ctx: RunContext, tech: TechniqueData, aim: Vector2) -> bool:
	var center: Vector2 = aim
	if center.distance_to(ctx.player.global_position) > 450.0:
		center = ctx.player.global_position + (aim - ctx.player.global_position).normalized() * 450.0
	var targets: Array[Enemy] = ctx.enemies.query_radius(center, tech.radius)
	if targets.is_empty():
		targets = ctx.enemies.query_radius(ctx.player.global_position, tech.radius)
	if targets.is_empty():
		return false
	targets.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	var previous: Vector2 = ally.global_position
	var tags: Array[StringName] = [DamageInfo.TAG_TECHNIQUE]
	for i: int in mini(tech.count, targets.size()):
		var enemy: Enemy = targets[i]
		var info: DamageInfo = ally.make_info(tech.damage, tags)
		info.statuses = tech.statuses
		var was_elite: bool = enemy.is_elite
		ctx.combat.deal_damage(enemy, info)
		if was_elite and not enemy.alive:
			ctx.stats.add(StringName(String(ally.data.id) + "_technique_elite_kills"))
		ctx.fx.line(previous, enemy.global_position, Color(1.0, 0.5, 0.2), 4.0, 0.3)
		previous = enemy.global_position
	ally.global_position = previous
	return true


## Puits de gravité : aspire les ennemis vers le point visé puis implose.
static func _gravity_well(ally: Ally, ctx: RunContext, tech: TechniqueData, aim: Vector2) -> bool:
	var player_pos: Vector2 = ctx.player.global_position
	var center: Vector2 = aim
	if center.distance_to(player_pos) > 420.0:
		center = player_pos + (aim - player_pos).normalized() * 420.0
	var stats: StatSheet = ctx.player.stats
	var radius: float = tech.radius * stats.get_value(StatKeys.WELL_RADIUS)
	var duration: float = tech.duration + stats.get_value(StatKeys.WELL_DURATION)
	var pull: float = float(tech.params.get("pull", 220.0)) * stats.get_value(StatKeys.WELL_PULL)
	var tags: Array[StringName] = [DamageInfo.TAG_TECHNIQUE]
	var implode: DamageInfo = ally.make_info(tech.damage, tags)
	implode.statuses = tech.statuses
	ctx.hazards.add_well(center, radius, duration, pull, implode, ally.data.id)
	return true


## Embrasement : fait détoner toutes les Marques présentes sur le terrain.
static func _prism_flare(ally: Ally, ctx: RunContext, tech: TechniqueData) -> bool:
	var total: int = 0
	var marked: Array[Enemy] = []
	for enemy: Enemy in ctx.enemies.list:
		if enemy.alive and enemy.statuses.get_stacks(&"mark") > 0:
			marked.append(enemy)
	for enemy: Enemy in marked:
		total += ctx.status_system.detonate(enemy, tech.damage * ally.damage_mult(), ally.data.id)
	ctx.fx.ring(ctx.player.global_position, 300.0, Color(0.6, 1.0, 1.0, 0.5), 0.35)
	ctx.stats.set_max(StringName(String(ally.data.id) + "_max_detonated"), float(total))
	return true
