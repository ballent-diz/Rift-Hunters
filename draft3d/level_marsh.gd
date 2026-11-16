class_name DraftLevelMarsh
extends DraftLevel
## Huitième niveau de la base 3D : le Marais des Marées (90 × 90 m). Une carte qui change pendant la partie : des
## îlots reliés par des levées de terre, au milieu d'une eau trouble. Toutes les 80 s, la marée monte, noie les
## levées basses, puis se retire.
## - Levées hautes (au niveau des îlots) : jamais noyées ; elles font le grand tour (ouest et est).
## - Levées basses (25 cm plus bas) : les raccourcis vers le sanctuaire et entre les îlots ; noyées à marée haute.
## - Marée haute : on n'entre plus sur une levée noyée (un Chasseur déjà engagé peut en ressortir), la navigation est
##   recalculée sans elle (les monstres font le tour) ; l'eau n'arrête ni la vue ni les tirs.
## - Le sanctuaire (îlot central, lieu du boss) n'est jamais noyé : à marée haute, on ne l'atteint que par le nord.
## Ni étage ni escalier. Décor : pack KayKit Medieval Hexagon (CC0, × 5) et piliers du donjon.

signal tide_changed(high: bool)

const MIN := Vector2(-45.0, -45.0)
const MAX := Vector2(45.0, 45.0)
const START := Vector3(0, 0.45, 36)
const BOSS_SPOT := Vector3(0, 0.45, -6)
const LAND_TOP := 0.25
const LOW_TOP := 0.0
## Niveau de l'eau à marée basse et à marée haute (m) ; une levée basse est noyée au-dessus de LOW_TOP + 0,05.
const WATER_LOW := -0.35
const WATER_HIGH := 0.14
## Cycle de marée (s) : basse, montée, haute, descente.
const TIDE_LOW := 50.0
const TIDE_RISE := 8.0
const TIDE_HIGH := 16.0
const TIDE_FALL := 6.0
const PACK := "res://draft3d/medieval/%s.gltf"
const SCALE := 5.0
const MUD := Color("3d3a2a")
const LAND := Color("5d6b3a")
const DIKE := Color("7a6a44")
const WATER := Color(0.18, 0.36, 0.38, 0.82)
const RIFT := Color("b06bff")
## Îlots : centre (x, z) et rayon.
const ISLANDS: Array[Vector3] = [
	Vector3(0, 36, 8.0), Vector3(0, -6, 12.0), Vector3(-30, 10, 8.0), Vector3(30, 8, 8.0),
	Vector3(-28, -30, 7.5), Vector3(28, -30, 7.5), Vector3(-14, 22, 4.5), Vector3(14, 23, 4.5),
]
## Levées : îlot de départ, îlot d'arrivée, largeur, basse (noyée à marée haute).
const DIKES: Array[Dictionary] = [
	{"from": 0, "to": 6, "width": 5.0, "low": false},
	{"from": 6, "to": 2, "width": 5.0, "low": false},
	{"from": 2, "to": 4, "width": 5.0, "low": false},
	{"from": 4, "to": 1, "width": 5.0, "low": false},
	{"from": 0, "to": 7, "width": 5.0, "low": false},
	{"from": 7, "to": 3, "width": 5.0, "low": false},
	{"from": 3, "to": 5, "width": 5.0, "low": false},
	{"from": 5, "to": 1, "width": 5.0, "low": false},
	{"from": 0, "to": 1, "width": 4.5, "low": true},
	{"from": 2, "to": 1, "width": 4.0, "low": true},
	{"from": 3, "to": 1, "width": 4.0, "low": true},
	{"from": 6, "to": 7, "width": 4.0, "low": true},
	{"from": 4, "to": 5, "width": 4.5, "low": true},
]

var high_tide: bool = false
var tide_time: float = 0.0
## Marée suspendue (essais, captures) : `set_tide` la règle à la main.
var tide_running: bool = true
var _water: MeshInstance3D
var _land: Array[PackedVector2Array] = []
var _low: Array[Dictionary] = []


func build() -> void:
	name = "Level"
	bounds_min = MIN
	bounds_max = MAX
	start = START
	boss_spot = BOSS_SPOT
	sky = Color("101a1c")
	ambient = Color("8fa79a")
	sun = Color("d8e6c0")
	sun_energy = 0.55
	# Vérification : partir à un instant donné du cycle (--tide-at=60 : marée haute dès le départ).
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tide-at="):
			tide_time = float(arg.trim_prefix("--tide-at="))
	_bed()
	for island: Vector3 in ISLANDS:
		var outline: PackedVector2Array = _circle(Vector2(island.x, island.y), island.z)
		_land.append(outline)
		_slab("Island", outline, LAND_TOP, 2.5, LAND)
	for dike: Dictionary in DIKES:
		_dike(dike)
	_shores()
	_decor()
	_setup_navigation()


