class_name TerrainDirector
extends Node2D
## Terrain qui change le mouvement (docs/design/CARTES.md) :
## - brique B1, terrain lent (gués de la carte 4, plus tard boue ou neige) : tout le monde y est ralenti, Chasseur,
##   Échos et Corrompus ;
## - brique B6, courants (carte 5) : le Chasseur et les Corrompus y dérivent ; le suivre est un raccourci.
## La Ruée garde sa vitesse et ne dérive pas : c'est la porte de sortie. Dessine les zones pour la lisibilité.

const RIPPLE := Color(0.75, 0.9, 1.0)

var ctx: RunContext
var _time: float = 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Terrain"
	# Au-dessus du sol (-10), sous les zones (0) et les personnages.
	z_index = -5


static func uses_terrain(arena: ArenaData) -> bool:
	return not arena.slow_zones.is_empty() or not arena.currents.is_empty()


## Multiplicateur de vitesse à cette position (1 hors des zones lentes).
func speed_mult(pos: Vector2) -> float:
	for rect: Rect2 in ctx.arena.slow_zones:
		if rect.has_point(pos):
			return ctx.arena.slow_zone_mult
	return 1.0


## Dérive des courants à cette position (px/s ; zéro hors des courants).
func drift(pos: Vector2) -> Vector2:
	for i: int in ctx.arena.currents.size():
		if ctx.arena.currents[i].has_point(pos):
			return current_dir(i) * ctx.arena.current_speed
	return Vector2.ZERO


func current_dir(index: int) -> Vector2:
	return lane_dir(ctx.arena.current_dirs, index)


## Sens d'une bande (courant ou lit de crue) ; vers la droite si la carte ne le donne pas.
static func lane_dir(dirs: Array[Vector2], index: int) -> Vector2:
	if index < dirs.size() and dirs[index].length() > 0.01:
		return dirs[index].normalized()
	return Vector2.RIGHT


func step(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if ctx == null:
		return
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	view = view.grow(64.0)
	for i: int in ctx.arena.slow_zones.size():
		var rect: Rect2 = ctx.arena.slow_zones[i]
		if ctx.arena.slow_zones_painted or not rect.intersects(view):
			continue
		draw_rect(rect, Color(0.3, 0.6, 0.85, 0.22))
		draw_rect(rect, Color(RIPPLE, 0.35), false, 2.0)
		# Ondulations : cercles qui s'élargissent à des points fixes de la zone.
		var count: int = clampi(int(rect.get_area() / 40000.0), 2, 24)
		for k: int in count:
			var seed_x: float = fmod((i * 13 + k) * 0.6180339, 1.0)
			var seed_y: float = fmod((i * 7 + k) * 0.4142135, 1.0)
			var center: Vector2 = rect.position + Vector2(seed_x, seed_y) * rect.size
			var life: float = fmod(_time * 0.45 + k * 0.37, 1.0)
			draw_arc(center, 6.0 + life * 26.0, 0.0, TAU, 20, Color(RIPPLE, 0.65 * (1.0 - life)), 2.0)
	for i: int in ctx.arena.currents.size():
		var rect: Rect2 = ctx.arena.currents[i]
		if rect.intersects(view):
			draw_rect(rect, Color(0.3, 0.6, 0.85, 0.18))
			draw_flow(self, rect, current_dir(i), _time * ctx.arena.current_speed, Color(RIPPLE, 0.55))


## Chevrons qui défilent dans le sens du flot (courants et crues).
static func draw_flow(canvas: CanvasItem, rect: Rect2, dir: Vector2, travel: float, color: Color) -> void:
	var across: Vector2 = dir.orthogonal()
	var length: float = absf(rect.size.dot(dir))
	var width: float = absf(rect.size.dot(across))
	var spacing: float = 90.0
	var rows: int = maxi(1, int(width / 70.0))
	var start: Vector2 = rect.get_center() - dir * length * 0.5
	for row: int in rows:
		var side: float = (row + 0.5) / rows - 0.5
		var offset: float = fmod(travel + row * spacing * 0.5, spacing)
		var along: float = offset
		while along < length:
			var tip: Vector2 = start + dir * along + across * side * width
			var fade: float = minf(along, length - along) / 60.0
			var c: Color = Color(color, color.a * clampf(fade, 0.0, 1.0))
			canvas.draw_line(tip, tip - dir * 14.0 + across * 10.0, c, 2.5)
			canvas.draw_line(tip, tip - dir * 14.0 - across * 10.0, c, 2.5)
			along += spacing
