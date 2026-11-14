extends Node3D
## Habillage de la Cour seulement : maillages UV et matériaux, puis détails sans corps physique.

const ROOT := "res://draft3d/matter/cour/"
const GRASS := preload("res://draft3d/matter/cour/grass_mesh.gd")
var _scaled_materials := {}
var _ground_positions := PackedVector3Array()
var _ground_uvs := PackedVector2Array()
var _grass_meshes := {}

func setup(level: Node3D) -> void:
	name = "CourMatter"
	if OS.get_cmdline_user_args().has("--cour-matter=0"):
		return
	apply_matter(level)

func apply_matter(level: Node3D) -> void:
	var prepared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "uv_report.json"))["modules"]
	for child: Node in level.get_children():
		if child == self or not child is Node3D:
			continue
		var id := child.scene_file_path.get_file().get_basename()
		if id == "floor_tile_large":
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				append_ground(instance, level)
		elif prepared.has(id):
			for mesh_entry: Dictionary in prepared[id]:
				var instance := child.get_node(mesh_entry["node_path"]) as MeshInstance3D
				instance.mesh = load(mesh_entry["path"])
				instance.material_override = null
				for surface: int in instance.mesh.get_surface_count():
					instance.set_surface_override_material(surface, null)
					if id != "stairs_wide":
						var scale_value := (child as Node3D).scale.x
						var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
						instance.set_surface_override_material(surface, scaled_material(material, scale_value))
		elif child.name in ["Terrace", "CornerTerrace"]:
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				texture_foundation(instance)
	create_ground()
	create_meadow()
	place_details()

func create_meadow() -> void:
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "grass_regions.json"))
	var mask := {}
	for point: Array in regions.points:
		mask[Vector2i(floori(float(point[0]) * 2), floori(float(point[1]) * 2))] = true
	var groups := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 241115
	for tile: int in range(0, _ground_positions.size(), 6):
		var start := _ground_positions[tile]
		var end := _ground_positions[tile + 2]
		for x: int in range(roundi(start.x * 2), roundi(end.x * 2)):
			for z: int in range(roundi(start.z * 2), roundi(end.z * 2)):
				var key := Vector2i(posmod(x, 32), posmod(z, 32))
				if not mask.has(key):
					continue
				var chunk := Vector2i(floori(float(x) / 32), floori(float(z) / 32))
				if not groups.has(chunk):
					groups[chunk] = []
				var at := Vector3(x * 0.5 + 0.25, start.y, z * 0.5 + 0.25)
				at += Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
				var basis_value := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15))
				groups[chunk].append(Transform3D(basis_value, at))
	var meadow := Node3D.new()
	meadow.name = "CourMeadow"
	add_child(meadow)
	var mesh := GRASS.build(0, true)
	var count := 0
	for chunk: Vector2i in groups:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = groups[chunk].size()
		for i: int in groups[chunk].size():
			multimesh.set_instance_transform(i, groups[chunk][i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		meadow.add_child(instance)
		count += multimesh.instance_count
	meadow.set_meta("grass_instances", count)

func append_ground(instance: MeshInstance3D, level: Node3D) -> void:
	# Les corps physiques KayKit restent en place ; seul le dallage visible est masqué.
	var bounds := instance.mesh.get_aabb()
	var relative := level.global_transform.affine_inverse() * instance.global_transform
	var corners := [Vector3(bounds.position.x, bounds.end.y, bounds.position.z),
		Vector3(bounds.end.x, bounds.end.y, bounds.position.z),
		Vector3(bounds.end.x, bounds.end.y, bounds.end.z),
		Vector3(bounds.position.x, bounds.end.y, bounds.end.z)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		var point: Vector3 = relative * corners[index]
		_ground_positions.append(point)
		# Phase commune : le motif ne repart jamais de zéro au bord d'un module de quatre mètres.
		_ground_uvs.append(Vector2(point.x, point.z) / 16.0)
	instance.visible = false
	instance.set_meta("cour_floor_replaced", true)

func create_ground() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _ground_positions
	arrays[Mesh.ARRAY_TEX_UV] = _ground_uvs
	var normals := PackedVector3Array()
	normals.resize(_ground_positions.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, load(ROOT + "materials/terrain.tres"))
	var instance := MeshInstance3D.new()
	instance.name = "CourTerrain"
	instance.mesh = mesh
	add_child(instance)

func scaled_material(source: StandardMaterial3D, value: float) -> StandardMaterial3D:
	if is_equal_approx(value, 1.0):
		return source
	var key := source.resource_path + "@" + str(snappedf(value, 0.001))
	if not _scaled_materials.has(key):
		var material := source.duplicate() as StandardMaterial3D
		material.uv1_scale = Vector3(value, value, 1)
		_scaled_materials[key] = material
	return _scaled_materials[key]

func texture_foundation(instance: MeshInstance3D) -> void:
	var arrays := instance.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv := PackedVector2Array()
	for i: int in positions.size():
		var point := positions[i]
		var normal := normals[i].abs()
		if normal.y >= normal.x and normal.y >= normal.z:
			uv.append(Vector2(point.x, point.z) / 4.0)
		elif normal.x >= normal.z:
			uv.append(Vector2(point.z, point.y) / 4.0)
		else:
			uv.append(Vector2(point.x, point.y) / 4.0)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, load(ROOT + "materials/stone.tres"))
	instance.mesh = mesh
	instance.material_override = null
	instance.set_surface_override_material(0, null)

func place_details() -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "placements.json"))["placements"]
	for entry: Dictionary in entries:
		if str(entry["visual_id"]).begins_with("object.cour_grass_"):
			place_grass(entry)
			continue
		var sprite := Sprite3D.new()
		sprite.name = entry["name"]
		var asset: Dictionary = Assets.entry(StringName(entry["visual_id"]))
		sprite.texture = load(str(asset["sheet"]))
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.5
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.pixel_size = 0.037 * float(asset["scale"])
		sprite.offset = Vector2.ZERO
		sprite.position = Vector3(entry["position"][0], entry["position"][1], entry["position"][2])
		var orientation: String = entry["orientation"]
		if orientation == "ground":
			sprite.axis = Vector3.AXIS_Y
			sprite.rotation.y = deg_to_rad(float(entry["yaw"]))
			sprite.position += sprite.basis * Vector3(0, 0, (32.0 - float(asset["anchor"][1])) * sprite.pixel_size)
		elif orientation == "upright":
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			# Sprite3D exprime l'offset Y dans son plan local : le pied reste sur le sol.
			sprite.offset = Vector2.ZERO
			sprite.position.y += (float(asset["anchor"][1]) - 32.0) * sprite.pixel_size
		else:
			sprite.position.y += (float(asset["anchor"][1]) - 32.0) * sprite.pixel_size
		sprite.set_meta("cour_detail", entry["visual_id"])
		add_child(sprite)

func place_grass(entry: Dictionary) -> void:
	var variant: int = ["object.cour_grass_olive", "object.cour_grass_broad", "object.cour_grass_dry"].find(entry.visual_id)
	if not _grass_meshes.has(variant):
		_grass_meshes[variant] = GRASS.build(variant)
	var instance := MeshInstance3D.new()
	instance.name = entry.name
	instance.mesh = _grass_meshes[variant]
	instance.position = Vector3(entry.position[0], entry.position[1], entry.position[2])
	instance.rotation.y = deg_to_rad(float(entry.yaw))
	instance.set_meta("cour_detail", entry.visual_id)
	instance.set_meta("cour_grass_3d", true)
	add_child(instance)
