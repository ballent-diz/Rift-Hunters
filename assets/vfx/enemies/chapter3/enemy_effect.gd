extends Node2D
## Présentation autonome : le combat fournit les points, dimensions et événements confirmés.
## Aucune collision, cible, apparition, altération ou résolution de dégâts ici.
signal visual_finished

const Stroke = preload("res://assets/vfx/echoes/painted_stroke.gd")
const Shapes = preload("res://assets/vfx/hunter/effects_common.gd")
const INK := Color("102833")
const WARNING := Color("f19983")
const WHITE := Color("ecfff7")
const ROOT := Color("565d39")

@export var effect_kind: StringName = &"splash"
@export var color := Color("40c6bd")
@export var accent := Color("c9f2ed")
@export var radius: float = 80.0
@export var width: float = 24.0
@export var travel_distance: float = 240.0
@export var visual_duration: float = 0.8
@export var half_angle_degrees: float = 40.0
@export var target_shape: StringName = &"area"
@export_range(0, 32) var particle_budget: int = 16
@export var loop_visual: bool = false
@export var destroy_on_finish: bool = true
var secondary_offsets := PackedVector2Array()
var path_points := PackedVector2Array()
var facet_strengths := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
var strength: float = 1.0
var stage: float = 0.0
var _elapsed: float = 0.0
var _playing: bool = false
var _releasing: bool = false
var _release_age: float = 0.0
var _finished: bool = false
var _visible_time: bool = false


func _ready() -> void:
	z_index = 100 if effect_kind == &"indicator" else 1


func duration() -> float:
	return maxf(visual_duration, 0.05)


func play(direction: Vector2 = Vector2.RIGHT) -> void:
	rotation = direction.angle() if direction.length_squared() > 0.0001 else 0.0
	_elapsed = 0.0
	_release_age = 0.0
	_releasing = false
	_finished = false
	_visible_time = true
	_playing = true
	queue_redraw()


func play_from(seconds: float, direction: Vector2 = Vector2.RIGHT) -> void:
	play(direction)
	_elapsed = clampf(seconds, 0.0, duration())
	queue_redraw()


func seek_visual(seconds: float) -> void:
	_elapsed = clampf(seconds, 0.0, duration())
	_playing = false
	_releasing = false
	_finished = false
	_visible_time = true
	queue_redraw()


## Points LOCAUX déjà tronqués/réfléchis par le combat ; aucune recherche d'obstacle ici.
func set_path_local(points: PackedVector2Array) -> void:
	path_points = points.slice(0, 64)
	queue_redraw()


func set_secondary_offsets(points: PackedVector2Array) -> void:
	secondary_offsets = points.slice(0, 8)
	queue_redraw()


## Intensité d'armure et stade de durcissement fournis par les données de jeu.
func set_visual_state(value: float, hardening: float = 0.0) -> void:
	strength = clampf(value, 0.0, 1.0)
	stage = clampf(hardening, 0.0, 1.0)
	queue_redraw()


func set_facet_strengths(values: PackedFloat32Array) -> void:
	for i: int in 4:
		facet_strengths[i] = clampf(values[i], 0.0, 1.0) if i < values.size() else 0.0
	queue_redraw()


func release() -> void:
	if _finished or _releasing:
		return
	_releasing = true
	_release_age = 0.0
	_playing = true


func _process(delta: float) -> void:
	if not _playing or _finished:
		return
	_elapsed += maxf(delta, 0.0)
	if _releasing:
		_release_age += maxf(delta, 0.0)
		if _release_age >= 0.22:
			_finish()
	elif _elapsed >= duration() and not loop_visual:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_playing = false
	_visible_time = false
	visual_finished.emit()
	if destroy_on_finish:
		queue_free()


