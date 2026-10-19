class_name FloodDirector
extends Node2D
## Brique B3 « danger périodique télégraphié », habillage crues (docs/design/CARTES.md, carte 5) : les lits de rivière
## de la carte débordent à tour de rôle. Alerte (l'eau monte, bord de danger et sens du flot), puis crue : le flot
## emporte et blesse tout ce qui s'y trouve. Le Chasseur en sort par le côté ou par la Ruée (invulnérable, sans
## dérive) ; les Corrompus y perdent une grosse part de leurs PV : les y attirer. Boss et Échos épargnés.

enum State { CALM, WARNING, FLOOD }

const TICK := 0.5
const WATER := Color(0.25, 0.52, 0.85)
const FOAM := Color(0.85, 0.95, 1.0)

var ctx: RunContext
var state: State = State.CALM
## Lit en crue ou en alerte (-1 avant la première).
var lane: int = -1
var floods: int = 0
var _next: int = 0
var _timer: float = 0.0
var _tick: float = 0.0
var _time: float = 0.0
var _rise: float = 0.0
## Télégraphe au-dessus des Corrompus et du voile de nuit, comme les dangers des ennemis.
var _telegraph: Node2D


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Floods"
	z_index = -4
	_timer = ctx.arena.flood_first
	_next = ctx.rng.randi() % ctx.arena.flood_lanes.size()
	_telegraph = Node2D.new()
	_telegraph.z_as_relative = false
	_telegraph.z_index = 3
	add_child(_telegraph)
	_telegraph.draw.connect(_draw_telegraph)


func lane_rect() -> Rect2:
	return ctx.arena.flood_lanes[lane] if lane >= 0 else Rect2()


func lane_dir() -> Vector2:
	return TerrainDirector.lane_dir(ctx.arena.flood_dirs, lane)


## Secondes avant la prochaine étape (alerte, crue ou décrue).
func time_left() -> float:
	return maxf(_timer, 0.0)


func step(delta: float) -> void:
	_time += delta
	_timer -= delta
	match state:
		State.CALM:
			_rise = maxf(_rise - delta / 0.6, 0.0)
			if _timer <= 0.0:
				_warn()
		State.WARNING:
			_rise = clampf(1.0 - _timer / maxf(ctx.arena.flood_warning, 0.01), 0.0, 1.0) * 0.4
			if _timer <= 0.0:
				_surge()
		State.FLOOD:
			_rise = minf(_rise + delta / 0.3, 1.0)
			_tick -= delta
			if _tick <= 0.0:
				_tick = TICK
				_strike()
			if _timer <= 0.0:
				state = State.CALM
				_timer = ctx.arena.flood_interval
	queue_redraw()
	_telegraph.queue_redraw()


func _warn() -> void:
	state = State.WARNING
	lane = _next
	_next = (_next + 1) % ctx.arena.flood_lanes.size()
	_timer = ctx.arena.flood_warning
	if floods == 0:
		ctx.events.event_started.emit("FLOOD_INTRO")


func _surge() -> void:
	state = State.FLOOD
	floods += 1
	_timer = ctx.arena.flood_duration
	_tick = 0.0
	ctx.stats.add(&"floods")


## Coup du flot : le Chasseur s'il est dans le lit (sauf Ruée), et chaque Corrompu du lit.
func _strike() -> void:
	var rect: Rect2 = lane_rect()
	if rect.has_point(ctx.player.global_position):
		ctx.combat.damage_player(ctx.arena.flood_damage * ctx.difficulty.enemy_damage_mult, &"flood")
	var reach: float = rect.size.length() * 0.5
	for enemy: Enemy in ctx.enemies.query_radius(rect.get_center(), reach):
		if not enemy.alive or enemy.is_boss or enemy.is_obstacle or not rect.has_point(enemy.position):
			continue
		var info := DamageInfo.make(enemy.max_hp * ctx.arena.flood_enemy_ratio, DamageInfo.SourceKind.ENVIRONMENT,
			&"flood")
		ctx.combat.deal_damage(enemy, info)


## Poussée du flot à cette position (px/s ; zéro hors de la crue).
func drift(pos: Vector2) -> Vector2:
	if state == State.FLOOD and lane_rect().has_point(pos):
		return lane_dir() * ctx.arena.flood_push
	return Vector2.ZERO


## Danger pour le bot : sortir du lit par le côté le plus proche pendant l'alerte et la crue.
func danger(pos: Vector2) -> Vector2:
	if state == State.CALM or not lane_rect().grow(40.0).has_point(pos):
		return Vector2.ZERO
	var across: Vector2 = lane_dir().orthogonal()
	return across * (1.0 if (pos - lane_rect().get_center()).dot(across) >= 0.0 else -1.0)


func _view() -> Rect2:
	var view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	return view.grow(64.0)


## Eau du lit : elle monte pendant l'alerte, déferle pendant la crue, se retire ensuite.
func _draw() -> void:
	if ctx == null or lane < 0 or _rise <= 0.0 or not lane_rect().intersects(_view()):
		return
	var rect: Rect2 = lane_rect()
	draw_rect(rect, Color(WATER, 0.6 * _rise))
	if state == State.FLOOD:
		TerrainDirector.draw_flow(self, rect, lane_dir(), _time * ctx.arena.flood_push, Color(FOAM, 0.75 * _rise))


func _draw_telegraph() -> void:
	if ctx == null or lane < 0 or state == State.CALM or not lane_rect().intersects(_view()):
		return
	var rect: Rect2 = lane_rect()
	if state == State.WARNING:
		var pulse: float = 0.5 + 0.5 * sin(_time * 12.0)
		_telegraph.draw_rect(rect, Color(HazardManager.DANGER, 0.08 + 0.06 * pulse))
		_telegraph.draw_rect(rect, Color(HazardManager.DANGER, 0.6 + 0.35 * pulse), false, 3.0)
		TerrainDirector.draw_flow(_telegraph, rect, lane_dir(), _time * 160.0, Color(HazardManager.DANGER, 0.8))
	else:
		_telegraph.draw_rect(rect, Color(HazardManager.DANGER, 0.5), false, 2.0)
