class_name HunterTalentEffect
extends GameplayEffect
## Passifs transformants et clés de voûte de l'arbre du Chasseur (docs/design/ARBRE_DU_CHASSEUR.md).
## `talent` choisit le comportement ; l'état de partie vit dans les closures créées par install().

@export var talent: StringName = &""
## Dégâts de base des talents qui en infligent (multipliés par les dégâts du Chasseur).
@export var damage: float = 18.0


func install(ctx: RunContext, _owner_id: StringName) -> void:
	match talent:
		&"slicing_dash":
			ctx.events.player_dashed.connect(func(from: Vector2, to: Vector2) -> void: _slicing_dash(ctx, from, to))
		&"counter_cut":
			ctx.events.player_dodged.connect(func() -> void:
				if ctx.spells:
					ctx.spells.world.empower_blade())
		&"propagation":
			ctx.events.enemy_killed.connect(func(enemy: Enemy, _info: DamageInfo) -> void: _propagate(ctx, enemy))
		&"split_bolt":
			ctx.events.enemy_damaged.connect(func(enemy: Enemy, info: DamageInfo, _amount: float) -> void:
				_split_bolt(ctx, enemy, info))
		&"void_wake":
			ctx.events.player_dashed.connect(func(from: Vector2, to: Vector2) -> void: _void_wake(ctx, from, to))
		&"anchor":
			ctx.events.enemy_killed.connect(func(enemy: Enemy, _info: DamageInfo) -> void: _anchor(ctx, enemy))
		&"close_guard":
			var guard := {"ready": 0.0}
			ctx.events.player_hurt.connect(func(_amount: float) -> void: _close_guard(ctx, guard))
		&"fusion":
			var fusion := {"until": -1.0}
			ctx.events.spell_cast.connect(func(id: StringName) -> void:
				if _path(id) == &"bond":
					fusion["until"] = ctx.time + 4.0)
			ctx.events.enemy_damaged.connect(func(enemy: Enemy, info: DamageInfo, _amount: float) -> void:
				_fusion(ctx, enemy, info, fusion))
		&"blade_master":
			ctx.events.spell_cast.connect(func(id: StringName) -> void: _blade_master(ctx, id))
		&"living_prism":
			var shots := {"count": 0}
			ctx.events.enemy_damaged.connect(func(enemy: Enemy, info: DamageInfo, _amount: float) -> void:
				_living_prism(ctx, enemy, info, shots))
		&"void_master":
			ctx.combat.add_damage_modifier(func(enemy: Enemy, info: DamageInfo) -> float:
				var held: bool = enemy.statuses.get_stacks(&"root") > 0 or enemy.statuses.get_stacks(&"slow") > 0
				return 1.25 if held and info.is_friendly() else 1.0)
		&"pack_soul":
			ctx.events.spell_cast.connect(func(_id: StringName) -> void:
				for ally: Ally in ctx.allies.team:
					ally.technique_cd = maxf(ally.technique_cd - 1.0, 0.0))
		_:
			push_error("Talent inconnu : %s" % talent)


static func _path(spell_id: StringName) -> StringName:
	var spell: SpellData = GameDB.spells.get(spell_id)
	return spell.path if spell else &""


func _hit(ctx: RunContext, enemy: Enemy, amount_mult: float, statuses: Array[StatusApplication] = []) -> void:
	var tags: Array[StringName] = [DamageInfo.TAG_PROC]
	var info := DamageInfo.make(damage * amount_mult * ctx.player.stats.get_value(StatKeys.DAMAGE),
		DamageInfo.SourceKind.PLAYER, &"player", tags)
	info.is_proc = true
	info.statuses = statuses
	ctx.combat.deal_damage(enemy, info)


static func _status(id: StringName) -> Array[StatusApplication]:
	var application := StatusApplication.new()
	application.status_id = id
	application.stacks = 1
	var list: Array[StatusApplication] = [application]
	return list


## Ruée tranchante : la Ruée blesse les ennemis traversés.
func _slicing_dash(ctx: RunContext, from: Vector2, to: Vector2) -> void:
	var middle: Vector2 = (from + to) * 0.5
	for enemy: Enemy in ctx.enemies.query_radius(middle, from.distance_to(to) * 0.5 + 30.0):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
		if closest.distance_to(enemy.global_position) <= 30.0 + enemy.radius:
			_hit(ctx, enemy, 1.0)
	ctx.fx.line(from, to, Color(1.0, 0.75, 0.5), 6.0, 0.2)


## Propagation : les Marques d'un ennemi qui meurt passent à l'ennemi le plus proche.
static func _propagate(ctx: RunContext, enemy: Enemy) -> void:
	var stacks: int = enemy.statuses.get_stacks(&"mark")
	if stacks <= 0:
		return
	var next: Enemy = ctx.enemies.find_nearest(enemy.global_position, 160.0, {enemy.get_instance_id(): true})
	if next:
		ctx.status_system.apply(next, &"mark", stacks, &"player")
		ctx.fx.line(enemy.global_position, next.global_position, Color(0.6, 0.95, 1.0), 2.0, 0.2)


