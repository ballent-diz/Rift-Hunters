class_name ColdDirector
extends Node2D
## Brique B7 « chaleur des braseros » (chapitre 4, docs/design/CARTES.md) : loin des braseros, le froid monte (jauge
## autour du Chasseur) ; pleine, elle ralentit et blesse. Près d'un brasero allumé, le froid redescend. Le Chaman du
## gel souffle les braseros ; ils se rallument seuls après un délai.

const TICK := 0.5
const FROST := Color(0.7, 0.88, 1.0)
const FIRE := Color(1.0, 0.6, 0.2)

var ctx: RunContext
## Jauge de froid du Chasseur (0 à 100).
var cold: float = 0.0
## Instant où chaque brasero se rallume (0 : allumé).
var out_until: Array[float] = []
var _tick: float = 0.0
var _time: float = 0.0
var _announced := false
## Sprites des braseros (object.brazier : allumé, éteint) ; vide sans feuille, la forme provisoire est dessinée.
var _sprites: Array[AnimatedSprite2D] = []


static func uses_cold(arena: ArenaData) -> bool:
	return arena.cold_rate > 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Cold"
	z_index = -3
	out_until.resize(ctx.arena.braziers.size())
	out_until.fill(0.0)
	var frames: SpriteFrames = Assets.get_sprite_frames(&"object.brazier")
	if frames == null:
		return
	for pos: Vector2 in ctx.arena.braziers:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.centered = false
		sprite.offset = -Assets.anchor(&"object.brazier")
		sprite.scale = Vector2.ONE * Assets.pixel_scale(&"object.brazier")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = pos
		sprite.z_index = 3
		add_child(sprite)
		sprite.play(&"lit")
		_sprites.append(sprite)


func is_lit(index: int) -> bool:
	return ctx.time >= out_until[index]


## Le Chasseur est-il dans la chaleur d'un brasero allumé ?
func warm(pos: Vector2) -> bool:
	for i: int in ctx.arena.braziers.size():
		if is_lit(i) and pos.distance_to(ctx.arena.braziers[i]) <= ctx.arena.brazier_radius:
			return true
	return false


func nearest_lit(pos: Vector2, max_range: float) -> int:
	var best: int = -1
	for i: int in ctx.arena.braziers.size():
		var d: float = pos.distance_to(ctx.arena.braziers[i])
		if is_lit(i) and d <= max_range and (best < 0 or d < pos.distance_to(ctx.arena.braziers[best])):
			best = i
	return best


func snuff(index: int) -> void:
	out_until[index] = ctx.time + ctx.arena.brazier_relight
	ctx.fx.burst(ctx.arena.braziers[index], 80.0, Color(0.5, 0.5, 0.55, 0.6))
	ctx.stats.add(&"braziers_snuffed")


func full() -> bool:
	return cold >= 100.0


func step(delta: float) -> void:
	_time += delta
	var player: Player = ctx.player
	if warm(player.global_position):
		cold = maxf(cold - ctx.arena.cold_recover * delta, 0.0)
	else:
		cold = minf(cold + ctx.arena.cold_rate * delta, 100.0)
		if not _announced and cold >= 50.0:
			_announced = true
			ctx.events.event_started.emit("COLD_INTRO")
	_tick -= delta
	if full() and _tick <= 0.0:
		_tick = TICK
		player.hinder(TICK + 0.1, ctx.arena.cold_hinder)
		ctx.combat.damage_player(ctx.arena.cold_damage * ctx.difficulty.enemy_damage_mult, &"cold")
		ctx.stats.add(&"cold_ticks")
	for i: int in _sprites.size():
		var anim: StringName = &"lit" if is_lit(i) else &"out"
		if _sprites[i].animation != anim:
			_sprites[i].play(anim)
	queue_redraw()


## Bot : quand le froid monte, rejoindre le brasero allumé le plus proche.
func danger(pos: Vector2) -> Vector2:
	if cold < 60.0:
		return Vector2.ZERO
	var index: int = nearest_lit(pos, INF)
	if index < 0:
		return Vector2.ZERO
	var target: Vector2 = ctx.arena.braziers[index]
	if pos.distance_to(target) < ctx.arena.brazier_radius * 0.6:
		return Vector2.ZERO
	return (target - pos).normalized() * (1.0 + (cold - 60.0) / 40.0)


## Chaleur des braseros (le sprite object.brazier est un enfant ; forme provisoire sans feuille) et jauge de froid.
func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
	for i: int in ctx.arena.braziers.size():
		var pos: Vector2 = ctx.arena.braziers[i]
		var sprite: bool = i < _sprites.size()
		if is_lit(i):
			draw_circle(pos, ctx.arena.brazier_radius, Color(FIRE, 0.06 + 0.03 * pulse))
			draw_arc(pos, ctx.arena.brazier_radius, 0.0, TAU, 64, Color(FIRE, 0.35), 2.0)
			if not sprite:
				draw_circle(pos, 16.0 + 3.0 * pulse, Color(FIRE, 0.9))
		else:
			if not sprite:
				draw_circle(pos, 14.0, Color(0.35, 0.36, 0.4, 0.9))
			var left: float = clampf((out_until[i] - ctx.time) / ctx.arena.brazier_relight, 0.0, 1.0)
			draw_arc(pos, 30.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 24, Color(FIRE, 0.6), 2.0)
		if not sprite:
			draw_circle(pos, 9.0, Color(0.42, 0.28, 0.16))
	if cold > 0.0:
		var center: Vector2 = ctx.player.global_position
		var color: Color = Color(FROST, 0.9) if not full() else Color(1.0, 1.0, 1.0, 0.6 + 0.4 * pulse)
		draw_arc(center, 34.0, -PI / 2.0, -PI / 2.0 + TAU * cold / 100.0, 40, color, 4.0)
