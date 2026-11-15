extends Node3D
## Compare les pièces sources, les UV préservés et toute la physique de la carte 2 avant/après habillage.

const ROOT := "res://draft3d/matter/graveyard/"

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(1))
	call_deferred("verify")

func verify() -> void:
	assert(OS.get_cmdline_user_args().has("--graveyard-matter=0"))
	var checker := preload("res://tools/art/check_cour_matter.gd").new()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var triangles := 0
	var normal_error := 0.0
	for entry: Dictionary in catalog.values():
		var source := (load(str(entry.source)) as PackedScene).instantiate()
		for part: Dictionary in entry.meshes:
			var original := source.get_node(str(part.node_path)) as MeshInstance3D
			var target := load(str(part.path)) as ArrayMesh
			var before: Array = checker.triangles(original.mesh, true)
			var after: Array = checker.triangles(target, false)
			assert(before.size() == after.size(), "Nombre de triangles différent : " + str(part.key))
			assert(original.mesh.get_aabb().is_equal_approx(target.get_aabb()))
			for index: int in before.size():
				assert(before[index].corners == after[index].corners, "Sommets/UV source : " + str(part.key))
				for corner: int in 3:
					var error: float = before[index].normals[corner].distance_to(after[index].normals[corner])
					normal_error = maxf(error, normal_error)
					# Deux encodages octaédriques sur les normales des pièces Halloween.
					assert(error < 0.0003)
			triangles += before.size()
		source.free()
	var level := DraftLevelGraveyard.new()
	add_child(level)
	level.build()
	var collisions: Array = checker.collisions(level)
	var modules: Array = checker.modules(level)
	var navigation: Array = checker.navigation(level)
	var ground := {}
	var source_meshes := {}
	for instance: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
		source_meshes[instance] = instance.mesh
		if instance.get_parent().name in ["Ground", "Mound"]:
			ground[instance] = instance.mesh.surface_get_arrays(0)
	var matter := level.get_node("GraveyardMatter")
	matter.apply_matter(level)
	assert(collisions == checker.collisions(level), "Collisions modifiées")
	assert(modules == checker.modules(level), "Pose des modules modifiée")
	assert(navigation == checker.navigation(level), "Navigation modifiée")
	assert(matter.find_children("*", "CollisionObject3D", true, false).is_empty())
	for instance: MeshInstance3D in ground:
		var after := instance.mesh.surface_get_arrays(0)
		for attribute: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
			assert(ground[instance][attribute].size() == after[attribute].size())
			for index: int in after[attribute].size():
				assert(ground[instance][attribute][index].distance_to(after[attribute][index]) < 0.0002)
	var changed := 0
	for instance: MeshInstance3D in source_meshes:
		if instance.mesh != source_meshes[instance]:
			changed += 1
	var result := {"status": "conforme", "models": catalog.size(), "triangles": triangles,
		"max_normal_encoding_error": normal_error, "painted_instances": matter.get_meta("painted_instances"),
		"changed_visual_meshes": changed, "ground_volumes_checked": ground.size(),
		"ground_geometry": "identique", "collision_shapes": collisions.size(), "collisions": "identiques",
		"module_transforms": "identiques", "navigation": "identique",
		"navigation_polygons": level.navigation_mesh.get_polygon_count(),
		"collision_sha256": JSON.stringify(collisions).sha256_text(),
		"navigation_sha256": JSON.stringify(navigation).sha256_text()}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	checker.free()
	print("GRAVEYARD_CHECK ", JSON.stringify(result))
	get_tree().quit()
