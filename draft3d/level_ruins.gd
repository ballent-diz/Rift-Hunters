class_name DraftLevelRuins
extends DraftLevel
## Premier niveau de la base 3D : les Ruines des Veilleurs (96 × 56 m). Modules KayKit vérifiés (CC0), chacun avec
## sa collision ; tout est assemblé ici, la navigation est recalculée au lancement.
##
## Cinq quartiers reliés par des portes et des brèches, sans cul-de-sac :
## - le Parvis (sud) : départ du Chasseur, dégagé, quelques abris ;
## - la Cour (centre) : grande place, arche, murets, piliers ; le boss y apparaît ;
## - la Terrasse haute (nord, 2 m) : trois escaliers, parapets ;
## - les Entrepôts (ouest) : rangées de murs et de caisses, couloirs serrés pour semer une horde ;
## - la Colonnade (est) : forêt de piliers et petite terrasse d'angle avec son escalier.
## Limites visibles partout : murs au nord et sur les côtés, barrières basses au sud (côté caméra).

const MIN := Vector2(-48.0, -20.0)
const MAX := Vector2(48.0, 36.0)
## Demi-largeur de la Cour centrale et limite sud de la Cour (murs à portes au-delà).
const COURT_HALF := 24.0
const COURT_SOUTH := 20.0
const TERRACE_HEIGHT := 2.0
const TERRACE_HALF_WIDTH := 12.0
const TERRACE_FRONT := -12.0
## Petite terrasse d'angle de la Colonnade (nord-est).
const CORNER_TERRACE := Rect2(32.0, -20.0, 16.0, 8.0)
const START := Vector3(0, 0.2, 28)
const BOSS_SPOT := Vector3(0, 0.2, -4)


func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	_ground()
	_terrace()
	_corner_terrace()
	_limits()
	_court_walls()
	_shelters()
	_warehouses()
	_colonnade()
	_forecourt()
	var matter := Node3D.new()
	matter.set_script(preload("res://draft3d/matter/cour/cour_dressing.gd"))
	add_child(matter)
	matter.setup(self)
	_setup_navigation()


func _ground() -> void:
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
			if absf(x) < TERRACE_HALF_WIDTH and z < TERRACE_FRONT:
				continue
			if CORNER_TERRACE.has_point(Vector2(x, z)):
				continue
			_module("floor_tile_large", Vector3(x, 0, z))


func _terrace() -> void:
	var depth: float = TERRACE_FRONT - MIN.y
	_box("Terrace", Vector3(0, TERRACE_HEIGHT * 0.5 - 0.05, MIN.y + depth * 0.5),
		Vector3(TERRACE_HALF_WIDTH * 2.0, TERRACE_HEIGHT + 0.1, depth), Color("555567"))
	for x: int in range(-10, 11, 4):
		for z: int in [-18, -14]:
			_module("floor_tile_large", Vector3(x, TERRACE_HEIGHT, z))
	# Trois accès : on peut monter d'un côté et redescendre de l'autre (contournement, pas de cul-de-sac).
	_module("stairs_wide", Vector3(0, 0, TERRACE_FRONT), Vector3(1, 0.5, 1.5))
	_module("stairs_wide", Vector3(TERRACE_HALF_WIDTH, 0, -16), Vector3(1, 0.5, 1.5), 90)
	_module("stairs_wide", Vector3(-TERRACE_HALF_WIDTH, 0, -16), Vector3(1, 0.5, 1.5), -90)
	for x: int in [-8, 8]:
		_module("pillar_decorated", Vector3(x, TERRACE_HEIGHT, -17.5))
		_module("banner_red", Vector3(x, TERRACE_HEIGHT + 2.3, -16.65), Vector3.ONE * 0.65)
		_torch(Vector3(x, TERRACE_HEIGHT, -12.8))
	_module("chest", Vector3(0, TERRACE_HEIGHT, -18.6), Vector3.ONE * 0.8)
	# Parapets bas sur le devant de la terrasse, de part et d'autre de l'escalier : abris en hauteur.
	for x: int in [-8, 8]:
		_module("barrier", Vector3(x, TERRACE_HEIGHT, TERRACE_FRONT + 0.5))


