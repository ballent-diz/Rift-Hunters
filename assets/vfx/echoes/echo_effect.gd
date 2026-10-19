extends Node2D
## Présentation uniquement : le propriétaire du sort fournit positions, rayon et durée réels.
signal visual_finished

const Shapes = preload("res://assets/vfx/hunter/effects_common.gd")
const BRUSH = preload("res://assets/vfx/hunter/cleaving_slash/textures/blade-ribbon.png")
const PAINT = preload("res://assets/vfx/echoes/echo_paint.gdshader")
const Stroke = preload("res://assets/vfx/echoes/painted_stroke.gd")
const WHITE := Color("fff5dd")

@export var echo_id: StringName = &"cinderwing"
@export var effect_kind: StringName = &"feather"
@export var color := Color("f07a2a")
@export var accent := Color("e0c232")
@export_range(4.0, 600.0) var radius: float = 80.0
@export_range(0.1, 30.0) var visual_duration: float = 0.85
@export_range(0.0, 1200.0) var travel_distance: float = 180.0
@export_range(1, 48) var particle_budget: int = 18
@export_range(0, 1) var detail_level: int = 1
@export var destroy_on_finish: bool = true
@export var loop_visual: bool = false
@export var target_shape: StringName = &"area"
var secondary_offsets := PackedVector2Array()
var _elapsed: float = 0.0
var _playing: bool = false
var _releasing: bool = false


func _ready() -> void:
	var paint := ShaderMaterial.new()
	paint.shader = PAINT
	material = paint


func play(direction: Vector2 = Vector2.RIGHT) -> void:
	rotation = direction.angle() if direction.length_squared() > 0.001 else 0.0
	_elapsed = 0.0
	_playing = true
	_releasing = false
	queue_redraw()


## Trajet graphique ; ne jamais l'ajouter à un projectile qui se déplace déjà.
func play_between(from: Vector2, to: Vector2) -> void:
	global_position = from
	travel_distance = from.distance_to(to)
	play(to - from)


func play_from(seconds: float, direction: Vector2 = Vector2.RIGHT) -> void:
	play(direction)
	_elapsed = clampf(seconds, 0.0, duration())
	if material:
		material.set_shader_parameter("effect_time", _elapsed)
	queue_redraw()


## Positions locales, données par C7 après résolution des cibles réelles ; maximum huit liaisons.
func set_secondary_offsets(offsets: PackedVector2Array) -> void:
	secondary_offsets = offsets.slice(0, 8)
	queue_redraw()


func seek_visual(seconds: float) -> void:
	_elapsed = maxf(seconds, 0.0)
	_playing = false
	if material:
		material.set_shader_parameter("effect_time", _elapsed)
	queue_redraw()


func release() -> void:
	_releasing = true
	_elapsed = maxf(_elapsed, duration() - 0.25)
	_playing = true


func duration() -> float:
	return maxf(visual_duration, 0.1)


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if material:
		material.set_shader_parameter("effect_time", _elapsed)
	queue_redraw()
	if _elapsed >= duration():
		if loop_visual and not _releasing:
			_elapsed = fmod(_elapsed, duration())
			return
		_playing = false
		visual_finished.emit()
		if destroy_on_finish:
			queue_free()


func _draw() -> void:
	if _elapsed >= duration():
		return
	var p: float = clampf(_elapsed / duration(), 0.0, 1.0)
	var fade: float = smoothstep(0.0, 0.06, p) * (1.0 - smoothstep(0.80, 1.0, p))
	var strike: float = clampf((p - 0.12) / 0.58, 0.0, 1.0)
	match effect_kind:
		&"indicator": _indicator(fade)
		&"feather": _feather(Vector2(travel_distance * strike, -10), fade, strike)
		&"rain": _rain(p, fade)
		&"dash", &"leap": _dash(p, fade, effect_kind == &"leap")
		&"bite", &"claw", &"antler", &"ram": _melee(p, fade)
		&"flow", &"lava": _lava(p, fade, effect_kind == &"flow")
		&"geyser": _geyser(p, fade)
		&"flame", &"projectile", &"burn": _flame(p, fade)
		&"implode", &"implosion_mark": _implode(p, fade)
		&"spore", &"cloud", &"spores": _spores(p, fade)
		&"bud": _bud(p, fade)
		&"gravity": _gravity(p, fade)
		&"meteor": _meteor(p, fade)
		&"grove", &"heal": _grove(p, fade)
		&"thorns": _thorns(p, fade)
		&"cone", &"blind": _solar(p, fade)
		&"dust", &"swarm", &"powder", &"speed": _moths(p, fade)
		&"dome", &"wave", &"conductive_shield": _electric(p, fade)


