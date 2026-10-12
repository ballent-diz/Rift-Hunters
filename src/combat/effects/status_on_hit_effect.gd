class_name StatusOnHitEffect
extends GameplayEffect
## Applique un statut quand une source touche un ennemi (option : un coup sur N).

@export var source_filter: StringName = &"any"
@export var required_tag: StringName = &""
@export var status_id: StringName = &""
@export var stacks: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0
@export var every_n: int = 1


func install(ctx: RunContext, owner_id: StringName) -> void:
	var counter: Array[int] = [0]
	ctx.events.enemy_damaged.connect(func(enemy: Enemy, info: DamageInfo, _amount: float) -> void:
		if info.is_proc or info.has_tag(DamageInfo.TAG_DOT):
			return
		if not GameplayEffect.matches_source(source_filter, owner_id, info):
			return
		if required_tag != &"" and not info.has_tag(required_tag):
			return
		counter[0] += 1
		if counter[0] % maxi(every_n, 1) != 0:
			return
		if chance < 1.0 and ctx.rng.randf() > chance:
			return
		ctx.status_system.apply(enemy, status_id, stacks, info.source_id)
	)
