class_name DraftLevelCity
extends DraftLevel
## Cinquième niveau de la base 3D : la Cité Effondrée (96 × 60 m), ville de pierre en ruine, de nuit, éclairée par
## les lueurs violettes de la Faille. Pièces du pack KayKit Dungeon Remastered (CC0, draft3d/dungeon/) posées par le
## centre de leur emprise, avec une collision simple ; murs, portes et brèches du donjon (draft3d/modules/).
##
## Plan en damier, lu depuis la porte (règles de composition : docs/maps/CARTES_3D.md) :
## - la Porte sud : départ du Chasseur, entre deux piliers et deux torches ;
## - l'Avenue (cardo) : pavée, bordée de façades à portes, elle mène tout droit au Forum ;
## - la Rue transversale (decumanus) : pavée d'est en ouest, elle traverse le Forum et dessert les quartiers ;
## - le Forum (centre) : grande place dallée, portiques sur ses flancs, quatre colonnes d'abri ; le boss y apparaît ;
## - l'Acropole (nord, 2 m) : dallée, colonnade et arches ; grand escalier depuis le Forum, escalier est depuis la
##   Voie sacrée ;
## - la Voie sacrée et le Temple (nord-est) : allée pavée du decumanus au pied de l'escalier est, péristyle ouvert ;
## - les Maisons (ouest) et les Entrepôts (sud-est) : îlots de 8 × 8 m alignés sur les rues, deux portes au moins,
##   murs brisés et éboulis côte à côte, une maison effondrée par quartier.
## Limites : rempart sur trois côtés, parapet bas au sud (il ne cache pas le jeu).

const MIN := Vector2(-48.0, -30.0)
const MAX := Vector2(48.0, 30.0)
const START := Vector3(0, 0.2, 24)
const BOSS_SPOT := Vector3(0, 0.2, -4)
const FORUM := Rect2(-12.0, -12.0, 24.0, 16.0)
const TERRACE := Rect2(-14.0, -30.0, 28.0, 10.0)
const TERRACE_HEIGHT := 2.0
const PACK := "res://draft3d/dungeon/%s.glb"
const STONE := Color("2c2a33")
const RIFT := Color("b06bff")
const FLOOR_Y := 0.01
## Emplacements de mur d'une maison de 8 × 8 m (x, angle, z) : nord gauche, nord droite, est nord, est sud,
## sud droite, sud gauche, ouest sud, ouest nord.
const HOUSE_SLOTS: Array[Vector3] = [
	Vector3(-2, 0, -4), Vector3(2, 0, -4), Vector3(4, 90, -2), Vector3(4, 90, 2),
	Vector3(2, 0, 4), Vector3(-2, 0, 4), Vector3(-4, 90, 2), Vector3(-4, 90, -2)]


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
	_streets()
	_forum()
	_terrace()
	_sacred_way()
	_houses()
	_warehouses()
	_setup_navigation()


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box") -> Node3D:
	return _prop(PACK % id, at, yaw, 1.0, collision, true)


func _floor(id: String, x: float, z: float, y: float = FLOOR_Y) -> void:
	_piece(id, Vector3(x, y, z), 0.0, "none")


func _glow(at: Vector3, energy: float = 1.8, reach: float = 9.0) -> void:
	_light(at, RIFT, energy, reach)


## Pavage de dalles de 4 m sur un rectangle (bords alignés sur la grille de 4 m) ; une dalle sur `wear` est usée.
func _pave(area: Rect2, wear: int = 7, y: float = FLOOR_Y) -> void:
	var count: int = 0
	for x: int in range(int(area.position.x) + 2, int(area.end.x), 4):
		for z: int in range(int(area.position.y) + 2, int(area.end.y), 4):
			count += 1
			_floor("floor_dirt_large" if count % wear == 0 else "floor_tile_large", x, z, y)


## Rempart : murs jointifs au nord, à l'ouest et à l'est ; parapet bas au sud. Une paroi double chaque côté.
func _rampart() -> void:
	var north: Array[String] = ["wall", "wall", "wall_pillar", "wall", "wall_archedwindow_open", "wall_pillar"]
	var index: int = 0
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		_piece(north[index % north.size()], Vector3(x, 0, MIN.y - 0.6), 0, "none")
		if absi(x) > 4:
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


