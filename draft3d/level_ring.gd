class_name DraftLevelRing
extends DraftLevel
## Sixième niveau de la base 3D : l'Anneau de la Faille. Carte ronde, sans étage ni escalier : une couronne de terre
## (rayons 28 → 46 m) fait le tour d'un gouffre où saigne la Faille ; au centre, un îlot (rayon 20 m) relié à
## l'anneau par deux passerelles seulement. Le relief, c'est le vide : ses bords arrêtent la marche, pas les tirs.
##
## Lecture, depuis la Porte (sud) : on fait le tour de l'anneau, l'îlot du boss toujours en vue.
## - la Porte (sud, 30° → 150°) : départ ;
## - l'Ossuaire (ouest, 150° → 270°) et les Forges (est, 270° → 30°) ;
## - trois murs radiaux coupent l'anneau, chacun percé d'une brèche de 4 m (goulets pour semer la horde) ;
## - deux passerelles (210° et 330°) mènent à l'îlot central, lieu du boss.
## Angles : x = r·cos a, z = r·sin a ; 90° est au sud (côté caméra). Pièces : KayKit Dungeon Remastered (CC0).
##
## C'est le sommet de la tour du chapitre 6 (DraftTower). Les étages inférieurs reprennent l'anneau extérieur, avec
## un puits ouvert au centre (ni îlot ni passerelle), d'autres murs radiaux et une rampe le long du rempart : fermée
## par une herse, elle s'ouvre à la fin de l'étage et mène au palier de sortie (`exit_point`).

const MIN := Vector2(-50.0, -50.0)
const MAX := Vector2(50.0, 50.0)
const RING_INNER := 28.0
const RING_OUTER := 46.5
const ISLAND := 20.0
const START := Vector3(0, 0.2, 37)
const BOSS_SPOT := Vector3(0, 0.2, 0)
## Étages (`floor_index`) : murs radiaux, rampe (angle du pied → angle du haut, Vector2.ZERO : aucune) et angle
## d'arrivée (celui de la sortie de l'étage d'en dessous). 0 : la Garnison, 1 : les Cellules (gardien), 2 : le Sommet.
const FLOORS: Array[Dictionary] = [
	{"dividers": [0.0, 180.0], "ramp": Vector2(240.0, 276.0), "arrival": 90.0},
	{"dividers": [20.0, 160.0, 230.0, 330.0], "ramp": Vector2(140.0, 102.0), "arrival": 281.0},
	{"dividers": [30.0, 150.0, 270.0], "ramp": Vector2.ZERO, "arrival": 90.0},
]
const TOP_FLOOR := 2
const RAMP_RISE := 3.0
## Rampe : bande de l'anneau qu'elle occupe (rayons), palier en haut (degrés au-delà du haut de la rampe).
const RAMP_BAND := Vector2(41.2, 47.8)
const LANDING_SPAN := 10.0
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
## Décors pleins posés : les points d'apparition s'en écartent (un point recalé contre un décor y resterait coincé).
const SPAWN_CLEARANCE := 3.5

## Étage de la tour ; le sommet par défaut (DraftLevel.create(6)).
var floor_index: int = TOP_FLOOR
var _occupied: Array[Vector3] = []
var _gate: Array[Node] = []


func build() -> void:
	name = "Level"
	var conf: Dictionary = FLOORS[floor_index]
	bounds_min = MIN
	bounds_max = MAX
	start = START if floor_index != 1 else polar(conf["arrival"], 41.0, 0.2)
	boss_spot = BOSS_SPOT if summit() else polar(float(conf["arrival"]) + 180.0, 37.0, 0.2)
	sky = Color("07060f")
	ambient = Color("7a6fa8")
	sun = Color("b7a6ff")
	sun_energy = 0.4
	_abyss()
	_ring()
	if summit():
		_island()
		_bridges()
	_rampart()
	_dividers(conf["dividers"])
	_road()
	match floor_index:
		0:
			_gate_decor()
			_garrison()
		1:
			_arrival_door(conf["arrival"])
			_cells()
		_:
			_gate_decor()
			_ossuary()
			_forges()
	if has_ramp():
		_ramp()
	_rim_glow()
	_setup_navigation()


func summit() -> bool:
	return floor_index == TOP_FLOOR


func has_ramp() -> bool:
	return FLOORS[floor_index]["ramp"] != Vector2.ZERO


