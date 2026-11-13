class_name DraftLevelGraveyard
extends DraftLevel
## Deuxième niveau de la base 3D : le Cimetière des Cendres (88 × 64 m), en extérieur, de nuit.
## Modules KayKit Halloween Bits (CC0, draft3d/halloween/), importés tels quels avec une collision simple.
##
## Quartiers, tous reliés, sans cul-de-sac :
## - le Portail (sud) : départ du Chasseur sous l'arche, allée centrale bordée de lanternes ;
## - le Champ des tombes (sud-ouest) : rangées de tombes et de stèles, enclos à claire-voie : abris bas, couloirs ;
## - le Bois mort (sud-est) : arbres morts et pins, dont seuls les troncs arrêtent les tirs ;
## - la Crypte (centre-nord) : grand bâtiment à contourner, parvis où apparaît le boss ;
## - le Tertre (nord-ouest, 2 m) : butte à deux escaliers, autel au sommet ;
## - l'Ossuaire (nord-est) : cercueils et stèles serrés.
## Limites : grille tout autour, portail au sud.

const MIN := Vector2(-44.0, -32.0)
const MAX := Vector2(44.0, 32.0)
const START := Vector3(0, 0.2, 26)
const BOSS_SPOT := Vector3(0, 0.2, -2)
const MOUND := Rect2(-40.0, -30.0, 16.0, 12.0)
const MOUND_HEIGHT := 2.0
const PACK := "res://draft3d/halloween/%s.gltf"
const LANTERN := Color("ff9a4d")


func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	sky = Color("0a0e18")
	ambient = Color("8c98c2")
	sun = Color("b9c6ff")
	sun_energy = 0.55
	_ground()
	_fences()
	_paths()
	_mound()
	_crypt()
	_graves()
	_dead_wood()
	_ossuary()
	_setup_navigation()


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box", size: float = 1.0) -> Node3D:
	return _prop(PACK % id, at, yaw, size, collision)


func _ground() -> void:
	var size := Vector3(MAX.x - MIN.x + 2.0, 0.5, MAX.y - MIN.y + 2.0)
	_box("Ground", Vector3(0, -0.25, 0), size, Color("2c3a2b"))


func _fences() -> void:
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		_piece("fence_broken" if posmod(x, 20) == 6 else "fence", Vector3(x, 0, MIN.y - 0.3))
		if absi(x) > 2:
			_piece("fence", Vector3(x, 0, MAX.y + 0.3))
	for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
		_piece("fence", Vector3(MIN.x - 0.3, 0, z), 90)
		_piece("fence_broken" if posmod(z, 20) == 10 else "fence", Vector3(MAX.x + 0.3, 0, z), 90)
	# Portail sud : l'arche fermée marque l'entrée du cimetière (le Chasseur part juste devant).
	_piece("arch_gate", Vector3(-2, 0, MAX.y + 0.3))
	_piece("arch_gate", Vector3(2, 0, MAX.y + 0.3))
	for side: int in [-1, 1]:
		_piece("pumpkin_orange_jackolantern", Vector3(side * 5.5, 0, MAX.y - 1.2), -20.0 * side, "none")
		_light(Vector3(side * 5.5, 1.0, MAX.y - 1.4), LANTERN, 1.2, 4.0)
	# Rideau d'arbres derrière la grille : ferme l'horizon (hors carte, décor).
	for x: int in range(int(MIN.x), int(MAX.x) + 1, 8):
		_piece("tree_pine_yellow_large" if posmod(x, 16) == 0 else "tree_pine_orange_large", Vector3(x, 0, MIN.y - 4.0), 0, "none")
	for z: int in range(int(MIN.y) + 4, int(MAX.y), 8):
		_piece("tree_pine_orange_medium", Vector3(MIN.x - 3.5, 0, z), 0, "none")
		_piece("tree_pine_yellow_medium", Vector3(MAX.x + 3.5, 0, z), 0, "none")
	var width: float = MAX.x - MIN.x + 2.0
	var depth: float = MAX.y - MIN.y + 2.0
	_fence(Vector3(0, 2, MAX.y + 0.6), Vector3(width, 6, 0.4))
	_fence(Vector3(0, 2, MIN.y - 0.6), Vector3(width, 10, 0.4))
	_fence(Vector3(MIN.x - 0.6, 2, 0), Vector3(0.4, 10, depth))
	_fence(Vector3(MAX.x + 0.6, 2, 0), Vector3(0.4, 10, depth))


