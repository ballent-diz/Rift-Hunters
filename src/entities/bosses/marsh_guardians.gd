class_name MarshGuardians
extends BossMechanics
## Mécaniques phares des gardiens des cartes 11 et 12 (docs/design/MONSTRES.md) :
## - Garde d'écorce (Gardien d'écorce, carte 11) : il s'enracine et lève son bouclier d'écorce. Il pivote lentement
##   vers le Chasseur ; de face, les coups ne portent presque pas ; de dos ou de flanc, ils portent davantage. Les
##   Échos qui l'occupent ou une Ruée dans son dos ouvrent la voie ; ses racines entravent pour garder la proie en face.
## - Plongée (Gueule des marais, carte 12) : elle plonge, intouchable ; une ride la trahit et suit le Chasseur.
##   Elle s'arrête, l'onde est annoncée, puis elle ressurgit : onde de choc, et elle reste sonnée et vulnérable.

const BARK := Color(0.55, 0.42, 0.26)
const WATER := Color(0.3, 0.75, 0.72)

## Garde en cours : {"until", "facing", "turn", "front", "back"} (vide : aucune).
var guard: Dictionary = {}
## Plongée en cours : {"pos", "speed", "chase_until", "surface_at", "radius", "damage", "stun"} (vide : aucune).
var dive: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "MarshGuardians"
	ctx.combat.add_damage_modifier(_damage_modifier)


func step(delta: float) -> void:
	super.step(delta)
	_step_guard(delta)
	_step_dive(delta)
	queue_redraw()


func finish() -> void:
	guard = {}
	_end_dive()
	queue_redraw()


func _damage_modifier(enemy: Enemy, info: DamageInfo) -> float:
	if brain == null or enemy != boss() or not info.is_friendly():
		return 1.0
	if not dive.is_empty():
		return 0.0
	if guard.is_empty():
		return 1.0
	if from_front(source_position(info)):
		ctx.fx.spark(enemy.position, BARK.lightened(0.3), 6.0)
		ctx.stats.add(&"boss_guard_blocked")
		return float(guard["front"])
	ctx.stats.add(&"boss_guard_flanked")
	return float(guard["back"])


# --- Garde d'écorce -------------------------------------------------------------------------------------------

