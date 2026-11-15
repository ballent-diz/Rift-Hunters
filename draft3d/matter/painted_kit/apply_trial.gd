extends RefCounted
## Habillage réversible des murs et escaliers de la Cour, activé seulement par --painted-kit.

const ROOT := "res://draft3d/matter/painted_kit/"
const WALLS := ["wall", "wall_cracked", "wall_broken", "wall_doorway"]
const PILLAR_POSITION := Vector3(-8, 2, -17.5)

static func apply(level: Node3D) -> void:
	var counts := {}
	for child: Node in level.get_children():
		if not child is Node3D:
			continue
		var selected := child as Node3D
		var id := child.scene_file_path.get_file().get_basename()
		var is_pillar := id == "pillar_decorated" and selected.position.distance_to(PILLAR_POSITION) < 0.1
		if id not in WALLS and id != "stairs_wide" and not is_pillar:
			continue
		var expected_scale := Vector3(1, 0.5, 1.5) if id == "stairs_wide" else Vector3.ONE
		assert(selected.scale.is_equal_approx(expected_scale), "Densité UV à recalibrer : " + id)
		var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + "_uv.json"))
		for instance: MeshInstance3D in selected.find_children("*", "MeshInstance3D", true, false):
			instance.mesh = load(ROOT + id + ".res")
			instance.material_override = null
			for s: int in instance.mesh.get_surface_count():
				if plan.surfaces[str(s)].painted:
					instance.set_surface_override_material(s, null)
		selected.set_meta("painted_kit", id)
		counts[id] = int(counts.get(id, 0)) + 1
	print("PAINTED_KIT_INSTANCES ", JSON.stringify(counts))
