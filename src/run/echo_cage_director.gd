class_name EchoCageDirector
extends Node2D
## Brique B10 « Échos piégés » (carte 24, objectif facultatif) : des cages runiques retiennent des Échos. Rester dans
## le cercle d'une cage la brise peu à peu (la jauge retombe dehors) ; l'ouvrir attire une embuscade d'Ombres
## déchirées. Libérée, la cage rend des PV et laisse un coffre.

const RUNE := Color(0.85, 0.45, 1.0)
const ECHO := Color(0.6, 0.95, 1.0)

var ctx: RunContext
## Avancement de chaque cage (0 à 1), -1 une fois libérée.
var progress: Array[float] = []
var _ambushed: Array[bool] = []
var _time: float = 0.0
var _announced: bool = false


static func uses_cages(arena: ArenaData) -> bool:
	return not arena.echo_cages.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "EchoCages"
	z_index = 1
	for i: int in ctx.arena.echo_cages.size():
		progress.append(0.0)
		_ambushed.append(false)


func freed() -> int:
	return progress.count(-1.0)


func step(delta: float) -> void:
	_time += delta
	var player: Vector2 = ctx.player.global_position
	for i: int in progress.size():
		if progress[i] < 0.0:
			continue
		var cage: Vector2 = ctx.arena.echo_cages[i]
		var near: float = cage.distance_to(player)
		if not _announced and near <= ctx.arena.echo_cage_radius * 3.0:
			_announced = true
			ctx.events.event_started.emit("ECHO_CAGE_INTRO")
		if ctx.player.alive and near <= ctx.arena.echo_cage_radius:
			if not _ambushed[i]:
				_ambushed[i] = true
				_ambush(cage)
			progress[i] += delta / maxf(ctx.arena.echo_cage_time, 0.1)
			if progress[i] >= 1.0:
				_free(i)
		else:
			progress[i] = maxf(progress[i] - delta / maxf(ctx.arena.echo_cage_time * 2.0, 0.1), 0.0)
	queue_redraw()


func _ambush(cage: Vector2) -> void:
	var data: EnemyData = GameDB.enemy(ctx.arena.echo_cage_ambush)
	if data == null:
		return
	for k: int in ctx.arena.echo_cage_ambush_count:
		var pos: Vector2 = ctx.obstacles.push_out(cage + Vector2.RIGHT.rotated(TAU * k / ctx.arena.echo_cage_ambush_count) * 260.0,
			data.radius)
		ctx.fx.burst(pos, 50.0, Color(RUNE, 0.6))
		ctx.enemies.spawn(data, pos)


func _free(index: int) -> void:
	progress[index] = -1.0
	var cage: Vector2 = ctx.arena.echo_cages[index]
	ctx.fx.burst(cage, 140.0, Color(ECHO, 0.7))
	ctx.fx.ring(cage, 220.0, Color(ECHO, 0.6), 0.6)
	ctx.player.heal(ctx.player.max_hp * ctx.arena.echo_cage_heal)
	ctx.pickups.spawn_chest(cage)
	ctx.stats.add(&"echoes_freed")
	ctx.events.event_started.emit(TranslationServer.translate("ECHO_CAGE_FREED") % [freed(), progress.size()])


func _draw() -> void:
	if ctx == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	for i: int in progress.size():
		if progress[i] < 0.0:
			continue
		var cage: Vector2 = ctx.arena.echo_cages[i]
		var radius: float = ctx.arena.echo_cage_radius
		draw_circle(cage, radius, Color(0.12, 0.04, 0.2, 0.35))
		draw_arc(cage, radius, 0.0, TAU, 48, Color(RUNE, 0.5 + 0.3 * pulse), 2.0)
		# Écho prisonnier : silhouette lumineuse derrière les barreaux.
		draw_circle(cage + Vector2(0, -30), 16.0 + 2.0 * pulse, Color(ECHO, 0.55))
		draw_circle(cage + Vector2(0, -30), 8.0, Color(ECHO, 0.9))
		for k: int in 7:
			var x: float = -36.0 + 12.0 * k
			draw_line(cage + Vector2(x, -72), cage + Vector2(x, 6), Color(RUNE.darkened(0.2), 0.95), 3.0)
		draw_line(cage + Vector2(-40, -72), cage + Vector2(40, -72), Color(RUNE.darkened(0.3), 0.95), 4.0)
		draw_line(cage + Vector2(-40, 6), cage + Vector2(40, 6), Color(RUNE.darkened(0.3), 0.95), 4.0)
		if progress[i] > 0.0:
			draw_arc(cage, radius + 8.0, -PI / 2.0, -PI / 2.0 + TAU * progress[i], 48, Color(ECHO, 0.95), 5.0)