func bark_guard(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var duration: float = float(params.get("duration", 7.0))
	guard = {"until": ctx.time + pattern.telegraph + duration,
		"facing": (ctx.player.global_position - boss().position).normalized(),
		"turn": float(params.get("turn_speed", 0.9)), "front": float(params.get("front_mult", 0.1)),
		"back": float(params.get("back_mult", 1.5))}
	ctx.fx.ring(boss().position, boss().radius * 1.8, Color(BARK, 0.8), pattern.telegraph)
	intro("BOSS_GUARD_INTRO")
	ctx.stats.add(&"boss_guards")
	# Planté sur place pendant toute la garde ; les racines partent en cours de garde (motif root_snare).
	brain.busy_time = pattern.telegraph + duration


func guarding() -> bool:
	return not guard.is_empty()


## Coup venu de face (dans le demi-cercle avant du bouclier) ?
func from_front(source: Vector2) -> bool:
	if guard.is_empty():
		return false
	var to_source: Vector2 = (source - boss().position).normalized()
	return to_source.dot(guard["facing"]) > 0.25


func _step_guard(delta: float) -> void:
	if guard.is_empty():
		return
	if ctx.time >= float(guard["until"]):
		guard = {}
		return
	# Le bouclier pivote lentement vers le Chasseur : le contourner, ou le laisser occupé par les Échos.
	var facing: Vector2 = guard["facing"]
	var wanted: Vector2 = (ctx.player.global_position - boss().position).normalized()
	var angle: float = facing.angle_to(wanted)
	var step: float = float(guard["turn"]) * delta
	guard["facing"] = facing.rotated(clampf(angle, -step, step))
	boss().visual.set_facing_left((guard["facing"] as Vector2).x < 0.0, true)


## Racines entravantes : un cercle de racines sous le Chasseur, qui l'entrave s'il y reste.
func root_snare(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var pos: Vector2 = ctx.player.global_position
	var radius: float = float(params.get("radius", 110.0))
	ctx.hazards.add_circle(pos, radius, pattern.telegraph, brain._damage(pattern), true, brain.data.id)
	brain.schedule(pattern.telegraph, func() -> void:
		ctx.fx.debris(pos, BARK, 10)
		if ctx.player.global_position.distance_to(pos) <= radius + ctx.player.radius:
			ctx.player.hinder(float(params.get("hinder", 1.5)), float(params.get("hinder_mult", 0.25)))
			ctx.stats.add(&"boss_roots_caught"))
	if guard.is_empty():
		brain.busy_time = pattern.telegraph * 0.5


# --- Plongée --------------------------------------------------------------------------------------------------

func maw_dive(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var chase: float = float(params.get("chase", 2.5))
	var warning: float = float(params.get("warning", 0.9))
	dive = {"pos": boss().position, "speed": float(params.get("speed", 230.0)), "chase_until": ctx.time + chase,
		"surface_at": ctx.time + chase + warning, "warning": warning, "radius": float(params.get("radius", 150.0)),
		"damage": brain._damage(pattern), "stun": float(params.get("stun", 2.0)), "warned": false}
	boss().visual.play_action(&"dive")
	boss().visual.visible = false
	boss().invulnerable_time = chase + warning + 0.1
	ctx.fx.burst(boss().position, boss().radius * 1.5, Color(WATER, 0.5))
	intro("BOSS_DIVE_INTRO")
	ctx.stats.add(&"boss_dives")
	brain.busy_time = chase + warning + float(params.get("stun", 2.0)) + 0.2


func diving() -> bool:
	return not dive.is_empty()


func _step_dive(delta: float) -> void:
	if dive.is_empty():
		return
	var pos: Vector2 = dive["pos"]
	# Sous la surface, pas de coup au contact.
	boss().touch_cooldown = maxf(boss().touch_cooldown, 0.3)
	if ctx.time < float(dive["chase_until"]):
		# La ride suit le Chasseur sous la surface.
		var to_player: Vector2 = ctx.player.global_position - pos
		pos += to_player.limit_length(float(dive["speed"]) * delta)
		dive["pos"] = ctx.obstacles.push_out(pos, 20.0)
		boss().position = dive["pos"]
		return
	if not dive["warned"]:
		dive["warned"] = true
		ctx.hazards.add_circle(pos, float(dive["radius"]), float(dive["warning"]), float(dive["damage"]), true,
			brain.data.id)
	if ctx.time >= float(dive["surface_at"]):
		var stun: float = dive["stun"]
		var radius: float = dive["radius"]
		_end_dive()
		ctx.fx.burst(pos, radius, Color(WATER, 0.6))
		ctx.fx.debris(pos, WATER, 14)
		# Sortie de plongée : sonnée et vulnérable un instant.
		brain.stun(stun)
		brain.heart_time = stun
		ctx.stats.add(&"boss_dive_surfaced")


func _end_dive() -> void:
	if dive.is_empty():
		return
	dive = {}
	if brain != null and boss() != null:
		boss().visual.visible = true
		boss().invulnerable_time = 0.0


# --- Bot ------------------------------------------------------------------------------------------------------

## Garde : contourner le bouclier (se placer dans le dos du Gardien).
func bot_move(pos: Vector2) -> Vector2:
	if guard.is_empty() or brain == null or not boss().alive:
		return Vector2.ZERO
	var behind: Vector2 = boss().position - (guard["facing"] as Vector2) * 230.0
	if pos.distance_to(behind) < 90.0:
		return Vector2.ZERO
	return (behind - pos).normalized()


# --- Dessin ---------------------------------------------------------------------------------------------------

func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	if not guard.is_empty() and brain != null and boss().alive:
		var facing: Vector2 = guard["facing"]
		var center: Vector2 = boss().position
		draw_arc(center, boss().radius * 1.5, facing.angle() - 1.3, facing.angle() + 1.3, 24,
			Color(BARK.lightened(0.15), 0.85), 9.0)
		draw_arc(center, boss().radius * 1.5, facing.angle() + 1.3, facing.angle() + TAU - 1.3, 24,
			Color(1.0, 0.85, 0.5, 0.25 + 0.2 * pulse), 2.0)
	if not dive.is_empty():
		var pos: Vector2 = dive["pos"]
		for k: int in 3:
			var r: float = 24.0 + 18.0 * k + 10.0 * pulse
			draw_arc(pos, r, 0.0, TAU, 28, Color(WATER, 0.55 - 0.15 * k), 2.5)
