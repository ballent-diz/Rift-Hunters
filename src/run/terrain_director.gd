class_name TerrainDirector
extends Node2D
## Brique B1 « terrain qui change le mouvement » (docs/design/CARTES.md) : zones de terrain lent (gués de la carte 4,
## plus tard boue ou neige) qui ralentissent tout le monde, Chasseur, Échos et Corrompus. La Ruée garde sa vitesse :
## c'est la porte de sortie. Tactique : attirer les hordes dans l'eau. Dessine des ondulations pour la lisibilité.

const RIPPLE := Color(0.75, 0.9, 1.0)

var ctx: RunContext
var _time: float = 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Terrain"
	# Au-dessus du sol (-10), sous les zones (0) et les personnages.
	z_index = -5


## Multiplicateur de vitesse à cette position (1 hors des zones lentes).
func speed_mult(pos: Vector2) -> float:
	for rect: Rect2 in ctx.arena.slow_zones:
		if rect.has_point(pos):
			return ctx.arena.slow_zone_mult
	return 1.0


func step(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if ctx == null:
		return
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	for i: int in ctx.arena.slow_zones.size():
		var rect: Rect2 = ctx.arena.slow_zones[i]
		if not rect.intersects(view.grow(64.0)):
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
