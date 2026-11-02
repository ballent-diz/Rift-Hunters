class_name TideDirector
extends Node2D
## Brique B4 « passages qui changent », habillage marée (docs/design/CARTES.md, carte 12) : l'eau monte et descend
## à intervalles annoncés. À marée basse, les chaussées basses sont des raccourcis ; alerte (l'eau monte, bords
## qui clignotent), puis marée haute : elles sont noyées et infranchissables, et tout ce qui s'y trouve est repoussé
## sur la rive la plus proche. Un chemin plus long reste toujours praticable (garanti par le plan de la carte).

enum State { LOW, RISING, HIGH }

const WATER := Color(0.2, 0.62, 0.66)
const FOAM := Color(0.85, 1.0, 0.97)

var ctx: RunContext
var state: State = State.LOW
var tides: int = 0
var _walls: Array[int] = []
var _timer: float = 0.0
var _time: float = 0.0
## Niveau de l'eau sur les chaussées (0 : sèches, 1 : noyées), pour le dessin.
var _level: float = 0.0


static func uses_tide(arena: ArenaData) -> bool:
	return not arena.tide_causeways.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Tide"
	z_index = -4
	_timer = ctx.arena.tide_first
	for rect: Rect2 in ctx.arena.tide_causeways:
		var id: int = ctx.obstacles.add_wall(rect, true)
		ctx.obstacles.set_wall_enabled(id, false)
		_walls.append(id)


func is_high() -> bool:
	return state == State.HIGH


## Secondes avant la prochaine étape (alerte, marée haute ou basse).
func time_left() -> float:
	return maxf(_timer, 0.0)


func step(delta: float) -> void:
	_time += delta
	_timer -= delta
	match state:
		State.LOW:
			_level = maxf(_level - delta / 1.2, 0.0)
			if _timer <= 0.0:
				state = State.RISING
				_timer = ctx.arena.tide_warning
				if tides == 0:
					ctx.events.event_started.emit("TIDE_INTRO")
		State.RISING:
			_level = clampf(1.0 - _timer / maxf(ctx.arena.tide_warning, 0.01), 0.0, 1.0) * 0.6
			if _timer <= 0.0:
				_set_high(true)
		State.HIGH:
			_level = minf(_level + delta / 0.4, 1.0)
			if _timer <= 0.0:
				_set_high(false)
	queue_redraw()


func _set_high(high: bool) -> void:
	state = State.HIGH if high else State.LOW
	_timer = ctx.arena.tide_high if high else ctx.arena.tide_low
	if high:
		tides += 1
	for id: int in _walls:
		ctx.obstacles.set_wall_enabled(id, high)
	if ctx.flow:
		ctx.flow.apply_walls(ctx.obstacles)
	if high:
		# Ceux restés sur une chaussée regagnent la rive la plus proche (les murs les repoussent).
		ctx.player.global_position = ctx.obstacles.push_out(ctx.player.global_position, 14.0)
		for enemy: Enemy in ctx.enemies.list:
			if enemy.alive and not enemy.is_boss:
				enemy.position = ctx.obstacles.push_out(enemy.position, enemy.radius)


## Chaussée sous ce point (-1 si aucune).
func causeway_at(pos: Vector2) -> int:
	for i: int in ctx.arena.tide_causeways.size():
		if ctx.arena.tide_causeways[i].has_point(pos):
			return i
	return -1


## Bot : quitter une chaussée quand l'eau monte.
func danger(pos: Vector2) -> Vector2:
	if state != State.RISING:
		return Vector2.ZERO
	var index: int = causeway_at(pos)
	if index < 0:
		return Vector2.ZERO
	var rect: Rect2 = ctx.arena.tide_causeways[index]
	var exits: Array[Vector2] = [Vector2(rect.position.x - 1.0, pos.y), Vector2(rect.end.x + 1.0, pos.y),
		Vector2(pos.x, rect.position.y - 1.0), Vector2(pos.x, rect.end.y + 1.0)]
	var best: Vector2 = exits[0]
	for exit: Vector2 in exits:
		if exit.distance_to(pos) < best.distance_to(pos):
			best = exit
	return (best - pos).normalized() * 1.5


func _draw() -> void:
	if ctx == null or _level <= 0.01:
		return
	for i: int in ctx.arena.tide_causeways.size():
		var rect: Rect2 = ctx.arena.tide_causeways[i]
		draw_rect(rect, Color(WATER, 0.25 + 0.5 * _level))
		if state == State.RISING:
			var blink: float = 0.5 + 0.5 * sin(_time * 10.0)
			draw_rect(rect, Color(FOAM, 0.5 + 0.4 * blink), false, 3.0)
		var count: int = clampi(int(rect.get_area() / 30000.0), 2, 20)
		for k: int in count:
			var seed_x: float = fmod((i * 13 + k) * 0.6180339, 1.0)
			var seed_y: float = fmod((i * 3 + k) * 0.4142135, 1.0)
			var center: Vector2 = rect.position + Vector2(seed_x, seed_y) * rect.size
			var life: float = fmod(_time * 0.5 + k * 0.31, 1.0)
			draw_arc(center, 6.0 + life * 24.0, 0.0, TAU, 18, Color(FOAM, 0.5 * _level * (1.0 - life)), 2.0)
