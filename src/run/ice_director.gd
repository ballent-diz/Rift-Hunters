class_name IceDirector
extends Node2D
## Glace qui fait glisser (brique B1, chapitre 4, docs/design/CARTES.md). Plaques peintes dans le décor
## (ArenaData.ice_patches, ellipses) : dessus, le Chasseur et les Corrompus gardent leur élan. Accélérer ou retourner
## sa course prend ice_accel_time, lâcher la direction fait glisser ice_glide_time, la vitesse maximale monte de
## ice_speed_mult et la Ruée porte plus loin. Les volants ne touchent pas la glace. Aucun dessin : la glace est peinte.

## Traînée de givre derrière le Chasseur qui glisse : intervalle entre deux éclats et vitesse minimale.
const TRAIL_INTERVAL := 0.07
const TRAIL_MIN_SPEED := 60.0
const TRAIL_COLOR := Color(0.86, 0.95, 1.0, 0.75)

var ctx: RunContext
## Ellipses : centre (x, y) et inverse des demi-axes au carré (z, w), pour un test sans division.
var _ellipses: Array[Vector4] = []
var _bounds := Rect2()
var _trail: float = 0.0
var _announced: bool = false


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "IceDirector"
	for i: int in ctx.arena.ice_patches.size():
		var rect: Rect2 = ctx.arena.ice_patches[i]
		var half: Vector2 = rect.size * 0.5
		_ellipses.append(Vector4(rect.get_center().x, rect.get_center().y, 1.0 / (half.x * half.x),
			1.0 / (half.y * half.y)))
		_bounds = rect if i == 0 else _bounds.merge(rect)


## Vrai si `pos` est sur une plaque de glace.
func on_ice(pos: Vector2) -> bool:
	if not _bounds.has_point(pos):
		return false
	for e: Vector4 in _ellipses:
		var dx: float = pos.x - e.x
		var dy: float = pos.y - e.y
		if dx * dx * e.z + dy * dy * e.w <= 1.0:
			return true
	return false


## Vitesse sur la glace : la vitesse actuelle rejoint la vitesse voulue (déjà majorée par speed_mult) en
## ice_accel_time ; sans direction, elle s'éteint en ice_glide_time. `top` : vitesse maximale de référence.
func glide(current: Vector2, desired: Vector2, top: float, delta: float) -> Vector2:
	if desired.length_squared() > 1.0:
		return current.move_toward(desired, top / maxf(ctx.arena.ice_accel_time, 0.05) * delta)
	return current.move_toward(Vector2.ZERO, top / maxf(ctx.arena.ice_glide_time, 0.05) * delta)


## Corrompu (hors volants) : sur la glace, il garde son élan ; ceux qui foncent dépassent le Chasseur. Référence de
## freinage : sa vitesse de base (une vitesse voulue nulle ne doit pas le faire glisser sans fin).
func slide_enemy(enemy: Enemy, speed: float, delta: float) -> void:
	if enemy.data.flying:
		return
	if on_ice(enemy.position):
		var top: float = maxf(speed, enemy.move_speed) * speed_mult()
		enemy.velocity = glide(enemy.slide, enemy.velocity * speed_mult(), top, delta)
	enemy.slide = enemy.velocity


func speed_mult() -> float:
	return ctx.arena.ice_speed_mult


func dash_mult() -> float:
	return ctx.arena.ice_dash_mult


func step(delta: float) -> void:
	var player: Player = ctx.player
	if not player.alive or not on_ice(player.global_position):
		return
	if not _announced:
		_announced = true
		ctx.events.event_started.emit("ICE_INTRO")
	if player.velocity.length() < TRAIL_MIN_SPEED:
		return
	_trail -= delta
	if _trail <= 0.0:
		_trail = TRAIL_INTERVAL
		ctx.fx.spark(player.global_position + Vector2(0, 6), TRAIL_COLOR, 3.0)
