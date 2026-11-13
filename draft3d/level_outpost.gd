class_name DraftLevelOutpost
extends DraftLevel
## Quatrième niveau de la base 3D : l'Avant-poste des Glaces (92 × 64 m), base technique posée sur la banquise.
## Modules KayKit Space Base Bits (CC0, draft3d/spacebase/), agrandis quatre fois (miniatures) et posés par le
## centre de leur emprise, avec une collision simple.
##
## Quartiers, tous reliés, sans cul-de-sac :
## - l'Aire d'atterrissage (sud) : départ du Chasseur, module posé sur son aire, camions, caisses ;
## - la Base (centre) : quatre modules d'habitation, un tunnel qui barre le nord, une cour intérieure à deux portes ;
## - le Dépôt (ouest) : piles de fret en quinconce, couloirs serrés ;
## - le Champ solaire (est) : rangées de panneaux (abris bas) et éoliennes (seuls les mâts arrêtent les tirs) ;
## - le Plateau de forage (nord, 2 m) : deux escaliers, la foreuse au sommet ; le boss apparaît à son pied ;
## - les Éboulis (coins nord) : gros rochers.
## Limites : falaise de glace tout autour.

const MIN := Vector2(-46.0, -32.0)
const MAX := Vector2(46.0, 32.0)
const START := Vector3(0, 0.2, 26)
const BOSS_SPOT := Vector3(0, 0.2, -14)
const PLATEAU := Rect2(-14.0, -31.0, 28.0, 11.0)
const PLATEAU_HEIGHT := 2.0
const PACK := "res://draft3d/spacebase/%s.gltf"
const SCALE := 4.0
const ICE := Color("6f8fae")
const BEACON := Color("7fe6ff")

var _ice: StandardMaterial3D


func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	sky = Color("0c1420")
	ambient = Color("8fa9c9")
	sun = Color("d8ecff")
	sun_energy = 0.6
	_box("Ice", Vector3(0, -0.25, 0), Vector3(MAX.x - MIN.x + 2.0, 0.5, MAX.y - MIN.y + 2.0), ICE)
	_cliffs()
	_landing()
	_base()
	_depot()
	_solar_field()
	_plateau()
	_setup_navigation()


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box", size: float = SCALE) -> Node3D:
	var node: Node3D = _prop(PACK % id, at, yaw, size, collision, true)
	if id.begins_with("terrain") or id.begins_with("rock"):
		# Le pack est aux couleurs d'un désert rouge : roches et falaises sont repeintes en glace.
		for item: Node in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := item as MeshInstance3D
			for surface: int in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(surface, _ice_material())
	return node


func _ice_material() -> StandardMaterial3D:
	if _ice == null:
		_ice = StandardMaterial3D.new()
		_ice.albedo_color = Color("4f7397")
		_ice.roughness = 0.35
	return _ice


func _beacon(at: Vector3) -> void:
	_piece("lights", at, 0, "trunk", 3.0)
	_light(at + Vector3.UP * 2.6, BEACON, 1.6, 7.0)


## Falaise de glace : blocs de terrain jointifs tout autour, doublés d'une paroi (aucun jour entre deux blocs).
func _cliffs() -> void:
	for x: int in range(int(MIN.x) + 4, int(MAX.x) + 1, 8):
		_piece("terrain_tall", Vector3(x, 0, MIN.y - 4.2), 0, "none")
		_piece("terrain_low", Vector3(x, 0, MAX.y + 4.2), 0, "none")
	for z: int in range(int(MIN.y) + 4, int(MAX.y) + 1, 8):
		_piece("terrain_tall", Vector3(MIN.x - 4.2, 0, z), 0, "none")
		_piece("terrain_tall", Vector3(MAX.x + 4.2, 0, z), 0, "none")
	var width: float = MAX.x - MIN.x + 2.0
	var depth: float = MAX.y - MIN.y + 2.0
	_fence(Vector3(0, 2, MAX.y + 0.4), Vector3(width, 6, 0.4))
	_fence(Vector3(0, 2, MIN.y - 0.4), Vector3(width, 10, 0.4))
	_fence(Vector3(MIN.x - 0.4, 2, 0), Vector3(0.4, 10, depth))
	_fence(Vector3(MAX.x + 0.4, 2, 0), Vector3(0.4, 10, depth))


## Aire d'atterrissage (sud) : le module sur son aire, deux camions, du fret épars, des balises.
func _landing() -> void:
	_piece("landingpad_small", Vector3(-14, -1.2, 24))
	_piece("lander_A", Vector3(-14, 0.8, 24), 30)
	_piece("spacetruck_large", Vector3(11, 0, 27), 70)
	_piece("spacetruck_trailer", Vector3(15.5, 0, 28.4), 70)
	_piece("spacetruck", Vector3(24, 0, 20), -30)
	for spot: Vector3 in [Vector3(-4, 0, 19), Vector3(6, 0, 17), Vector3(-26, 0, 29), Vector3(30, 0, 28)]:
		_piece("cargo_A_packed", spot, 20)
		_piece("containers_B", spot + Vector3(2.4, 0, 0.6), 50)
	for side: int in [-1, 1]:
		_beacon(Vector3(side * 5.0, 0, 30))
		_beacon(Vector3(side * 38.0, 0, 16))


