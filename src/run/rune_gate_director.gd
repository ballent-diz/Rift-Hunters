class_name RuneGateDirector
extends Node2D
## Brique B4 « passages qui changent », habillage portes runiques (carte 22, docs/maps/SANCTUAIRE_DES_RUNES.md) : les
## arches gravées des rues se ferment par groupes (rideau de runes infranchissable) et le groupe fermé tourne à
## intervalles annoncés : les runes des portes qui vont se fermer s'allument, puis les portes s'échangent. Le plan de
## la carte garantit un détour : même les six portes fermées, le parvis reste joignable.

const RUNE := Color(0.82, 0.4, 1.0)
const STONE := Color(0.25, 0.2, 0.32)

var ctx: RunContext
## Rotations déjà jouées.
var turns: int = 0
## Groupe fermé (indice dans rune_gate_patterns), -1 : toutes ouvertes.
var pattern: int = -1
## Groupe annoncé (alerte), -1 sinon.
var next_pattern: int = -1
var _walls: Array[int] = []
var _timer: float = 0.0
var _time: float = 0.0
var _shown: Array[float] = []


static func uses_gates(arena: ArenaData) -> bool:
	return not arena.rune_gates.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "RuneGates"
	z_index = 2
	_timer = ctx.arena.rune_gate_first
	for rect: Rect2 in ctx.arena.rune_gates:
		var id: int = ctx.obstacles.add_wall(rect, true)
		ctx.obstacles.set_wall_enabled(id, false)
		_walls.append(id)
		_shown.append(0.0)


func is_closed(index: int) -> bool:
	return ctx.obstacles.wall_enabled[_walls[index]]


func closed_gates() -> Array[int]:
	var out: Array[int] = []
	for i: int in _walls.size():
		if is_closed(i):
			out.append(i)
	return out


func time_left() -> float:
	return maxf(_timer, 0.0)


func step(delta: float) -> void:
	_time += delta
	_timer -= delta
	if next_pattern < 0 and _timer <= ctx.arena.rune_gate_warning:
		next_pattern = (pattern + 1) % maxi(ctx.arena.rune_gate_patterns.size(), 1)
		if turns == 0:
			ctx.events.event_started.emit("RUNE_GATES_INTRO")
	if _timer <= 0.0:
		_turn()
	for i: int in _shown.size():
		var target: float = 1.0 if is_closed(i) else 0.0
		_shown[i] = move_toward(_shown[i], target, delta / 0.35)
	queue_redraw()


## Les portes du groupe suivant se ferment, les autres s'ouvrent ; ceux pris dans une porte qui se ferme en sont
## repoussés.
func _turn() -> void:
	_timer = ctx.arena.rune_gate_period
	pattern = next_pattern if next_pattern >= 0 else 0
	next_pattern = -1
	turns += 1
	ctx.stats.add(&"rune_gates_turned")
	var closing: PackedInt32Array = ctx.arena.rune_gate_patterns[pattern] if pattern < ctx.arena.rune_gate_patterns.size() \
		else PackedInt32Array()
	for i: int in _walls.size():
		ctx.obstacles.set_wall_enabled(_walls[i], closing.has(i))
	if ctx.flow:
		ctx.flow.apply_walls(ctx.obstacles)
	ctx.player.global_position = ctx.obstacles.push_out(ctx.player.global_position, 14.0)
	for enemy: Enemy in ctx.enemies.list:
		if enemy.alive and not enemy.is_boss:
			enemy.position = ctx.obstacles.push_out(enemy.position, enemy.radius)
	for i: int in closing:
		ctx.fx.burst(ctx.arena.rune_gates[i].get_center(), 90.0, Color(RUNE, 0.5))


## Rotation immédiate (gardien du sanctuaire) : l'alerte est sautée.
func force_turn() -> void:
	if next_pattern < 0:
		next_pattern = (pattern + 1) % maxi(ctx.arena.rune_gate_patterns.size(), 1)
	_turn()


func _draw() -> void:
	if ctx == null:
		return
	var warned: PackedInt32Array = ctx.arena.rune_gate_patterns[next_pattern] if next_pattern >= 0 \
		and next_pattern < ctx.arena.rune_gate_patterns.size() else PackedInt32Array()
	for i: int in _walls.size():
		var rect: Rect2 = ctx.arena.rune_gates[i]
		if _shown[i] > 0.01:
			draw_rect(rect, Color(STONE, 0.35 * _shown[i]))
			var count: int = maxi(int(maxf(rect.size.x, rect.size.y) / 28.0), 3)
			var long: bool = rect.size.x >= rect.size.y
			for k: int in count:
				var t: float = (k + 0.5) / count
				var pos: Vector2 = rect.position + (Vector2(rect.size.x * t, rect.size.y * 0.5) if long
					else Vector2(rect.size.x * 0.5, rect.size.y * t))
				var flicker: float = 0.6 + 0.4 * sin(_time * 5.0 + k * 1.3)
				draw_circle(pos, 6.0, Color(RUNE, 0.8 * _shown[i] * flicker))
			draw_rect(rect, Color(RUNE, 0.9 * _shown[i]), false, 3.0)
		if warned.has(i) and not is_closed(i):
			var blink: float = 0.5 + 0.5 * sin(_time * 12.0)
			draw_rect(rect, Color(RUNE, 0.35 + 0.45 * blink), false, 2.0)
