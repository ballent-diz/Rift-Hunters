class_name DraftLevelAudit
extends RefCounted
## Contrôle de composition d'une carte 3D (règles : docs/maps/CARTES_3D.md, « Règles de composition »).
## S'applique à une carte construite, dans l'arbre, navigation cuite (`DraftLevel.bake()`) :
## - chaque escalier relie deux surfaces praticables (bas au sol, haut sur un palier à sa hauteur, chemin court) ;
## - chaque surface surélevée praticable a au moins deux accès ;
## - aucun module flottant, enterré dans le relief ou encastré dans un autre ;
## - toute surface praticable est atteignable depuis le départ (pas de terrasse ni de zone isolée) ;
## - départ, lieu du boss et points d'apparition sur la navigation, atteignables, hors des murs.
## Outil : `tools/level_audit.tscn` (carte de navigation en image) ; essai : `test_draft3d.gd`.

const STAIRS_SCENE := "stairs_wide.tscn"
## Module stairs_wide à l'échelle 1 : palier haut à l'origine, pied à 4,3 m vers +z local, 4 m de haut.
const STAIRS_HEIGHT := 4.0
const STAIRS_RUN := 4.3
const SOLID := 1
const LANDING_GAP := 0.7
const HEIGHT_TOLERANCE := 0.3
const FLOAT_TOLERANCE := 0.2
## Surface praticable isolée signalée au-delà de cette aire (m²) : les dessus de caisses ou de murs n'en sont pas.
const ISLAND_AREA := 4.0
const OVERLAP_RATIO := 0.2
const AGENT_RADIUS := 0.35

var level: DraftLevel
## Incohérences : {kind, text, at}. `kind` : stairs, access, floating, buried, overlap, island, spawn.
var issues: Array[Dictionary] = []
## Escaliers : {bottom, top, ok}.
var stairs: Array[Dictionary] = []
## Surfaces praticables (composantes de la navigation) : {area, center, reachable, polygons}.
var islands: Array[Dictionary] = []
## Emprises au sol des décors pleins (Rect2, plan x/z), pour la carte de navigation.
var footprints: Array[Rect2] = []
var _space: PhysicsDirectSpaceState3D
var _objects: Array[Dictionary] = []
var _fences: Array[RID] = []
var _terrain: Dictionary = {}


static func check(target: DraftLevel) -> DraftLevelAudit:
	var audit := DraftLevelAudit.new()
	audit.level = target
	audit._run()
	return audit


func lines() -> PackedStringArray:
	var result := PackedStringArray()
	for issue: Dictionary in issues:
		var at: Vector3 = issue["at"]
		result.append("%s (%.1f, %.1f, %.1f) : %s" % [issue["kind"], at.x, at.y, at.z, issue["text"]])
	return result


func _run() -> void:
	_space = level.get_world_3d().direct_space_state
	_collect()
	_check_islands()
	_check_stairs()
	_check_objects()
	_check_spots()


func _issue(kind: String, text: String, at: Vector3) -> void:
	issues.append({"kind": kind, "text": text, "at": at})


## Décors (modules et pièces de pack), parois invisibles, relief (`_box` surélevé).
func _collect() -> void:
	for child: Node in level.get_children():
		if child is StaticBody3D:
			var body := child as StaticBody3D
			# Paroi invisible (`_fence`, marquée) ou relief (`_box`, dalles d'une carte).
			if body.has_meta(&"fence") or body.collision_layer & SOLID == 0:
				_fences.append(body.get_rid())
			else:
				_terrain[body.get_rid()] = body.name
			continue
		if not (child is Node3D) or child.scene_file_path == "":
			continue
		var node := child as Node3D
		var bounds: AABB = _bounds(node)
		if bounds.size == Vector3.ZERO:
			continue
		var bodies: Array[RID] = []
		for found: Node in node.find_children("*", "CollisionObject3D", true, false):
			var object := found as CollisionObject3D
			if object.collision_layer & SOLID:
				bodies.append(object.get_rid())
		var entry: Dictionary = {"node": node, "name": node.scene_file_path.get_file().get_basename(),
			"bounds": bounds, "bodies": bodies}
		_objects.append(entry)
		if not bodies.is_empty():
			footprints.append(Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z))


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first: bool = true
	var to_level: Transform3D = level.global_transform.affine_inverse()
	for found: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box: AABB = to_level * mesh.global_transform * mesh.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Surface sous un point (rayon vers le bas), sans les parois invisibles ni les corps exclus. NAN si rien.