## Base (centre) : quatre modules en carré, un tunnel entre les deux du nord ; la cour s'ouvre au sud et sur les côtés.
func _base() -> void:
	_piece("basemodule_A", Vector3(-10, 0, -4), 0)
	_piece("basemodule_E", Vector3(10, 0, -4), 90)
	_piece("tunnel_straight_A", Vector3(0, 0, -4), 0)
	_piece("basemodule_B", Vector3(-10, 0, 9), 180)
	_piece("basemodule_garage", Vector3(10, 0, 9), 180)
	_piece("roofmodule_solarpanels", Vector3(-10, 4.0, -4), 0, "none")
	_piece("roofmodule_cargo_A", Vector3(10, 4.0, 9), 0, "none")
	_piece("cargo_B", Vector3(-2.5, 0, 4), 15)
	_piece("cargo_B_packed", Vector3(3, 0, 1.5), 60)
	_beacon(Vector3(-4.2, 0, 12.5))
	_beacon(Vector3(4.2, 0, 12.5))


## Dépôt (ouest) : piles de fret en quinconce et hangars, couloirs de 5 à 7 m.
func _depot() -> void:
	for row: int in 4:
		for column: int in 3:
			var at := Vector3(-41.0 + column * 7.5 + (3.5 if row % 2 == 1 else 0.0), 0, -22.0 + row * 9.0)
			_piece("cargo_A_stacked" if (row + column) % 2 == 0 else "cargo_B_stacked", at, 90.0 * column)
	_piece("cargodepot_A", Vector3(-27, 0, 14), 90)
	_piece("cargodepot_C", Vector3(-38, 0, 22), 0)
	_piece("containers_D", Vector3(-22, 0, -12), 30)
	_beacon(Vector3(-20.5, 0, 2))


## Champ solaire (est) : trois rangées de panneaux, deux éoliennes, une station.
func _solar_field() -> void:
	for row: int in 3:
		for column: int in 4:
			_piece("solarpanel", Vector3(24.0 + column * 5.5, 0, -6.0 + row * 7.0), 0)
	_piece("windturbine_tall", Vector3(40, 0, -20), 0, "trunk")
	_piece("windturbine_low", Vector3(26, 0, -18), 40, "trunk")
	_piece("structure_low", Vector3(34, 0, -27), 0)
	_piece("rocks_B", Vector3(42, 0, 24), 30)
	_piece("rocks_A", Vector3(21, 0, -27), 0)
	_beacon(Vector3(20.5, 0, 2))


## Plateau de forage (nord) : dalle de glace à 2 m, un escalier au sud et un à l'est ; la foreuse au sommet.
func _plateau() -> void:
	var center: Vector2 = PLATEAU.get_center()
	_box("Plateau", Vector3(center.x, PLATEAU_HEIGHT * 0.5 - 0.05, center.y),
		Vector3(PLATEAU.size.x, PLATEAU_HEIGHT + 0.1, PLATEAU.size.y), ICE.darkened(0.12))
	_module("stairs_wide", Vector3(center.x, 0, PLATEAU.end.y), Vector3(1, 0.5, 1.5))
	_module("stairs_wide", Vector3(PLATEAU.end.x, 0, center.y), Vector3(1, 0.5, 1.5), 90)
	_piece("drill_structure", Vector3(center.x - 7.0, PLATEAU_HEIGHT, center.y - 0.5))
	_piece("cargo_A", Vector3(center.x + 6.0, PLATEAU_HEIGHT, center.y - 3.0), 20)
	_beacon(Vector3(center.x - 12.0, PLATEAU_HEIGHT, PLATEAU.end.y - 1.2))
	_beacon(Vector3(center.x + 12.0, PLATEAU_HEIGHT, PLATEAU.end.y - 1.2))
	_piece("rocks_B", Vector3(-24, 0, -27), 200)
	_piece("rock_B", Vector3(-19, 0, -21), 0, "box", 5.0)


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x: int in range(int(MIN.x) + 2, int(MAX.x), 4):
		result.append(Vector3(x, 0, MAX.y - 1.5))
		if not (x > PLATEAU.position.x and x < PLATEAU.end.x):
			result.append(Vector3(x, 0, MIN.y + 1.5))
	for z: int in range(int(MIN.y) + 2, int(MAX.y), 4):
		result.append(Vector3(MIN.x + 1.5, 0, z))
		result.append(Vector3(MAX.x - 1.5, 0, z))
	result.append(Vector3(4, PLATEAU_HEIGHT, -28))
	result.append(Vector3(10, PLATEAU_HEIGHT, -24))
	return result
