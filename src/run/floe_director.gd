class_name FloeDirector
extends Node2D
## Brique B4 « passages qui changent », habillage banquise (carte 19, docs/maps/BANQUISE_DU_PHARE.md) : des plaques de
## banquise se fendent à intervalles annoncés (fissures qui clignotent, danger au sol), puis s'ouvrent sur l'eau noire
## et deviennent infranchissables avant de regeler. Le Chasseur resté dessus est blessé et rejeté sur la glace ferme ;
## les Corrompus qui marchent dessus sombrent (gros dégâts), d'où l'intérêt d'y attirer la horde.
## Sécurité du parcours : jamais plus de floe_access_max plaques d'accès au phare ouvertes à la fois, et au plus une
## plaque par quart de la carte.

enum State { CLOSED, CRACKING, OPEN }

## Hauteur des bandes qui approchent chaque polygone en rectangles de collision.
const STRIP := 40.0
const CRACK := Color(0.75, 0.97, 1.0)
const WATER := Color(0.02, 0.05, 0.09)
const REFREEZE := 1.2

var ctx: RunContext
## Cycles de fente déjà joués.
var cycles: int = 0
var _state: Array[State] = []
## Secondes avant la prochaine étape de chaque plaque (alerte → ouverte → regel).
var _left: Array[float] = []
## Ouverture affichée (0 : glace, 1 : eau noire), pour le fondu.
var _shown: Array[float] = []
var _walls: Array[Array] = []
var _bounds: Array[Rect2] = []
var _centers: Array[Vector2] = []
var _textures: Array[Texture2D] = []
var _timer: float = 0.0
var _time: float = 0.0
var _access_turn: int = 0


static func uses_floe(arena: ArenaData) -> bool:
	return not arena.floe_plates.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Floe"
	z_index = -4
	_timer = ctx.arena.floe_first
	_access_turn = ctx.rng.randi() % maxi(ctx.arena.floe_access.size(), 1)
	for i: int in ctx.arena.floe_plates.size():
		var poly: PackedVector2Array = ctx.arena.floe_plates[i]
		_state.append(State.CLOSED)
		_left.append(0.0)
		_shown.append(0.0)
		_bounds.append(_bounds_of(poly))
		_centers.append(_bounds[i].get_center())
		var ids: Array[int] = []
		for rect: Rect2 in strips(poly):
			var id: int = ctx.obstacles.add_wall(rect, true)
			ctx.obstacles.set_wall_enabled(id, false)
			ids.append(id)
		_walls.append(ids)
		var texture: Texture2D = null
		if i < ctx.arena.floe_overlays.size() and ResourceLoader.exists(ctx.arena.floe_overlays[i]):
			texture = load(ctx.arena.floe_overlays[i])
		_textures.append(texture)


