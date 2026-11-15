extends Node3D
## Habillage réversible : les corps, les formes physiques et la pose des modules restent ceux du niveau.

const ROOT := "res://draft3d/matter/outpost/"
const REPLACEMENTS := {
	"basemodule_A": "building_home_A_blue", "basemodule_B": "building_home_B_blue",
	"basemodule_E": "building_tavern_blue", "basemodule_garage": "building_blacksmith_blue",
	"cargodepot_A": "building_home_A_blue", "cargodepot_C": "building_home_B_blue",
	"structure_low": "building_home_A_blue", "drill_structure": "building_tower_A_blue",
	"lander_A": "building_tower_B_blue", "cargo_A": "crate_A_big", "cargo_B": "crate_B_big",
	"cargo_A_packed": "crate_A_big", "cargo_B_packed": "crate_B_big",
	"cargo_A_stacked": "crate_A_big", "cargo_B_stacked": "crate_B_big",
	"containers_B": "crate_long_B", "containers_D": "crate_long_C",
	"spacetruck": "crate_long_A", "spacetruck_large": "crate_long_B",
	"spacetruck_trailer": "crate_long_C", "solarpanel": "resource_lumber",
	"tunnel_straight_A": "crate_long_B"}
const SLOTS := ["masonry", "wood", "roof", "iron", "canvas", "ice", "cliff", "ground"]

var replacements := []
var _materials := {}
var _cache := {}

func setup(level: Node3D) -> void:
	name = "OutpostMatter"
	if not OS.get_cmdline_user_args().has("--outpost-matter=0"):
		apply_matter(level)

func apply_matter(level: Node3D) -> void:
	for slot: String in SLOTS:
		_materials[slot] = load(ROOT + slot + ".tres")
	for child: Node3D in level.get_children():
		var id := child.scene_file_path.get_file().get_basename()
		if child.scene_file_path.begins_with("res://draft3d/spacebase/"):
			var meshes := child.find_children("*", "MeshInstance3D", true, false)
			var bounds := AABB()
			var first := true
			for mesh: MeshInstance3D in meshes:
				var box: AABB = child.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
			if id.begins_with("rock") or id.begins_with("terrain"):
				for mesh: MeshInstance3D in meshes:
					paint_existing(mesh, child, "cliff", child.scale.x)
				continue
			for mesh: MeshInstance3D in meshes:
				mesh.hide()
			var visual := Node3D.new()
			visual.name = "AncientVisual"
			child.add_child(visual)
			if id.begins_with("roofmodule"):
				# Les toitures médiévales remplacent aussi ces antennes : aucune pièce en lévitation.
				continue
			if id in ["lights", "windturbine_low", "windturbine_tall"]:
				mast(visual, bounds.get_center(), child.scale.x, id)
			elif id == "landingpad_small":
				box(visual, AABB(Vector3(bounds.position.x, 0, bounds.position.z),
					Vector3(bounds.size.x, bounds.end.y, bounds.size.z)), "masonry", child.scale.x)
			elif REPLACEMENTS.has(id):
				# Le bas des boîtes physiques source est à Y=0, même pour les véhicules surélevés.
				var target := AABB(Vector3(bounds.position.x, 0, bounds.position.z),
					Vector3(bounds.size.x, bounds.end.y, bounds.size.z))
				replace_model(visual, str(REPLACEMENTS[id]), target, child.scale.x, id)
				replacements.append({"source": id, "replacement": REPLACEMENTS[id],
					"footprint": str(target), "at": str(child.transform)})
			else:
				assert(false, "Objet technique sans remplacement : " + id)
		elif id == "stairs_wide":
			for mesh: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				mesh.mesh = load("res://draft3d/matter/painted_kit/stairs_wide.res")
				mesh.material_override = null
				for surface: int in mesh.mesh.get_surface_count():
					var stone := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
					stone.albedo_color = Color(0.82, 0.91, 1.0)
					mesh.set_surface_override_material(surface, stone)
		elif child.name in ["Ice", "Plateau"]:
			for mesh: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
				paint_existing(mesh, level, "ground")
	set_meta("replacements", replacements.size())
	print("OUTPOST_MATTER ", replacements.size(), " objets anciens ; physique conservée")

func box(parent: Node3D, bounds: AABB, slot: String, size: float) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = bounds.size
	mesh.mesh = shape
	mesh.position = bounds.get_center()
	parent.add_child(mesh)
	paint_existing(mesh, parent, slot, size)

func mast(parent: Node3D, center: Vector3, size: float, id: String) -> void:
	# Emprise exacte du cylindre d'origine : rayon 35 cm, hauteur bloquante 2,4 m.
	var height := 2.4 if id == "lights" else 5.5
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.23 / size
	shape.bottom_radius = 0.35 / size
	shape.height = height / size
	shape.radial_segments = 8
	mesh.mesh = shape
	mesh.position = Vector3(center.x, height / size * 0.5, center.z)
	parent.add_child(mesh)
	paint_existing(mesh, parent, "masonry" if id == "lights" else "wood", size)
	if id == "lights":
		var crystal := MeshInstance3D.new()
		var gem := SphereMesh.new()
		gem.radius = 0.23 / size
		gem.height = 0.55 / size
		gem.radial_segments = 4
		gem.rings = 1
		crystal.mesh = gem
		crystal.position = Vector3(center.x, 2.65 / size, center.z)
		crystal.material_override = _materials.ice
		parent.add_child(crystal)
	else:
		# Bannière au-dessus de la collision du mât ; ni pale ni moteur.
		box(parent, AABB(Vector3(center.x, 3.4 / size, center.z - 0.035 / size),
			Vector3(1.1, 1.5, 0.07) / size), "canvas", size)

