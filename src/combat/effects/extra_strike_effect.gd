class_name ExtraStrikeEffect
extends GameplayEffect
## Frappe supplémentaire quand la source touche une cible sous un statut (marquage → attaque).

@export var source_filter: StringName = &"any"
@export var required_status: StringName = &""
@export var damage_ratio: float = 0.5
@export_range(0.0, 1.0) var chance: float = 1.0
## Synergie créditée (statistiques, maîtrise).
@export var synergy_id: StringName = &""


func install(ctx: RunContext, owner_id: StringName) -> void:
	ctx.events.enemy_damaged.connect(func(enemy: Enemy, info: DamageInfo, _amount: float) -> void:
		if info.is_proc or info.has_tag(DamageInfo.TAG_DOT) or not enemy.is_alive():
			return
		if not GameplayEffect.matches_source(source_filter, owner_id, info):
			return
		if required_status != &"" and not enemy.statuses.has(required_status):
			return
		if chance < 1.0 and ctx.rng.randf() > chance:
			return
		var proc: DamageInfo = info.duplicate_info()
		proc.amount = info.amount * damage_ratio
		proc.is_proc = true
		proc.statuses = []
		proc.tags.append(DamageInfo.TAG_PROC)
		ctx.combat.queue(func() -> void:
			if enemy.is_alive():
				ctx.combat.deal_damage(enemy, proc)
				ctx.fx.spark(enemy.global_position, Color(1.0, 0.75, 0.3), 14.0)
		)
		if synergy_id != &"":
			ctx.events.synergy_proc.emit(synergy_id)
	)