func _corner_terrace() -> void:
	var rect: Rect2 = CORNER_TERRACE
	var center: Vector2 = rect.get_center()
	_box("CornerTerrace", Vector3(center.x, TERRACE_HEIGHT * 0.5 - 0.05, center.y),
		Vector3(rect.size.x, TERRACE_HEIGHT + 0.1, rect.size.y), Color("555567"))
	for x: int in [34, 38, 42, 46]:
		for z: int in [-18, -14]:
			_module("floor_tile_large", Vector3(x, TERRACE_HEIGHT, z))
	_module("stairs_wide", Vector3(center.x, 0, rect.end.y), Vector3(1, 0.5, 1.5))
	_module("chest", Vector3(center.x, TERRACE_HEIGHT, -18.6), Vector3.ONE * 0.8)
	_module("barrier", Vector3(35, TERRACE_HEIGHT, rect.end.y + 0.5))
	_module("barrier", Vector3(45, TERRACE_HEIGHT, rect.end.y + 0.5))
	_torch(Vector3(33.5, TERRACE_HEIGHT, -18.5))
	_torch(Vector3(46.5, TERRACE_HEIGHT, -18.5))


func _raised(x: float) -> bool:
	return absf(x) < TERRACE_HALF_WIDTH or (x > CORNER_TERRACE.position.x and x < CORNER_TERRACE.end.x)


func _limits() -> void:
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		_module("wall_cracked" if posmod(x, 16) == 2 else "wall", Vector3(x, TERRACE_HEIGHT if _raised(x) else 0.0, MIN.y - 0.5))
		_module("barrier", Vector3(x, 0, MAX.y + 0.4))
	for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
		_module("wall_broken" if posmod(z, 16) == 2 else "wall", Vector3(MIN.x - 0.5, 0, z), Vector3.ONE, 90)
		_module("wall_broken" if posmod(z, 16) == 10 else "wall", Vector3(MAX.x + 0.5, 0, z), Vector3.ONE, 90)
	# Les barrières et les murs brisés laissent des jours : une paroi invisible ferme la carte au même endroit.
	var width: float = MAX.x - MIN.x + 2.0
	var depth: float = MAX.y - MIN.y + 2.0
	var middle := Vector3((MIN.x + MAX.x) * 0.5, 2, (MIN.y + MAX.y) * 0.5)
	_fence(Vector3(middle.x, 2, MAX.y + 0.6), Vector3(width, 6, 0.4))
	_fence(Vector3(middle.x, 2, MIN.y - 0.6), Vector3(width, 10, 0.4))
	_fence(Vector3(MIN.x - 0.6, 2, middle.z), Vector3(0.4, 10, depth))
	_fence(Vector3(MAX.x + 0.6, 2, middle.z), Vector3(0.4, 10, depth))


## Enceinte de la Cour : murs percés de portes et de brèches vers les Entrepôts, la Colonnade et le Parvis.
func _court_walls() -> void:
	for side: int in [-1, 1]:
		for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
			if z == -6 or z == 26:
				continue  # brèches
			_module("wall_doorway" if z == 10 else ("wall_broken" if posmod(z, 12) == 2 else "wall"),
				Vector3(side * (COURT_HALF + 0.5), 0, z), Vector3.ONE, 90)
		_torch(Vector3(side * (COURT_HALF - 1.2), 0, -8.6))
		_torch(Vector3(side * (COURT_HALF - 1.2), 0, 23.4))
	for x: int in range(-22, 23, 4):
		if absi(x) == 14:
			continue  # brèches
		_module("wall_doorway" if x == -2 else ("wall_cracked" if posmod(x, 12) == 6 else "wall"),
			Vector3(x + 2 if x == -2 else x, 0, COURT_SOUTH + 0.5))
	_torch(Vector3(-3, 0, COURT_SOUTH + 1.6))
	_torch(Vector3(3, 0, COURT_SOUTH + 1.6))


