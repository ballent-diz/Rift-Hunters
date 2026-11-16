class_name DraftLevelRing
extends DraftLevel
## Sixième niveau de la base 3D : l'Anneau de la Faille. Carte ronde, sans étage ni escalier : une couronne de terre
## (rayons 28 → 46 m) fait le tour d'un gouffre où saigne la Faille ; au centre, un îlot (rayon 10 m) relié à
## l'anneau par deux passerelles seulement. Le relief, c'est le vide : ses bords arrêtent la marche, pas les tirs.
##
## Lecture, depuis la Porte (sud) : on fait le tour de l'anneau, l'îlot du boss toujours en vue.
## - la Porte (sud, 30° → 150°) : départ ;
## - l'Ossuaire (ouest, 150° → 270°) et les Forges (est, 270° → 30°) ;
## - trois murs radiaux coupent l'anneau, chacun percé d'une brèche de 4 m (goulets pour semer la horde) ;
## - deux passerelles (210° et 330°) mènent à l'îlot central, lieu du boss.
## Angles : x = r·cos a, z = r·sin a ; 90° est au sud (côté caméra). Pièces : KayKit Dungeon Remastered (CC0).

const MIN := Vector2(-50.0, -50.0)
const MAX := Vector2(50.0, 50.0)
const RING_INNER := 28.0
const RING_OUTER := 46.5
const ISLAND := 10.0
const START := Vector3(0, 0.2, 37)
const BOSS_SPOT := Vector3(0, 0.2, 0)
const DIVIDERS: Array[float] = [30.0, 150.0, 270.0]
const BRIDGES: Array[float] = [210.0, 330.0]
const BRIDGE_WIDTH := 5.0
const BREACH := Vector2(34.0, 38.0)
const PACK := "res://draft3d/dungeon/%s.glb"
const EARTH := Color("2a2630")
const ISLAND_STONE := Color("3a3442")
const ABYSS := Color("1a0d2b")
const RIFT := Color("b06bff")
const SEGMENTS := 72
const FLOOR_Y := 0.01


func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	sky = Color("07060f")
	ambient = Color("7a6fa8")
	sun = Color("b7a6ff")
	sun_energy = 0.4
	_abyss()
	_ring()
	_island()
	_bridges()
	_rampart()
	_dividers()
	_road()
	_setup_navigation()


static func polar(angle: float, radius: float, height: float = 0.0) -> Vector3:
	var a: float = deg_to_rad(angle)
	return Vector3(cos(a) * radius, height, sin(a) * radius)


## Angle (yaw) qui aligne l'axe x d'une pièce sur la tangente, ou sur le rayon.
static func tangent_yaw(angle: float) -> float:
	return -(angle + 90.0)


static func radial_yaw(angle: float) -> float:
	return -angle


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box") -> Node3D:
	return _prop(PACK % id, at, yaw, 1.0, collision, true)


