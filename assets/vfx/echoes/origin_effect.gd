extends "res://assets/vfx/echoes/echo_effect.gd"
## C5-ter : vocabulaire peint des sept Échos d'origine ; contrat et couche commune hérités.


func _draw() -> void:
	if _elapsed >= duration():
		return
	var p: float = clampf(_elapsed / duration(), 0.0, 1.0)
	var fade: float = smoothstep(0.0, 0.08, p) * (1.0 - smoothstep(0.78, 1.0, p))
	if effect_kind == &"reflection" and loop_visual and not _releasing:
		fade = 0.85 + sin(p * TAU) * 0.1
	if fade <= 0.001:
		return
	match effect_kind:
		&"indicator": _indicator(fade)
		&"blade_pounce": _blade_move(p, fade, true)
		&"cinder_dash": _blade_move(p, fade, false)
		&"ash_dance": _dance(p, fade)
		&"stone_slam": _slam(p, fade)
		&"fracture": _cracks(Vector2.ZERO, radius, p, fade)
		&"stone_gravity": _well(p, fade)
		&"stone_taunt": _rampart(p, fade)
		&"prism_orb": _orb(p, fade)
		&"prism_mark": _mark(Vector2.ZERO, radius, p, fade)
		&"prism_flare": _flare(p, fade)
		&"spark_rain": _prism_rain(p, fade)
		&"thorn_patch", &"roots": _bramble(Vector2.ZERO, radius, p, fade)
		&"briar_wall": _briar_line(p, fade)
		&"bloom": _bloom(p, fade)
		&"chain", &"electrified": _chain(p, fade)
		&"ion_storm": _storm(p, fade)
		&"devour": _jaws(Vector2(travel_distance * smoothstep(0.08, 0.3, p), 0), radius, p, fade)
		&"feast": _feast(p, fade)
		&"maw_pit": _pit(p, fade)
		&"mirror_bolt": _mirrors(p, fade, 1)
		&"mirror_shards": _mirrors(p, fade, 5)
		&"reflection": _mirror_guard(p, fade)


func _slash(center: Vector2, size: float, p: float, fade: float, flip: float = 1.0) -> void:
	var sweep: float = lerpf(-1.4, 1.0, smoothstep(0.05, 0.8, p))
	for layer: int in (3 if detail_level == 1 else 2):
		var points := PackedVector2Array()
		for i: int in (14 if detail_level == 1 else 7):
			var angle: float = sweep - i * 0.075
			points.append(center + Vector2(cos(angle), sin(angle) * flip) * (size - layer * 5))
		_path(points, 12.0 - layer * 3, accent if layer == 0 else color, fade * (1 - layer * 0.2))
	if p > 0.35:
		for i: int in mini(5, particle_budget):
			var pos: Vector2 = center + Vector2.from_angle(i * 2.399 + sweep) * size * p
			_spark(pos, 8 * (1 - p), fade, i + p)


func _blade_move(p: float, fade: float, pounce: bool) -> void:
	var move: float = smoothstep(0.08, 0.50, p)
	var tip := Vector2(travel_distance * move, 0)
	if pounce:
		tip.y -= sin(move * PI) * minf(35, radius * 0.6)
	var ribbon := PackedVector2Array()
	for i: int in 12:
		var back: float = i / 11.0
		ribbon.append(tip - Vector2(minf(tip.x, 85) * back, -sin(back * PI) * 8))
	_path(ribbon, 20, color, fade * 0.65)
	_path(ribbon, 5, accent, fade * 0.7)
	_slash(tip, radius, clampf((p - 0.25) / 0.7, 0, 1), fade)
	if not pounce:
		_slash(tip + Vector2(-10, 0), radius * 0.75, clampf((p - 0.3) / 0.6, 0, 1), fade * 0.7, -1)


func _dance(p: float, fade: float) -> void:
	if secondary_offsets.is_empty():
		_slash(Vector2.ZERO, radius, p, fade)
		return
	var count: int = mini(secondary_offsets.size(), 6)
	for i: int in count:
		var age: float = (p - 0.10 - i * 0.10) / 0.32
		if age < 0 or age > 1:
			continue
		var target: Vector2 = secondary_offsets[i]
		var start: Vector2 = Vector2.ZERO if i == 0 else secondary_offsets[i - 1]
		var tip: Vector2 = start.lerp(target, smoothstep(0, 0.4, age))
		_path(PackedVector2Array([start, (start + tip) * 0.5 + Vector2(0, -12), tip]),
			10, color, fade * (1 - age) * 0.7)
		_slash(target, radius, age, fade * sin(age * PI), -1 if i % 2 else 1)


