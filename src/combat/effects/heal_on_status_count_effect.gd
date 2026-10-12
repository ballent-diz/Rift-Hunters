class_name HealOnStatusCountEffect
extends GameplayEffect
## Soigne le Chasseur tous les N cumuls d'un statut posés par la source.

@export var source_filter: StringName = &"owner"
@export var status_id: StringName = &"mark"
@export var count: int = 25
@export var heal: float = 3.0


func install(ctx: RunContext, owner_id: StringName) -> void:
	var counter: Array[int] = [0]
	ctx.events.status_applied.connect(func(_target: Combatant, id: StringName, added: int, source_id: StringName) -> void:
		if id != status_id or added <= 0:
			return
		if not GameplayEffect.matches_source_id(source_filter, owner_id, source_id):
			return
		counter[0] += added
		while counter[0] >= count:
			counter[0] -= count
			ctx.player.heal(heal)
	)