func _surface(at: Vector3, reach: float, exclude: Array[RID] = []) -> float:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * reach, SOLID)
	var skip: Array[RID] = _fences.duplicate()
	skip.append_array(exclude)
	query.exclude = skip
	var hit: Dictionary = _space.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else NAN


# --- Navigation : composantes connexes et accessibilité depuis le départ ----------------------------------------

func _check_islands() -> void:
	var mesh: NavigationMesh = level.navigation_mesh
	var vertices: PackedVector3Array = mesh.get_vertices()
	var count: int = mesh.get_polygon_count()
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(count)
	for index: int in count:
		parent[index] = index
	var edges: Dictionary = {}
	for index: int in count:
		var polygon: PackedInt32Array = mesh.get_polygon(index)
		for corner: int in polygon.size():
			var key: String = _edge_key(vertices[polygon[corner]], vertices[polygon[(corner + 1) % polygon.size()]])
			if edges.has(key):
				_union(parent, index, edges[key])
			else:
				edges[key] = index
	var groups: Dictionary = {}
	for index: int in count:
		var root: int = _find(parent, index)
		if not groups.has(root):
			groups[root] = {"area": 0.0, "weighted": Vector3.ZERO, "polygons": PackedInt32Array()}
		# Les tableaux compacts se copient : on réécrit l'entrée.
		var group: Dictionary = groups[root]
		var polygon: PackedInt32Array = mesh.get_polygon(index)
		var area: float = _polygon_area(vertices, polygon)
		group["area"] = float(group["area"]) + area
		group["weighted"] = (group["weighted"] as Vector3) + _polygon_center(vertices, polygon) * area
		var members: PackedInt32Array = group["polygons"]
		members.append(index)
		group["polygons"] = members
	var start_on_nav: Vector3 = level.closest(level.start)
	for group: Dictionary in groups.values():
		var area: float = group["area"]
		var polygons: PackedInt32Array = group["polygons"]
		# Point de contrôle : centre du plus grand polygone (le barycentre peut tomber dans un trou).
		var probe: Vector3 = _polygon_center(vertices, mesh.get_polygon(_largest(vertices, polygons)))
		var route: PackedVector3Array = level.path(start_on_nav, probe)
		var reachable: bool = route.size() >= 1 and route[route.size() - 1].distance_to(probe) < 0.5
		var center: Vector3 = (group["weighted"] as Vector3) / maxf(area, 0.0001)
		var island: Dictionary = {"area": area, "center": center, "reachable": reachable, "polygons": polygons,
			"flagged": false}
		islands.append(island)
		# Seules comptent les surfaces posées sur le sol ou le relief : le dessus d'un mur n'est pas une zone.
		# Une surface fantôme sous un relief plein (sol recouvert par une terrasse) n'en est pas une non plus.
		if not reachable and area >= ISLAND_AREA and _terrain_at(probe + Vector3.DOWN * 0.4).is_valid() \
				and not _solid_at(probe + Vector3.UP * 0.6):
			island["flagged"] = true
			_issue("island", "surface praticable de %.0f m² inaccessible depuis le départ" % area, probe)


func _edge_key(a: Vector3, b: Vector3) -> String:
	var first: String = "%d,%d,%d" % [roundi(a.x * 20.0), roundi(a.y * 20.0), roundi(a.z * 20.0)]
	var second: String = "%d,%d,%d" % [roundi(b.x * 20.0), roundi(b.y * 20.0), roundi(b.z * 20.0)]
	return first + "|" + second if first < second else second + "|" + first


func _find(parent: PackedInt32Array, index: int) -> int:
	var root: int = index
	while parent[root] != root:
		root = parent[root]
	while parent[index] != root:
		var next: int = parent[index]
		parent[index] = root
		index = next
	return root


