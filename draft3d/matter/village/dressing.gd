extends Node3D
## Habillage du Hameau : aucun corps ajouté, positions et volumes des rives/ponts conservés.

const ROOT := "res://draft3d/matter/village/"

func setup(level: Node3D) -> void:
	name = "VillageMatter"
	if OS.get_cmdline_user_args().has("--village-matter=0"):
		return
	apply_matter(level)

func apply_matter(level: Node3D) -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var painted := 0
	var bridges := 0
	var grounds := 0
	var waters := 0
	for child: Node in level.get_children():
		if not child is Node3D:
			continue
		var object := child as Node3D
		var id := child.scene_file_path.get_file().get_basename()
		var kind := "%s_s%d" % [id, roundi(object.scale.x * 100)]
		if catalog.has(kind) and child.scene_file_path == str(catalog[kind].source):
			for part: Dictionary in catalog[kind].meshes:
				var instance := child.get_node(str(part.node_path)) as MeshInstance3D
				instance.mesh = load(str(part.path))
				clear_overrides(instance)
				instance.set_meta("village_painted", part.key)
				painted += 1
		elif id == "stairs_wide":
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				instance.mesh = load("res://draft3d/matter/painted_kit/stairs_wide.res")
				clear_overrides(instance)
		elif child.name in ["SouthBank", "NorthBank", "Knoll"]:
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				apply_surface(instance, level, ROOT + "ground.tres", 16.0)
				grounds += 1
		elif child is StaticBody3D and is_equal_approx(object.position.y, -0.15):
			# Les noms des trois corps Bridge sont auto-renommés par Godot ; leur altitude les identifie.
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				apply_surface(instance, level, ROOT + "bridge.tres", 1.2)
				bridges += 1
		elif child is MeshInstance3D and is_equal_approx(object.position.y, -0.9):
			apply_surface(child as MeshInstance3D, level, ROOT + "water.tres", 8.0)
			waters += 1
	assert(bridges == 3 and grounds == 3 and waters == 1)
	set_meta("painted_instances", painted)
	set_meta("bridges", bridges)
	set_meta("grounds", grounds)
	print("VILLAGE_MATTER ", painted, " maillages ; ", bridges, " ponts")

func clear_overrides(instance: MeshInstance3D) -> void:
	instance.material_override = null
	for surface: int in instance.mesh.get_surface_count():
		instance.set_surface_override_material(surface, null)

func apply_surface(instance: MeshInstance3D, level: Node3D, material_path: String, span: float) -> void:
	var arrays := instance.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv := PackedVector2Array()
	for index: int in points.size():
		var point: Vector3 = level.global_transform.affine_inverse() * instance.global_transform * points[index]
		var normal := normals[index].abs()
		if normal.y >= normal.x and normal.y >= normal.z:
			uv.append(Vector2(point.x, point.z) / span)
		else:
			uv.append(Vector2(point.x if normal.z > normal.x else point.z, -point.y) / span)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, load(material_path))
	instance.mesh = mesh
	clear_overrides(instance)
