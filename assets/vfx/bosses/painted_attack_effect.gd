extends "res://assets/vfx/enemies/chapter3/enemy_effect.gd"
## Motifs peints autonomes ; le combat fournit l'origine, le trajet et les événements réels.
var star_points := PackedVector2Array()


func _stroke(points: PackedVector2Array, size: float, ink: Color, light: Color, fade: float) -> void:
	Stroke.stroke(self, points, size * 0.7, ink, light, fade * 0.45)
	super._stroke(points, size, ink, light, fade)


func set_star_positions(points: PackedVector2Array) -> void:
	star_points = points.slice(0, 32)
	queue_redraw()


func _draw() -> void:
	if not _visible_time or _finished:
		return
	_facet_vertices.clear()
	_facet_colors.clear()
	_facet_indices.clear()
	var p: float = fposmod(_elapsed, duration()) / duration() if loop_visual else clampf(_elapsed / duration(), 0, 1)
	var fade: float = 1.0 if loop_visual else 1.0 - smoothstep(0.75, 1.0, p)
	if _releasing:
		fade *= 1.0 - clampf(_release_age / 0.22, 0, 1)
	match effect_kind:
		&"claw", &"sweep": _claw(p, fade)
		&"shadow_wave": _wave(p, fade)
		&"summon", &"brood", &"lay_eggs": _summoning(p, fade)
		&"absorb": _absorption(p, fade)
		&"void_beam", &"eye_beam": _beam(p, fade)
		&"star_crown": _crown(p, fade)
		&"crater_sequence", &"eruption": _eruption(p, fade)
		&"rock_rain": _rain(p, fade)
		&"skyfall", &"dive", &"leap": _landing(p, fade)
		&"plunge": _burrow(p, fade)
		&"pyre_slam":
			_debris(Vector2.ZERO, p, fade, radius, 24)
			_fire_ring(p, fade)
		&"blazing_rage": _rage_flames(p, fade)
		&"soot_web": _web(p, fade)
		&"charge": _charge(p, fade)
		&"flame_breath": _breath_fire(p, fade)
		&"slag_molt": _molt(p, fade)
	if not _facet_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _facet_indices, _facet_vertices, _facet_colors)


func _fire_ring(p: float, fade: float) -> void:
	for i: int in 12:
		var a: float = i * TAU / 12
		var start: Vector2 = Vector2.from_angle(a) * radius * (0.25 + p * 0.7)
		var finish: Vector2 = Vector2.from_angle(a + 0.35) * radius * (0.3 + p * 0.7)
		_stroke(PackedVector2Array([start, start.lerp(finish, 0.5) + Vector2(0, -6), finish]),
			width * (1 - p * 0.65), color.darkened(0.6), color, fade)
		_facet(start, a + PI / 2, 12, 4, color, accent, fade)


func _wave(p: float, fade: float) -> void:
	for band: int in 5:
		var points := PackedVector2Array()
		for i: int in 25:
			var t: float = i / 24.0
			var a: float = (t - 0.5) * 2.0
			points.append(Vector2(cos(a), sin(a)) * radius * (0.3 + p * 0.9) + Vector2(band * 6, 0))
		_stroke(points, width * (0.8 - band * 0.09), color.darkened(0.7), color, fade * 0.8)
	_debris(Vector2(radius * p, 0), p, fade * 0.6, radius * 0.5, 12)


func _summoning(p: float, fade: float) -> void:
	var count: int = mini(secondary_offsets.size(), 8) if not secondary_offsets.is_empty() else 3
	for i: int in count:
		var at: Vector2 = secondary_offsets[i] if not secondary_offsets.is_empty() else Vector2((i - 1) * radius * 0.55, 0)
		for arm: int in 3:
			var points := PackedVector2Array()
			for n: int in 17:
				var t: float = n / 16.0
				var a: float = arm * TAU / 3 + t * TAU - p * TAU
				points.append(at + Vector2(cos(a), sin(a) * 0.4) * radius * 0.35 * (1 - t))
			_stroke(points, 5, color.darkened(0.6), color, fade)
		if effect_kind != &"summon":
			_facet(at + Vector2(0, -12), -PI / 2, 30, 21, color.darkened(0.65), color, fade)
			_stroke(PackedVector2Array([at + Vector2(-4, -22), at + Vector2(2, -14), at + Vector2(-2, -4)]),
				2, color, accent, fade * (0.6 + sin(p * TAU) * 0.2))
		else:
			_facet(at + Vector2(0, -radius * p * 0.4), -PI / 2, 12 + p * 18, 7, color, accent, fade)


func _absorption(p: float, fade: float) -> void:
	if p < 0.65:
		_swallow(p / 0.65, fade)
	else:
		var t: float = (p - 0.65) / 0.35
		for i: int in mini(particle_budget, 9):
			var a: float = (i - 4) * 0.14
			var at: Vector2 = Vector2.from_angle(a) * travel_distance * t
			_facet(at, a, 18, 7, color, accent, fade)
			_stroke(PackedVector2Array([at - Vector2.from_angle(a) * 20, at]), 7, color.darkened(0.5), color, fade)


func _crown(p: float, fade: float) -> void:
	var count: int = star_points.size() if not star_points.is_empty() else mini(particle_budget, 12)
	for i: int in count:
		if star_points.is_empty() and i < 2:
			continue
		var a: float = i * TAU / maxf(count, 1) + p * TAU
		var at: Vector2 = star_points[i] if not star_points.is_empty() else Vector2.from_angle(a) * radius
		Shapes.star(self, at, width * 0.7, Color(color, fade), a)
		Shapes.star(self, at, width * 0.32, Color(accent, fade), -a)
		_facet(at, a, width * 1.7, width * 0.3, color, accent, fade)
		var trail := PackedVector2Array()
		for j: int in 9:
			trail.append(Vector2.from_angle(a - j * 0.025) * at.length())
		_stroke(trail, width * 0.3, color.darkened(0.5), color, fade * 0.65)


func _eruption(p: float, fade: float) -> void:
	if effect_kind == &"eruption" and stage > 0.5:
		for i: int in 12:
			var a: float = i * TAU / 12
			var at: Vector2 = Vector2.from_angle(a) * radius * 0.55
			_facet(at, a + PI / 2, radius * 0.3, width * 0.65, color.darkened(0.7), color, fade)
			_stroke(PackedVector2Array([at * 0.7, at]), 3, color, accent, fade * 0.75)
		return
	_fire_ring(minf(p * 1.5, 1), fade * 0.7)
	for jet: int in 7:
		var points := PackedVector2Array()
		for i: int in 16:
			var t: float = i / 15.0
			var rise: float = sin(minf(p * 1.3, 1) * PI)
			points.append(Vector2((jet - 3) * radius * 0.1 + sin(t * 7 + jet) * 5,
				-t * radius * 1.7 * rise + t * t * radius * 0.25))
		_stroke(points, width * (0.4 + (jet % 3) * 0.2), color.darkened(0.5), color, fade)
		_stroke(points, 2, color, accent, fade * 0.8)
	_debris(Vector2(0, -radius * 0.4), p, fade, radius, 16)


func _rain(p: float, fade: float) -> void:
	var count: int = secondary_offsets.size() if not secondary_offsets.is_empty() else 1
	for i: int in mini(count, 8):
		var impact: Vector2 = secondary_offsets[i] if not secondary_offsets.is_empty() else Vector2.ZERO
		var t: float = clampf(p * 1.5, 0, 1)
		var at: Vector2 = impact + Vector2(-radius * (1 - t), -radius * 2.5 * (1 - t))
		if p < 0.7:
			_facet(at, p * TAU + i, width * 1.5, width, color.darkened(0.6), color, fade)
		if p > 0.65:
			_debris(impact, (p - 0.65) / 0.35, fade, radius * 0.7, 12)


