class_name TerrainDirector
extends Node2D
## Terrain qui change le mouvement (docs/design/CARTES.md) :
## - brique B1, terrain lent (gués de la carte 4, plus tard boue ou neige) : tout le monde y est ralenti, Chasseur,
##   Échos et Corrompus ;
## - brique B6, courants (carte 5) : le Chasseur et les Corrompus y dérivent ; le suivre est un raccourci ;
## - vase qui colle (carte 11) : très lente, et elle colle encore un instant après la sortie (par entité).
## La Ruée garde sa vitesse et ne dérive pas : c'est la porte de sortie. Dessine les zones pour la lisibilité.

const RIPPLE := Color(0.75, 0.9, 1.0)
const MUD := Color(0.36, 0.27, 0.16)
const MUD_SHINE := Color(0.72, 0.62, 0.4)

var ctx: RunContext
var _time: float = 0.0
## Fin de l'effet collant par entité (identifiant d'instance → instant où il cesse).
var _stuck: Dictionary = {}
var _sweep: float = 0.0
var _mud_announced: bool = false


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Terrain"
	# Au-dessus du sol (-10), sous les zones (0) et les personnages.
	z_index = -5


static func uses_terrain(arena: ArenaData) -> bool:
	return not arena.slow_zones.is_empty() or not arena.currents.is_empty() or not arena.mud_zones.is_empty()


## Multiplicateur de vitesse à cette position (1 hors des zones lentes). `who` (identifiant d'instance) suit l'effet
## collant de la vase ; 0 : position seule.
func speed_mult(pos: Vector2, who: int = 0) -> float:
	var mult: float = 1.0
	for rect: Rect2 in ctx.arena.slow_zones:
		if rect.has_point(pos):
			mult = ctx.arena.slow_zone_mult
			break
	return minf(mult, mud_mult(pos, who))


## Bot : sortir de la vase par le bord le plus proche (un joueur moyen ne s'y attarde pas).
func danger(pos: Vector2) -> Vector2:
	for rect: Rect2 in ctx.arena.mud_zones:
		if rect.has_point(pos):
			var to_left: float = pos.x - rect.position.x
			var to_right: float = rect.end.x - pos.x
			var to_top: float = pos.y - rect.position.y
			var to_bottom: float = rect.end.y - pos.y
			var nearest: float = minf(minf(to_left, to_right), minf(to_top, to_bottom))
			if nearest == to_left:
				return Vector2.LEFT * 0.6
			if nearest == to_right:
				return Vector2.RIGHT * 0.6
			return (Vector2.UP if nearest == to_top else Vector2.DOWN) * 0.6
	return Vector2.ZERO


func in_mud(pos: Vector2) -> bool:
	for rect: Rect2 in ctx.arena.mud_zones:
		if rect.has_point(pos):
			return true
	return false


func mud_mult(pos: Vector2, who: int = 0) -> float:
	if ctx.arena.mud_zones.is_empty():
		return 1.0
	var stick: float = maxf(ctx.arena.mud_stick, 0.0)
	if in_mud(pos):
		if who != 0:
			_stuck[who] = _time + stick
		if not _mud_announced and ctx.player and who == ctx.player.get_instance_id():
			_mud_announced = true
			ctx.events.event_started.emit("MUD_INTRO")
		return ctx.arena.mud_mult
	var until: float = float(_stuck.get(who, 0.0))
	if who == 0 or until <= _time or stick <= 0.0:
		return 1.0
	# Collant : la vitesse remonte de mud_mult à 1 pendant mud_stick secondes.
	var left: float = (until - _time) / stick
	return lerpf(1.0, ctx.arena.mud_mult, left)


## Dérive des courants à cette position (px/s ; zéro hors des courants).
func drift(pos: Vector2) -> Vector2:
	for i: int in ctx.arena.currents.size():
		if ctx.arena.currents[i].has_point(pos):
			return current_dir(i) * ctx.arena.current_speed
	return Vector2.ZERO


func current_dir(index: int) -> Vector2:
	return lane_dir(ctx.arena.current_dirs, index)


## Sens d'une bande (courant ou lit de crue) ; vers la droite si la carte ne le donne pas.
static func lane_dir(dirs: Array[Vector2], index: int) -> Vector2:
	if index < dirs.size() and dirs[index].length() > 0.01:
		return dirs[index].normalized()
	return Vector2.RIGHT


