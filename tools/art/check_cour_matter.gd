extends Node3D
## Contrôle ciblé : triangles visuels, UV source, collisions, poses et navigation avant/après.

const ROOT := "res://draft3d/matter/cour/"
const MODULES := ["wall", "wall_cracked", "wall_broken", "stairs_wide",
	"pillar_decorated", "wall_doorway", "barrier", "banner_red", "crates_stacked", "barrel_large", "chest"]

func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(func() -> void: get_tree().quit(1))
	call_deferred("verify")

func triangles(mesh: Mesh, original_uv: bool) -> Array:
	var result := []
	for surface: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV if original_uv else Mesh.ARRAY_TEX_UV2]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices = PackedInt32Array(range(positions.size()))
		for index: int in range(0, indices.size(), 3):
			var corners := []
			var corner_normals := []
			for corner: int in 3:
				var i: int = indices[index + corner]
				corners.append([str(positions[i]), str(uvs[i])])
				corner_normals.append(normals[i])
			result.append({"corners": JSON.stringify(corners), "normals": corner_normals})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.corners < b.corners)
	return result

func collisions(level: Node3D) -> Array:
	var result := []
	for node: CollisionShape3D in level.find_children("*", "CollisionShape3D", true, false):
		var properties := {}
		for property: Dictionary in node.shape.get_property_list():
			if property.name in ["size", "points", "data", "radius", "height", "plane", "margin"]:
				properties[property.name] = str(node.shape.get(property.name))
		var body := node.get_parent() as CollisionObject3D
		result.append(JSON.stringify([str(node.global_transform), node.shape.get_class(), properties,
			node.disabled, body.collision_layer, body.collision_mask]))
	result.sort()
	return result

func modules(level: Node3D) -> Array:
	var result := []
	for node: Node in level.get_children():
		if node is Node3D and not node.scene_file_path.is_empty():
			result.append([node.scene_file_path, str((node as Node3D).transform)])
	return result

func navigation(level: NavigationRegion3D) -> Array:
	level.bake_navigation_mesh(false)
	var mesh := level.navigation_mesh
	var result := [str(mesh.get_vertices())]
	for index: int in mesh.get_polygon_count():
		result.append(str(mesh.get_polygon(index)))
	return result

func verify() -> void:
	assert(OS.get_cmdline_user_args().has("--cour-matter=0"), "Lancer le contrôle avec --cour-matter=0")
	var triangle_count := 0
	var max_normal_error := 0.0
	var prepared_modules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "uv_report.json"))["modules"]
	for id: String in MODULES:
		var node := (load("res://draft3d/modules/%s.tscn" % id) as PackedScene).instantiate()
		for mesh_entry: Dictionary in prepared_modules[id]:
			var instance := node.get_node(mesh_entry["node_path"]) as MeshInstance3D
			var prepared := load(mesh_entry["path"]) as Mesh
			var before := triangles(instance.mesh, true)
			var after := triangles(prepared, false)
			assert(before.size() == after.size(), "Nombre de triangles différent : " + id)
			for i: int in before.size():
				assert(before[i].corners == after[i].corners, "Géométrie/UV2 modifiées : " + id)
				for corner: int in 3:
					var error: float = before[i].normals[corner].distance_to(after[i].normals[corner])
					max_normal_error = maxf(max_normal_error, error)
					assert(error < 0.0002, "Normale modifiée : " + id)
			assert(instance.mesh.get_aabb().is_equal_approx(prepared.get_aabb()), id)
			triangle_count += before.size()
		node.free()
	var level := DraftLevelRuins.new()
	add_child(level)
	level.build()
	var before_collision := collisions(level)
	var before_modules := modules(level)
	var before_navigation := navigation(level)
	var placements: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "placements.json"))["placements"]
	var dressing := level.get_node("CourMatter")
	var floors := []
	for child: Node in level.get_children():
		if child.scene_file_path.get_file().get_basename() == "floor_tile_large":
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				floors.append(instance)
	dressing.apply_matter(level)
	assert(before_collision == collisions(level), "Collisions différentes")
	assert(before_modules == modules(level), "Placement de module différent")
	assert(before_navigation == navigation(level), "Navigation différente")
	assert(dressing.get_child_count() == placements.size() + 1)
	assert(dressing.find_children("*", "CollisionObject3D", true, false).is_empty())
	var grass_count := 0
	for detail: Node in dressing.get_children():
		if detail.has_meta("cour_grass_3d"):
			assert(detail is MeshInstance3D)
			grass_count += 1
	assert(grass_count > 0, "Herbe 3D absente")
	var ground := dressing.get_node("CourTerrain") as MeshInstance3D
	var ground_arrays := ground.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = ground_arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = ground_arrays[Mesh.ARRAY_TEX_UV]
	assert(positions.size() == floors.size() * 6, "Sol non remplacé en totalité")
	var cursor := 0
	for floor_instance: MeshInstance3D in floors:
		assert(not floor_instance.visible and floor_instance.get_meta("cour_floor_replaced"))
		var bounds := floor_instance.mesh.get_aabb()
		var local_positions := []
		for i: int in range(cursor, cursor + 6):
			var world_point := ground.global_transform * positions[i]
			var point := floor_instance.global_transform.affine_inverse() * world_point
			assert(absf(point.y - bounds.end.y) < 0.00001, "Hauteur du sol déplacée")
			local_positions.append(point)
			assert(uvs[i].is_equal_approx(Vector2(positions[i].x, positions[i].z) / 16.0), "Raccord UV")
		assert(local_positions[0].is_equal_approx(Vector3(bounds.position.x, bounds.end.y, bounds.position.z)))
		assert(local_positions[2].is_equal_approx(Vector3(bounds.end.x, bounds.end.y, bounds.end.z)))
		cursor += 6
	var detail_definitions: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "details.json"))
	for detail: Dictionary in detail_definitions:
		var asset_report := AssetValidator.validate_entry(detail.id, Assets.entry(StringName(detail.id)))
		assert(asset_report.status == "OK", JSON.stringify(asset_report))
	var report := {"status": "conforme", "modules_checked": MODULES.size(), "triangles_checked": triangle_count,
		"module_instances": before_modules.size(), "collision_shapes": before_collision.size(),
		"collision_sha256": JSON.stringify(before_collision).sha256_text(),
		"navigation_polygons": level.navigation_mesh.get_polygon_count(),
		"navigation_sha256": JSON.stringify(before_navigation).sha256_text(), "detail_instances": placements.size(),
		"manifest_entries_validated": detail_definitions.size(),
		"grass_3d_instances": grass_count,
		"floor_tiles_replaced": floors.size(), "floor_top_height_and_footprint": "identiques",
		"floor_geometry": "surface visuelle continue, deux triangles par ancienne tuile",
		"geometry_original_uv": "identiques", "max_normal_encoding_error": max_normal_error,
		"module_transforms": "identiques",
		"collisions": "identiques", "navigation": "identique"}
	var output := "user://cour-check.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.trim_prefix("--report=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("COUR_CHECK_OK ", JSON.stringify(report))
	get_tree().quit()
