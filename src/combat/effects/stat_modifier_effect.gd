class_name StatModifierEffect
extends GameplayEffect
## Modifie une statistique du Chasseur (et des clés d'équipe) ou de l'Écho propriétaire.

enum Target { PLAYER, OWNER }

@export var target: Target = Target.PLAYER
@export var stat: StringName = &""
@export var flat: float = 0.0
@export var pct: float = 0.0


func install(ctx: RunContext, owner_id: StringName) -> void:
	if target == Target.OWNER:
		var ally: Ally = ctx.allies.get_ally(owner_id)
		if ally:
			ally.stats.add_modifier(stat, flat, pct)
	else:
		ctx.player.stats.add_modifier(stat, flat, pct)
