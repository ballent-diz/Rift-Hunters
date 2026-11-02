extends "res://assets/vfx/enemies/chapter3/enemy_effect.gd"
## Présentation pure : dimensions, niveau d'eau et état de rupture viennent du combat.
## Aucun dégât, déplacement réel, recherche de cible ou collision.


func _stroke(points: PackedVector2Array, size: float, ink: Color, light: Color, fade: float) -> void:
	# Sous-couche colorée, puis grain du pinceau commun : lisible aussi sur un sol clair.
	Stroke.stroke(self, points, size * 0.7, ink, light, fade * 0.45)
	super._stroke(points, size, ink, light, fade)


func release() -> void:
	if effect_kind in [&"silk_thread", &"ice_prison", &"slag_shell"]:
		stage = 1.0
		strength = 0.0
	super.release()


func _draw() -> void:
	if not _visible_time or _finished:
		return
	_facet_vertices.clear()
	_facet_colors.clear()
	_facet_indices.clear()
	var p: float = fposmod(_elapsed, duration()) / duration() if loop_visual else clampf(_elapsed / duration(), 0, 1)
	var fade: float = 1.0 if loop_visual else 1.0 - smoothstep(0.8, 1.0, p)
	if _releasing:
		fade *= 1.0 - clampf(_release_age / 0.22, 0, 1)
	match effect_kind:
		&"duel_circle", &"hush_circle", &"cold_aura": _ring(p, fade)
		&"silk_thread": _silk(p, fade)
		&"slag_shell": _shell(p, fade)
		&"slag_rain_impact", &"dive_burst":
			_debris(Vector2.ZERO, p, fade, radius, 24)
			_contact(Vector2.ZERO, radius * 0.3, p, fade)
		&"bark_shield": _bark(p, fade)
		&"dive_ripple": _ripples(p, fade)
		&"snowball": _snowball(p, fade)
		&"ice_prison": _prison(p, fade)
		&"blizzard_vortex": _vortex(p, fade)
		&"frost_mist": _mist(p, fade)
		&"ice_crack": _crack(p, fade)
		&"spell_echo_volley": _volley(p, fade)
		&"ice_spikes": _spikes(p, fade)
		&"shatter_floor": _floor(p, fade)
		&"spell_capture": _swallow(p, fade)
		&"rockfall": _rockfall(p, fade)
		&"tide_water": _water(p, fade)
	if not _facet_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _facet_indices, _facet_vertices, _facet_colors)


func _arc(at: Vector2, r: float, start: float, length: float, size: float, opacity: float) -> void:
	var points := PackedVector2Array()
	for i: int in 25:
		points.append(at + Vector2.from_angle(start + length * i / 24.0) * r)
	_stroke(points, size, color.darkened(0.6), color, opacity)
	_stroke(points, 1.3, color, accent, opacity * 0.8)


func _ring(p: float, fade: float) -> void:
	var count: int = 24 if effect_kind == &"hush_circle" else 16
	var warm: bool = effect_kind == &"cold_aura"
	for i: int in count:
		var angle: float = TAU * i / count
		var pulse: float = 0.82 + 0.18 * sin(p * TAU + i * 1.7)
		_arc(Vector2.ZERO, radius, angle, TAU / count * 0.85, width * pulse, fade * (0.32 if warm else 0.85))
		if not warm:
			var at: Vector2 = Vector2.from_angle(angle) * radius
			_facet(at + Vector2(0, -5.0 - pulse * 5), -PI / 2, 12 + pulse * 8, 5, color, accent, fade * 0.75)
			if effect_kind == &"duel_circle":
				var flame := PackedVector2Array([at, at + Vector2(sin(p * TAU + i) * 6, -12),
					at + Vector2(sin(p * TAU + i + 1) * 4, -27)])
				_stroke(flame, 11, color.darkened(0.5), accent, fade * pulse)
	if warm:
		for i: int in mini(particle_budget, 12):
			var at: Vector2 = Vector2.from_angle(i * 2.39996) * radius * (0.25 + i % 4 * 0.16)
			at.y -= fposmod(p + i * 0.13, 1.0) * 12
			_facet(at, -PI / 2, 4, 2, color, accent, fade * 0.45)


func _silk(p: float, fade: float) -> void:
	var path: PackedVector2Array = _line()
	var first: Vector2 = path[0]
	var last: Vector2 = path[-1]
	for half: int in 2:
		var points := PackedVector2Array()
		for i: int in 13:
			var t: float = (i / 12.0 + half) * 0.5
			if stage > 0.5:
				t = t * 0.88 if half == 0 else 0.56 + (t - 0.5) * 0.88
			var at: Vector2 = first.lerp(last, t)
			at.y += sin(t * PI) * (3.0 + stage * 28.0) + sin(t * TAU * 4 + p * TAU) * 0.7
			points.append(at)
		_stroke(points, 3.5, Color("403643"), color, fade)
		_stroke(points, 1, color, accent, fade)
	for i: int in mini(particle_budget, 12):
		var t: float = i / 11.0
		_facet(first.lerp(last, t), PI / 4, 3, 1.5, color, accent, fade * 0.7)


