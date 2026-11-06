class_name ZoneOverlay
extends Node2D
## Barrières continues et flèche de route ; uniquement le rendu, pas les obstacles.

const DISSOLVE_TIME := 1.2
const APPEAR_TIME := 0.5
const GLOW := Color(0.72, 0.79, 1.0)
## Flèche de route stable (retour de test) : elle ne suit un nouveau cap que s'il s'écarte de plus de ROUTE_DEADZONE
## (radians) de celui qu'elle montre, et elle y tourne en douceur (ROUTE_TURN_TIME).
const ROUTE_DEADZONE := 0.45
const ROUTE_TURN_TIME := 0.3

var ctx: RunContext
var _time: float = 0.0
var _dissolving: Dictionary = {}
var _appearing: Dictionary = {}
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


func dissolve(index: int) -> void:
	_dissolving[index] = DISSOLVE_TIME
	_dirty = true


func _process(delta: float) -> void:
	if ctx == null:
		return
	_time += delta
	if _version != ctx.obstacles.walls_version:
		for i: int in ctx.obstacles.walls.size():
			if ctx.obstacles.wall_enabled[i] and (i >= _previous.size() or not _previous[i]):
				_appearing[i] = 0.0
		_previous.assign(ctx.obstacles.wall_enabled)
		_version = ctx.obstacles.walls_version
		_dirty = true
	for index: int in _dissolving.keys():
		_dissolving[index] = float(_dissolving[index]) - delta
		if float(_dissolving[index]) <= 0.0:
			_dissolving.erase(index)
			_dirty = true
	for index: int in _appearing.keys():
		_appearing[index] = minf(APPEAR_TIME, float(_appearing[index]) + delta)
	if _dirty:
		_rebuild()
	_steer_route(delta)
	for curtain: RiftWallVisual in _curtains:
		var id: int = curtain.members[0]
		var strength: float = 1.0
		if _dissolving.has(id):
			strength = float(_dissolving[id]) / DISSOLVE_TIME
		elif _appearing.has(id):
			strength = float(_appearing[id]) / APPEAR_TIME
		curtain.animate(strength, _time, _dissolving.has(id))
	queue_redraw()


func _rebuild() -> void:
	for curtain: RiftWallVisual in _curtains:
		curtain.queue_free()
	_curtains.clear()
	for dissolving: bool in [false, true]:
		var rects: Array[Rect2] = []
		var indices: Array[int] = []
		for i: int in ctx.obstacles.walls.size():
			if (_dissolving.has(i) if dissolving else ctx.obstacles.wall_enabled[i]):
				rects.append(ctx.obstacles.walls[i])
				indices.append(i)
		for group: PackedInt32Array in RiftWallVisual.connected_groups(rects):
			var pieces: Array[Rect2] = []
			var members: Array[int] = []
			for local: int in group:
				pieces.append(rects[local])
				members.append(indices[local])
			var curtain := RiftWallVisual.new()
			curtain.setup(pieces, members)
			add_child(curtain)
			_curtains.append(curtain)
	_dirty = false


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