## Allée centrale du portail à la crypte, et allée transversale ; lanternes tous les dix mètres.
func _paths() -> void:
	var tiles: Array[String] = ["path_A", "path_B", "path_C"]
	var index: int = 0
	for z: int in range(-8, 31, 2):
		_piece(tiles[index % 3], Vector3(0, 0.02, z), 90.0 * (index % 4), "none")
		index += 1
	for x: int in range(-34, 35, 2):
		if x != 0:
			_piece(tiles[index % 3], Vector3(x, 0.02, 6), 90.0 * (index % 4), "none")
			index += 1
	for z: int in [-4, 6, 16, 26]:
		for side: int in [-1, 1]:
			_piece("post_lantern", Vector3(side * 2.6, 0, z), 90, "trunk")
			_light(Vector3(side * 2.6, 2.6, z), LANTERN, 1.5, 6.0)
	for x: int in [-30, -16, 16, 30]:
		_piece("post_lantern", Vector3(x, 0, 8.4), 0, "trunk")
		_light(Vector3(x, 2.6, 8.4), LANTERN, 1.5, 6.0)


## Tertre (nord-ouest) : butte à 2 m, un escalier au sud et un à l'est, autel et pins au sommet.
func _mound() -> void:
	var center: Vector2 = MOUND.get_center()
	_box("Mound", Vector3(center.x, MOUND_HEIGHT * 0.5 - 0.05, center.y),
		Vector3(MOUND.size.x, MOUND_HEIGHT + 0.1, MOUND.size.y), Color("34432f"))
	_module("stairs_wide", Vector3(center.x, 0, MOUND.end.y), Vector3(1, 0.5, 1.5))
	_module("stairs_wide", Vector3(MOUND.end.x, 0, center.y), Vector3(1, 0.5, 1.5), 90)
	_piece("shrine_candles", Vector3(center.x, MOUND_HEIGHT, center.y - 3.0))
	_light(Vector3(center.x, MOUND_HEIGHT + 1.6, center.y - 2.4), Color("ffd27a"), 1.8, 7.0)
	_piece("tree_pine_orange_medium", Vector3(MOUND.position.x + 2.0, MOUND_HEIGHT, MOUND.position.y + 2.0), 0, "trunk")
	_piece("tree_pine_yellow_small", Vector3(MOUND.end.x - 2.5, MOUND_HEIGHT, MOUND.position.y + 2.0), 0, "trunk")
	_piece("bench_decorated", Vector3(center.x - 4.5, MOUND_HEIGHT, center.y + 1.0), 90)
	_piece("fence_seperate", Vector3(center.x - 5.0, MOUND_HEIGHT, MOUND.end.y - 0.4))
	_piece("fence_seperate_broken", Vector3(center.x + 5.0, MOUND_HEIGHT, MOUND.end.y - 0.4))


## Crypte (centre-nord) : un grand volume à contourner ; son parvis est le lieu du boss.
func _crypt() -> void:
	_piece("crypt", Vector3(0, 0, -16))
	for side: int in [-1, 1]:
		_piece("pillar", Vector3(side * 6.0, 0, -10))
		_piece("pillar", Vector3(side * 6.0, 0, -22))
		_piece("coffin_decorated", Vector3(side * 9.5, 0, -16), 90)
		_piece("skull_candle", Vector3(side * 3.6, 0, -10.6), 0, "none")
		_light(Vector3(side * 3.6, 1.2, -10.6), Color("c8a0ff"), 1.4, 5.0)
	_piece("plaque_candles", Vector3(0, 0, -9.5), 0, "none")