## Dalle en prisme (polygone convexe vu de dessus, du sommet `top` sur `depth` m), avec sa collision pleine.
func _slab(id: String, points: PackedVector2Array, top: float, depth: float, color: Color, visible_mesh: bool = true) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom: float = top - depth
	for index: int in range(1, points.size() - 1):
		tool.set_normal(Vector3.UP)
		for corner: Vector2 in [points[0], points[index], points[index + 1]]:
			tool.add_vertex(Vector3(corner.x, top, corner.y))
	for index: int in points.size():
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		var side: Vector2 = (b - a).orthogonal().normalized()
		var normal := Vector3(-side.x, 0, -side.y)
		for corner: Vector3 in [Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b.x, bottom, b.y),
				Vector3(a.x, top, a.y), Vector3(b.x, bottom, b.y), Vector3(a.x, bottom, a.y)]:
			tool.set_normal(normal)
			tool.add_vertex(corner)
	var body := StaticBody3D.new()
	body.name = id
	add_child(body)
	if visible_mesh:
		body.add_child(_mesh_of(tool, color))
	var hull := PackedVector3Array()
	for corner: Vector2 in points:
		hull.append(Vector3(corner.x, top, corner.y))
		hull.append(Vector3(corner.x, bottom, corner.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


func _mesh_of(tool: SurfaceTool, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	return mesh


## Bord du vide : paroi qui n'arrête que la marche (couche 8), de `a` à `b` (plan x/z).
func _edge(a: Vector2, b: Vector2) -> void:
	var body := StaticBody3D.new()
	body.name = "Edge"
	body.collision_layer = 8
	add_child(body)
	var middle: Vector2 = (a + b) * 0.5
	body.position = Vector3(middle.x, 1.0, middle.y)
	body.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	var shape := BoxShape3D.new()
	shape.size = Vector3(a.distance_to(b) + 0.3, 3.0, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


func _arc(radius: float, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps: int = maxi(2, ceili(absf(to - from) / (360.0 / SEGMENTS)))
	for step: int in steps + 1:
		var at: Vector3 = polar(lerpf(from, to, float(step) / steps), radius)
		points.append(Vector2(at.x, at.z))
	return points


## Gouffre : fond lointain et lueurs violettes qui montent de la Faille.
func _abyss() -> void:
	# Fond sans collision : la navigation ne doit pas s'y poser.
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Abyss"
	var disk := CylinderMesh.new()
	disk.top_radius = RING_INNER + 4.0
	disk.bottom_radius = RING_INNER + 4.0
	disk.height = 0.5
	floor_mesh.mesh = disk
	var material := StandardMaterial3D.new()
	material.albedo_color = ABYSS
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = material
	floor_mesh.position = Vector3(0, -16, 0)
	add_child(floor_mesh)
	for step: int in 6:
		_light(polar(30.0 + 60.0 * step, 19.0, -5.0), RIFT, 2.4, 16.0)


## Anneau : collision par secteurs de 5° ; un seul maillage (dessus, falaise intérieure, falaise extérieure) pour
## que la falaise se lise d'un seul tenant. Bord intérieur fermé à la marche, sauf aux passerelles.
func _ring() -> void:
	var step: float = 360.0 / SEGMENTS
	var outer: float = RING_OUTER + 1.5
	var depth: float = 7.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in SEGMENTS:
		var a0: float = index * step
		var a1: float = a0 + step
		var inner_a: Vector3 = polar(a0, RING_INNER)
		var inner_b: Vector3 = polar(a1, RING_INNER)
		var outer_a: Vector3 = polar(a0, outer)
		var outer_b: Vector3 = polar(a1, outer)
		_slab("Ring", PackedVector2Array([Vector2(inner_a.x, inner_a.z), Vector2(outer_a.x, outer_a.z),
			Vector2(outer_b.x, outer_b.z), Vector2(inner_b.x, inner_b.z)]), 0.0, depth, EARTH, false)
		_quad(tool, [inner_a, outer_a, outer_b, inner_b], Vector3.UP)
		var down := Vector3.DOWN * depth
		_quad(tool, [inner_a, inner_b, inner_b + down, inner_a + down], -polar(a0 + step * 0.5, 1.0))
		_quad(tool, [outer_a, outer_b, outer_b + down, outer_a + down], polar(a0 + step * 0.5, 1.0))
	add_child(_mesh_of(tool, EARTH))
	_rim(RING_INNER + 0.1, false)


func _quad(tool: SurfaceTool, corners: Array[Vector3], normal: Vector3) -> void:
	for index: int in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(normal)
		tool.add_vertex(corners[index])


## Ferme un cercle à la marche, en laissant passer les passerelles.
func _rim(radius: float, island: bool) -> void:
	var step: float = 360.0 / SEGMENTS
	for index: int in SEGMENTS:
		var middle: float = (index + 0.5) * step
		var blocked: bool = true
		for bridge: float in BRIDGES:
			var half_angle: float = rad_to_deg(BRIDGE_WIDTH * 0.5 / radius) + step * 0.5
			if absf(angle_difference(deg_to_rad(middle), deg_to_rad(bridge))) < deg_to_rad(half_angle):
				blocked = false
		if blocked:
			var a: Vector3 = polar(index * step, radius - (0.15 if island else -0.15))
			var b: Vector3 = polar((index + 1) * step, radius - (0.15 if island else -0.15))
			_edge(Vector2(a.x, a.z), Vector2(b.x, b.z))


## Îlot central : dalle ronde un peu plus claire, lieu du boss, quatre piliers d'abri, cœur de la Faille.
func _island() -> void:
	_slab("Island", _arc(ISLAND, 0.0, 360.0 - 360.0 / SEGMENTS), 0.0, 9.0, ISLAND_STONE)
	_rim(ISLAND - 0.1, true)
	for angle: float in [45.0, 135.0, 225.0, 315.0]:
		_piece("pillar", polar(angle, 6.0))
	_light(Vector3(0, 3.5, 0), RIFT, 2.6, 13.0)


## Passerelles de l'îlot à l'anneau, piliers aux deux têtes, bords fermés à la marche.
func _bridges() -> void:
	for angle: float in BRIDGES:
		var dir := Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle)))
		var side: Vector2 = dir.orthogonal() * BRIDGE_WIDTH * 0.5
		var near: Vector2 = dir * (ISLAND - 0.6)
		var far: Vector2 = dir * (RING_INNER + 0.6)
		_slab("Bridge", PackedVector2Array([near - side, far - side, far + side, near + side]), 0.0, 1.2,
			ISLAND_STONE.darkened(0.1))
		_edge(near - side, far - side)
		_edge(near + side, far + side)
		for radius: float in [ISLAND + 0.8, RING_INNER - 0.8]:
			for side_sign: float in [-1.0, 1.0]:
				var at: Vector2 = dir * radius + dir.orthogonal() * side_sign * (BRIDGE_WIDTH * 0.5 + 0.8)
				_piece("pillar", Vector3(at.x, 0, at.y))


## Rempart circulaire (murs tangents de 4 m) ; au sud, côté caméra, un parapet bas qui ne cache pas le jeu.
func _rampart() -> void:
	var count: int = 74
	for index: int in count:
		var angle: float = 360.0 * index / count
		var south: bool = absf(angle - 90.0) < 40.0
		var id: String = "barrier_column" if south else ("wall_pillar" if index % 5 == 0 else "wall")
		_piece(id, polar(angle, RING_OUTER + 0.6), tangent_yaw(angle), "none")
	_rim(RING_OUTER, true)


## Murs radiaux entre les secteurs, percés d'une brèche de 4 m au milieu de l'anneau.
func _dividers() -> void:
	for angle: float in DIVIDERS:
		var yaw: float = radial_yaw(angle)
		_piece("wall", polar(angle, 30.0), yaw)
		_piece("wall_half", polar(angle, 33.0), yaw)
		_piece("wall_half", polar(angle, 39.0), yaw)
		_piece("wall", polar(angle, 42.0), yaw)
		_piece("wall_half", polar(angle, 45.0), yaw)
		_torch(polar(angle + 4.0, BREACH.x - 1.0))


## Chemin de ronde pavé au milieu de l'anneau (dalles tangentes), repère de lecture du tour.
func _road() -> void:
	var radius: float = 36.0
	var step: float = rad_to_deg(4.0 / radius)
	var angle: float = 0.0
	while angle < 360.0:
		_piece("floor_tile_large", polar(angle, radius, FLOOR_Y), tangent_yaw(angle), "none")
		angle += step


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index: int in 45:
		var angle: float = 8.0 * index
		result.append(polar(angle, RING_OUTER - 2.0))
		result.append(polar(angle + 4.0, RING_INNER + 2.0))
	return result
