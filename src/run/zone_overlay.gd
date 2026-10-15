class_name ZoneOverlay
extends Node2D
## Affichage du mode « vagues par zone » dans le monde : barrières d'énergie violette (et leur dissolution),
## flèche de route autour du Chasseur quand il faut rejoindre la zone suivante ou l'arène.
## Rendu procédural provisoire : les visuels définitifs sont le lot A3 (docs/ROADMAP.md).

const DISSOLVE_TIME := 1.2
const CORE := Color(0.62, 0.3, 1.0)
const GLOW := Color(0.85, 0.65, 1.0)

var ctx: RunContext
var _time: float = 0.0
## Barrières en cours de dissolution : indice → temps restant.
var _dissolving: Dictionary = {}


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	z_index = 6


func dissolve(index: int) -> void:
	_dissolving[index] = DISSOLVE_TIME
	var wall: Rect2 = ctx.obstacles.walls[index]
	ctx.fx.burst(wall.get_center(), maxf(wall.size.x, wall.size.y) * 0.6, Color(0.75, 0.45, 1.0, 0.6))


func _process(delta: float) -> void:
	_time += delta
	for index: int in _dissolving.keys():
		_dissolving[index] = float(_dissolving[index]) - delta
		if float(_dissolving[index]) <= 0.0:
			_dissolving.erase(index)
	queue_redraw()


func _draw() -> void:
	if ctx == null:
		return
	for i: int in ctx.obstacles.walls.size():
		if ctx.obstacles.wall_enabled[i]:
			_draw_wall(ctx.obstacles.walls[i], 1.0)
		elif _dissolving.has(i):
			_draw_wall(ctx.obstacles.walls[i], float(_dissolving[i]) / DISSOLVE_TIME)
	_draw_route()


## Mur d'énergie : voile translucide, bords lumineux et filaments qui montent.
func _draw_wall(rect: Rect2, strength: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	draw_rect(rect, Color(CORE, (0.16 + 0.08 * pulse) * strength))
	draw_rect(rect, Color(GLOW, 0.75 * strength), false, 2.0)
	var vertical: bool = rect.size.y >= rect.size.x
	var length: float = rect.size.y if vertical else rect.size.x
	var across: float = rect.size.x if vertical else rect.size.y
	var lanes: int = maxi(3, int(across / 14.0))
	for lane: int in lanes:
		var offset: float = (lane + 0.5) / lanes * across
		var phase: float = fmod(_time * 60.0 + lane * 37.0, length)
		var a: Vector2
		var b: Vector2
		if vertical:
			a = rect.position + Vector2(offset, length - phase)
			b = a + Vector2(0, -minf(26.0, length - phase))
		else:
			a = rect.position + Vector2(phase, offset)
			b = a + Vector2(minf(26.0, length - phase), 0)
		draw_line(a, b, Color(GLOW, 0.55 * strength), 2.0)


## Chevrons autour du Chasseur dans la direction de la route à suivre.
func _draw_route() -> void:
	if ctx.zones == null or ctx.player == null:
		return
	var pos: Vector2 = ctx.player.global_position
	var dir: Vector2 = ctx.zones.objective_direction(pos)
	if dir == Vector2.ZERO:
		return
	var bob: float = 6.0 * sin(_time * 5.0)
	for k: int in 3:
		var tip: Vector2 = pos + dir * (58.0 + 14.0 * k + bob)
		var side: Vector2 = dir.orthogonal() * 9.0
		var back: Vector2 = tip - dir * 11.0
		var alpha: float = 0.9 - 0.25 * k
		draw_polyline(PackedVector2Array([back + side, tip, back - side]), Color(GLOW, alpha), 3.0, true)
