extends Node3D
## Contrôle de l'essai : topologie, UV source, normale, densité, trois instances et physique inchangées.

const KIT := "res://draft3d/matter/painted_kit/"
const SOURCE := "res://draft3d/matter/cour/meshes/"

func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(func() -> void: get_tree().quit(1))
	call_deferred("verify")

func verify() -> void:
	assert(OS.get_cmdline_user_args().has("--cour-matter=0"))
	var checker := preload("res://tools/art/check_cour_matter.gd").new()
	var total_triangles := 0
	var max_normal_error := 0.0
	for id: String in ["wall", "stairs_wide", "pillar_decorated"]:
		var source := load(SOURCE + id + ".res") as Mesh
		var target := load(KIT + id + ".res") as Mesh
		var before: Array = checker.triangles(source, false)
		var after: Array = checker.triangles(target, false)
		assert(before.size() == after.size(), "Nombre de triangles modifié : " + id)
		assert(source.get_aabb().is_equal_approx(target.get_aabb()), id)
		for i: int in before.size():
			assert(before[i].corners == after[i].corners, "Sommets ou UV2 modifiés : " + id)
			for corner: int in 3:
				var error: float = before[i].normals[corner].distance_to(after[i].normals[corner])
				max_normal_error = maxf(max_normal_error, error)
				assert(error < 0.0002, "Normales modifiées : " + id)
		total_triangles += before.size()
	var level := DraftLevelRuins.new()
	add_child(level)
	level.build()
	var collisions: Array = checker.collisions(level)
	var poses: Array = checker.modules(level)
	var navigation: Array = checker.navigation(level)
	var original_meshes := {}
	for instance: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
		original_meshes[instance] = instance.mesh
	preload("res://draft3d/matter/painted_kit/apply_trial.gd").apply(level)
	assert(collisions == checker.collisions(level), "Collisions modifiées")
	assert(poses == checker.modules(level), "Placement modifié")
	assert(navigation == checker.navigation(level), "Navigation modifiée")
	var changed := 0
	for instance: MeshInstance3D in original_meshes:
		if instance.mesh != original_meshes[instance]:
			changed += 1
	assert(changed == 3, "L'essai doit modifier exactement trois instances visuelles")
	var result := {"status": "conforme", "modules": 3, "changed_mesh_instances": changed,
		"triangles_checked": total_triangles, "max_normal_encoding_error": max_normal_error,
		"collision_shapes": collisions.size(), "navigation_polygons": level.navigation_mesh.get_polygon_count(),
		"collisions": "identiques", "navigation": "identique", "module_transforms": "identiques"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	checker.free()
	print("PAINTED_KIT_CHECK ", JSON.stringify(result))
	get_tree().quit()
