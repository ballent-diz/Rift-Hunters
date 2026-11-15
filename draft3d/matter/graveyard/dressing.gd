extends Node3D
## Matière uniquement : copies visuelles, sol aux mêmes sommets et mêmes hauteurs, aucun corps ajouté.

const ROOT := "res://draft3d/matter/graveyard/"

func setup(level: Node3D) -> void:
	name = "GraveyardMatter"
	if OS.get_cmdline_user_args().has("--graveyard-matter=0"):
		return
	apply_matter(level)

func apply_matter(level: Node3D) -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var count := 0
	for child: Node in level.get_children():
		var id := child.scene_file_path.get_file().get_basename()
		if catalog.has(id) and child.scene_file_path == str(catalog[id].source):
			for part: Dictionary in catalog[id].meshes:
				var instance := child.get_node(str(part.node_path)) as MeshInstance3D
				instance.mesh = load(str(part.path))
				instance.material_override = null
				for surface: int in instance.mesh.get_surface_count():
					instance.set_surface_override_material(surface, null)
				instance.set_meta("graveyard_painted", part.key)
				count += 1
		elif id == "stairs_wide":
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				instance.mesh = load("res://draft3d/matter/painted_kit/stairs_wide.res")
				instance.material_override = null
				for surface: int in instance.mesh.get_surface_count():
					instance.set_surface_override_material(surface, null)
		elif child.name in ["Ground", "Mound"]:
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				apply_ground(instance, level)
	set_meta("painted_instances", count)
	print("GRAVEYARD_MATTER ", count, " maillages")

func apply_ground(instance: MeshInstance3D, level: Node3D) -> void:
	var arrays := instance.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv := PackedVector2Array()
	for index: int in points.size():
		var point: Vector3 = level.global_transform.affine_inverse() * instance.global_transform * points[index]
		var normal := normals[index].abs()
		if normal.y >= normal.x and normal.y >= normal.z:
			uv.append(Vector2(point.x, point.z) / 16.0)
		else:
			uv.append(Vector2(point.x if normal.z > normal.x else point.z, -point.y) / 16.0)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, load(ROOT + "ground.tres"))
	instance.mesh = mesh
	instance.material_override = null
