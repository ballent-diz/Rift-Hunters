extends RefCounted
## Rubans peints groupés : deux commandes de dessin, quel que soit le nombre de segments.
## Matière et volume visibles à la taille du jeu ; aucun nœud, collision ou horloge de gameplay.


static func stroke(canvas: Node2D, points: PackedVector2Array, width: float,
		ink: Color, light: Color, fade: float, brush: Texture2D = null) -> void:
	if points.size() < 2 or width < 0.2 or fade < 0.003:
		return
	var normals := PackedVector2Array()
	for i: int in points.size():
		var before: Vector2 = points[i] - points[maxi(0, i - 1)]
		var after: Vector2 = points[mini(points.size() - 1, i + 1)] - points[i]
		var tangent: Vector2 = before.normalized() + after.normalized()
		if tangent.length_squared() < 0.001:
			tangent = after if after.length_squared() > 0.001 else before
		normals.append(tangent.normalized().orthogonal())
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var shade := Color(ink.r * 0.3, ink.g * 0.3, ink.b * 0.4, fade * 0.65)
	var middle := Color(ink, fade * 0.95)
	var shine := Color(ink.lerp(light, 0.65), fade)
	var rows: Array[float] = [-0.45, -0.28, 0.0, 0.28, 0.45]
	var ramp: Array[Color] = [shade, middle, shine, middle, shade]
	for i: int in points.size():
		for row: int in rows.size():
			vertices.append(points[i] + normals[i] * width * rows[row])
			colors.append(ramp[row])
		if i == 0 or points[i].distance_squared_to(points[i - 1]) < 0.01:
			continue
		for row: int in 4:
			var a: int = (i - 1) * 5 + row
			var b: int = i * 5 + row
			indices.append_array(PackedInt32Array([a, b, b + 1, a, b + 1, a + 1]))
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, vertices, colors)
	if brush == null:
		return
	vertices.clear()
	indices.clear()
	var uv := PackedVector2Array()
	for i: int in points.size():
		var u: float = i / float(points.size() - 1)
		vertices.append(points[i] - normals[i] * width * 0.9)
		vertices.append(points[i] + normals[i] * width * 0.9)
		uv.append(Vector2(u, 0))
		uv.append(Vector2(u, 1))
		if i > 0 and points[i].distance_squared_to(points[i - 1]) > 0.01:
			var a: int = (i - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 3, a, a + 3, a + 1]))
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, vertices,
		PackedColorArray([Color(light, fade * 0.85)]), uv, PackedInt32Array(), PackedFloat32Array(), brush.get_rid())
