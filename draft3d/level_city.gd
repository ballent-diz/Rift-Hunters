class_name DraftLevelCity
extends DraftLevel
## Cinquième niveau de la base 3D : la Cité Effondrée (96 × 60 m), ville de pierre en ruine, de nuit, éclairée par
## les lueurs violettes de la Faille. Pièces du pack KayKit Dungeon Remastered (CC0, draft3d/dungeon/) posées par le
## centre de leur emprise, avec une collision simple.
##
## Quartiers, tous reliés, sans cul-de-sac :
## - la Porte sud : départ du Chasseur, au pied de la grande avenue pavée bordée de colonnes ;
## - l'Arc : porte debout au croisement de l'avenue et de la rue transversale (on passe dessous) ;
## - le Forum (centre) : cercle de piliers ; le boss y apparaît ;
## - les Maisons (ouest) : îlots de maisons sans toit, à deux ouvertures chacune, ruelles de 4 à 6 m ;
## - le Temple (nord-est) : péristyle de piliers, éboulis au centre, grilles au sol ;
## - les Entrepôts (sud-est) : fûts, caisses, pans de mur isolés ;
## - l'Acropole (nord, 2 m) : deux escaliers, arches au sommet, la lueur la plus forte.
## Limites : rempart sur trois côtés, parapet bas au sud (il ne cache pas le jeu).

const MIN := Vector2(-48.0, -30.0)
const MAX := Vector2(48.0, 30.0)
const START := Vector3(0, 0.2, 24)
const BOSS_SPOT := Vector3(0, 0.2, -10)
const TERRACE := Rect2(-14.0, -30.0, 28.0, 10.0)
const TERRACE_HEIGHT := 2.0
const PACK := "res://draft3d/dungeon/%s.glb"
const STONE := Color("2c2a33")
const RIFT := Color("b06bff")
const FLOOR_Y := 0.01


func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	sky = Color("09091a")
	ambient = Color("8086b4")
	sun = Color("a9b8ff")
	sun_energy = 0.45
	_box("Ground", Vector3(0, -0.25, 0), Vector3(MAX.x - MIN.x + 2.0, 0.5, MAX.y - MIN.y + 2.0), STONE)
	_rampart()
	_avenue()
	_forum()
	_houses()
	_temple()
	_warehouses()
	_terrace()
	_setup_navigation()


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box") -> Node3D:
	return _prop(PACK % id, at, yaw, 1.0, collision, true)


func _floor(id: String, x: float, z: float, yaw: float = 0.0) -> void:
	_piece(id, Vector3(x, FLOOR_Y, z), yaw, "none")


func _glow(at: Vector3, energy: float = 1.8, reach: float = 9.0) -> void:
	_light(at, RIFT, energy, reach)


## Porte debout sous laquelle on passe (module du donjon, collision sur ses seuls piédroits).
func _gateway(at: Vector3, yaw: float = 0.0) -> void:
	_module("wall_doorway", at, Vector3.ONE, yaw)


## Rempart : murs jointifs au nord, à l'ouest et à l'est ; parapet bas au sud. Une paroi double chaque côté.
func _rampart() -> void:
	var north: Array[String] = ["wall", "wall", "wall_pillar", "wall", "wall_archedwindow_open", "wall_pillar"]
	var index: int = 0
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		_piece(north[index % north.size()], Vector3(x, 0, MIN.y - 0.6), 0, "none")
		_piece("barrier_column", Vector3(x, 0, MAX.y + 0.5), 0, "none")
		index += 1
	var sides: Array[String] = ["wall", "wall_pillar", "wall", "wall_scaffold", "wall", "wall_sloped"]
	index = 0
	for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
		_piece(sides[index % sides.size()], Vector3(MIN.x - 0.6, 0, z), 90, "none")
		_piece(sides[(index + 3) % sides.size()], Vector3(MAX.x + 0.6, 0, z), 90, "none")
		index += 1
	var width: float = MAX.x - MIN.x + 2.0
	var depth: float = MAX.y - MIN.y + 2.0
	_fence(Vector3(0, 2, MAX.y + 0.4), Vector3(width, 6, 0.4))
	_fence(Vector3(0, 2, MIN.y - 0.4), Vector3(width, 10, 0.4))
	_fence(Vector3(MIN.x - 0.4, 2, 0), Vector3(0.4, 10, depth))
	_fence(Vector3(MAX.x + 0.4, 2, 0), Vector3(0.4, 10, depth))