func _draw() -> void:
	if not _visible_time or _finished:
		return
	var p: float = fposmod(_elapsed, duration()) / duration() if loop_visual else clampf(_elapsed / duration(), 0.0, 1.0)
	var fade: float = 1.0 if loop_visual else 1.0 - smoothstep(0.65, 1.0, p)
	if _releasing:
		fade *= 1.0 - clampf(_release_age / 0.22, 0.0, 1.0)
	match effect_kind:
		&"indicator": _indicator(p, fade)
		&"projectile": _projectile(p, fade)
		&"splash", &"frost": _splash(p, fade)
		&"roots", &"leash": _roots(p, fade)
		&"spores", &"heal": _spores(p, fade)
		&"mark": _mark(p, fade)
		&"shield", &"facets": _shield(p, fade)
		&"blink", &"clones": _blink(p, fade)
		&"mirror": _mirror(p, fade)
		&"beam": _beam(p, fade)
		&"shards", &"burst": _burst(p, fade)
		&"rage", &"weakness", &"swallow": _pulse(p, fade)
		&"mud_wall": _mud_wall(p, fade)
		&"whirlpool": _whirlpool(p, fade)
		&"tide": _tide(p, fade)
		&"claw": _claw(p, fade)


func _stroke(points: PackedVector2Array, size: float, ink: Color, light: Color, fade: float) -> void:
	Stroke.stroke(self, points, maxf(size, 0.1), ink, light, fade)


func _line() -> PackedVector2Array:
	if path_points.size() >= 2:
		return path_points
	return PackedVector2Array([Vector2.ZERO, Vector2(maxf(travel_distance, 0.0), 0.0)])


func _projectile(p: float, fade: float) -> void:
	var size: float = maxf(width, 1.0)
	var points := PackedVector2Array()
	for i: int in 8:
		var t: float = i / 7.0
		points.append(Vector2(-size * 2.4 * (1.0 - t), sin(t * TAU + p * TAU) * size * 0.09))
	_stroke(points, size * 0.7, INK, color, fade)
	Shapes.facet(self, Vector2.ZERO, 0.0, size * 1.6, size * 0.75, color, accent, fade)
	Shapes.star(self, Vector2(size * 0.35, -size * 0.12), size * 0.24, Color(accent, fade))


func _splash(p: float, fade: float) -> void:
	var reach: float = maxf(radius, 0.0) * (0.2 + 0.8 * ease(p, 0.4))
	var puddle := PackedVector2Array()
	for i: int in 18:
		var angle: float = i * TAU / 18.0
		var lobe: float = 0.82 + sin(i * 2.4) * 0.18
		puddle.append(Vector2(cos(angle), sin(angle) * 0.6) * reach * lobe * 0.62)
	draw_colored_polygon(puddle, Color(INK, fade * 0.72))
	var rim := puddle.duplicate()
	rim.append(rim[0])
	_stroke(rim, 6.0, color.darkened(0.5), color, fade * 0.7)
	for arm: int in 7:
		var direction := Vector2.from_angle(arm * TAU / 7.0 + 0.2)
		var points := PackedVector2Array([direction * reach * 0.12,
			direction * reach * 0.38 + Vector2(0, -sin(p * PI) * radius * 0.18),
			direction * reach * 0.76])
		_stroke(points, (12.0 + arm % 3 * 3.0) * (1.0 - p * 0.65), INK, color, fade)
		_stroke(points, 2.2, color, accent, fade * 0.65)
	var count: int = clampi(particle_budget, 0, 32)
	for i: int in count:
		var axis := Vector2.from_angle(i * 2.39996)
		var fraction: float = 0.35 + float(i % 5) * 0.13
		var pos: Vector2 = axis * reach * fraction
		pos.y -= sin(p * PI) * radius * (0.12 + float(i % 3) * 0.06)
		Shapes.facet(self, pos, axis.angle() + p, 8.0 + float(i % 4) * 4.0,
			5.0 + float(i % 3) * 2.0, INK, color, fade)
	for i: int in 3:
		var arc: float = i * TAU / 3.0
		draw_arc(Vector2.ZERO, maxf(reach * 0.7, 0.1), arc, arc + 0.9, 9, Color(accent, fade * 0.65), 2.0, false)