func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	parent[_find(parent, a)] = _find(parent, b)


func _polygon_area(vertices: PackedVector3Array, polygon: PackedInt32Array) -> float:
	var total: float = 0.0
	for corner: int in range(1, polygon.size() - 1):
		var a: Vector3 = vertices[polygon[0]]
		var ab: Vector3 = vertices[polygon[corner]] - a
		var ac: Vector3 = vertices[polygon[corner + 1]] - a
		total += absf(ab.x * ac.z - ab.z * ac.x) * 0.5
	return total


func _polygon_center(vertices: PackedVector3Array, polygon: PackedInt32Array) -> Vector3:
	var sum := Vector3.ZERO
	for corner: int in polygon.size():
		sum += vertices[polygon[corner]]
	return sum / float(polygon.size())


func _largest(vertices: PackedVector3Array, polygons: PackedInt32Array) -> int:
	var best: int = polygons[0]
	var best_area: float = -1.0
	for index: int in polygons:
		var area: float = _polygon_area(vertices, level.navigation_mesh.get_polygon(index))
		if area > best_area:
			best = index
			best_area = area
	return best


# --- Escaliers -----------------------------------------------------------------------------------------------------

func _check_stairs() -> void:
	var accesses: Dictionary = {}
	for entry: Dictionary in _objects:
		var node: Node3D = entry["node"]
		if not node.scene_file_path.ends_with(STAIRS_SCENE):
			continue
		var xf: Transform3D = level.global_transform.affine_inverse() * node.global_transform
		var down_slope := Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized()
		var rise: float = STAIRS_HEIGHT * xf.basis.y.length()
		var run: float = STAIRS_RUN * xf.basis.z.length()
		var top: Vector3 = xf.origin - down_slope * LANDING_GAP + Vector3.UP * rise
		var bottom: Vector3 = xf.origin + down_slope * (run + LANDING_GAP)
		var bodies: Array[RID] = entry["bodies"]
		var top_ground: float = _surface(top + Vector3.UP * 1.5, 3.0, bodies)
		var bottom_ground: float = _surface(bottom + Vector3.UP * 1.5, 3.0, bodies)
		var problems: PackedStringArray = PackedStringArray()
		if is_nan(top_ground) or absf(top_ground - top.y) > HEIGHT_TOLERANCE:
			problems.append("haut sans palier à %.1f m (surface : %s)" % [top.y, _height_text(top_ground)])
		if is_nan(bottom_ground) or absf(bottom_ground - bottom.y) > HEIGHT_TOLERANCE:
			problems.append("pied sans sol à %.1f m (surface : %s)" % [bottom.y, _height_text(bottom_ground)])
		var top_nav: Vector3 = level.closest(top)
		var bottom_nav: Vector3 = level.closest(bottom)
		if _flat(top_nav).distance_to(_flat(top)) > 0.8 or absf(top_nav.y - top.y) > 0.5:
			problems.append("palier haut non praticable (encombré ou hors navigation)")
		if _flat(bottom_nav).distance_to(_flat(bottom)) > 0.8 or absf(bottom_nav.y - bottom.y) > 0.5:
			problems.append("pied non praticable (encombré ou hors navigation)")
		if problems.is_empty():
			var route: PackedVector3Array = level.path(bottom_nav, top_nav)
			var length: float = _length(route)
			if route.is_empty() or route[route.size() - 1].distance_to(top_nav) > 0.5:
				problems.append("aucun chemin du pied au palier")
			elif length > run + rise + 4.0 * LANDING_GAP + 2.0:
				problems.append("on ne monte pas par cet escalier (détour de %.0f m)" % length)
		var ok: bool = problems.is_empty()
		stairs.append({"bottom": bottom, "top": top, "ok": ok})
		if not ok:
			_issue("stairs", "escalier : " + ", ".join(problems), xf.origin)
			continue
		# Le palier peut être dallé (modules au sol) : on cherche le relief juste sous sa surface.
		var rid: RID = _terrain_at(top + Vector3.DOWN * 0.5)
		if rid.is_valid():
			accesses[rid] = int(accesses.get(rid, 0)) + 1
	for rid: RID in _terrain:
		var body := instance_from_id(PhysicsServer3D.body_get_object_instance_id(rid)) as StaticBody3D
		var shape := body.get_child(0) as CollisionShape3D
		if shape == null or not (shape.shape is BoxShape3D):
			continue
		var top_y: float = body.position.y + (shape.shape as BoxShape3D).size.y * 0.5
		if top_y < 0.6:
			continue
		# Relief praticable seulement (un rempart plein n'a pas de navigation sur le dessus).
		var summit := Vector3(body.position.x, top_y, body.position.z)
		var on_top: Vector3 = level.closest(summit)
		if _flat(on_top).distance_to(_flat(summit)) > 1.5 or absf(on_top.y - top_y) > 0.3:
			continue
		var used: int = int(accesses.get(rid, 0))
		if used < 2:
			_issue("access", "« %s » (%.1f m) : %d escalier(s), deux accès au moins" % [_terrain[rid], top_y, used],
				body.position + Vector3.UP * (top_y - body.position.y))


