class_name FlowField
extends RefCounted
## Carte de flux vers le Chasseur : distance de parcours (en contournant le décor) de chaque case praticable.
## Un seul calcul sert à tous les ennemis : chacun descend la pente vers le Chasseur et emprunte donc les routes
## au lieu de rester coincé derrière un îlot de rochers. En terrain dégagé, la ligne droite est conservée.

## Taille d'une case (unités du monde).
const CELL := 16.0
## Marge au bord d'un obstacle pour qu'une case soit praticable (≥ rayon des ennemis courants : le chemin ne
## rase pas les obstacles).
const CLEARANCE := 16.0
## Coûts de déplacement (orthogonal / diagonal ≈ 1 : 1,5).
const COST_STRAIGHT := 2
const COST_DIAGONAL := 3
## En dessous de cette distance de parcours, on fonce droit sur la cible.
const NEAR_COST := 8
## Si la pente et la ligne droite divergent de moins de ~20°, on garde la ligne droite (pas de zigzag de grille).
const STRAIGHT_DOT := 0.94
const UNREACHED := 1 << 30
const NEIGHBORS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var origin := Vector2.ZERO
var size := Vector2i.ZERO
var _walkable := PackedByteArray()
var _dist := PackedInt32Array()
var _target_cell := Vector2i(-1, -1)


## Cases praticables d'après le champ d'obstacles (une fois par partie).
func setup(obstacles: ObstacleField, rect: Rect2) -> void:
	origin = rect.position
	size = Vector2i(ceili(rect.size.x / CELL), ceili(rect.size.y / CELL))
	var count: int = size.x * size.y
	_walkable.resize(count)
	_dist.resize(count)
	_dist.fill(UNREACHED)
	for y: int in size.y:
		for x: int in size.x:
			var center: Vector2 = cell_center(Vector2i(x, y))
			_walkable[y * size.x + x] = 0 if obstacles.blocks(center, CLEARANCE) else 1
	_target_cell = Vector2i(-1, -1)


func is_walkable(cell: Vector2i) -> bool:
	return _in_bounds(cell) and _walkable[cell.y * size.x + cell.x] == 1


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori((pos.x - origin.x) / CELL), floori((pos.y - origin.y) / CELL))


func cell_center(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## Distance de parcours (coûts cumulés) depuis la cible, UNREACHED hors carte ou injoignable.
func cost_at(pos: Vector2) -> int:
	var cell: Vector2i = cell_of(pos)
	return _dist[cell.y * size.x + cell.x] if _in_bounds(cell) else UNREACHED


## Recalcule la carte vers `target` (rien à faire si la cible n'a pas changé de case).
func update(target: Vector2) -> void:
	var start: Vector2i = _nearest_walkable(cell_of(target))
	if start == _target_cell or start.x < 0:
		return
	_target_cell = start
	_dist.fill(UNREACHED)
	var w: int = size.x
	var first: int = start.y * w + start.x
	_dist[first] = 0
	# Algorithme de Dial : une file par coût (coûts entiers et petits), chaque case traitée une fois.
	var buckets: Array[Array] = [[first]]
	var d: int = 0
	while d < buckets.size():
		var bucket: Array = buckets[d]
		for index: int in bucket:
			if _dist[index] != d:
				continue
			var x: int = index % w
			var y: int = index / w
			for n: Vector2i in NEIGHBORS:
				var nx: int = x + n.x
				var ny: int = y + n.y
				if nx < 0 or ny < 0 or nx >= w or ny >= size.y:
					continue
				var j: int = ny * w + nx
				if _walkable[j] == 0:
					continue
				var step: int = COST_STRAIGHT
				if n.x != 0 and n.y != 0:
					# Pas de coin coupé : les deux cases orthogonales doivent être praticables.
					if _walkable[y * w + nx] == 0 or _walkable[ny * w + x] == 0:
						continue
					step = COST_DIAGONAL
				var nd: int = d + step
				if nd < _dist[j]:
					_dist[j] = nd
					while buckets.size() <= nd:
						buckets.append([])
					buckets[nd].append(j)
		d += 1


## Direction de déplacement vers la cible depuis `pos` ; `direct` = ligne droite (utilisée près de la cible,
## en terrain dégagé ou hors de la carte).
func direction(pos: Vector2, direct: Vector2) -> Vector2:
	var cell: Vector2i = cell_of(pos)
	if not _in_bounds(cell):
		return direct
	var here: int = _dist[cell.y * size.x + cell.x]
	if here <= NEAR_COST:
		return direct
	# Case injoignable (dans la marge d'un obstacle) : on rejoint la case voisine la plus proche de la cible.
	var best: int = here
	var best_cell := Vector2i(-1, -1)
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var c := Vector2i(cell.x + dx, cell.y + dy)
			if not _in_bounds(c):
				continue
			var value: int = _dist[c.y * size.x + c.x]
			if value >= best:
				continue
			# Case à deux pas : le milieu doit être praticable (on ne vise pas à travers un coin de rocher).
			if (absi(dx) == 2 or absi(dy) == 2) and not is_walkable(Vector2i(cell.x + dx / 2, cell.y + dy / 2)):
				continue
			best = value
			best_cell = c
	if best_cell.x < 0:
		return direct
	var flow: Vector2 = (cell_center(best_cell) - pos).normalized()
	return direct if flow.dot(direct) > STRAIGHT_DOT else flow


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	cell = Vector2i(clampi(cell.x, 0, size.x - 1), clampi(cell.y, 0, size.y - 1))
	if is_walkable(cell):
		return cell
	for radius: int in range(1, 6):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if is_walkable(c):
					return c
	return Vector2i(-1, -1)