func _shelters() -> void:
	# Arche au sud : une ligne de mur avec une porte, contournable par les deux côtés.
	_module("wall_doorway", Vector3(0, 0, 8))
	_module("wall_broken", Vector3(-4, 0, 8))
	_module("wall_broken", Vector3(4, 0, 8))
	# Murets est et ouest : deux lignes d'abri nord-sud au milieu des ailes de la Cour.
	for side: int in [-1, 1]:
		_module("wall", Vector3(side * 15, 0, -1), Vector3.ONE, 90)
		_module("wall_broken", Vector3(side * 15, 0, 3), Vector3.ONE, 90)
		for z: float in [-4.5, 2.5]:
			_module("pillar_decorated", Vector3(side * 7, 0, z), Vector3.ONE * 0.7)
		_module("crates_stacked", Vector3(side * 19, 0, 14), Vector3.ONE * 0.85)
		_module("barrel_large", Vector3(side * 19 + 1.5, 0, 14.7), Vector3.ONE * 0.85)
		_module("crates_stacked", Vector3(side * 20, 0, -10), Vector3.ONE * 0.85)
		_module("barrel_large", Vector3(side * 18.4, 0, -9.4), Vector3.ONE * 0.85)
		_torch(Vector3(side * 3, 0, 7.4))
		_torch(Vector3(side * 14.3, 0, -3.4))


## Entrepôts (ouest) : quatre rangées de murs, des piles de caisses en quinconce, des couloirs de 6 à 8 m.
func _warehouses() -> void:
	for row: int in 4:
		var z: float = -12.0 + row * 12.0
		var shift: float = 0.0 if row % 2 == 0 else 6.0
		_module("wall", Vector3(-40 + shift, 0, z))
		_module("wall_broken", Vector3(-36 + shift, 0, z))
		_module("crates_stacked", Vector3(-29 - shift * 0.5, 0, z + 5.0), Vector3.ONE * 0.9)
		_module("barrel_large", Vector3(-27.6 - shift * 0.5, 0, z + 5.8), Vector3.ONE * 0.85)
		_module("crates_stacked", Vector3(-44 + shift * 0.4, 0, z - 5.0), Vector3.ONE * 0.9)
		_module("barrel_large", Vector3(-45, 0, z + 2.0), Vector3.ONE * 0.85)
		_torch(Vector3(-46.6, 0, z + 6.0))


## Colonnade (est) : piliers en quinconce, la petite terrasse d'angle au nord.
func _colonnade() -> void:
	for row: int in 5:
		var z: float = -2.0 + row * 8.0
		for column: int in 3:
			var x: float = 30.0 + column * 6.0 + (3.0 if row % 2 == 1 else 0.0)
			if x < MAX.x - 2.0:
				_module("pillar_decorated", Vector3(x, 0, z), Vector3.ONE * 0.7)
		_torch(Vector3(46.6, 0, z + 4.0))
	_module("crates_stacked", Vector3(28, 0, -15), Vector3.ONE * 0.85)
	_module("barrel_large", Vector3(29.4, 0, -14.2), Vector3.ONE * 0.85)


## Parvis (sud) : départ du Chasseur, dégagé, avec deux abris et deux piliers.
func _forecourt() -> void:
	for side: int in [-1, 1]:
		_module("crates_stacked", Vector3(side * 9, 0, 31), Vector3.ONE * 0.85)
		_module("barrel_large", Vector3(side * 9 + 1.5, 0, 31.7), Vector3.ONE * 0.85)
		_module("pillar_decorated", Vector3(side * 18, 0, 27), Vector3.ONE * 0.7)
		_torch(Vector3(side * 22, 0, 34.5))


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		result.append(Vector3(x, 0, MAX.y - 1.5))
		if not _raised(x):
			result.append(Vector3(x, 0, MIN.y + 1.5))
	for z: int in range(int(MIN.y) + 6, int(MAX.y) - 2, 4):
		result.append(Vector3(MIN.x + 1.5, 0, z))
		result.append(Vector3(MAX.x - 1.5, 0, z))
	for x: int in [-9, -3, 3, 9, 38, 42]:
		result.append(Vector3(x, TERRACE_HEIGHT, -18.8))
	return result
