class_name DetonationEffect
extends GameplayEffect
## Réactions aux détonations de Marques : soin, bouclier, détonation automatique au cumul max.

@export var heal_per_stack: float = 0.0
@export var shield_per_stack: float = 0.0
@export var max_shield: float = 40.0
## Détone automatiquement une cible qui atteint son cumul maximal de Marques.
@export var auto_detonate_at_max: bool = false
@export var auto_detonate_damage_per_stack: float = 10.0


func install(ctx: RunContext, owner_id: StringName) -> void:
	if heal_per_stack > 0.0 or shield_per_stack > 0.0:
		ctx.events.detonation.connect(func(_enemy: Enemy, stacks: int, _source_id: StringName) -> void:
			if heal_per_stack > 0.0:
				ctx.player.heal(heal_per_stack * stacks)
			if shield_per_stack > 0.0:
				ctx.player.add_shield(shield_per_stack * stacks, max_shield)
		)
	if auto_detonate_at_max:
		ctx.events.status_applied.connect(func(target: Combatant, id: StringName, added: int, _source: StringName) -> void:
			if id != &"mark" or added <= 0 or not (target is Enemy):
				return
			var enemy: Enemy = target
			if enemy.statuses.get_stacks(&"mark") >= ctx.status_system.max_stacks_for(&"mark"):
				ctx.combat.queue(func() -> void:
					if enemy.is_alive():
						ctx.status_system.detonate(enemy, auto_detonate_damage_per_stack, owner_id)
				)
		)
