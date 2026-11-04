class_name NightDirector
extends Node2D
## Brique B2 « nuit et lucioles » (docs/design/CARTES.md). Un voile sombre couvre le monde, percé de halos autour du
## Chasseur, des Échos, du boss et des clairières de lucioles. On ne cible que ce qu'on voit : tirs automatiques et
## Échos visent les ennemis éclairés ou Révélés ; les clairières révèlent les ennemis qui y passent. Les sorts visés et
## les zones touchent tout le monde ; les télégraphes de danger restent dessinés au-dessus du voile (HazardManager).

const VEIL := preload("res://assets/shaders/night_veil.gdshader")
const MAX_LIGHTS := 16
## Fréquence à laquelle les clairières révèlent les ennemis présents.
const REVEAL_INTERVAL := 0.8
const FIREFLIES_PER_GLADE := 18
## Blizzard : flocons dessinés à l'écran (au plus fort d'une rafale).
const SNOW_FLAKES := 160

var ctx: RunContext
var _fireflies: Node2D
var _reveal_timer: float = 0.0
var _time: float = 0.0
## Blizzard : direction du vent de la rafale en cours et numéro de cette rafale (annonce : night_intro_key).
var _wind_dir := Vector2.RIGHT
var _gust_index: int = -1


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Night"
	# Ajouté au monde juste après les Corrompus (même z) : le voile les couvre, pas les Échos ni le Chasseur.
	z_index = 2
	var veil := ShaderMaterial.new()
	veil.shader = VEIL
	veil.set_shader_parameter("darkness", ctx.arena.night)
	if ctx.arena.blizzard:
		veil.set_shader_parameter("night_color", ctx.arena.blizzard_color)
		veil.set_shader_parameter("darkness", ctx.arena.blizzard_calm)
	material = veil
	_fireflies = Node2D.new()
	_fireflies.z_index = 5
	add_child(_fireflies)
	_fireflies.draw.connect(_draw_fireflies)
	ctx.enemies.visibility = can_target
	_start.call_deferred()


## Une fois la partie construite : annonce (HUD prêt) et effets peints des Échos au-dessus du voile.
func _start() -> void:
	ctx.events.event_started.emit(ctx.arena.night_intro_key)
	if ctx.allies and ctx.allies.vfx.layer:
		ctx.allies.vfx.layer.z_index = 2


## Ennemi visible : éclairé, Révélé, ou boss (toujours visible).
func can_target(enemy: Enemy) -> bool:
	if ctx.arena.blizzard and gust_strength() < 0.5:
		return true
	return enemy.is_boss or enemy.statuses.has(&"reveal") or is_lit(enemy.position)


## Blizzard : force de la rafale (0 au calme, 1 au plus fort) ; elle monte pendant l'annonce et retombe en 1 s.
func gust_strength() -> float:
	if not ctx.arena.blizzard:
		return 1.0
	var t: float = fmod(ctx.time, ctx.arena.blizzard_period)
	var start: float = ctx.arena.blizzard_period - ctx.arena.blizzard_gust - ctx.arena.blizzard_warning
	if t < start:
		return 0.0
	if t < start + ctx.arena.blizzard_warning:
		return (t - start) / maxf(ctx.arena.blizzard_warning, 0.01)
	var left: float = ctx.arena.blizzard_period - t
	return clampf(left, 0.0, 1.0)


## Blizzard : poussée du vent à cette position (zéro au calme et dans les refuges du vent).
func wind(pos: Vector2) -> Vector2:
	if not ctx.arena.blizzard:
		return Vector2.ZERO
	var strength: float = gust_strength()
	if strength <= 0.0:
		return Vector2.ZERO
	for glade: Vector2 in ctx.arena.firefly_glades:
		if pos.distance_to(glade) <= ctx.arena.firefly_radius:
			return Vector2.ZERO
	return _wind_dir * ctx.arena.blizzard_wind * strength


func is_lit(pos: Vector2) -> bool:
	if ctx.player and pos.distance_to(ctx.player.global_position) <= ctx.arena.light_radius:
		return true
	if ctx.allies:
		for ally: Ally in ctx.allies.team:
			if pos.distance_to(ally.global_position) <= ctx.arena.echo_light_radius:
				return true
	for source: Vector3 in light_sources():
		if pos.distance_to(Vector2(source.x, source.y)) <= source.z:
			return true
	return false


## Sources fixes (x, y, rayon) : clairières, et braseros allumés quand la carte a du froid (Col des braseros).
func light_sources() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for glade: Vector2 in ctx.arena.firefly_glades:
		result.append(Vector3(glade.x, glade.y, ctx.arena.firefly_radius))
	if ctx.cold:
		for i: int in ctx.arena.braziers.size():
			if ctx.cold.is_lit(i):
				result.append(Vector3(ctx.arena.braziers[i].x, ctx.arena.braziers[i].y, ctx.arena.brazier_radius))
	return result


