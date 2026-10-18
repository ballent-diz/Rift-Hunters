class_name RiftWallVisual
extends Node2D
## Rideau animé natif Godot : ruban continu et courbe à travers les rectangles voisins.
## Géométrie reconstruite seulement au changement de barrières ; aucune collision n'est modifiée.

const CURTAIN := preload("res://assets/shaders/rift_curtain.gdshader")

var members: Array[int] = []
var _curtain_material: ShaderMaterial
var _lift := Vector2(0, -108)
var _particles: CPUParticles2D


static func connected_groups(rects: Array[Rect2]) -> Array[PackedInt32Array]:
	var groups: Array[PackedInt32Array] = []
	var remaining: Array[int] = []
	for i: int in rects.size():
		remaining.append(i)
	while not remaining.is_empty():
		var group := PackedInt32Array([remaining.pop_back()])
		var cursor: int = 0
		while cursor < group.size():
			for j: int in range(remaining.size() - 1, -1, -1):
				if rects[group[cursor]].grow(0.5).intersects(rects[remaining[j]], true):
					group.append(remaining[j])
					remaining.remove_at(j)
			cursor += 1
		groups.append(group)
	return groups


static func curtain_path(rects: Array[Rect2]) -> PackedVector2Array:
	var ordered: Array[Rect2] = rects.duplicate()
	var axis := Vector2.RIGHT
	if rects.size() == 1:
		axis = Vector2.DOWN if rects[0].size.y > rects[0].size.x else Vector2.RIGHT
	else:
		var longest: float = -1.0
		for a: Rect2 in rects:
			for b: Rect2 in rects:
				var distance: float = a.get_center().distance_squared_to(b.get_center())
				if distance > longest:
					longest = distance
					axis = (b.get_center() - a.get_center()).normalized()
	if axis == Vector2.ZERO:
		axis = Vector2.DOWN if rects[0].size.y > rects[0].size.x else Vector2.RIGHT
	ordered.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.get_center().dot(axis) < b.get_center().dot(axis))
	var points := PackedVector2Array()
	var first: Rect2 = ordered[0]
	var last: Rect2 = ordered[-1]
	points.append(first.get_center() - axis * _reach(first, axis))
	for rect: Rect2 in ordered:
		points.append(rect.get_center())
	points.append(last.get_center() + axis * _reach(last, axis))
	var curve := Curve2D.new()
	curve.bake_interval = 10.0
	for i: int in points.size():
		var tangent: Vector2 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]) * 0.18
		curve.add_point(points[i], -tangent, tangent)
	return curve.get_baked_points()


static func _reach(rect: Rect2, direction: Vector2) -> float:
	return minf(rect.size.x * 0.5 / maxf(absf(direction.x), 0.001),
		rect.size.y * 0.5 / maxf(absf(direction.y), 0.001))


func setup(rects: Array[Rect2], indices: Array[int]) -> void:
	members = indices
	var path: PackedVector2Array = curtain_path(rects)
	var span: Vector2 = path[-1] - path[0]
	_lift = Vector2(58.0 if absf(span.y) > absf(span.x) * 1.6 else 0.0, -108.0)
	var entry: Dictionary = Assets.entry(&"vfx.barrier.energy")
	_curtain_material = ShaderMaterial.new()
	_curtain_material.shader = CURTAIN
	_curtain_material.set_shader_parameter("energy_atlas", load(String(entry.get("sheet", ""))))
	_curtain_material.set_shader_parameter("lift", _lift)
	var segments: Array[PackedVector2Array] = []
	for i: int in path.size() - 1:
		segments.append(PackedVector2Array([path[i], path[i + 1]]))
	_build_curtain(segments)
	_build_particles(path)


func _build_curtain(segments: Array[PackedVector2Array]) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var total: float = 0.0
	for segment: PackedVector2Array in segments:
		total += segment[0].distance_to(segment[1])
	var traveled: float = 0.0
	for segment: PackedVector2Array in segments:
		var columns: int = maxi(1, ceili(segment[0].distance_to(segment[1]) / 16.0))
		for column: int in columns:
			var a: Vector2 = segment[0].lerp(segment[1], float(column) / columns)
			var b: Vector2 = segment[0].lerp(segment[1], float(column + 1) / columns)
			for row: int in 6:
				var top: float = float(row) / 6.0
				var bottom: float = float(row + 1) / 6.0
				var points: Array[Vector2] = [a, b, b, a, b, a]
				var heights: Array[float] = [top, top, bottom, top, bottom, bottom]
				var distances: Array[float] = [0.0, 1.0, 1.0, 0.0, 1.0, 0.0]
				for i: int in 6:
					var point: Vector2 = points[i] + _lift * (1.0 - heights[i])
					vertices.append(Vector3(point.x, point.y, 0))
					var along: float = traveled + segment[0].distance_to(a) + a.distance_to(b) * distances[i]
					uvs.append(Vector2(along / 140.0, heights[i]))
					colors.append(Color(along / maxf(total, 1.0), 1.0, 1.0, 1.0))
		traveled += segment[0].distance_to(segment[1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var curtain := MeshInstance2D.new()
	curtain.mesh = mesh
	curtain.material = _curtain_material
	add_child(curtain)


func _build_particles(path: PackedVector2Array) -> void:
	# Aucun émetteur graphique sans affichage (tests et serveur headless).
	if DisplayServer.get_name() == "headless":
		return
	_particles = CPUParticles2D.new()
	_particles.amount = 32
	_particles.lifetime = 0.9
	_particles.preprocess = 0.4
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_particles.emission_points = path
	_particles.direction = Vector2.UP
	_particles.spread = 24.0
	_particles.gravity = Vector2(0, -34)
	_particles.initial_velocity_min = 8.0
	_particles.initial_velocity_max = 28.0
	_particles.scale_amount_min = 1.2
	_particles.scale_amount_max = 2.2
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(0.5, 0.4, 1, 0), Color(0.9, 0.85, 1, 0.9),
		Color(0.5, 0.4, 1, 0.6), Color(0.3, 0.2, 1, 0)])
	_particles.color_ramp = gradient
	add_child(_particles)


func animate(strength: float, clock: float, dissolving: bool = false) -> void:
	visible = strength > 0.0
	_curtain_material.set_shader_parameter("strength", strength)
	_curtain_material.set_shader_parameter("clock", clock)
	_curtain_material.set_shader_parameter("dissolving", dissolving)
	if _particles:
		_particles.position = _lift * (1.0 if dissolving else smoothstep(0.0, 1.0, strength))
		_particles.modulate.a = strength
		_particles.emitting = strength > 0.1
