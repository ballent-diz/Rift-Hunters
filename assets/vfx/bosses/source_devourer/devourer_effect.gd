extends Node2D
## Dessin autonome uniquement : aucune cible, collision, apparition ou résolution de dégâts.
signal visual_finished

const Stroke = preload("res://assets/vfx/echoes/painted_stroke.gd")
const Shapes = preload("res://assets/vfx/hunter/effects_common.gd")
const Brush = preload("res://assets/vfx/hunter/cleaving_slash/textures/blade-ribbon.png")
const Paint = preload("res://assets/vfx/echoes/echo_paint.gdshader")
const VOID := Color("9963c9")
const LIGHT := Color("eee3f4")
const INK := Color("292031")
const STONE := Color("727568")
const MOSS := Color("708651")
const WARNING := Color("ef9475")

@export var effect_kind: StringName = &"claw"
@export var radius: float = 150.0
@export var travel_distance: float = 420.0
@export var width: float = 70.0
@export var visual_duration: float = 0.85
@export var half_angle_degrees: float = 45.0
@export_range(1, 32) var particle_budget: int = 20
@export_range(0, 1) var detail_level: int = 1
@export var phase2: bool = false
@export var target_shape: StringName = &"area"
@export var destroy_on_finish: bool = true
@export var loop_visual: bool = false
var secondary_offsets := PackedVector2Array()
var _elapsed: float = 0.0
var _playing: bool = false
var _releasing: bool = false


func _ready() -> void:
	z_index = 1
	var paint := ShaderMaterial.new()
	paint.shader = Paint
	material = paint


func duration() -> float:
	return maxf(visual_duration, 0.1)


func play(direction: Vector2 = Vector2.RIGHT) -> void:
	rotation = direction.angle() if direction.length_squared() > 0.001 else 0.0
	_elapsed = 0.0
	_playing = true
	_releasing = false
	queue_redraw()


func play_from(seconds: float, direction: Vector2 = Vector2.RIGHT) -> void:
	play(direction)
	_elapsed = clampf(seconds, 0.0, duration())
	queue_redraw()


func seek_visual(seconds: float) -> void:
	_elapsed = clampf(seconds, 0.0, duration())
	_playing = false
	if material:
		material.set_shader_parameter("effect_time", _elapsed)
	queue_redraw()


func set_secondary_offsets(points: PackedVector2Array) -> void:
	secondary_offsets = points.slice(0, 8)
	queue_redraw()


func release() -> void:
	_releasing = true
	loop_visual = false
	_elapsed = maxf(_elapsed, duration() - 0.22)
	_playing = true


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if material:
		material.set_shader_parameter("effect_time", _elapsed)
	queue_redraw()
	if _elapsed < duration():
		return
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
	var p: float = _elapsed / duration()
	var fade: float = smoothstep(0.0, 0.07, p) * (1.0 - smoothstep(0.68, 1.0, p))
	match effect_kind:
		&"indicator": _indicator(p)
		&"claw": _claw(p, fade)
		&"heavy_slam": _slam(p, fade)
		&"rift_breath": _breath(p, fade)
		&"summon": _summon(p, fade)
		&"root_sweep": _roots(p, fade)
		&"transform": _transform(p, fade)
		&"roar": _roar(p, fade)
		&"hurt": _burst(p, 0.5, 12, radius, STONE, LIGHT)
		&"death": _burst(p, duration(), particle_budget, radius, INK, STONE)
		&"rift_fragment": _fragment(p, fade)


func _stroke(points: PackedVector2Array, size: float, ink: Color, light: Color, fade: float) -> void:
	Stroke.stroke(self, points, size, ink, light, fade, Brush)


func _burst(p: float, life: float, count: int, reach: float, ink: Color, light: Color) -> void:
	Shapes.burst(self, Vector2.ZERO, p * life, life, clampi(mini(count, particle_budget), 1, 32), reach, ink, light, 0.17)


func _claw(p: float, fade: float) -> void:
	var sweep: float = clampf((p - 0.12) / 0.58, 0.0, 1.0)
	if sweep <= 0.0:
		return
	var half: float = deg_to_rad(half_angle_degrees)
	for finger: int in 3:
		var points := PackedVector2Array()
		for i: int in 15:
			var t: float = float(i) / 14.0
			var angle: float = lerpf(-half, -half + sweep * half * 2.0, t)
			points.append(Vector2.from_angle(angle) * (radius - 16.0 - finger * 16.0))
		_stroke(points, (27.0 if phase2 else 21.0) * (1.0 - finger * 0.14), INK, VOID, fade * 0.9)
		_stroke(points, 5.0, VOID, LIGHT, fade)
	Shapes.burst(self, Vector2(radius * 0.7, 0), maxf(p - 0.30, 0.0), 0.65,
		mini(12, particle_budget), radius * 0.38, STONE, LIGHT)


