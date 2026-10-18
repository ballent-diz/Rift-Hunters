class_name RetaliateOnHurtEffect
extends GameplayEffect
## Quand le Chasseur est touché, l'Écho propriétaire renvoie la foudre sur les ennemis proches (Égidor).
## Dégâts = base + ratio des dégâts encaissés, multipliés par les dégâts de l'Écho.

@export var radius: float = 220.0
@export var targets: int = 3
@export var base_damage: float = 12.0
@export var taken_ratio: float = 1.5
@export var status_id: StringName = &"static"
@export var cooldown: float = 1.0


func install(ctx: RunContext, owner_id: StringName) -> void:
	var ready_at: Array[float] = [0.0]
	ctx.events.player_hurt.connect(func(amount: float) -> void:
		if ctx.time < ready_at[0]:
			return
		var ally: Ally = ctx.allies.get_ally(owner_id)
		if ally == null:
			return
		ready_at[0] = ctx.time + cooldown
		var origin: Vector2 = ctx.player.global_position
		var raw: float = base_damage + amount * taken_ratio
		var statuses: Array[StatusApplication] = []
		if status_id != &"":
			var application := StatusApplication.new()
			application.status_id = status_id
			statuses.append(application)
		ctx.combat.queue(func() -> void:
			var victims: Array[Enemy] = ctx.enemies.query_radius(origin, radius)
			victims.sort_custom(func(a: Enemy, b: Enemy) -> bool:
				return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
			for i: int in mini(targets, victims.size()):
				var info: DamageInfo = ally.make_info(raw, [DamageInfo.TAG_PROC])
				info.is_proc = true
				info.statuses = statuses
				ctx.combat.deal_damage(victims[i], info)
				ctx.fx.line(origin, victims[i].global_position, Color(1.0, 0.95, 0.5), 3.0, 0.2)
			ctx.stats.add(StringName(String(owner_id) + "_retaliations"))
		)
	)
