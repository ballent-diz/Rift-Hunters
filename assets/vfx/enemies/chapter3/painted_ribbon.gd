extends RefCounted
## Matière peinte en une commande : pas de bande rectangulaire opaque sous le pinceau.


static func stroke(canvas: Node2D, points: PackedVector2Array, width: float,
		ink: Color, light: Color, opacity: float, brush: Texture2D) -> void:
	if points.size() < 2 or width < 0.2 or opacity < 0.003 or brush == null:
		return
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var uv := PackedVector2Array()
	var normals := PackedVector2Array()
	var tapers := PackedFloat32Array()
	var shades: Array[Color] = [ink.darkened(0.2), ink.lerp(light, 0.35),
		ink.lerp(light, 0.85), ink.lerp(light, 0.55), ink]
	for i: int in points.size():
		var before: Vector2 = points[i] - points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 1, points.size() - 1)] - points[i]
		var tangent: Vector2 = before.normalized() + after.normalized()
		if tangent.length_squared() < 0.001:
			tangent = after if after.length_squared() > 0.001 else before
		normals.append(tangent.normalized().orthogonal())
		var u: float = i / float(points.size() - 1)
		tapers.append(0.15 + 0.85 * pow(maxf(sin(u * PI), 0.0), 0.3))
	# Contour et matière partagent la même commande et le même masque effilé.
	for layer: int in 2:
		var start: int = vertices.size()
		var band: float = width + 2.5 if layer == 0 else width
		for i: int in points.size():
			var u: float = i / float(points.size() - 1)
			for row: int in 5:
				var v: float = row / 4.0
				vertices.append(points[i] + normals[i] * (v - 0.5) * band * tapers[i])
				colors.append(Color(ink.darkened(0.4) if layer == 0 else shades[row], opacity))
				uv.append(Vector2(u, v))
			if i == 0 or points[i].distance_squared_to(points[i - 1]) < 0.01:
				continue
			for row: int in 4:
				var a: int = start + (i - 1) * 5 + row
				var b: int = start + i * 5 + row
				indices.append_array(PackedInt32Array([a, b, b + 1, a, b + 1, a + 1]))
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices,
			vertices, colors, uv, PackedInt32Array(), PackedFloat32Array(), brush.get_rid())
