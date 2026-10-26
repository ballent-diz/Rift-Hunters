class_name BossSignatures
extends BossMechanics
## Mécaniques phares des Dévoreurs des chapitres 1 et 2 (docs/design/MONSTRES.md) :
## - Orbes de source (Dévoreur des Sources) : orbes lents qui suivent le Chasseur ; une Ruée dedans les renvoie vers le
##   boss, qui est touché et étourdi (un seul orbe doré étourdit dans une salve). Au contact sans Ruée : dégâts, ralenti.
## - Couronne d'astres (Astravorn) : anneau d'étoiles qui tourne autour du boss avec des brèches, rétrécit et accélère ;
##   de l'extérieur, les coups sont presque tous absorbés. À la fin, les étoiles partent vers l'extérieur.
## - Séquence des cratères (Pyrevorn) : une grille de cases autour du Chasseur ; des cases s'allument une à une, puis
##   entrent en éruption dans le même ordre, à peine annoncées : retenir lesquelles et dans quel ordre.

const ORB := Color(0.45, 0.85, 1.0)
const GOLD := Color(1.0, 0.85, 0.35)
const STAR := Color(0.85, 0.82, 1.0)
const EMBER := Color(1.0, 0.45, 0.12)
const ORB_RADIUS := 22.0
const STAR_RADIUS := 17.0
## Pré-éclair d'une case avant son éruption : visible, trop court pour traverser une case.
const CRATER_FLASH := 0.3

## {"pos", "vel", "speed", "life", "damage", "golden", "reflected", "stun", "ratio"}
var orbs: Array[Dictionary] = []
## Couronne en cours (vide : aucune).
var crown: Dictionary = {}
## Séquence des cratères en cours : cases (Rect2) et étapes {"cell", "lit_at", "erupt_at", "done"}.
var crater_cells: Array[Rect2] = []
var crater_steps: Array[Dictionary] = []
var crater_damage: float = 0.0
## Le bot (joueur moyen) retient la séquence sept fois sur dix.
var _bot_remembers: bool = false


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "BossSignatures"
	ctx.combat.add_damage_modifier(_crown_modifier)


# --- Orbes de source -------------------------------------------------------------------------------------------

