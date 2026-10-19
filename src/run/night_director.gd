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
const FIREFLY_COLOR := Color(0.85, 1.0, 0.45)
const FIREFLIES_PER_GLADE := 18

var ctx: RunContext
var _fireflies: Node2D
var _reveal_timer: float = 0.0
var _time: float = 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Night"
	# Ajouté au monde juste après les Corrompus (même z) : le voile les couvre, pas les Échos ni le Chasseur.
	z_index = 2
	var veil := ShaderMaterial.new()
	veil.shader = VEIL
	veil.set_shader_parameter("darkness", ctx.arena.night)
	material = veil
	_fireflies = Node2D.new()
	_fireflies.z_index = 5
	add_child(_fireflies)
	_fireflies.draw.connect(_draw_fireflies)
	ctx.enemies.visibility = can_target
	_start.call_deferred()


## Une fois la partie construite : annonce (HUD prêt) et effets peints des Échos au-dessus du voile.
func _start() -> void:
	ctx.events.event_started.emit("NIGHT_INTRO")
	if ctx.allies and ctx.allies.vfx.layer:
		ctx.allies.vfx.layer.z_index = 2


## Ennemi visible : éclairé, Révélé, ou boss (toujours visible).
func can_target(enemy: Enemy) -> bool:
	return enemy.is_boss or enemy.statuses.has(&"reveal") or is_lit(enemy.position)


func is_lit(pos: Vector2) -> bool:
	if ctx.player and pos.distance_to(ctx.player.global_position) <= ctx.arena.light_radius:
		return true
	if ctx.allies:
		for ally: Ally in ctx.allies.team:
			if pos.distance_to(ally.global_position) <= ctx.arena.echo_light_radius:
				return true
	for glade: Vector2 in ctx.arena.firefly_glades:
		if pos.distance_to(glade) <= ctx.arena.firefly_radius:
			return true
	return false


## Lumières (x, y, rayon, intensité) : Chasseur, Échos, boss, puis les clairières les plus proches du Chasseur.
func lights() -> PackedVector4Array:
	var result := PackedVector4Array()
	var center: Vector2 = ctx.player.global_position
	result.append(Vector4(center.x, center.y, ctx.arena.light_radius, 1.0))
	for ally: Ally in ctx.allies.team:
		result.append(Vector4(ally.global_position.x, ally.global_position.y, ctx.arena.echo_light_radius, 0.85))
	if ctx.boss and ctx.boss.alive:
		result.append(Vector4(ctx.boss.position.x, ctx.boss.position.y, ctx.boss.radius * 3.0, 0.8))
	var glades: Array[Vector2] = ctx.arena.firefly_glades.duplicate()
	glades.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	for i: int in glades.size():
		if result.size() >= MAX_LIGHTS:
			break
		var flicker: float = 0.88 + 0.08 * sin(_time * 2.3 + i * 1.7)
		result.append(Vector4(glades[i].x, glades[i].y, ctx.arena.firefly_radius, flicker))
	return result


func step(delta: float) -> void:
	_time += delta
	_reveal_timer -= delta
	if _reveal_timer <= 0.0:
		_reveal_timer = REVEAL_INTERVAL
		for glade: Vector2 in ctx.arena.firefly_glades:
			for enemy: Enemy in ctx.enemies.query_radius(glade, ctx.arena.firefly_radius):
				ctx.status_system.apply(enemy, &"reveal", 1, &"firefly")
	var lit: PackedVector4Array = lights()
	(material as ShaderMaterial).set_shader_parameter("lights", lit)
	(material as ShaderMaterial).set_shader_parameter("light_count", lit.size())
	queue_redraw()
	_fireflies.queue_redraw()


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
			_fireflies.draw_circle(pos, 5.0, Color(FIREFLY_COLOR, 0.18 * glow))
			_fireflies.draw_circle(pos, 1.8, Color(FIREFLY_COLOR, 0.9 * glow))