## Polygone plein, ignoré s'il est dégénéré (surface nulle au début d'une croissance) ou invisible.
func _poly(points: PackedVector2Array, ink: Color) -> void:
	if ink.a <= 0.001 or points.size() < 3:
		return
	var area: float = 0.0
	for i: int in points.size():
		area += points[i].cross(points[(i + 1) % points.size()])
	if absf(area) > 0.5:
		draw_colored_polygon(points, ink)


func _ink(ink: Color, opacity: float) -> Color:
	return Color(ink, clampf(opacity, 0.0, 1.0))


func _path(points: PackedVector2Array, width: float, ink: Color, fade: float) -> void:
	if detail_level == 0:
		if points.size() > 1 and fade > 0.003:
			draw_polyline(points, _ink(ink.lerp(accent, 0.3), fade), maxf(1.5, width * 0.75), false)
		return
	Stroke.stroke(self, points, width, ink, accent, fade, BRUSH if detail_level == 1 else null)


func _spark(center: Vector2, size: float, fade: float, angle: float = 0.0) -> void:
	size *= 1.25
	if detail_level == 0:
		var along := Vector2.from_angle(angle) * size * 0.5
		var across: Vector2 = along.orthogonal() * 0.4
		_poly(PackedVector2Array([center - along, center + across,
			center + along, center - across]), _ink(accent, fade))
		return
	Shapes.facet(self, center, angle, size, size * 0.4, color, accent, fade)


func _quill(pos: Vector2, length: float, width: float, angle: float, fade: float) -> void:
	if fade <= 0.001:
		return
	var tip: Vector2 = pos + Vector2(length * 0.6, 0).rotated(angle)
	var tail: Vector2 = pos - Vector2(length * 0.5, 0).rotated(angle)
	var top: Vector2 = pos + Vector2(-length * 0.1, -width * 0.55).rotated(angle)
	var bottom: Vector2 = pos + Vector2(-length * 0.2, width * 0.45).rotated(angle)
	_poly(PackedVector2Array([tail, top, tip]), _ink(color, fade))
	_poly(PackedVector2Array([tail, bottom, tip]), _ink(color.darkened(0.3), fade))
	draw_line(tail, tip, _ink(accent, fade), 1.2)
	if detail_level == 0:
		return
	for i: int in 4:
		var start: Vector2 = tail.lerp(tip, 0.3 + i * 0.14)
		var barb := Vector2(-length * 0.12, width * (0.40 - i * 0.07))
		draw_line(start, start + barb.rotated(angle), _ink(accent, fade * 0.7), 1.0)
		draw_line(start, start + Vector2(barb.x, -barb.y).rotated(angle), _ink(WHITE, fade * 0.45), 1.0)


func _scatter(p: float, fade: float, count: int = 14, reach: float = -1.0) -> void:
	if fade <= 0.001:
		return
	Shapes.burst(self, Vector2.ZERO, p, 1.0, mini(count, particle_budget),
		radius if reach < 0.0 else reach, color, accent)


func _indicator(fade: float) -> void:
	var pulse: float = 0.75 + 0.15 * sin(_elapsed * 5.0)
	var ink: Color = _ink(accent, fade * pulse)
	match target_shape:
		&"line":
			for side: float in [-1.0, 1.0]:
				draw_line(Vector2(0, side * radius * 0.2), Vector2(travel_distance, side * radius * 0.2), ink, 1.5)
			Shapes.star(self, Vector2(travel_distance, 0), 7.0, ink)
		&"cone":
			for side: float in [-1.0, 1.0]:
				draw_line(Vector2.ZERO, Vector2.from_angle(side * 0.55) * radius, ink, 1.5)
			Shapes.ring(self, Vector2.ZERO, radius, ink, 1.5, -0.55, 0.55)
		_:
			for i: int in 8:
				Shapes.ring(self, Vector2.ZERO, radius, ink, 1.5, i * TAU / 8.0, (i + 0.7) * TAU / 8.0)
			for i: int in 4:
				var pos := Vector2.from_angle(i * PI * 0.5) * radius
				draw_line(pos * 0.94, pos * 1.06, ink, 2.0)


