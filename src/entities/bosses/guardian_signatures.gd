class_name GuardianSignatures
extends BossMechanics
## Mécaniques phares des gardiens de carte (docs/design/MONSTRES.md) :
## - Voile de brume (Chimère des brumes, carte 4) : la Chimère devient brume, intouchable, tant que brûlent les
##   lanternes qu'elle allume autour d'elle (fils de brume visibles). Les briser toutes la fige : sonnée, dégâts ×2.
##   Si le voile tient jusqu'au bout, les lanternes s'éteignent et la Chimère se reforme en reprenant des PV.
## - Charge du bûcher (Gardien du bûcher, carte 6) : il fonce tout droit, loin ; s'il percute un rocher ou une
##   barrière, il s'assomme (sonné, dégâts ×2). Placer un obstacle derrière soi et s'écarter au dernier moment.
## (La Sentinelle des racines a la sienne dans BossController : le séisme, anneaux sans brèche à franchir d'une Ruée.)

const MIST := Color(0.78, 0.86, 1.0)
const EMBER := Color(1.0, 0.5, 0.15)

## Voile en cours : {"until", "heal", "stun", "exposed"} (vide : aucun) et lanternes qui le nourrissent.
var veil: Dictionary = {}
var lanterns: Array[Enemy] = []
## Charge en cours : {"dir", "speed", "start", "until", "damage", "stun", "hit"} (vide : aucune).
var ram: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "GuardianSignatures"
	ctx.combat.add_damage_modifier(_veil_modifier)


func step(delta: float) -> void:
	super.step(delta)
	_step_veil()
	_step_ram(delta)
	queue_redraw()


func finish() -> void:
	_end_veil()
	ram = {}
	queue_redraw()


# --- Voile de brume --------------------------------------------------------------------------------------------

