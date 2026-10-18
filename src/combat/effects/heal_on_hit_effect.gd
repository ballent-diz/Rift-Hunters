class_name HealOnHitEffect
extends GameplayEffect
## Chaque coup porté par la source soigne le Chasseur (temps de recharge entre deux soins). Sylvécaille.

@export var source_filter: StringName = &"owner"
@export var required_tag: StringName = &"attack"
@export var heal: float = 1.0
@export var cooldown: float = 0.5


func install(ctx: RunContext, owner_id: StringName) -> void:
	var ready_at: Array[float] = [0.0]
	ctx.events.enemy_damaged.connect(func(_enemy: Enemy, info: DamageInfo, _amount: float) -> void:
		if ctx.time < ready_at[0] or info.is_proc:
			return
		if not GameplayEffect.matches_source(source_filter, owner_id, info):
			return
		if required_tag != &"" and not info.has_tag(required_tag):
			return
		ready_at[0] = ctx.time + cooldown
		var before: float = ctx.player.hp
		ctx.player.heal(heal, false)
		ctx.stats.add(StringName(String(owner_id) + "_healed"), ctx.player.hp - before)
		if ctx.player.hp > before:
			ctx.allies.vfx.status_at(owner_id, ctx.player.global_position, 22.0, 0.9)
	)
