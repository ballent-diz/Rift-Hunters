class_name ZoneOverlay
extends Node2D
## Barrières continues et flèche de route ; uniquement le rendu, pas les obstacles.

const DISSOLVE_TIME := 1.2
const APPEAR_TIME := 0.5
const GLOW := Color(0.72, 0.79, 1.0)

var ctx: RunContext
var _time: float = 0.0
var _dissolving: Dictionary = {}
var _appearing: Dictionary = {}
var _previous: Array[bool] = []
var _curtains: Array[RiftWallVisual] = []
var _version: int = -1
var _dirty: bool = true


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


## Chevrons autour du Chasseur dans la direction de la route à suivre.
func _draw_route() -> void:
	if ctx.player == null or (ctx.zones == null and ctx.rifts == null):
		return
	var pos: Vector2 = ctx.player.global_position
	var dir: Vector2 = ctx.zones.objective_direction(pos) if ctx.zones else ctx.rifts.objective_direction(pos)
	if dir == Vector2.ZERO:
		return
	var bob: float = 2.0 * sin(_time * 2.4)
	for k: int in 2:
		var tip: Vector2 = pos + dir * (58.0 + 14.0 * k + bob)
		var side: Vector2 = dir.orthogonal() * 9.0
		var back: Vector2 = tip - dir * 11.0
		var alpha: float = (0.76 - 0.24 * k) * (0.86 + 0.14 * sin(_time * 2.4))
		var points := PackedVector2Array([back + side, tip, back - side])
		draw_polyline(points, Color(0.04, 0.06, 0.13, alpha), 6.0, true)
		draw_polyline(points, Color(GLOW, alpha), 2.0, true)
