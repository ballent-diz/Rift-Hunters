class_name GuardAuraEffect
extends GameplayEffect
## Le Chasseur subit moins de dégâts quand l'Écho propriétaire est proche (passive « Rempart »).

@export var radius: float = 160.0
@export var reduction: float = 0.1


func install(ctx: RunContext, owner_id: StringName) -> void:
	ctx.combat.add_player_damage_modifier(func(_amount: float) -> float:
		var ally: Ally = ctx.allies.get_ally(owner_id)
		if ally and ally.global_position.distance_to(ctx.player.global_position) <= radius:
			return 1.0 - reduction
		return 1.0
	)