func _height_text(value: float) -> String:
	return "aucune" if is_nan(value) else "%.1f m" % value


func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


func _length(route: PackedVector3Array) -> float:
	var total: float = 0.0
	for index: int in range(1, route.size()):
		total += route[index - 1].distance_to(route[index])
	return total


# --- Décors : flottants, enterrés, encastrés ------------------------------------------------------------------------

func _check_objects() -> void:
	for entry: Dictionary in _objects:
		var bounds: AABB = entry["bounds"]
		var bodies: Array[RID] = entry["bodies"]
		var name: String = entry["name"]
		var center: Vector3 = bounds.get_center()
		var probes: Array[Vector3] = [Vector3(center.x, bounds.position.y, center.z)]
		for corner: Vector2 in [Vector2(-0.45, -0.45), Vector2(0.45, -0.45), Vector2(-0.45, 0.45), Vector2(0.45, 0.45)]:
			probes.append(Vector3(center.x + corner.x * bounds.size.x, bounds.position.y,
				center.z + corner.y * bounds.size.z))
		# Une dalle porte sa propre collision (elle sert de sol) : on ne l'exclut pas du rayon.
		var support_exclude: Array[RID] = []
		if bounds.size.y > 0.4:
			support_exclude = bodies
		var best_gap: float = INF
		var inside: int = 0
		var inside_name: String = ""
		for probe: Vector3 in probes:
			# Rayon depuis le sommet du décor : un pied légèrement enfoncé dans le sol n'est pas un défaut.
			var ground: float = _surface(Vector3(probe.x, bounds.end.y + 0.1, probe.z), bounds.size.y + 4.0,
				support_exclude)
			if not is_nan(ground):
				best_gap = minf(best_gap, maxf(probe.y - ground, 0.0))
			var terrain: String = _inside_terrain(probe + Vector3.UP * 0.45)
			if terrain != "":
				inside += 1
				inside_name = terrain
		# Décor de bordure (hors de l'aire de jeu) : seule sa face visible compte, pas son appui.
		var inside_bounds: bool = Rect2(level.bounds_min, level.bounds_max - level.bounds_min).has_point(
			Vector2(center.x, center.z))
		# Un décor accroché (bannière, applique) touche un autre décor plein : il ne flotte pas.
		if best_gap > FLOAT_TOLERANCE and inside_bounds and not _attached(bounds, bodies):
			_issue("floating", "%s flotte (%.1f m au-dessus de tout appui)" % [name, best_gap]
				if best_gap < INF else "%s flotte (aucun appui dessous)" % name, center)
		if inside >= 3:
			_issue("buried", "%s enterré dans « %s »" % [name, inside_name], center)
	for first: int in _objects.size():
		var a: Dictionary = _objects[first]
		if (a["bodies"] as Array).is_empty():
			continue
		for second: int in range(first + 1, _objects.size()):
			var b: Dictionary = _objects[second]
			if (b["bodies"] as Array).is_empty():
				continue
			var ratio: float = _overlap(a["bounds"], b["bounds"])
			if ratio > OVERLAP_RATIO:
				var middle: Vector3 = ((a["bounds"] as AABB).get_center() + (b["bounds"] as AABB).get_center()) * 0.5
				_issue("overlap", "%s et %s s'interpénètrent (%d %%)" % [a["name"], b["name"], roundi(ratio * 100.0)],
					middle)