func _cracks(center: Vector2, size: float, p: float, fade: float) -> void:
	var growth: float = smoothstep(0.05, 0.35, p)
	for i: int in mini(7, particle_budget):
		var a: float = i * TAU / 7.0 + 0.2
		var points := PackedVector2Array([center, center + Vector2.from_angle(a - 0.12) * size * 0.42 * growth,
			center + Vector2.from_angle(a + 0.05) * size * 0.75 * growth,
			center + Vector2.from_angle(a) * size * growth])
		draw_polyline(points, _ink(Color("25232e"), fade * 0.7), 4)
		draw_polyline(points, _ink(color, fade * 0.9), 1.5)
		if detail_level == 1:
			draw_line(points[1], points[1] + Vector2.from_angle(a + 0.8) * size * 0.2 * growth,
				_ink(accent, fade * 0.6), 1)


func _slam(p: float, fade: float) -> void:
	_cracks(Vector2.ZERO, radius, p, fade)
	for i: int in mini(9, particle_budget):
		var a: float = i * 2.39996
		var lift: float = sin(clampf((p - 0.1) / 0.8, 0, 1) * PI)
		var pos: Vector2 = Vector2.from_angle(a) * radius * (0.2 + p * 0.6) - Vector2(0, 20 * lift)
		_spark(pos, (8 + i % 3 * 4) * lift, fade, a + p)


func _well(p: float, fade: float) -> void:
	var collapse: float = smoothstep(0.62, 0.9, p)
	var size: float = radius * (1 - collapse * 0.8)
	for i: int in mini(12, particle_budget):
		var a: float = i * 2.39996 + p * 4
		var distance: float = size * (0.2 + fmod(i * 0.137 + 1 - p, 1) * 0.8)
		var pos := Vector2.from_angle(a) * Vector2(distance, distance * 0.65)
		_spark(pos, 10 + i % 3 * 3, fade, a)
		_path(PackedVector2Array([pos, pos * 0.7 + pos.orthogonal() * 0.18, pos * 0.45]),
			3, accent, fade * 0.45)
	if collapse > 0:
		_cracks(Vector2.ZERO, radius * collapse, p, fade * collapse)


func _rampart(p: float, fade: float) -> void:
	var grow: float = smoothstep(0.05, 0.3, p)
	if grow <= 0.002:
		return
	for i: int in 3:
		var base := Vector2((i - 1) * radius * 0.45, 15)
		var height: float = (32 + (1 - absi(i - 1)) * 16) * grow
		var top: Vector2 = base - Vector2(3, height)
		_poly(PackedVector2Array([base - Vector2(13, 0), top - Vector2(10, 0), top + Vector2(6, -6),
			top + Vector2(14, 4), base + Vector2(13, 3)]), _ink(Color("32333f"), fade * 0.55))
		_path(PackedVector2Array([base, top + Vector2(1, 14), top]), 5, color, fade * 0.9)
		_spark(top, 10, fade, -1.2)
	_cracks(Vector2.ZERO, radius * 0.7, p, fade * 0.7)


func _flight(p: float) -> Vector2:
	var progress: float = smoothstep(0.1, 0.78, p)
	if not secondary_offsets.is_empty():
		return secondary_offsets[0] * progress + Vector2(0, -sin(progress * PI) * 18)
	return Vector2(travel_distance * progress, -sin(progress * PI) * 12)


func _prism(pos: Vector2, size: float, angle: float, fade: float) -> void:
	_spark(pos, size, fade, angle)
	if detail_level == 1:
		_spark(pos + Vector2.from_angle(angle + 1.3) * size * 0.3, size * 0.55, fade * 0.65, angle - 0.5)
		draw_line(pos - Vector2.from_angle(angle) * size * 0.3,
			pos + Vector2.from_angle(angle) * size * 0.45, _ink(WHITE, fade), 1)


func _orb(p: float, fade: float) -> void:
	var pos: Vector2 = _flight(p)
	for i: int in (3 if detail_level == 1 else 1):
		var tail := PackedVector2Array()
		for j: int in 8:
			tail.append(pos + Vector2(-j * 6, sin(j * 0.5 + p * 14 + i) * (j + 2)))
		_path(tail, 8 - i * 2, color, fade * 0.5)
	_prism(pos, 21, p * 3, fade)
	Shapes.star(self, pos, 5, _ink(accent, fade))


