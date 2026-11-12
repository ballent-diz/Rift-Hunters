extends SceneTree
## Prépare les modules réutilisables AVEC leurs collisions dans des scènes natives Godot.

const PROFILES := {
	"floor_tile_large": {"kind": "floor"},
	"wall": {}, "wall_broken": {}, "wall_cracked": {},
	"wall_doorway": {}, "pillar_decorated": {},
	"barrier": {}, "barrel_large": {"kind": "convex"},
	"crates_stacked": {"kind": "convex"},
	"stairs_wide": {"kind": "stairs"},
	"banner_red": {"kind": "none"}, "torch_lit": {"kind": "none"},
	"chest": {"kind": "convex"}
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://modules")
	for id: String in PROFILES:
		build(id, PROFILES[id])
	quit()

func build(id: String, profile: Dictionary) -> void:
	var packed := load("res://assets/kaykit/%s.glb" % id) as PackedScene
	assert(packed != null, id)
	var root := Node3D.new()
	root.name = id
	var visual := packed.instantiate() as Node3D
	visual.name = "Visual"
	# Déplier le GLB en nœuds natifs avant de sauver les matériaux et collisions.
	# Des enfants ajoutés par-dessus une instance importée créeraient des doublons à son chargement.
	visual.scene_file_path = ""
	if id == "wall_doorway":
		# Le GLB contient aussi une porte fermée. L'arche de l'essai reste ouverte.
		for door: Node in visual.find_children("*doorway_door*", "", true, false):
			door.get_parent().remove_child(door)
			door.free()
	root.add_child(visual)
	visual.owner = root
	for child: Node in visual.find_children("*", "", true, false):
		child.owner = root
	for item: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		for surface: int in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
			material.albedo_color = Color(0.72, 0.75, 0.82) if id.begins_with("floor") else Color(0.85, 0.85, 0.9)
			material.roughness = 0.88
			mesh.set_surface_override_material(surface, material)
		mesh.owner = root
	var kind: String = profile.get("kind", "mesh")
	if kind == "stairs":
		# Une rampe lisse sous les nez des marches évite les accrocs sans téléporter le joueur.
		var body := StaticBody3D.new()
		body.name = "Collision"
		root.add_child(body)
		body.owner = root
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array([
			Vector3(-2.8, 0, 0), Vector3(2.8, 0, 0), Vector3(-2.8, 4, 0), Vector3(2.8, 4, 0),
			Vector3(-2.8, -0.1, 4.3), Vector3(2.8, -0.1, 4.3),
			Vector3(-2.8, 0, 4.3), Vector3(2.8, 0, 4.3)
		])
		add_shape(body, shape, Transform3D.IDENTITY, root)
	elif kind != "none":
		var body := StaticBody3D.new()
		body.name = "Collision"
		root.add_child(body)
		body.owner = root
		for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			var transform := mesh_node.transform
			var parent := mesh_node.get_parent()
			while parent != root:
				transform = (parent as Node3D).transform * transform
				parent = parent.get_parent()
			var shape: Shape3D
			if kind == "floor":
				var aabb := mesh_node.mesh.get_aabb()
				var box := BoxShape3D.new()
				box.size = Vector3(aabb.size.x, 0.2, aabb.size.z)
				transform.origin += Vector3(aabb.get_center().x, -0.1, aabb.get_center().z)
				shape = box
			elif kind == "convex":
				shape = mesh_node.mesh.create_convex_shape(true, false)
			else:
				shape = mesh_node.mesh.create_trimesh_shape()
			add_shape(body, shape, transform, root)
	var scene := PackedScene.new()
	assert(scene.pack(root) == OK)
	assert(ResourceSaver.save(scene, "res://modules/%s.tscn" % id) == OK)
	root.free()
	print("MODULE_OK ", id)

func add_shape(body: StaticBody3D, shape: Shape3D, transform: Transform3D, owner: Node) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = transform
	body.add_child(collision)
	collision.owner = owner
