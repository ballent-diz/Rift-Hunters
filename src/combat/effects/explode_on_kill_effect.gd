class_name ExplodeOnKillEffect
extends GameplayEffect
## Les ennemis tués sous un statut explosent (dégâts de zone, sans réaction en chaîne infinie).

@export var source_filter: StringName = &"any"
@export var required_status: StringName = &""
@export var radius: float = 60.0
@export var damage: float = 20.0
@export var scales_with_player_damage: bool = true


func install(ctx: RunContext, owner_id: StringName) -> void:
	ctx.events.enemy_killed.connect(func(enemy: Enemy, info: DamageInfo) -> void:
		if info.has_tag(DamageInfo.TAG_EXPLOSION):
			return
		if not GameplayEffect.matches_source(source_filter, owner_id, info):
			return
		if required_status != &"" and not enemy.statuses.has(required_status):
			return
		var center: Vector2 = enemy.global_position
		var amount: float = damage * (ctx.player.stats.get_value(StatKeys.DAMAGE) if scales_with_player_damage else 1.0)
		var tags: Array[StringName] = [DamageInfo.TAG_EXPLOSION, DamageInfo.TAG_PROC]
		var blast: DamageInfo = DamageInfo.make(amount, info.source_kind, info.source_id, tags)
		blast.is_proc = true
		ctx.combat.queue(func() -> void:
			for other: Enemy in ctx.enemies.query_radius(center, radius):
				ctx.combat.deal_damage(other, blast)
			ctx.fx.burst(center, radius, Color(1.0, 0.5, 0.2, 0.45))
		)
	)
