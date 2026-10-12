class_name Player
extends Combatant
## Le Chasseur : déplacement, Ruée, arme automatique (Trait de Faille), XP et niveaux.

var ctx: RunContext
var stats := StatSheet.new()
var brain: PlayerBrain
var velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var level: int = 1
var xp: float = 0.0
var pending_levels: int = 0
var shield: float = 0.0
var dash_cooldown_left: float = 0.0
var last_breaths_used: int = 0
## Intensité du retour visuel de dégâts (vignette), décroît dans le HUD.
var hurt_flash: float = 0.0
## Mode test : ne subit aucun dégât.
var god_mode: bool = false
var _iframes: float = 0.0
var _dash_time: float = 0.0
var _dash_dir := Vector2.ZERO
var _dash_from := Vector2.ZERO
var _bolt_timer: float = 0.0
var _redraw_state: int = -1


func setup(p_ctx: RunContext, p_brain: PlayerBrain) -> void:
	ctx = p_ctx
	brain = p_brain
	brain.ctx = ctx
	var b: BalanceConfig = ctx.balance
	var defaults := {
		StatKeys.MAX_HP: b.player_max_hp, StatKeys.REGEN: b.player_regen,
		StatKeys.MOVE_SPEED: b.player_move_speed, StatKeys.PICKUP_RADIUS: b.pickup_radius,
		StatKeys.DAMAGE: 1.0, StatKeys.ATTACK_SPEED: 1.0,
		StatKeys.PROJECTILE_COUNT: float(b.bolt.projectile_count), StatKeys.PIERCE: float(b.bolt.pierce),
		StatKeys.BOLT_SPLIT: float(b.bolt.split), StatKeys.BOLT_RANGE: b.bolt.attack_range,
		StatKeys.DASH_COOLDOWN: b.dash_cooldown, StatKeys.DASH_IFRAMES: b.dash_iframes,
		StatKeys.DAMAGE_TAKEN: 1.0, StatKeys.ELITE_DAMAGE: 1.0, StatKeys.LAST_BREATH: 0.0,
		StatKeys.ALLY_DAMAGE: 1.0, StatKeys.ALLY_ATTACK_SPEED: 1.0, StatKeys.TECHNIQUE_COOLDOWN: 1.0,
		StatKeys.TEAM_SLOTS: float(b.base_team_slots), StatKeys.RECRUIT_RANK: 1.0, StatKeys.EVOLUTION_RANK: 3.0,
		StatKeys.MARK_MAX_STACKS: 0.0, StatKeys.MARK_DURATION: 0.0,
		StatKeys.FRACTURE_DURATION: 0.0, StatKeys.FRACTURE_AMP: 0.0, StatKeys.BURN_DPS: 1.0,
		StatKeys.WELL_RADIUS: 1.0, StatKeys.WELL_DURATION: 0.0, StatKeys.WELL_PULL: 1.0,
		StatKeys.XP_GAIN: 1.0, StatKeys.SHARD_GAIN: 1.0, StatKeys.ESSENCE_GAIN: 0.0,
		StatKeys.REROLLS: 0.0, StatKeys.BANISHES: 0.0, StatKeys.UPGRADE_CHOICES: float(b.upgrade_choices),
		StatKeys.RELIC_CHOICES: float(b.relic_choices), StatKeys.MUTATION_WEIGHT: 1.0,
		StatKeys.STARTING_RELIC_CHOICE: 0.0, StatKeys.HEALING: 1.0,
	}
	for key: StringName in defaults:
		stats.set_base(key, float(defaults[key]))
	max_hp = stats.get_value(StatKeys.MAX_HP)
	hp = max_hp
	radius = b.player_radius
	stats.changed.connect(_on_stat_changed)
	visual = EntityVisual.new()
	add_child(visual)
	if b.player_visual:
		visual.setup(b.player_visual)


func _on_stat_changed(key: StringName) -> void:
	if key != StatKeys.MAX_HP:
		return
	var new_max: float = maxf(stats.get_value(StatKeys.MAX_HP), 1.0)
	var diff: float = new_max - max_hp
	max_hp = new_max
	if diff > 0.0:
		hp += diff
	hp = minf(hp, max_hp)


func is_dashing() -> bool:
	return _dash_time > 0.0


func can_be_hurt() -> bool:
	return alive and _iframes <= 0.0 and _dash_time <= 0.0 and not god_mode


func step(delta: float) -> void:
	if not alive:
		return
	_iframes = maxf(_iframes - delta, 0.0)
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	var regen: float = stats.get_value(StatKeys.REGEN)
	if regen > 0.0:
		heal(regen * delta, false)
	var move: Vector2 = brain.move_vector()
	if _dash_time > 0.0:
		_dash_time -= delta
		position += _dash_dir * (ctx.balance.dash_distance / ctx.balance.dash_duration) * delta
		if _dash_time <= 0.0:
			ctx.events.player_dashed.emit(_dash_from, global_position)
	else:
		velocity = move * stats.get_value(StatKeys.MOVE_SPEED) * statuses.speed_mult()
		position += velocity * delta
		if brain.wants_dash() and dash_cooldown_left <= 0.0:
			_start_dash(move)
	if move.length() > 0.1:
		facing = move.normalized()
	_constrain()
	visual.set_facing_left(facing.x < -0.1)
	visual.tick(delta, velocity.length() > 5.0)
	visual.modulate.a = 0.45 if (_iframes > 0.0 and int(_iframes * 20.0) % 2 == 0) else 1.0
	_update_weapon(delta)
	var state: int = int(shield > 0.0) + int(is_dashing()) * 2
	if state != _redraw_state:
		_redraw_state = state
		queue_redraw()