func source_orb(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var count: int = int(params.get("count", 1))
	var golden: int = int(params.get("golden", 0))
	var spread: float = float(params.get("spread", 0.55))
	var mouth: Vector2 = brain._mouth()
	var dir: Vector2 = (ctx.player.global_position - mouth).normalized()
	ctx.fx.ring(mouth, 34.0, ORB, pattern.telegraph)
	intro("BOSS_ORB_INTRO")
	for i: int in count:
		var angle: float = (i - (count - 1) * 0.5) * spread
		var orb := {"pos": mouth, "vel": dir.rotated(angle) * float(params.get("speed", 120.0)),
			"speed": float(params.get("speed", 120.0)), "life": float(params.get("life", 7.0)),
			"damage": brain._damage(pattern), "golden": i == golden, "reflected": false,
			"stun": float(params.get("stun", 2.0)), "ratio": float(params.get("reflect_ratio", 0.03))}
		brain.schedule(pattern.telegraph, func() -> void:
			orb["pos"] = brain._mouth()
			orbs.append(orb))
	brain.busy_time = pattern.telegraph + float(params.get("recovery", 0.4))


func _step_orbs(delta: float) -> void:
	var player: Player = ctx.player
	var i: int = orbs.size() - 1
	while i >= 0:
		var orb: Dictionary = orbs[i]
		orb["life"] = float(orb["life"]) - delta
		var keep: bool = true
		if orb["reflected"]:
			var to_boss: Vector2 = boss().position - (orb["pos"] as Vector2)
			orb["vel"] = to_boss.normalized() * float(orb["speed"]) * 4.0
			orb["pos"] = (orb["pos"] as Vector2) + (orb["vel"] as Vector2) * delta
			if to_boss.length() < boss().radius + ORB_RADIUS:
				_orb_hits_boss(orb)
				keep = false
		else:
			var to_player: Vector2 = player.global_position - (orb["pos"] as Vector2)
			var wanted: Vector2 = to_player.normalized() * float(orb["speed"])
			orb["vel"] = (orb["vel"] as Vector2).lerp(wanted, clampf(1.6 * delta, 0.0, 1.0))
			orb["pos"] = (orb["pos"] as Vector2) + (orb["vel"] as Vector2) * delta
			var reach: float = ORB_RADIUS + player.radius
			if to_player.length() < reach + 12.0 and (player.is_dashing() or player.parry_time > 0.0):
				orb["reflected"] = true
				orb["life"] = 4.0
				ctx.fx.burst(orb["pos"], 40.0, Color(ORB, 0.6))
				ctx.stats.add(&"boss_orbs_reflected")
			elif to_player.length() < reach:
				ctx.combat.damage_player(float(orb["damage"]), brain.data.id)
				ctx.stats.add(&"boss_orb_hits")
				player.hinder(1.5, 0.6)
				ctx.fx.burst(orb["pos"], 50.0, Color(ORB, 0.5))
				keep = false
			elif float(orb["life"]) <= 0.0 or ctx.obstacles.blocks_shot(orb["pos"]):
				ctx.fx.burst(orb["pos"], 30.0, Color(ORB, 0.35))
				keep = false
		if not keep:
			orbs.remove_at(i)
		i -= 1


func _orb_hits_boss(orb: Dictionary) -> void:
	strike_boss(float(orb["ratio"]))
	ctx.fx.burst(boss().position, boss().radius * 1.3, Color(GOLD if orb["golden"] else ORB, 0.6))
	if orb["golden"]:
		brain.stun(float(orb["stun"]))


# --- Couronne d'astres -----------------------------------------------------------------------------------------

func star_crown(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var stars: int = int(params.get("stars", 16))
	var gap_count: int = int(params.get("gaps", 2))
	var gap_width: int = int(params.get("gap_width", 2))
	var gaps: Dictionary = {}
	var first: int = ctx.rng.randi() % stars
	for g: int in gap_count:
		for w: int in gap_width:
			gaps[(first + g * stars / gap_count + w) % stars] = true
	crown = {"stars": stars, "gaps": gaps, "angle": ctx.rng.randf() * TAU,
		"start": float(params.get("start_radius", 380.0)), "end": float(params.get("end_radius", 150.0)),
		"radius": float(params.get("start_radius", 380.0)), "spin": float(params.get("spin", 0.8)),
		"spin_end": float(params.get("spin_end", 1.8)), "rise": pattern.telegraph, "total": float(params.get("duration", 9.0)),
		"elapsed": 0.0, "damage": brain._damage(pattern), "outside": float(params.get("outside_mult", 0.15)),
		"burst_speed": float(params.get("burst_speed", 210.0)), "spark": 0.0}
	intro("BOSS_CROWN_INTRO")
	brain.busy_time = pattern.telegraph + 0.3


func crown_active() -> bool:
	return not crown.is_empty() and float(crown["elapsed"]) >= float(crown["rise"])


func star_positions() -> PackedVector2Array:
	var points := PackedVector2Array()
	if crown.is_empty():
		return points
	var stars: int = crown["stars"]
	for s: int in stars:
		if not (crown["gaps"] as Dictionary).has(s):
			points.append(boss().position + Vector2.RIGHT.rotated(float(crown["angle"]) + TAU * s / stars) * float(crown["radius"]))
	return points


func _step_crown(delta: float) -> void:
	if crown.is_empty():
		return
	crown["elapsed"] = float(crown["elapsed"]) + delta
	crown["spark"] = maxf(float(crown["spark"]) - delta, 0.0)
	var t: float = clampf((float(crown["elapsed"]) - float(crown["rise"])) / float(crown["total"]), 0.0, 1.0)
	crown["radius"] = lerpf(crown["start"], crown["end"], t)
	crown["angle"] = float(crown["angle"]) + lerpf(crown["spin"], crown["spin_end"], t) * delta
	if not crown_active():
		return
	var player: Player = ctx.player
	if player.can_be_hurt():
		for point: Vector2 in star_positions():
			if point.distance_to(player.global_position) < STAR_RADIUS + player.radius:
				ctx.combat.damage_player(float(crown["damage"]), brain.data.id)
				ctx.stats.add(&"boss_star_hits")
				break
	if t >= 1.0:
		_burst_crown()


## Fin de la couronne : chaque étoile part vers l'extérieur (rester près du boss protège).
func _burst_crown() -> void:
	for point: Vector2 in star_positions():
		var dir: Vector2 = (point - boss().position).normalized()
		ctx.projectiles.spawn_hostile(point, dir, float(crown["burst_speed"]), float(crown["damage"]) * 0.7,
			brain.data.id, 9.0, 3.0)
	ctx.fx.burst(boss().position, float(crown["radius"]), Color(STAR, 0.4))
	crown = {}


## De l'extérieur de la couronne, les coups contre le boss sont presque tous absorbés.
func _crown_modifier(enemy: Enemy, info: DamageInfo) -> float:
	if not crown_active() or brain == null or enemy != boss() or not info.is_friendly():
		return 1.0
	var source: Vector2 = source_position(info)
	if source.distance_to(enemy.position) <= float(crown["radius"]):
		ctx.stats.add(&"boss_crown_inside_hits")
		return 1.0
	ctx.stats.add(&"boss_crown_absorbed")
	if float(crown["spark"]) <= 0.0:
		crown["spark"] = 0.15
		ctx.fx.spark(enemy.position + (source - enemy.position).normalized() * float(crown["radius"]), STAR, 12.0)
	return float(crown["outside"])


# --- Séquence des cratères -------------------------------------------------------------------------------------

func crater_sequence(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var grid: int = int(params.get("grid", 3))
	var cell: float = float(params.get("cell", 260.0))
	var steps: int = mini(int(params.get("steps", 4)), grid * grid)
	var show_gap: float = float(params.get("show_gap", 0.55))
	var erupt_gap: float = float(params.get("erupt_gap", 0.9))
	var half: float = grid * cell * 0.5
	var area: Rect2 = ctx.arena_rect().grow(-half)
	var center: Vector2 = ctx.player.global_position.clamp(area.position, area.end) if area.has_area() \
		else ctx.player.global_position
	crater_cells.clear()
	for y: int in grid:
		for x: int in grid:
			crater_cells.append(Rect2(center - Vector2(half, half) + Vector2(x, y) * cell, Vector2(cell, cell)))
	var order: Array[int] = []
	for i: int in crater_cells.size():
		order.append(i)
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = ctx.rng.randi() % (i + 1)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	crater_steps.clear()
	var lights_end: float = ctx.time + pattern.telegraph + steps * show_gap
	for k: int in steps:
		crater_steps.append({"cell": order[k], "lit_at": ctx.time + pattern.telegraph + k * show_gap,
			"erupt_at": lights_end + float(params.get("pause", 0.6)) + k * erupt_gap, "done": false})
	crater_damage = brain._damage(pattern)
	_bot_remembers = ctx.rng.randf() < 0.7
	intro("BOSS_CRATER_INTRO")
	brain.busy_time = lights_end - ctx.time + 0.2


func crater_active() -> bool:
	return not crater_steps.is_empty()


func _step_craters() -> void:
	if crater_steps.is_empty():
		return
	var all_done: bool = true
	for step_data: Dictionary in crater_steps:
		if step_data["done"]:
			continue
		if ctx.time >= float(step_data["erupt_at"]):
			step_data["done"] = true
			_erupt(crater_cells[int(step_data["cell"])])
		else:
			all_done = false
	if all_done and ctx.time > float(crater_steps.back()["erupt_at"]) + 0.4:
		crater_steps.clear()
		crater_cells.clear()


func _erupt(cell: Rect2) -> void:
	var player: Player = ctx.player
	if cell.grow(-player.radius * 0.3).has_point(player.global_position):
		ctx.combat.damage_player(crater_damage, brain.data.id)
		ctx.stats.add(&"boss_crater_hits")
	ctx.fx.burst(cell.get_center(), cell.size.x * 0.55, Color(EMBER, 0.55))
	ctx.fx.debris(cell.get_center(), EMBER, 10)
	Audio.play_sfx(&"detonation")


## Case dont l'éruption est encore à venir à cette position (-1 : aucune).
func pending_cell_at(pos: Vector2) -> int:
	for step_data: Dictionary in crater_steps:
		if not step_data["done"] and crater_cells[int(step_data["cell"])].has_point(pos):
			return int(step_data["cell"])
	return -1


func step(delta: float) -> void:
	super.step(delta)
	_step_orbs(delta)
	_step_crown(delta)
	_step_craters()
	queue_redraw()


func finish() -> void:
	orbs.clear()
	crown = {}
	crater_steps.clear()
	crater_cells.clear()
	queue_redraw()


# --- Bot -------------------------------------------------------------------------------------------------------

func danger(pos: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for orb: Dictionary in orbs:
		var away: Vector2 = pos - (orb["pos"] as Vector2)
		if not orb["reflected"] and away.length() < 140.0 and ctx.player.dash_cooldown_left > 0.0:
			result += away.normalized()
	if crown_active():
		for point: Vector2 in star_positions():
			var away: Vector2 = pos - point
			if away.length() < STAR_RADIUS + 40.0:
				result += away.normalized() * 1.5
	# Le bot qui a retenu la séquence quitte les cases encore à venir, une fois les lumières éteintes.
	if _bot_remembers and not crater_steps.is_empty() and ctx.time >= float(crater_steps.back()["lit_at"]):
		if pending_cell_at(pos) >= 0:
			result += (_safe_cell_center(pos) - pos).normalized() * 2.0
	return result


func _safe_cell_center(pos: Vector2) -> Vector2:
	var best := pos
	for i: int in crater_cells.size():
		var center: Vector2 = crater_cells[i].get_center()
		if pending_cell_at(center) < 0 and (best == pos or center.distance_to(pos) < best.distance_to(pos)):
			best = center
	return best


## Orbe à portée et Ruée prête : foncer dedans pour le renvoyer ; couronne : entrer par une brèche.
func bot_move(pos: Vector2) -> Vector2:
	var orb: Dictionary = _orb_near(pos)
	if not orb.is_empty():
		return ((orb["pos"] as Vector2) - pos).normalized()
	if crown_active():
		var distance: float = pos.distance_to(boss().position)
		if distance > float(crown["radius"]):
			var gap: Vector2 = _nearest_gap(pos)
			return (gap - pos).normalized() if pos.distance_to(gap) > 30.0 else (boss().position - pos).normalized()
		# Dedans : rester loin des étoiles qui se resserrent.
		if distance > float(crown["radius"]) - 55.0:
			return (boss().position - pos).normalized()
	return Vector2.ZERO


func bot_dash() -> bool:
	var orb: Dictionary = _orb_near(ctx.player.global_position)
	return not orb.is_empty() and (orb["pos"] as Vector2).distance_to(ctx.player.global_position) < 70.0


func _orb_near(pos: Vector2) -> Dictionary:
	if ctx.player.dash_cooldown_left > 0.0:
		return {}
	for orb: Dictionary in orbs:
		if not orb["reflected"] and (orb["pos"] as Vector2).distance_to(pos) < 160.0:
			return orb
	return {}


func _nearest_gap(pos: Vector2) -> Vector2:
	var stars: int = crown["stars"]
	var best := boss().position
	for s: int in stars:
		if (crown["gaps"] as Dictionary).has(s):
			var point: Vector2 = boss().position + Vector2.RIGHT.rotated(float(crown["angle"]) + TAU * s / stars) \
				* (float(crown["radius"]) + 30.0)
			if best == boss().position or point.distance_to(pos) < best.distance_to(pos):
				best = point
	return best


# --- Dessin ----------------------------------------------------------------------------------------------------

func _draw() -> void:
	for orb: Dictionary in orbs:
		var color: Color = GOLD if orb["golden"] else ORB
		var pulse: float = 0.5 + 0.5 * sin(_time * 8.0)
		draw_circle(orb["pos"], ORB_RADIUS * (1.3 + 0.15 * pulse), Color(color, 0.18))
		draw_circle(orb["pos"], ORB_RADIUS, Color(color, 0.75))
		draw_circle(orb["pos"], ORB_RADIUS * 0.45, Color(1.0, 1.0, 1.0, 0.85))
	if not crown.is_empty():
		var alpha: float = 1.0 if crown_active() else clampf(float(crown["elapsed"]) / maxf(float(crown["rise"]), 0.01), 0.0, 1.0) * 0.5
		draw_arc(boss().position, float(crown["radius"]), 0.0, TAU, 64, Color(STAR, 0.18 * alpha), 2.0)
		for point: Vector2 in star_positions():
			draw_circle(point, STAR_RADIUS * 1.5, Color(STAR, 0.2 * alpha))
			draw_circle(point, STAR_RADIUS, Color(STAR, 0.85 * alpha))
	_draw_craters()


func _draw_craters() -> void:
	if crater_steps.is_empty():
		return
	for cell: Rect2 in crater_cells:
		draw_rect(cell, Color(EMBER, 0.08))
		draw_rect(cell, Color(EMBER, 0.35), false, 2.0)
	for step_data: Dictionary in crater_steps:
		var cell: Rect2 = crater_cells[int(step_data["cell"])]
		var lit: float = ctx.time - float(step_data["lit_at"])
		# Allumage : une case à la fois, qui s'éteint avant la suivante (il faut la retenir).
		if lit >= 0.0 and lit < 0.5:
			draw_rect(cell.grow(-6.0), Color(EMBER, 0.55 * (1.0 - lit / 0.5) + 0.2))
		var left: float = float(step_data["erupt_at"]) - ctx.time
		if not step_data["done"] and left <= CRATER_FLASH:
			draw_rect(cell.grow(-4.0), Color(1.0, 0.85, 0.4, 0.8), false, 4.0)
		if step_data["done"] and left > -0.35:
			draw_rect(cell, Color(1.0, 0.6, 0.2, 0.5 * (1.0 + left / 0.35)))