func _feather(pos: Vector2, fade: float, p: float) -> void:
	var points := PackedVector2Array()
	for i: int in 9:
		points.append(pos - Vector2(i * 6.0, sin(p * 12.0 - i * 0.5) * i))
	_path(points, 17.0, color, fade * 0.85)
	_quill(pos, 46.0, 22.0, 0.0, fade)
	draw_line(pos - Vector2(12, 0), pos + Vector2(14, 0), _ink(WHITE, fade), 1.5)


func _rain(p: float, fade: float) -> void:
	for i: int in mini(12, particle_budget):
		var phase: float = fmod(p * 2.0 + i * 0.137, 1.0)
		var base := Vector2.from_angle(i * 2.39996) * radius * sqrt((i + 1.0) / 13.0)
		var pos: Vector2 = base + Vector2(12, -105) * (1.0 - phase)
		_path(PackedVector2Array([pos - Vector2(5, -24), pos]), 7, color, fade * sin(phase * PI) * 0.8)
		_quill(pos, 38.0, 17.0, 1.8, fade * sin(phase * PI))
		if phase > 0.7:
			Shapes.star(self, base, 8.0 * (1.0 - phase) * 3.0, _ink(accent, fade * 0.7))


func _dash(p: float, fade: float, leap: bool) -> void:
	var pos := Vector2(travel_distance * smoothstep(0.12, 0.70, p), 0)
	if leap:
		pos.y -= sin(clampf((p - 0.12) / 0.58, 0, 1) * PI) * radius * 0.6
	var points := PackedVector2Array()
	for i: int in 14:
		var x: float = maxf(0.0, pos.x - i * 8.0)
		points.append(Vector2(x, pos.y + sin(i * 0.7 + p * 12) * i * 0.5))
	_path(points, 28.0, color, fade * 0.9)
	for i: int in 3:
		_spark(pos + Vector2(-i * 7, (i - 1) * 9), 34.0 - i * 6, fade, -0.3)
	if echo_id == &"cinderwing":
		_bolt(pos - Vector2(45, 12), pos + Vector2(15, -8), fade)


func _melee(p: float, fade: float) -> void:
	var tip: float = lerpf(-1.0, 1.0, smoothstep(0.12, 0.6, p))
	if effect_kind == &"ram":
		var pos := Vector2(radius * smoothstep(0.10, 0.5, p), 0)
		for i: int in 4:
			Shapes.facet(self, pos + Vector2(-i * 8, (i % 2 - 0.5) * 13), 0.0,
				24 - i * 3, 15, color, accent, fade)
		if echo_id == &"stormshell":
			_bolt(pos - Vector2(28, 18), pos + Vector2(14, 13), fade)
		else:
			Shapes.ring(self, pos, 24, _ink(accent, fade), 1.5, -2.7, 1.8)
		_scatter(maxf(0, p - 0.25), fade, 8, radius * 0.6)
		return
	if effect_kind == &"antler":
		for side: float in [-1.0, 1.0]:
			var pos := Vector2(radius * smoothstep(0.1, 0.5, p), side * 13)
			_path(PackedVector2Array([Vector2(0, side * 4), pos]), 7, color, fade)
			_spark(pos, 22, fade, -side * 0.3)
			_spark(pos + Vector2(-15, side * 9), 12, fade, -side * 0.5)
		return
	if effect_kind == &"bite":
		for side: float in [-1.0, 1.0]:
			var jaw := PackedVector2Array()
			for i: int in 8:
				var t: float = i / 7.0
				jaw.append(Vector2(t * radius, side * (1 - t) * 24 * (1 - p)))
			_path(jaw, 15, color, fade)
			for tooth: int in (4 if detail_level == 1 else 2):
				var center := Vector2(radius * (0.35 + tooth * 0.15), side * 12 * (1 - p))
				_poly(PackedVector2Array([center + Vector2(-6, 0), center + Vector2(6, 0),
					center - Vector2(0, side * 12)]), _ink(accent, fade))
		_spark(Vector2(radius, 0), 18, fade)
		return
	for j: int in 3:
		var points := PackedVector2Array()
		for i: int in 12:
			var a: float = tip - i * 0.13
			points.append(Vector2.from_angle(a) * (radius - j * 9.0))
		_path(points, 16.0 - j * 3.0, accent if j == 0 else color, fade * (1.0 - j * 0.12))
	_scatter(maxf(0, p - 0.25) * 1.2, fade, 9, radius * 0.6)


