extends Node3D
## Compare la physique, chaque triangle visuel, ses UV source et ses normales avant/après.

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(func() -> void: get_tree().quit(1))
	call_deferred("verify")

func verify() -> void:
	assert(OS.get_cmdline_user_args().has("--city-matter=0"))
	var checker := preload("res://tools/art/check_cour_matter.gd").new()
	var level := DraftLevelCity.new()
	add_child(level)
	level.build()
	var collisions: Array = checker.collisions(level)
	var modules: Array = checker.modules(level)
	var navigation: Array = checker.navigation(level)
	var originals := {}
	var bounds := {}
	var models := {}
	for child: Node3D in level.get_children():
		if not child.scene_file_path.is_empty():
			models[child.scene_file_path] = true
	for mesh: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
		originals[mesh] = checker.triangles(mesh.mesh, true)
		bounds[mesh] = mesh.mesh.get_aabb()
	var matter := level.get_node("CityMatter")
	matter.apply_matter(level)
	assert(collisions == checker.collisions(level), "Collisions modifiées")
	assert(modules == checker.modules(level), "Pose des modules modifiée")
	assert(navigation == checker.navigation(level), "Navigation modifiée")
	assert(matter.get_child_count() == 0, "Géométrie supplémentaire")
	var triangles := 0
	var error := 0.0
	var bounds_error := 0.0
	var slots := {}
	for mesh: MeshInstance3D in originals:
		var before: Array = originals[mesh]
		var after: Array = checker.triangles(mesh.mesh, false)
		assert(before.size() == after.size())
		var source_bounds: AABB = bounds[mesh]
		var target_bounds := mesh.mesh.get_aabb()
		bounds_error = maxf(bounds_error, source_bounds.position.distance_to(target_bounds.position))
		bounds_error = maxf(bounds_error, source_bounds.end.distance_to(target_bounds.end))
		# Godot ajoute ~0,00001 m à l'AABB d'une BoxMesh transformée en ArrayMesh ; les sommets sont vérifiés ensuite.
		assert(bounds_error < 0.0001, "Emprise différente : " + str(mesh.get_path()))
		for index: int in before.size():
			assert(before[index].corners == after[index].corners, "Sommets/UV source modifiés : " + str(mesh.get_path()))
			for corner: int in 3:
				error = maxf(error, before[index].normals[corner].distance_to(after[index].normals[corner]))
				assert(error < 0.0003)
		triangles += before.size()
		for surface: int in mesh.mesh.get_surface_count():
			var name_slot: String = (mesh.mesh as ArrayMesh).surface_get_name(surface)
			slots[name_slot] = int(slots.get(name_slot, 0)) + 1
	var report := {"status": "conforme", "models": models.size(), "meshes": originals.size(),
		"painted_instances": matter.painted_instances, "triangles": triangles, "max_normal_encoding_error": error,
		"geometry_source_uv": "identiques", "max_aabb_encoding_error_m": bounds_error, "module_transforms": "identiques",
		"collisions": "identiques", "navigation": "identique", "collision_shapes": collisions.size(),
		"navigation_polygons": level.navigation_mesh.get_polygon_count(), "material_surfaces": slots,
		"collision_sha256": JSON.stringify(collisions).sha256_text(),
		"navigation_sha256": JSON.stringify(navigation).sha256_text()}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CITY_CHECK ", JSON.stringify(report))
	checker.free()
	get_tree().quit()