func _roots(p: float, fade: float) -> void:
	var base: PackedVector2Array = _line()
	if effect_kind == &"leash":
		for strand: int in 2:
			var woven := PackedVector2Array()
			for segment: int in base.size() - 1:
				var delta: Vector2 = base[segment + 1] - base[segment]
				for i: int in 12:
					var t: float = i / 11.0
					woven.append(base[segment].lerp(base[segment + 1], t)
						+ delta.normalized().orthogonal() * sin(t * TAU * 2.0 + p * TAU + strand * PI) * width * 0.2)
			_stroke(woven, width * 0.65, ROOT.darkened(0.5), ROOT, fade)
		return
	for root: int in 5:
		var direction := Vector2.from_angle(lerpf(-0.7, 0.7, root / 4.0))
		var reach: float = radius * smoothstep(0.0, 0.4, p)
		var points := PackedVector2Array([Vector2.ZERO, direction * reach * 0.32 + Vector2(0, -12),
			direction * reach * 0.7 + Vector2(0, -22), direction * reach])
		_stroke(points, 12.0 - root, ROOT.darkened(0.5), ROOT, fade)
		_stroke(points, 2.0, color, accent, fade * 0.7)


func _spores(p: float, fade: float) -> void:
	for spiral: int in 3:
		var strand := PackedVector2Array()
		for k: int in 14:
			var t: float = k / 13.0
			var angle: float = spiral * TAU / 3.0 + t * 2.2 + p * TAU
			strand.append(Vector2.from_angle(angle) * radius * (0.12 + t * 0.45) - Vector2(0, t * 12.0))
		_stroke(strand, 5.0, INK, color, fade * 0.45)
	var count: int = clampi(particle_budget, 0, 24)
	for i: int in count:
		var t: float = fposmod(p + i * 0.618034, 1.0)
		var point := Vector2.from_angle(i * 2.39996) * radius * (0.25 + float(i % 5) * 0.14)
		point.y -= t * 32.0
		var alpha: float = sin(t * PI) * fade
		var size: float = 2.5 + float(i % 3) * 1.7
		draw_circle(point, size + 1.5, Color(INK, alpha))
		draw_circle(point, size, Color(color, alpha))
		Shapes.star(self, point + Vector2(-1, -1), size * 0.65, Color(accent, alpha))


func _mark(p: float, fade: float) -> void:
	var pulse: float = 0.85 + sin(p * TAU * 3.0) * 0.15
	for i: int in 4:
		var axis := Vector2.from_angle(i * PI * 0.5)
		var center: Vector2 = axis * radius * 0.52
		Shapes.facet(self, center, axis.angle(), radius * 0.22 * pulse,
			radius * 0.1, INK, color, fade)
	Shapes.star(self, Vector2.ZERO, radius * 0.2 * pulse, Color(WARNING, fade))


func _shield(p: float, fade: float) -> void:
	var sectors: int = 4 if effect_kind == &"facets" else 6
	for i: int in sectors:
		var angle: float = i * TAU / sectors
		var integrity: float = facet_strengths[i] if effect_kind == &"facets" else strength
		if integrity <= 0.0:
			continue
		var points := PackedVector2Array()
		for k: int in 7:
			var a: float = angle - 0.4 + k * 0.8 / 6.0
			points.append(Vector2.from_angle(a) * radius)
		_stroke(points, 8.0 * integrity, INK, color, fade * integrity)
		Shapes.facet(self, Vector2.from_angle(angle) * radius, angle + PI * 0.5,
			18.0, 6.0, color, accent, fade * integrity)
	if effect_kind == &"shield":
		for point: Vector2 in secondary_offsets:
			_stroke(PackedVector2Array([Vector2.ZERO, point]), 3.0, ROOT, color, fade * 0.45)