func _lava(p: float, fade: float, flowing: bool) -> void:
	var count: int = 8 if flowing else 5
	if detail_level == 0:
		count = 4 if flowing else 2
	for i: int in count:
		var pos := Vector2(i * travel_distance / count, sin(i * 1.9) * 10) if flowing else Vector2.ZERO
		var grow: float = smoothstep(i * 0.045, i * 0.045 + 0.2, p)
		var points := PackedVector2Array()
		for j: int in 12:
			var a: float = j * TAU / 12.0
			points.append(pos + Vector2.from_angle(a) * radius * 0.3 * grow * (0.85 + sin(j * 2 + i) * 0.15))
		_poly(points, _ink(Color("312934"), fade * 0.48))
		var molten := PackedVector2Array()
		for point: Vector2 in points:
			molten.append(pos + (point - pos) * 0.78)
		_poly(molten, _ink(color, fade * grow * 0.65))
		for j: int in 3:
			var start: Vector2 = pos + Vector2.from_angle(j * 2.1 + i) * radius * 0.08
			_path(PackedVector2Array([start, start * 0.4 + pos * 0.6 + Vector2(radius * 0.18, 4)]),
				6.0, accent, fade * grow)
		_spark(pos + Vector2(0, -8 - sin(p * 9 + i) * 7), 6, fade * 0.6, -1.5)


func _geyser(p: float, fade: float) -> void:
	var lift: float = sin(clampf((p - 0.08) / 0.78, 0.0, 1.0) * PI)
	for i: int in (5 if detail_level == 1 else 3):
		var points := PackedVector2Array()
		for j: int in 10:
			var t: float = j / 9.0
			points.append(Vector2((i - 2) * 9.0 * t, -radius * 1.4 * lift * sin(t * PI * 0.6)))
		_path(points, 22.0 - absf(i - 2) * 4, color if i != 2 else accent, fade)
	_scatter(p, fade, 14, radius * 0.8)


func _flame(p: float, fade: float) -> void:
	var pos := Vector2(travel_distance * smoothstep(0.10, 0.85, p), -10)
	if not secondary_offsets.is_empty():
		var progress: float = smoothstep(0.10, 0.85, p) * secondary_offsets.size()
		var segment: int = mini(int(progress), secondary_offsets.size() - 1)
		var start: Vector2 = Vector2.ZERO if segment == 0 else secondary_offsets[segment - 1]
		pos = start.lerp(secondary_offsets[segment], clampf(progress - segment, 0, 1))
	for i: int in 4:
		var tail := PackedVector2Array()
		for j: int in 9:
			tail.append(pos + Vector2(-j * 5.0, sin(j * 0.6 + p * 17 + i) * (j + 2) + (i - 2) * 3))
		_path(tail, 17.0 - i * 2, color, fade * 0.8)
	var flame := PackedVector2Array([
		pos + Vector2(18, 0), pos + Vector2(2, -11), pos + Vector2(-16, -9),
		pos + Vector2(-9, -3), pos + Vector2(-27, 1), pos + Vector2(-11, 5),
		pos + Vector2(-19, 13), pos + Vector2(3, 10)])
	for i: int in flame.size():
		flame[i] = pos + (flame[i] - pos) * 1.4
	_poly(flame, _ink(color, fade * 0.98))
	var core := PackedVector2Array([pos + Vector2(8, 0), pos + Vector2(-2, -6),
		pos + Vector2(-14, -3), pos + Vector2(-7, 0), pos + Vector2(-14, 5), pos + Vector2(-1, 6)])
	_poly(core, _ink(Color("252934"), fade * 0.9))
	Shapes.star(self, pos + Vector2(6, -2), 5, _ink(WHITE, fade))


