class_name RiftWallVisual
extends Node2D
## Barrière peinte (docs/art/BARRIERES_PEINTES.md) : voile modulaire et bornes de sceau posés sur la ligne de sol
## d'un groupe de rectangles connexes. Un seul nœud par groupe, redessiné seulement quand la pose change (12 im/s),
## en appels groupés sur une même texture. Uniquement le rendu : aucune collision n'est lue ni modifiée.

enum Phase { CLOSED, DISSOLVE, OPEN }

## Longueur au sol d'un module de voile (face ou biais), en unités de jeu.
const MODULE := 128.0
## Bras du module d'angle (est puis sud).
const CORNER_ARM := 64.0
const FPS := 12.0
const ART_SCALE := 0.5
## Coin dont un bras est plus court : jonction sans borne (marches d'un mur en escalier).
const SEAL_MIN_ARM := 40.0
## Hauteurs relatives (0 au sol, 1 au sommet) du plan projeté du biais, marges de crête et de fragments comprises.
const BIAS_LOW := -0.12
const BIAS_HIGH := 1.12
const KINDS: Array[StringName] = [&"face", &"bias", &"corner", &"seal_a", &"seal_b"]

var members: Array[int] = []
var phase: Phase = Phase.CLOSED
## Instant (horloge de l'overlay) du début de l'apparition ou de la dissolution.
var since: float = -INF
var _set: Dictionary = {}
var _pieces: Array[Dictionary] = []
var _seals: PackedVector2Array = PackedVector2Array()
var _veil: Vector2i = Vector2i(-1, -1)
var _seal: Vector2i = Vector2i(-1, -1)


## Jeu de barrière du chapitre (1 à 5) : textures et cellules des cinq modules, chapitre 1 si l'un manque.
static func barrier_set(chapter: int) -> Dictionary:
	var result: Dictionary = {}
	for n: int in [clampi(chapter, 1, 5), 1]:
		result.clear()
		for kind: StringName in KINDS:
			var id := StringName("object.barrier_%d" % n + ("" if kind == &"face" else "." + String(kind)))
			var e: Dictionary = Assets.entry(id)
			var path: String = String(e.get("sheet", ""))
			if path.is_empty() or not ResourceLoader.exists(path):
				break
			var cell: Array = e.get("cell", [0, 0])
			var anchor: Array = e.get("anchor", [0, 0])
			result[kind] = {"texture": load(path), "cell": Vector2(float(cell[0]), float(cell[1])),
				"anchor": Vector2(float(anchor[0]), float(anchor[1])), "animations": e.get("animations", {})}
		if result.size() == KINDS.size():
			result["chapter"] = n
			return result
	return {}


## Chapitre de l'arène dans la campagne principale ; 1 hors campagne (piste de survie, arènes libres).
static func chapter_for(arena_id: StringName) -> int:
	var chapter: ChapterData = Campaign.chapter_of(arena_id)
	if chapter == null or chapter.track != Campaign.MAIN:
		return 1
	return clampi(chapter.order, 1, 5)


static func connected_groups(rects: Array[Rect2]) -> Array[PackedInt32Array]:
	var groups: Array[PackedInt32Array] = []
	var remaining: Array[int] = []
	for i: int in rects.size():
		remaining.append(i)
	while not remaining.is_empty():
		var group := PackedInt32Array([remaining.pop_back()])
		var cursor: int = 0
		while cursor < group.size():
			for j: int in range(remaining.size() - 1, -1, -1):
				if rects[group[cursor]].grow(0.5).intersects(rects[remaining[j]], true):
					group.append(remaining[j])
					remaining.remove_at(j)
			cursor += 1
		groups.append(group)
	return groups


## Ligne de sol d'un groupe : polyligne à segments horizontaux et verticaux, par l'axe long des rectangles.
## Un rectangle seul donne sa ligne médiane ; une chaîne en escalier donne des marches qui suivent ses centres.
static func ground_path(rects: Array[Rect2]) -> PackedVector2Array:
	var axis := _long_axis(rects[0])
	if rects.size() > 1:
		var longest: float = -1.0
		for a: Rect2 in rects:
			for b: Rect2 in rects:
				var distance: float = a.get_center().distance_squared_to(b.get_center())
				if distance > longest:
					longest = distance
					axis = b.get_center() - a.get_center()
	var horizontal: bool = absf(axis.x) >= absf(axis.y)
	var ordered: Array[Rect2] = rects.duplicate()
	ordered.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.get_center().dot(axis) < b.get_center().dot(axis))
	var raw: Array[Vector2] = [_end_point(ordered, true, horizontal)]
	for rect: Rect2 in ordered:
		raw.append(rect.get_center())
	raw.append(_end_point(ordered, false, horizontal))
	var points := PackedVector2Array([raw[0]])
	for i: int in range(1, raw.size()):
		var prev: Vector2 = points[-1]
		var next: Vector2 = raw[i]
		if not is_equal_approx(prev.x, next.x) and not is_equal_approx(prev.y, next.y):
			var across: bool = horizontal
			if i >= 2 and i < raw.size() - 1:
				across = _horizontal_first(ordered[i - 2], ordered[i - 1], horizontal)
			_push(points, Vector2(next.x, prev.y) if across else Vector2(prev.x, next.y))
		_push(points, next)
	return points