## Lumières (x, y, rayon, intensité) : Chasseur, Échos, boss, puis les clairières les plus proches du Chasseur.
func lights() -> PackedVector4Array:
	var result := PackedVector4Array()
	var center: Vector2 = ctx.player.global_position
	result.append(Vector4(center.x, center.y, ctx.arena.light_radius, 1.0))
	for ally: Ally in ctx.allies.team:
		result.append(Vector4(ally.global_position.x, ally.global_position.y, ctx.arena.echo_light_radius, 0.85))
	if ctx.boss and ctx.boss.alive:
		result.append(Vector4(ctx.boss.position.x, ctx.boss.position.y, ctx.boss.radius * 3.0, 0.8))
	var glades: Array[Vector3] = light_sources()
	glades.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x, a.y).distance_squared_to(center) < Vector2(b.x, b.y).distance_squared_to(center))
	for i: int in glades.size():
		if result.size() >= MAX_LIGHTS:
			break
		var flicker: float = 0.88 + 0.08 * sin(_time * 2.3 + i * 1.7)
		result.append(Vector4(glades[i].x, glades[i].y, glades[i].z, flicker))
	return result


func step(delta: float) -> void:
	_time += delta
	if ctx.arena.blizzard:
		_step_blizzard()
	_reveal_timer -= delta
	if _reveal_timer <= 0.0:
		_reveal_timer = REVEAL_INTERVAL
		for source: Vector3 in light_sources():
			for enemy: Enemy in ctx.enemies.query_radius(Vector2(source.x, source.y), source.z):
				ctx.status_system.apply(enemy, &"reveal", 1, &"firefly")
	var lit: PackedVector4Array = lights()
	(material as ShaderMaterial).set_shader_parameter("lights", lit)
	(material as ShaderMaterial).set_shader_parameter("light_count", lit.size())
	queue_redraw()
	_fireflies.queue_redraw()


func _step_blizzard() -> void:
	var gust: int = int(ctx.time / ctx.arena.blizzard_period)
	if gust != _gust_index and gust_strength() > 0.0:
		_gust_index = gust
		_wind_dir = Vector2.RIGHT.rotated(ctx.rng.randf() * TAU)
		ctx.stats.add(&"blizzard_gusts")
	var darkness: float = lerpf(ctx.arena.blizzard_calm, ctx.arena.night, gust_strength())
	(material as ShaderMaterial).set_shader_parameter("darkness", darkness)


## Rectangle visible par la caméra (le voile ne couvre que l'écran, avec une marge).
func _view() -> Rect2:
	var viewport: Viewport = get_viewport()
	var screen := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	return (viewport.get_canvas_transform().affine_inverse() * screen).grow(64.0)


func _draw() -> void:
	if ctx == null:
		return
	draw_rect(_view(), Color.WHITE)


## Lucioles des clairières, au-dessus du voile : points qui dérivent et clignotent.
func _draw_fireflies() -> void:
	if ctx == null:
		return
	var view: Rect2 = _view()
	if ctx.arena.blizzard:
		_draw_snow(view)
		return
	for g: int in ctx.arena.firefly_glades.size():
		var glade: Vector2 = ctx.arena.firefly_glades[g]
		if not view.grow(ctx.arena.firefly_radius).has_point(glade):
			continue
		for i: int in FIREFLIES_PER_GLADE:
			var phase: float = g * 31.0 + i * 7.3
			var orbit: float = ctx.arena.firefly_radius * (0.25 + 0.7 * fmod(phase * 0.618, 1.0))
			var angle: float = phase + _time * (0.25 + 0.15 * fmod(phase, 1.0))
			var pos: Vector2 = glade + Vector2.from_angle(angle) * orbit + Vector2(0, sin(_time * 1.7 + phase) * 10.0)
			var glow: float = 0.45 + 0.55 * absf(sin(_time * 2.1 + phase * 1.3))
			_fireflies.draw_circle(pos, 5.0, Color(ctx.arena.firefly_color, 0.18 * glow))
			_fireflies.draw_circle(pos, 1.8, Color(ctx.arena.firefly_color, 0.9 * glow))


## Blizzard : flocons portés par le vent, en traînées pendant les rafales (au-dessus du voile).
func _draw_snow(view: Rect2) -> void:
	var strength: float = gust_strength()
	var drift: Vector2 = Vector2(0.3, 1.0).normalized().lerp(_wind_dir, strength).normalized()
	var speed: float = 60.0 + 360.0 * strength
	var count: int = int(SNOW_FLAKES * (0.4 + 0.6 * strength))
	for i: int in count:
		var seed_x: float = fmod(float(i) * 0.6180339, 1.0)
		var seed_y: float = fmod(float(i) * 0.4142135 + 0.37, 1.0)
		var offset: Vector2 = drift * fmod(_time * speed + float(i) * 53.0, view.size.length())
		var pos: Vector2 = view.position + Vector2(seed_x * view.size.x, seed_y * view.size.y) + offset
		pos = view.position + Vector2(fposmod(pos.x - view.position.x, view.size.x), fposmod(pos.y - view.position.y,
			view.size.y))
		var tail: Vector2 = -drift * (3.0 + 26.0 * strength)
		_fireflies.draw_line(pos, pos + tail, Color(1.0, 1.0, 1.0, 0.35 + 0.35 * strength), 2.0)
