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
## Barrières temporaires (mode vagues par zone) : rectangles infranchissables qu'on ouvre en cours de partie.
var walls: Array[Rect2] = []
var wall_enabled: Array[bool] = []
## Incrémenté à chaque ouverture / fermeture de barrière (la navigation se met à jour).
var walls_version: int = 0
var _grid: Dictionary = {}
## Carte de distance (arène dessinée) : distance signée au bord infranchissable, en unités du monde.
var _field: Image
var _field_rect := Rect2()
var _field_px := Vector2.ONE
var _field_step: float = 1.0


## Arène dessinée : image en niveaux de gris (128 = bord, chaque niveau = `step` unités, au-dessus = praticable)
## étendue sur `rect` (l'arène).
func set_distance_field(image: Image, rect: Rect2, step: float = 1.0) -> void:
	_field = image
	_field_step = step
	_field_rect = rect
	_field_px = rect.size / Vector2(image.get_size())


## Distance signée au bord infranchissable le plus proche (> 0 praticable). Sans carte : très grande.
func distance(pos: Vector2) -> float:
	if _field == null:
		return 1e9
	var p: Vector2 = (pos - _field_rect.position) / _field_px - Vector2(0.5, 0.5)
	var size: Vector2i = _field.get_size()
	var x0: int = clampi(floori(p.x), 0, size.x - 1)
	var y0: int = clampi(floori(p.y), 0, size.y - 1)
	var x1: int = mini(x0 + 1, size.x - 1)
	var y1: int = mini(y0 + 1, size.y - 1)
	var fx: float = clampf(p.x - x0, 0.0, 1.0)
	var fy: float = clampf(p.y - y0, 0.0, 1.0)
	var top: float = lerpf(_field.get_pixel(x0, y0).r, _field.get_pixel(x1, y0).r, fx)
	var bottom: float = lerpf(_field.get_pixel(x0, y1).r, _field.get_pixel(x1, y1).r, fx)
	return (lerpf(top, bottom, fy) * 255.0 - 128.0) * _field_step


## Direction qui éloigne du bord infranchissable (vers le praticable).
func _field_normal(pos: Vector2) -> Vector2:
	var h: float = _field_px.x
	var grad := Vector2(distance(pos + Vector2(h, 0)) - distance(pos - Vector2(h, 0)),
		distance(pos + Vector2(0, h)) - distance(pos - Vector2(0, h)))
	return grad.normalized() if grad.length_squared() > 1e-6 else Vector2.ZERO


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
	return circles.is_empty() and _field == null and walls.is_empty()


## Ajoute une barrière (fermée) ; renvoie son indice.
func add_wall(rect: Rect2) -> int:
	walls.append(rect)
	wall_enabled.append(true)
	walls_version += 1
	return walls.size() - 1


func set_wall_enabled(index: int, enabled: bool) -> void:
	if wall_enabled[index] != enabled:
		wall_enabled[index] = enabled
		walls_version += 1


## Sort un cercle d'une barrière fermée par le bord le plus proche.
func _push_out_walls(pos: Vector2, radius: float) -> Vector2:
	for i: int in walls.size():
		if not wall_enabled[i]:
			continue
		var r: Rect2 = walls[i].grow(radius)
		if not r.has_point(pos):
			continue
		var exits: Array[float] = [pos.x - r.position.x, r.end.x - pos.x, pos.y - r.position.y, r.end.y - pos.y]
		var best: int = 0
		for side: int in 4:
			if exits[side] < exits[best]:
				best = side
		match best:
			0: pos.x = r.position.x - 0.5
			1: pos.x = r.end.x + 0.5
			2: pos.y = r.position.y - 0.5
			_: pos.y = r.end.y + 0.5
	return pos


func _wall_blocks(pos: Vector2, radius: float) -> bool:
	for i: int in walls.size():
		if wall_enabled[i] and walls[i].grow(radius).has_point(pos):
			return true
	return false


## Position corrigée pour qu'un cercle (pos, radius) ne chevauche aucun obstacle.
func push_out(pos: Vector2, radius: float) -> Vector2:
	if not walls.is_empty():
		pos = _push_out_walls(pos, radius)
	if _field != null:
		pos = _push_out_field(pos, radius)
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


func _push_out_field(pos: Vector2, radius: float) -> Vector2:
	var result: Vector2 = pos
	for step: int in 3:
		var d: float = distance(result)
		if d >= radius:
			break
		var normal: Vector2 = _field_normal(result)
		if normal == Vector2.ZERO:
			break
		var depth: float = radius - d
		result += normal * depth + normal.orthogonal() * depth * SLIDE * 0.5
	return result


## Poussée d'évitement (bot de test) : vers l'extérieur des obstacles à moins de `reach`.
func repulsion(pos: Vector2, reach: float) -> Vector2:
	var force := Vector2.ZERO
	for c: Vector3 in near(pos, reach):
		var away := Vector2(pos.x - c.x, pos.y - c.y)
		force += away.normalized() * (reach - (away.length() - c.z)) / 30.0
	if _field != null:
		var d: float = distance(pos)
		if d < reach:
			force += _field_normal(pos) * (reach - d) / 30.0
	for i: int in walls.size():
		if wall_enabled[i] and walls[i].grow(reach).has_point(pos):
			var away: Vector2 = pos - walls[i].get_center()
			force += away.normalized() * 0.8
	return force


## Vrai si un cercle (pos, radius) chevauche un obstacle. `include_walls` : compter les barrières fermées.
func blocks(pos: Vector2, radius: float, include_walls: bool = true) -> bool:
	if include_walls and not walls.is_empty() and _wall_blocks(pos, radius):
		return true
	if _field != null and distance(pos) < radius:
		return true
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
