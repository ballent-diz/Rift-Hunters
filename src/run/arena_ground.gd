class_name ArenaGround
extends Node2D
## Sol de l'arène (placeholder) : dalles sombres, fissures de faille et bordure. Dessiné une seule fois.

var arena: ArenaData
var seed_value: int = 0


func setup(p_arena: ArenaData, p_seed: int) -> void:
	arena = p_arena
	seed_value = p_seed
	z_index = -10
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = arena.size * 0.5
	var rect := Rect2(-half, arena.size)
	draw_rect(rect.grow(600.0), Color(0.03, 0.03, 0.06))
	draw_rect(rect, arena.ground_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tile: float = 160.0
	var x: float = -half.x
	while x < half.x:
		var y: float = -half.y
		while y < half.y:
			if rng.randf() < 0.35:
				draw_rect(Rect2(x + 4, y + 4, tile - 8, tile - 8), Color(arena.ground_detail_color, rng.randf_range(0.15, 0.35)))
			y += tile
		x += tile
	for i: int in 90:
		var start := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		var points := PackedVector2Array([start])
		var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
		for s: int in rng.randi_range(3, 7):
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			points.append(points[points.size() - 1] + dir * rng.randf_range(18.0, 46.0))
		draw_polyline(points, Color(0.45, 0.25, 0.75, rng.randf_range(0.15, 0.35)), 2.0)
	for i: int in 40:
		var pos := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		draw_circle(pos, rng.randf_range(2.0, 5.0), Color(0.6, 0.4, 1.0, 0.25))
	draw_rect(rect, Color(0.55, 0.3, 0.9, 0.9), false, 6.0)
