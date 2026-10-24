class_name RockfallDirector
extends Node2D
## Pluie de roches magmatiques (carte 10, finale du chapitre 2, docs/design/CARTES.md) : des roches tombent au hasard
## autour du Chasseur. Chaque chute est annoncée (ombre qui grandit et cercle au sol), puis la roche s'écrase : dégâts à
## tout le monde, Corrompus compris, et petite plaque de sol brûlant. Plus fréquente à chaque zone nettoyée et pendant
## le combat final.

const ROCK := Color(0.16, 0.11, 0.1)
const MAGMA := Color(1.0, 0.5, 0.12)
## Distance des chutes autour du Chasseur : dans son champ de vision, rarement pile sur lui.
const NEAR := 140.0
const FAR := 620.0
## Part des chutes visées directement sur le Chasseur (le reste tombe autour).
const AIMED_SHARE := 0.3

var ctx: RunContext
## {"pos": Vector2, "left": float (avant l'impact), "total": float}
var falling: Array[Dictionary] = []
var impacts: int = 0
var _timer: float = 0.0


static func uses_rockfall(arena: ArenaData) -> bool:
	return arena.rockfall_interval > 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Rockfall"
	z_index = 3
	_timer = ctx.arena.rockfall_interval * 2.0


## Intervalle courant : plus court à chaque zone nettoyée, et pendant le combat final.
func interval() -> float:
	var value: float = ctx.arena.rockfall_interval
	if ctx.zones:
		value *= pow(ctx.arena.rockfall_zone_mult, ctx.zones.zone_index)
	if ctx.boss != null and ctx.boss.alive:
		value *= ctx.arena.rockfall_boss_mult
	return value


func step(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval()
		drop(_pick_target())
	var i: int = falling.size() - 1
	while i >= 0:
		falling[i]["left"] = float(falling[i]["left"]) - delta
		if float(falling[i]["left"]) <= 0.0:
			_impact(falling[i]["pos"])
			falling.remove_at(i)
		i -= 1
	queue_redraw()


## Annonce une chute à cette position (dégâts au Chasseur par le danger télégraphié, aux Corrompus à l'impact).
func drop(pos: Vector2) -> void:
	var warning: float = ctx.arena.rockfall_warning
	ctx.hazards.add_circle(pos, ctx.arena.rockfall_radius, warning,
		ctx.arena.rockfall_damage * ctx.difficulty.enemy_damage_mult, true, &"rockfall")
	falling.append({"pos": pos, "left": warning, "total": warning})


func _pick_target() -> Vector2:
	var player: Vector2 = ctx.player.global_position
	var area: Rect2 = ctx.arena_rect().grow(-ctx.arena.rockfall_radius)
	for attempt: int in 8:
		var pos: Vector2 = player
		if ctx.rng.randf() >= AIMED_SHARE:
			pos += Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * ctx.rng.randf_range(NEAR, FAR)
		pos = pos.clamp(area.position, area.end)
		if ctx.obstacles.distance(pos) > 0.0:
			return pos
	return player


func _impact(pos: Vector2) -> void:
	impacts += 1
	var radius: float = ctx.arena.rockfall_radius
	for enemy: Enemy in ctx.enemies.query_radius(pos, radius):
		if not enemy.alive or enemy.is_obstacle or enemy.position.distance_to(pos) > radius + enemy.radius:
			continue
		var ratio: float = 0.0 if enemy.is_boss else ctx.arena.rockfall_enemy_ratio
		ctx.combat.deal_damage(enemy, DamageInfo.make(ctx.arena.rockfall_damage + enemy.max_hp * ratio,
			DamageInfo.SourceKind.ENVIRONMENT, &"rockfall"))
	ctx.fx.burst(pos, radius, Color(MAGMA, 0.5))
	ctx.fx.debris(pos, MAGMA, 10)
	if ctx.arena.rockfall_burn_time > 0.0 and ctx.burn:
		ctx.burn.add_plate(pos, radius * 0.7, ctx.arena.rockfall_burn_time)
	ctx.stats.add(&"rockfalls")


## Ombre qui grandit sous la roche, puis la roche qui tombe pendant la dernière demi-seconde.
func _draw() -> void:
	for rock: Dictionary in falling:
		var pos: Vector2 = rock["pos"]
		var progress: float = 1.0 - float(rock["left"]) / maxf(float(rock["total"]), 0.01)
		var radius: float = ctx.arena.rockfall_radius
		draw_circle(pos, radius * (0.25 + 0.55 * progress), Color(0.0, 0.0, 0.0, 0.25 + 0.25 * progress))
		var fall: float = clampf(float(rock["left"]) / 0.5, 0.0, 1.0)
		if fall < 1.0:
			var center: Vector2 = pos + Vector2(0.0, -fall * 420.0)
			draw_circle(center, radius * 0.32, ROCK)
			draw_circle(center, radius * 0.18, MAGMA)
