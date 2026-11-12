class_name DraftLevel
extends NavigationRegion3D
## Carte du premier jet : la Cour des Veilleurs. Modules KayKit vérifiés (CC0), chacun avec sa collision.
## Grande cour (48 × 40 m), terrasse nord à 2 m reliée par trois escaliers (centre, est, ouest), abris (murets, piliers,
## caisses, arche), limites visibles : murs au nord et sur les côtés, barrières basses au sud (côté caméra).
## Tout est assemblé ici : déplacer une ligne déplace le module et sa collision ; la navigation est recalculée.

const HALF := Vector2(24.0, 20.0)
const TERRACE_HEIGHT := 2.0
const TERRACE_HALF_WIDTH := 12.0
const TERRACE_FRONT := -12.0
const START := Vector3(0, 0.2, 14)
const BOSS_SPOT := Vector3(0, 0.2, -4)

var ready_for_paths: bool = false
var _spawn_points: Array[Vector3] = []


func build() -> void:
	name = "Level"
	_ground()
	_terrace()
	_limits()
	_shelters()
	_setup_navigation()


func _module(id: String, at: Vector3, size := Vector3.ONE, yaw: float = 0.0) -> Node3D:
	var instance: Node3D = (load("res://draft3d/modules/%s.tscn" % id) as PackedScene).instantiate()
	add_child(instance)
	instance.position = at
	instance.scale = size
	instance.rotation.y = deg_to_rad(yaw)
	return instance


func _ground() -> void:
	for x: int in range(-22, 23, 4):
		for z: int in range(-18, 19, 4):
			if absf(x) < TERRACE_HALF_WIDTH and z < TERRACE_FRONT:
				continue
			_module("floor_tile_large", Vector3(x, 0, z))


func _terrace() -> void:
	var depth: float = HALF.y + TERRACE_FRONT
	_box("Terrace", Vector3(0, TERRACE_HEIGHT * 0.5 - 0.05, -HALF.y + depth * 0.5),
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


func _limits() -> void:
	for x: int in range(-22, 23, 4):
		var raised: bool = absf(x) < TERRACE_HALF_WIDTH
		_module("wall_cracked" if x % 8 == 2 else "wall", Vector3(x, TERRACE_HEIGHT if raised else 0.0, -HALF.y - 0.5))
		_module("barrier", Vector3(x, 0, HALF.y + 0.4))
	for z: int in range(-18, 19, 4):
		for side: int in [-1, 1]:
			_module("wall_broken" if z % 8 == 2 else "wall", Vector3(side * (HALF.x + 0.5), 0, z), Vector3.ONE, 90)
	# Les barrières et les murs brisés laissent des jours : une paroi invisible ferme la carte au même endroit.
	_fence(Vector3(0, 2, HALF.y + 0.6), Vector3(HALF.x * 2.0 + 2.0, 6, 0.4))
	_fence(Vector3(0, 2, -HALF.y - 0.6), Vector3(HALF.x * 2.0 + 2.0, 10, 0.4))
	for side: int in [-1, 1]:
		_fence(Vector3(side * (HALF.x + 0.6), 2, 0), Vector3(0.4, 10, HALF.y * 2.0 + 2.0))


func _shelters() -> void:
	# Arche au sud : une ligne de mur avec une porte, contournable par les deux côtés.
	_module("wall_doorway", Vector3(0, 0, 8))
	_module("wall_broken", Vector3(-4, 0, 8))
	_module("wall_broken", Vector3(4, 0, 8))
	# Murets est et ouest : deux lignes d'abri nord-sud au milieu des ailes.
	for side: int in [-1, 1]:
		_module("wall", Vector3(side * 15, 0, -1), Vector3.ONE, 90)
		_module("wall_broken", Vector3(side * 15, 0, 3), Vector3.ONE, 90)
		for z: float in [-4.5, 2.5]:
			_module("pillar_decorated", Vector3(side * 7, 0, z), Vector3.ONE * 0.7)
		_module("crates_stacked", Vector3(side * 19, 0, 12), Vector3.ONE * 0.85)
		_module("barrel_large", Vector3(side * 19 + 1.5, 0, 12.7), Vector3.ONE * 0.85)
		_module("crates_stacked", Vector3(side * 20, 0, -9), Vector3.ONE * 0.85)
		_module("barrel_large", Vector3(side * 18.4, 0, -8.4), Vector3.ONE * 0.85)
		_torch(Vector3(side * 3, 0, 7.4))
		_torch(Vector3(side * 14.3, 0, -3.4))
		_torch(Vector3(side * 22.5, 0, 17))
		_torch(Vector3(side * 22.5, 0, -10))


func _box(id: String, at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = id
	add_child(body)
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	body.add_child(mesh)


## Paroi de collision sans maillage, toujours doublée d'une limite visible (mur ou barrière).
func _fence(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Fence"
	add_child(body)
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


func _torch(at: Vector3) -> void:
	_module("torch_lit", at, Vector3.ONE * 0.8)
	var light := OmniLight3D.new()
	light.position = at + Vector3.UP * 1.6
	light.light_color = Color("ffac66")
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)


func _setup_navigation() -> void:
	var map: RID = get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.2)
	NavigationServer3D.map_set_cell_height(map, 0.1)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.6
	mesh.agent_max_climb = 0.3
	mesh.agent_max_slope = 48.0
	mesh.cell_size = 0.2
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	navigation_mesh = mesh


## À appeler une fois la carte dans l'arbre : calcule la navigation et les points d'apparition du pourtour.
func bake() -> void:
	bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for x: int in range(-22, 23, 4):
		_add_spawn(Vector3(x, 0, HALF.y - 1.5))
		if absf(x) > TERRACE_HALF_WIDTH + 2.0:
			_add_spawn(Vector3(x, 0, -HALF.y + 1.5))
	for z: int in range(-14, 15, 4):
		_add_spawn(Vector3(-HALF.x + 1.5, 0, z))
		_add_spawn(Vector3(HALF.x - 1.5, 0, z))
	for x: int in [-9, -3, 3, 9]:
		_add_spawn(Vector3(x, TERRACE_HEIGHT, -18.8))
	ready_for_paths = true


func _add_spawn(pos: Vector3) -> void:
	var snapped: Vector3 = closest(pos)
	if snapped.distance_to(pos) < 1.5:
		_spawn_points.append(snapped)


func closest(pos: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, pos)


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true)


## Point d'apparition du pourtour, à bonne distance du Chasseur.
func spawn_point(rng: RandomNumberGenerator, avoid: Vector3, min_distance: float = 13.0) -> Vector3:
	var best: Vector3 = _spawn_points[0]
	for attempt: int in 8:
		var candidate: Vector3 = _spawn_points[rng.randi() % _spawn_points.size()]
		if candidate.distance_to(avoid) >= min_distance:
			return candidate
		if candidate.distance_to(avoid) > best.distance_to(avoid):
			best = candidate
	return best


func spawn_points() -> Array[Vector3]:
	return _spawn_points