func _blink(p: float, fade: float) -> void:
	var origins := secondary_offsets if not secondary_offsets.is_empty() else PackedVector2Array([Vector2.ZERO])
	for center: Vector2 in origins:
		var count: int = clampi(particle_budget, 0, 20)
		for i: int in count:
			var angle: float = i * 2.39996
			var spread: float = radius * sin(p * PI) * (0.2 + float(i % 5) * 0.15)
			var pos: Vector2 = center + Vector2(cos(angle) * spread * 0.5, sin(angle) * spread)
			Shapes.facet(self, pos, angle, 8.0 + i % 4 * 3.0, 3.0, color, accent, fade)
		Shapes.star(self, center, radius * 0.6 * sin(p * PI), Color(accent, fade))


func _mirror(p: float, fade: float) -> void:
	var points := PackedVector2Array([Vector2(0, -radius), Vector2(width * 0.55, 0),
		Vector2(0, radius), Vector2(-width * 0.55, 0)])
	draw_colored_polygon(points, Color(INK, fade * 0.85))
	Shapes.facet(self, Vector2.ZERO, PI * 0.5, radius * 1.8, width, color.darkened(0.3), accent, fade * 0.8)
	points.append(points[0])
	_stroke(points, 4.0, INK, color, fade)
	for side: int in 4:
		var corner: Vector2 = points[side]
		Shapes.facet(self, corner, corner.angle(), 10.0, 5.0, INK, accent, fade)
	var sweep_y: float = lerpf(-radius * 0.6, radius * 0.6, p)
	_stroke(PackedVector2Array([Vector2(-width * 0.25, sweep_y), Vector2(width * 0.25, sweep_y - 7.0)]),
		3.0, color, WHITE, fade * 0.8)
	Shapes.star(self, Vector2(0, sin(p * TAU) * radius * 0.5), width * 0.23, Color(WHITE, fade))


func _beam(p: float, fade: float) -> void:
	var points: PackedVector2Array = _line()
	var pulse: float = 0.94 + sin(p * TAU * 4.0) * 0.06
	_stroke(points, width + 5.0, INK, color.darkened(0.4), fade)
	_stroke(points, width * pulse, color, accent, fade * 0.9)
	_stroke(points, width * 0.22, accent, WHITE, fade)
	for point: Vector2 in points:
		Shapes.star(self, point, width * 0.65, Color(accent, fade))


func _burst(p: float, fade: float) -> void:
	Shapes.burst(self, Vector2.ZERO, p, 1.0, clampi(particle_budget, 0, 32), radius, color, accent)
	if effect_kind == &"shards":
		for i: int in 3:
			var angle: float = lerpf(-0.5, 0.5, i / 2.0)
			Shapes.facet(self, Vector2.from_angle(angle) * travel_distance * p,
				angle, width * 1.6, width * 0.5, color, accent, fade)


func _pulse(p: float, fade: float) -> void:
	var pulse: float = 0.7 + sin(p * TAU * 2.0) * 0.3
	for i: int in 3:
		var points := PackedVector2Array()
		for k: int in 8:
			var y: float = k / 7.0
			points.append(Vector2((i - 1) * radius * 0.3 + sin(y * TAU + p * TAU) * 6.0,
				-radius * y))
		_stroke(points, width * (1.0 + pulse), INK, color, fade * 0.85)
		_stroke(points, width * 0.24, color, accent, fade * 0.8)
	for i: int in mini(particle_budget, 12):
		var t: float = fposmod(p + i * 0.618, 1.0)
		var point := Vector2(sin(i * 2.4) * radius * 0.45, -t * radius)
		Shapes.facet(self, point, -PI * 0.5, 6.0 + i % 3 * 2.0, 3.0, color, accent, fade * sin(t * PI))
	Shapes.star(self, Vector2(0, -radius * 0.3), width * pulse, Color(accent, fade))


func _mud_wall(p: float, fade: float) -> void:
	var height: float = radius * stage
	for i: int in 7:
		var x: float = lerpf(-width * 0.5, width * 0.5, i / 6.0)
		var top: float = height * (0.8 + float(i % 3) * 0.1)
		var points := PackedVector2Array([Vector2(x, 4), Vector2(x - 4, -top * 0.4), Vector2(x, -top)])
		_stroke(points, width * 0.2, INK, ROOT.lerp(color, 0.25), fade)
		_stroke(points, 2.0, color.darkened(0.3), accent, fade * 0.45)
	if stage < 0.8:
		for i: int in mini(particle_budget, 8):
			var point := Vector2(cos(i * 2.39996) * width * 0.4, sin(i * 2.39996 + p * TAU) * 6.0)
			draw_circle(point, 5.0, Color(color.darkened(0.6), fade * 0.7))