## Porte sud, Avenue (x −4 → 4) et Rue transversale (z −4 → 4), pavées sur toute leur longueur.
func _streets() -> void:
	_pave(Rect2(-4, 4, 8, 24))
	_pave(Rect2(-8, 24, 16, 4), 5)
	_pave(Rect2(-48, -4, 36, 8), 6)
	_pave(Rect2(12, -4, 36, 8), 6)
	# Porte : deux piliers dans l'alignement du parapet, torches à l'intérieur.
	_piece("pillar", Vector3(-5, 0, 29))
	_piece("pillar", Vector3(5, 0, 29))
	_torch(Vector3(-5, 0, 27))
	_torch(Vector3(5, 0, 27))
	_glow(Vector3(0, 3.0, 12), 1.4, 9.0)


## Forum (x −12 → 12, z −12 → 4) : dallé d'un bord à l'autre, portiques sur les flancs, colonnes d'abri.
func _forum() -> void:
	_pave(FORUM, 9)
	for spot: Vector2 in [Vector2(-1, -5), Vector2(1, -3), Vector2(-3, -3)]:
		_floor("floor_tile_small_broken_A" if spot.x < 0 else "floor_tile_small_broken_B", spot.x, spot.y, 0.02)
	# Portiques : piliers sur les bords ouest et est, au nord de la rue transversale.
	for z: int in [-10, -6]:
		_piece("pillar", Vector3(-13, 0, z))
		_piece("pillar", Vector3(13, 0, z))
	# Abris : quatre colonnes autour du lieu du boss (l'onde annoncée se brise sur elles).
	for spot: Vector2 in [Vector2(-7, -8), Vector2(7, -8), Vector2(-7, 1), Vector2(7, 1)]:
		_piece("pillar", Vector3(spot.x, 0, spot.y))
	_piece("candle_triple", Vector3(-2.5, 0, -4), 0, "none")
	_piece("candle_triple", Vector3(2.5, 0, -4), 0, "none")
	_glow(Vector3(0, 3.5, -4), 2.2, 12.0)


## Acropole (x −14 → 14, z −30 → −20, 2 m) : dalle pavée, grand escalier vers le Forum encadré de piliers, escalier
## est vers la Voie sacrée ; colonnade en façade, arches au fond.
func _terrace() -> void:
	var center: Vector2 = TERRACE.get_center()
	_box("Terrace", Vector3(center.x, TERRACE_HEIGHT * 0.5 - 0.05, center.y),
		Vector3(TERRACE.size.x, TERRACE_HEIGHT + 0.1, TERRACE.size.y), STONE.darkened(0.15))
	_pave(Rect2(-12, -28, 24, 8), 6, TERRACE_HEIGHT + FLOOR_Y)
	_module("stairs_wide", Vector3(0, 0, TERRACE.end.y), Vector3(1, 0.5, 1.5))
	_module("stairs_wide", Vector3(TERRACE.end.x, 0, -25), Vector3(1, 0.5, 1.5), 90)
	_piece("pillar", Vector3(-4.6, 0, -18.6))
	_piece("pillar", Vector3(4.6, 0, -18.6))
	for x: int in [-8, 0, 8]:
		_piece("wall_arched" if x != 0 else "wall_archedwindow_open", Vector3(x, TERRACE_HEIGHT, -29.5))
	for x: int in [-12, -7, 7, 12]:
		_piece("pillar", Vector3(x, TERRACE_HEIGHT, -21))
	_piece("rubble_half", Vector3(-11, TERRACE_HEIGHT, -27.6), 90)
	_piece("candle_triple", Vector3(3, TERRACE_HEIGHT, -27.5), 0, "none")
	_piece("candle_triple", Vector3(-3, TERRACE_HEIGHT, -27.5), 0, "none")
	_glow(Vector3(0, TERRACE_HEIGHT + 3.0, -26), 2.6, 12.0)


