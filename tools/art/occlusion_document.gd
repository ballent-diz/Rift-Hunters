class_name OcclusionDocument
extends RefCounted
## Données de l'éditeur de masquage (tools/art/occlusion_editor.tscn ; docs/maps/MASQUAGE_PAR_LE_DECOR.md) : éléments
## de décor (silhouette visible + ligne de pied), sauvegarde, reprise, et cuisson de la texture de profondeur lue par
## le jeu (OcclusionMap). Tout est exprimé dans la grille de masquage : 1 cellule = `cell` pixels de la carte entière
## (tuiles côte à côte). Les images de la carte et les collisions ne sont jamais modifiées.

const MANIFEST := "res://assets/asset_manifest.json"
const FILE := "occlusion.json"
const DEPTH_FILE := "depth.png"
const MASK_DIR := "masks"
## Catégories proposées (facultatives, pour s'y retrouver ; aucun effet en jeu).
const CATEGORIES: Array[String] = ["", "rock", "tree", "wall", "building", "ruin", "pillar", "statue", "debris"]
## Taille visée d'une cellule, en unités peintes de la carte.
const TARGET_CELL_UNITS := 2.0


## Élément de masquage : silhouette (image LA8, alpha = masque) sur `rect` et ligne de pied a → b (cellules).
class Element:
	extends RefCounted
	var id: String = ""
	var category: String = ""
	var rect := Rect2i()
	var mask: Image
	var depth_a := Vector2.ZERO
	var depth_b := Vector2.ZERO
	var hidden: bool = false

	## Ligne de profondeur (Y en cellules) à la colonne x : interpolée entre les deux repères, constante au-delà.
	func depth_at(x: float) -> float:
		if is_equal_approx(depth_a.x, depth_b.x):
			return maxf(depth_a.y, depth_b.y)
		var left: Vector2 = depth_a if depth_a.x < depth_b.x else depth_b
		var right: Vector2 = depth_b if depth_a.x < depth_b.x else depth_a
		var t: float = clampf((x - left.x) / (right.x - left.x), 0.0, 1.0)
		return lerpf(left.y, right.y, t)

	func covers(p: Vector2i) -> bool:
		if mask == null or not rect.has_point(p):
			return false
		return mask.get_pixelv(p - rect.position).a > 0.5

	func copy() -> Element:
		var e := Element.new()
		e.id = id
		e.category = category
		e.rect = rect
		e.mask = mask.duplicate() if mask != null else null
		e.depth_a = depth_a
		e.depth_b = depth_b
		e.hidden = hidden
		return e


var environment_id: StringName = &""
## Dossier des données (res://assets/environments/<décor>/occlusion).
var directory: String = ""
var map_size := Vector2i.ONE
var cell: int = 1
var grid := Vector2i.ONE
var elements: Array[Element] = []
## Codes de profondeur par cellule (0 = aucun élément), tenus à jour par bake().
var _codes := PackedInt32Array()


## Nouveau document pour une carte de `map_size` pixels couvrant `painted_size` unités peintes.
static func create(p_environment: StringName, p_directory: String, p_map_size: Vector2i,
		painted_size: Vector2) -> OcclusionDocument:
	var doc := OcclusionDocument.new()
	doc.environment_id = p_environment
	doc.directory = p_directory
	doc.map_size = p_map_size
	var px_per_unit: float = float(p_map_size.x) / maxf(painted_size.x, 1.0)
	doc.cell = maxi(1, roundi(TARGET_CELL_UNITS * px_per_unit))
	doc.grid = Vector2i(ceili(float(p_map_size.x) / doc.cell), ceili(float(p_map_size.y) / doc.cell))
	doc._codes.resize(doc.grid.x * doc.grid.y)
	return doc


## Dossier par défaut des données d'un décor (à côté de ses tuiles).
static func default_directory(environment_id: StringName) -> String:
	var map_path: String = str(Assets.entry(environment_id).get("map", ""))
	return map_path.get_base_dir().path_join("occlusion")