func mist_veil(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var data: EnemyData = GameDB.enemy(StringName(params.get("lantern", "mist_lantern")))
	var count: int = int(params.get("count", 3))
	var distance: float = float(params.get("distance", 380.0))
	var area: Rect2 = ctx.arena_rect().grow(-80.0)
	var offset: float = ctx.rng.randf() * TAU
	var spots: Array[Vector2] = []
	for i: int in count:
		# Point praticable sur le cercle (quelques essais en tournant si un rocher ou l'eau gêne).
		for attempt: int in 8:
			var angle: float = offset + TAU * i / count + attempt * 0.35
			var pos: Vector2 = (boss().position + Vector2.RIGHT.rotated(angle) * distance).clamp(area.position, area.end)
			if ctx.obstacles.distance(pos) >= 30.0:
				spots.append(pos)
				break
	for pos: Vector2 in spots:
		ctx.fx.ring(pos, 30.0, Color(MIST, 0.8), pattern.telegraph)
	brain.schedule(pattern.telegraph, func() -> void:
		if data == null or spots.is_empty():
			return
		lanterns.clear()
		for pos: Vector2 in spots:
			lanterns.append(ctx.enemies.spawn(data, pos))
		veil = {"until": ctx.time + float(params.get("duration", 12.0)), "heal": float(params.get("heal_ratio", 0.04)),
			"stun": float(params.get("stun", 2.5)), "exposed": float(params.get("exposed", 4.0))}
		boss().visual.modulate.a = 0.45
		ctx.fx.burst(boss().position, boss().radius * 2.0, Color(MIST, 0.5)))
	intro("BOSS_VEIL_INTRO")
	brain.busy_time = pattern.telegraph + 0.3


func veiled() -> bool:
	return not veil.is_empty()


func lanterns_alive() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for lantern: Enemy in lanterns:
		if is_instance_valid(lantern) and lantern.alive:
			alive.append(lantern)
	return alive


func _step_veil() -> void:
	if veil.is_empty():
		return
	if lanterns_alive().is_empty():
		# Dernière lanterne brisée : la Chimère se fige, sonnée et vulnérable.
		var stun: float = veil["stun"]
		var exposed: float = veil["exposed"]
		_end_veil()
		brain.stun(stun)
		brain.heart_time = exposed
		ctx.fx.burst(boss().position, boss().radius * 2.5, Color(MIST, 0.6))
		ctx.stats.add(&"boss_veil_broken")
	elif ctx.time >= float(veil["until"]):
		var heal: float = veil["heal"]
		_end_veil()
		boss().hp = minf(boss().max_hp, boss().hp + boss().max_hp * heal)
		ctx.fx.burst(boss().position, boss().radius * 1.5, Color(0.6, 1.0, 0.7, 0.45))
		ctx.stats.add(&"boss_veil_held")


func _end_veil() -> void:
	for lantern: Enemy in lanterns_alive():
		ctx.enemies.marsh.vanish(lantern)
	lanterns.clear()
	veil = {}
	if brain != null and boss() != null:
		boss().visual.modulate.a = 1.0


## Sous le voile, la Chimère n'est que brume : aucun coup ne porte.
func _veil_modifier(enemy: Enemy, info: DamageInfo) -> float:
	if veil.is_empty() or brain == null or enemy != boss() or not info.is_friendly():
		return 1.0
	ctx.fx.spark(enemy.position, MIST, 8.0)
	ctx.stats.add(&"boss_veil_blocked")
	return 0.0


# --- Charge du bûcher ------------------------------------------------------------------------------------------

func pyre_ram(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var dir: Vector2 = (ctx.player.global_position - boss().position).normalized()
	var speed: float = float(params.get("speed", 640.0))
	var length: float = float(params.get("length", 900.0))
	boss().visual.set_facing_left(dir.x < 0.0, true)
	ctx.fx.danger_line(boss().position, boss().position + dir * length, boss().radius * 1.6, pattern.telegraph)
	ram = {"dir": dir, "speed": speed, "start": ctx.time + pattern.telegraph,
		"until": ctx.time + pattern.telegraph + length / speed, "damage": brain._damage(pattern),
		"stun": float(params.get("stun", 3.0)), "hit": false}
	intro("BOSS_RAM_INTRO")
	brain.busy_time = pattern.telegraph + length / speed + float(params.get("recovery", 0.5))


func ramming() -> bool:
	return not ram.is_empty() and ctx.time >= float(ram["start"])


func _step_ram(delta: float) -> void:
	if ram.is_empty() or not ramming():
		return
	if ctx.time >= float(ram["until"]):
		ram = {}
		return
	var dir: Vector2 = ram["dir"]
	var before: Vector2 = boss().position
	boss().position += dir * float(ram["speed"]) * delta
	var front: Vector2 = boss().position + dir * boss().radius * 0.6
	var rect: Rect2 = ctx.arena_rect().grow(-boss().radius)
	if ctx.obstacles.blocks(front, boss().radius * 0.4) or not rect.has_point(boss().position):
		# Percute un rocher, un mur ou le bord : assommé.
		boss().position = ctx.obstacles.push_out(before.clamp(rect.position, rect.end), boss().radius)
		var stun: float = ram["stun"]
		ram = {}
		brain.stun(stun)
		brain.heart_time = stun
		ctx.fx.burst(front, boss().radius * 1.5, Color(EMBER, 0.6))
		ctx.fx.debris(front, EMBER, 14)
		ctx.stats.add(&"boss_ram_stunned")
		return
	var player: Player = ctx.player
	if not ram["hit"] and player.global_position.distance_to(boss().position) < boss().radius + player.radius:
		ram["hit"] = true
		ctx.combat.damage_player(float(ram["damage"]), brain.data.id)
		var side: Vector2 = dir.orthogonal()
		if side.dot(player.global_position - boss().position) < 0.0:
			side = -side
		player.global_position = ctx.obstacles.push_out(player.global_position + side * 70.0, player.radius)
		ctx.stats.add(&"boss_ram_hits")


# --- Bot -------------------------------------------------------------------------------------------------------

## Charge annoncée : s'écarter de l'axe (le bot ne cherche pas à placer un rocher derrière lui).
func danger(pos: Vector2) -> Vector2:
	if ram.is_empty():
		return Vector2.ZERO
	var dir: Vector2 = ram["dir"]
	var to_pos: Vector2 = pos - boss().position
	var along: float = to_pos.dot(dir)
	var side: Vector2 = to_pos - dir * along
	if along > 0.0 and side.length() < boss().radius + 70.0:
		return (side.normalized() if side.length() > 0.5 else dir.orthogonal()) * 2.0
	return Vector2.ZERO


## Voile de brume : aller briser la lanterne la plus proche.
func bot_move(pos: Vector2) -> Vector2:
	if veil.is_empty():
		return Vector2.ZERO
	var best: Enemy = null
	for lantern: Enemy in lanterns_alive():
		if best == null or lantern.position.distance_to(pos) < best.position.distance_to(pos):
			best = lantern
	if best == null or best.position.distance_to(pos) < 220.0:
		return Vector2.ZERO
	return (best.position - pos).normalized()


# --- Dessin ----------------------------------------------------------------------------------------------------

func _draw() -> void:
	if veil.is_empty():
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
	for lantern: Enemy in lanterns_alive():
		draw_line(lantern.position, boss().position, Color(MIST, 0.25 + 0.25 * pulse), 4.0)
		draw_circle(lantern.position, lantern.radius * (1.6 + 0.3 * pulse), Color(MIST, 0.22))
	draw_circle(boss().position, boss().radius * 1.4, Color(MIST, 0.12 + 0.08 * pulse))
