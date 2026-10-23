class_name AllyBehavior
extends RefCounted
## Stratégie de comportement d'un Écho. Les paramètres viennent des données (AttackData).


func tick(_ally: Ally, _ctx: RunContext, _delta: float) -> void:
	pass


## Cible prioritaire : ennemis proches du point de focus s'il est actif, sinon le plus proche.
static func pick_target(ally: Ally, ctx: RunContext, search_range: float) -> Enemy:
	if ctx.allies.focus_time > 0.0:
		var focused: Enemy = ctx.enemies.find_nearest(ctx.allies.focus_point, ctx.balance.focus_radius)
		if focused:
			return focused
	var origin: Vector2 = ally.global_position
	var target: Enemy = ctx.enemies.find_nearest_visible(origin, search_range)
	if target and target.global_position.distance_to(ctx.player.global_position) > 420.0:
		return null
	return target