## Trait scindé : un Trait qui touche un ennemi marqué se divise en 2.
func _split_bolt(ctx: RunContext, enemy: Enemy, info: DamageInfo) -> void:
	if info.is_proc or not info.has_tag(DamageInfo.TAG_BOLT) or enemy.statuses.get_stacks(&"mark") <= 0:
		return
	var base: Vector2 = info.direction if info.direction != Vector2.ZERO else Vector2.RIGHT
	for angle: float in [-0.6, 0.6]:
		var shard: DamageInfo = info.duplicate_info()
		shard.amount *= 0.5
		shard.is_proc = true
		shard.statuses = []
		var p: Projectile = ctx.projectiles.spawn_friendly(enemy.global_position, base.rotated(angle), 520.0, shard,
			{"radius": 5.0, "life": 0.6, "color": Color(0.7, 0.95, 1.0)})
		p.hit_ids[enemy.get_instance_id()] = true


## Sillage du vide : la Ruée laisse une traînée qui Entrave.
static func _void_wake(ctx: RunContext, from: Vector2, to: Vector2) -> void:
	for t: float in [0.0, 0.5, 1.0]:
		ctx.hazards.add_zone(from.lerp(to, t), 40.0, 2.0, 1.0, &"player", _status(&"slow"), Color(0.6, 0.4, 1.0))


## Ancre : un ennemi tué sous Racines s'effondre en petite Singularité.
func _anchor(ctx: RunContext, enemy: Enemy) -> void:
	if enemy.statuses.get_stacks(&"root") <= 0:
		return
	var tags: Array[StringName] = [DamageInfo.TAG_PROC]
	var info := DamageInfo.make(damage * ctx.player.stats.get_value(StatKeys.DAMAGE), DamageInfo.SourceKind.PLAYER,
		&"player", tags)
	info.is_proc = true
	ctx.hazards.add_well(enemy.global_position, 90.0, 1.2, 200.0, info, &"player")


## Garde rapprochée : quand le Chasseur est touché, l'Écho le plus proche bondit sur l'ennemi le plus proche.
func _close_guard(ctx: RunContext, guard: Dictionary) -> void:
	if ctx.time < float(guard["ready"]) or ctx.allies.team.is_empty():
		return
	var pos: Vector2 = ctx.player.global_position
	var target: Enemy = ctx.enemies.find_nearest(pos, 220.0)
	if target == null:
		return
	var ally: Ally = ctx.allies.team[0]
	for candidate: Ally in ctx.allies.team:
		if candidate.global_position.distance_to(pos) < ally.global_position.distance_to(pos):
			ally = candidate
	guard["ready"] = ctx.time + 3.0
	ctx.fx.line(ally.global_position, target.global_position, Color(0.55, 1.0, 0.6), 3.0, 0.25)
	ally.global_position = target.global_position + (pos - target.global_position).normalized() * 24.0
	var tags: Array[StringName] = [DamageInfo.TAG_PROC]
	var info: DamageInfo = ally.make_info(damage * 1.5, tags)
	info.is_proc = true
	ctx.combat.deal_damage(target, info)


## Fusion : après un sort de Lien, les attaques des Échos posent Marque et Fracture (35 % chacune).
static func _fusion(ctx: RunContext, enemy: Enemy, info: DamageInfo, fusion: Dictionary) -> void:
	if ctx.time >= float(fusion["until"]) or info.is_proc or info.source_kind != DamageInfo.SourceKind.ALLY:
		return
	if not enemy.is_alive():
		return
	if ctx.rng.randf() < 0.35:
		ctx.status_system.apply(enemy, &"mark", 1, info.source_id)
	if ctx.rng.randf() < 0.35:
		ctx.status_system.apply(enemy, &"fracture", 1, info.source_id)


## Maître-lame : chaque sort de Lame réduit de 1 s la recharge des autres sorts.
static func _blade_master(ctx: RunContext, spell_id: StringName) -> void:
	if _path(spell_id) != &"blade" or ctx.spells == null:
		return
	for i: int in ctx.spells.slots.size():
		var spell: SpellData = ctx.spells.slots[i]
		if spell and spell.id != spell_id:
			ctx.spells.cooldowns[i] = maxf(ctx.spells.cooldowns[i] - 1.0, 0.0)


## Prisme vivant : un Trait sur 3 pose une Marque.
static func _living_prism(ctx: RunContext, enemy: Enemy, info: DamageInfo, shots: Dictionary) -> void:
	if info.is_proc or not info.has_tag(DamageInfo.TAG_BOLT) or not enemy.is_alive():
		return
	shots["count"] = int(shots["count"]) + 1
	if int(shots["count"]) % 3 == 0:
		ctx.status_system.apply(enemy, &"mark", 1, &"player")
