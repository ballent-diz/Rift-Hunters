extends Node
## Copies purement visuelles des pièces Medieval présentes sur la carte 2 ; UV source conservés en UV2.

const ROOT := "res://draft3d/matter/village/"
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
	assert(OS.get_cmdline_user_args().has("--village-matter=0"), "Exporter les pièces d'origine avec --village-matter=0")
	# Chargement différé : laisser Godot initialiser les autoloads avant les dépendances des cartes.
	var level := (load("res://draft3d/level_village.gd") as Script).new() as Node3D
	add_child(level)
	level.build()
	for child: Node in level.get_children():
		if not child.scene_file_path.begins_with("res://draft3d/medieval/"):
			continue
		var id := child.scene_file_path.get_file().get_basename()
		var size := (child as Node3D).scale.x
		var kind := "%s_s%d" % [id, roundi(size * 100)]
		if manifest.has(kind):
			continue
		var entries := []
		var instances := child.find_children("*", "MeshInstance3D", true, false)
		for index: int in instances.size():
			var instance := instances[index] as MeshInstance3D
			var key := "%s_%02d" % [kind, index]
			var relative := (child as Node3D).global_transform.affine_inverse() * instance.global_transform
			var texture_transform := Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3.ZERO) * relative
			var mesh := prepare(instance, id, key, texture_transform)
			var path := ROOT + "meshes/" + key + ".res"
			assert(ResourceSaver.save(mesh, path) == OK)
			entries.append({"key": key, "node_path": str(child.get_path_to(instance)), "path": path})
		manifest[kind] = {"source": child.scene_file_path, "id": id, "scale": size, "meshes": entries}
	FileAccess.open(ROOT + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--export="):
			FileAccess.open(arg.trim_prefix("--export="), FileAccess.WRITE).store_string(JSON.stringify(export_data))
	print("VILLAGE_PREPARED ", manifest.size(), " modèles / ", export_data.size(), " maillages")
	get_tree().quit()

func prepare(instance: MeshInstance3D, id: String, key: String, texture_transform: Transform3D) -> ArrayMesh:
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
			var bounds := instance.mesh.get_aabb()
			var middle := (points[indices[triangle]] + points[indices[triangle + 1]] + points[indices[triangle + 2]]) / 3.0
			var height := (middle.y - bounds.position.y) / maxf(bounds.size.y, 0.001)
			var slot := classify(id, color, height)
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
			var mapped := texture_transform * point
			points.append([mapped.x, mapped.y, mapped.z])
		output.append({"slot": slot, "positions": points})
	export_data[key] = {"id": id, "surfaces": output}
	assert(mesh.get_aabb().is_equal_approx(instance.mesh.get_aabb()))
	return mesh

func classify(id: String, color: Color, height: float) -> String:
	var slot := "stone"
	if id.begins_with("tree"):
		slot = "ground" if height < 0.12 else "foliage" if color.g > color.r * 1.08 else "bark"
	elif id == "building_grain":
		slot = "soil" if height < 0.25 else "straw"
	elif id.begins_with("rock") or id.begins_with("fence_stone"):
		slot = "iron" if color.v < 0.18 else "stone"
	elif color.s > 0.25 and color.h > 0.42 and color.h < 0.76:
		slot = "cloth" if id in ["building_market_blue", "flag_blue", "tent"] else "roof"
	elif color.s > 0.22 and color.h > 0.18 and color.h < 0.43:
		slot = "ground" if height < 0.12 else "foliage"
	elif id == "tent" or id == "sack":
		slot = "wood" if color.s > 0.3 else "canvas"
	elif id.begins_with("crate") or id in ["barrel", "wheelbarrow", "weaponrack", "resource_lumber"]:
		slot = "wood" if color.s > 0.2 else "iron"
	elif id.begins_with("fence_wood") or id == "flag_blue":
		slot = "wood"
	elif color.v < 0.18:
		slot = "iron"
	elif color.s > 0.2 and color.h < 0.2:
		slot = "wood"
	elif id.begins_with("building"):
		if height < 0.18:
			slot = "stone"
		else:
			slot = "canvas" if id == "building_market_blue" else "plaster"
	return slot

func finalize() -> void:
	var entries: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var tints := {"stone": Color(0.64, 0.68, 0.72), "wood": Color(0.7, 0.68, 0.65),
		"roof": Color(0.72, 0.76, 0.8), "plaster": Color(0.72, 0.73, 0.7), "cloth": Color(0.75, 0.8, 0.85),
		"canvas": Color(0.82, 0.82, 0.78), "bark": Color(0.7, 0.68, 0.65), "iron": Color(0.65, 0.68, 0.72),
		"foliage": Color(0.7, 0.78, 0.65), "ground": Color(0.7, 0.75, 0.8), "soil": Color(0.65, 0.55, 0.4),
		"straw": Color(0.8, 0.78, 0.7)}
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
	print("VILLAGE_FINALIZED ", count)
