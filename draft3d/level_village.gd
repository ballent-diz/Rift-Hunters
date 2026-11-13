class_name DraftLevelVillage
extends DraftLevel
## Troisième niveau de la base 3D : le Hameau du Gué (92 × 64 m), village en plein jour coupé par une rivière.
## Modules KayKit Medieval Hexagon Pack (CC0, draft3d/medieval/), agrandis cinq fois (ce sont des miniatures de
## carte de stratégie) et importés tels quels avec une collision simple.
##
## Quartiers, tous reliés, sans cul-de-sac :
## - la Place (sud) : départ du Chasseur, puits, marché, taverne, maisons, caisses et tentes ;
## - la Rivière (milieu) : infranchissable, sauf par trois ponts (ouest, centre plus étroit, est) : goulets où
##   étirer une horde ;
## - les Champs (nord-ouest) : moulin, parcelles, clôtures de bois ;
## - la Butte de l'église (nord, 2 m) : deux escaliers, l'église au sommet ; le boss apparaît à son pied ;
## - le Bosquet (nord-est) : arbres serrés (seuls les troncs arrêtent les tirs), tour de guet, scierie.
## Limites : muret de pierre tout autour, rideau d'arbres derrière.

const MIN := Vector2(-46.0, -32.0)
const MAX := Vector2(46.0, 32.0)
const START := Vector3(0, 0.2, 26)
const BOSS_SPOT := Vector3(0, 0.2, -10)
## Lit de la rivière (z) et ponts : [centre x, largeur].
const RIVER := Vector2(-3.0, 3.0)
const BRIDGES: Array = [[-26.0, 7.0], [0.0, 4.5], [26.0, 7.0]]
const KNOLL := Rect2(-9.0, -31.0, 18.0, 12.0)
const KNOLL_HEIGHT := 2.0
const PACK := "res://draft3d/medieval/%s.gltf"
const SCALE := 5.0
const GRASS := Color("5f8f47")


func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	sky = Color("7fa9c4")
	ambient = Color("e2e8ee")
	sun = Color("fff0d0")
	sun_energy = 1.0
	_ground()
	_walls()
	_square()
	_fields()
	_knoll()
	_grove()
	_setup_navigation()


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box", size: float = SCALE) -> Node3D:
	return _prop(PACK % id, at, yaw, size, collision, true)


## Deux rives d'herbe, la rivière entre elles (eau en contrebas, bords fermés), trois ponts de planches.
func _ground() -> void:
	var width: float = MAX.x - MIN.x + 2.0
	_box("SouthBank", Vector3(0, -0.25, (RIVER.y + MAX.y + 1.0) * 0.5), Vector3(width, 0.5, MAX.y + 1.0 - RIVER.y), GRASS)
	_box("NorthBank", Vector3(0, -0.25, (RIVER.x + MIN.y - 1.0) * 0.5), Vector3(width, 0.5, RIVER.x - MIN.y + 1.0), GRASS)
	# L'eau n'est qu'une image (sans collision ni navigation) : personne n'y marche, les berges sont fermées.
	var water := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(width, 0.5, RIVER.y - RIVER.x)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("3f86b8")
	material.roughness = 0.25
	slab.material = material
	water.mesh = slab
	water.position = Vector3(0, -0.9, (RIVER.x + RIVER.y) * 0.5)
	add_child(water)
	var edge: float = MIN.x - 1.0
	for bridge: Array in BRIDGES:
		var x: float = bridge[0]
		var span: float = bridge[1]
		_box("Bridge", Vector3(x, -0.15, (RIVER.x + RIVER.y) * 0.5), Vector3(span, 0.3, RIVER.y - RIVER.x + 0.4), Color("8a6a45"))
		for side: int in [-1, 1]:
			_piece("fence_wood_straight", Vector3(x + side * span * 0.5, 0, 0))
		# Entre deux ponts, la berge est fermée : on ne marche pas dans la rivière.
		_bank(edge, x - span * 0.5)
		edge = x + span * 0.5
	_bank(edge, MAX.x + 1.0)
	for i: int in 14:
		_piece("rock_single_%s" % ["A", "C", "E"][i % 3], Vector3(MIN.x + 4.0 + i * 6.6, -0.6, -0.6 + (i % 3) * 0.7), 40.0 * i,
			"none", 4.0)


