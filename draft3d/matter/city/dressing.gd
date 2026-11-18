extends Node3D
## Matières peintes de la cité : mêmes sommets, normales, UV source en UV2 et mêmes nœuds physiques.

const ROOT := "res://draft3d/matter/city/"
const SLOTS := ["masonry", "stone", "wood", "iron", "bronze", "paving", "worn_paving", "ground"]
const PERIOD := {"masonry": 2.4, "stone": 4.0, "wood": 1.6, "iron": 4.0,
	"bronze": 4.0, "paving": 3.0, "worn_paving": 3.0, "ground": 8.0}

var painted_instances := 0
var catalog := {}
var _materials := {}
var _meshes := {}

func setup(level: Node3D) -> void:
	name = "CityMatter"
	if not OS.get_cmdline_user_args().has("--city-matter=0"):
		apply_matter(level)

func apply_matter(level: Node3D) -> void:
	for slot: String in SLOTS:
		_materials[slot] = load(ROOT + slot + ".tres")
	for child: Node3D in level.get_children():
		if child == self:
			continue
		var id := child.scene_file_path.get_file().get_basename()
		if id == "stairs_wide":
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				instance.mesh = load("res://draft3d/matter/painted_kit/stairs_wide.res")
				instance.material_override = null
				for surface: int in instance.mesh.get_surface_count():
					instance.set_surface_override_material(surface, null)
				painted_instances += 1
			continue
		if child.scene_file_path.is_empty() and child.name not in ["Ground", "Terrace"]:
			continue
		var ground := child.name in ["Ground", "Terrace"]
		for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
			if instance.mesh == null:
				continue
			var basis := instance.global_basis
			var origin := instance.global_position
			# 24 m : multiple commun de toutes les périodes des matières, y compris le bois (1,6 m).
			var phase := Vector3(fposmod(origin.x, 24.0), fposmod(origin.y, 24.0), fposmod(origin.z, 24.0))
			phase = phase.snapped(Vector3.ONE * 0.0001)
			var key := str(child.scene_file_path) + str(child.get_path_to(instance)) + str(basis) + str(phase)
			if not _meshes.has(key):
				_meshes[key] = prepare(instance, str(child.name) if ground else id, "ground" if ground else "")
			instance.mesh = _meshes[key]
			instance.material_override = null
			for surface: int in instance.mesh.get_surface_count():
				instance.set_surface_override_material(surface, null)
			painted_instances += 1
	print("CITY_MATTER ", painted_instances, " meshes peints ; ", catalog.size(), " modèles")

func prepare(instance: MeshInstance3D, id: String, forced: String) -> ArrayMesh:
	var groups := {}
	for surface: int in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices = PackedInt32Array(range(points.size()))
		var source := instance.get_active_material(surface) as StandardMaterial3D
		var image: Image = source.albedo_texture.get_image() if source and source.albedo_texture else null
		if image and image.is_compressed():
			image.decompress()
		for tri: int in range(0, indices.size(), 3):
			var normal: Vector3 = (instance.global_basis.inverse().transposed() * normals[indices[tri]]).normalized()
			var color := source.albedo_color if source else Color.GRAY
			if image and not uv.is_empty():
				var at := (uv[indices[tri]] + uv[indices[tri + 1]] + uv[indices[tri + 2]]) / 3.0
				color *= image.get_pixel(clampi(int(at.x * image.get_width()), 0, image.get_width() - 1),
					clampi(int(at.y * image.get_height()), 0, image.get_height() - 1))
			var slot := forced if not forced.is_empty() else classify(id, color, normal, source)
			if forced == "ground" and normal.y < 0.5:
				slot = "masonry"
			var group_key := slot + str(surface) if slot == "preserve" else slot
			if not groups.has(group_key):
				groups[group_key] = {"slot": slot, "points": PackedVector3Array(), "normals": PackedVector3Array(),
					"uv": PackedVector2Array(), "original_uv": PackedVector2Array(), "source": source}
			var group: Dictionary = groups[group_key]
			var axis := normal.abs().max_axis_index()
			for corner: int in 3:
				var index := indices[tri + corner]
				var point: Vector3 = instance.global_transform * points[index]
				var original := uv[index] if not uv.is_empty() else Vector2.ZERO
				group.points.append(points[index])
				group.normals.append(normals[index])
				group.original_uv.append(original)
				var flat := Vector2(point.z, -point.y) if axis == 0 else Vector2(point.x, -point.y)
				if axis == 1:
					flat = Vector2(point.x, point.z)
				group.uv.append(original if slot == "preserve" else flat / float(PERIOD[slot]))
	var result := ArrayMesh.new()
	for group: Dictionary in groups.values():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.points
		arrays[Mesh.ARRAY_NORMAL] = group.normals
		arrays[Mesh.ARRAY_TEX_UV] = group.uv
		arrays[Mesh.ARRAY_TEX_UV2] = group.original_uv
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material: Material = group.source if group.slot == "preserve" else _materials[group.slot]
		result.surface_set_material(result.get_surface_count() - 1, material)
		result.surface_set_name(result.get_surface_count() - 1, group.slot)
		if not catalog.has(id):
			catalog[id] = {}
		catalog[id][group.slot] = true
	return result

func classify(id: String, color: Color, normal: Vector3, source: StandardMaterial3D) -> String:
	if source and source.emission_enabled:
		return "preserve"
	var slot := "wood"
	if "torch" in id or "candle" in id:
		if color.r > 0.65 and color.g > 0.3 and color.b < color.g and color.s > 0.4:
			slot = "preserve"
		elif "candle" in id and color.s < 0.4 and color.v > 0.35:
			slot = "stone"
		else:
			slot = "bronze" if color.r > color.b * 1.2 else "iron"
	elif id.begins_with("floor"):
		if "dirt" in id:
			slot = "worn_paving"
		elif "grate" in id and color.v < 0.4:
			slot = "iron"
		elif "weeds" in id and color.g > color.r * 1.15:
			slot = "preserve"
		else:
			slot = "paving" if normal.y > 0.5 else "stone"
	elif id.begins_with("wall"):
		if "gated" in id and color.v < 0.4:
			slot = "iron"
		elif "scaffold" in id and color.r > color.b * 1.2:
			slot = "wood"
		else:
			slot = "stone" if normal.y > 0.5 or "pillar" in id else "masonry"
	elif "pillar" in id or "rubble" in id or "barrier" in id:
		slot = "bronze" if color.r > color.b * 1.3 and color.g > color.b * 1.05 else "stone"
	elif color.v < 0.25 or (color.s < 0.15 and color.v < 0.5):
		slot = "iron"
	return slot