func replace_model(parent: Node3D, id: String, target: AABB, size: float, old_id: String) -> void:
	if old_id in ["cargo_A_stacked", "cargo_B_stacked"]:
		for x: int in 2:
			for y: int in 2:
				for z: int in 2:
					var part := AABB(target.position + target.size * Vector3(x, y, z) / 2.0, target.size / 2.0)
					replace_model(parent, id, part, size, old_id + "_" + str(x) + str(y) + str(z))
		return
	var key := old_id + "_" + str(size)
	if not _cache.has(key):
		var source := (load("res://draft3d/medieval/" + id + ".gltf") as PackedScene).instantiate() as Node3D
		add_child(source)
		var instances := source.find_children("*", "MeshInstance3D", true, false)
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in instances:
			var aabb: AABB = source.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
			bounds = aabb if first else bounds.merge(aabb)
			first = false
		var fit := target.size / bounds.size
		var transform := Transform3D(Basis.from_scale(fit), target.position - bounds.position * fit)
		var result := ArrayMesh.new()
		for instance: MeshInstance3D in instances:
			var to_root := source.global_transform.affine_inverse() * instance.global_transform
			append_mesh(result, instance, transform * to_root, size, "", old_id)
		_cache[key] = result
		source.free()
	var model := MeshInstance3D.new()
	model.mesh = _cache[key]
	parent.add_child(model)
	# Une base pleine rend explicite toute l'emprise bloquante, y compris sous les débords de toiture.
	var base := target
	base.size.y = minf(target.size.y * 0.2, 0.3 / size)
	box(parent, base, "masonry" if id.begins_with("building") else "wood", size)

func paint_existing(instance: MeshInstance3D, root: Node3D, slot: String, size: float = 1.0) -> void:
	var result := ArrayMesh.new()
	var transform := root.global_transform.affine_inverse() * instance.global_transform
	append_mesh(result, instance, transform, size, slot)
	instance.mesh = result
	instance.transform = root.global_transform.affine_inverse() * instance.global_transform
	# append_mesh a placé les sommets dans root : conserver le nœud, neutraliser seulement son repère visuel.
	instance.transform = Transform3D.IDENTITY
	if instance.get_parent() != root:
		instance.transform = instance.get_parent().global_transform.affine_inverse() * root.global_transform
	instance.material_override = null
	for surface: int in result.get_surface_count():
		instance.set_surface_override_material(surface, null)

func append_mesh(result: ArrayMesh, instance: MeshInstance3D, transform: Transform3D,
		size: float, forced: String, old_id: String = "") -> void:
	var groups := {}
	for surface: int in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index: int in points.size():
				indices.append(index)
		var source := instance.get_active_material(surface) as StandardMaterial3D
		var image: Image = source.albedo_texture.get_image() if source and source.albedo_texture else null
		for tri: int in range(0, indices.size(), 3):
			var slot := forced
			if slot.is_empty():
				var color := source.albedo_color if source else Color.GRAY
				if image and not uv.is_empty():
					var at := (uv[indices[tri]] + uv[indices[tri + 1]] + uv[indices[tri + 2]]) / 3.0
					color *= image.get_pixel(clampi(int(at.x * image.get_width()), 0, image.get_width() - 1),
						clampi(int(at.y * image.get_height()), 0, image.get_height() - 1))
				slot = classify(color)
				if not old_id.begins_with("basemodule") and not old_id.begins_with("cargodepot") \
					and old_id not in ["structure_low", "drill_structure", "lander_A"]:
					slot = "iron" if color.v < 0.16 else "wood"
			if not groups.has(slot):
				groups[slot] = {"points": PackedVector3Array(), "normals": PackedVector3Array(), "uv": PackedVector2Array()}
			var group: Dictionary = groups[slot]
			var normal: Vector3 = (transform.basis.inverse().transposed() * normals[indices[tri]]).normalized()
			if forced.is_empty() and slot == "masonry" and normal.y > 0.25 and normal.y < 0.98 \
				and old_id in ["basemodule_A", "basemodule_B", "basemodule_E", "basemodule_garage", \
					"cargodepot_A", "cargodepot_C", "structure_low"]:
				slot = "roof"
				if not groups.has(slot):
					groups[slot] = {"points": PackedVector3Array(), "normals": PackedVector3Array(), "uv": PackedVector2Array()}
				group = groups[slot]
			var axis := normal.abs().max_axis_index()
			for corner: int in 3:
				var index := indices[tri + corner]
				var point: Vector3 = transform * points[index]
				group.points.append(point)
				group.normals.append((transform.basis.inverse().transposed() * normals[index]).normalized())
				var flat := Vector2(point.z, -point.y) if axis == 0 else Vector2(point.x, -point.y)
				if axis == 1:
					flat = Vector2(point.x, point.z)
				# 40 texels/m ; 160px par tuile de 4m. Sol 320px sur 8m.
				group.uv.append(flat * size / (8.0 if slot == "ground" else 4.0))
	for slot: String in groups:
		if groups[slot].points.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = groups[slot].points
		arrays[Mesh.ARRAY_NORMAL] = groups[slot].normals
		arrays[Mesh.ARRAY_TEX_UV] = groups[slot].uv
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, _materials[slot])

func classify(color: Color) -> String:
	if color.b > color.r * 1.12 and color.b > color.g * 1.03 and color.s > 0.2:
		return "roof"
	if color.v < 0.18:
		return "iron"
	if color.r > color.b * 1.25 and color.r > color.g * 1.08:
		return "wood"
	return "masonry"