## Champ des tombes (sud-ouest) : quatre rangées, des enclos à claire-voie, des passages entre les rangées.
func _graves() -> void:
	var kinds: Array[String] = ["grave_A", "gravestone", "grave_B", "gravemarker_A", "grave_A_destroyed", "gravemarker_B"]
	var index: int = 0
	for row: int in 4:
		var z: float = 11.0 + row * 5.5
		for column: int in 5:
			var x: float = -37.0 + column * 6.0 + (3.0 if row % 2 == 1 else 0.0)
			_piece(kinds[index % kinds.size()], Vector3(x, 0, z))
			index += 1
	for x: int in [-36, -26, -16]:
		_piece("fence_seperate" if x != -26 else "fence_seperate_broken", Vector3(x, 0, 9.0))
	_piece("fence_seperate", Vector3(-8.5, 0, 14), 90)
	_piece("fence_seperate", Vector3(-8.5, 0, 24), 90)
	_piece("tree_dead_large_decorated", Vector3(-12, 0, 19), 0, "trunk")
	_piece("ribcage", Vector3(-22, 0.3, 28.5), 30, "none")
	_piece("bone_A", Vector3(-30, 0.1, 9.8), 60, "none")


## Bois mort (sud-est) : troncs en quinconce ; les feuillages ne bloquent ni les tirs ni le passage.
func _dead_wood() -> void:
	var kinds: Array[String] = ["tree_dead_large", "tree_pine_orange_small", "tree_dead_medium", "tree_pine_yellow_medium",
		"tree_dead_small", "tree_pine_orange_medium"]
	var index: int = 0
	for row: int in 4:
		var z: float = 11.0 + row * 5.5
		for column: int in 5:
			var x: float = 11.0 + column * 6.5 + (3.2 if row % 2 == 1 else 0.0)
			if x < MAX.x - 3.0:
				_piece(kinds[index % kinds.size()], Vector3(x, 0, z), 37.0 * index, "trunk")
			index += 1
	_piece("pumpkin_yellow", Vector3(20, 0, 9.4), 0, "none")
	_piece("pumpkin_orange_small", Vector3(21.2, 0, 9.9), 0, "none")
	_piece("bench", Vector3(34, 0, 8.8))


## Ossuaire (nord-est) : cercueils et stèles serrés, deux arbres morts.
func _ossuary() -> void:
	for row: int in 3:
		var z: float = -28.0 + row * 6.0
		for column: int in 4:
			var x: float = 17.0 + column * 6.0 + (3.0 if row % 2 == 1 else 0.0)
			if (row + column) % 3 == 0:
				_piece("coffin", Vector3(x, 0, z), 90.0 * column)
			else:
				_piece("gravestone" if (row + column) % 2 == 0 else "grave_B", Vector3(x, 0, z))
	_piece("tree_dead_large", Vector3(41, 0, -8), 0, "trunk")
	_piece("tree_dead_medium", Vector3(14, 0, -29), 0, "trunk")
	_piece("shrine", Vector3(30, 0, -7.5))
	_light(Vector3(30, 1.8, -7.0), Color("c8a0ff"), 1.4, 6.0)
	_piece("skull", Vector3(36, 0, -6.5), 40, "none")


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		result.append(Vector3(x, 0, MAX.y - 1.5))
		if not (x > MOUND.position.x and x < MOUND.end.x):
			result.append(Vector3(x, 0, MIN.y + 1.5))
	for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
		if not (z > MOUND.position.y and z < MOUND.end.y):
			result.append(Vector3(MIN.x + 1.5, 0, z))
		result.append(Vector3(MAX.x - 1.5, 0, z))
	result.append(Vector3(-36, MOUND_HEIGHT, -27))
	result.append(Vector3(-28, MOUND_HEIGHT, -27))
	return result
