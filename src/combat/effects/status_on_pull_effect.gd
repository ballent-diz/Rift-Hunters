class_name StatusOnPullEffect
extends GameplayEffect
## Les ennemis pris dans un Puits de gravité reçoivent un statut à chaque seconde.

@export var status_id: StringName = &"mark"
@export var stacks: int = 2
@export var synergy_id: StringName = &""


func install(ctx: RunContext, _owner_id: StringName) -> void:
	ctx.events.well_tick.connect(func(enemies: Array, source_id: StringName) -> void:
		for enemy: Enemy in enemies:
			ctx.status_system.apply(enemy, status_id, stacks, source_id)
		if synergy_id != &"" and not enemies.is_empty():
			ctx.events.synergy_proc.emit(synergy_id)
	)