func _slam(p: float, fade: float) -> void:
	var contact: float = clampf((p - 0.30) / 0.60, 0.0, 1.0)
	if contact <= 0.0:
		return
	var reach: float = radius * (1.0 - pow(1.0 - contact, 3.0))
	for i: int in (12 if phase2 else 8):
		var angle: float = float(i) * 2.39996
		var axis := Vector2.from_angle(angle)
		var side := axis.orthogonal()
		var points := PackedVector2Array([axis * 12.0, axis * reach * 0.38 + side * 9.0,
			axis * reach * 0.67 - side * 8.0, axis * reach])
		_stroke(points, 9.0 * fade, INK, STONE, fade * 0.8)
		if i % 2 == 0:
			_stroke(points, 2.2, VOID, LIGHT, fade * 0.65)
	Shapes.burst(self, Vector2.ZERO, contact * 0.65, 0.65, mini(particle_budget, 28),
		radius * 0.68, STONE, Color("b6b6a0"), 0.42)
	for shard: int in mini(particle_budget, 10):
		var angle: float = shard * 2.39996
		var point: Vector2 = Vector2.from_angle(angle) * reach * (0.35 + float(shard % 3) * 0.15)
		point.y -= sin(contact * PI) * (12.0 + shard * 2.0)
		Shapes.facet(self, point, angle + contact, 21.0 + shard, 13.0 + shard * 0.7,
			INK, STONE, fade * 0.85)


func _breath(p: float, fade: float) -> void:
	var reach: float = travel_distance * clampf((p - 0.12) / 0.35, 0.0, 1.0)
	if reach < 1.0:
		return
	for stream: int in (7 if phase2 else 5):
		var count: float = 6.0 if phase2 else 4.0
		var fraction: float = float(stream) / count - 0.5
		var stream_reach: float = reach * (0.80 + float(stream % 3) * 0.08)
		var points := PackedVector2Array()
		for i: int in 21:
			var t: float = float(i) / 20.0
			var spread: float = fraction * width * (0.12 + t * 0.48)
			var ripple: float = sin(t * 18.0 - p * 22.0 + stream) * width * 0.04 * t
			points.append(Vector2(t * stream_reach, spread + ripple))
		_stroke(points, width * 0.16, INK, VOID, fade * 0.62)
		_stroke(points, 2.5 if stream % 2 else 4.0, VOID, LIGHT, fade * 0.78)
		Shapes.facet(self, points[20], sin(p * 8.0 + stream) * 0.3, 19.0, 5.0,
			VOID, LIGHT, fade * 0.75)
	Shapes.burst(self, Vector2(reach, 0), p, 1.0, mini(particle_budget, 12), width * 0.5, VOID, LIGHT)


func _roots(p: float, fade: float) -> void:
	var grow: float = clampf((p - 0.12) / 0.48, 0.0, 1.0)
	var half: float = deg_to_rad(half_angle_degrees)
	for root: int in 5:
		var angle: float = lerpf(-half * 0.68, half * 0.68, float(root) / 4.0)
		var points := PackedVector2Array()
		for i: int in 19:
			var t: float = float(i) / 18.0
			var axis := Vector2.from_angle(angle + sin(t * PI) * 0.20)
			points.append(axis * radius * grow * t + axis.orthogonal() * sin(t * 11 + root) * 7.0 * t)
		_stroke(points, 25.0 * (1.0 - root * 0.08), INK, STONE, fade * 0.9)
		_stroke(points, 4.0, MOSS, VOID, fade * 0.7)
		for knot: int in 3:
			Shapes.facet(self, points[5 + knot * 4], angle + knot * 0.4, 12.0, 7.0, INK, MOSS, fade * 0.65)
		if points.size() > 12:
			var tip: Vector2 = points[12] + Vector2.from_angle(angle + 0.9) * 27.0 * grow
			_stroke(PackedVector2Array([points[9], points[12], tip]), 5.0, INK, MOSS, fade)