func _attached(bounds: AABB, own: Array[RID]) -> bool:
	var shape := BoxShape3D.new()
	shape.size = bounds.size + Vector3.ONE * 0.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
	query.collision_mask = SOLID
	var skip: Array[RID] = _fences.duplicate()
	skip.append_array(own)
	query.exclude = skip
	return not _space.intersect_shape(query, 1).is_empty()


func _inside_terrain(at: Vector3) -> String:
	var rid: RID = _terrain_at(at)
	return _terrain[rid] if rid.is_valid() and _terrain[rid] != "Ground" else ""


func _solid_at(at: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = SOLID
	return not _space.intersect_point(query, 1).is_empty()


func _terrain_at(at: Vector3) -> RID:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = SOLID
	for hit: Dictionary in _space.intersect_point(query, 8):
		var rid: RID = hit["rid"]
		if _terrain.has(rid):
			return rid
	return RID()


## Part de l'emprise du plus petit des deux décors occupée par l'autre (plan x/z, hauteurs communes).
func _overlap(a: AABB, b: AABB) -> float:
	var low: float = maxf(a.position.y, b.position.y)
	var high: float = minf(a.end.y, b.end.y)
	if high - low < 0.3:
		return 0.0
	var width: float = minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var depth: float = minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
	if width < 0.25 or depth < 0.25:
		return 0.0
	var smaller: float = minf(a.size.x * a.size.z, b.size.x * b.size.z)
	return width * depth / maxf(smaller, 0.01)


# --- Départ, boss, apparitions ---------------------------------------------------------------------------------------

func _check_spots() -> void:
	var start_on_nav: Vector3 = level.closest(level.start)
	if start_on_nav.distance_to(level.start) > 1.0:
		_issue("spawn", "départ hors de la navigation", level.start)
	_check_spot("lieu du boss", level.boss_spot, start_on_nav)
	if level.spawn_points().size() < 12:
		_issue("spawn", "trop peu de points d'apparition (%d)" % level.spawn_points().size(), level.start)
	for spot: Vector3 in level.spawn_points():
		_check_spot("point d'apparition", spot, start_on_nav)


func _check_spot(label: String, spot: Vector3, origin: Vector3) -> void:
	var on_nav: Vector3 = level.closest(spot)
	if _flat(on_nav).distance_to(_flat(spot)) > 1.0:
		_issue("spawn", "%s hors de la navigation" % label, spot)
		return
	var route: PackedVector3Array = level.path(origin, on_nav)
	if route.is_empty() or route[route.size() - 1].distance_to(on_nav) > 0.5:
		_issue("spawn", "%s inaccessible depuis le départ" % label, spot)
	var shape := CapsuleShape3D.new()
	shape.radius = AGENT_RADIUS
	shape.height = 1.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, on_nav + Vector3.UP * 0.85)
	query.collision_mask = SOLID
	query.exclude = _fences
	if not _space.intersect_shape(query, 1).is_empty():
		_issue("spawn", "%s dans un décor" % label, spot)


# --- Carte de navigation (image vue de dessus) ---------------------------------------------------------------------

