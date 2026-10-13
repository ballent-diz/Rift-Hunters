class_name SpatialGrid
extends RefCounted
## Grille spatiale uniforme pour les requêtes de proximité (reconstruite à chaque frame).

const _EMPTY: Array = []

var cell_size: float = 64.0
var _cells: Dictionary = {}  # int -> Array
var _used: Array[int] = []


func _init(p_cell_size: float = 64.0) -> void:
	cell_size = p_cell_size


func clear() -> void:
	for key: int in _used:
		(_cells[key] as Array).clear()
	_used.clear()


func insert(item: Object, pos: Vector2) -> void:
	var key: int = _key(floori(pos.x / cell_size), floori(pos.y / cell_size))
	var found: Variant = _cells.get(key)
	var cell: Array
	if found == null:
		cell = []
		_cells[key] = cell
	else:
		cell = found
	if cell.is_empty():
		_used.append(key)
	cell.append(item)


## Ajoute à out tous les éléments des cellules touchées par le cercle (vérifier la distance ensuite).
func query(pos: Vector2, radius: float, out: Array) -> void:
	var min_x: int = int(floor((pos.x - radius) / cell_size))
	var max_x: int = int(floor((pos.x + radius) / cell_size))
	var min_y: int = int(floor((pos.y - radius) / cell_size))
	var max_y: int = int(floor((pos.y + radius) / cell_size))
	for cx: int in range(min_x, max_x + 1):
		for cy: int in range(min_y, max_y + 1):
			var key: int = _key(cx, cy)
			if _cells.has(key):
				var cell: Array = _cells[key]
				if not cell.is_empty():
					out.append_array(cell)


static func _key(cx: int, cy: int) -> int:
	return ((cx + 32768) << 16) | ((cy + 32768) & 0xFFFF)


## Contenu de la cellule qui contient pos (référence directe, ne pas modifier).
func cell_at(pos: Vector2) -> Array:
	var key: int = _key(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))
	return _cells[key] if _cells.has(key) else _EMPTY

