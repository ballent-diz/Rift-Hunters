class_name DashStatusEffect
extends GameplayEffect
## La Ruée applique un statut aux ennemis proches du point d'arrivée.

@export var status_id: StringName = &"fracture"
@export var stacks: int = 1
@export var radius: float = 80.0


func install(ctx: RunContext, _owner_id: StringName) -> void:
	ctx.events.player_dashed.connect(func(_from: Vector2, to: Vector2) -> void:
		for enemy: Enemy in ctx.enemies.query_radius(to, radius):
			ctx.status_system.apply(enemy, status_id, stacks, &"player")
		ctx.fx.ring(to, radius, Color(1.0, 0.6, 0.3, 0.5), 0.3)
	)
