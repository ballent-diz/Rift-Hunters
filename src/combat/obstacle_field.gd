class_name ObstacleField
extends RefCounted
## Obstacles infranchissables du décor (rochers, arbres, ruines, eau) : cercles rangés dans une grille.
## Le joueur, les Échos et les ennemis en sont repoussés ; un ennemi qui arrive de face glisse sur le côté
## (contournement) au lieu de rester bloqué. Les projectiles et le boss les ignorent.

const CELL := 128.0
## Part du recul appliquée de côté : fait contourner l'obstacle.
const SLIDE := 0.6

## Cercles : Vector3(x, y, rayon).
var circles: Array[Vector3] = []
var _grid: Dictionary = {}


func add(center: Vector2, radius: float) -> void:
	var circle := Vector3(center.x, center.y, radius)
	var index: int = circles.size()
	circles.append(circle)
	var lo := Vector2i(floori((center.x - radius) / CELL), floori((center.y - radius) / CELL))
	var hi := Vector2i(floori((center.x + radius) / CELL), floori((center.y + radius) / CELL))
	for cx: int in range(lo.x, hi.x + 1):
		for cy: int in range(lo.y, hi.y + 1):
			var key := Vector2i(cx, cy)
			if not _grid.has(key):
				var list: Array[int] = []
				_grid[key] = list
			(_grid[key] as Array[int]).append(index)


func is_empty() -> bool:
	return circles.is_empty()


## Position corrigée pour qu'un cercle (pos, radius) ne chevauche aucun obstacle.
func push_out(pos: Vector2, radius: float) -> Vector2:
	if circles.is_empty():
		return pos
	var key := Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))
	var result: Vector2 = pos
	for pass_index: int in 2:
		var moved: bool = false
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				var bucket: Variant = _grid.get(Vector2i(key.x + dx, key.y + dy))
				if bucket == null:
					continue
				for index: int in bucket:
					var c: Vector3 = circles[index]
					var offset := Vector2(result.x - c.x, result.y - c.y)
					var min_dist: float = c.z + radius
					var d2: float = offset.length_squared()
					if d2 >= min_dist * min_dist:
						continue
					var d: float = sqrt(d2)
					var normal: Vector2 = offset / d if d > 0.01 else Vector2.UP
					var depth: float = min_dist - d
					result += normal * depth + normal.orthogonal() * depth * SLIDE
					moved = true
		if not moved:
			break
	return result


## Vrai si un cercle (pos, radius) chevauche un obstacle.
func blocks(pos: Vector2, radius: float) -> bool:
	var key := Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var bucket: Variant = _grid.get(Vector2i(key.x + dx, key.y + dy))
			if bucket == null:
				continue
			for index: int in bucket:
				var c: Vector3 = circles[index]
				if Vector2(pos.x - c.x, pos.y - c.y).length() < c.z + radius:
					return true
	return false


## Cercles à moins de `reach` (bord à bord) d'une position. Portée limitée à une case autour.
func near(pos: Vector2, reach: float) -> Array[Vector3]:
	var found: Array[Vector3] = []
	var seen: Dictionary = {}
	var key := Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var bucket: Variant = _grid.get(Vector2i(key.x + dx, key.y + dy))
			if bucket == null:
				continue
			for index: int in bucket:
				if seen.has(index):
					continue
				seen[index] = true
				var c: Vector3 = circles[index]
				if Vector2(pos.x - c.x, pos.y - c.y).length() - c.z < reach:
					found.append(c)
	return found
