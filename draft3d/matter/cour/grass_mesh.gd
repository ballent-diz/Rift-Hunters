extends RefCounted
## Touffes en vrais volumes : brins courbés à section triangulaire, sans billboard ni collision.

static func build(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 241114 + variant * 79
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors := [Color("33413a"), Color("375736"), Color("5f6a47"), Color("8d725f")]
	for clump: int in 7:
		var center := Vector3(rng.randf_range(-0.62, 0.62), 0, rng.randf_range(-0.42, 0.42))
		for blade: int in 13:
			var base := center + Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.18, 0.18))
			var angle := rng.randf() * TAU
			var across := Vector3(cos(angle), 0, sin(angle))
			var lean := Vector3(-sin(angle), 0, cos(angle)) * rng.randf_range(0.06, 0.19)
			var height := rng.randf_range(0.20, 0.48)
			var width := rng.randf_range(0.025, 0.055)
			var middle := base + Vector3.UP * height * 0.58 + lean * 0.3
			var tip := base + Vector3.UP * height + lean
			var bottom := [base - across * width, base + across * width, base + lean.normalized() * width * 0.5]
			var upper := [middle - across * width * 0.55, middle + across * width * 0.55,
				middle + lean.normalized() * width * 0.3]
			var color: Color = colors[rng.randi_range(0, 2) if variant != 2 else rng.randi_range(1, 3)]
			for side: int in 3:
				var next := (side + 1) % 3
				for triangle: Array in [[bottom[side], upper[side], bottom[next]],
					[bottom[next], upper[side], upper[next]], [upper[side], tip, upper[next]]]:
					for point: Vector3 in triangle:
						surface.set_color(color)
						surface.add_vertex(point)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.resource_name = "Cour_grass_volume"
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic_specular = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh
