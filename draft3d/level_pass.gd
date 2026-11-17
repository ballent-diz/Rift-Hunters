class_name DraftLevelPass
extends DraftLevel
## Septième niveau de la base 3D : le Défilé Hurlant. Carte très longue et étroite (170 × 36 m) que la caméra suit
## d'ouest en est : une gorge entre une haute falaise au nord et un rebord de rochers bas au sud (côté caméra, il ne
## cache pas le jeu). Ni étage ni escalier : le relief, ce sont les masses rocheuses qui resserrent la gorge.
##
## Lecture, d'ouest en est (on avance vers le boss) :
## - le Campement (départ) : tentes, caisses, râtelier ;
## - goulet double (un rocher au milieu) → la Carrière : blocs taillés, échelle, brouette ;
## - goulet simple, serré, côté sud → le Cirque : la plus grande clairière, bosquets d'abri ;
## - goulet double → la Tour brisée : ruine de guet, caisses ;
## - goulet simple, côté nord → l'Arène des Pierres levées : cercle de menhirs, lieu du boss.
## Rochers et falaises : prismes modelés (sommet effilé, sans navigation dessus) ; décor : pack KayKit Medieval
## Hexagon (CC0, draft3d/medieval/), agrandi cinq fois.

const MIN := Vector2(-85.0, -14.0)
const MAX := Vector2(85.0, 14.0)
const START := Vector3(-76, 0.2, 2)
const BOSS_SPOT := Vector3(66, 0.2, 0)
const PACK := "res://draft3d/medieval/%s.gltf"
const SCALE := 5.0
const DUST := Color("5a4a3c")
const ROCK := Color("4a3f44")
const CLIFF := Color("3a3138")
const EMBER := Color("ff9a4a")
## Goulets : x du milieu, puis passages ouverts (intervalles de z) ; le reste de la largeur est de la roche.
const NECKS: Array[Dictionary] = [
	{"x": -59.0, "open": [Vector2(-9.0, -3.0), Vector2(3.0, 9.0)]},
	{"x": -28.0, "open": [Vector2(2.0, 7.5)]},
	{"x": 8.0, "open": [Vector2(-10.0, -4.0), Vector2(4.0, 10.0)]},
	{"x": 43.0, "open": [Vector2(-8.5, -2.0)]},
]
const NECK_DEPTH := 7.0
## Rebord nord de la falaise et rebord sud des rochers bas (z) : la gorge praticable est entre les deux.
const NORTH_EDGE := -13.0
const SOUTH_EDGE := 13.0



func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	sky = Color("1c1220")
	ambient = Color("b48a7a")
	sun = Color("ffb27a")
	sun_energy = 0.7
	_box("Ground", Vector3(0, -0.25, 0), Vector3(MAX.x - MIN.x + 4.0, 0.5, MAX.y - MIN.y + 4.0), DUST)
	_walls()
	_necks()
	_camp()
	_quarry()
	_cirque()
	_tower()
	_arena()
	_setup_navigation()


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box", size: float = SCALE) -> Node3D:
	return _prop(PACK % id, at, yaw, size, collision, true)


## Rocher : ellipse irrégulière à la base, sommet réduit (`taper`). Collision pleine (arrête marche, vue et tirs) ;
## son sommet, inaccessible, est marqué « décor » pour le contrôle de composition.
func _rock(center: Vector2, half: Vector2, height: float, color: Color = ROCK, taper: float = 0.45) -> void:
	var base := PackedVector2Array()
	for step: int in 9:
		var angle: float = TAU * step / 9.0 + _jitter(0.15)
		var stretch: float = 1.0 + _jitter(0.12)
		base.append(center + Vector2(cos(angle) * half.x, sin(angle) * half.y) * stretch)
	_massif(base, center, height, color, taper)


## Massif de roche (voir DraftLevel._rock_prism), posé au sol.
func _massif(points: PackedVector2Array, center: Vector2, height: float, color: Color, taper: float) -> void:
	_rock_prism(points, center, 0.0, height, color, taper)


## Falaise au nord (haute, de rocher en rocher), rebord bas au sud et aux deux bouts ; parois doublées.
func _walls() -> void:
	var x: float = MIN.x - 2.0
	while x < MAX.x + 4.0:
		_rock(Vector2(x, NORTH_EDGE - 5.0 + _jitter(0.6)), Vector2(6.0, 5.0), 8.0 + _jitter(2.0), CLIFF, 0.5)
		_rock(Vector2(x + 2.5, SOUTH_EDGE + 3.5 + _jitter(0.5)), Vector2(4.5, 3.5), 1.6 + _jitter(0.4), ROCK, 0.6)
		x += 6.5
	for end: float in [MIN.x - 3.0, MAX.x + 3.0]:
		for z: float in [-8.0, 0.0, 8.0]:
			_rock(Vector2(end, z), Vector2(4.0, 5.0), 6.0 + _jitter(1.5), CLIFF, 0.5)
	var width: float = MAX.x - MIN.x + 2.0
	_fence(Vector3(0, 2, MAX.y + 0.4), Vector3(width, 6, 0.4))
	_fence(Vector3(0, 2, MIN.y - 0.4), Vector3(width, 10, 0.4))
	_fence(Vector3(MIN.x - 0.4, 2, 0), Vector3(0.4, 10, MAX.y - MIN.y + 2.0))
	_fence(Vector3(MAX.x + 0.4, 2, 0), Vector3(0.4, 10, MAX.y - MIN.y + 2.0))


