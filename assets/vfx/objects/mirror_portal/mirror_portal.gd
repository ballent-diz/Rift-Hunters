extends Node2D
## Visuel autonome : aucune téléportation, collision ou minuterie de gameplay.

signal finished(state: StringName)

@export_range(8.0, 96.0) var radius: float = 32.0
@export_range(0.05, 12.0) var duration: float = 0.65
@export var tint: Color = Color("7bdedb")

const STATES: Array[StringName] = [&"active", &"cooldown", &"enter", &"exit", &"hidden"]
const SHARDS: int = 24
var visual_state: StringName = &"active"
var _time: float = 0.0
var _frozen: bool = false
var _emitted: bool = false


func _ready() -> void:
	queue_redraw()


func set_state(value: StringName) -> void:
	if value not in STATES:
		return
	visual_state = value
	_time = 0.0
	_emitted = false
	_frozen = false
	visible = value != &"hidden"
	set_process(visible)
	queue_redraw()


func play(value: StringName) -> void:
	set_state(value)


func seek_visual(seconds: float) -> void:
	_time = maxf(0.0, seconds)
	_frozen = true
	queue_redraw()


func release() -> void:
	set_state(&"hidden")
	_frozen = true


func _process(delta: float) -> void:
	if _frozen:
		return
	_time += delta
	if visual_state in [&"enter", &"exit", &"cooldown"] and _time >= duration and not _emitted:
		_emitted = true
		finished.emit(visual_state)
	queue_redraw()


func _poly(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)


func _draw() -> void:
	if visual_state == &"hidden":
		return
	var unit: float = radius / 32.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * unit)
	var off: bool = visual_state == &"cooldown"
	var progress: float = clampf(_time / maxf(duration, 0.05), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.6)
	var rim: Color = tint.darkened(0.55) if off else tint.lerp(Color("ecffff"), 0.22 + 0.18 * pulse)
	# Socle compact : aucun disque lumineux au sol.
	_poly(PackedVector2Array([Vector2(-30, -4), Vector2(-23, -12), Vector2(23, -12),
		Vector2(30, -4), Vector2(20, 1), Vector2(-20, 1)]), Color("1b343b"))
	_poly(PackedVector2Array([Vector2(-25, -6), Vector2(-20, -11), Vector2(20, -11),
		Vector2(25, -6), Vector2(17, -3), Vector2(-17, -3)]), Color("748c87"))
	# Cadre facetté, silhouette en arche brisée, ancrée au pied.
	var outer: PackedVector2Array = PackedVector2Array([Vector2(-26, -9), Vector2(-27, -63),
		Vector2(-17, -85), Vector2(0, -97), Vector2(17, -85), Vector2(27, -63), Vector2(26, -9)])
	_poly(outer, Color("142c39"))
	var glass: PackedVector2Array = PackedVector2Array([Vector2(-18, -12), Vector2(-19, -60),
		Vector2(-12, -77), Vector2(0, -87), Vector2(12, -77), Vector2(19, -60), Vector2(18, -12)])
	_poly(glass, Color("20373e") if off else Color("103e55"))
	for side: int in [-1, 1]:
		var x: float = float(side)
		_poly(PackedVector2Array([Vector2(19 * x, -10), Vector2(26 * x, -9), Vector2(27 * x, -63),
			Vector2(19 * x, -59)]), Color("526a6a") if off else tint.darkened(0.47))
		_poly(PackedVector2Array([Vector2(19 * x, -59), Vector2(27 * x, -63), Vector2(17 * x, -85),
			Vector2(12 * x, -77)]), tint.darkened(0.5) if off else tint.darkened(0.12))
		_poly(PackedVector2Array([Vector2(12 * x, -77), Vector2(17 * x, -85), Vector2(0, -97),
			Vector2(0, -87)]), Color("658282") if off else tint.lightened(0.3))
		draw_polyline(PackedVector2Array([Vector2(19 * x, -12), Vector2(19 * x, -60),
			Vector2(12 * x, -77), Vector2(0, -87)]), rim, 1.2, true)
		for i: int in range(4):
			var y: float = -21.0 - i * 12.0
			draw_line(Vector2(22 * x, y), Vector2(25 * x, y - 2), Color("1a4248"), 1.0)
	# Vitre en facettes étroites : lumière locale, sans voile couvrant les ennemis.
	var alpha: float = 0.09 if off else 0.35
	for i: int in range(6):
		var left: float = -17.0 + i * 5.7
		var motion: float = sin(_time * 1.8 + i * 0.8) * (0.2 if off else 2.4)
		_poly(PackedVector2Array([Vector2(left, -16), Vector2(left + 4, -18),
			Vector2(left + 5 + motion, -65), Vector2(left + motion, -65)]), Color(tint, alpha))
	if not off:
		for i: int in range(5):
			var y: float = -24.0 - i * 10.0
			var wave: float = sin(_time * 2.1 + i * 0.6) * 5.0
			draw_polyline(PackedVector2Array([Vector2(-16, y), Vector2(-7, y - 2 + wave),
				Vector2(6, y + wave), Vector2(16, y - 1)]), Color(tint, 0.24), 1.0, true)
		_poly(PackedVector2Array([Vector2(-9, -70), Vector2(-4, -75), Vector2(7, -28),
			Vector2(3, -23)]), Color("c9ffff80"))
	# Une même teinte (tint) identifie les deux membres d'une paire.
	_poly(PackedVector2Array([Vector2(0, -94), Vector2(4, -89), Vector2(0, -84),
		Vector2(-4, -89)]), rim)
	if visual_state in [&"enter", &"exit"]:
		_draw_transit(progress)


func _draw_transit(progress: float) -> void:
	var envelope: float = sin(progress * PI)
	if envelope <= 0.001:
		return
	var outgoing: bool = visual_state == &"exit"
	var phase: float = progress if outgoing else 1.0 - progress
	var center: Vector2 = Vector2(0, -47)
	# Trois rubans étroits en torsion, regroupés dans le même CanvasItem.
	for ribbon: int in range(3):
		var strip: PackedVector2Array = PackedVector2Array()
		for k: int in range(18):
			var f: float = k / 17.0
			var angle: float = f * TAU * 0.85 + ribbon * TAU / 3.0 + phase * 2.0
			var spread: float = 6.0 + phase * 28.0
			strip.append(center + Vector2(cos(angle) * spread * f, sin(angle) * 14 * f + (f - 0.5) * 48))
		draw_polyline(strip, Color(tint, envelope * 0.8), 1.8, true)
	for shard: int in range(SHARDS):
		var angle: float = shard * 2.399963
		var distance: float = 8.0 + phase * (15.0 + float(shard % 5) * 4.0)
		var point: Vector2 = center + Vector2(cos(angle) * distance, sin(angle) * distance * 1.05)
		var axis: Vector2 = Vector2.from_angle(angle + phase) * (1.5 + float(shard % 3))
		var normal: Vector2 = axis.orthogonal().normalized() * 1.1
		_poly(PackedVector2Array([point + axis, point + normal, point - axis, point - normal]),
			Color(tint.lightened(0.35), envelope * 0.9))