func _landing(p: float, fade: float) -> void:
	if p < 0.65:
		var points := PackedVector2Array()
		for i: int in 14:
			var t: float = i / 13.0
			points.append(Vector2(sin(t * PI) * width * 0.3, -radius * 2 * (1 - p / 0.65) - t * radius * 0.7))
		_stroke(points, width * 0.65, color.darkened(0.6), color, fade * p)
	else:
		var t: float = (p - 0.65) / 0.35
		_debris(Vector2.ZERO, t, fade, radius, 24)
		_fire_ring(t, fade)


func _burrow(p: float, fade: float) -> void:
	for i: int in 9:
		var x: float = (i - 4) * radius * 0.18
		var at := Vector2(x, sin(i * 2.1 + p * TAU) * 3)
		_facet(at, i * 0.7, width * 0.8, width * 0.4, color.darkened(0.7), color, fade)
	if p > 0.65:
		_debris(Vector2.ZERO, (p - 0.65) / 0.35, fade, radius, 20)


func _rage_flames(p: float, fade: float) -> void:
	for i: int in 9:
		var a: float = i * TAU / 9
		var at: Vector2 = Vector2.from_angle(a) * radius * 0.55
		var points := PackedVector2Array([at, at + Vector2(sin(p * TAU + i) * 7, -15),
			at + Vector2(sin(p * TAU + i + 1) * 4, -35)])
		_stroke(points, width * 0.8, color.darkened(0.5), color, fade * 0.85)
		_stroke(points, 2, color, accent, fade * 0.7)


func _web(p: float, fade: float) -> void:
	for ring: int in 3:
		var points := PackedVector2Array()
		for i: int in 25:
			var a: float = i * TAU / 24
			points.append(Vector2(cos(a), sin(a) * 0.7) * radius * (ring + 1) / 3.0)
		_stroke(points, 2, color.darkened(0.6), color, fade * 0.8)
	for i: int in 8:
		var tip: Vector2 = Vector2(cos(i * TAU / 8), sin(i * TAU / 8) * 0.7) * radius
		_stroke(PackedVector2Array([Vector2.ZERO, tip]), 2, color.darkened(0.5), accent, fade * 0.8)
	_debris(Vector2.ZERO, p, fade * 0.25, radius, 8)


func _charge(p: float, fade: float) -> void:
	if p < 0.6:
		var points: PackedVector2Array = _line()
		_stroke(points, width, color.darkened(0.6), color, fade * sin(p / 0.6 * PI))
		_debris(points[-1], p / 0.6, fade * 0.5, width * 1.5, 10)
	else:
		var t: float = (p - 0.6) / 0.4
		var points := PackedVector2Array()
		for i: int in 20:
			var angle: float = t * TAU - i / 19.0 * 1.8
			points.append(Vector2.from_angle(angle) * radius)
		_stroke(points, width * 1.4, color.darkened(0.6), color, fade)
		_stroke(points, 2, color, accent, fade * 0.9)


func _breath_fire(p: float, fade: float) -> void:
	var length: float = travel_distance * smoothstep(0, 0.25, p)
	for band: int in 7:
		var angle: float = (band - 3) * deg_to_rad(half_angle_degrees) / 3
		var direction := Vector2.from_angle(angle)
		var points := PackedVector2Array()
		for i: int in 21:
			var t: float = i / 20.0
			points.append(direction * length * t + Vector2(0, sin(t * 12 - p * TAU * 2 + band) * width * t * 0.2))
		_stroke(points, width * (1.5 + band % 2 * 0.3), color.darkened(0.6), color, fade * 0.8)
		_stroke(points, 2, color, accent, fade * 0.7)


func _molt(p: float, fade: float) -> void:
	for i: int in 10:
		var a: float = i * TAU / 10
		var at: Vector2 = Vector2(cos(a), sin(a) * 0.55) * radius * (0.5 + p * 0.45)
		at.y += p * p * radius * 0.3
		_facet(at, a + p * 0.5, width * (1.2 - p * 0.4), width * 0.65,
			color.darkened(0.7), color, fade)
	_fire_ring(p, fade * 0.4)