## Hauteur de la rampe à cet angle (0 hors de la rampe, RAMP_RISE sur le palier).
func ramp_height(angle: float) -> float:
	if not has_ramp():
		return 0.0
	var ramp: Vector2 = FLOORS[floor_index]["ramp"]
	var along: float = _along(angle, ramp)
	var total: float = absf(ramp.y - ramp.x)
	if along < 0.0 or along > total + LANDING_SPAN:
		return 0.0
	return RAMP_RISE * minf(along / total, 1.0)


## Degrés parcourus depuis le pied de la rampe, dans le sens de la montée (négatif avant le pied).
func _along(angle: float, ramp: Vector2) -> float:
	var direction: float = signf(ramp.y - ramp.x)
	return wrapf((angle - ramp.x) * direction + 180.0, 0.0, 360.0) - 180.0


func _in_ramp(angle: float, margin: float = 0.0) -> bool:
	if not has_ramp():
		return false
	var ramp: Vector2 = FLOORS[floor_index]["ramp"]
	var along: float = _along(angle, ramp)
	return along > -margin and along < absf(ramp.y - ramp.x) + LANDING_SPAN + margin


## La herse du pied de la rampe se lève : la sortie de l'étage est ouverte.
func open_ramp() -> void:
	# Herse et muret masqués (le rendu pixel garde une référence à leurs maillages), paroi supprimée.
	for node: Node in _gate:
		if node is StaticBody3D:
			node.queue_free()
		else:
			(node as Node3D).visible = false
	_gate.clear()


static func polar(angle: float, radius: float, height: float = 0.0) -> Vector3:
	var a: float = deg_to_rad(angle)
	return Vector3(cos(a) * radius, height, sin(a) * radius)


## Angle (yaw) qui aligne l'axe x d'une pièce sur la tangente, ou sur le rayon.
static func tangent_yaw(angle: float) -> float:
	return -(angle + 90.0)


