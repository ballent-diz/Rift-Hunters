extends Node3D
## Habillage de la Cour seulement : maillages UV et matériaux, puis détails sans corps physique.

const ROOT := "res://draft3d/matter/cour/"
var _scaled_materials := {}

func setup(level: Node3D) -> void:
	name = "CourMatter"
	if OS.get_cmdline_user_args().has("--cour-matter=0"):
		return
	apply_matter(level)

func apply_matter(level: Node3D) -> void:
	var prepared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "uv_report.json"))["modules"]
	for child: Node in level.get_children():
		if child == self or not child is Node3D:
			continue
		var id := child.scene_file_path.get_file().get_basename()
		if prepared.has(id):
			for mesh_entry: Dictionary in prepared[id]:
				var instance := child.get_node(mesh_entry["node_path"]) as MeshInstance3D
				instance.mesh = load(mesh_entry["path"])
				instance.material_override = null
				for surface: int in instance.mesh.get_surface_count():
					instance.set_surface_override_material(surface, null)
					if id != "stairs_wide":
						var scale_value := (child as Node3D).scale.x
						var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
						instance.set_surface_override_material(surface, scaled_material(material, scale_value))
		elif child.name in ["Terrace", "CornerTerrace"]:
			for instance: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				texture_foundation(instance)
	place_details()

func scaled_material(source: StandardMaterial3D, value: float) -> StandardMaterial3D:
	if is_equal_approx(value, 1.0):
		return source
	var key := source.resource_path + "@" + str(snappedf(value, 0.001))
	if not _scaled_materials.has(key):
		var material := source.duplicate() as StandardMaterial3D
		material.uv1_scale = Vector3(value, value, 1)
		_scaled_materials[key] = material
	return _scaled_materials[key]

func texture_foundation(instance: MeshInstance3D) -> void:
	var arrays := instance.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv := PackedVector2Array()
	for i: int in positions.size():
		var point := positions[i]
		var normal := normals[i].abs()
		if normal.y >= normal.x and normal.y >= normal.z:
			uv.append(Vector2(point.x, point.z) / 4.0)
		elif normal.x >= normal.z:
			uv.append(Vector2(point.z, point.y) / 4.0)
		else:
			uv.append(Vector2(point.x, point.y) / 4.0)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, load(ROOT + "materials/stone.tres"))
	instance.mesh = mesh
	instance.material_override = null
	instance.set_surface_override_material(0, null)

func place_details() -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "placements.json"))["placements"]
	for entry: Dictionary in entries:
		var sprite := Sprite3D.new()
		sprite.name = entry["name"]
		var asset: Dictionary = Assets.entry(StringName(entry["visual_id"]))
		sprite.texture = load(str(asset["sheet"]))
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.5
		sprite.shaded = false
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.pixel_size = 0.037 * float(asset["scale"])
		sprite.offset = Vector2.ZERO
		sprite.position = Vector3(entry["position"][0], entry["position"][1], entry["position"][2])
		var orientation: String = entry["orientation"]
		if orientation == "ground":
			sprite.axis = Vector3.AXIS_Y
			sprite.rotation.y = deg_to_rad(float(entry["yaw"]))
			sprite.position += sprite.basis * Vector3(0, 0, (32.0 - float(asset["anchor"][1])) * sprite.pixel_size)
		elif orientation == "upright":
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			# Sprite3D exprime l'offset Y dans son plan local : le pied reste sur le sol.
			sprite.offset = Vector2.ZERO
			sprite.position.y += (float(asset["anchor"][1]) - 32.0) * sprite.pixel_size
		else:
			sprite.position.y += (float(asset["anchor"][1]) - 32.0) * sprite.pixel_size
		sprite.set_meta("cour_detail", entry["visual_id"])
		add_child(sprite)
