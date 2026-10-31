class_name AshGuardians
extends BossMechanics
## Mécaniques phares des gardiens des cartes 7 à 9 (docs/design/MONSTRES.md) :
## - Cercle du duel (Chevalier calciné, carte 7) : il trace un cercle de feu autour de lui et du Chasseur. Les Échos
##   sont repoussés dehors ; dedans, le Chevalier prend 1,5 × les coups du Chasseur ; sortir du cercle brûle.
## - Fils tendus (Reine-veuve, carte 8) : des fils de soie barrent le terrain. Les toucher colle sur place, et la
##   Reine bondit sur la proie engluée. Une Ruée à travers un fil le coupe (et libère).
## - Carapace de scories (Matrone des scories, carte 9) : tant qu'elle tient, les coups ne portent presque pas. Une
##   roche qui tombe sur la Matrone (pluie de la carte ou sa propre pluie) la fend pour quelques secondes.

const FIRE := Color(1.0, 0.45, 0.12)
const SILK := Color(0.86, 0.84, 0.8)
const SLAG := Color(0.42, 0.3, 0.24)

## Duel en cours : {"center", "radius", "until", "mult", "burn", "tick"} (vide : aucun).
var duel: Dictionary = {}
## Fils : {"a", "b", "until", "ready"} ; collé : secondes restantes sur place (le bond est déjà lancé).
var threads: Array[Dictionary] = []
var stuck_time: float = 0.0
## Carapace : active pour la Matrone ; fendue jusqu'à cracked_until.
var shell := false
var cracked_until: float = 0.0
var _thread_params: Dictionary = {}
var _shell_params: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "AshGuardians"
	ctx.combat.add_damage_modifier(_damage_modifier)


func step(delta: float) -> void:
	super.step(delta)
	_step_duel(delta)
	_step_threads(delta)
	queue_redraw()


func finish() -> void:
	duel = {}
	threads.clear()
	shell = false
	queue_redraw()


func _damage_modifier(enemy: Enemy, info: DamageInfo) -> float:
	if brain == null or enemy != boss() or not info.is_friendly():
		return 1.0
	var mult: float = 1.0
	if not duel.is_empty() and info.source_kind == DamageInfo.SourceKind.PLAYER:
		mult *= float(duel["mult"])
	if shell:
		if cracked():
			mult *= float(_shell_params.get("cracked_mult", 1.5))
		else:
			ctx.fx.spark(enemy.position, SLAG.lightened(0.3), 6.0)
			ctx.stats.add(&"boss_shell_blocked")
			mult *= float(_shell_params.get("shell_mult", 0.15))
	return mult


# --- Cercle du duel -------------------------------------------------------------------------------------------

