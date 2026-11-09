class_name StatueDirector
extends Node2D
## Brique B8 « statues qui s'éveillent » (carte 24, docs/maps/PANTHEON_BRISE.md) : une Statue endormie se dresse sur
## chaque socle peint. Quand le Chasseur passe à portée (ou qu'une Gardienne l'appelle), elle tremble, puis descend de
## son socle en Statue éveillée (CityTechniques.awaken). Chaque socle ne s'éveille qu'une fois.

const VISUAL := &"enemy.awakened_statue"
const STONE := Color(0.85, 0.78, 0.62)

var ctx: RunContext
## État de chaque socle : 0 endormie, 1 qui s'éveille, 2 éveillée (socle vide).
var states: Array[int] = []
var _left: Array[float] = []
var _sprites: Array[AnimatedSprite2D] = []
var _time: float = 0.0
var _announced: bool = false


static func uses_statues(arena: ArenaData) -> bool:
	return not arena.statue_plinths.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Statues"
	z_index = 1
	var frames: SpriteFrames = Assets.get_sprite_frames(VISUAL)
	for plinth: Vector2 in ctx.arena.statue_plinths:
		states.append(0)
		_left.append(0.0)
		var sprite: AnimatedSprite2D = null
		if frames:
			sprite = AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.centered = false
			sprite.offset = -Assets.anchor(VISUAL)
			sprite.scale = Vector2.ONE * Assets.pixel_scale(VISUAL)
			sprite.position = plinth + ctx.arena.statue_offset
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.play(&"dormant" if frames.has_animation(&"dormant") else &"idle")
			add_child(sprite)
		_sprites.append(sprite)


func dormant_count() -> int:
	return states.count(0)


## Socle endormi le plus proche de `pos` à moins de `reach` (-1 si aucun).
func nearest_dormant(pos: Vector2, reach: float) -> int:
	var best: int = -1
	for i: int in states.size():
		var d: float = ctx.arena.statue_plinths[i].distance_to(pos)
		if states[i] == 0 and d <= reach and (best < 0 or d < ctx.arena.statue_plinths[best].distance_to(pos)):
			best = i
	return best


## Lance l'éveil d'un socle : il tremble `warning` secondes, puis la Statue descend.
func wake(index: int, warning: float = -1.0) -> bool:
	if index < 0 or states[index] != 0:
		return false
	states[index] = 1
	_left[index] = ctx.arena.statue_warning if warning < 0.0 else warning
	if _sprites[index]:
		_sprites[index].play(&"awaken")
	if not _announced:
		_announced = true
		ctx.events.event_started.emit("STATUES_INTRO")
	return true


func step(delta: float) -> void:
	_time += delta
	var player: Vector2 = ctx.player.global_position
	for i: int in states.size():
		match states[i]:
			0:
				if ctx.player.alive and ctx.arena.statue_plinths[i].distance_to(player) <= ctx.arena.statue_awaken_radius:
					wake(i)
			1:
				_left[i] -= delta
				if _sprites[i]:
					_sprites[i].position = ctx.arena.statue_plinths[i] + ctx.arena.statue_offset \
						+ Vector2(sin(_time * 40.0) * 2.0, 0.0)
				if _left[i] <= 0.0:
					_descend(i)
	queue_redraw()


func _descend(index: int) -> void:
	states[index] = 2
	if _sprites[index]:
		_sprites[index].visible = false
	var statue: EnemyData = GameDB.enemy(ctx.arena.statue_enemy)
	if statue == null or ctx.city == null:
		return
	var plinth: Vector2 = ctx.arena.statue_plinths[index]
	var toward: Vector2 = (ctx.player.global_position - plinth).normalized()
	var pos: Vector2 = ctx.obstacles.push_out(plinth + toward * (statue.radius + 60.0), statue.radius)
	ctx.city.awaken(statue, pos, 0.8)


func _draw() -> void:
	if ctx == null:
		return
	for i: int in states.size():
		if states[i] == 1:
			var pulse: float = 0.5 + 0.5 * sin(_time * 14.0)
			draw_arc(ctx.arena.statue_plinths[i], 80.0, 0.0, TAU, 32, Color(STONE, 0.4 + 0.5 * pulse), 3.0)
