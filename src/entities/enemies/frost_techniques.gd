class_name FrostTechniques
extends Node2D
## Techniques des Corrompus du chapitre 4, le Glacier silencieux (docs/design/MONSTRES.md, E18 à E22), appelées par
## EnemyManager (technique_<kind> ici quand le gestionnaire n'a pas _technique_<kind>). Les effets qui durent (boules
## de neige, cercles de silence, tourbillons, prison) vivent dans ce nœud (RunContext.frost), mis à jour par la partie.

const ICE := Color(0.75, 0.92, 1.0)
const HUSH := Color(0.62, 0.45, 1.0)

var ctx: RunContext
var m: EnemyManager
## Boules de neige qui roulent : {"pos", "dir", "speed", "radius", "grow", "max", "damage", "until", "hit", "source"}.
var snowballs: Array[Dictionary] = []
## Cercles de silence : {"source": Enemy, "radius", "until"}.
var hushes: Array[Dictionary] = []
## Tourbillons de blizzard : {"pos", "radius", "until", "speed"}.
var vortexes: Array[Dictionary] = []
## Prison de glace sur le Chasseur : secondes restantes (la Ruée la brise).
var prison_time: float = 0.0
## Dernier sort lancé par le Chasseur (écho des sorts) : identifiant et instant.
var last_spell: StringName = &""
var last_spell_time: float = -999.0
var _time: float = 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	m = ctx.enemies
	name = "Frost"
	z_index = 3
	ctx.events.spell_cast.connect(func(id: StringName) -> void:
		last_spell = id
		last_spell_time = ctx.time)


func step(delta: float) -> void:
	_time += delta
	_step_prison(delta)
	_step_snowballs(delta)
	_step_hushes()
	_step_vortexes(delta)
	queue_redraw()


# --- Prison de glace (E18) -------------------------------------------------------------------------------------