## Goulets : la roche comble la largeur de la gorge sauf les passages ouverts ; plus bas au sud (côté caméra).
func _necks() -> void:
	for neck: Dictionary in NECKS:
		var x: float = neck["x"]
		var edges: Array[float] = [NORTH_EDGE - 1.0]
		for gap: Vector2 in neck["open"]:
			edges.append(gap.x)
			edges.append(gap.y)
		edges.append(SOUTH_EDGE + 1.0)
		for index: int in range(0, edges.size(), 2):
			var from: float = edges[index]
			var to: float = edges[index + 1]
			if to - from < 0.5:
				continue
			var middle: float = (from + to) * 0.5
			var height: float = 6.0 if middle < 0.0 else 3.0
			# Mur de roche (rectangle aux angles abattus) : il ferme la gorge jusqu'au bord du passage.
			var half := Vector2(NECK_DEPTH * 0.5, (to - from) * 0.5 + 0.3)
			var outline := PackedVector2Array()
			for corner: Vector2 in [Vector2(-1, -0.6), Vector2(-0.6, -1), Vector2(0.6, -1), Vector2(1, -0.6),
					Vector2(1, 0.6), Vector2(0.6, 1), Vector2(-0.6, 1), Vector2(-1, 0.6)]:
				outline.append(Vector2(x, middle) + corner * half + Vector2(_jitter(0.4), 0))
			_massif(outline, Vector2(x, middle), height, ROCK, 0.55)
		_torch_light(Vector3(x - NECK_DEPTH * 0.5 - 1.5, 0, (neck["open"][0] as Vector2).x - 1.0))


func _torch_light(at: Vector3) -> void:
	_light(at + Vector3.UP * 2.5, EMBER, 1.2, 7.0)


## Campement (x −85 → −63) : tentes contre la falaise, caisses, râtelier, feu.
func _camp() -> void:
	_piece("tent", Vector3(-78, 0, -8), 20)
	_piece("tent", Vector3(-70, 0, -9), -10)
	_piece("crate_A_big", Vector3(-66, 0, 8), 15)
	_piece("crate_long_A", Vector3(-80, 0, 9), 90)
	_piece("weaponrack", Vector3(-73, 0, -4), 0)
	_piece("flag_red", Vector3(-82, 0, 0), 0, "trunk")
	_light(Vector3(-74, 2.0, 4), EMBER, 2.0, 9.0)


## Carrière (x −52 → −35) : blocs taillés, échelle contre la falaise, brouette ; deux blocs servent d'abri.
func _quarry() -> void:
	_piece("resource_stone", Vector3(-46, 0, -7), 30)
	_piece("resource_stone", Vector3(-40, 0, 5), -20)
	_piece("ladder", Vector3(-44, 0, -12.2), 0, "none")
	_piece("wheelbarrow", Vector3(-38, 0, -4), 60)
	_rock(Vector2(-48, 7), Vector2(1.6, 1.4), 2.2)
	_piece("rock_single_C", Vector3(-36, 0, 10), 0)


## Cirque (x −20 → 0) : la grande clairière ; deux bosquets et des rochers isolés pour se couvrir.
func _cirque() -> void:
	for spot: Vector2 in [Vector2(-15, -6), Vector2(-5, 6)]:
		_piece("trees_A_medium", Vector3(spot.x, 0, spot.y), _jitter(90.0), "trunk")
	_piece("tree_single_B", Vector3(-18, 0, 7), 0, "trunk")
	_piece("tree_single_A", Vector3(-2, 0, -9), 0, "trunk")
	_rock(Vector2(-10, 0), Vector2(1.8, 1.5), 2.4)


## Tour brisée (x 16 → 35) : ruine de guet adossée à la falaise, caisses et sacs d'une halte abandonnée.
func _tower() -> void:
	_piece("building_destroyed", Vector3(26, 0, -8), 0)
	_piece("crate_B_big", Vector3(20, 0, 6), 20)
	_piece("sack", Vector3(22, 0, 8), 0, "none")
	_piece("barrel", Vector3(32, 0, 5), 0)
	_piece("trees_B_small", Vector3(34, 0, -6), 0, "trunk")


## Arène des Pierres levées (x 50 → 85) : cercle de menhirs (rayon 11 m) autour du lieu du boss, ouvert vers le
## goulet ; lueur de la Faille au centre.
func _arena() -> void:
	# Huit menhirs, sauf les deux qui feraient face au goulet (ouest) : on entre dans le cercle par là.
	for step: int in 8:
		var angle: float = PI + TAU * (step + 0.5) / 8.0
		if step == 0 or step == 7:
			continue
		var at := Vector2(BOSS_SPOT.x, BOSS_SPOT.z) + Vector2(cos(angle) * 11.0, sin(angle) * 9.0)
		_rock(at, Vector2(1.7, 1.3), 5.5 + _jitter(0.8), CLIFF, 0.45)
		_light(Vector3(at.x, 0.6, at.y), Color("b06bff"), 0.9, 3.5)
	_light(BOSS_SPOT + Vector3.UP * 3.5, Color("b06bff"), 3.4, 16.0)
	_piece("rock_single_D", Vector3(80, 0, -9), 0)
	_piece("rock_single_B", Vector3(80, 0, 9), 0)


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var x: float = MIN.x + 3.0
	while x < MAX.x - 2.0:
		# Pas de point dans un goulet : il tomberait dans la roche.
		var in_neck: bool = false
		for neck: Dictionary in NECKS:
			in_neck = in_neck or absf(x - float(neck["x"])) < NECK_DEPTH * 0.5 + 3.0
		if not in_neck:
			result.append(Vector3(x, 0, NORTH_EDGE + 1.5))
			result.append(Vector3(x + 2.0, 0, SOUTH_EDGE - 1.5))
		x += 4.0
	return result
