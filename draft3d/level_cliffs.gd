class_name DraftLevelCliffs
extends DraftLevel
## Neuvième niveau de la base 3D : les Corniches (68 × 112 m), première carte plus profonde que large. Une falaise en
## gradins que l'on gravit vers le nord, face à la caméra : chaque corniche est plus haute et plus loin.
## - la Grève (0 m, sud) : départ, sable, épave de campement ;
## - les Terrasses du Guet (3 m) : postes de guet en ruine ;
## - le Promontoire (6 m) : colonnade effondrée ;
## - la Couronne (9 m, nord) : sanctuaire au sommet, lieu du boss.
## Pour monter : rampes en lacets le long des falaises, éboulis en pente douce, escaliers de pierre ; deux accès au
## moins par corniche, aucun cul-de-sac. Sur chaque corniche basse, un perchoir 1,5 m plus haut (deux pentes) : hors
## de portée de la mêlée, il se paie d'un accès étroit. Fronts de falaise découpés par des rochers en saillie (abris
## entre deux niveaux).
## On saute d'une corniche (on ne remonte que par un accès). Règles du relief : on tire vers le bas et vers le haut
## si la vue est dégagée, la mêlée ne porte pas au-delà de 1 m de dénivelé, une
## attaque annoncée au sol ne touche que son niveau. Pièces : KayKit Dungeon (draft3d/modules, draft3d/dungeon) et
## Medieval Hexagon (draft3d/medieval, × 5).

const MIN := Vector2(-34.0, -56.0)
const MAX := Vector2(34.0, 56.0)
const START := Vector3(0, 0.2, 48)
const BOSS_SPOT := Vector3(0, 9.2, -40)
const STEP := 3.0
## Corniches : hauteur, rebord sud (falaise) et rebord nord (z) ; saillies : x de début, x de fin, rebord sud.
const LEDGES: Array[Dictionary] = [
	{"top": 0.0, "front": 57.0, "back": 28.0, "jut": []},
	{"top": 3.0, "front": 28.0, "back": 4.0, "jut": [Vector3(-6, 8, 32), Vector3(18, 35, 30)]},
	{"top": 6.0, "front": 4.0, "back": -24.0, "jut": [Vector3(-35, -20, 8), Vector3(6, 18, 7)]},
	{"top": 9.0, "front": -24.0, "back": -57.0, "jut": [Vector3(-8, 8, -20)]},
]
const PACK := "res://draft3d/dungeon/%s.glb"
const MEDIEVAL := "res://draft3d/medieval/%s.gltf"
const SAND := Color("8a7a58")
const GRASS := Color("5d6a3e")
const STONE := Color("6a6470")
const CROWN := Color("4e4858")
const CLIFF := Color("4a4248")
const RAMP := Color("7a6e5a")
const RIFT := Color("b06bff")
const EMBER := Color("ffb070")
const PERCH := 1.5
## Fronts de falaise laissés libres (accès) : par corniche (index), intervalles de x.
const CLEAR: Array = [[], [Vector2(-33, -8), Vector2(21, 32)], [Vector2(-15, -5), Vector2(14, 34)],
	[Vector2(-34, -9), Vector2(-6, 6)]]


func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	sky = Color("1a2030")
	ambient = Color("a0a8c0")
	sun = Color("ffe0b8")
	sun_energy = 0.75
	var colors: Array[Color] = [SAND, GRASS, STONE, CROWN]
	for index: int in LEDGES.size():
		_ledge(LEDGES[index], colors[index])
	_borders()
	_ascents()
	_perches()
	_cliff_faces()
	_shore()
	_watch()
	_promontory()
	_crown()
	_setup_navigation()


## Corniche : bloc plein du sol à sa hauteur, plus ses saillies vers le sud (front de falaise irrégulier).
func _ledge(ledge: Dictionary, color: Color) -> void:
	var top: float = ledge["top"]
	var front: float = ledge["front"]
	var back: float = ledge["back"]
	var height: float = top + 0.5
	_box("Ledge", Vector3(0, top - height * 0.5, (front + back) * 0.5),
		Vector3(MAX.x - MIN.x + 2.0, height, front - back), color)
	for jut: Vector3 in ledge["jut"]:
		_box("Ledge", Vector3((jut.x + jut.y) * 0.5, top - height * 0.5, (front + jut.z) * 0.5),
			Vector3(jut.y - jut.x, height, jut.z - front), color)


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box") -> Node3D:
	return _prop(PACK % id, at, yaw, 1.0, collision, true)


