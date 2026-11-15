extends RefCounted
## Essai réversible sur trois instances existantes, activé seulement par --painted-kit.

const ROOT := "res://draft3d/matter/painted_kit/"
const TARGETS := {"wall": Vector3(-2, 2, -20.5), "stairs_wide": Vector3(0, 0, -12),
	"pillar_decorated": Vector3(-8, 2, -17.5)}

static func apply(level: Node3D) -> void:
	for id: String in TARGETS:
		var selected: Node3D
		var distance := INF
		for child: Node in level.get_children():
			if child is Node3D and child.scene_file_path.get_file().get_basename() == id:
				var current: float = (child as Node3D).position.distance_to(TARGETS[id])
				if current < distance:
					distance = current
					selected = child
		assert(selected != null and distance < 0.1, "Instance de référence introuvable : " + id)
		var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + "_uv.json"))
		for instance: MeshInstance3D in selected.find_children("*", "MeshInstance3D", true, false):
			instance.mesh = load(ROOT + id + ".res")
			instance.material_override = null
			for s: int in instance.mesh.get_surface_count():
				if plan.surfaces[str(s)].painted:
					instance.set_surface_override_material(s, null)
		selected.set_meta("painted_kit", id)
		print("PAINTED_KIT_INSTANCE ", id, " ", selected.position)