func _bank(from: float, to: float) -> void:
	if to - from < 0.5:
		return
	for z: float in [RIVER.x + 0.2, RIVER.y - 0.2]:
		_fence(Vector3((from + to) * 0.5, 1.0, z), Vector3(to - from, 4.0, 0.4), true)


func _walls() -> void:
	for x: int in range(int(MIN.x) + 3, int(MAX.x), 6):
		_piece("fence_stone_straight", Vector3(x, 0, MIN.y - 0.4), 90)
		_piece("fence_stone_straight_gate" if x == 3 else "fence_stone_straight", Vector3(x, 0, MAX.y + 0.4), 90)
		_piece("trees_A_large" if posmod(x, 12) == 3 else "trees_B_large", Vector3(x, 0, MIN.y - 5.0), 30.0 * x, "none")
	for z: int in range(int(MIN.y) + 3, int(MAX.y), 6):
		_piece("fence_stone_straight", Vector3(MIN.x - 0.4, 0, z))
		_piece("fence_stone_straight", Vector3(MAX.x + 0.4, 0, z))
		_piece("trees_B_medium", Vector3(MIN.x - 4.5, 0, z), 50.0 * z, "none")
		_piece("trees_A_medium", Vector3(MAX.x + 4.5, 0, z), 70.0 * z, "none")
	var width: float = MAX.x - MIN.x + 2.0
	var depth: float = MAX.y - MIN.y + 2.0
	_fence(Vector3(0, 2, MAX.y + 0.7), Vector3(width, 6, 0.4))
	_fence(Vector3(0, 2, MIN.y - 0.7), Vector3(width, 10, 0.4))
	_fence(Vector3(MIN.x - 0.7, 2, 0), Vector3(0.4, 10, depth))
	_fence(Vector3(MAX.x + 0.7, 2, 0), Vector3(0.4, 10, depth))


## Place du village (sud) : le puits au centre, les bâtiments en couronne, des ruelles entre eux.
func _square() -> void:
	_piece("building_well_blue", Vector3(0, 0, 14))
	_piece("building_market_blue", Vector3(-15, 0, 18), 20)
	_piece("building_tavern_blue", Vector3(16, 0, 19), -25)
	_piece("building_home_A_blue", Vector3(-30, 0, 24), 90)
	_piece("building_home_B_blue", Vector3(-36, 0, 12), 60)
	_piece("building_home_A_blue", Vector3(30, 0, 26), -90)
	_piece("building_home_B_blue", Vector3(37, 0, 13), 200)
	_piece("building_blacksmith_blue", Vector3(-22, 0, 8), 180)
	_piece("building_home_A_blue", Vector3(22, 0, 9), 150)
	_piece("building_destroyed", Vector3(40, 0, 26), 30)
	for spot: Vector3 in [Vector3(-8, 0, 21), Vector3(8, 0, 10), Vector3(-9, 0, 8), Vector3(9, 0, 24)]:
		_piece("crate_A_big", spot, 15, "box", 6.0)
		_piece("barrel", spot + Vector3(1.6, 0, 0.4), 0, "box", 6.0)
		_piece("crate_long_B", spot + Vector3(-0.2, 0, 1.6), 80, "box", 5.0)
	_piece("tent", Vector3(-3, 0, 29), 0, "box", 6.0)
	_piece("tent", Vector3(5, 0, 29.5), 40, "box", 6.0)
	_piece("weaponrack", Vector3(11, 0, 15.5), 60, "none", 6.0)
	_piece("wheelbarrow", Vector3(-12, 0, 13), 30, "none", 6.0)
	_piece("flag_blue", Vector3(-2.5, 0, 6.5), 0, "none", 8.0)
	_piece("flag_blue", Vector3(2.5, 0, 6.5), 0, "none", 8.0)
	for spot: Vector3 in [Vector3(-41, 0, 30), Vector3(42, 0, 6), Vector3(-42, 0, 6), Vector3(12, 0, 30)]:
		_piece("tree_single_B", spot, 0, "trunk")