func _shell(p: float, fade: float) -> void:
	for row: int in 3:
		for column: int in 4:
			if row != 1 and column in [0, 3]:
				continue
			var center := Vector2((column - 1.5) * radius * 0.34 + (row % 2) * 5, (row - 1) * radius * 0.3)
			var direction: Vector2 = center.normalized()
			center += direction * (1 - strength) * 22
			var plate := PackedVector2Array([center + Vector2(-12, 0), center + Vector2(-8, -13),
				center + Vector2(7, -14), center + Vector2(13, 0), center + Vector2(6, 11), center + Vector2(-8, 10)])
			draw_colored_polygon(plate, Color(color.darkened(0.25 + row * 0.09), fade * 0.85))
			_stroke(PackedVector2Array([plate[0], plate[1], plate[2], plate[3]]), 3,
				color.darkened(0.5), color.lerp(accent, 0.35), fade)
			_stroke(PackedVector2Array([center + Vector2(-3, -8), center + Vector2(3, -2), center + Vector2(0, 7)]),
				1.5, color, accent, fade * (0.4 + sin(p * TAU + column) * 0.15))


func _bark(p: float, fade: float) -> void:
	for i: int in 9:
		var a: float = -1.05 + i / 8.0 * 2.1
		var center: Vector2 = Vector2.from_angle(a) * radius
		_facet(center, a + PI / 2, radius * 0.5, 17, color.darkened(0.45), color, fade)
		for grain: int in 3:
			var offset := Vector2(grain * 3 - 3, -12)
			_stroke(PackedVector2Array([center + offset, center + offset + Vector2(3, 18)]),
				1.3, color.darkened(0.7), accent, fade * 0.55)
		if i % 2 == 0:
			_facet(center + Vector2(-5, -16 - sin(p * TAU + i) * 1.5), a, 12, 6, Color("4c6853"), accent, fade)


func _ripples(p: float, fade: float) -> void:
	for ring: int in 3:
		var t: float = fposmod(p + ring / 3.0, 1)
		var points := PackedVector2Array()
		for i: int in 33:
			var a: float = i * TAU / 32
			points.append(Vector2(cos(a), sin(a) * 0.4) * radius * (0.3 + t * 0.7))
		_stroke(points, 3, color.darkened(0.7), color, fade * sin(t * PI) * 0.7)
		_stroke(points, 1, color, accent, fade * sin(t * PI) * 0.7)


func _snowball(p: float, fade: float) -> void:
	var size: float = radius * (0.6 + stage * 0.4)
	for i: int in 24:
		var a: float = i * TAU / 24
		var b: float = (i + 1) * TAU / 24
		var shade: float = clampf(0.45 + Vector2.from_angle(a).dot(Vector2(-0.7, -0.7)) * 0.45, 0, 1)
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO,
			Vector2.from_angle(a) * size, Vector2.from_angle(b) * size]), Color(color.lerp(accent, shade), fade))
	for i: int in mini(particle_budget, 20):
		var angle: float = i * 2.39996 + p * TAU
		var center: Vector2 = Vector2.from_angle(angle) * size * sqrt((i + 0.5) / 22.0) * 0.82
		_facet(center, angle, 2.5 + i % 3, 1.6, color, accent, fade * 0.8)
	_arc(Vector2.ZERO, size * 0.95, -PI * 0.92, PI * 0.76, 3, fade * 0.85)


func _prison(_p: float, fade: float) -> void:
	if strength > 0.5:
		var block := PackedVector2Array([Vector2(-radius * 0.7, 0), Vector2(-radius * 0.76, -radius * 1.4),
			Vector2(-radius * 0.35, -radius * 1.85), Vector2(radius * 0.5, -radius * 1.7),
			Vector2(radius * 0.75, -radius * 1.25), Vector2(radius * 0.7, 0)])
		draw_colored_polygon(block, Color(color, fade * 0.3))
		var border: PackedVector2Array = block.duplicate()
		border.append(block[0])
		_stroke(border, 4, color.darkened(0.3), accent, fade)
		_stroke(PackedVector2Array([block[2], Vector2(-radius * 0.1, -radius), Vector2(radius * 0.05, 0)]),
			3, color, accent, fade * 0.75)
		_stroke(PackedVector2Array([block[3], Vector2(radius * 0.25, -radius * 0.8), block[5]]),
			2, color, accent, fade * 0.6)
		return
	for i: int in 7:
		var a: float = TAU * i / 7
		var at := Vector2(cos(a) * radius * 0.65, sin(a) * radius * 0.25 - radius * 0.55)
		at += Vector2.from_angle(a) * (1 - strength) * (12 + _release_age * 160)
		_facet(at, -PI / 2 + (1 - strength) * sin(a) * 0.8, radius * 1.65, radius * 0.4, color, accent, fade * 0.8)
		_stroke(PackedVector2Array([at + Vector2(-3, 24), at + Vector2(0, -28)]), 1.5, color, accent, fade)


