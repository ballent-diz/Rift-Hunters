class_name MirrorCrystalVisual
extends Node2D
## Visualisation autonome B5. Aucun dégât, collision ou choix de cible.
signal finished
signal animation_finished(animation: StringName)

@export var radius: float = 30.0
@export var duration: float = 0.65
@export var tint: Color = Color(0.22, 0.83, 0.95, 1.0)
@export var ray_length: float = 240.0
@export var direction: Vector2 = Vector2.RIGHT
@export var idle_height: float = 72.0
@export var charged_pulse_speed: float = 5.0
@export var debris_duration: float = 0.9
@export var ray_width: float = 9.0

var state: StringName = &"idle"
var elapsed: float = 0.0
var _frozen: bool = false
var _emitted: bool = false

func _ready() -> void:
	queue_redraw()

func set_state(value: StringName) -> void:
	play(value)

func play(value: StringName = &"idle") -> void:
	if value not in [&"idle", &"charged", &"burst", &"debris", &"hidden"]:
		value = &"idle"
	state = value
	elapsed = 0.0
	_frozen = false
	_emitted = false
	visible = state != &"hidden"
	set_process(visible)
	queue_redraw()

func seek_visual(seconds: float) -> void:
	elapsed = maxf(seconds, 0.0)
	_frozen = true
	queue_redraw()

func release() -> void:
	state = &"hidden"
	visible = false
	set_process(false)
	_frozen = true

func _process(delta: float) -> void:
	if _frozen:
		return
	elapsed += delta
	if state in [&"burst", &"debris"]:
		var end_time := duration if state == &"burst" else debris_duration
		if elapsed >= maxf(end_time, 0.01) and not _emitted:
			_emitted = true
			elapsed = maxf(end_time, 0.01)
			_frozen = true
			animation_finished.emit(state)
			finished.emit()
	queue_redraw()

func _draw() -> void:
	if state == &"hidden":
		return
	var size_factor := maxf(radius, 1.0) / 30.0
	if state in [&"idle", &"charged"]:
		_draw_body(size_factor)
	elif state == &"burst":
		_draw_burst(size_factor)
	elif state == &"debris":
		_draw_debris(size_factor)

func _draw_body(s: float) -> void:
	var h := maxf(idle_height, 12.0) * s
	var pulse := 0.5 + 0.5 * sin(elapsed * charged_pulse_speed)
	var charged := state == &"charged"
	# Socle bas en perspective ; ancre au pied (0,0).
	var base := PackedVector2Array([Vector2(-25, -8), Vector2(-15, -17),
		Vector2(17, -17), Vector2(27, -7), Vector2(17, 1), Vector2(-15, 1)])
	for i in base.size():
		base[i] *= s
	draw_colored_polygon(base, Color(0.10, 0.19, 0.20, 0.9))
	draw_polyline(PackedVector2Array([base[0], base[1], base[2], base[3]]), Color(0.42, 0.57, 0.54), 1.5 * s, true)
	var tip := Vector2(-2.0 * s, -h)
	var left := Vector2(-18.0 * s, -h * 0.66)
	var right := Vector2(17.0 * s, -h * 0.64)
	var foot := Vector2(1.0 * s, -5.0 * s)
	var ridge := Vector2(0, -h * 0.51)
	var dark := tint.darkened(0.68)
	var middle := tint.darkened(0.20)
	var lit := tint.lightened(0.25)
	if charged:
		lit = lit.lerp(Color.WHITE, 0.2 + pulse * 0.25)
		middle = middle.lightened(pulse * 0.16)
	draw_colored_polygon(PackedVector2Array([tip, left, foot, right]), dark)
	draw_colored_polygon(PackedVector2Array([tip, left, ridge]), middle)
	draw_colored_polygon(PackedVector2Array([tip, ridge, right]), lit)
	draw_colored_polygon(PackedVector2Array([left, foot, ridge]), tint.darkened(0.43))
	draw_colored_polygon(PackedVector2Array([ridge, foot, right]), middle)
	draw_polyline(PackedVector2Array([left, tip, right, foot, left]), tint.lightened(0.6), 1.3 * s, true)
	draw_line(tip, ridge, Color(0.83, 1, 1), 1.4 * s, true)
	draw_line(ridge, foot, tint.lightened(0.4), 1.0 * s, true)
	# Petites stries minérales : matière déterministe, aucun bruit aléatoire.
	for i in 7:
		var y := -h * (0.24 + float(i) * 0.076)
		var x := (3.0 + float(i % 3)) * s
		draw_line(Vector2(x, y), Vector2(x + 3 * s, y - 2 * s), Color(0.78, 1, 1, 0.32), s, true)
	if charged:
		for i in 8:
			var phase := fmod(elapsed * 0.45 + float(i) / 8.0, 1.0)
			var p := Vector2(sin(float(i) * 2.4) * 23 * s, -h * phase)
			_draw_spark(p, 1.8 * s, Color(0.8, 1, 1, sin(phase * PI) * 0.8))

func _draw_burst(s: float) -> void:
	var t := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var origin := Vector2(0, -idle_height * s * 0.4)
	var forward := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var reach := maxf(ray_length, 1.0) * (1.0 - pow(1.0 - t, 3.0))
	var fade := pow(1.0 - t, 0.65)
	for i in 3:
		var axis := forward.rotated(float(i) * TAU / 3.0)
		var normal := axis.orthogonal()
		var end := origin + axis * reach
		var width := maxf(ray_width, 1.0) * s * fade
		var outer := PackedVector2Array([origin - normal * width, origin + axis * reach * 0.55 + normal * width * 0.5,
			end, origin + axis * reach * 0.55 - normal * width * 0.5])
		# Ombre de contour, matière colorée et cœur fin ; aucun disque lumineux.
		draw_line(origin, end, Color(0.02, 0.12, 0.18, fade * 0.8), width * 2.2, true)
		draw_colored_polygon(outer, Color(tint, fade * 0.78))
		draw_line(origin, end, Color(0.85, 1, 1, fade), maxf(width * 0.25, 0.1), true)
		for j in 5:
			var along := (float(j) + 0.4) / 5.0
			var point := origin + axis * reach * along + normal * sin(float(j) * 3.1) * width
			_draw_spark(point, (2.0 + float(j % 2)) * s * fade, Color(tint.lightened(0.6), fade))
	_draw_fragments(s, t, fade)

func _draw_fragments(s: float, t: float, alpha: float) -> void:
	var origin := Vector2(0, -idle_height * s * 0.35)
	for i in 12:
		var angle := float(i) * 2.39996
		var speed := (18.0 + float(i % 4) * 8.0) * s
		var p := origin + Vector2.from_angle(angle) * speed * t
		p.y += 34.0 * s * t * t
		var a := Vector2.from_angle(angle + t) * (3.0 + float(i % 3)) * s
		var b := a.orthogonal() * 0.48
		draw_colored_polygon(PackedVector2Array([p - a, p + b, p + a, p - b]), Color(tint.darkened(float(i % 3) * 0.18), alpha))
		draw_line(p - a, p + b, Color(tint.lightened(0.65), alpha), s, true)

func _draw_debris(s: float) -> void:
	var t := clampf(elapsed / maxf(debris_duration, 0.01), 0.0, 1.0)
	_draw_fragments(s, 1.0, 1.0 - t)

func _draw_spark(p: Vector2, width: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-width, 0), p + Vector2(0, -width * 1.8),
		p + Vector2(width, 0), p + Vector2(0, width * 1.8)]), color)
