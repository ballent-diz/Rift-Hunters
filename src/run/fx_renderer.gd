class_name FxRenderer
extends Node2D
## Effets visuels éphémères dessinés en un seul passage : chiffres de dégâts, éclats, anneaux, lignes.
## Opacité plafonnée pour ne jamais masquer les ennemis et les projectiles dangereux.

const MAX_ALPHA := 0.55

var ctx: RunContext
var _numbers: Array[Dictionary] = []
var _shapes: Array[Dictionary] = []
var _font: Font


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	z_index = 10
	_font = ThemeDB.fallback_font


func damage_number(pos: Vector2, amount: float, info: DamageInfo) -> void:
	if not Settings.damage_numbers or _numbers.size() >= ctx.balance.max_damage_numbers:
		return
	var color := Color(0.85, 0.95, 1.0)
	var size: int = 13
	if info.has_tag(DamageInfo.TAG_DOT):
		color = Color(1.0, 0.6, 0.3)
		size = 10
	elif info.has_tag(DamageInfo.TAG_DETONATION):
		color = Color(0.5, 1.0, 1.0)
		size = 17
	elif info.has_tag(DamageInfo.TAG_TECHNIQUE):
		color = Color(1.0, 0.9, 0.4)
		size = 16
	elif info.source_kind == DamageInfo.SourceKind.ALLY:
		color = Color(1.0, 0.85, 0.65)
	var offset := Vector2(randf_range(-8, 8), -10)
	_numbers.append({"pos": pos + offset, "text": str(int(round(amount))), "color": color, "size": size, "life": 0.6, "total": 0.6})


func text(pos: Vector2, value: String, color: Color) -> void:
	_numbers.append({"pos": pos, "text": value, "color": color, "size": 15, "life": 0.9, "total": 0.9})


func spark(pos: Vector2, color: Color, size: float) -> void:
	_shapes.append({"type": 0, "pos": pos, "color": color, "size": size, "life": 0.15, "total": 0.15})


func ring(pos: Vector2, radius: float, color: Color, life: float) -> void:
	_shapes.append({"type": 1, "pos": pos, "color": color, "size": radius, "life": life, "total": life})


func burst(pos: Vector2, radius: float, color: Color) -> void:
	_shapes.append({"type": 2, "pos": pos, "color": color, "size": radius, "life": 0.25, "total": 0.25})


func line(from: Vector2, to: Vector2, color: Color, width: float, life: float = 0.2) -> void:
	_shapes.append({"type": 3, "pos": from, "to": to, "color": color, "size": width, "life": life, "total": life})


## Télégraphe de trajectoire dangereuse (charge d'ennemi).
func danger_line(from: Vector2, to: Vector2, width: float, life: float) -> void:
	_shapes.append({"type": 4, "pos": from, "to": to, "color": Color(1.0, 0.25, 0.6), "size": width, "life": life, "total": life})


func step(delta: float) -> void:
	for list: Array[Dictionary] in [_numbers, _shapes]:
		var i: int = list.size() - 1
		while i >= 0:
			var e: Dictionary = list[i]
			e["life"] = float(e["life"]) - delta
			if float(e["life"]) <= 0.0:
				list[i] = list[list.size() - 1]
				list.pop_back()
			i -= 1
	for n: Dictionary in _numbers:
		n["pos"] = (n["pos"] as Vector2) + Vector2(0, -38.0 * delta)
	queue_redraw()


func _draw() -> void:
	for e: Dictionary in _shapes:
		var t: float = float(e["life"]) / float(e["total"])
		var color: Color = e["color"]
		var alpha: float = minf(color.a, MAX_ALPHA) * t
		match int(e["type"]):
			0:
				draw_circle(e["pos"], float(e["size"]) * (1.2 - t * 0.5), Color(color, alpha + 0.2))
			1:
				draw_arc(e["pos"], float(e["size"]) * (1.15 - t * 0.15), 0.0, TAU, 40, Color(color, alpha + 0.2), 2.5)
			2:
				draw_circle(e["pos"], float(e["size"]) * (1.1 - t * 0.3), Color(color, alpha * 0.6))
				draw_arc(e["pos"], float(e["size"]), 0.0, TAU, 40, Color(color, alpha + 0.2), 2.0)
			3:
				draw_line(e["pos"], e["to"], Color(color, alpha + 0.3), float(e["size"]))
			4:
				draw_line(e["pos"], e["to"], Color(color, 0.25), float(e["size"]))
				draw_line(e["pos"], e["to"], Color(color, 0.85), 2.0)
	for n: Dictionary in _numbers:
		var t: float = float(n["life"]) / float(n["total"])
		var color: Color = n["color"]
		var pos: Vector2 = n["pos"]
		draw_string_outline(_font, pos, n["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, n["size"], 3, Color(0, 0, 0, t))
		draw_string(_font, pos, n["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, n["size"], Color(color, t))
