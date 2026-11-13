class_name DraftLevel
extends NavigationRegion3D
## Carte de la base 3D : socle commun des niveaux (modules avec collision, navigation, points d'apparition).
## Chaque niveau en hérite et s'assemble dans `build()` : DraftLevelRuins (1), DraftLevelGraveyard (2),
## DraftLevelVillage (3).
## `DraftLevel.create(order)` donne la carte d'un chapitre.

## Emprise de la carte (x, z), départ du Chasseur, lieu d'apparition du boss.
var bounds_min := Vector2(-24, -20)
var bounds_max := Vector2(24, 20)
var start := Vector3(0, 0.2, 0)
var boss_spot := Vector3.ZERO
## Ambiance : fond, lumière ambiante, soleil (couleur, énergie).
var sky := Color("101222")
var ambient := Color("b2b9d8")
var sun := Color("ffe4bc")
var sun_energy: float = 0.8
var ready_for_paths: bool = false
var _spawn_points: Array[Vector3] = []


## Carte du chapitre ; les chapitres sans carte propre jouent sur le niveau 1 en attendant.
static func create(order: int) -> DraftLevel:
	match order:
		2:
			return DraftLevelGraveyard.new()
		3:
			return DraftLevelVillage.new()
	return DraftLevelRuins.new()


func build() -> void:
	pass


## Points d'apparition candidats (pourtour) ; gardés s'ils tombent sur la navigation.
func _spawn_candidates() -> Array[Vector3]:
	return []


func _module(id: String, at: Vector3, size := Vector3.ONE, yaw: float = 0.0) -> Node3D:
	var instance: Node3D = (load("res://draft3d/modules/%s.tscn" % id) as PackedScene).instantiate()
	add_child(instance)
	instance.position = at
	instance.scale = size
	instance.rotation.y = deg_to_rad(yaw)
	return instance


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
## `walk_only` : la paroi n'arrête que la marche du Chasseur (berge d'une rivière), pas la vue ni les tirs.
func _fence(at: Vector3, size: Vector3, walk_only: bool = false) -> void:
	var body := StaticBody3D.new()
	body.name = "Fence"
	if walk_only:
		body.collision_layer = 8
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


## Élément de décor d'un pack importé tel quel (glTF), avec une collision simple : "box" (boîte englobante),
## "trunk" (tronc : les traits passent sous le feuillage), "none" (traversable).
## `centered` : le module est posé par le centre de son emprise au sol, et non par son origine (les pièces de bord
## d'un pack en tuiles ont leur origine au centre de la tuile, à plusieurs mètres de leur dessin).
func _prop(path: String, at: Vector3, yaw: float = 0.0, size: float = 1.0, collision: String = "box",
		centered: bool = false) -> Node3D:
	var instance: Node3D = (load(path) as PackedScene).instantiate()
	add_child(instance)
	instance.position = at
	instance.scale = Vector3.ONE * size
	instance.rotation.y = deg_to_rad(yaw)
	if collision == "none" and not centered:
		return instance
	var bounds := AABB()
	var first: bool = true
	for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if centered:
		var middle := Vector3(bounds.get_center().x, 0.0, bounds.get_center().z)
		instance.position = at - instance.basis * middle
	if collision == "none":
		return instance
	var body := StaticBody3D.new()
	instance.add_child(body)
	var shape_node := CollisionShape3D.new()
	if collision == "trunk":
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.35 / size
		trunk.height = 2.4 / size
		shape_node.shape = trunk
		shape_node.position = Vector3(bounds.get_center().x, 1.2 / size, bounds.get_center().z)
	else:
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(bounds.size.x, bounds.end.y, bounds.size.z)
		shape_node.shape = box_shape
		shape_node.position = Vector3(bounds.get_center().x, bounds.end.y * 0.5, bounds.get_center().z)
	body.add_child(shape_node)
	return instance


func _light(at: Vector3, color: Color, energy: float = 1.4, reach: float = 5.0) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	add_child(light)


## À appeler une fois la carte dans l'arbre : calcule la navigation et les points d'apparition du pourtour.
func bake() -> void:
	bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for candidate: Vector3 in _spawn_candidates():
		_add_spawn(candidate)
	ready_for_paths = true


func _add_spawn(pos: Vector3) -> void:
	var snapped: Vector3 = closest(pos)
	if snapped.distance_to(pos) < 1.5:
		_spawn_points.append(snapped)


func closest(pos: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, pos)


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true)


## Point d'apparition du pourtour : hors de portée immédiate du Chasseur, mais assez près pour que la horde
## arrive vite sur une grande carte (entre `min_distance` et `max_distance`, sinon le plus proche au-delà).
func spawn_point(rng: RandomNumberGenerator, avoid: Vector3, min_distance: float = 13.0,
		max_distance: float = 32.0) -> Vector3:
	var good: Array[Vector3] = []
	var fallback: Vector3 = _spawn_points[0]
	var fallback_distance: float = INF
	for candidate: Vector3 in _spawn_points:
		var distance: float = candidate.distance_to(avoid)
		if distance >= min_distance and distance <= max_distance:
			good.append(candidate)
		elif distance >= min_distance and distance < fallback_distance:
			fallback = candidate
			fallback_distance = distance
	return good[rng.randi() % good.size()] if not good.is_empty() else fallback


func spawn_points() -> Array[Vector3]:
	return _spawn_points