static func _long_axis(rect: Rect2) -> Vector2:
	return Vector2.RIGHT if rect.size.x >= rect.size.y else Vector2.DOWN


static func _is_strip(rect: Rect2) -> bool:
	return maxf(rect.size.x, rect.size.y) >= 1.5 * minf(rect.size.x, rect.size.y)


## Entre deux rectangles : quitter le premier selon son axe long, ou entrer dans le second selon le sien
## (angle en L entre deux bandes), sinon suivre l'axe dominant de la chaîne.
static func _horizontal_first(a: Rect2, b: Rect2, horizontal: bool) -> bool:
	if _is_strip(a):
		return _long_axis(a) == Vector2.RIGHT
	if _is_strip(b):
		return _long_axis(b) == Vector2.DOWN
	return horizontal


## Extrémité d'une chaîne : bord du rectangle d'extrémité, le long de son axe long (ou de l'axe dominant).
static func _end_point(ordered: Array[Rect2], first: bool, horizontal: bool) -> Vector2:
	var rect: Rect2 = ordered[0] if first else ordered[-1]
	var axis: Vector2 = Vector2.RIGHT if horizontal else Vector2.DOWN
	if _is_strip(rect):
		axis = _long_axis(rect)
	var away: float = -1.0 if first else 1.0
	if ordered.size() > 1:
		var neighbour: Vector2 = (ordered[1] if first else ordered[-2]).get_center()
		var side: float = (rect.get_center() - neighbour).dot(axis)
		if not is_zero_approx(side):
			away = signf(side)
	return rect.get_center() + axis * away * absf(rect.size.dot(axis)) * 0.5


## Ajoute un point en fusionnant les doublons et les points alignés.
static func _push(points: PackedVector2Array, point: Vector2) -> void:
	if points[-1].is_equal_approx(point):
		return
	if points.size() >= 2:
		var a: Vector2 = points[-2]
		var b: Vector2 = points[-1]
		if (is_equal_approx(a.x, b.x) and is_equal_approx(b.x, point.x)) \
				or (is_equal_approx(a.y, b.y) and is_equal_approx(b.y, point.y)):
			points[-1] = point
			return
	points.append(point)


## Pose le long de la polyligne : modules face (horizontaux, de gauche à droite) et biais (verticaux, de haut en bas)
## tous les 128 unités, le dernier coupé à sa longueur ; module d'angle pour un pli est→sud aux bras assez longs ;
## bornes aux extrémités et aux coins. Pièces : {kind, origin (départ au sol), length}.
static func layout(path: PackedVector2Array) -> Dictionary:
	var count: int = path.size() - 1
	var trim_start := PackedFloat32Array()
	var trim_end := PackedFloat32Array()
	trim_start.resize(count)
	trim_end.resize(count)
	var pieces: Array[Dictionary] = []
	var seals := PackedVector2Array()
	if count < 1:
		return {"pieces": pieces, "seals": seals}
	seals.append(path[0])
	for i: int in range(1, count):
		var corner: Vector2 = path[i]
		var before: Vector2 = path[i - 1]
		var after: Vector2 = path[i + 1]
		var arm_before: float = before.distance_to(corner)
		var arm_after: float = after.distance_to(corner)
		var horizontal_first: bool = is_equal_approx(before.y, corner.y)
		var west: Vector2 = before if horizontal_first else after
		var south: Vector2 = after if horizontal_first else before
		var east_south: bool = west.x < corner.x and south.y > corner.y
		if east_south and minf(arm_before, arm_after) >= CORNER_ARM:
			trim_end[i - 1] = CORNER_ARM
			trim_start[i] = CORNER_ARM
			pieces.append({"kind": &"corner", "origin": corner - Vector2(CORNER_ARM, 0), "length": CORNER_ARM})
		if minf(arm_before, arm_after) >= SEAL_MIN_ARM:
			seals.append(corner)
	seals.append(path[-1])
	for i: int in count:
		var dir: Vector2 = (path[i + 1] - path[i]).normalized()
		var a: Vector2 = path[i] + dir * trim_start[i]
		var b: Vector2 = path[i + 1] - dir * trim_end[i]
		var vertical: bool = is_equal_approx(a.x, b.x)
		var start: Vector2 = a if (a.y < b.y if vertical else a.x < b.x) else b
		var total: float = a.distance_to(b)
		var step: Vector2 = Vector2.DOWN if vertical else Vector2.RIGHT
		var done: float = 0.0
		while total - done > 0.5:
			var length: float = minf(MODULE, total - done)
			pieces.append({"kind": &"bias" if vertical else &"face", "origin": start + step * done, "length": length})
			done += length
	pieces.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		return (p["origin"] as Vector2).y < (q["origin"] as Vector2).y)
	return {"pieces": pieces, "seals": seals}


