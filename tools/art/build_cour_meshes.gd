extends SceneTree
## Prépare des copies de maillages de matière uniquement ; les scènes et collisions KayKit restent intactes.

const ROOT := "res://draft3d/matter/cour/"
const MODULES := ["wall", "wall_cracked", "wall_broken", "stairs_wide",
	"pillar_decorated", "wall_doorway", "barrier", "banner_red", "crates_stacked", "barrel_large", "chest"]
var materials := {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + "meshes")
	DirAccess.make_dir_recursive_absolute(ROOT + "materials")
	var report := {}
	for id: String in MODULES:
		var node := (load("res://draft3d/modules/%s.tscn" % id) as PackedScene).instantiate()
		var surfaces := []
		var instances := node.find_children("*", "MeshInstance3D", true, false)
		for index: int in instances.size():
			var instance := instances[index] as MeshInstance3D
			var mesh := prepare_mesh(instance, id)
			var suffix := "_%02d" % index if instances.size() > 1 else ""
			var path := ROOT + "meshes/%s%s.res" % [id, suffix]
			assert(ResourceSaver.save(mesh, path) == OK)
			surfaces.append({"path": path, "node_path": str(node.get_path_to(instance)),
				"surface_count": mesh.get_surface_count(),
				"original_bounds": str(instance.mesh.get_aabb()), "new_bounds": str(mesh.get_aabb())})
		if instances.size() > 1 and FileAccess.file_exists(ROOT + "meshes/%s.res" % id):
			DirAccess.remove_absolute(ROOT + "meshes/%s.res" % id)
		report[id] = surfaces
		node.free()
	var file := FileAccess.open(ROOT + "uv_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"method": "UV0 planar local projection; original UV0 preserved as UV2",
		"tile_span_m": 4.0, "texel_m": 0.025, "modules": report}, "\t"))
	print("COUR_MESHES_OK ", MODULES.size())
	quit()

func prepare_mesh(instance: MeshInstance3D, id: String) -> ArrayMesh:
	var groups := {}
	for s: int in instance.mesh.get_surface_count():
		var source := instance.mesh.surface_get_arrays(s)
		var positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var material := instance.get_active_material(s) as BaseMaterial3D
		var image: Image = material.albedo_texture.get_image() if material.albedo_texture else null
		for i: int in range(0, indices.size(), 3):
			var uv := (uvs[indices[i]] + uvs[indices[i + 1]] + uvs[indices[i + 2]]) / 3.0
			var color := material.albedo_color
			if image:
				color *= image.get_pixel(clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1),
					clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1))
			var slot := material_slot(id, color)
			if not groups.has(slot):
				groups[slot] = {"positions": PackedVector3Array(), "normals": PackedVector3Array(),
					"uv": PackedVector2Array(), "original_uv": PackedVector2Array()}
			var group: Dictionary = groups[slot]
			var face := (normals[indices[i]] + normals[indices[i + 1]] + normals[indices[i + 2]]).abs()
			for corner: int in 3:
				var index: int = indices[i + corner]
				var pos := positions[index]
				group.positions.append(pos)
				group.normals.append(normals[index])
				group.original_uv.append(uvs[index])
				# Les escaliers ont cette échelle non uniforme dans la Cour ; la géométrie reste intacte.
				var texture_pos := pos * Vector3(1, 0.5, 1.5) if id == "stairs_wide" else pos
				var projected: Vector2
				if face.y >= face.x and face.y >= face.z:
					projected = Vector2(texture_pos.x, texture_pos.z)
				elif face.x >= face.z:
					projected = Vector2(texture_pos.z, texture_pos.y)
				else:
					projected = Vector2(texture_pos.x, texture_pos.y)
				group.uv.append(projected / 4.0)
	var result := ArrayMesh.new()
	for slot: String in groups:
		var group: Dictionary = groups[slot]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.positions
		arrays[Mesh.ARRAY_NORMAL] = group.normals
		arrays[Mesh.ARRAY_TEX_UV] = group.uv
		arrays[Mesh.ARRAY_TEX_UV2] = group.original_uv
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface := result.get_surface_count() - 1
		result.surface_set_name(surface, slot)
		result.surface_set_material(surface, painted_material(slot))
	# Le shadow_mesh KayKit a une surface unique : il ne convient plus au découpage par matière.
	# Godot utilise donc le maillage peint lui-même pour projeter les mêmes silhouettes d'ombre.
	assert(result.get_aabb().is_equal_approx(instance.mesh.get_aabb()))
	return result

func material_slot(id: String, color: Color) -> String:
	var slot := "stone"
	if id == "floor_tile_large":
		slot = "paving"
	elif id == "banner_red" and color.s > 0.25:
		slot = "burgundy" if color.h < 0.1 or color.h > 0.9 else "bronze"
	elif color.s > 0.25 and color.h > 0.68 and color.h < 0.93:
		slot = "corrupt_stone"
	elif color.s > 0.2 and color.h > 0.2 and color.h < 0.48:
		slot = "moss"
	elif color.s > 0.22 and color.h < 0.19 and color.v > 0.13:
		slot = "bronze" if id in ["pillar_decorated", "chest"] and color.h > 0.08 else "oak"
	elif id in ["barrel_large", "crates_stacked", "chest"]:
		slot = "iron" if color.s < 0.2 else "split_oak"
	elif color.v < 0.13:
		slot = "iron"
	elif id == "wall_cracked":
		slot = "cracks"
	elif id == "wall_broken":
		slot = "rubble"
	return slot

func painted_material(slot: String) -> StandardMaterial3D:
	if materials.has(slot):
		return materials[slot]
	var material := StandardMaterial3D.new()
	material.resource_name = "Cour_" + slot
	material.albedo_texture = load(ROOT + "textures/" + slot + ".png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.texture_repeat = true
	material.roughness = 0.95
	material.metallic_specular = 0.0
	assert(ResourceSaver.save(material, ROOT + "materials/" + slot + ".tres") == OK)
	materials[slot] = material
	return material
