class_name StatusChainEffect
extends GameplayEffect
## Quand un statut est appliqué par une source, applique aussi un second statut (ex. Racines → Fracture).

@export var trigger_status: StringName = &""
@export var source_filter: StringName = &"any"
@export var applied_status: StringName = &""
@export var stacks: int = 1
@export var synergy_id: StringName = &""


func install(ctx: RunContext, owner_id: StringName) -> void:
	ctx.events.status_applied.connect(func(target: Combatant, id: StringName, added: int, source_id: StringName) -> void:
		if id != trigger_status or added <= 0 or not (target is Enemy):
			return
		if not GameplayEffect.matches_source_id(source_filter, owner_id, source_id):
			return
		ctx.combat.queue(func() -> void: ctx.status_system.apply(target, applied_status, stacks, source_id))
		if synergy_id != &"":
			ctx.events.synergy_proc.emit(synergy_id)
	)