## Vue de dessus : surfaces praticables (gris selon la hauteur, rouge si isolées), emprises des décors pleins,
## escaliers (pied → palier, vert ou rouge), départ (vert), boss (violet), apparitions (bleu), incohérences (croix
## rouges), parcours d'un essai (orange).
func draw_map(trail: PackedVector3Array = PackedVector3Array(), pixels_per_meter: int = 8) -> Image:
	var low := Vector2(level.bounds_min.x - 2.0, level.bounds_min.y - 2.0)
	var size := Vector2(level.bounds_max.x - level.bounds_min.x + 4.0, level.bounds_max.y - level.bounds_min.y + 4.0)
	var image := Image.create(int(size.x * pixels_per_meter), int(size.y * pixels_per_meter), false, Image.FORMAT_RGB8)
	image.fill(Color("14141c"))
	var scale: float = float(pixels_per_meter)
	var to_pixel := func(at: Vector3) -> Vector2: return (Vector2(at.x, at.z) - low) * scale
	var mesh: NavigationMesh = level.navigation_mesh
	var vertices: PackedVector3Array = mesh.get_vertices()
	# Surfaces inaccessibles d'abord : une surface fantôme sous un relief ne recouvre pas le dessus praticable.
	var ordered: Array[Dictionary] = []
	for island: Dictionary in islands:
		if not island["reachable"]:
			ordered.append(island)
	for island: Dictionary in islands:
		if island["reachable"]:
			ordered.append(island)
	for island: Dictionary in ordered:
		for index: int in island["polygons"] as PackedInt32Array:
			var polygon: PackedInt32Array = mesh.get_polygon(index)
			var points := PackedVector2Array()
			var height: float = 0.0
			for corner: int in polygon.size():
				points.append(to_pixel.call(vertices[polygon[corner]]))
				height += vertices[polygon[corner]].y
			height /= float(polygon.size())
			var shade: float = clampf(0.42 + height * 0.12, 0.3, 0.9)
			var color := Color(shade, shade, shade * 1.08)
			if not island["reachable"]:
				# Rouge : zone isolée signalée ; brun sombre : dessus de décor ou surface sous un relief (sans effet).
				color = Color(0.85, 0.2, 0.2) if island["flagged"] else Color(0.3, 0.24, 0.24)
			_fill_polygon(image, points, color)
	for rect: Rect2 in footprints:
		var corner: Vector2 = to_pixel.call(Vector3(rect.position.x, 0, rect.position.y))
		_outline(image, Rect2(corner, rect.size * scale), Color("4a5a9a"))
	for point: Vector3 in trail:
		_dot(image, to_pixel.call(point), 1, Color("ff9a2e"))
	for step: Dictionary in stairs:
		var color := Color("50e070") if step["ok"] else Color("ff3030")
		_line(image, to_pixel.call(step["bottom"]), to_pixel.call(step["top"]), color)
		_dot(image, to_pixel.call(step["top"]), 3, color)
	for spot: Vector3 in level.spawn_points():
		_dot(image, to_pixel.call(spot), 2, Color("4fb4ff"))
	_dot(image, to_pixel.call(level.start), 5, Color("30ff60"))
	_dot(image, to_pixel.call(level.boss_spot), 5, Color("c050ff"))
	for issue: Dictionary in issues:
		var at: Vector2 = to_pixel.call(issue["at"])
		_line(image, at + Vector2(-6, -6), at + Vector2(6, 6), Color("ff2020"))
		_line(image, at + Vector2(-6, 6), at + Vector2(6, -6), Color("ff2020"))
	return image


func _fill_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	var box := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	for y: int in range(maxi(int(box.position.y), 0), mini(int(box.end.y) + 1, image.get_height())):
		for x: int in range(maxi(int(box.position.x), 0), mini(int(box.end.x) + 1, image.get_width())):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				image.set_pixel(x, y, color)


func _outline(image: Image, rect: Rect2, color: Color) -> void:
	var a: Vector2 = rect.position
	var b: Vector2 = rect.end
	_line(image, a, Vector2(b.x, a.y), color)
	_line(image, Vector2(b.x, a.y), b, color)
	_line(image, b, Vector2(a.x, b.y), color)
	_line(image, Vector2(a.x, b.y), a, color)


func _line(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var steps: int = maxi(int(from.distance_to(to)), 1)
	for step: int in steps + 1:
		var at: Vector2 = from.lerp(to, float(step) / float(steps))
		_dot(image, at, 0, color)


func _dot(image: Image, at: Vector2, radius: int, color: Color) -> void:
	for y: int in range(int(at.y) - radius, int(at.y) + radius + 1):
		for x: int in range(int(at.x) - radius, int(at.x) + radius + 1):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)