## Voie sacrée (x 16 → 24) du decumanus au pied de l'escalier est, puis Temple (x 26 → 44, z −24 → −6) : péristyle
## de piliers ouvert sur la voie et sur la rue, cella fermée au fond, éboulis d'un pilier tombé.
func _sacred_way() -> void:
	_pave(Rect2(16, -28, 8, 24), 5)
	for x: float in [26.0, 30.5, 35.0, 39.5, 44.0]:
		_piece("pillar", Vector3(x, 0, -6))
	for z: int in [-11, -16, -21]:
		_piece("pillar", Vector3(26, 0, z))
		if z != -16:
			_piece("pillar", Vector3(44, 0, z))
	_piece("rubble_half", Vector3(41.5, 0, -16), 90)
	for x: int in [31, 39]:
		_piece("wall_arched", Vector3(x, 0, -24.5))
	_piece("wall_gated", Vector3(35, 0, -24.5))
	_pave(Rect2(28, -24, 16, 16), 6)
	_floor("floor_tile_big_grate", 34, -14)
	_piece("candle_triple", Vector3(32, 0, -22), 0, "none")
	_piece("candle_triple", Vector3(38, 0, -22), 0, "none")
	_glow(Vector3(35, 3.5, -14), 2.0, 10.0)
	_glow(Vector3(20, 3.0, -24), 1.4, 7.0)


## Maison sans toit de 8 × 8 m. Emplacements (HOUSE_SLOTS) : "wall", "window", "broken" (brèche), "door" (pan de 2 m
## à l'angle et porte de 2 m : la porte du donjon est trop étroite pour la navigation), "half" (même pan, reste d'un
## mur tombé), "" (mur tombé : ouverture de 4 m).
func _house(center: Vector2, slots: Array[String]) -> void:
	for index: int in HOUSE_SLOTS.size():
		var slot: Vector3 = HOUSE_SLOTS[index]
		var at := Vector3(center.x + slot.x, 0, center.y + slot.z)
		match slots[index]:
			"wall":
				_piece("wall", at, slot.y)
			"window":
				_piece("wall_window_open", at, slot.y)
			"broken":
				_module("wall_broken", at, Vector3.ONE, slot.y)
			"door", "half":
				# Pan de 2 m à l'angle : porte de 2 m (« door ») ou reste d'un mur tombé (« half »).
				var along := Vector3(1, 0, 0) if slot.y == 0.0 else Vector3(0, 0, 1)
				var corner: float = signf(slot.x if slot.y == 0.0 else slot.z)
				_piece("wall_half", at + along * corner, slot.y)
	_floor("floor_dirt_large", center.x, center.y)