## Grande avenue (sud → forum) et rue transversale, pavées ; colonnade, arche au croisement, torches à la porte.
func _avenue() -> void:
	var count: int = 0
	for z: int in range(28, -5, -4):
		for x: int in [-2, 2]:
			count += 1
			_floor("floor_dirt_large" if count % 7 == 0 else "floor_tile_large", x, z)
	for x: int in range(-42, 43, 4):
		if absi(x) > 4:
			count += 1
			_floor("floor_dirt_large_rocky" if count % 6 == 0 else "floor_tile_large", x, 2)
	for z: int in [20, 14, 8]:
		_piece("pillar", Vector3(-5.5, 0, z))
		_piece("column" if z == 14 else "pillar", Vector3(5.5, 0, z))
	_gateway(Vector3(0, 0, 5))
	_piece("pillar", Vector3(-2.8, 0, 5))
	_piece("pillar", Vector3(2.8, 0, 5))
	_piece("rubble_half", Vector3(-9, 0, 26), 20)
	_piece("barrier_column", Vector3(9, 0, 27), 90)
	_torch(Vector3(-4.5, 0, 27))
	_torch(Vector3(4.5, 0, 27))


## Forum (centre) : huit piliers en cercle autour du lieu du boss, dalles brisées, lueur de Faille.
func _forum() -> void:
	for step: int in 8:
		var angle: float = deg_to_rad(22.5 + 45.0 * step)
		var at := Vector3(BOSS_SPOT.x + cos(angle) * 9.0, 0, BOSS_SPOT.z + sin(angle) * 9.0)
		_piece("column" if step in [2, 7] else "pillar", at)
	for spot: Vector2 in [Vector2(-3, -8), Vector2(3, -12), Vector2(-5, -13), Vector2(5, -7), Vector2(0, -10)]:
		_floor("floor_tile_small_broken_A" if spot.x < 0 else "floor_tile_small_broken_B", spot.x, spot.y)
	_piece("candle_triple", Vector3(-6.5, 0, -10), 0, "none")
	_piece("candle_triple", Vector3(6.5, 0, -10), 0, "none")
	_glow(Vector3(0, 3.5, -10), 2.2, 11.0)


## Maison sans toit de 8 × 8 m : huit emplacements de mur de 4 m (nord gauche, nord droite, est haut, est bas,
## sud droite, sud gauche, ouest bas, ouest haut) ; un emplacement vide est une ouverture.
func _house(center: Vector2, slots: Array[String]) -> void:
	var spots: Array[Vector3] = [
		Vector3(-2, 0, -4), Vector3(2, 0, -4), Vector3(4, 90, -2), Vector3(4, 90, 2),
		Vector3(2, 0, 4), Vector3(-2, 0, 4), Vector3(-4, 90, 2), Vector3(-4, 90, -2)]
	for index: int in spots.size():
		if slots[index] != "":
			var spot: Vector3 = spots[index]
			_piece(slots[index], Vector3(center.x + spot.x, 0, center.y + spot.z), spot.y)
	_floor("floor_dirt_large", center.x, center.y)


## Maisons (ouest) : quatre îlots au nord de la rue, deux au sud ; chaque maison a deux ouvertures.
func _houses() -> void:
	_house(Vector2(-38, -20), ["wall", "wall_window_open", "", "wall", "wall_sloped", "wall", "wall", ""])
	_house(Vector2(-24, -20), ["wall_archedwindow_open", "wall", "wall", "", "", "wall", "wall_scaffold", "wall"])
	_house(Vector2(-38, -8), ["wall", "", "wall", "wall_sloped", "wall", "wall_window_open", "", "wall"])
	_house(Vector2(-24, -8), ["", "wall", "wall_sloped", "wall", "wall", "", "wall", "wall_archedwindow_open"])
	_house(Vector2(-38, 13), ["wall", "wall", "", "wall", "wall_window_open", "wall", "wall", ""])
	_house(Vector2(-24, 13), ["wall_sloped", "", "wall", "wall", "", "wall", "wall", "wall_archedwindow_open"])
	_piece("table_long_broken", Vector3(-39.8, 0, -20.5), 0)
	_piece("trunk_large_A", Vector3(-25, 0, -9), 15)
	_piece("barrel_small_stack", Vector3(-39, 0, 14), 70)
	_piece("rubble_large", Vector3(-31, 0, 24), 8)
	_piece("rubble_half", Vector3(-15, 0, -20), 100)
	_piece("column", Vector3(-15, 0, 12))
	_piece("column", Vector3(-12, 0, 20))
	for spot: Vector2 in [Vector2(-31, -14), Vector2(-31, -2), Vector2(-17, -6), Vector2(-31, 8), Vector2(-17, 22)]:
		_floor("floor_tile_small_weeds_A", spot.x, spot.y)
	_glow(Vector3(-31, 3.0, -14))
	_glow(Vector3(-31, 3.0, 19))


