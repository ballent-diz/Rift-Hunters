class_name NovaOnHurtEffect
extends GameplayEffect
## Quand le Chasseur est touché : onde de choc (temps de recharge).

@export var damage: float = 30.0
@export var radius: float = 140.0
@export var knockback: float = 260.0
@export var cooldown: float = 5.0


func install(ctx: RunContext, _owner_id: StringName) -> void:
	var ready_at: Array[float] = [0.0]
	ctx.events.player_hurt.connect(func(_amount: float) -> void:
		if ctx.time < ready_at[0]:
			return
		ready_at[0] = ctx.time + cooldown
		var center: Vector2 = ctx.player.global_position
		var amount: float = damage * ctx.player.stats.get_value(StatKeys.DAMAGE)
		ctx.combat.queue(func() -> void:
			for enemy: Enemy in ctx.enemies.query_radius(center, radius):
				var info := DamageInfo.make(amount, DamageInfo.SourceKind.PLAYER, &"player", [DamageInfo.TAG_EXPLOSION])
				info.knockback = knockback
				info.direction = (enemy.global_position - center).normalized()
				ctx.combat.deal_damage(enemy, info)
			ctx.fx.burst(center, radius, Color(0.6, 0.9, 1.0, 0.4))
		)
	)