func duel_circle(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var player: Vector2 = ctx.player.global_position
	var center: Vector2 = boss().position.lerp(player, 0.5)
	var radius: float = maxf(float(params.get("radius", 350.0)), boss().position.distance_to(player) * 0.5 + 90.0)
	ctx.fx.ring(center, radius, Color(FIRE, 0.7), pattern.telegraph)
	brain.schedule(pattern.telegraph, func() -> void:
		duel = {"center": center, "radius": radius, "until": ctx.time + float(params.get("duration", 8.0)),
			"mult": float(params.get("damage_mult", 1.5)), "burn": float(params.get("burn", 6.0)), "tick": 0.0}
		ctx.fx.burst(center, radius, Color(FIRE, 0.25))
		ctx.stats.add(&"boss_duels"))
	intro("BOSS_DUEL_INTRO")
	brain.busy_time = pattern.telegraph + 0.4


func dueling() -> bool:
	return not duel.is_empty()


func _step_duel(delta: float) -> void:
	if duel.is_empty():
		return
	if ctx.time >= float(duel["until"]):
		duel = {}
		return
	var center: Vector2 = duel["center"]
	var radius: float = duel["radius"]
	# Les Échos restent dehors ; le Chevalier reste dedans.
	if ctx.allies:
		for ally: Ally in ctx.allies.team:
			var away: Vector2 = ally.global_position - center
			if away.length() < radius + 20.0:
				ally.global_position = center + (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * (radius + 24.0)
	var from_center: Vector2 = boss().position - center
	if from_center.length() > radius - boss().radius:
		boss().position = center + from_center.normalized() * (radius - boss().radius)
	# Sortir du cercle brûle.
	duel["tick"] = float(duel["tick"]) - delta
	if ctx.player.global_position.distance_to(center) > radius and float(duel["tick"]) <= 0.0:
		duel["tick"] = 0.5
		ctx.combat.damage_player(float(duel["burn"]) * ctx.difficulty.enemy_damage_mult, brain.data.id)
		ctx.fx.spark(ctx.player.global_position, FIRE, 10.0)
		ctx.stats.add(&"boss_duel_burns")


# --- Fils tendus ----------------------------------------------------------------------------------------------

func silk_threads(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	_thread_params = params
	var count: int = int(params.get("count", 4))
	var length: float = float(params.get("length", 420.0))
	var player: Vector2 = ctx.player.global_position
	var area: Rect2 = ctx.arena_rect().grow(-60.0)
	var made: Array[Dictionary] = []
	for i: int in count * 3:
		if made.size() >= count:
			break
		var mid: Vector2 = player + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * ctx.rng.randf_range(140.0, 460.0)
		var dir: Vector2 = Vector2.RIGHT.rotated(ctx.rng.randf() * PI)
		var a: Vector2 = (mid - dir * length * 0.5).clamp(area.position, area.end)
		var b: Vector2 = (mid + dir * length * 0.5).clamp(area.position, area.end)
		# Un fil tendu au-dessus du sol praticable (pas dans la lave ni à travers un mur).
		if ctx.obstacles.distance(mid) < 20.0 or not ctx.obstacles.line_clear(a.lerp(b, 0.2), a.lerp(b, 0.8)):
			continue
		made.append({"a": a, "b": b, "until": ctx.time + pattern.telegraph + float(params.get("duration", 14.0)),
			"ready": ctx.time + pattern.telegraph})
		ctx.fx.danger_line(a, b, 10.0, pattern.telegraph)
	threads.append_array(made)
	intro("BOSS_THREADS_INTRO")
	brain.busy_time = pattern.telegraph + 0.3


static func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


func _step_threads(delta: float) -> void:
	stuck_time = maxf(stuck_time - delta, 0.0)
	if threads.is_empty():
		return
	var player: Player = ctx.player
	var pos: Vector2 = player.global_position
	var i: int = threads.size() - 1
	while i >= 0:
		var thread: Dictionary = threads[i]
		if ctx.time >= float(thread["until"]):
			threads.remove_at(i)
			i -= 1
			continue
		if ctx.time < float(thread["ready"]):
			i -= 1
			continue
		var near: bool = _distance_to_segment(pos, thread["a"], thread["b"]) < player.radius + 6.0
		if near and player.is_dashing():
			# Ruée à travers le fil (la Ruée garde sa vitesse, même engluée) : il est tranché.
			ctx.fx.debris(pos, SILK, 10)
			threads.remove_at(i)
			ctx.stats.add(&"boss_threads_cut")
		elif near and stuck_time <= 0.0:
			_stick(pos)
		i -= 1


## Proie engluée : collée sur place, puis la Reine bondit sur elle (zone d'impact annoncée).
func _stick(pos: Vector2) -> void:
	var stick: float = float(_thread_params.get("stick", 1.2))
	stuck_time = stick + 0.6
	ctx.player.hinder(stick, 0.0)
	ctx.fx.ring(pos, 40.0, Color(SILK, 0.9), stick)
	ctx.stats.add(&"boss_threads_stuck")
	var radius: float = float(_thread_params.get("pounce_radius", 120.0))
	var damage: float = float(_thread_params.get("pounce_damage", 20.0)) * ctx.difficulty.enemy_damage_mult \
		* ctx.arena.boss_damage_mult
	ctx.hazards.add_circle(pos, radius, stick, damage, true, brain.data.id)
	brain.busy_time = maxf(brain.busy_time, stick + 0.4)
	brain.schedule(stick, func() -> void:
		boss().position = ctx.obstacles.push_out(pos, boss().radius)
		ctx.fx.burst(pos, radius, Color(SILK, 0.4))
		boss().visual.play_action(&"attack"))


# --- Carapace de scories --------------------------------------------------------------------------------------

## Carapace dès l'arrivée de la Matrone ; chaque roche qui tombe sur elle la fend.
func begin_shell(params: Dictionary) -> void:
	shell = true
	_shell_params = params
	if ctx.rockfall and not ctx.rockfall.landed.is_connected(_on_rock_landed):
		ctx.rockfall.landed.connect(_on_rock_landed)
	intro("BOSS_SHELL_INTRO")


func cracked() -> bool:
	return ctx.time < cracked_until


## Pluie de scories : des roches tombent autour du Chasseur ; celles qui touchent la Matrone fendent sa carapace.
func slag_rain(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var radius: float = float(params.get("radius", 90.0))
	var player: Vector2 = ctx.player.global_position
	var area: Rect2 = ctx.arena_rect().grow(-radius)
	for i: int in int(params.get("count", 3)):
		var pos: Vector2 = player if i == 0 else player + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) \
			* ctx.rng.randf_range(120.0, 320.0)
		pos = pos.clamp(area.position, area.end)
		ctx.hazards.add_circle(pos, radius, pattern.telegraph, brain._damage(pattern), true, brain.data.id)
		brain.schedule(pattern.telegraph, func() -> void:
			ctx.fx.burst(pos, radius, Color(FIRE, 0.45))
			ctx.fx.debris(pos, SLAG, 8)
			_on_rock_landed(pos, radius))
	brain.busy_time = pattern.telegraph * 0.5


func _on_rock_landed(pos: Vector2, radius: float) -> void:
	if not shell or brain == null or not boss().alive:
		return
	if boss().position.distance_to(pos) > radius + boss().radius:
		return
	cracked_until = ctx.time + float(_shell_params.get("crack_time", 10.0))
	brain.stun(float(_shell_params.get("stun", 1.0)))
	ctx.fx.burst(boss().position, boss().radius * 2.0, Color(FIRE, 0.6))
	ctx.fx.text(boss().position + Vector2(0, -boss().radius - 34.0), tr("BOSS_SHELL_CRACKED"), FIRE)
	ctx.stats.add(&"boss_shell_cracked")


# --- Bot ------------------------------------------------------------------------------------------------------

## Fils : s'en écarter (sauf pour les trancher d'une Ruée quand il est collé).
func danger(pos: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for thread: Dictionary in threads:
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pos, thread["a"], thread["b"])
		var away: Vector2 = pos - closest
		if away.length() < 70.0:
			push += (away.normalized() if away.length() > 0.5 else Vector2.UP) * (70.0 - away.length()) / 35.0
	return push


## Duel : rester dans le cercle ; carapace intacte : rester près de la Matrone pour que les roches la touchent.
func bot_move(pos: Vector2) -> Vector2:
	if not duel.is_empty():
		var center: Vector2 = duel["center"]
		if pos.distance_to(center) > float(duel["radius"]) - 70.0:
			return (center - pos).normalized()
		return Vector2.ZERO
	if shell and not cracked() and brain != null and boss().alive and pos.distance_to(boss().position) > 260.0:
		return (boss().position - pos).normalized() * 0.6
	return Vector2.ZERO


## Collé à un fil : la Ruée tranche et libère.
func bot_dash() -> bool:
	return stuck_time > 0.0 and ctx.player.is_hindered()


# --- Dessin ---------------------------------------------------------------------------------------------------

func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	if not duel.is_empty():
		var center: Vector2 = duel["center"]
		var radius: float = duel["radius"]
		draw_circle(center, radius, Color(FIRE, 0.05))
		draw_arc(center, radius, 0.0, TAU, 96, Color(FIRE, 0.65 + 0.3 * pulse), 6.0)
		draw_arc(center, radius + 10.0, 0.0, TAU, 96, Color(FIRE, 0.2), 10.0)
	for thread: Dictionary in threads:
		var ready: bool = ctx.time >= float(thread["ready"])
		draw_line(thread["a"], thread["b"], Color(SILK, 0.85 if ready else 0.35), 3.0 if ready else 1.5)
		draw_circle(thread["a"], 5.0, Color(SILK, 0.8))
		draw_circle(thread["b"], 5.0, Color(SILK, 0.8))
	if shell and brain != null and boss().alive:
		var b: Enemy = boss()
		if cracked():
			for k: int in 5:
				var angle: float = TAU * k / 5.0 + 0.4
				draw_line(b.position, b.position + Vector2.RIGHT.rotated(angle) * b.radius * 1.3, Color(FIRE, 0.8), 3.0)
		else:
			draw_arc(b.position, b.radius * 1.25, 0.0, TAU, 40, Color(SLAG.lightened(0.2), 0.75), 7.0)
			draw_arc(b.position, b.radius * 1.25, 0.0, TAU, 40, Color(FIRE, 0.15 + 0.15 * pulse), 2.0)