func setup(rects: Array[Rect2], indices: Array[int], barrier: Dictionary, p_phase: Phase, p_since: float) -> void:
	members = indices
	_set = barrier
	phase = p_phase
	since = p_since
	var placed: Dictionary = layout(ground_path(rects))
	_pieces.assign(placed["pieces"])
	_seals = placed["seals"]
	var sorted: Array[Vector2] = []
	sorted.assign(_seals)
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	_seals = PackedVector2Array(sorted)


func piece_count() -> int:
	return _pieces.size()


func seal_count() -> int:
	return _seals.size()


## Choisit les poses à l'instant `clock` (horloge partagée de l'overlay) ; redessine seulement si elles changent.
func advance(clock: float) -> void:
	var elapsed: float = clock - since
	var veil := Vector2i(-1, -1)
	var seal := Vector2i(-1, -1)
	match phase:
		Phase.CLOSED:
			veil = _pose(&"loop", clock, true)
			if elapsed >= 0.0 and elapsed < clip_duration(_set, &"appear"):
				veil = _pose(&"appear", elapsed, false)
			seal = _pose(&"idle", clock, true, &"seal_a")
		Phase.DISSOLVE:
			veil = _pose(&"dissolve", elapsed, false)
			seal = _pose(&"open", elapsed, false, &"seal_a")
		Phase.OPEN:
			seal = _pose(&"open", INF, false, &"seal_a")
	if veil != _veil or seal != _seal:
		_veil = veil
		_seal = seal
		queue_redraw()


## Durée d'un clip du voile (images / 12 im/s), pour l'horloge visuelle seulement.
static func clip_duration(barrier: Dictionary, anim: StringName) -> float:
	var info: Dictionary = (barrier.get(&"face", {}) as Dictionary).get("animations", {}).get(String(anim), {})
	return float(info.get("frames", 0)) / float(info.get("fps", FPS))


## (ligne, image) d'une animation au temps `t`.
func _pose(anim: StringName, t: float, looping: bool, kind: StringName = &"face") -> Vector2i:
	var info: Dictionary = (_set.get(kind, {}) as Dictionary).get("animations", {}).get(String(anim), {})
	var frames: int = maxi(int(info.get("frames", 1)), 1)
	var index: int = int(floorf(minf(t, 1e6) * float(info.get("fps", FPS))))
	index = posmod(index, frames) if looping else clampi(index, 0, frames - 1)
	return Vector2i(int(info.get("row", 0)), index)


func _draw() -> void:
	if _set.is_empty():
		return
	if _veil.x >= 0:
		for piece: Dictionary in _pieces:
			_draw_piece(piece)
	if _seal.x >= 0:
		for i: int in _seals.size():
			_draw_cell(&"seal_a" if i % 2 == 0 else &"seal_b", _seals[i], _seal)


func _draw_piece(piece: Dictionary) -> void:
	var kind: StringName = piece["kind"]
	var origin: Vector2 = piece["origin"]
	var length: float = piece["length"]
	match kind:
		&"corner":
			_draw_cell(kind, origin, _veil)
		&"face":
			var info: Dictionary = _set[kind]
			var cell: Vector2 = info["cell"]
			var anchor: Vector2 = info["anchor"]
			var width: float = length / ART_SCALE
			var source := Rect2(Vector2(_veil.y, _veil.x) * cell, Vector2(width, cell.y))
			draw_texture_rect_region(info["texture"], Rect2(origin - anchor * ART_SCALE,
				Vector2(width, cell.y) * ART_SCALE), source)
		&"bias":
			_draw_bias(origin, length)


## Biais coupé le long de sa ligne de sol : parallélogramme du plan projeté (paramètre t de 0 à la longueur).
func _draw_bias(origin: Vector2, length: float) -> void:
	var info: Dictionary = _set[&"bias"]
	var cell: Vector2 = info["cell"]
	var anchor: Vector2 = info["anchor"]
	var texture: Texture2D = info["texture"]
	var offset: Vector2 = Vector2(_veil.y, _veil.x) * cell
	var size := Vector2(texture.get_width(), texture.get_height())
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner: Vector2 in [Vector2(0, BIAS_LOW), Vector2(0, BIAS_HIGH), Vector2(1, BIAS_HIGH), Vector2(1, BIAS_LOW)]:
		var t: float = corner.x * length / ART_SCALE
		var h: float = corner.y
		# Projection enregistrée du voile : sommet décalé de 40 unités à droite pour 100 de haut.
		var pixel := Vector2(anchor.x + 80.0 * h, anchor.y + t - 200.0 * h)
		points.append(origin + (pixel - anchor) * ART_SCALE)
		uvs.append((offset + pixel) / size)
	draw_colored_polygon(points, Color.WHITE, uvs, texture)


func _draw_cell(kind: StringName, foot: Vector2, pose: Vector2i) -> void:
	var info: Dictionary = _set[kind]
	var cell: Vector2 = info["cell"]
	var anchor: Vector2 = info["anchor"]
	draw_texture_rect_region(info["texture"], Rect2(foot - anchor * ART_SCALE, cell * ART_SCALE),
		Rect2(Vector2(pose.y, pose.x) * cell, cell))
