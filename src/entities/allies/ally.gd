class_name Ally
extends Node2D
## Écho allié (invulnérable dans le prototype). Données : MonsterData. Comportement : AllyBehavior.

## Rayon du corps pour contourner les obstacles du décor.
const BODY_RADIUS := 13.0
## Au-delà de cette distance de son point de formation, l'Écho suit la carte de flux.
const FLOW_MIN_DISTANCE := 120.0

var ctx: RunContext
var data: MonsterData
var rank: int = 1
var evolution: EvolutionData
var variant: EvolutionData
var stats := StatSheet.new()
var attack: AttackData
var technique: TechniqueData
var behavior: AllyBehavior
var affinities: Array[StringName] = []
var slot_index: int = 0
var attack_cd: float = 0.5
var technique_cd: float = 0.0
## Sort choisi dans l'arbre de l'Écho : une évolution ne le remplace pas.
var technique_locked: bool = false
var velocity := Vector2.ZERO
## Mémoire du comportement (état, cible, minuteries).
var memory: Dictionary = {}
var visual: EntityVisual
var _mult_damage: float = 1.0
var _mult_speed: float = 1.0
var _mult_range: float = 1.0
var _stuck_time: float = 0.0


func setup(p_ctx: RunContext, p_data: MonsterData, p_rank: int) -> void:
	ctx = p_ctx
	data = p_data
	rank = p_rank
	stats.set_base(StatKeys.DAMAGE, 1.0)
	stats.set_base(StatKeys.ATTACK_SPEED, 1.0)
	stats.set_base(StatKeys.ALLY_RANGE, 1.0)
	stats.set_base(StatKeys.TECHNIQUE_COOLDOWN, 1.0)
	affinities = data.affinities.duplicate()
	attack = data.attack
	technique = data.technique
	behavior = AllyBehaviors.create(data.behavior_id)
	visual = EntityVisual.new()
	add_child(visual)
	_refresh_visual()
	z_index = 3


func apply_modifier(evo: EvolutionData) -> void:
	if evo.behavior_id != &"":
		behavior = AllyBehaviors.create(evo.behavior_id)
		memory.clear()
	if evo.attack:
		attack = evo.attack
	if evo.technique and not technique_locked:
		technique = evo.technique
	_mult_damage *= evo.damage_mult
	_mult_speed *= evo.attack_speed_mult
	_mult_range *= evo.range_mult
	for affinity: StringName in evo.added_affinities:
		if not affinities.has(affinity):
			affinities.append(affinity)
	for effect: GameplayEffect in evo.effects:
		effect.install(ctx, data.id)
	_refresh_visual()


func _refresh_visual() -> void:
	var visual_data: VisualData = data.visual
	if evolution and evolution.visual:
		visual_data = evolution.visual
		# Évolution sans feuille de sprites mais forme de base dessinée : sprite de base teinté.
		if not Assets.has_sheet(evolution.visual.visual_id) and Assets.has_sheet(data.visual.visual_id):
			visual.setup(data.visual, evolution.visual.primary)
			return
	var palette: Array = ctx.setup.palettes.get(data.id, [])
	if palette.size() == 2 and evolution == null:
		visual.setup(visual_data, palette[0], palette[1])
	else:
		visual.setup(visual_data)


func damage_mult() -> float:
	var rank_bonus: float = 1.0 + ctx.balance.ally_rank_damage_bonus * (rank - 1)
	return stats.get_value(StatKeys.DAMAGE) * ctx.player.stats.get_value(StatKeys.ALLY_DAMAGE) * rank_bonus * _mult_damage


func attack_speed_mult() -> float:
	return stats.get_value(StatKeys.ATTACK_SPEED) * ctx.player.stats.get_value(StatKeys.ALLY_ATTACK_SPEED) * _mult_speed


func attack_range() -> float:
	return attack.attack_range * stats.get_value(StatKeys.ALLY_RANGE) * _mult_range


func technique_cooldown() -> float:
	if technique == null:
		return 0.0
	return technique.cooldown * ctx.player.stats.get_value(StatKeys.TECHNIQUE_COOLDOWN) \
		* maxf(stats.get_value(StatKeys.TECHNIQUE_COOLDOWN), 0.2)


func make_info(amount: float, tags: Array[StringName]) -> DamageInfo:
	var info := DamageInfo.make(amount * damage_mult(), DamageInfo.SourceKind.ALLY, data.id, tags)
	return info


func display_name() -> String:
	return tr(evolution.name_key) if evolution else tr(data.name_key)


## Position de formation autour du Chasseur.
func follow_point() -> Vector2:
	var angle: float = PI * 0.75 + slot_index * TAU / 3.0
	return ctx.player.global_position + Vector2.RIGHT.rotated(angle) * ctx.balance.ally_follow_distance


func move_toward_point(target: Vector2, speed: float, delta: float) -> void:
	# Point visé dans le décor (Chasseur collé à un rocher) : ramené sur le praticable.
	target = ctx.obstacles.push_out(target, BODY_RADIUS)
	var offset: Vector2 = target - global_position
	if offset.length() < 4.0:
		velocity = Vector2.ZERO
		_stuck_time = 0.0
		return
	var heading: Vector2 = offset.normalized()
	# Rejoindre le Chasseur de loin : par les routes (carte de flux), pas à travers le décor.
	if ctx.flow != null and offset.length() > FLOW_MIN_DISTANCE \
			and target.distance_to(ctx.player.global_position) < ctx.balance.ally_follow_distance * 2.0:
		heading = ctx.flow.direction(global_position, heading)
	var wanted: Vector2 = heading * minf(speed, offset.length() / maxf(delta, 0.001))
	var before: Vector2 = global_position
	global_position = ctx.obstacles.push_out(global_position + wanted * delta, BODY_RADIUS)
	velocity = (global_position - before) / maxf(delta, 0.001)
	_check_stuck(wanted, delta)


## Écho coincé derrière un obstacle ou trop loin : il rejoint le Chasseur par un saut de faille.
func _check_stuck(wanted: Vector2, delta: float) -> void:
	var progress: float = velocity.dot(wanted.normalized())
	if progress < wanted.length() * 0.3:
		_stuck_time += delta
	else:
		_stuck_time = maxf(_stuck_time - delta, 0.0)
	var far: bool = global_position.distance_to(ctx.player.global_position) > ctx.balance.ally_leash_distance
	if _stuck_time >= ctx.balance.ally_stuck_time or far:
		blink_to_player()


func blink_to_player() -> void:
	var to: Vector2 = ctx.obstacles.push_out(follow_point(), BODY_RADIUS)
	if ctx.obstacles.blocks(to, BODY_RADIUS):
		to = ctx.player.global_position
	if ctx.fx:
		ctx.fx.ring(global_position, 22.0, Color(0.75, 0.45, 1.0, 0.9), 0.35)
		ctx.fx.ring(to, 22.0, Color(0.75, 0.45, 1.0, 0.9), 0.35)
	global_position = to
	velocity = Vector2.ZERO
	_stuck_time = 0.0
