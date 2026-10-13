class_name SpreadStatusOnKillEffect
extends GameplayEffect
## À la mort d'un ennemi sous statut, propage ce statut autour (ou applique un statut donné).

@export var source_filter: StringName = &"any"
@export var required_tag: StringName = &""
## Statut lu sur l'ennemi tué (vide = aucune condition).
@export var required_status: StringName = &""
## Statut appliqué autour (vide = required_status).
@export var status_id: StringName = &""
## Cumuls appliqués : fixes si > 0, sinon ceux de l'ennemi tué.
@export var stacks: int = 0
@export var radius: float = 120.0
@export var synergy_id: StringName = &""


func install(ctx: RunContext, owner_id: StringName) -> void:
	ctx.events.enemy_killed.connect(func(enemy: Enemy, info: DamageInfo) -> void:
		if not GameplayEffect.matches_source(source_filter, owner_id, info):
			return
		if required_tag != &"" and not info.has_tag(required_tag):
			return
		var dead_stacks: int = enemy.statuses.get_stacks(required_status) if required_status != &"" else 1
		if dead_stacks <= 0:
			return
		var applied: StringName = status_id if status_id != &"" else required_status
		var amount: int = stacks if stacks > 0 else dead_stacks
		var center: Vector2 = enemy.global_position
		var source: StringName = info.source_id
		ctx.combat.queue(func() -> void:
			for other: Enemy in ctx.enemies.query_radius(center, radius):
				ctx.status_system.apply(other, applied, amount, source)
			ctx.fx.ring(center, radius, Color(0.6, 0.9, 1.0, 0.5), 0.25)
		)
		if synergy_id != &"":
			ctx.events.synergy_proc.emit(synergy_id)
	)