## Temple (nord-est) : péristyle de piliers (x 22 → 42, z −24 → −6), mur du fond, éboulis au centre, grilles.
func _temple() -> void:
	for x: int in range(22, 43, 5):
		_piece("pillar", Vector3(x, 0, -6))
		if x != 32:
			_piece("pillar" if x != 27 else "column", Vector3(x, 0, -24))
	for z: int in [-12, -18]:
		_piece("pillar", Vector3(22, 0, z))
		_piece("pillar" if z == -12 else "column", Vector3(42, 0, z))
	for x: int in [26, 38]:
		_piece("wall_arched", Vector3(x, 0, -27))
	_piece("wall_gated", Vector3(32, 0, -27))
	for x: int in range(26, 39, 4):
		for z: int in range(-20, -9, 4):
			_floor("floor_tile_big_grate" if (x == 30 and z == -12) or (x == 38 and z == -20) else "floor_tile_large",
				x, z)
	_piece("rubble_large", Vector3(32, 0, -16), 12)
	_piece("candle_triple", Vector3(29, 0, -23), 0, "none")
	_piece("candle_triple", Vector3(35, 0, -23), 0, "none")
	_piece("rubble_half", Vector3(18, 0, -13), -60)
	_glow(Vector3(32, 3.5, -11), 2.0, 10.0)


## Entrepôts (sud-est) : une maison éventrée, pans de mur isolés, fûts et caisses.
func _warehouses() -> void:
	_house(Vector2(36, 14), ["wall", "", "wall_scaffold", "wall", "", "wall", "wall_sloped", "wall"])
	_piece("wall_sloped", Vector3(20, 0, 10), 0)
	_piece("wall", Vector3(16, 0, 10), 0)
	_piece("wall_window_open", Vector3(22, 0, 20), 90)
	_piece("box_stacked", Vector3(15, 0, 23), 20)
	_piece("keg", Vector3(27, 0, 25), 0)
	_piece("keg", Vector3(29.5, 0, 25.5), 30)
	_piece("barrel_small_stack", Vector3(43, 0, 24), 100)
	_piece("trunk_large_A", Vector3(36, 0, 14), -20)
	_piece("barrier_column", Vector3(44, 0, 7), 90)
	_piece("column", Vector3(13, 0, 16))
	for spot: Vector2 in [Vector2(28, 12), Vector2(20, 26), Vector2(42, 20)]:
		_floor("floor_tile_small_weeds_A", spot.x, spot.y)
	_glow(Vector3(27, 3.0, 17))


## Acropole (nord) : dalle à 2 m, un escalier au sud et un à l'est ; arches au fond, piliers en façade.
func _terrace() -> void:
	var center: Vector2 = TERRACE.get_center()
	_box("Terrace", Vector3(center.x, TERRACE_HEIGHT * 0.5 - 0.05, center.y),
		Vector3(TERRACE.size.x, TERRACE_HEIGHT + 0.1, TERRACE.size.y), STONE.darkened(0.15))
	_module("stairs_wide", Vector3(center.x, 0, TERRACE.end.y), Vector3(1, 0.5, 1.5))
	_module("stairs_wide", Vector3(TERRACE.end.x, 0, center.y), Vector3(1, 0.5, 1.5), 90)
	for x: int in [-8, 0, 8]:
		_piece("wall_arched" if x != 0 else "wall_archedwindow_open", Vector3(x, TERRACE_HEIGHT, -28.5))
	for x: int in [-12, -5, 5, 12]:
		_piece("pillar" if absi(x) == 12 else "column", Vector3(x, TERRACE_HEIGHT, TERRACE.end.y - 1.2))
	_piece("rubble_half", Vector3(-10, TERRACE_HEIGHT, -25), 200)
	_piece("candle_triple", Vector3(3, TERRACE_HEIGHT, -26.5), 0, "none")
	_piece("candle_triple", Vector3(-3, TERRACE_HEIGHT, -26.5), 0, "none")
	_glow(Vector3(0, TERRACE_HEIGHT + 3.0, -26), 2.6, 12.0)


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		result.append(Vector3(x, 0, MAX.y - 1.5))
		if not (x > TERRACE.position.x and x < TERRACE.end.x):
			result.append(Vector3(x, 0, MIN.y + 1.5))
	for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
		result.append(Vector3(MIN.x + 1.5, 0, z))
		result.append(Vector3(MAX.x - 1.5, 0, z))
	result.append(Vector3(4, TERRACE_HEIGHT, -27))
	result.append(Vector3(9, TERRACE_HEIGHT, -24))
	return result
