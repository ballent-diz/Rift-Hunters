extends Node
## Copies purement visuelles des pièces Halloween présentes sur la carte 2 ; UV source conservés en UV2.

const ROOT := "res://draft3d/matter/graveyard/"
var export_data := {}
var manifest := {}

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void: get_tree().quit(1))
	call_deferred("build")

func build() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "meshes")
	if OS.get_cmdline_user_args().has("--finalize"):
		finalize()
		get_tree().quit()
		return
	assert(OS.get_cmdline_user_args().has("--graveyard-matter=0"), "Exporter les pièces d'origine avec --graveyard-matter=0")
	# Chargement différé : laisser Godot initialiser les autoloads avant les dépendances des cartes.
	var level := (load("res://draft3d/level_graveyard.gd") as Script).new() as Node3D
	add_child(level)
	level.build()
	for child: Node in level.get_children():
		if not child.scene_file_path.begins_with("res://draft3d/halloween/"):
			continue
		var id := child.scene_file_path.get_file().get_basename()
		if manifest.has(id) or id.begins_with("pumpkin"):
			continue
		var entries := []
		var instances := child.find_children("*", "MeshInstance3D", true, false)
		for index: int in instances.size():
			var instance := instances[index] as MeshInstance3D
			var key := "%s_%02d" % [id, index]
			var mesh := prepare(instance, id, key)
			var path := ROOT + "meshes/" + key + ".res"
			assert(ResourceSaver.save(mesh, path) == OK)
			entries.append({"key": key, "node_path": str(child.get_path_to(instance)), "path": path})
		manifest[id] = {"source": child.scene_file_path, "meshes": entries}
	FileAccess.open(ROOT + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--export="):
			FileAccess.open(arg.trim_prefix("--export="), FileAccess.WRITE).store_string(JSON.stringify(export_data))
	print("GRAVEYARD_PREPARED ", manifest.size(), " modèles / ", export_data.size(), " maillages")
	get_tree().quit()

func prepare(instance: MeshInstance3D, id: String, key: String) -> ArrayMesh:
	var groups := {}
	for surface: int in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index: int in points.size():
				indices.append(index)
		var source := instance.get_active_material(surface) as StandardMaterial3D
		var image: Image = source.albedo_texture.get_image() if source.albedo_texture else null
		for triangle: int in range(0, indices.size(), 3):
			var at := (uvs[indices[triangle]] + uvs[indices[triangle + 1]] + uvs[indices[triangle + 2]]) / 3.0
			var color := source.albedo_color
			if image:
				color *= image.get_pixel(clampi(int(at.x * image.get_width()), 0, image.get_width() - 1),
					clampi(int(at.y * image.get_height()), 0, image.get_height() - 1))
			var slot := classify(id, color)
			if not groups.has(slot):
				groups[slot] = {"points": PackedVector3Array(), "normals": PackedVector3Array(),
					"uv": PackedVector2Array(), "source": source}
			var group: Dictionary = groups[slot]
			for corner: int in 3:
				var index := indices[triangle + corner]
				group.points.append(points[index])
				group.normals.append(normals[index])
				group.uv.append(uvs[index])
	var mesh := ArrayMesh.new()
	var output := []
	for slot: String in groups:
		var group: Dictionary = groups[slot]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.points
		arrays[Mesh.ARRAY_NORMAL] = group.normals
		arrays[Mesh.ARRAY_TEX_UV] = group.uv
		arrays[Mesh.ARRAY_TEX_UV2] = group.uv
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface := mesh.get_surface_count() - 1
		mesh.surface_set_name(surface, slot)
		mesh.surface_set_material(surface, group.source)
		var points := []
		for point: Vector3 in group.points:
			points.append([point.x, point.y, point.z])
		output.append({"slot": slot, "positions": points})
	export_data[key] = {"id": id, "surfaces": output}
	assert(mesh.get_aabb().is_equal_approx(instance.mesh.get_aabb()))
	return mesh

func classify(id: String, color: Color) -> String:
	var slot := "stone"
	# Flammes et verres chauds gardent leurs UV et leur matériau d'origine.
	if color.v > 0.65 and color.s > 0.4 and color.h < 0.18 \
		and ("candle" in id or "lantern" in id or "shrine" in id):
		slot = "preserve"
	elif id.begins_with("tree"):
		if "pine" in id and color.s > 0.25 and color.g > color.b * 1.1:
			slot = "foliage"
		elif color.v > 0.7 and color.s < 0.25:
			slot = "bone"
		else:
			slot = "bark"
	elif id == "crypt":
		if color.s > 0.35 and color.h < 0.2:
			slot = "roof"
		else:
			slot = "preserve" if color.v < 0.35 else "masonry"
	elif id.begins_with("coffin") or id.begins_with("bench"):
		if color.v > 0.75 and color.s < 0.2:
			slot = "bone"
		else:
			slot = "iron" if color.v < 0.22 else "wood"
	elif "fence" in id or id.begins_with("arch"):
		slot = "stone" if color.v > 0.55 else "iron"
	elif "lantern" in id:
		slot = "iron" if color.v < 0.3 else "wood"
	elif "bone" in id or "skull" in id or "ribcage" in id or ("candle" in id and color.v > 0.6):
		slot = "bone"
	return slot

func finalize() -> void:
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var tints := {"stone": Color(0.7, 0.75, 0.8), "masonry": Color(0.7, 0.75, 0.8),
		"roof": Color(0.7, 0.72, 0.8), "wood": Color(0.7, 0.68, 0.72), "bark": Color(0.65, 0.63, 0.69),
		"iron": Color(0.65, 0.68, 0.75), "foliage": Color(0.9, 0.95, 0.8), "bone": Color(0.65, 0.65, 0.68)}
	var count := 0
	for entry: Dictionary in entries.values():
		for part: Dictionary in entry.meshes:
			var original := load(str(part.path)) as ArrayMesh
			if OS.get_cmdline_user_args().has("--retint"):
				for surface: int in original.get_surface_count():
					var slot := original.surface_get_name(surface)
					if tints.has(slot):
						(original.surface_get_material(surface) as StandardMaterial3D).albedo_color = tints[slot]
				assert(ResourceSaver.save(original, str(part.path)) == OK)
				count += 1
				continue
			var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "uv/" + part.key + ".json"))
			var result := ArrayMesh.new()
			for surface: int in original.get_surface_count():
				var arrays := original.surface_get_arrays(surface)
				var slot := original.surface_get_name(surface)
				var material: Material = original.surface_get_material(surface)
				if slot != "preserve":
					var uv := PackedVector2Array()
					for point: Array in plan.surfaces[str(surface)].uv:
						uv.append(Vector2(point[0], point[1]))
					arrays[Mesh.ARRAY_TEX_UV] = uv
					var painted := StandardMaterial3D.new()
					painted.resource_name = "Graveyard_" + slot
					painted.albedo_color = tints[slot]
					painted.albedo_texture = load(ROOT + "atlases/" + part.key + ".png")
					painted.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					painted.roughness = 1.0
					painted.metallic_specular = 0.0
					painted.texture_repeat = false
					material = painted
				result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				result.surface_set_name(surface, slot)
				result.surface_set_material(surface, material)
			assert(ResourceSaver.save(result, str(part.path)) == OK)
			count += 1
	print("GRAVEYARD_FINALIZED ", count)
