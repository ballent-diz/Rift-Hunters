class_name RiftDirector
extends Node2D
## Mode « fermeture de failles » (docs/design/LONGEVITE.md, lot D2) : des failles réparties sur la carte crachent des
## Corrompus et des élites tant qu'elles sont ouvertes. Le Chasseur les referme en les détruisant, dans l'ordre qu'il
## veut ; quand la dernière se referme, la finale (ArenaFinale) appelle vers l'arène du boss.
## Dessine aussi le halo au sol et la jauge de chaque faille (visuels définitifs : Codex).

## Part des PV max rendue au Chasseur à chaque faille refermée.
const HEAL_RATIO := 0.15
const HALO := Color(0.62, 0.3, 1.0)

var ctx: RunContext
var rifts: Array[Enemy] = []
var closed: int = 0
## Navigation vers la faille ouverte la plus proche, puis vers l'arène (flèche de route).
var guide: FlowField
var _budget: float = 0.0
var _elite_timer: float = 0.0
var _time: float = 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	z_index = 1
	var data: EnemyData = GameDB.enemy(ctx.arena.rift_enemy_id)
	if data == null:
		push_error("Faille introuvable : %s" % ctx.arena.rift_enemy_id)
		return
	for point: Vector2 in ctx.arena.rift_points:
		rifts.append(ctx.enemies.spawn(data, point))
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	guide = FlowField.new()
	guide.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	_elite_timer = ctx.arena.rift_elite_interval * 0.5
	ctx.events.event_started.emit(TranslationServer.translate("RIFTS_INTRO") % total())


func total() -> int:
	return rifts.size()


func open_rifts() -> Array[Enemy]:
	var open: Array[Enemy] = []
	for rift: Enemy in rifts:
		if is_instance_valid(rift) and rift.alive:
			open.append(rift)
	return open


func step(delta: float) -> void:
	_time += delta
	queue_redraw()
	var open: Array[Enemy] = open_rifts()
	var wave: WavePhaseData = ctx.spawner.current_wave()
	if open.is_empty() or wave == null:
		return
	_budget = minf(_budget + ctx.arena.rift_spawn_rate * open.size() * ctx.difficulty.spawn_rate_mult * delta, 6.0)
	var alive: int = ctx.enemies.count()
	while _budget >= 1.0 and alive < ctx.spawner.current_cap():
		_budget -= 1.0
		var data: EnemyData = ctx.spawner.pick_enemy(wave)
		if data:
			ctx.enemies.spawn(data, spawn_position(open[ctx.rng.randi() % open.size()]))
			alive += 1
	_elite_timer -= delta
	if _elite_timer <= 0.0:
		_elite_timer = ctx.arena.rift_elite_interval * ctx.difficulty.elite_interval_mult
		ctx.spawner.spawn_elite(&"", spawn_position(open[ctx.rng.randi() % open.size()]))


## Point d'apparition autour d'une faille, hors du décor infranchissable.
func spawn_position(rift: Enemy) -> Vector2:
	var best: Vector2 = rift.position
	for attempt: int in 10:
		var dist: float = ctx.rng.randf_range(rift.radius + 40.0, ctx.arena.rift_spawn_radius)
		var pos: Vector2 = rift.position + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * dist
		if not ctx.obstacles.blocks(pos, SpawnDirector.SPAWN_CLEARANCE):
			return pos
		best = ctx.obstacles.push_out(pos, SpawnDirector.SPAWN_CLEARANCE)
	return best


## Position visée : la faille ouverte la plus proche, puis l'arène pendant l'appel (INF si rien à rejoindre).
func objective(pos: Vector2) -> Vector2:
	var best := Vector2.INF
	for rift: Enemy in open_rifts():
		if best == Vector2.INF or rift.position.distance_squared_to(pos) < best.distance_squared_to(pos):
			best = rift.position
	if best == Vector2.INF and ctx.finale and ctx.finale.state == ArenaFinale.State.TRAVEL:
		best = ctx.arena.finale_center
	return best


## Direction de la route vers l'objectif depuis `pos` (zéro si aucun objectif ou s'il est déjà à l'écran).
func objective_direction(pos: Vector2) -> Vector2:
	var goal: Vector2 = objective(pos)
	if goal == Vector2.INF or goal.distance_to(pos) < 380.0:
		return Vector2.ZERO
	guide.apply_walls(ctx.obstacles)
	guide.update(goal)
	return guide.direction(pos, (goal - pos).normalized())


func _on_enemy_killed(enemy: Enemy, _info: DamageInfo) -> void:
	if not rifts.has(enemy):
		return
	closed += 1
	ctx.stats.add(&"rifts_closed")
	ctx.fx.burst(enemy.position, 160.0, Color(0.75, 0.45, 1.0, 0.7))
	ctx.player.heal(ctx.player.max_hp * HEAL_RATIO)
	ctx.events.chest_collected.emit()
	Audio.play_sfx(&"evolution")
	ctx.events.event_started.emit(TranslationServer.translate("RIFT_CLOSED_BANNER") % [closed, total()])
	if closed >= total() and ctx.finale:
		ctx.finale.start_travel()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.6)
	for rift: Enemy in open_rifts():
		var center: Vector2 = rift.position
		var radius: float = rift.radius * 2.2
		draw_circle(center, radius * (1.0 + 0.08 * pulse), Color(HALO, 0.14 + 0.08 * pulse))
		draw_arc(center, radius, 0.0, TAU, 48, Color(HALO.lightened(0.3), 0.55), 2.0, true)
		# Jauge de la faille : arc qui se vide avec ses PV.
		var ratio: float = clampf(rift.hp / rift.max_hp, 0.0, 1.0)
		draw_arc(center, radius + 10.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 48, Color(1.0, 0.82, 0.45, 0.9), 4.0, true)