func _summon(p: float, fade: float) -> void:
	var points := secondary_offsets.slice(0, 8)
	if points.is_empty():
		points = PackedVector2Array([Vector2.ZERO])
	for pos: Vector2 in points:
		for strand: int in 4:
			var path := PackedVector2Array()
			for i: int in 13:
				var t: float = float(i) / 12.0
				var angle: float = strand * PI * 0.5 + t * 2.4 + p * 1.4
				path.append(pos + Vector2.from_angle(angle) * radius * (1.0 - t) * 0.65
					+ Vector2(0, -t * radius * 0.7 * sin(p * PI)))
			_stroke(path, 5.0, INK, VOID, fade * 0.7)
		Shapes.star(self, pos + Vector2(0, -radius * 0.28), 8.0 * sin(p * PI), LIGHT)


func _transform(p: float, fade: float) -> void:
	for i: int in 8:
		var axis := Vector2.from_angle(float(i) * TAU / 8.0)
		var reach: float = radius * (0.28 + p * 0.5)
		var points := PackedVector2Array([Vector2(0, -50), Vector2(0, -50) + axis * reach * 0.45,
			Vector2(0, -50) + axis * reach + axis.orthogonal() * sin(i * 2.1 + p * 13) * 10.0])
		_stroke(points, 6.0, INK, VOID, fade * 0.7)
		Shapes.facet(self, points[2], i * 1.3 + p, 10.0 + i, 7.0, STONE, MOSS, fade)
	Shapes.burst(self, Vector2(0, -40), maxf(p - 0.20, 0.0), 0.80,
		mini(particle_budget, 24), radius * 0.65, STONE, LIGHT, 0.5)


func _roar(p: float, fade: float) -> void:
	for pulse: int in 3:
		var expansion: float = fposmod(p * 1.8 + float(pulse) * 0.22, 1.0)
		var points := PackedVector2Array()
		for i: int in 13:
			var angle: float = lerpf(-0.8, 0.8, float(i) / 12.0)
			points.append(Vector2.from_angle(angle) * radius * (0.2 + expansion * 0.8))
		_stroke(points, 3.0, INK, VOID, fade * (1.0 - expansion) * 0.7)


func _fragment(p: float, fade: float) -> void:
	var point := Vector2(travel_distance * p, 0)
	Shapes.facet(self, point, -0.3 + p, width * 0.8, width * 0.35, STONE, VOID, fade)
	_stroke(PackedVector2Array([point - Vector2(width * 1.1, 0), point]), width * 0.18, INK, LIGHT, fade)


func _indicator(p: float) -> void:
	var strength: float = 0.6 + sin(p * PI * 5.0) * 0.14
	var edge := Color(WARNING, strength)
	var dark := Color(INK, 0.85)
	if target_shape == &"line":
		var rect := Rect2(0, -width * 0.5, travel_distance, width)
		draw_rect(rect, Color(WARNING, 0.055), true)
		draw_rect(rect, dark, false, 6.0)
		draw_rect(rect, edge, false, 2.0)
		for i: int in 6:
			var x: float = (float(i) + 0.5) * travel_distance / 6.0
			draw_polyline(PackedVector2Array([Vector2(x - 9, -7), Vector2(x, 0), Vector2(x - 9, 7)]), edge, 2.0)
	elif target_shape == &"cone":
		var half: float = deg_to_rad(half_angle_degrees)
		var left := Vector2.from_angle(-half) * radius
		var right := Vector2.from_angle(half) * radius
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, left, right]), Color(WARNING, 0.055))
		draw_line(Vector2.ZERO, left, dark, 6.0)
		draw_line(Vector2.ZERO, right, dark, 6.0)
		draw_line(Vector2.ZERO, left, edge, 2.0)
		draw_line(Vector2.ZERO, right, edge, 2.0)
		draw_arc(Vector2.ZERO, radius, -half, half, 32, edge, 2.0)
	else:
		for i: int in 16:
			var start: float = float(i) * TAU / 16.0
			draw_arc(Vector2.ZERO, radius, start, start + TAU / 21.0, 5, dark, 6.0)
			draw_arc(Vector2.ZERO, radius, start, start + TAU / 21.0, 5, edge, 2.0)
		# Charge discrète, sans disque plein ni halo sous les personnages.
		draw_arc(Vector2.ZERO, radius * 0.92, -PI * 0.5, -PI * 0.5 + TAU * p, 48, Color(WARNING, 0.45), 1.5)