func _vortex(p: float, fade: float) -> void:
	for arm: int in 5:
		var points := PackedVector2Array()
		for i: int in 29:
			var t: float = i / 28.0
			var a: float = t * TAU * 1.4 + arm * TAU / 5 - p * TAU
			points.append(Vector2(cos(a) * radius * (0.25 + t * 0.6), -t * radius * 1.6 + sin(a) * radius * 0.2))
		_stroke(points, width * (0.8 + arm * 0.12), color.darkened(0.5), color, fade * 0.85)
		_stroke(points, 1.7, color, accent, fade * 0.7)
	_debris(Vector2(0, -radius * 0.6), p, fade * 0.6, radius, 12)


func _mist(p: float, fade: float) -> void:
	for band: int in 5:
		var points := PackedVector2Array()
		for i: int in 19:
			var t: float = i / 18.0
			points.append(Vector2((t - 0.5) * radius * 2, band * 6 - 12 + sin(t * TAU * 1.7 - p * TAU + band) * 7))
		_stroke(points, width * 0.8, color.darkened(0.5), color, fade * 0.5)
	_debris(Vector2.ZERO, p, fade * 0.35, radius * 0.7, 8)


func _crack(p: float, fade: float) -> void:
	var path: PackedVector2Array = _line()
	for segment: int in path.size() - 1:
		var points := PackedVector2Array()
		for i: int in 17:
			var t: float = i / 16.0
			if t > minf(p * 2, 1):
				break
			var at: Vector2 = path[segment].lerp(path[segment + 1], t)
			at.y += sin(i * 2.7) * 7
			points.append(at)
			if i % 3 == 1:
				_stroke(PackedVector2Array([at, at + Vector2(-12, sin(i) * 21)]), 3, color, accent, fade)
		_stroke(points, width, color.darkened(0.7), color, fade)
		_stroke(points, 2, color, accent, fade)


func _volley(p: float, fade: float) -> void:
	for i: int in 3:
		var direction := Vector2.from_angle((i - 1) * 0.22)
		var at: Vector2 = direction * travel_distance * p
		_stroke(PackedVector2Array([at - direction * 25, at]), width, color.darkened(0.6), color, fade)
		_facet(at, direction.angle(), 28, 12, color, accent, fade)


func _spikes(p: float, fade: float) -> void:
	var grow: float = smoothstep(0, 0.35, p)
	for i: int in 7:
		var at := Vector2((i - 3) * radius * 0.24, absf(i - 3) * 3)
		var height: float = (radius * 0.55 + (i % 3) * 13) * grow
		_facet(at + Vector2(0, -height * 0.5), -PI / 2, height, 18, color, accent, fade)
	if p > 0.6:
		_debris(Vector2(0, -radius * 0.4), (p - 0.6) / 0.4, fade, radius * 0.6, 12)


func _floor(p: float, fade: float) -> void:
	for i: int in 7:
		var a: float = i * TAU / 7
		var at: Vector2 = Vector2.from_angle(a) * radius * (0.35 + p * 0.25)
		at.y += maxf(p - 0.45, 0) * radius * 0.8
		_facet(at, a + p * 0.5, radius * 0.7 * (1 - p * 0.35), radius * 0.4, color.darkened(0.4), accent, fade)
		_stroke(PackedVector2Array([Vector2.ZERO, at]), 2, color.darkened(0.8), accent, fade * 0.8)


func _rockfall(p: float, fade: float) -> void:
	var t: float = clampf(p / 0.6, 0, 1)
	var at := Vector2(-travel_distance * (1 - t), -radius * 3 * (1 - t) - sin(t * PI) * radius)
	if p < 0.65:
		_facet(at, p * TAU, radius * 0.8, radius * 0.65, color.darkened(0.4), color, fade)
		_facet(at + Vector2(-4, -5), p * TAU + 0.4, radius * 0.4, radius * 0.3, color, accent, fade)
	if p >= 0.6:
		_debris(Vector2.ZERO, (p - 0.6) / 0.4, fade, radius * 1.3, 20)
		_contact(Vector2.ZERO, radius * 0.4, (p - 0.6) / 0.4, fade)


func _water(p: float, fade: float) -> void:
	var points := PackedVector2Array()
	var height: float = radius * (0.25 + stage * 0.75)
	for i: int in 25:
		var x: float = (i / 24.0 - 0.5) * travel_distance
		points.append(Vector2(x, -height + sin(i * 0.7 + p * TAU) * 3))
	var fill: PackedVector2Array = points.duplicate()
	fill.append(Vector2(travel_distance * 0.5, radius * 0.4))
	fill.append(Vector2(-travel_distance * 0.5, radius * 0.4))
	draw_colored_polygon(fill, Color(color, fade * 0.38))
	_stroke(points, width, color.darkened(0.35), accent, fade * 0.8)
	for band: int in 3:
		var stripe := PackedVector2Array()
		for i: int in 17:
			stripe.append(Vector2((i / 16.0 - 0.5) * travel_distance * 0.9, band * 12 - height * 0.55 + sin(i + p * TAU) * 2))
		_stroke(stripe, 2, color, accent, fade * 0.4)
