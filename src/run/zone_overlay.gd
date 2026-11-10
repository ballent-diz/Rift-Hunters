class_name ZoneOverlay
extends Node2D
## Barrières continues et flèche de route ; uniquement le rendu, pas les obstacles.

const GLOW := Color(0.72, 0.79, 1.0)
## Plan des barrières peintes : sous le Chasseur (4) et les Échos (3), au-dessus des Corrompus et des ramassables.
const BARRIER_Z := 2
## Flèche de route stable (retour de test) : elle ne suit un nouveau cap que s'il s'écarte de plus de ROUTE_DEADZONE
## (radians) de celui qu'elle montre, et elle y tourne en douceur (ROUTE_TURN_TIME).
const ROUTE_DEADZONE := 0.45
const ROUTE_TURN_TIME := 0.3

var ctx: RunContext
## Jeu de barrière peinte du chapitre de l'arène (RiftWallVisual.barrier_set).
var barrier: Dictionary = {}
var _time: float = 0.0
## Horloge visuelle seulement : instant d'apparition / de dissolution par barrière (les règles ont la leur).
var _appear_at: Dictionary = {}
var _dissolve_at: Dictionary = {}
## Barrières ouvertes par une zone nettoyée : leurs bornes restent au sol, éteintes.
var _opened: Dictionary = {}
var _persist: Dictionary = {}
var _previous: Array[bool] = []
var _curtains: Array[RiftWallVisual] = []
var _version: int = -1
var _dirty: bool = true
## Cap montré par la flèche de route et cap visé (zéro : pas de flèche).
var _route_dir := Vector2.ZERO
var _route_goal := Vector2.ZERO


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	z_index = 6
	_previous.assign(ctx.obstacles.wall_enabled)
	barrier = RiftWallVisual.barrier_set(RiftWallVisual.chapter_for(ctx.arena.id))


## Ouverture d'une barrière de zone : dissolution du voile, puis bornes éteintes laissées en place.
func dissolve(index: int) -> void:
	if not _dissolve_at.has(index):
		_dissolve_at[index] = _time
	_persist[index] = true
	_dirty = true


func _process(delta: float) -> void:
	if ctx == null:
		return
	_time += delta
	if _version != ctx.obstacles.walls_version:
		_track_walls()
	var dissolve_time: float = RiftWallVisual.clip_duration(barrier, &"dissolve")
	for index: int in _dissolve_at.keys():
		if _time - float(_dissolve_at[index]) >= dissolve_time:
			_dissolve_at.erase(index)
			if _persist.has(index):
				_opened[index] = true
			_dirty = true
	if _dirty:
		_rebuild()
	_steer_route(delta)
	for curtain: RiftWallVisual in _curtains:
		curtain.advance(_time)
	queue_redraw()


## Barrières qui viennent de se fermer (apparition) ou de s'ouvrir sans passer par dissolve() (dissolution seule).
func _track_walls() -> void:
	var walls: ObstacleField = ctx.obstacles
	for i: int in walls.walls.size():
		var was: bool = i < _previous.size() and _previous[i]
		if walls.wall_enabled[i] and not was:
			_appear_at[i] = _time
			_dissolve_at.erase(i)
			_opened.erase(i)
			_persist.erase(i)
		elif was and not walls.wall_enabled[i] and not _dissolve_at.has(i):
			_dissolve_at[i] = _time
	_previous.assign(walls.wall_enabled)
	_version = walls.walls_version
	_dirty = true


func _rebuild() -> void:
	for curtain: RiftWallVisual in _curtains:
		curtain.queue_free()
	_curtains.clear()
	_dirty = false
	if barrier.is_empty():
		return
	for phase: RiftWallVisual.Phase in [RiftWallVisual.Phase.CLOSED, RiftWallVisual.Phase.DISSOLVE,
			RiftWallVisual.Phase.OPEN]:
		var rects: Array[Rect2] = []
		var indices: Array[int] = []
		for i: int in ctx.obstacles.walls.size():
			if _in_phase(i, phase):
				rects.append(ctx.obstacles.walls[i])
				indices.append(i)
		for group: PackedInt32Array in RiftWallVisual.connected_groups(rects):
			var pieces: Array[Rect2] = []
			var members: Array[int] = []
			var since: float = -INF
			for local: int in group:
				pieces.append(rects[local])
				members.append(indices[local])
				var source: Dictionary = _dissolve_at if phase == RiftWallVisual.Phase.DISSOLVE else _appear_at
				since = maxf(since, float(source.get(indices[local], -INF)))
			var curtain := RiftWallVisual.new()
			curtain.z_as_relative = false
			curtain.z_index = BARRIER_Z
			curtain.setup(pieces, members, barrier, phase, since)
			add_child(curtain)
			_curtains.append(curtain)


## Les barrières passagères (marées, banquises, portes runiques) ont leur propre rendu.
func _in_phase(i: int, phase: RiftWallVisual.Phase) -> bool:
	if ctx.obstacles.wall_transient[i]:
		return false
	match phase:
		RiftWallVisual.Phase.CLOSED:
			return ctx.obstacles.wall_enabled[i]
		RiftWallVisual.Phase.DISSOLVE:
			return _dissolve_at.has(i) and not ctx.obstacles.wall_enabled[i]
	return _opened.has(i) and not ctx.obstacles.wall_enabled[i]


func _draw() -> void:
	if ctx != null:
		_draw_route()


func _steer_route(delta: float) -> void:
	var dir: Vector2 = ctx.objective_direction(ctx.player.global_position) if ctx.player else Vector2.ZERO
	if dir == Vector2.ZERO:
		_route_dir = Vector2.ZERO
		_route_goal = Vector2.ZERO
		return
	if _route_dir == Vector2.ZERO:
		_route_dir = dir
		_route_goal = dir
		return
	if absf(_route_goal.angle_to(dir)) > ROUTE_DEADZONE:
		_route_goal = dir
	_route_dir = _route_dir.slerp(_route_goal, 1.0 - exp(-delta / ROUTE_TURN_TIME)).normalized()


## Chevrons autour du Chasseur dans la direction de la route à suivre.
func _draw_route() -> void:
	if ctx.player == null or _route_dir == Vector2.ZERO:
		return
	var pos: Vector2 = ctx.player.global_position
	var dir: Vector2 = _route_dir
	var bob: float = 2.0 * sin(_time * 2.4)
	for k: int in 2:
		var tip: Vector2 = pos + dir * (58.0 + 14.0 * k + bob)
		var side: Vector2 = dir.orthogonal() * 9.0
		var back: Vector2 = tip - dir * 11.0
		var alpha: float = (0.76 - 0.24 * k) * (0.86 + 0.14 * sin(_time * 2.4))
		var points := PackedVector2Array([back + side, tip, back - side])
		draw_polyline(points, Color(0.04, 0.06, 0.13, alpha), 6.0, true)
		draw_polyline(points, Color(GLOW, alpha), 2.0, true)
