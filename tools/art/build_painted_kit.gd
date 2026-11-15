extends SceneTree
## Exporte les faces pour le conditionnement UV puis prépare des copies purement visuelles.

const ROOT := "res://draft3d/matter/painted_kit/"
const SOURCE := "res://draft3d/matter/cour/meshes/"
const MODULES := ["wall", "wall_cracked", "wall_broken", "wall_doorway", "stairs_wide", "pillar_decorated"]

func _initialize() -> void:
	var only := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
		if arg.begins_with("--export="):
			export_faces(arg.trim_prefix("--export="))
			quit()
			return
	for id: String in MODULES:
		if not only.is_empty() and id not in only:
			continue
		var source := load(SOURCE + id + ".res") as ArrayMesh
		var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + "_uv.json"))
		var result := ArrayMesh.new()
		var material := StandardMaterial3D.new()
		material.resource_name = "PaintedKit_" + id
		material.albedo_texture = load(ROOT + id + ".png")
		material.albedo_color = Color(0.64, 0.68, 0.72, 1.0)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.texture_repeat = false
		material.roughness = 1.0
		material.metallic_specular = 0.0
		for s: int in source.get_surface_count():
			var arrays := source.surface_get_arrays(s)
			var changed: bool = plan.surfaces[str(s)].painted
			if changed:
				var uv := PackedVector2Array()
				for point: Array in plan.surfaces[str(s)].uv:
					uv.append(Vector2(point[0], point[1]))
				assert(uv.size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
				arrays[Mesh.ARRAY_TEX_UV] = uv
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			result.surface_set_name(s, source.surface_get_name(s))
			result.surface_set_material(s, material if changed else source.surface_get_material(s))
		assert(result.get_aabb().is_equal_approx(source.get_aabb()))
		assert(ResourceSaver.save(result, ROOT + id + ".res") == OK)
		print("PAINTED_KIT_MESH ", id)
	quit()

func export_faces(path: String) -> void:
	var output := {}
	for id: String in MODULES:
		var mesh := load(SOURCE + id + ".res") as ArrayMesh
		var surfaces := []
		for s: int in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var points := []
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				points.append([point.x, point.y, point.z])
			surfaces.append({"slot": mesh.surface_get_name(s), "positions": points})
		output[id] = surfaces
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(output, "\t", true, true))
	print("PAINTED_KIT_EXPORT ", path)
