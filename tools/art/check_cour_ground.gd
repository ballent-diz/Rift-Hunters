extends Node3D
## Contrôle natif du sol peint : toutes les emprises et hauteurs, physique, navigation et herbe.

func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(func() -> void: get_tree().quit(1))
	call_deferred("verify")

func verify() -> void:
	assert(OS.get_cmdline_user_args().has("--cour-matter=0"))
	assert(OS.get_cmdline_user_args().has("--painted-kit"))
	var checker := preload("res://tools/art/check_cour_matter.gd").new()
	var level := DraftLevelRuins.new()
	add_child(level)
	level.build()
	var collisions: Array = checker.collisions(level)
	var poses: Array = checker.modules(level)
	var navigation: Array = checker.navigation(level)
	var floors: Array[MeshInstance3D] = []
	for child: Node in level.get_children():
		if child.scene_file_path.get_file().get_basename() == "floor_tile_large":
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				floors.append(instance)
	var dressing := level.get_node("CourMatter")
	dressing.apply_matter(level)
	assert(collisions == checker.collisions(level), "Collisions modifiées")
	assert(poses == checker.modules(level), "Placement modifié")
	assert(navigation == checker.navigation(level), "Navigation modifiée")
	assert(dressing.find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(not dressing.has_node("CourMeadow"), "Le tapis dense ne doit pas doubler le sol peint")
	var ground := dressing.get_node("CourTerrain") as MeshInstance3D
	var arrays := ground.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert(floors.size() > 0 and positions.size() == floors.size() * 6)
	var cursor := 0
	for floor_instance: MeshInstance3D in floors:
		assert(not floor_instance.visible and floor_instance.get_meta("cour_floor_replaced"))
		var bounds := floor_instance.mesh.get_aabb()
		var corners := [Vector3(bounds.position.x, bounds.end.y, bounds.position.z),
			Vector3(bounds.end.x, bounds.end.y, bounds.position.z),
			Vector3(bounds.end.x, bounds.end.y, bounds.end.z),
			Vector3(bounds.position.x, bounds.end.y, bounds.end.z)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			var world_point := ground.global_transform * positions[cursor]
			var point := floor_instance.global_transform.affine_inverse() * world_point
			assert(point.is_equal_approx(corners[index]), "Emprise ou hauteur du sol déplacée")
			assert(uvs[cursor].is_equal_approx(Vector2(positions[cursor].x, positions[cursor].z) / 16.0))
			cursor += 1
	var grass_count := 0
	for detail: Node in dressing.get_children():
		if detail.has_meta("cour_grass_3d"):
			assert(detail is MeshInstance3D)
			var bounds: AABB = detail.mesh.get_aabb()
			assert(bounds.end.y < 0.28 and bounds.position.y >= 0.0)
			grass_count += 1
	assert(grass_count > 0)
	var result := {"status": "conforme", "floor_tiles": floors.size(),
		"floor_height_and_footprint": "identiques", "world_uv_period_m": 16,
		"collision_shapes": collisions.size(), "collisions": "identiques",
		"module_transforms": "identiques", "navigation": "identique",
		"navigation_polygons": level.navigation_mesh.get_polygon_count(),
		"grass_clumps": grass_count, "dense_meadow": false,
		"collision_sha256": JSON.stringify(collisions).sha256_text(),
		"navigation_sha256": JSON.stringify(navigation).sha256_text()}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	checker.free()
	print("COUR_GROUND_CHECK ", JSON.stringify(result))
	get_tree().quit()