## Reprend un document enregistré ; null s'il n'existe pas ou ne correspond plus à la carte.
static func open(p_directory: String, expected_map_size: Vector2i) -> OcclusionDocument:
	var path: String = p_directory.path_join(FILE)
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	var doc := OcclusionDocument.new()
	doc.environment_id = StringName(str(d.get("environment", "")))
	doc.directory = p_directory
	doc.map_size = _vec2i(d.get("map_size", []))
	if doc.map_size != expected_map_size:
		push_warning("Masquage : taille de carte changée (%s → %s), données ignorées" % [doc.map_size, expected_map_size])
		return null
	doc.cell = int(d.get("cell", 1))
	doc.grid = _vec2i(d.get("grid", []))
	doc._codes.resize(doc.grid.x * doc.grid.y)
	for raw: Variant in d.get("elements", []):
		var item: Dictionary = raw
		var e := Element.new()
		e.id = str(item.get("id", ""))
		e.category = str(item.get("category", ""))
		var r: Array = item.get("rect", [0, 0, 0, 0])
		e.rect = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		var line: Array = item.get("depth", [[0, 0], [0, 0]])
		e.depth_a = Vector2(float(line[0][0]), float(line[0][1]))
		e.depth_b = Vector2(float(line[1][0]), float(line[1][1]))
		e.hidden = bool(item.get("hidden", false))
		var mask_file: String = str(item.get("mask", ""))
		if mask_file != "" and e.rect.has_area():
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(p_directory.path_join(mask_file)))
			if img != null:
				img.convert(Image.FORMAT_LA8)
				if img.get_size() == e.rect.size:
					e.mask = img
		if e.mask == null:
			e.rect = Rect2i(e.rect.position, Vector2i.ZERO)
		doc.elements.append(e)
	doc.bake()
	return doc


static func _vec2i(raw: Variant) -> Vector2i:
	var list: Array = raw if raw is Array else []
	return Vector2i(int(list[0]), int(list[1])) if list.size() >= 2 else Vector2i.ZERO


# --- Repères -------------------------------------------------------------------------------------------------------

## Rectangle de la carte en jeu (ou dans l'éditeur) : cellule → monde.
func cell_to_world(p: Vector2, world_rect: Rect2) -> Vector2:
	return world_rect.position + p * float(cell) / Vector2(map_size) * world_rect.size


func world_to_cell(p: Vector2, world_rect: Rect2) -> Vector2:
	return (p - world_rect.position) / world_rect.size * Vector2(map_size) / float(cell)


## Rectangle du monde couvert par une région de la grille.
func region_to_world(r: Rect2i, world_rect: Rect2) -> Rect2:
	var a: Vector2 = cell_to_world(Vector2(r.position), world_rect)
	return Rect2(a, cell_to_world(Vector2(r.end), world_rect) - a)


# --- Éléments ------------------------------------------------------------------------------------------------------

func find(id: String) -> Element:
	for e: Element in elements:
		if e.id == id:
			return e
	return null


## Nouvel élément ; identifiant stable « <catégorie>_<nn> » (« element_<nn> » sans catégorie), jamais réutilisé.
func add_element(category: String, foot: Vector2) -> Element:
	var e := Element.new()
	e.category = category
	var prefix: String = category if category != "" else "element"
	var n: int = 1
	while find("%s_%02d" % [prefix, n]) != null:
		n += 1
	e.id = "%s_%02d" % [prefix, n]
	e.depth_a = foot
	e.depth_b = foot
	elements.append(e)
	return e


## Éléments sous une cellule (le plus proche, ligne de pied la plus basse, en premier).
func elements_at(p: Vector2i) -> Array[Element]:
	var hits: Array[Element] = []
	for e: Element in elements:
		if e.covers(p):
			hits.append(e)
	hits.sort_custom(func(a: Element, b: Element) -> bool: return a.depth_at(p.x) > b.depth_at(p.x))
	return hits


## Agrandit le masque pour couvrir `r` (limité à la grille).
func _grow(e: Element, r: Rect2i) -> void:
	r = r.intersection(Rect2i(Vector2i.ZERO, grid))
	if not r.has_area():
		return
	var target: Rect2i = r if not e.rect.has_area() or e.mask == null else e.rect.merge(r)
	if target == e.rect and e.mask != null:
		return
	var img := Image.create(target.size.x, target.size.y, false, Image.FORMAT_LA8)
	if e.mask != null and e.rect.has_area():
		img.blit_rect(e.mask, Rect2i(Vector2i.ZERO, e.rect.size), e.rect.position - target.position)
	e.mask = img
	e.rect = target


## Remplit une plage horizontale [x0, x1) de la ligne y (cellules), ajout ou gomme.
func _span(e: Element, y: int, x0: int, x1: int, add: bool) -> void:
	if e.mask == null:
		return
	var a: int = maxi(x0, e.rect.position.x)
	var b: int = mini(x1, e.rect.end.x)
	if b <= a or y < e.rect.position.y or y >= e.rect.end.y:
		return
	e.mask.fill_rect(Rect2i(a - e.rect.position.x, y - e.rect.position.y, b - a, 1), Color(1, 1, 1, 1.0 if add else 0.0))


