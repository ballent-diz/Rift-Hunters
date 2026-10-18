class_name ArenaFinale
extends Node2D
## Finale de zone : nettoyage, appel, ouverture de faille, puis combat fermé avec les Échos.
## Deux variantes : arène murée (ArenaData.finale_walls : les barrières d'entrée apparaissent quand le Chasseur est
## dans l'arène, ses collisions délimitent le combat) ou cercle d'énergie (ArenaData.finale_radii).
enum State { WAVES, CLEARING, TRAVEL, OPENING, FIGHT, COMPLETE }
## Arène murée : distance minimale aux barrières d'entrée pour se refermer (le Chasseur n'est jamais pris dedans).
const WALL_CLEARANCE := 60.0
var ctx: RunContext
var state: State = State.WAVES
var opening_time: float = 0.0
var _wall_ids: Array[int] = []
## Arène murée : cases de navigation de l'arène (barrières fermées), pour savoir quand le Chasseur y est entré.
var _arena_labels := PackedInt32Array()

func setup(context: RunContext) -> void:
	ctx = context
	z_index = 5
	ctx.events.boss_defeated.connect(func(_boss: Enemy) -> void:
		state = State.COMPLETE
		queue_redraw())
	if ctx.arena.finale_walls.is_empty():
		return
	for rect: Rect2 in ctx.arena.finale_walls:
		_wall_ids.append(ctx.obstacles.add_wall(rect))
	if ctx.flow == null:
		ctx.flow = FlowField.new()
		ctx.flow.setup(ctx.obstacles, ctx.arena_rect(), ctx.arena.navigation_cell_size)
	ctx.flow.apply_walls(ctx.obstacles)
	var seeds: Array[Vector2] = [ctx.arena.finale_center]
	_arena_labels = ctx.flow.label_regions(seeds)
	# L'arène reste ouverte jusqu'à l'arrivée du Chasseur.
	_set_walls(false)

func walled() -> bool:
	return not _wall_ids.is_empty()

## Mode « vagues par zone » ou « failles » : tout est nettoyé ou refermé, le Chasseur rejoint l'arène.
func start_travel() -> void:
	if state == State.WAVES or state == State.CLEARING:
		state = State.TRAVEL
		ctx.events.event_started.emit(ctx.arena.finale_travel_key)


func step(delta: float) -> void:
	if state == State.WAVES and ctx.arena.zones.is_empty() and ctx.arena.rift_points.is_empty() \
			and ctx.time >= ctx.arena.boss_time:
		state = State.CLEARING
		ctx.events.event_started.emit("FINALE_CLEAR")
	if state == State.CLEARING:
		var remaining: bool = false
		for enemy: Enemy in ctx.enemies.list:
			if enemy.alive:
				remaining = true
		if not remaining:
			state = State.TRAVEL
			ctx.events.event_started.emit(ctx.arena.finale_travel_key)
	if state == State.TRAVEL and contains(ctx.player.global_position, 45.0):
		state = State.OPENING
		opening_time = 0.0
		ctx.projectiles.clear_hostile()
		ctx.hazards.clear_hostile()
		ctx.events.event_started.emit("FINALE_OPENING")
		if walled():
			_set_walls(true)
		for ally: Ally in ctx.allies.team:
			ally.global_position = constrain(ctx.player.global_position + Vector2(0, 45), Ally.BODY_RADIUS)
	elif state == State.OPENING:
		opening_time += delta
		if opening_time >= ctx.arena.finale_opening_duration:
			var data: BossData = GameDB.boss(ctx.arena.boss_id)
			if data != null:
				ctx.spawner.boss_spawned = true
				ctx.boss = ctx.enemies.spawn_boss(data, ctx.arena.finale_center)
				ctx.events.boss_spawned.emit(ctx.boss)
				state = State.FIGHT
	queue_redraw()

func closed() -> bool:
	return state == State.OPENING or state == State.FIGHT

## Dans l'arène : à l'intérieur de l'ellipse, ou (arène murée) dans sa région et à distance des barrières d'entrée.
func contains(point: Vector2, margin: float = 0.0) -> bool:
	if walled():
		if ctx.flow.region_at(_arena_labels, point) != 0:
			return false
		for rect: Rect2 in ctx.arena.finale_walls:
			if rect.grow(WALL_CLEARANCE + margin).has_point(point):
				return false
		return true
	var radii: Vector2 = ctx.arena.finale_radii - Vector2.ONE * margin
	return ((point - ctx.arena.finale_center) / radii).length_squared() <= 1.0

func constrain(point: Vector2, margin: float) -> Vector2:
	if walled():
		return point  # les collisions de l'arène et ses barrières suffisent
	var radii: Vector2 = ctx.arena.finale_radii - Vector2.ONE * (margin + 8.0)
	var local: Vector2 = (point - ctx.arena.finale_center) / radii
	return ctx.arena.finale_center + local.limit_length(1.0) * radii

func enforce_boundary() -> void:
	if not closed() or walled():
		return
	ctx.player.global_position = constrain(ctx.player.global_position, ctx.player.radius)
	for ally: Ally in ctx.allies.team:
		ally.global_position = constrain(ally.global_position, Ally.BODY_RADIUS)
	for enemy: Enemy in ctx.enemies.list:
		if enemy.alive:
			enemy.global_position = constrain(enemy.global_position, enemy.radius)

func _set_walls(enabled: bool) -> void:
	for id: int in _wall_ids:
		ctx.obstacles.set_wall_enabled(id, enabled)
		if enabled and ctx.fx:
			var rect: Rect2 = ctx.obstacles.walls[id]
			ctx.fx.burst(rect.get_center(), maxf(rect.size.x, rect.size.y) * 0.6, Color(0.75, 0.45, 1.0, 0.6))
	ctx.flow.apply_walls(ctx.obstacles)

func _draw() -> void:
	if ctx == null or state < State.TRAVEL or state == State.COMPLETE:
		return
	var center: Vector2 = ctx.arena.finale_center
	if closed() and not walled():
		var points := PackedVector2Array()
		for i: int in 97:
			points.append(center + Vector2.from_angle(TAU * i / 96.0) * ctx.arena.finale_radii)
		draw_polyline(points, Color(0.68, 0.28, 1.0, 0.6), 8.0, true)
		draw_polyline(points, Color(0.85, 0.65, 1.0), 2.0, true)
	if state != State.FIGHT:
		var radius: float = 30.0 + 55.0 * clampf(opening_time / ctx.arena.finale_opening_duration, 0.0, 1.0)
		draw_circle(center, radius, Color(0.08, 0.015, 0.16, 0.9))
		draw_arc(center, radius, 0, TAU, 64, Color(0.8, 0.35, 1.0), 4.0, true)
		draw_arc(center, radius + 8, 0, TAU, 64, Color(0.5, 0.25, 1.0, 0.6), 2.0, true)