static func radial_yaw(angle: float) -> float:
	return -angle


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box") -> Node3D:
	if collision != "none":
		_occupied.append(at)
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
func _edge(a: Vector2, b: Vector2, height: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Edge"
	body.collision_layer = 8
	add_child(body)
	var middle: Vector2 = (a + b) * 0.5
	body.position = Vector3(middle.x, 1.0 + height, middle.y)
	body.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	var shape := BoxShape3D.new()
	shape.size = Vector3(a.distance_to(b) + 0.3, 3.0, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body


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
		_light(polar(30.0 + 60.0 * step, 24.0, -5.0), RIFT, 2.4, 12.0)


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


## Ferme un cercle à la marche, en laissant passer les passerelles du sommet ; au-dessus de la rampe, la paroi
## monte avec elle.
func _rim(radius: float, island: bool) -> void:
	var step: float = 360.0 / SEGMENTS
	for index: int in SEGMENTS:
		var middle: float = (index + 0.5) * step
		var blocked: bool = true
		for bridge: float in (BRIDGES if summit() else []):
			var half_angle: float = rad_to_deg(BRIDGE_WIDTH * 0.5 / radius) + step * 0.5
			if absf(angle_difference(deg_to_rad(middle), deg_to_rad(bridge))) < deg_to_rad(half_angle):
				blocked = false
		if blocked:
			var a: Vector3 = polar(index * step, radius - (0.15 if island else -0.15))
			var b: Vector3 = polar((index + 1) * step, radius - (0.15 if island else -0.15))
			var lift: float = ramp_height(middle) if radius > RAMP_BAND.x else 0.0
			_edge(Vector2(a.x, a.z), Vector2(b.x, b.z), lift)


## Îlot central : dalle ronde un peu plus claire, lieu du boss, quatre piliers d'abri, cœur de la Faille.
func _island() -> void:
	_slab("Island", _arc(ISLAND, 0.0, 360.0 - 360.0 / SEGMENTS), 0.0, 9.0, ISLAND_STONE)
	_rim(ISLAND - 0.1, true)
	for angle: float in [45.0, 135.0, 225.0, 315.0]:
		_piece("pillar", polar(angle, 11.0))
	# Deux anneaux pavés sur l'îlot (dalles tangentes, sans collision) ; au cœur, la Faille affleure.
	for radius: float in [8.0, 16.0]:
		_paved_circle(radius)
	for angle: float in [0.0, 90.0, 180.0, 270.0]:
		_piece("candle_triple", polar(angle, 4.0), 0.0, "none")
	_light(Vector3(0, 4.5, 0), RIFT, 2.8, 20.0)


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
		for radius: float in [ISLAND + 2.0, (ISLAND + RING_INNER) * 0.5, RING_INNER - 2.0]:
			var tile: Vector2 = dir * radius
			_piece("floor_tile_large", Vector3(tile.x, FLOOR_Y + 0.005, tile.y), radial_yaw(angle), "none")
		for radius: float in [ISLAND + 0.8, RING_INNER - 0.8]:
			for side_sign: float in [-1.0, 1.0]:
				var at: Vector2 = dir * radius + dir.orthogonal() * side_sign * (BRIDGE_WIDTH * 0.5 + 0.8)
				_piece("pillar", Vector3(at.x, 0, at.y))


## Rempart circulaire (murs tangents de 4 m) ; au sud, côté caméra, un parapet bas qui ne cache pas le jeu. Le long
## de la rampe, il monte avec elle ; au palier, une porte ouvre sur l'escalier de la tour (sortie de l'étage).
func _rampart() -> void:
	var count: int = 74
	var exit_angle: float = INF
	if has_ramp():
		var ramp: Vector2 = FLOORS[floor_index]["ramp"]
		exit_angle = ramp.y + signf(ramp.y - ramp.x) * LANDING_SPAN * 0.5
		exit_point = polar(exit_angle, 44.0, RAMP_RISE + 0.2)
	for index: int in count:
		var angle: float = 360.0 * index / count
		var at: Vector3 = polar(angle, RING_OUTER + 0.6, ramp_height(angle))
		if absf(angle_difference(deg_to_rad(angle), deg_to_rad(exit_angle))) < deg_to_rad(2.5):
			_module("wall_doorway", at, Vector3.ONE, tangent_yaw(angle))
			_light(polar(angle, 45.5, RAMP_RISE + 2.0), RIFT, 2.2, 6.0)
			continue
		var south: bool = absf(angle - 90.0) < 40.0
		var id: String = "barrier_column" if south else ("wall_pillar" if index % 5 == 0 else "wall")
		_piece(id, at, tangent_yaw(angle), "none")
	_rim(RING_OUTER, true)


## Porte d'arrivée dans le rempart (on y débouche de l'étage d'en dessous).
func _arrival_door(angle: float) -> void:
	_module("wall_doorway", polar(angle, RING_OUTER + 0.4), Vector3.ONE, tangent_yaw(angle))
	_light(polar(angle, 44.5, 2.5), RIFT, 2.0, 7.0)
	_occupied.append(polar(angle, 44.0))


## Rampe le long du rempart (pente douce, pas de marche) et palier ; herse au pied, fermée jusqu'à la fin de l'étage.
func _ramp() -> void:
	var ramp: Vector2 = FLOORS[floor_index]["ramp"]
	var direction: float = signf(ramp.y - ramp.x)
	var total: float = absf(ramp.y - ramp.x) + LANDING_SPAN
	var steps: int = ceili(total / 3.0)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in steps:
		var a0: float = ramp.x + direction * total * index / steps
		var a1: float = ramp.x + direction * total * (index + 1) / steps
		var h0: float = ramp_height(a0) if index > 0 else 0.0
		var h1: float = ramp_height(a1) if index < steps - 1 else RAMP_RISE
		var top: Array[Vector3] = [polar(a0, RAMP_BAND.x, h0), polar(a0, RAMP_BAND.y, h0),
			polar(a1, RAMP_BAND.y, h1), polar(a1, RAMP_BAND.x, h1)]
		var hull := PackedVector3Array()
		for corner: Vector3 in top:
			hull.append(corner)
			hull.append(Vector3(corner.x, -0.05, corner.z))
		var body := StaticBody3D.new()
		body.name = "Ramp"
		add_child(body)
		var shape := ConvexPolygonShape3D.new()
		shape.points = hull
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		var normal: Vector3 = (top[1] - top[0]).cross(top[3] - top[0]).normalized()
		_quad(tool, top, normal if normal.y > 0.0 else -normal)
		var drop := Vector3.DOWN * 0.05
		_quad(tool, [top[0], top[3], Vector3(top[3].x, 0, top[3].z) + drop, Vector3(top[0].x, 0, top[0].z) + drop],
			-polar((a0 + a1) * 0.5, 1.0))
	var far: float = ramp.x + direction * total
	_quad(tool, [polar(far, RAMP_BAND.x, RAMP_RISE), polar(far, RAMP_BAND.y, RAMP_RISE), polar(far, RAMP_BAND.y),
		polar(far, RAMP_BAND.x)], polar(far + direction * 90.0, 1.0))
	add_child(_mesh_of(tool, ISLAND_STONE))
	# Herse : paroi qui n'arrête que la marche (la navigation passe, les monstres se faufilent entre les barreaux).
	var foot: float = ramp.x - direction * 1.0
	var a: Vector3 = polar(foot, RAMP_BAND.x - 0.3)
	var b: Vector3 = polar(foot, RAMP_BAND.y - 0.4)
	_gate.append(_edge(Vector2(a.x, a.z), Vector2(b.x, b.z)))
	_gate.append(_prop(PACK % "wall_gated", polar(foot, 44.2), radial_yaw(foot), 1.0, "none", true))
	_gate.append(_prop(PACK % "wall_half", polar(foot, 41.4), radial_yaw(foot), 1.0, "none", true))
	_torch(polar(foot - direction * 3.0, 40.5))
	_light(exit_point + Vector3.UP * 1.5, RIFT, 1.8, 8.0)


## Murs radiaux entre les secteurs, percés d'une brèche de 4 m au milieu de l'anneau.
func _dividers(angles: Array) -> void:
	for angle: float in angles:
		var yaw: float = radial_yaw(angle)
		_piece("wall", polar(angle, 30.0), yaw)
		_piece("wall_half", polar(angle, 33.0), yaw)
		_piece("wall_half", polar(angle, 39.0), yaw)
		_piece("wall", polar(angle, 42.0), yaw)
		_piece("wall_half", polar(angle, 45.0), yaw)
		_torch(polar(angle + 4.0, BREACH.x - 1.0))


## Chemin de ronde pavé au milieu de l'anneau, repère de lecture du tour.
func _road() -> void:
	_paved_circle(36.0)


## Cercle de dalles tangentes de 4 m, assez serrées pour ne pas laisser de jour au bord extérieur.
func _paved_circle(radius: float) -> void:
	var count: int = ceili(TAU * (radius + 2.0) / 3.8)
	for index: int in count:
		var angle: float = 360.0 * index / count
		_piece("floor_tile_large", polar(angle, radius, FLOOR_Y), tangent_yaw(angle), "none")


## Porte (sud, départ du rez-de-chaussée et arrivée au sommet) : deux piliers dans le parapet, braseros, deux postes de garde en ruine (pans de mur et caisses).
func _gate_decor() -> void:
	for angle: float in [86.0, 94.0]:
		_piece("pillar", polar(angle, RING_OUTER - 0.6))
	for angle: float in [82.0, 98.0]:
		_torch(polar(angle, 43.5))
	for angle: float in [62.0, 118.0]:
		_piece("wall_half", polar(angle, 42.0), tangent_yaw(angle))
		_piece("box_stacked", polar(angle + (7.0 if angle < 90.0 else -7.0), 44.0), tangent_yaw(angle))
		_piece("rubble_half", polar(angle, 31.0), tangent_yaw(angle))
	_light(polar(90.0, 41.0, 3.0), Color("ffac66"), 1.2, 8.0)


## Ossuaire (ouest) : contreforts contre le rempart, niches à bougies entre eux, sarcophages brisés, deux murs
## effondrés en travers de l'anneau (abris), éboulis.
func _ossuary() -> void:
	_niches(160.0, 266.0)
	for spot: Vector2 in [Vector2(178.0, 41.5), Vector2(238.0, 41.5)]:
		_piece("table_long_broken", polar(spot.x, spot.y), radial_yaw(spot.x))
	for angle_wall: float in [186.0, 252.0]:
		_module("wall_broken", polar(angle_wall, 41.0), Vector3.ONE, tangent_yaw(angle_wall))
		_occupied.append(polar(angle_wall, 41.0))
	_piece("rubble_large", polar(193.0, 31.5), tangent_yaw(193.0))
	_piece("rubble_half", polar(258.0, 31.0), tangent_yaw(258.0))
	_glow(polar(210.0, 42.0, 3.0))


## Forges (est) : établis, fûts et caisses contre le rempart, échafaudages, lumière chaude des foyers ; deux tas de
## caisses au bord du chemin (abris).
func _forges() -> void:
	for angle: float in [290.0, 350.0, 10.0]:
		_piece("wall_scaffold", polar(angle, RING_OUTER - 0.6), tangent_yaw(angle), "none")
	for angle: float in [300.0, 340.0]:
		_piece("table_long_broken", polar(angle, 42.5), radial_yaw(angle))
		_piece("keg", polar(angle + 6.0, 43.5), 0.0)
		_torch(polar(angle - 5.0, 44.0))
		_light(polar(angle, 42.0, 2.5), Color("ff8a3d"), 1.6, 8.0)
	_piece("barrel_small_stack", polar(322.0, 43.5), tangent_yaw(322.0))
	_piece("barrel_small_stack", polar(15.0, 43.0), tangent_yaw(15.0))
	_piece("box_stacked", polar(312.0, 31.5), tangent_yaw(312.0))
	_piece("box_stacked", polar(5.0, 31.5), tangent_yaw(5.0))


## Contreforts contre le rempart, niches à bougies entre eux (de `from` à `to` degrés).
func _niches(from: float, to: float) -> void:
	var angle: float = from
	while angle < to:
		_piece("wall_half", polar(angle, RING_OUTER - 1.6), radial_yaw(angle))
		_piece("candle_triple", polar(angle + 5.0, RING_OUTER - 1.2), 0.0, "none")
		angle += 12.0


## Garnison (rez-de-chaussée) : râteliers et tables au nord, caisses d'abri au bord du chemin, murs effondrés au sud.
func _garrison() -> void:
	for angle: float in [200.0, 312.0, 336.0]:
		_piece("table_long_broken", polar(angle, 42.5), radial_yaw(angle))
		_piece("keg", polar(angle + 6.0, 43.5), 0.0)
		_torch(polar(angle - 5.0, 44.0))
	_piece("barrel_small_stack", polar(222.0, 43.5), tangent_yaw(222.0))
	for angle: float in [30.0, 150.0, 210.0, 330.0]:
		_piece("box_stacked", polar(angle, 31.5), tangent_yaw(angle))
	for angle: float in [45.0, 135.0]:
		_module("wall_broken", polar(angle, 41.0), Vector3.ONE, tangent_yaw(angle))
		_occupied.append(polar(angle, 41.0))
	_piece("rubble_half", polar(250.0, 31.0), tangent_yaw(250.0))
	_glow(polar(270.0, 36.0, 3.0), 1.6, 10.0)


## Cellules (étage du gardien) : niches le long du rempart, murs de cellules effondrés en travers de l'anneau,
## éboulis ; lueur forte au centre du puits.
func _cells() -> void:
	_niches(168.0, 222.0)
	_niches(338.0, 372.0)
	for angle: float in [60.0, 190.0, 255.0, 300.0]:
		_module("wall_broken", polar(angle, 41.0), Vector3.ONE, tangent_yaw(angle))
		_occupied.append(polar(angle, 41.0))
	for angle: float in [45.0, 205.0, 345.0]:
		_piece("rubble_half", polar(angle, 31.0), tangent_yaw(angle))
	_piece("rubble_large", polar(270.0, 31.5), tangent_yaw(270.0))
	_piece("table_long_broken", polar(30.0, 42.0), radial_yaw(30.0))
	_glow(polar(281.0, 36.0, 3.0), 1.6, 10.0)


## Bords du gouffre : lueurs violettes sous le rebord de l'anneau et de l'îlot (le vide se lit à son contour).
func _rim_glow() -> void:
	for step: int in 12:
		_light(polar(15.0 + 30.0 * step, RING_INNER - 1.0, -1.5), RIFT, 1.6, 6.0)
		if step % 2 == 0 and summit():
			_light(polar(30.0 * step, ISLAND + 1.0, -1.5), RIFT, 1.4, 6.0)


func _glow(at: Vector3, energy: float = 1.8, reach: float = 9.0) -> void:
	_light(at, RIFT, energy, reach)


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index: int in 45:
		var angle: float = 8.0 * index
		for spot: Vector3 in [polar(angle, RING_OUTER - 2.0), polar(angle + 4.0, RING_INNER + 2.0)]:
			var clear: bool = not _in_ramp(rad_to_deg(atan2(spot.z, spot.x)), 6.0)
			for taken: Vector3 in _occupied:
				if Vector2(taken.x, taken.z).distance_to(Vector2(spot.x, spot.z)) < SPAWN_CLEARANCE:
					clear = false
			if clear:
				result.append(spot)
	return result
