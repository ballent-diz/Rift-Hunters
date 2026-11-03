class_name CoverRocks
extends Node2D
## Abris posés par le jeu (ArenaData.cover_rocks) : rochers de cristal indestructibles, ajoutés au champ d'obstacles
## avant la navigation. Ils arrêtent le passage, les tirs et les souffles (règle des abris, docs/design/DIFFICULTE.md).
## Dessin provisoire : pierre facettée, lumière en haut à gauche, liseré violet en bas à droite (docs/ART_BIBLE.md).

const STONE := Color(0.32, 0.38, 0.42)
const LIT := Color(0.62, 0.74, 0.78)
const CRYSTAL := Color(0.55, 0.9, 0.95)
const RIM := Color(0.45, 0.3, 0.7)

var _rocks: Array[Vector2] = []
var _radius: float = 58.0


## Ajoute les rochers au champ d'obstacles et garde de quoi les dessiner.
func setup(arena: ArenaData, obstacles: ObstacleField) -> void:
	name = "CoverRocks"
	_radius = arena.cover_radius
	for pos: Vector2 in arena.cover_rocks:
		obstacles.add(pos, _radius)
		_rocks.append(pos)
	queue_redraw()


func _draw() -> void:
	for center: Vector2 in _rocks:
		var r: float = _radius
		draw_set_transform(center + Vector2(10, 14), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, r * 1.05, Color(0, 0, 0, 0.3))
		draw_set_transform(center, 0.0, Vector2.ONE)
		var body := PackedVector2Array([Vector2(-r, 0.3 * r), Vector2(-0.85 * r, -0.55 * r), Vector2(-0.3 * r, -1.25 * r),
			Vector2(0.45 * r, -1.05 * r), Vector2(r, -0.35 * r), Vector2(0.9 * r, 0.45 * r), Vector2(0.1 * r, 0.75 * r)])
		draw_colored_polygon(body, STONE)
		draw_colored_polygon(PackedVector2Array([body[1], body[2], body[3], Vector2(0.05 * r, -0.35 * r)]), LIT)
		draw_colored_polygon(PackedVector2Array([body[0], body[1], Vector2(0.05 * r, -0.35 * r), body[6]]),
			STONE.lightened(0.12))
		var outline := body.duplicate()
		outline.append(body[0])
		draw_polyline(outline, Color(0.08, 0.1, 0.12), 2.0, true)
		draw_polyline(PackedVector2Array([body[4], body[5], body[6]]), RIM, 2.5, true)
		# Éclats de cristal pris dans la pierre.
		for k: int in 3:
			var base := Vector2((-0.35 + 0.3 * k) * r, (-0.2 - 0.15 * (k % 2)) * r)
			var tip: Vector2 = base + Vector2(0.08 * r, -0.45 * r)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-0.09 * r, 0), tip, base + Vector2(0.11 * r, 0)]),
				Color(CRYSTAL, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