func step(delta: float) -> void:
	_time += delta
	_sweep -= delta
	if _sweep <= 0.0 and not _stuck.is_empty():
		_sweep = 2.0
		for key: Variant in _stuck.keys():
			if float(_stuck[key]) <= _time:
				_stuck.erase(key)
	queue_redraw()


func _draw() -> void:
	if ctx == null:
		return
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	view = view.grow(64.0)
	for i: int in ctx.arena.slow_zones.size():
		var rect: Rect2 = ctx.arena.slow_zones[i]
		if ctx.arena.slow_zones_painted or not rect.intersects(view):
			continue
		draw_rect(rect, Color(0.3, 0.6, 0.85, 0.22))
		draw_rect(rect, Color(RIPPLE, 0.35), false, 2.0)
		# Ondulations : cercles qui s'élargissent à des points fixes de la zone.
		var count: int = clampi(int(rect.get_area() / 40000.0), 2, 24)
		for k: int in count:
			var seed_x: float = fmod((i * 13 + k) * 0.6180339, 1.0)
			var seed_y: float = fmod((i * 7 + k) * 0.4142135, 1.0)
			var center: Vector2 = rect.position + Vector2(seed_x, seed_y) * rect.size
			var life: float = fmod(_time * 0.45 + k * 0.37, 1.0)
			draw_arc(center, 6.0 + life * 26.0, 0.0, TAU, 20, Color(RIPPLE, 0.65 * (1.0 - life)), 2.0)
	for i: int in ctx.arena.mud_zones.size():
		var rect: Rect2 = ctx.arena.mud_zones[i]
		if rect.intersects(view):
			_draw_mud(rect, i)
	for i: int in ctx.arena.currents.size():
		var rect: Rect2 = ctx.arena.currents[i]
		if rect.intersects(view):
			draw_rect(rect, Color(0.3, 0.6, 0.85, 0.18))
			draw_flow(self, rect, current_dir(i), _time * ctx.arena.current_speed, Color(RIPPLE, 0.55))


## Vase : teinte brune (si elle n'est pas peinte) et bulles qui gonflent puis éclatent, pour la lire en jeu.
func _draw_mud(rect: Rect2, index: int) -> void:
	if not ctx.arena.mud_painted:
		draw_rect(rect, Color(MUD, 0.45))
		draw_rect(rect, Color(MUD_SHINE, 0.4), false, 2.0)
	var count: int = clampi(int(rect.get_area() / 30000.0), 2, 30)
	for k: int in count:
		var seed_x: float = fmod((index * 11 + k) * 0.6180339, 1.0)
		var seed_y: float = fmod((index * 5 + k) * 0.4142135, 1.0)
		var center: Vector2 = rect.position + Vector2(seed_x, seed_y) * rect.size
		var life: float = fmod(_time * 0.6 + k * 0.29, 1.0)
		var radius: float = 3.0 + life * 7.0
		draw_circle(center, radius, Color(MUD_SHINE, 0.35 * (1.0 - life)))
		draw_arc(center, radius, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.4 * (1.0 - life)), 1.5)


## Chevrons qui défilent dans le sens du flot (courants et crues).
static func draw_flow(canvas: CanvasItem, rect: Rect2, dir: Vector2, travel: float, color: Color) -> void:
	var across: Vector2 = dir.orthogonal()
	var length: float = absf(rect.size.dot(dir))
	var width: float = absf(rect.size.dot(across))
	var spacing: float = 90.0
	var rows: int = maxi(1, int(width / 70.0))
	var start: Vector2 = rect.get_center() - dir * length * 0.5
	for row: int in rows:
		var side: float = (row + 0.5) / rows - 0.5
		var offset: float = fmod(travel + row * spacing * 0.5, spacing)
		var along: float = offset
		while along < length:
			var tip: Vector2 = start + dir * along + across * side * width
			var fade: float = minf(along, length - along) / 60.0
			var c: Color = Color(color, color.a * clampf(fade, 0.0, 1.0))
			canvas.draw_line(tip, tip - dir * 14.0 + across * 10.0, c, 2.5)
			canvas.draw_line(tip, tip - dir * 14.0 - across * 10.0, c, 2.5)
			along += spacing