func _start_dash(move: Vector2) -> void:
	_dash_dir = move.normalized() if move.length() > 0.1 else facing
	_dash_time = ctx.balance.dash_duration
	_dash_from = global_position
	_iframes = maxf(_iframes, stats.get_value(StatKeys.DASH_IFRAMES))
	dash_cooldown_left = maxf(stats.get_value(StatKeys.DASH_COOLDOWN), 0.4)
	ctx.stats.add(&"dashes")
	ctx.fx.ring(global_position, 18.0, Color(0.6, 0.95, 1.0, 0.6), 0.2)
	visual.play_action(&"dash")


func _constrain() -> void:
	var rect: Rect2 = ctx.arena_rect().grow(-radius)
	position = ctx.obstacles.push_out(position, radius).clamp(rect.position, rect.end)
	for obstacle: Enemy in ctx.enemies.obstacles:
		var offset: Vector2 = position - obstacle.position
		var min_dist: float = radius + obstacle.radius
		if offset.length_squared() < min_dist * min_dist:
			position = obstacle.position + offset.normalized() * min_dist


func _update_weapon(delta: float) -> void:
	_bolt_timer -= delta * stats.get_value(StatKeys.ATTACK_SPEED)
	if _bolt_timer > 0.0:
		return
	var bolt: AttackData = ctx.balance.bolt
	var target: Enemy = ctx.enemies.find_nearest(global_position, stats.get_value(StatKeys.BOLT_RANGE))
	if target == null:
		_bolt_timer = 0.0
		return
	_bolt_timer = bolt.cooldown
	Audio.play_sfx(&"bolt_fire")
	var count: int = maxi(stats.get_int(StatKeys.PROJECTILE_COUNT), 1)
	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	var spread: float = deg_to_rad(10.0)
	for i: int in count:
		var angle: float = (i - (count - 1) * 0.5) * spread
		var tags: Array[StringName] = [DamageInfo.TAG_BOLT, DamageInfo.TAG_ATTACK]
		var info := DamageInfo.make(bolt.damage * stats.get_value(StatKeys.DAMAGE), DamageInfo.SourceKind.PLAYER, &"player", tags)
		info.knockback = bolt.knockback
		info.statuses = bolt.statuses
		ctx.projectiles.spawn_friendly(global_position, base_dir.rotated(angle), bolt.projectile_speed, info, {
			"pierce": stats.get_int(StatKeys.PIERCE),
			"split": stats.get_int(StatKeys.BOLT_SPLIT),
			"radius": 6.0,
			"life": 1.4,
			"color": Color(0.75, 0.95, 1.0),
		})


func receive_damage(amount: float) -> void:
	var rest: float = amount
	if shield > 0.0:
		var absorbed: float = minf(shield, rest)
		shield -= absorbed
		rest -= absorbed
	hp -= rest
	_iframes = ctx.balance.hurt_iframes
	hurt_flash = 1.0
	visual.flash()
	visual.play_action(&"hurt")
	if hp <= 0.0:
		if last_breaths_used < stats.get_int(StatKeys.LAST_BREATH):
			last_breaths_used += 1
			hp = 1.0
			_iframes = 2.0
			ctx.fx.burst(global_position, 90.0, Color(1.0, 1.0, 1.0, 0.5))
			ctx.stats.add(&"last_breath_used")
		else:
			hp = 0.0
			alive = false
			visual.play_action(&"death")


func heal(amount: float, show: bool = true) -> void:
	if not alive or amount <= 0.0:
		return
	var before: float = hp
	hp = minf(max_hp, hp + amount * maxf(stats.get_value(StatKeys.HEALING), 0.0))
	ctx.stats.add(&"healed", hp - before)
	if show and hp - before >= 1.0:
		ctx.fx.text(global_position + Vector2(0, -24), "+%d" % int(hp - before), Color(0.5, 1.0, 0.6))


func add_shield(amount: float, cap: float) -> void:
	shield = minf(cap, shield + amount)


func gain_xp(amount: float) -> void:
	xp += amount * stats.get_value(StatKeys.XP_GAIN)
	var needed: int = ctx.balance.xp_to_next(level)
	while xp >= needed:
		xp -= needed
		level += 1
		pending_levels += 1
		ctx.stats.set_max(&"max_level", level)
		ctx.events.level_up.emit(level)
		needed = ctx.balance.xp_to_next(level)


func xp_ratio() -> float:
	return xp / float(ctx.balance.xp_to_next(level))


func _draw() -> void:
	# Pas d'anneau sous le Chasseur (demande du propriétaire) : seul le bouclier est dessiné, centré sur le corps.
	var body := Vector2(0, -14) if visual != null and visual.has_sheet() else Vector2.ZERO
	if shield > 0.0:
		draw_arc(body, radius + 12.0, 0.0, TAU, 32, Color(1.0, 0.95, 0.6, 0.8), 2.5)