func _whirlpool(p: float, fade: float) -> void:
	for arm: int in 4:
		var points := PackedVector2Array()
		for i: int in 25:
			var t: float = i / 24.0
			var angle: float = arm * TAU / 4.0 + t * TAU * 0.8 - p * TAU
			points.append(Vector2.from_angle(angle) * radius * (0.12 + 0.88 * t))
		_stroke(points, maxf(width * 0.7, 2.0), INK, color, fade * 0.7)
		_stroke(points, 2.0, color, accent, fade * 0.8)
	for i: int in mini(particle_budget, 20):
		var t: float = fposmod(p + i * 0.618034, 1.0)
		var angle: float = i * 2.39996 - p * TAU * 2.0
		var point: Vector2 = Vector2.from_angle(angle) * radius * (1.0 - t * 0.86)
		Shapes.facet(self, point, angle + PI * 0.5, 13.0 + i % 4 * 3.0,
			4.0 + i % 3, color, accent, fade * sin(t * PI))


func _tide(p: float, fade: float) -> void:
	for part: int in 12:
		var start: float = part * TAU / 12.0
		var points := PackedVector2Array()
		for i: int in 9:
			var a: float = start + i / 8.0 * TAU / 12.0 * 0.92
			var ripple: float = sin(a * 18.0 - p * TAU) * 3.0
			points.append(Vector2.from_angle(a) * (radius + ripple))
		_stroke(points, width, INK, color, fade * 0.65)
		_stroke(points, 2.0, color, accent, fade * 0.85)


func _claw(p: float, fade: float) -> void:
	var sweep: float = smoothstep(0.0, 0.65, p)
	for finger: int in 3:
		var points := PackedVector2Array()
		for i: int in 14:
			var angle: float = lerpf(-deg_to_rad(half_angle_degrees), deg_to_rad(half_angle_degrees), i / 13.0 * sweep)
			points.append(Vector2.from_angle(angle) * (radius - finger * 12.0))
		_stroke(points, maxf(width - finger * 2.0, 1.0), INK, color, fade)
		_stroke(points, 2.0, color, accent, fade)


## Télégraphe distinct : dimension exacte du danger, contour corail, remplissage très faible.
func _indicator(p: float, fade: float) -> void:
	var ink := Color(WARNING, fade * (0.75 + sin(p * TAU * 3.0) * 0.2))
	if target_shape == &"line":
		var points: PackedVector2Array = _line()
		_stroke(points, width + 4.0, INK, INK, fade)
		_stroke(points, width, WARNING, WARNING, fade * 0.08)
		for i: int in points.size() - 1:
			var normal: Vector2 = (points[i + 1] - points[i]).normalized().orthogonal() * width * 0.5
			draw_line(points[i] + normal, points[i + 1] + normal, ink, 2.0, false)
			draw_line(points[i] - normal, points[i + 1] - normal, ink, 2.0, false)
	elif target_shape == &"sector":
		var half: float = deg_to_rad(half_angle_degrees)
		draw_arc(Vector2.ZERO, maxf(radius, 0.1), -half, half, 32, ink, 3.0, false)
		draw_line(Vector2.ZERO, Vector2.from_angle(-half) * radius, ink, 2.0, false)
		draw_line(Vector2.ZERO, Vector2.from_angle(half) * radius, ink, 2.0, false)
	else:
		draw_arc(Vector2.ZERO, maxf(radius, 0.1), 0.0, TAU, 48, Color(INK, fade), 5.0, false)
		draw_arc(Vector2.ZERO, maxf(radius, 0.1), 0.0, TAU, 48, ink, 2.0, false)
