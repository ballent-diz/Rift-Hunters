extends Node3D
## Preuve de conservation de la physique et contrôle des nouvelles emprises visuelles.

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void: get_tree().quit(1))
	call_deferred("verify")

func verify() -> void:
	assert(OS.get_cmdline_user_args().has("--outpost-matter=0"))
	var checker := preload("res://tools/art/check_cour_matter.gd").new()
	var level := DraftLevelOutpost.new()
	add_child(level)
	level.build()
	var collisions: Array = checker.collisions(level)
	var modules: Array = checker.modules(level)
	var navigation: Array = checker.navigation(level)
	var ground_before := ground_geometry(level)
	var matter := level.get_node("OutpostMatter")
	matter.apply_matter(level)
	assert(collisions == checker.collisions(level), "Collisions modifiées")
	assert(modules == checker.modules(level), "Placement modifié")
	assert(navigation == checker.navigation(level), "Navigation modifiée")
	assert(ground_before == ground_geometry(level), "Sol ou escaliers déplacés")
	var checked := 0
	var hidden := 0
	var max_error := 0.0
	for child: Node3D in level.get_children():
		if not child.scene_file_path.begins_with("res://draft3d/spacebase/"):
			continue
		var id := child.scene_file_path.get_file().get_basename()
		if id.begins_with("rock") or id.begins_with("terrain"):
			continue
		var visual := child.get_node("AncientVisual")
		var original_meshes := child.find_children("*", "MeshInstance3D", true, false)
		for mesh: MeshInstance3D in original_meshes:
			if not visual.is_ancestor_of(mesh):
				assert(not mesh.visible, "Objet futuriste encore visible : " + id)
				hidden += 1
		assert(visual.find_children("*", "CollisionObject3D", true, false).is_empty())
		if id.begins_with("roofmodule") or id in ["lights", "windturbine_low", "windturbine_tall"]:
			continue
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = child.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var shapes := child.find_children("*", "CollisionShape3D", true, false)
		assert(shapes.size() == 1)
		var shape := shapes[0] as CollisionShape3D
		var box_shape := shape.shape as BoxShape3D
		var local_pose: Transform3D = child.global_transform.affine_inverse() * shape.global_transform
		var expected := local_pose * AABB(-box_shape.size / 2.0, box_shape.size)
		for axis: int in [0, 1, 2]:
			max_error = maxf(max_error, absf(bounds.position[axis] - expected.position[axis]) * child.scale.x)
			max_error = maxf(max_error, absf(bounds.end[axis] - expected.end[axis]) * child.scale.x)
		assert(max_error < 0.005, "Volume visuel hors de la boîte source : " + id)
		checked += 1
	var report := {"status": "conforme", "replaced_objects": matter.replacements.size(),
		"visual_bounds_checked": checked, "max_world_bounds_error_m": max_error,
		"hidden_technical_meshes": hidden, "collision_shapes": collisions.size(),
		"collisions": "identiques", "module_transforms": "identiques", "ground_and_stairs": "identiques",
		"navigation": "identique", "navigation_polygons": level.navigation_mesh.get_polygon_count(),
		"collision_sha256": JSON.stringify(collisions).sha256_text(),
		"navigation_sha256": JSON.stringify(navigation).sha256_text(), "replacements": matter.replacements}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("OUTPOST_CHECK ", JSON.stringify(report))
	checker.free()
	get_tree().quit()

func ground_geometry(level: Node3D) -> Array:
	var result := []
	for child: Node3D in level.get_children():
		if child.name not in ["Ice", "Plateau"] and child.scene_file_path.get_file().get_basename() != "stairs_wide":
			continue
		for mesh: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
			var points := []
			for surface: int in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				if indices.is_empty():
					indices = PackedInt32Array(range(arrays[Mesh.ARRAY_VERTEX].size()))
				for index: int in indices:
					var p: Vector3 = mesh.global_transform * arrays[Mesh.ARRAY_VERTEX][index]
					points.append("%.3f,%.3f,%.3f" % [p.x, p.y, p.z])
			points.sort()
			result.append(points)
	return result
