extends Node

func _ready() -> void:
	call_deferred("inventory")

func inventory() -> void:
	var level := (load("res://draft3d/level_outpost.gd") as Script).new() as Node3D
	add_child(level)
	level.build()
	var entries := {}
	for child: Node3D in level.get_children():
		if not child.scene_file_path.begins_with("res://draft3d/spacebase/"):
			continue
		var id := child.scene_file_path.get_file().get_basename()
		if entries.has(id):
			continue
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = child.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		entries[id] = {"position": str(bounds.position), "size": str(bounds.size),
			"world_size": str(bounds.size * child.scale.x)}
	print(JSON.stringify(entries, "\t"))
	get_tree().quit()
