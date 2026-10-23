class_name BurnDirector
extends Node2D
## Sol brûlant (carte 6, docs/design/CARTES.md ; mécanique E3 de docs/design/MONSTRES.md) : plaques praticables qui
## blessent tout ce qui s'y tient, Chasseur et Corrompus (sauf boss) — y attirer les hordes. Plaques de la carte
## (ArenaData.burn_plates, peintes sur le décor) et plaques temporaires laissées par des Corrompus (Brute du bûcher).
## La Ruée traverse sans dégâts (invulnérabilité du Chasseur).

const EMBER := Color(1.0, 0.45, 0.12)
## Plaques temporaires visibles au plus (les plus anciennes s'éteignent d'abord).
const MAX_TEMPORARY := 12

var ctx: RunContext
## {"pos": Vector2, "radius": float, "left": float (INF : plaque de la carte), "total": float}
var plates: Array[Dictionary] = []
var _tick: float = 0.0
var _time: float = 0.0


static func uses_burn(arena: ArenaData) -> bool:
	return not arena.burn_plates.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Burn"
	z_index = -3
	for plate: Vector3 in ctx.arena.burn_plates:
		plates.append({"pos": Vector2(plate.x, plate.y), "radius": plate.z, "left": INF, "total": INF})


## Plaque temporaire (technique d'un Corrompu) : brûle pendant duration secondes.
func add_plate(pos: Vector2, radius: float, duration: float) -> void:
	var temporary: Array[Dictionary] = []
	temporary.assign(plates.filter(func(p: Dictionary) -> bool: return float(p["left"]) != INF))
	if temporary.size() >= MAX_TEMPORARY:
		plates.erase(temporary[0])
	plates.append({"pos": pos, "radius": radius, "left": duration, "total": duration})


## Plaque sous ce point (marge : rayon du corps), ou {}.
func plate_at(pos: Vector2, margin: float = 0.0) -> Dictionary:
	for plate: Dictionary in plates:
		if pos.distance_to(plate["pos"]) <= float(plate["radius"]) + margin:
			return plate
	return {}


## Évitement pour le bot : sortir de la plaque par le chemin le plus court.
func danger(pos: Vector2) -> Vector2:
	var plate: Dictionary = plate_at(pos, 24.0)
	if plate.is_empty():
		return Vector2.ZERO
	var away: Vector2 = pos - (plate["pos"] as Vector2)
	return away.normalized() if away.length() > 1.0 else Vector2.RIGHT


func step(delta: float) -> void:
	if plates.is_empty():
		return
	_time += delta
	var i: int = plates.size() - 1
	while i >= 0:
		if float(plates[i]["left"]) != INF:
			plates[i]["left"] = float(plates[i]["left"]) - delta
			if float(plates[i]["left"]) <= 0.0:
				plates.remove_at(i)
		i -= 1
	_tick -= delta
	if _tick <= 0.0:
		_tick = ctx.arena.burn_tick
		_burn()
	queue_redraw()


func _burn() -> void:
	var player: Player = ctx.player
	if not plate_at(player.global_position, player.radius * 0.3).is_empty():
		ctx.combat.damage_player(ctx.arena.burn_damage * ctx.difficulty.enemy_damage_mult, &"burn")
	for plate: Dictionary in plates:
		for enemy: Enemy in ctx.enemies.query_radius(plate["pos"], float(plate["radius"])):
			if not enemy.alive or enemy.is_boss or enemy.is_obstacle:
				continue
			var info := DamageInfo.make(enemy.max_hp * ctx.arena.burn_enemy_ratio, DamageInfo.SourceKind.ENVIRONMENT,
				&"burn")
			ctx.combat.deal_damage(enemy, info)


## Plaques de la carte : déjà peintes, seulement une pulsation discrète du bord. Plaques temporaires : braises dessinées.
func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.0)
	for plate: Dictionary in plates:
		var radius: float = plate["radius"]
		if float(plate["left"]) == INF:
			draw_arc(plate["pos"], radius, 0.0, TAU, 48, Color(EMBER, 0.18 + 0.2 * pulse), 2.0)
			continue
		var fade: float = clampf(float(plate["left"]) / 0.6, 0.0, 1.0)
		draw_circle(plate["pos"], radius, Color(0.25, 0.08, 0.03, 0.45 * fade))
		draw_circle(plate["pos"], radius * (0.55 + 0.1 * pulse), Color(EMBER, 0.28 * fade))
		draw_arc(plate["pos"], radius, 0.0, TAU, 48, Color(EMBER, 0.75 * fade), 2.5)