## Pinceau rond (centre et rayon en cellules). Renvoie la région touchée.
func paint_circle(e: Element, center: Vector2, radius: float, add: bool) -> Rect2i:
	var r: float = maxf(radius, 0.5)
	var box := Rect2i(Vector2i((center - Vector2(r, r)).floor()), Vector2i(ceili(r * 2.0) + 2, ceili(r * 2.0) + 2))
	if add:
		_grow(e, box)
	for y: int in range(box.position.y, box.end.y):
		var dy: float = y + 0.5 - center.y
		if absf(dy) > r:
			continue
		var half: float = sqrt(r * r - dy * dy)
		_span(e, y, ceili(center.x - half - 0.5), floori(center.x + half - 0.5) + 1, add)
	return box.intersection(Rect2i(Vector2i.ZERO, grid))


## Polygone rempli (sommets en cellules, règle pair-impair : les trous tracés à l'intérieur restent des trous).
func fill_polygon(e: Element, points: PackedVector2Array, add: bool) -> Rect2i:
	if points.size() < 3:
		return Rect2i()
	var lo: Vector2 = points[0]
	var hi: Vector2 = points[0]
	for p: Vector2 in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var box := Rect2i(Vector2i(lo.floor()), Vector2i((hi - lo.floor()).ceil()) + Vector2i.ONE)
	if add:
		_grow(e, box)
	for y: int in range(box.position.y, box.end.y):
		var sy: float = y + 0.5
		var xs: Array[float] = []
		for i: int in points.size():
			var p: Vector2 = points[i]
			var q: Vector2 = points[(i + 1) % points.size()]
			if (p.y <= sy) != (q.y <= sy):
				xs.append(p.x + (sy - p.y) / (q.y - p.y) * (q.x - p.x))
		xs.sort()
		for k: int in range(0, xs.size() - 1, 2):
			_span(e, y, ceili(xs[k] - 0.5), ceili(xs[k + 1] - 0.5), add)
	return box.intersection(Rect2i(Vector2i.ZERO, grid))


## Réduit le masque à sa partie peinte.
func trim(e: Element) -> void:
	if e.mask == null:
		return
	var used: Rect2i = e.mask.get_used_rect()
	if not used.has_area():
		e.mask = null
		e.rect = Rect2i(e.rect.position, Vector2i.ZERO)
		return
	if used.size == e.rect.size:
		return
	e.mask = e.mask.get_region(used)
	e.rect = Rect2i(e.rect.position + used.position, used.size)


# --- Cuisson -------------------------------------------------------------------------------------------------------

## Recalcule les codes de profondeur de `region` (toute la grille par défaut) : sur chaque cellule, l'élément le plus
## proche (ligne de pied la plus basse) l'emporte. Les éléments masqués dans l'éditeur comptent aussi.
func bake(region: Rect2i = Rect2i()) -> void:
	var full := Rect2i(Vector2i.ZERO, grid)
	region = full if not region.has_area() else region.intersection(full)
	if _codes.size() != grid.x * grid.y:
		_codes.resize(grid.x * grid.y)
	for y: int in range(region.position.y, region.end.y):
		var row: int = y * grid.x
		for x: int in range(region.position.x, region.end.x):
			_codes[row + x] = 0
	var scale_y: float = float(cell) / float(map_size.y)
	for e: Element in elements:
		if e.mask == null:
			continue
		var r: Rect2i = e.rect.intersection(region)
		if not r.has_area():
			continue
		var data: PackedByteArray = e.mask.get_data()
		var w: int = e.rect.size.x
		var column_codes := PackedInt32Array()
		column_codes.resize(r.size.x)
		for i: int in r.size.x:
			column_codes[i] = OcclusionMap.encode(e.depth_at(r.position.x + i + 0.5) * scale_y)
		for y: int in range(r.position.y, r.end.y):
			var src: int = ((y - e.rect.position.y) * w + (r.position.x - e.rect.position.x)) * 2 + 1
			var dst: int = y * grid.x + r.position.x
			for i: int in r.size.x:
				if data[src + i * 2] > 127 and column_codes[i] > _codes[dst + i]:
					_codes[dst + i] = column_codes[i]


func code_at(p: Vector2i) -> int:
	return _codes[p.y * grid.x + p.x] if Rect2i(Vector2i.ZERO, grid).has_point(p) else 0