## Prison de glace (Chaman du gel) : un bloc se forme sous le Chasseur ; s'il y est encore, il est figé sur place
## jusqu'à ce qu'il brise la glace d'une Ruée (ou que la glace fonde).
func technique_ice_prison(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	if prison_time > 0.0:
		return false
	var radius: float = float(technique.params.get("radius", 70.0))
	enemy.technique_busy = technique.telegraph
	ctx.fx.ring(player_pos, radius, Color(ICE, 0.9), technique.telegraph)
	m._later(enemy, technique.telegraph, func() -> void:
		if ctx.player.alive and ctx.player.global_position.distance_to(player_pos) <= radius + ctx.player.radius:
			imprison(float(technique.params.get("duration", 2.5)))
			ctx.combat.damage_player(m._scaled(enemy, technique.damage), enemy.data.id))
	return true


func imprison(duration: float) -> void:
	prison_time = duration
	ctx.player.hinder(duration, 0.0)
	ctx.fx.burst(ctx.player.global_position, 40.0, Color(ICE, 0.7))
	ctx.stats.add(&"ice_prisons")
	if ctx.stats.get_value(&"ice_prisons") == 1.0:
		ctx.events.event_started.emit("ICE_PRISON_INTRO")


func imprisoned() -> bool:
	return prison_time > 0.0


func _step_prison(delta: float) -> void:
	if prison_time <= 0.0:
		return
	if ctx.player.is_dashing():
		# La Ruée brise la glace.
		prison_time = 0.0
		ctx.player.release_hinder()
		ctx.fx.debris(ctx.player.global_position, ICE, 12)
		ctx.stats.add(&"ice_prisons_broken")
		return
	prison_time = maxf(prison_time - delta, 0.0)


# --- Brume glaciale ---------------------------------------------------------------------------------------------

## Brume glaciale : nappe de givre sous le Chasseur qui le ralentit fortement (sans dégâts).
func technique_frost_mist(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	if ctx.burn == null:
		return false
	enemy.technique_busy = technique.telegraph
	m._later(enemy, technique.telegraph, func() -> void:
		ctx.burn.add_plate(player_pos, float(technique.params.get("radius", 130.0)),
			float(technique.params.get("duration", 6.0)), false, float(technique.params.get("hinder", 0.5)))
		ctx.fx.burst(player_pos, float(technique.params.get("radius", 130.0)), Color(ICE, 0.35)))
	return true


# --- Avalanche (E19) --------------------------------------------------------------------------------------------

## Avalanche (Yéti des cimes) : une boule de neige roule vers le Chasseur et grossit ; elle éclate contre le décor.
func technique_avalanche(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	var dir: Vector2 = (player_pos - enemy.position).normalized()
	enemy.technique_busy = technique.telegraph
	ctx.fx.danger_line(enemy.position, enemy.position + dir * 700.0, 40.0, technique.telegraph)
	m._later(enemy, technique.telegraph, func() -> void:
		snowballs.append({"pos": enemy.position + dir * (enemy.radius + 20.0), "dir": dir,
			"speed": float(technique.params.get("speed", 260.0)), "radius": float(technique.params.get("radius", 18.0)),
			"grow": float(technique.params.get("grow", 22.0)), "max": float(technique.params.get("max_radius", 70.0)),
			"damage": m._scaled(enemy, technique.damage), "until": ctx.time + float(technique.params.get("life", 4.0)),
			"hit": false, "source": enemy.data.id}))
	return true


func _step_snowballs(delta: float) -> void:
	var i: int = snowballs.size() - 1
	while i >= 0:
		var ball: Dictionary = snowballs[i]
		ball["pos"] = (ball["pos"] as Vector2) + (ball["dir"] as Vector2) * float(ball["speed"]) * delta
		ball["radius"] = minf(float(ball["radius"]) + float(ball["grow"]) * delta, float(ball["max"]))
		var pos: Vector2 = ball["pos"]
		var radius: float = ball["radius"]
		var player: Player = ctx.player
		if not ball["hit"] and player.global_position.distance_to(pos) < radius + player.radius:
			ball["hit"] = true
			ctx.combat.damage_player(float(ball["damage"]) * (0.6 + 0.4 * radius / float(ball["max"])), ball["source"])
			player.global_position = ctx.obstacles.push_out(player.global_position + (ball["dir"] as Vector2) * 60.0,
				player.radius)
		if ctx.time >= float(ball["until"]) or ctx.obstacles.distance(pos) < radius * 0.5 \
				or not ctx.arena_rect().has_point(pos):
			ctx.fx.burst(pos, radius * 1.4, Color(ICE, 0.5))
			ctx.fx.debris(pos, ICE, 10)
			snowballs.remove_at(i)
		i -= 1


# --- Grêle ------------------------------------------------------------------------------------------------------

## Pluie de grêle (Archère du givre) : grêlons annoncés autour du Chasseur.
func technique_hail(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	var count: int = int(technique.params.get("count", 5))
	var radius: float = float(technique.params.get("radius", 70.0))
	var spread: float = float(technique.params.get("spread", 220.0))
	enemy.technique_busy = 0.6
	for i: int in count:
		var pos: Vector2 = player_pos if i == 0 else player_pos + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) \
			* ctx.rng.randf_range(radius, spread)
		ctx.hazards.add_circle(pos, radius, technique.telegraph, m._scaled(enemy, technique.damage), true, enemy.data.id)
	return true


# --- Silence (E20) ----------------------------------------------------------------------------------------------

## Silence (Héraut du silence) : un cercle autour de l'élite où les sorts du Chasseur ne partent plus.
func technique_hush(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	var radius: float = float(technique.params.get("radius", 280.0))
	if enemy.position.distance_to(ctx.player.global_position) > radius * 1.5:
		return false
	enemy.technique_busy = technique.telegraph
	ctx.fx.ring(enemy.position, radius, Color(HUSH, 0.8), technique.telegraph)
	m._later(enemy, technique.telegraph, func() -> void:
		hushes.append({"source": enemy, "radius": radius, "until": ctx.time + float(technique.params.get("duration", 5.0))})
		if ctx.stats.get_value(&"hushes") == 0.0:
			ctx.events.event_started.emit("HUSH_INTRO")
		ctx.stats.add(&"hushes"))
	return true


## Le Chasseur est-il dans un cercle de silence (ses sorts ne partent pas) ?
func silenced(pos: Vector2) -> bool:
	for hush: Dictionary in hushes:
		var source: Variant = hush["source"]
		if is_instance_valid(source) and pos.distance_to((source as Enemy).position) <= float(hush["radius"]):
			return true
	return false


func _step_hushes() -> void:
	var i: int = hushes.size() - 1
	while i >= 0:
		var source: Variant = hushes[i]["source"]
		if ctx.time >= float(hushes[i]["until"]) or not is_instance_valid(source) or not (source as Enemy).alive:
			hushes.remove_at(i)
		i -= 1


# --- Écho des sorts (E21) ---------------------------------------------------------------------------------------

## Écho des sorts (Héraut du silence) : il aspire la trace du dernier sort du Chasseur (s'il date de moins de
## `memory` secondes) et la renvoie en gerbe de tirs violets.
func technique_spell_echo(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	if ctx.time - last_spell_time > float(technique.params.get("memory", 8.0)):
		return false
	enemy.technique_busy = technique.telegraph + 0.3
	ctx.fx.ring(enemy.position, enemy.radius * 2.0, Color(HUSH, 0.9), technique.telegraph)
	last_spell_time = -999.0
	m._later(enemy, technique.telegraph, func() -> void:
		var dir: Vector2 = (ctx.player.global_position - enemy.position).normalized()
		var count: int = int(technique.params.get("count", 5))
		var spread: float = deg_to_rad(float(technique.params.get("spread", 40.0)))
		for i: int in count:
			var angle: float = 0.0 if count == 1 else lerpf(-spread * 0.5, spread * 0.5, i / float(count - 1))
			ctx.projectiles.spawn_hostile(enemy.position + dir * (enemy.radius + 6.0), dir.rotated(angle),
				float(technique.params.get("speed", 340.0)), m._scaled(enemy, technique.damage), enemy.data.id, 10.0, 2.5)
		enemy.visual.play_action(&"spell_echo")
		ctx.stats.add(&"spell_echoes"))
	return true


# --- Blizzard ---------------------------------------------------------------------------------------------------

## Appel du blizzard (Sorcière des neiges) : un tourbillon de neige suit lentement le Chasseur ; dedans, il est
## ralenti et repoussé vers le bord.
func technique_blizzard_call(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	if vortexes.size() >= int(technique.params.get("max_active", 2)):
		return false
	enemy.technique_busy = technique.telegraph
	var pos: Vector2 = player_pos + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * 160.0
	ctx.fx.ring(pos, float(technique.params.get("radius", 150.0)), Color(ICE, 0.7), technique.telegraph)
	m._later(enemy, technique.telegraph, func() -> void:
		vortexes.append({"pos": pos, "radius": float(technique.params.get("radius", 150.0)),
			"until": ctx.time + float(technique.params.get("duration", 6.0)),
			"speed": float(technique.params.get("speed", 80.0))}))
	return true


func _step_vortexes(delta: float) -> void:
	var player: Player = ctx.player
	var i: int = vortexes.size() - 1
	while i >= 0:
		var vortex: Dictionary = vortexes[i]
		if ctx.time >= float(vortex["until"]):
			vortexes.remove_at(i)
			i -= 1
			continue
		var pos: Vector2 = vortex["pos"]
		vortex["pos"] = pos + (player.global_position - pos).limit_length(float(vortex["speed"]) * delta)
		var away: Vector2 = player.global_position - pos
		if away.length() < float(vortex["radius"]):
			player.hinder(0.3, 0.6)
			if not player.is_dashing():
				player.global_position = ctx.obstacles.push_out(player.global_position
					+ (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * 50.0 * delta, player.radius)
		i -= 1


# --- Fissure de banquise (E22) ----------------------------------------------------------------------------------

## Fissure de banquise (Mammouth de givre) : frappe du sol qui ouvre une ligne de glace brisée vers le Chasseur ;
## la fissure blesse puis reste un moment, glissante et lente à traverser.
func technique_ice_crack(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	var dir: Vector2 = (player_pos - enemy.position).normalized()
	var length: float = float(technique.params.get("length", 520.0))
	var step: float = float(technique.params.get("step", 90.0))
	var radius: float = float(technique.params.get("radius", 60.0))
	enemy.technique_busy = technique.telegraph + 0.3
	ctx.fx.danger_line(enemy.position, enemy.position + dir * length, radius * 2.0, technique.telegraph)
	var d: float = enemy.radius + radius
	while d <= length:
		var pos: Vector2 = enemy.position + dir * d
		ctx.hazards.add_circle(pos, radius, technique.telegraph, m._scaled(enemy, technique.damage), true, enemy.data.id)
		if ctx.burn:
			m._later(enemy, technique.telegraph, func() -> void:
				ctx.burn.add_plate(pos, radius, float(technique.params.get("duration", 5.0)), false,
					float(technique.params.get("hinder", 0.6))))
		d += step
	return true


# --- Piétinement -----------------------------------------------------------------------------------------------

## Charge du Mammouth de givre (E6) suivie de l'armure qui éclate (E8) : flanc découvert `expose` secondes.
func technique_trample(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	if not m._technique_charge(enemy, technique, player_pos):
		return false
	var expose: float = float(technique.params.get("expose", 2.0))
	enemy.technique_busy += expose
	m._later(enemy, technique.telegraph + float(technique.params.get("duration", 0.6)), func() -> void:
		enemy.extra_damage_taken = float(technique.params.get("expose_mult", 1.8))
		enemy.visual.play_action(StringName(technique.params.get("expose_anim", "armor_break")))
		ctx.fx.debris(enemy.position, ICE, 12))
	m._later(enemy, technique.telegraph + float(technique.params.get("duration", 0.6)) + expose, func() -> void:
		enemy.extra_damage_taken = 1.0)
	return true


# --- Braseros ---------------------------------------------------------------------------------------------------

## Souffle des braseros (trait du Chaman du gel) : éteint le brasero allumé le plus proche à portée.
func technique_snuff(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	if ctx.cold == null:
		return false
	var index: int = ctx.cold.nearest_lit(enemy.position, technique.max_range)
	if index < 0:
		return false
	enemy.technique_busy = technique.telegraph
	m._later(enemy, technique.telegraph, func() -> void:
		ctx.cold.snuff(index))
	return true


# --- Bot et dessin ----------------------------------------------------------------------------------------------

## Bot : s'écarter des boules de neige et des tourbillons.
func danger(pos: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for ball: Dictionary in snowballs:
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(pos, ball["pos"],
			(ball["pos"] as Vector2) + (ball["dir"] as Vector2) * 400.0)
		var away: Vector2 = pos - closest
		if away.length() < float(ball["radius"]) + 50.0:
			push += (away.normalized() if away.length() > 0.5 else (ball["dir"] as Vector2).orthogonal()) * 1.5
	for vortex: Dictionary in vortexes:
		var away: Vector2 = pos - (vortex["pos"] as Vector2)
		if away.length() < float(vortex["radius"]) + 40.0:
			push += away.normalized() * 1.2
	return push


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
	for ball: Dictionary in snowballs:
		draw_circle(ball["pos"], float(ball["radius"]), Color(0.92, 0.96, 1.0, 0.95))
		draw_arc(ball["pos"], float(ball["radius"]), 0.0, TAU, 24, Color(ICE.darkened(0.3), 0.8), 2.0)
	for hush: Dictionary in hushes:
		var source: Variant = hush["source"]
		if is_instance_valid(source):
			var center: Vector2 = (source as Enemy).position
			draw_circle(center, float(hush["radius"]), Color(HUSH, 0.07))
			draw_arc(center, float(hush["radius"]), 0.0, TAU, 64, Color(HUSH, 0.5 + 0.3 * pulse), 3.0)
	for vortex: Dictionary in vortexes:
		var center: Vector2 = vortex["pos"]
		var radius: float = vortex["radius"]
		for k: int in 3:
			var start: float = _time * 3.0 + k * TAU / 3.0
			draw_arc(center, radius * (0.4 + 0.2 * k), start, start + 2.2, 16, Color(ICE, 0.45), 3.0)
	if prison_time > 0.0:
		var pos: Vector2 = ctx.player.global_position
		draw_rect(Rect2(pos - Vector2(26, 34), Vector2(52, 60)), Color(ICE, 0.35))
		draw_rect(Rect2(pos - Vector2(26, 34), Vector2(52, 60)), Color(ICE, 0.9), false, 2.0)