func _implode(p: float, fade: float) -> void:
	var r: float = radius * (1.0 - smoothstep(0.1, 0.72, p))
	for i: int in mini(18, particle_budget):
		var a: float = i * TAU / 18.0 + p * 0.8
		var pos := Vector2.from_angle(a) * (r + 8)
		_spark(pos, 16 + p * 12, fade, a + PI)
		if i % 3 == 0:
			_path(PackedVector2Array([pos * 1.1, pos + pos.orthogonal() * 0.2, pos * 0.5]),
				8, color, fade * 0.75)
		draw_line(pos, pos + Vector2.from_angle(a) * 14, _ink(color, fade * 0.4), 1.0)
	if p > 0.6:
		Shapes.star(self, Vector2.ZERO, radius * 0.26 * sin((p - 0.6) / 0.4 * PI), _ink(color, fade))


func _spores(p: float, fade: float) -> void:
	var spread: float = 0.3 + smoothstep(0.1, 0.75, p) * 0.7
	var center := Vector2(travel_distance * p, 0) if effect_kind == &"spore" else Vector2.ZERO
	for i: int in mini(22, particle_budget):
		var pos: Vector2 = center + Vector2.from_angle(i * 2.39996 + p * 0.3) * radius * spread * sqrt((i + 1.0) / 23.0)
		pos.y -= 8 + sin(p * 8 + i) * 6
		var swell: float = 5.5 + sin(p * 7 + i) * 1.5
		_poly(PackedVector2Array([pos + Vector2(-swell, 1), pos + Vector2(-swell * 0.7, -swell),
			pos + Vector2(swell * 0.4, -swell * 1.2), pos + Vector2(swell, 0),
			pos + Vector2(0, swell * 0.6)]), _ink(color, fade * 0.85))
		draw_line(pos + Vector2(-1, -2), pos + Vector2(1, -2), _ink(WHITE, fade), 1.0)
		draw_line(pos + Vector2(0, 5), pos + Vector2(2, 12), _ink(accent, fade * 0.35), 1.0)


func _bud(p: float, fade: float) -> void:
	var grow: float = smoothstep(0.0, 0.25, p)
	for i: int in 5:
		var a: float = i * TAU / 5.0
		_spark(Vector2.from_angle(a) * 14 * grow, 24 * grow, fade, a)
	draw_line(Vector2(0, 0), Vector2(0, -23 * grow), _ink(accent, fade), 4.0)
	Shapes.facet(self, Vector2(0, -28 * grow), -PI * 0.5, 36 * grow, 30 * grow, color, accent, fade)
	if p > 0.65:
		_spores((p - 0.65) / 0.35, fade)


func _gravity(p: float, fade: float) -> void:
	for i: int in mini(12, particle_budget):
		var a: float = i * TAU / 12.0 + p * 4.0
		var r: float = radius * (0.25 + fmod(i * 0.137 + 1 - p, 1.0) * 0.75)
		_spark(Vector2.from_angle(a) * Vector2(r, r * 0.6), 17 + i % 3 * 4, fade, a)
		var points := PackedVector2Array()
		for j: int in 8:
			points.append(Vector2.from_angle(a - j * 0.08) * Vector2(r + j * 2, (r + j * 2) * 0.6))
		_path(points, 7.0, accent, fade * 0.7)


func _meteor(p: float, fade: float) -> void:
	if p < 0.52:
		var pos := Vector2(60, -150) * (1.0 - p / 0.52)
		_path(PackedVector2Array([pos, pos + Vector2(30, -70)]), 30, accent, fade * 0.9)
		Shapes.facet(self, pos, -1.1, 52, 40, color, accent, fade)
	else:
		Shapes.burst(self, Vector2.ZERO, p - 0.52, 0.48, mini(18, particle_budget), radius, color, accent)
		for i: int in 6:
			var a: float = i * TAU / 6.0
			draw_line(Vector2.from_angle(a) * 12, Vector2.from_angle(a) * radius * (p - 0.45), _ink(accent, fade), 2)