## Champs (nord-ouest) : moulin, parcelles de blé (plates), clôtures à contourner, grenier.
func _fields() -> void:
	_piece("building_windmill_blue", Vector3(-36, 0, -24), 20)
	for row: int in 2:
		for column: int in 2:
			_piece("building_grain", Vector3(-36.0 + column * 11.0, 0.02, -8.0 - row * 9.0), 0, "none", 4.5)
	for x: int in [-39, -27]:
		_piece("fence_wood_straight", Vector3(x, 0, -12.5), 90)
	_piece("fence_wood_straight", Vector3(-18.5, 0, -9))
	_piece("fence_wood_straight", Vector3(-18.5, 0, -19))
	_piece("building_lumbermill_blue", Vector3(-18, 0, -27), 160)
	_piece("resource_lumber", Vector3(-24, 0, -27), 20, "box", 6.0)
	_piece("sack", Vector3(-31, 0, -26), 0, "none", 8.0)
	_piece("tree_single_A", Vector3(-43, 0, -6), 0, "trunk")
	_piece("tree_single_A", Vector3(-14, 0, -6.5), 0, "trunk")


## Butte de l'église (nord) : plate-forme à 2 m, un escalier au sud et un à l'est ; le boss apparaît à son pied.
func _knoll() -> void:
	var center: Vector2 = KNOLL.get_center()
	_box("Knoll", Vector3(center.x, KNOLL_HEIGHT * 0.5 - 0.05, center.y),
		Vector3(KNOLL.size.x, KNOLL_HEIGHT + 0.1, KNOLL.size.y), GRASS.darkened(0.15))
	_module("stairs_wide", Vector3(center.x, 0, KNOLL.end.y), Vector3(1, 0.5, 1.5))
	_module("stairs_wide", Vector3(KNOLL.end.x, 0, center.y), Vector3(1, 0.5, 1.5), 90)
	_piece("building_church_blue", Vector3(center.x - 3.0, KNOLL_HEIGHT, center.y - 1.5))
	_piece("tree_single_B", Vector3(KNOLL.end.x - 2.0, KNOLL_HEIGHT, KNOLL.position.y + 2.0), 0, "trunk")
	_piece("fence_stone_straight", Vector3(center.x - 6.0, KNOLL_HEIGHT, KNOLL.end.y - 0.5), 90, "box", 4.0)
	_piece("fence_stone_straight", Vector3(center.x + 6.0, KNOLL_HEIGHT, KNOLL.end.y - 0.5), 90, "box", 4.0)


## Bosquet (nord-est) : arbres en quinconce, tour de guet, rochers.
func _grove() -> void:
	var kinds: Array[String] = ["tree_single_A", "tree_single_B", "trees_A_small", "tree_single_A", "trees_B_small"]
	var index: int = 0
	for row: int in 4:
		for column: int in 5:
			var at := Vector3(17.0 + column * 6.0 + (3.0 if row % 2 == 1 else 0.0), 0, -27.0 + row * 5.5)
			if at.x < MAX.x - 3.0 and not (row == 1 and column == 2):
				_piece(kinds[index % kinds.size()], at, 47.0 * index, "trunk")
			index += 1
	_piece("building_tower_A_blue", Vector3(31.5, 0, -21.5), 180)
	for spot: Vector3 in [Vector3(14, 0, -8), Vector3(40, 0, -7), Vector3(22, 0, -6.5)]:
		_piece("rock_single_E", spot, 25, "box", 7.0)


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		result.append(Vector3(x, 0, MAX.y - 1.5))
		if not (x > KNOLL.position.x and x < KNOLL.end.x):
			result.append(Vector3(x, 0, MIN.y + 1.5))
	for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
		if z < RIVER.x - 2.0 or z > RIVER.y + 2.0:
			result.append(Vector3(MIN.x + 1.5, 0, z))
			result.append(Vector3(MAX.x - 1.5, 0, z))
	result.append(Vector3(4, KNOLL_HEIGHT, -28))
	result.append(Vector3(6, KNOLL_HEIGHT, -22))
	return result