func _medieval(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box") -> Node3D:
	return _prop(MEDIEVAL % id, at, yaw, 5.0, collision, true)


## Pente praticable (rampe, éboulis) de `from` (bas) à `to` (haut), de largeur `width` : prisme plein jusqu'au sol,
## collision convexe ; enregistrée pour le contrôle de composition.
func _incline(from: Vector3, to: Vector3, width: float, color: Color = RAMP) -> void:
	var dir: Vector3 = Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	var side: Vector3 = dir.cross(Vector3.UP) * width * 0.5
	var low: float = from.y - 0.5
	var top: Array[Vector3] = [from - side, to - side, to + side, from + side]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal: Vector3 = (top[1] - top[0]).cross(top[3] - top[0]).normalized()
	if normal.y < 0.0:
		normal = -normal
	for index: int in [0, 1, 2, 0, 2, 3]:
		tool.set_normal(normal)
		tool.add_vertex(top[index])
	var hull := PackedVector3Array()
	for index: int in top.size():
		var a: Vector3 = top[index]
		var b: Vector3 = top[(index + 1) % top.size()]
		var face_normal: Vector3 = (b - a).cross(Vector3.UP).normalized()
		for corner: Vector3 in [a, b, Vector3(b.x, low, b.z), a, Vector3(b.x, low, b.z), Vector3(a.x, low, a.z)]:
			tool.set_normal(face_normal)
			tool.add_vertex(corner)
		hull.append(a)
		hull.append(Vector3(a.x, low, a.z))
	var body := StaticBody3D.new()
	body.name = "Incline"
	body.set_meta(&"incline", true)
	add_child(body)
	body.add_child(_mesh_of(tool, color))
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	inclines.append({"bottom": from + Vector3.UP * 0.0, "top": to})


## Rampe en lacet le long d'une falaise : pente parallèle au front, puis palier contre la corniche du dessus.
func _switchback(x_from: float, x_to: float, z: float, base: float, landing_z: Vector2) -> void:
	var width: float = 4.0
	_incline(Vector3(x_from, base, z), Vector3(x_to, base + STEP, z), width)
	var direction: float = signf(x_to - x_from)
	var landing_x: float = x_to + direction * 3.0
	_box("Ledge", Vector3(landing_x, base + STEP - (base + STEP + 0.5) * 0.5, (landing_z.x + landing_z.y) * 0.5),
		Vector3(6.0, base + STEP + 0.5, landing_z.y - landing_z.x), RAMP)
	_torch(Vector3(landing_x, base + STEP, landing_z.y - 0.8))


## Les accès : deux par corniche, aux deux bouts ou au centre, jamais au même endroit d'un étage à l'autre.
func _ascents() -> void:
	# Grève → Guet : lacet à l'ouest, escalier à l'est (sur la saillie).
	_switchback(-30.0, -16.0, 30.5, 0.0, Vector2(26.0, 32.5))
	_module("stairs_wide", Vector3(26, 0, 30), Vector3(1, 0.75, 1.5))
	# Guet → Promontoire : éboulis au centre-ouest, lacet à l'est.
	_incline(Vector3(-10, 3, 16), Vector3(-10, 6, 3), 6.0, CLIFF.lightened(0.15))
	_switchback(31.0, 21.0, 6.5, 3.0, Vector2(2.0, 8.5))
	# Promontoire → Couronne : grand escalier au centre (sur la saillie), lacet à l'ouest.
	_module("stairs_wide", Vector3(0, 6, -20), Vector3(1, 0.75, 1.5))
	for x: float in [-4.6, 4.6]:
		_piece("pillar", Vector3(x, 6, -15.5))
	_switchback(-12.0, -26.0, -21.5, 6.0, Vector2(-27.0, -19.5))


## Rebord sud d'une corniche à cette abscisse (saillie comprise).
func front_z(index: int, x: float) -> float:
	var ledge: Dictionary = LEDGES[index]
	for jut: Vector3 in ledge["jut"]:
		if x >= jut.x and x <= jut.y:
			return jut.z
	return ledge["front"]


## Perchoirs : plateaux 1,5 m au-dessus de leur corniche, deux pentes chacun.
func _perches() -> void:
	# Grève : le Rocher du Phare, feu de veille au sommet.
	_plateau(Rect2(16, 41, 8, 6), 0.0, SAND.darkened(0.15))
	_incline(Vector3(10, 0, 44), Vector3(16.5, PERCH, 44), 3.5, SAND.darkened(0.1))
	_incline(Vector3(20, 0, 53), Vector3(20, PERCH, 46.5), 3.5, SAND.darkened(0.1))
	_light(Vector3(20, PERCH + 2.0, 44), EMBER, 2.2, 10.0)
	_piece("candle_triple", Vector3(21.5, PERCH, 42.5), 0.0, "none")
	# Guet : le Belvédère, à l'ouest.
	_plateau(Rect2(-30, 14, 8, 7), 3.0, GRASS.darkened(0.15))
	_incline(Vector3(-26, 3, 26.5), Vector3(-26, 3 + PERCH, 20.5), 3.5, GRASS.darkened(0.1))
	_incline(Vector3(-15.5, 3, 17.5), Vector3(-22.5, 3 + PERCH, 17.5), 3.5, GRASS.darkened(0.1))
	_piece("wall_half", Vector3(-27, 3 + PERCH, 14.6), 0.0)
	_torch(Vector3(-24, 3 + PERCH, 15.2))
	# Promontoire : la Terrasse aux colonnes, ruine surélevée à l'est.
	_plateau(Rect2(12, -16, 12, 8), 6.0, STONE.darkened(0.12))
	_incline(Vector3(31, 6, -12), Vector3(23.5, 6 + PERCH, -12), 3.5, STONE.darkened(0.05))
	_incline(Vector3(18, 6, 0), Vector3(18, 6 + PERCH, -8.5), 3.5, STONE.darkened(0.05))
	for x: float in [13.5, 22.5]:
		for z: float in [-14.5, -9.5]:
			_piece("pillar", Vector3(x, 6 + PERCH, z))


func _plateau(area: Rect2, base: float, color: Color) -> void:
	var top: float = base + PERCH
	_box("Ledge", Vector3(area.get_center().x, top - (top + 0.5) * 0.5, area.get_center().y),
		Vector3(area.size.x, top + 0.5, area.size.y), color)


## Fronts de falaise découpés : rochers en saillie au pied de chaque falaise, qui dépassent un peu du rebord (abris
## entre deux niveaux) ; les accès restent dégagés.
func _cliff_faces() -> void:
	for index: int in range(1, LEDGES.size()):
		var lower: float = LEDGES[index - 1]["top"]
		var x: float = MIN.x + 2.5
		while x < MAX.x - 2.0:
			var clear: bool = true
			for gap: Vector2 in CLEAR[index]:
				clear = clear and not (x > gap.x - 2.5 and x < gap.y + 2.5)
			if clear:
				var z: float = front_z(index, x)
				_boulder(Vector2(x + _jitter(0.8), z + 0.9), Vector2(2.4 + _jitter(0.5), 1.3), lower,
					STEP + 0.6 + _jitter(0.6), CLIFF.lightened(0.05), 0.55)
			x += 4.5 + _jitter(1.0)


## Limites : falaises pleines à l'est et à l'ouest (hautes au nord), rochers bas au sud (côté caméra).
func _borders() -> void:
	for ledge: Dictionary in LEDGES:
		var top: float = ledge["top"]
		var front: float = ledge["front"]
		var back: float = ledge["back"]
		var height: float = top + 5.0
		for x: float in [MIN.x - 1.5, MAX.x + 1.5]:
			_cliff(Vector3(x, height * 0.5 - 0.5, (front + back) * 0.5), Vector3(3.0, height + 1.0, front - back))
	_cliff(Vector3(0, 9.0, MIN.y - 1.5), Vector3(MAX.x - MIN.x + 6.0, 20.0, 3.0))
	for x: float in range(int(MIN.x) + 2, int(MAX.x), 4):
		_medieval("rock_single_" + ["A", "B", "C", "D", "E"][absi(int(x)) % 5], Vector3(x, 0, MAX.y + 0.8),
			float(x) * 13.0, "none")
	_fence(Vector3(0, 2, MAX.y + 0.4), Vector3(MAX.x - MIN.x + 2.0, 6, 0.4))


## Grève (0 m) : campement échoué, caisses et barques retournées (abris bas).
## Paroi de falaise : bloc plein, marqué « décor » (son sommet n'est pas une corniche de jeu).
func _cliff(at: Vector3, size: Vector3) -> void:
	_box("Cliff", at, size, CLIFF)
	get_child(get_child_count() - 1).set_meta(&"decor", true)


func _shore() -> void:
	_medieval("tent", Vector3(-12, 0, 47), 20.0)
	_medieval("tent", Vector3(-4, 0, 51), -15.0)
	_medieval("crate_A_big", Vector3(4, 0, 44), 10.0)
	_medieval("crate_long_A", Vector3(-22, 0, 40), 80.0)
	_medieval("barrel", Vector3(-1, 0, 41), 0.0)
	_piece("trunk_large_A", Vector3(-28, 0, 46), 30.0)
	_medieval("rock_single_C", Vector3(-17, 0, 36), 0.0)
	_medieval("rock_single_A", Vector3(-30, 0, 52), 0.0)
	_medieval("rock_single_D", Vector3(30, 0, 48), 40.0)
	_light(Vector3(-8, 2.0, 46), EMBER, 1.6, 9.0)


## Terrasses du Guet (3 m) : poste de guet en ruine (enclos à deux ouvertures), bosquets, brasero.
func _watch() -> void:
	var post := Vector2(-1, 19)
	_piece("wall", Vector3(post.x - 2, 3, post.y - 4))
	_module("wall_broken", Vector3(post.x + 4, 3, post.y), Vector3.ONE, 90.0)
	_piece("wall_half", Vector3(post.x - 3, 3, post.y + 4))
	_piece("wall", Vector3(post.x - 4, 3, post.y - 2), 90.0)
	_piece("barrel_small_stack", Vector3(post.x - 1.5, 3, post.y - 1.5), 0.0)
	_medieval("trees_A_small", Vector3(28, 3, 12), 0.0, "trunk")
	_medieval("trees_B_small", Vector3(-4, 3, 8), 0.0, "trunk")
	_medieval("tree_single_B", Vector3(-31.5, 3.35, 25), 0.0, "trunk")
	_medieval("rock_single_B", Vector3(24, 3, 22), 0.0)
	_torch(Vector3(4, 3, 12))


## Promontoire (6 m) : cour en ruine à l'ouest (deux ouvertures), colonnade effondrée, éboulis.
func _promontory() -> void:
	var court := Vector2(-22, -10)
	_piece("wall", Vector3(court.x - 2, 6, court.y - 4))
	_piece("wall", Vector3(court.x + 2, 6, court.y - 4))
	_piece("wall", Vector3(court.x - 4, 6, court.y), 90.0)
	_module("wall_broken", Vector3(court.x + 2, 6, court.y + 4), Vector3.ONE, 0.0)
	_piece("rubble_half", Vector3(court.x + 1, 6, court.y + 0.5), 0.0)
	for x: float in [-8.0, -2.0]:
		_piece("pillar", Vector3(x, 6, -2))
	_piece("rubble_large", Vector3(-5, 6, -12), 0.0)
	_medieval("trees_B_small", Vector3(-30, 6, -20), 0.0, "trunk")
	_light(Vector3(-22, 9.0, -10), RIFT, 1.2, 8.0)


## Couronne (9 m) : sanctuaire au sommet, parvis dallé, arches au fond, quatre piliers autour du lieu du boss,
## autels à bougies, lueur de la Faille.
func _crown() -> void:
	for x: float in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		_piece("wall_arched" if x != 0.0 else "wall_archedwindow_open", Vector3(x, 9, -54.5))
	# Parvis dallé, rectangle régulier autour du lieu du boss.
	for x: int in range(-12, 13, 4):
		for z: int in range(-50, -29, 4):
			_piece("floor_tile_large", Vector3(x, 9.01, z), 0.0, "none")
	for angle: float in [45.0, 135.0, 225.0, 315.0]:
		var at: Vector3 = BOSS_SPOT + Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle))) * 8.0
		_piece("pillar", Vector3(at.x, 9, at.z))
	for x: float in [-26.0, 26.0]:
		_piece("candle_triple", Vector3(x, 9, -46), 0.0, "none")
		_piece("rubble_half", Vector3(x, 9, -36), 90.0)
	_light(BOSS_SPOT + Vector3.UP * 3.5, RIFT, 3.0, 16.0)
	for x: float in [-24.0, 24.0]:
		_torch(Vector3(x, 9, -30))


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for ledge: Dictionary in LEDGES:
		var top: float = ledge["top"]
		var middle: float = (float(ledge["front"]) + float(ledge["back"])) * 0.5
		for x: float in [MIN.x + 2.0, MAX.x - 2.0]:
			for dz: float in [-6.0, 0.0, 6.0]:
				result.append(Vector3(x, top, middle + dz))
	for x: int in range(int(MIN.x) + 4, int(MAX.x) - 2, 6):
		result.append(Vector3(x, 0, MAX.y - 2.0))
		result.append(Vector3(x, 9, MIN.y + 4.0))
	return result