## Région occupée par les éléments (vide s'il n'y en a pas).
func used_rect() -> Rect2i:
	var out := Rect2i()
	for e: Element in elements:
		if e.mask != null and e.rect.has_area():
			out = e.rect if not out.has_area() else out.merge(e.rect)
	return out


## Image RG8 des codes de `region` (R = octet fort, G = octet faible).
func depth_image(region: Rect2i) -> Image:
	var data := PackedByteArray()
	data.resize(region.size.x * region.size.y * 2)
	var i: int = 0
	for y: int in range(region.position.y, region.end.y):
		var row: int = y * grid.x
		for x: int in range(region.position.x, region.end.x):
			var code: int = _codes[row + x]
			data[i] = code >> 8
			data[i + 1] = code & 255
			i += 2
	return Image.create_from_data(region.size.x, region.size.y, false, Image.FORMAT_RG8, data)


## Données lues par le jeu (OcclusionMap.from_data), pour une texture couvrant `region`.
func runtime_data(region: Rect2i) -> Dictionary:
	return {
		"version": OcclusionMap.FORMAT_VERSION,
		"map_size": [map_size.x, map_size.y],
		"cell": cell,
		"depth": DEPTH_FILE,
		"depth_rect": [region.position.x, region.position.y, region.size.x, region.size.y],
	}


# --- Sauvegarde ----------------------------------------------------------------------------------------------------

## Écrit masques, liste des éléments et texture de profondeur, et déclare les données dans le manifeste
## (`declare` faux : fichiers seulement, pour les tests).
func save(declare: bool = true) -> Error:
	var dir_abs: String = ProjectSettings.globalize_path(directory)
	var err: Error = DirAccess.make_dir_recursive_absolute(dir_abs.path_join(MASK_DIR))
	if err != OK:
		return err
	# Masques : sources de travail, ignorées par l'import et l'export de Godot.
	var ignore := FileAccess.open(directory.path_join(MASK_DIR).path_join(".gdignore"), FileAccess.WRITE)
	if ignore:
		ignore.close()
	var listed: Array = []
	var kept: Dictionary = {}
	for e: Element in elements:
		trim(e)
		var mask_file: String = ""
		if e.mask != null:
			mask_file = MASK_DIR.path_join(e.id + ".png")
			err = e.mask.save_png(dir_abs.path_join(mask_file))
			if err != OK:
				return err
			kept[e.id + ".png"] = true
		listed.append({
			"id": e.id, "category": e.category,
			"rect": [e.rect.position.x, e.rect.position.y, e.rect.size.x, e.rect.size.y],
			"mask": mask_file, "hidden": e.hidden,
			"depth": [[snappedf(e.depth_a.x, 0.01), snappedf(e.depth_a.y, 0.01)],
				[snappedf(e.depth_b.x, 0.01), snappedf(e.depth_b.y, 0.01)]],
		})
	_remove_stale_masks(dir_abs.path_join(MASK_DIR), kept)
	bake()
	var region: Rect2i = used_rect()
	if not region.has_area():
		region = Rect2i(0, 0, 1, 1)
	var data: Dictionary = runtime_data(region)
	data["environment"] = str(environment_id)
	data["grid"] = [grid.x, grid.y]
	data["elements"] = listed
	var depth: Image = depth_image(region)
	depth.convert(Image.FORMAT_RGB8)
	err = depth.save_png(dir_abs.path_join(DEPTH_FILE))
	if err != OK:
		return err
	var file := FileAccess.open(directory.path_join(FILE), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	file.close()
	return _declare_in_manifest() if declare else OK


func _remove_stale_masks(mask_dir: String, kept: Dictionary) -> void:
	for name: String in DirAccess.get_files_at(mask_dir):
		if name.ends_with(".png") and not kept.has(name):
			DirAccess.remove_absolute(mask_dir.path_join(name))


func _declare_in_manifest() -> Error:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not manifest is Dictionary:
		return ERR_PARSE_ERROR
	var entries: Dictionary = (manifest as Dictionary).get("entries", {})
	var key: String = str(environment_id)
	if not entries.has(key):
		return ERR_DOES_NOT_EXIST
	var path: String = directory.path_join(FILE)
	if str(entries[key].get("occlusion", "")) == path:
		return OK
	entries[key]["occlusion"] = path
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(manifest, "\t", false) + "\n")
	file.close()
	Assets.load_manifest()
	return OK