func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step: int in 12:
		var angle: float = TAU * step / 12.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Fond du marais (vase, sans collision : la navigation ne s'y pose pas) et surface de l'eau, animée par la marée.
func _bed() -> void:
	var bed := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = MAX - MIN + Vector2(30, 30)
	bed.mesh = plane
	var mud := StandardMaterial3D.new()
	mud.albedo_color = MUD.darkened(0.45)
	bed.material_override = mud
	bed.position = Vector3(0, -1.4, 0)
	add_child(bed)
	_water = MeshInstance3D.new()
	_water.name = "Water"
	var surface := PlaneMesh.new()
	surface.size = MAX - MIN + Vector2(30, 30)
	_water.mesh = surface
	var material := StandardMaterial3D.new()
	material.albedo_color = WATER
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.7
	material.metallic_specular = 0.2
	_water.material_override = material
	_water.position = Vector3(0, WATER_LOW, 0)
	add_child(_water)


## Levée de `from` à `to` : dalle entre les deux îlots (elle s'enfonce d'un mètre dans chacun) ; une levée basse a
## ses deux barrières (parois de marche, levées à marée basse) au bord des îlots.
func _dike(dike: Dictionary) -> void:
	var a: Vector3 = ISLANDS[int(dike["from"])]
	var b: Vector3 = ISLANDS[int(dike["to"])]
	var dir: Vector2 = (Vector2(b.x, b.y) - Vector2(a.x, a.y)).normalized()
	var side: Vector2 = dir.orthogonal() * float(dike["width"]) * 0.5
	var start_point: Vector2 = Vector2(a.x, a.y) + dir * (a.z - 1.0)
	var end_point: Vector2 = Vector2(b.x, b.y) - dir * (b.z - 1.0)
	var outline := PackedVector2Array([start_point - side, end_point - side, end_point + side, start_point + side])
	_land.append(outline)
	var low: bool = dike["low"]
	_slab("Dike", outline, LOW_TOP if low else LAND_TOP, 2.5, DIKE if low else LAND)
	if not low:
		return
	var body := get_child(get_child_count() - 1) as StaticBody3D
	var gates: Array[StaticBody3D] = []
	for edge: Vector2 in [Vector2(a.x, a.y) + dir * (a.z - 0.2), Vector2(b.x, b.y) - dir * (b.z - 0.2)]:
		var gate := StaticBody3D.new()
		gate.name = "FloodGate"
		gate.set_meta(&"fence", true)
		gate.collision_layer = 0
		add_child(gate)
		gate.position = Vector3(edge.x, 1.2, edge.y)
		gate.rotation.y = -atan2(side.y, side.x)
		var shape := BoxShape3D.new()
		shape.size = Vector3(float(dike["width"]) + 0.6, 2.4, 0.3)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		gate.add_child(collision)
		gates.append(gate)
	var middle: Vector2 = (start_point + end_point) * 0.5
	_low.append({"body": body, "gates": gates, "center": Vector3(middle.x, LOW_TOP, middle.y),
		"length": start_point.distance_to(end_point), "width": float(dike["width"]), "yaw": -atan2(dir.y, dir.x),
		"closed": false})


## Rives : parois de marche (couche 8, ni vue ni tirs) le long de tout bord de terre qui donne sur l'eau.
func _shores() -> void:
	for outline: PackedVector2Array in _land:
		for index: int in outline.size():
			var a: Vector2 = outline[index]
			var b: Vector2 = outline[(index + 1) % outline.size()]
			var pieces: int = maxi(1, ceili(a.distance_to(b)))
			var run_start: int = -1
			for piece: int in pieces + 1:
				var open: bool = piece < pieces and _faces_water(a, b, outline, (piece + 0.5) / pieces)
				if open and run_start < 0:
					run_start = piece
				elif not open and run_start >= 0:
					_shore(a.lerp(b, float(run_start) / pieces), a.lerp(b, float(piece) / pieces))
					run_start = -1


func _faces_water(a: Vector2, b: Vector2, outline: PackedVector2Array, along: float) -> bool:
	var normal: Vector2 = (b - a).orthogonal().normalized()
	var center := Vector2.ZERO
	for corner: Vector2 in outline:
		center += corner / outline.size()
	var point: Vector2 = a.lerp(b, along)
	if normal.dot(point - center) < 0.0:
		normal = -normal
	var outside: Vector2 = point + normal * 0.4
	for other: PackedVector2Array in _land:
		if other != outline and Geometry2D.is_point_in_polygon(outside, other):
			return false
	return true


func _shore(a: Vector2, b: Vector2) -> void:
	var body := StaticBody3D.new()
	body.name = "Shore"
	body.collision_layer = 8
	add_child(body)
	var middle: Vector2 = (a + b) * 0.5
	body.position = Vector3(middle.x, 1.0, middle.y)
	body.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	var shape := BoxShape3D.new()
	shape.size = Vector3(a.distance_to(b) + 0.2, 3.0, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


func _piece(id: String, at: Vector3, yaw: float = 0.0, collision: String = "box", size: float = SCALE) -> Node3D:
	return _prop(PACK % id, Vector3(at.x, LAND_TOP + at.y, at.z), yaw, size, collision, true)


## Décor : sanctuaire (quatre piliers, lueur de la Faille), saules et roseaux (arbres et roches du pack médiéval),
## campement de pêcheurs au départ.
func _decor() -> void:
	for angle: float in [45.0, 135.0, 225.0, 315.0]:
		var at: Vector3 = BOSS_SPOT + Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle))) * 6.5
		_prop("res://draft3d/dungeon/pillar.glb", Vector3(at.x, LAND_TOP, at.z), 0.0, 1.0, "box", true)
	_light(BOSS_SPOT + Vector3.UP * 3.5, RIFT, 2.8, 14.0)
	_piece("tent", Vector3(-4, 0, 38), 10)
	_piece("barrel", Vector3(4.5, 0, 37), 0)
	_piece("crate_A_small", Vector3(5, 0, 33), 20)
	for spot: Vector3 in [Vector3(-32, 0, 12), Vector3(-27, 0, 7), Vector3(31, 0, 11), Vector3(-29, 0, -32),
			Vector3(26, 0, -27), Vector3(32, 0, -32)]:
		# Le pied des arbres du pack descend sous leur origine : on les remonte pour qu'il affleure le sol.
		_piece("tree_single_A" if int(spot.x) % 2 == 0 else "tree_single_B", spot + Vector3.UP * 0.35, spot.z * 7.0,
			"trunk")
	for spot: Vector3 in [Vector3(-14, 0, 23), Vector3(15, 0, 22), Vector3(28, 0, 5), Vector3(-31, 0, -27)]:
		_piece("rock_single_B", spot, spot.x * 5.0)
	_light(Vector3(0, 2.5, 36), Color("ffb070"), 1.6, 9.0)