## Bandes horizontales de STRIP unités qui couvrent le polygone : intervalles de quatre lignes de balayage par bande,
## fusionnés (les petits écarts aussi, le contour peint est dentelé).
static func strips(poly: PackedVector2Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var box: Rect2 = _bounds_of(poly)
	var y: float = box.position.y
	while y < box.end.y:
		var height: float = minf(STRIP, box.end.y - y)
		var spans: Array[Vector2] = []
		for line: int in 4:
			var scan: float = y + height * (line + 0.5) / 4.0
			var xs: Array[float] = []
			for i: int in poly.size():
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % poly.size()]
				if (a.y <= scan) != (b.y <= scan):
					xs.append(a.x + (scan - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			var k: int = 0
			while k + 1 < xs.size():
				spans.append(Vector2(xs[k], xs[k + 1]))
				k += 2
		spans.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var merged: Array[Vector2] = []
		for span: Vector2 in spans:
			if not merged.is_empty() and span.x <= merged[-1].y + 16.0:
				merged[-1].y = maxf(merged[-1].y, span.y)
			else:
				merged.append(span)
		for span: Vector2 in merged:
			if span.y - span.x > 8.0:
				out.append(Rect2(span.x, y, span.y - span.x, height))
		y += STRIP
	return out


static func _bounds_of(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		box = box.expand(p)
	return box


func plate_count() -> int:
	return _state.size()


func is_open(index: int) -> bool:
	return _state[index] == State.OPEN


func is_cracking(index: int) -> bool:
	return _state[index] == State.CRACKING


func open_plates() -> Array[int]:
	var out: Array[int] = []
	for i: int in _state.size():
		if _state[i] != State.CLOSED:
			out.append(i)
	return out


## Plaque sous ce point (-1 si aucune).
func plate_at(pos: Vector2) -> int:
	for i: int in _bounds.size():
		if _bounds[i].has_point(pos) and Geometry2D.is_point_in_polygon(pos, ctx.arena.floe_plates[i]):
			return i
	return -1


## Secondes avant le prochain cycle de fente.
func time_left() -> float:
	return maxf(_timer, 0.0)


func step(delta: float) -> void:
	_time += delta
	_timer -= delta
	for i: int in _state.size():
		match _state[i]:
			State.CRACKING:
				_left[i] -= delta
				if _left[i] <= 0.0:
					_open(i)
			State.OPEN:
				_left[i] -= delta
				_shown[i] = minf(_shown[i] + delta / 0.4, 1.0)
				if _left[i] <= 0.0:
					_close(i)
			_:
				_shown[i] = maxf(_shown[i] - delta / REFREEZE, 0.0)
	if _timer <= 0.0:
		_timer = ctx.arena.floe_period
		_start_cycle()
	queue_redraw()


## Choix d'un cycle : une plaque d'accès à tour de rôle (floe_access_max au plus), puis des plaques hors accès dans des
## quarts différents, en commençant par la plus proche du Chasseur (il voit la banquise se fendre).
func _start_cycle() -> void:
	if cycles == 0:
		ctx.events.event_started.emit("FLOE_INTRO")
	cycles += 1
	var picked: Array[int] = []
	var access: Array[int] = ctx.arena.floe_access
	for n: int in mini(ctx.arena.floe_access_max, access.size()):
		var index: int = access[(_access_turn + n) % access.size()]
		if _state[index] == State.CLOSED:
			picked.append(index)
	if not access.is_empty():
		_access_turn = (_access_turn + 1) % access.size()
	var ring: Array[int] = []
	for i: int in _state.size():
		if not access.has(i) and _state[i] == State.CLOSED:
			ring.append(i)
	var player: Vector2 = ctx.player.global_position if ctx.player else Vector2.ZERO
	ring.sort_custom(func(a: int, b: int) -> bool:
		return _centers[a].distance_squared_to(player) < _centers[b].distance_squared_to(player))
	if ring.size() > 1:
		# Hors la plus proche, l'ordre est tiré au sort pour varier les cycles.
		var rest: Array[int] = ring.slice(1)
		rest.shuffle()
		ring = [ring[0]]
		ring.append_array(rest)
	var quarters: Array[int] = []
	for index: int in picked:
		quarters.append(_quarter(_centers[index]))
	for index: int in ring:
		if picked.size() >= ctx.arena.floe_access_max + ctx.arena.floe_ring_count:
			break
		var quarter: int = _quarter(_centers[index])
		if quarters.has(quarter):
			continue
		quarters.append(quarter)
		picked.append(index)
	for index: int in picked:
		crack(index, ctx.arena.floe_warning)


## Fend une plaque fermée : alerte de `warning` secondes, puis elle s'ouvre (gardien : séisme de banquise).
func crack(index: int, warning: float) -> void:
	if _state[index] != State.CLOSED:
		return
	_state[index] = State.CRACKING
	_left[index] = warning
	var box: Rect2 = _bounds[index]
	var radius: float = maxf(box.size.x, box.size.y) * 0.45
	ctx.hazards.add_circle(_centers[index], radius, warning,
		ctx.arena.floe_damage * ctx.difficulty.enemy_damage_mult, true, &"floe")


## Plaques fermées les plus proches d'un point (séisme du gardien).
func nearest_closed(pos: Vector2, count: int) -> Array[int]:
	var list: Array[int] = []
	for i: int in _state.size():
		if _state[i] == State.CLOSED and not ctx.arena.floe_access.has(i):
			list.append(i)
	list.sort_custom(func(a: int, b: int) -> bool:
		return _centers[a].distance_squared_to(pos) < _centers[b].distance_squared_to(pos))
	return list.slice(0, count)


func _quarter(pos: Vector2) -> int:
	return (1 if pos.x >= 0.0 else 0) + (2 if pos.y >= 0.0 else 0)


func _open(index: int) -> void:
	_state[index] = State.OPEN
	_left[index] = ctx.arena.floe_open
	for id: int in _walls[index]:
		ctx.obstacles.set_wall_enabled(id, true)
	if ctx.flow:
		ctx.flow.apply_walls(ctx.obstacles)
	var poly: PackedVector2Array = ctx.arena.floe_plates[index]
	var center: Vector2 = _centers[index]
	ctx.fx.burst(center, maxf(_bounds[index].size.x, _bounds[index].size.y) * 0.5, Color(CRACK, 0.5))
	ctx.fx.debris(center, CRACK, 12)
	if ctx.player and Geometry2D.is_point_in_polygon(ctx.player.global_position, poly):
		ctx.player.global_position = _shore(ctx.player.global_position, 16.0, index)
	for enemy: Enemy in ctx.enemies.query_radius(center, _bounds[index].size.length() * 0.5):
		if not enemy.alive or enemy.is_boss or enemy.is_obstacle or (enemy.data and enemy.data.flying):
			continue
		if not Geometry2D.is_point_in_polygon(enemy.position, poly):
			continue
		ctx.combat.deal_damage(enemy, DamageInfo.make(ctx.arena.floe_damage + enemy.max_hp * ctx.arena.floe_enemy_ratio,
			DamageInfo.SourceKind.ENVIRONMENT, &"floe"))
		ctx.stats.add(&"floe_sunk")
		if enemy.alive:
			enemy.position = _shore(enemy.position, enemy.radius, index)
	ctx.stats.add(&"floes_broken")


func _close(index: int) -> void:
	_state[index] = State.CLOSED
	for id: int in _walls[index]:
		ctx.obstacles.set_wall_enabled(id, false)
	if ctx.flow:
		ctx.flow.apply_walls(ctx.obstacles)


## Point de glace ferme le plus proche hors de la plaque, en s'éloignant de son centre.
func _shore(pos: Vector2, radius: float, index: int) -> Vector2:
	var poly: PackedVector2Array = ctx.arena.floe_plates[index]
	for ring: float in [24.0, 48.0, 80.0, 120.0, 170.0, 230.0, 300.0, 380.0]:
		var best := Vector2.INF
		for i: int in 16:
			var point: Vector2 = pos + Vector2.RIGHT.rotated(TAU * i / 16.0) * ring
			if Geometry2D.is_point_in_polygon(point, poly) or ctx.obstacles.blocks(point, radius):
				continue
			if best == Vector2.INF or point.distance_squared_to(pos) < best.distance_squared_to(pos):
				best = point
		if best != Vector2.INF:
			return best
	return ctx.obstacles.push_out(pos, radius)


## Bot : quitter une plaque qui se fend.
func danger(pos: Vector2) -> Vector2:
	var index: int = plate_at(pos)
	if index < 0 or _state[index] != State.CRACKING:
		return Vector2.ZERO
	return (pos - _centers[index]).normalized() * 1.5


func _draw() -> void:
	if ctx == null:
		return
	for i: int in _state.size():
		var poly: PackedVector2Array = ctx.arena.floe_plates[i]
		if _shown[i] > 0.01:
			if _textures[i] and i < ctx.arena.floe_overlay_rects.size():
				draw_texture_rect(_textures[i], ctx.arena.floe_overlay_rects[i], false, Color(1, 1, 1, _shown[i]))
			else:
				draw_colored_polygon(poly, Color(WATER, 0.85 * _shown[i]))
		if _state[i] == State.CRACKING:
			var blink: float = 0.5 + 0.5 * sin(_time * 12.0)
			var closed := PackedVector2Array(poly)
			closed.append(poly[0])
			draw_polyline(closed, Color(CRACK, 0.45 + 0.45 * blink), 3.0)
			_draw_cracks(i, 1.0 - _left[i] / maxf(ctx.arena.floe_warning, 0.01))


## Fissures qui partent du centre et s'allongent pendant l'alerte.
func _draw_cracks(index: int, progress: float) -> void:
	var box: Rect2 = _bounds[index]
	var reach: float = minf(box.size.x, box.size.y) * 0.5 * clampf(progress, 0.15, 1.0)
	for k: int in 6:
		var angle: float = TAU * k / 6.0 + index * 0.7
		var mid: Vector2 = _centers[index] + Vector2.from_angle(angle + 0.25) * reach * 0.5
		var tip: Vector2 = _centers[index] + Vector2.from_angle(angle) * reach
		draw_polyline(PackedVector2Array([_centers[index], mid, tip]), Color(CRACK, 0.85), 2.5)