func _mark(pos: Vector2, size: float, p: float, fade: float) -> void:
	var center: Vector2 = pos - Vector2(0, size * 0.6 + sin(p * 7) * 2)
	var r: float = minf(13, size * 0.5)
	var diamond := PackedVector2Array([center + Vector2(-r, 0), center + Vector2(0, -r),
		center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
	_path(diamond, 3, color, fade * 0.8)
	_prism(center, r * 0.8, -1.5, fade)


func _flare(p: float, fade: float) -> void:
	var points: PackedVector2Array = secondary_offsets
	if points.is_empty():
		points = PackedVector2Array([Vector2.ZERO])
	for pos: Vector2 in points.slice(0, 8):
		for i: int in mini(8, particle_budget):
			var a: float = i * TAU / 8.0
			var dist: float = radius * smoothstep(0.12, 0.65, p)
			_prism(pos + Vector2.from_angle(a) * dist, 16 * (1 - p * 0.7), a, fade)
		if p < 0.35:
			_mark(pos, radius * 0.35, p, fade)


func _prism_rain(p: float, fade: float) -> void:
	for i: int in mini(10, particle_budget):
		var age: float = fmod(p * 1.8 + i * 0.173, 1)
		var target := Vector2.from_angle(i * 2.39996) * radius * sqrt((i + 1.0) / 11.0)
		var pos: Vector2 = target + Vector2(-20, -100) * (1 - age)
		_prism(pos, 18, 1.3, fade * sin(age * PI))
		if age > 0.75:
			Shapes.star(self, target, 11 * (1 - age) * 4, _ink(accent, fade * 0.8))


func _bramble(center: Vector2, size: float, p: float, fade: float) -> void:
	var grow: float = smoothstep(0.04, 0.25, p)
	for i: int in mini(6 if detail_level == 1 else 3, particle_budget):
		var a: float = i * 2.39996
		var reach: float = size * (0.5 + i % 3 * 0.2) * grow
		var points := PackedVector2Array()
		for j: int in (10 if detail_level == 1 else 5):
			var t: float = j / (9.0 if detail_level == 1 else 4.0)
			points.append(center + Vector2.from_angle(a + sin(t * 3 + p) * 0.15) * reach * t
				- Vector2(0, sin(t * PI) * 9))
		_path(points, 6, color, fade * 0.8)
		for j: int in (3 if detail_level == 1 else 1):
			var pos: Vector2 = center + Vector2.from_angle(a) * reach * (0.4 + j * 0.23)
			_spark(pos - Vector2(0, 4), 11 * grow, fade, a - 0.7)


func _briar_line(p: float, fade: float) -> void:
	for i: int in 5:
		var center := Vector2(travel_distance * i / 4.0, 0)
		_bramble(center, radius, clampf((p - i * 0.035) / 0.8, 0, 1), fade)


func _bloom(p: float, fade: float) -> void:
	_bramble(Vector2.ZERO, radius, p, fade * 0.7)
	for i: int in mini(5, particle_budget):
		var pos := Vector2.from_angle(i * 2.39996) * radius * (0.25 + i * 0.12)
		var grow: float = smoothstep(0.1, 0.4, p)
		for petal: int in (4 if detail_level == 1 else 2):
			_spark(pos + Vector2.from_angle(petal * TAU / 4) * 7 * grow,
				13 * grow, fade, petal * TAU / 4)
		Shapes.star(self, pos - Vector2(0, p * 18), 3, _ink(WHITE, fade * 0.8))
	for target: Vector2 in secondary_offsets.slice(0, 3):
		_path(PackedVector2Array([Vector2.ZERO, target * 0.5 - Vector2(0, 12), target]), 4, accent, fade * 0.55)


func _chain(p: float, fade: float) -> void:
	if effect_kind == &"electrified":
		for i: int in 3:
			var a: float = p * 7 + i * TAU / 3
			_conduct(Vector2.from_angle(a) * radius * 0.6,
				Vector2.from_angle(a + 0.8) * radius, fade * 0.8)
		return
	var targets: PackedVector2Array = secondary_offsets
	if targets.is_empty():
		targets = PackedVector2Array([Vector2(travel_distance, 0)])
	var start := Vector2.ZERO
	for i: int in targets.size():
		var onset: float = 0.10 + i * 0.05
		var strength: float = fade * smoothstep(onset, onset + 0.08, p)
		_conduct(start, targets[i], strength)
		if strength > 0.01:
			Shapes.star(self, targets[i], 7 * (0.8 + sin(p * 24 + i) * 0.2), _ink(accent, strength))
		start = targets[i]


func _conduct(from: Vector2, to: Vector2, fade: float) -> void:
	if fade <= 0.001 or from.distance_squared_to(to) < 0.01:
		return
	var direction: Vector2 = (to - from).normalized()
	var normal: Vector2 = direction.orthogonal()
	var points := PackedVector2Array()
	for i: int in 11:
		var point: Vector2 = from.lerp(to, i / 10.0)
		if i > 0 and i < 10:
			point += normal * sin(i * 4.9 + floor(_elapsed * 18)) * 7
		points.append(point)
	_path(points, 8, color, fade * 0.7)
	draw_polyline(points, _ink(accent, fade), 1.5)
	if detail_level == 1:
		for i: int in [3, 7]:
			var end: Vector2 = points[i] + direction * 12 + normal * (15 if i == 3 else -12)
			_path(PackedVector2Array([points[i], end + Vector2(-3, 4), end]), 3, accent, fade * 0.6)
		_spark(to, 10, fade, direction.angle())


func _storm(p: float, fade: float) -> void:
	if secondary_offsets.is_empty():
		_mark(Vector2.ZERO, 18, p, fade * 0.6)
		return
	for i: int in 8:
		if i >= secondary_offsets.size():
			break
		var onset: float = 0.16 + i * 0.075
		var age: float = (p - onset) / 0.22
		var pos: Vector2 = secondary_offsets[i]
		if p >= onset - 0.13 and p < onset:
			_mark(pos, 14, p, fade * 0.65)
		if age >= 0 and age < 1:
			_conduct(pos - Vector2(12, 130), pos, fade * (1 - age))
			_prism(pos, 18 * (1 - age), i, fade)


func _jaws(center: Vector2, size: float, p: float, fade: float) -> void:
	var close: float = sin(smoothstep(0.08, 0.75, p) * PI)
	for side: float in [-1, 1]:
		var jaw := PackedVector2Array()
		for i: int in 9:
			var t: float = i / 8.0
			jaw.append(center + Vector2((t - 0.5) * size * 1.7,
				side * (sin(t * PI) * size * 0.5 + 4) * (1 - close * 0.8)))
		_path(jaw, 11, color, fade * 0.8)
		for i: int in (5 if detail_level == 1 else 3):
			var x: float = (i / (4.0 if detail_level == 1 else 2.0) - 0.5) * size * 1.2
			var y: float = side * (size * 0.35 + 4) * (1 - close * 0.8)
			var tooth := PackedVector2Array([center + Vector2(x - 4, y), center + Vector2(x + 4, y),
				center + Vector2(x + 1, y - side * 11)])
			_poly(tooth, _ink(accent, fade * 0.9))


func _feast(p: float, fade: float) -> void:
	for i: int in mini(6 if detail_level == 1 else 2, particle_budget):
		var pos := Vector2.from_angle(i * TAU / 6 + 0.3) * radius * 0.6
		_jaws(pos, radius * 0.24, clampf(p + i * 0.035, 0, 1), fade * 0.75)
	_pit(p, fade * 0.7)


func _pit(p: float, fade: float) -> void:
	var grow: float = smoothstep(0.05, 0.35, p)
	for i: int in mini(8, particle_budget):
		var a: float = i * TAU / 8 + p * 0.5
		var outer := Vector2.from_angle(a) * Vector2(radius, radius * 0.55) * grow
		var inner: Vector2 = outer * (0.12 + (1 - p) * 0.2)
		_path(PackedVector2Array([outer, outer * 0.65 + outer.orthogonal() * 0.18, inner]), 8, color, fade * 0.7)
		_spark(inner, 12 * grow, fade, a + PI)
	_jaws(Vector2.ZERO, radius * 0.45, p, fade)


func _mirrors(p: float, fade: float, count: int) -> void:
	var progress: float = smoothstep(0.08, 0.78, p)
	for i: int in count:
		var angle: float = (i - (count - 1) * 0.5) * 0.18
		var pos := Vector2.from_angle(angle) * travel_distance * progress
		if count == 5 and secondary_offsets.size() >= 5:
			pos = secondary_offsets[i] * progress
			angle = secondary_offsets[i].angle()
		if count == 1 and secondary_offsets.size() >= 2:
			if p < 0.48:
				pos = secondary_offsets[0] * smoothstep(0.08, 0.45, p)
			else:
				pos = secondary_offsets[0].lerp(secondary_offsets[1], smoothstep(0.48, 0.85, p))
		var tail: Vector2 = pos - Vector2.from_angle(angle) * minf(70, travel_distance * progress)
		_path(PackedVector2Array([tail, pos]), 12, color, fade * 0.55)
		_prism(pos, 28, angle, fade)
		if count == 1 and secondary_offsets.size() >= 2 and p > 0.5:
			_path(PackedVector2Array([pos, pos + Vector2(-28, -15)]), 3, accent, fade * 0.45)


func _mirror_guard(p: float, fade: float) -> void:
	var count: int = 6 if detail_level == 1 else 4
	for i: int in count:
		var a: float = i * TAU / count + sin(p * TAU) * 0.08
		var pos := Vector2.from_angle(a) * Vector2(radius * 0.8, radius * 0.65)
		var tangent: Vector2 = Vector2.from_angle(a).orthogonal()
		var outward := Vector2.from_angle(a)
		_poly(PackedVector2Array([pos - tangent * 13, pos + tangent * 13,
			pos + outward * 9]), _ink(color, fade * 0.18))
		_prism(pos, 25, a + PI * 0.5, fade * 0.8)
		if detail_level == 1:
			draw_line(pos - tangent * 10, pos + tangent * 10, _ink(accent, fade * 0.65), 1)