## Maisons (ouest) : rangées alignées de part et d'autre de la rue transversale et d'une rue nord-sud (x −36 → −28).
## Portes sur les rues ; la maison au nord-ouest s'est effondrée (éboulis dedans, pans encore debout).
func _houses() -> void:
	_pave(Rect2(-36, -28, 8, 24), 6)
	_pave(Rect2(-36, 4, 8, 24), 6)
	# Rangée ouest (x −44 → −36), portes à l'est sur la rue nord-sud.
	_house(Vector2(-40, -20), ["half", "", "door", "", "half", "", "half", "wall"])
	_piece("rubble_large", Vector3(-40, 0, -20), 90)
	_house(Vector2(-40, -8), ["wall", "window", "door", "wall", "door", "wall", "wall", "wall"])
	_house(Vector2(-40, 8), ["door", "wall", "wall", "door", "wall", "window", "wall", "wall"])
	_house(Vector2(-40, 20), ["wall", "broken", "door", "wall", "wall", "wall", "window", "wall"])
	_piece("rubble_half", Vector3(-41.5, 0, 21.8), 0)
	# Rangée est (x −28 → −20), portes à l'ouest et vers la rue transversale.
	_house(Vector2(-24, -20), ["wall", "window", "wall", "door", "wall", "wall", "door", "wall"])
	_house(Vector2(-24, -8), ["wall", "broken", "wall", "wall", "door", "wall", "door", "window"])
	_piece("rubble_half", Vector3(-23.2, 0, -9.4), 0)
	_house(Vector2(-24, 8), ["door", "wall", "wall", "window", "wall", "wall", "door", "wall"])
	_house(Vector2(-24, 20), ["wall", "wall", "door", "wall", "wall", "broken", "door", "wall"])
	# Façades de l'Avenue (x −16 → −8), portes sur l'Avenue et sur la rue.
	_house(Vector2(-12, 8), ["door", "wall", "wall", "door", "wall", "wall", "window", "wall"])
	_house(Vector2(-12, 20), ["wall", "window", "door", "wall", "wall", "broken", "wall", "wall"])
	_piece("rubble_half", Vector3(-14, 0, 26.5), 0)
	# Mobilier : tables, fûts, étagères effondrées.
	_piece("table_long_broken", Vector3(-41.5, 0, -8), 0)
	_piece("barrel_small_stack", Vector3(-42, 0, 10.5), 0)
	_piece("trunk_large_A", Vector3(-26, 0, -5.5), 15)
	_piece("table_long_broken", Vector3(-25.5, 0, 8), 0)
	_piece("keg", Vector3(-13.5, 0, 22), 0)
	for spot: Vector2 in [Vector2(-31, -14), Vector2(-33, 14), Vector2(-18, 3)]:
		_floor("floor_tile_small_weeds_A", spot.x, spot.y, 0.02)
	_glow(Vector3(-32, 3.0, -14))
	_glow(Vector3(-32, 3.0, 14))


## Entrepôts (sud-est) : mêmes îlots alignés, fûts et caisses en façade ; l'entrepôt du centre s'est effondré.
func _warehouses() -> void:
	_pave(Rect2(28, 4, 8, 24), 6)
	# Façades de l'Avenue (x 8 → 16).
	_house(Vector2(12, 8), ["wall", "door", "door", "wall", "wall", "wall", "wall", "window"])
	_house(Vector2(12, 20), ["window", "wall", "wall", "door", "wall", "wall", "broken", "wall"])
	# Rangée x 20 → 28 : un entrepôt debout, un effondré.
	_house(Vector2(24, 8), ["wall", "door", "door", "wall", "wall", "wall", "wall", "wall"])
	_house(Vector2(24, 20), ["wall", "", "half", "", "half", "", "", "half"])
	_piece("rubble_large", Vector3(24, 0, 20), 0)
	# Rangée x 36 → 44, portes à l'ouest sur la rue nord-sud.
	_house(Vector2(40, 8), ["door", "wall", "wall", "wall", "wall", "window", "door", "wall"])
	_house(Vector2(40, 20), ["wall", "wall", "wall", "broken", "wall", "wall", "door", "wall"])
	_piece("rubble_half", Vector3(41.5, 0, 20), 90)
	# Marchandises : en façade sur la rue (abris bas) et à l'intérieur.
	_piece("box_stacked", Vector3(10.6, 0, 9), 0)
	_piece("keg", Vector3(22, 0, 6), 0)
	_piece("keg", Vector3(21.8, 0, 9.8), 30)
	_piece("barrel_small_stack", Vector3(31, 0, 13.5), 90)
	_piece("box_stacked", Vector3(31.6, 0, 22.5), 0)
	_piece("barrel_small_stack", Vector3(31, 0, 27), 0)
	for spot: Vector2 in [Vector2(30, 24), Vector2(18, 14), Vector2(34, 6)]:
		_floor("floor_tile_small_weeds_A", spot.x, spot.y, 0.02)
	_glow(Vector3(32, 3.0, 16))


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		result.append(Vector3(x, 0, MAX.y - 1.5))
		if not (x > TERRACE.position.x - 1.0 and x < TERRACE.end.x + 7.0):
			result.append(Vector3(x, 0, MIN.y + 1.5))
	for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
		result.append(Vector3(MIN.x + 1.5, 0, z))
		result.append(Vector3(MAX.x - 1.5, 0, z))
	result.append(Vector3(4, TERRACE_HEIGHT, -26))
	result.append(Vector3(10, TERRACE_HEIGHT, -24))
	return result