func _spawn_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index: int in ISLANDS.size():
		if index == 0 or index == 1:
			continue
		var island: Vector3 = ISLANDS[index]
		for step: int in 6:
			var angle: float = TAU * step / 6.0
			var reach: float = island.z - 2.0
			result.append(Vector3(island.x + cos(angle) * reach, LAND_TOP, island.y + sin(angle) * reach))
	return result


# --- Marée -----------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not ready_for_paths:
		return
	if tide_running:
		tide_time = fmod(tide_time + delta, TIDE_LOW + TIDE_RISE + TIDE_HIGH + TIDE_FALL)
		_water.position.y = water_level(tide_time)
		var flooded: bool = _water.position.y > LOW_TOP + 0.05
		if flooded != high_tide:
			_set_high(flooded, true)
	_update_gates()


## Hauteur de l'eau à l'instant `t` du cycle (montée et descente adoucies).
static func water_level(t: float) -> float:
	if t < TIDE_LOW:
		return WATER_LOW
	t -= TIDE_LOW
	if t < TIDE_RISE:
		return lerpf(WATER_LOW, WATER_HIGH, smoothstep(0.0, 1.0, t / TIDE_RISE))
	t -= TIDE_RISE
	if t < TIDE_HIGH:
		return WATER_HIGH
	t -= TIDE_HIGH
	return lerpf(WATER_HIGH, WATER_LOW, smoothstep(0.0, 1.0, t / TIDE_FALL))


## Marée haute ou basse, sans attendre le cycle (essais) ; `threaded` : navigation recalculée sans à-coup.
func set_tide(high: bool, threaded: bool = false) -> void:
	tide_running = false
	_water.position.y = WATER_HIGH if high else WATER_LOW
	_set_high(high, threaded)
	_update_gates()


func _set_high(high: bool, threaded: bool) -> void:
	high_tide = high
	# Une levée noyée sort de la navigation (couche 8 : on peut encore en ressortir) ; elle y revient à marée basse.
	for dike: Dictionary in _low:
		(dike["body"] as StaticBody3D).collision_layer = 8 if high else 1
	bake_navigation_mesh(threaded)
	tide_changed.emit(high)
	announce.emit("DRAFT_TIDE_HIGH" if high else "DRAFT_TIDE_LOW")


## Barrières des levées noyées : fermées dès que le Chasseur n'est plus dessus (il n'y est jamais piégé).
func _update_gates() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for dike: Dictionary in _low:
		var close: bool = high_tide
		if close and not dike["closed"]:
			var shape := BoxShape3D.new()
			shape.size = Vector3(float(dike["length"]) + 1.0, 3.0, float(dike["width"]) + 1.0)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis(Vector3.UP, float(dike["yaw"])), dike["center"] + Vector3.UP * 1.5)
			query.collision_mask = 4
			close = space.intersect_shape(query, 1).is_empty()
		if close != dike["closed"]:
			dike["closed"] = close
			for gate: StaticBody3D in dike["gates"]:
				gate.collision_layer = 8 if close else 0