func _grove(p: float, fade: float) -> void:
	for i: int in mini(7 if detail_level == 1 else 2, particle_budget):
		var pos := Vector2.from_angle(i * 2.39996) * radius * (0.35 + i * 0.08)
		var height: float = 34 * smoothstep(i * 0.018, 0.35, p)
		_path(PackedVector2Array([pos, pos - Vector2(4, height * 0.5), pos - Vector2(0, height)]),
			7, color, fade * 0.85)
		if detail_level == 1:
			Shapes.facet(self, pos - Vector2(0, height), -1.57, 24, 13, color, accent, fade)
			Shapes.facet(self, pos - Vector2(7, height * 0.5), -2.4, 20, 10, color, accent, fade * 0.9)
		else:
			_spark(pos - Vector2(0, height), 12, fade, -1.57)
	for offset: Vector2 in secondary_offsets:
		_path(PackedVector2Array([Vector2.ZERO, offset * 0.5 + Vector2(0, -10), offset]), 7, accent, fade * 0.75)
	_scatter(p * 0.6, fade, 8, radius * 0.65)


func _thorns(p: float, fade: float) -> void:
	var steps: int = 18 if detail_level == 1 else 9
	for side: float in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for i: int in steps:
			var a: float = -PI * 0.5 + i * PI / float(steps - 1)
			var pos := Vector2(side * cos(a) * radius * 0.6, sin(a) * radius * 0.75)
			points.append(pos)
			if i % 3 == 0 and (detail_level == 1 or i in [3, 6]):
				_spark(pos * 1.08, 20, fade, pos.angle())
		_path(points, 11, color, fade * smoothstep(0, 0.25, p))


func _solar(p: float, fade: float) -> void:
	var reach: float = radius * smoothstep(0.08, 0.5, p)
	for i: int in 7:
		var a: float = (i - 3) * 0.15
		var points := PackedVector2Array([Vector2.from_angle(a) * reach * 0.2, Vector2.from_angle(a) * reach])
		_path(points, 17 - absf(i - 3) * 3, color if i % 2 else accent, fade * 0.9)
		_spark(Vector2.from_angle(a) * reach, 10, fade, a)


func _moths(p: float, fade: float) -> void:
	for i: int in mini(16, particle_budget):
		var a: float = i * 2.39996 + p * 2.0
		var dist: float = radius * (0.3 + i * 0.04)
		var pos := Vector2.from_angle(a) * Vector2(dist, dist * 0.65)
		pos.y -= 8 + sin(p * 12 + i) * 8
		if effect_kind == &"dust":
			pos.x += travel_distance * p
		Shapes.star(self, pos, 6 + i % 2, _ink(color, fade * 0.9))
		var wing: float = 6 + sin(p * 35 + i) * 3
		for side: float in [-1, 1]:
			_poly(PackedVector2Array([pos, pos + Vector2(side * wing, -6),
				pos + Vector2(side * wing * 0.8, 3)]), _ink(accent, fade * 0.85))
		if effect_kind == &"speed" or effect_kind == &"powder":
			draw_line(pos - Vector2(9, 0), pos, _ink(color, fade * 0.4), 1)


func _bolt(from: Vector2, to: Vector2, fade: float) -> void:
	var points := PackedVector2Array()
	for i: int in 9:
		var pos: Vector2 = from.lerp(to, i / 8.0)
		if i > 0 and i < 8:
			pos += (to - from).normalized().orthogonal() * sin(i * 5.0 + floor(_elapsed * 18)) * 6.0
		points.append(pos)
	_path(points, 8, color, fade * 0.9)
	draw_polyline(points, _ink(accent, fade), 2.5)


func _electric(p: float, fade: float) -> void:
	var r: float = radius * (0.2 + p * 0.8) if effect_kind == &"wave" else radius
	var segments: int = 6 if detail_level == 1 else 4
	for i: int in segments:
		var a: float = i * TAU / segments
		var b: float = (i + 1) * TAU / segments
		var start := Vector2.from_angle(a) * Vector2(r, r * 0.7)
		var end := Vector2.from_angle(b) * Vector2(r, r * 0.7)
		_bolt(start, end, fade * 0.8)
		if effect_kind != &"wave" and (detail_level == 1 or i % 2 == 0):
			_bolt(start, Vector2(start.x * 0.4, -radius * 0.85), fade * 0.45)
	for offset: Vector2 in secondary_offsets:
		_bolt(Vector2.ZERO, offset, fade)
