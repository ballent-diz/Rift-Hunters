class_name CityTechniques
extends Node2D
## Techniques des Corrompus du chapitre 5, la Cité de la Faille (docs/design/MONSTRES.md, E23 à E29) : Déchus et
## Enfants de la Faille. Appelées par EnemyManager (technique_<kind> ici quand ni le gestionnaire ni FrostTechniques
## ne l'ont). Les effets qui durent (liens d'âme, sceaux de corruption, cris de ralliement) vivent dans ce nœud
## (RunContext.city), mis à jour par la partie.

const CORRUPTION := Color(0.78, 0.28, 0.92)
const STONE := Color(0.78, 0.74, 0.66)
const TICK := 0.5

var ctx: RunContext
var m: EnemyManager
## Liens d'âme : {"source": Enemy, "links": Array[Enemy], "until", "mult"}.
var soul_links: Array[Dictionary] = []
## Sceaux de corruption : {"pos", "radius", "until", "damage", "tick", "source"}.
var seals: Array[Dictionary] = []
## Ralliements : {"enemy": Enemy, "until", "speed", "damage"} (valeurs ajoutées, retirées à la fin).
var rallies: Array[Dictionary] = []
var _time: float = 0.0
var _drawn: bool = false


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	m = ctx.enemies
	name = "City"
	z_index = -2


func step(delta: float) -> void:
	_time += delta
	_step_links()
	_step_seals(delta)
	_step_rallies()
	var busy: bool = not soul_links.is_empty() or not seals.is_empty()
	if busy or _drawn:
		queue_redraw()
	_drawn = busy


# --- Carreau corrompu (E23, Arbalétrier déchu) ------------------------------------------------------------------

## Il épaule (ligne annoncée, visée verrouillée), puis tire un carreau rapide qui traverse la foule jusqu'au décor.
func technique_corrupted_bolt(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	var dir: Vector2 = (player_pos - enemy.position).normalized()
	var reach: float = float(technique.params.get("length", 700.0))
	enemy.technique_busy = technique.telegraph + 0.2
	enemy.aim_dir = dir
	ctx.fx.danger_line(enemy.position, enemy.position + dir * reach, 26.0, technique.telegraph)
	m._later(enemy, technique.telegraph, func() -> void:
		ctx.projectiles.spawn_hostile(enemy.position + dir * (enemy.radius + 6.0), dir,
			float(technique.params.get("speed", 900.0)), m._scaled(enemy, technique.damage), enemy.data.id, 10.0,
			reach / float(technique.params.get("speed", 900.0))))
	return true


# --- Cri de ralliement (E24, Capitaine déchu) -------------------------------------------------------------------

## Les Déchus proches accélèrent et frappent plus fort pendant `duration` secondes.
func technique_rally(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	var radius: float = float(technique.params.get("radius", 300.0))
	var speed_mult: float = float(technique.params.get("speed_mult", 1.35))
	var damage_mult: float = float(technique.params.get("damage_mult", 1.3))
	var until: float = ctx.time + technique.telegraph + float(technique.params.get("duration", 5.0))
	enemy.technique_busy = technique.telegraph
	ctx.fx.ring(enemy.position, radius, Color(CORRUPTION, 0.6), technique.telegraph + 0.3)
	m._later(enemy, technique.telegraph, func() -> void:
		var count: int = 0
		for ally: Enemy in ctx.enemies.query_radius(enemy.position, radius):
			if not ally.alive or ally.is_boss or ally.is_obstacle or _rallied(ally):
				continue
			var extra_speed: float = ally.move_speed * (speed_mult - 1.0)
			var extra_damage: float = ally.contact_damage * (damage_mult - 1.0)
			ally.move_speed += extra_speed
			ally.contact_damage += extra_damage
			rallies.append({"enemy": ally, "until": until, "speed": extra_speed, "damage": extra_damage})
			count += 1
		if count > 0:
			ctx.stats.add(&"rallies"))
	return true


func _rallied(enemy: Enemy) -> bool:
	for rally: Dictionary in rallies:
		if rally["enemy"] == enemy:
			return true
	return false


func rallied(enemy: Enemy) -> bool:
	return _rallied(enemy)


func _step_rallies() -> void:
	var i: int = rallies.size() - 1
	while i >= 0:
		var rally: Dictionary = rallies[i]
		var ally: Variant = rally["enemy"]
		if not is_instance_valid(ally) or not (ally as Enemy).alive:
			rallies.remove_at(i)
		elif ctx.time >= float(rally["until"]):
			(ally as Enemy).move_speed -= float(rally["speed"])
			(ally as Enemy).contact_damage -= float(rally["damage"])
			rallies.remove_at(i)
		i -= 1


# --- Lien d'âme (E25, Héraldiste de la Faille) ------------------------------------------------------------------

## Lie jusqu'à `count` Corrompus proches : tant que l'Héraldiste vit et que le lien dure, ils ne subissent qu'une part
## des dégâts (mult). L'abattre rompt tous ses liens.
func technique_soul_link(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	for link: Dictionary in soul_links:
		if link["source"] == enemy:
			return false
	var radius: float = float(technique.params.get("radius", 320.0))
	var count: int = int(technique.params.get("count", 4))
	var mult: float = float(technique.params.get("mult", 0.4))
	var allies: Array[Enemy] = []
	for ally: Enemy in ctx.enemies.query_radius(enemy.position, radius):
		if allies.size() >= count:
			break
		if ally == enemy or not ally.alive or ally.is_boss or ally.is_obstacle or linked(ally):
			continue
		allies.append(ally)
	if allies.is_empty():
		return false
	enemy.technique_busy = technique.telegraph
	m._later(enemy, technique.telegraph, func() -> void:
		var kept: Array[Enemy] = []
		for ally: Enemy in allies:
			if ally.alive:
				ally.extra_damage_taken = mult
				kept.append(ally)
		soul_links.append({"source": enemy, "links": kept, "until": ctx.time + float(technique.params.get("duration", 6.0)),
			"mult": mult})
		if not ctx.stats.counters.has(&"soul_links"):
			ctx.events.event_started.emit("SOUL_LINK_INTRO")
		ctx.stats.add(&"soul_links"))
	return true


func linked(enemy: Enemy) -> bool:
	for link: Dictionary in soul_links:
		if (link["links"] as Array).has(enemy):
			return true
	return false


func _step_links() -> void:
	var i: int = soul_links.size() - 1
	while i >= 0:
		var link: Dictionary = soul_links[i]
		var source: Variant = link["source"]
		var broken: bool = not is_instance_valid(source) or not (source as Enemy).alive or ctx.time >= float(link["until"])
		if broken:
			for ally: Variant in link["links"]:
				if is_instance_valid(ally) and is_equal_approx((ally as Enemy).extra_damage_taken, float(link["mult"])):
					(ally as Enemy).extra_damage_taken = 1.0
			soul_links.remove_at(i)
		i -= 1


# --- Sceau de corruption (E26, Héraldiste de la Faille) ---------------------------------------------------------

## Un sceau se trace sous le Chasseur ; à la fin de l'alerte, il frappe puis reste au sol et ronge qui s'y tient.
func technique_corruption_seal(enemy: Enemy, technique: EnemyTechniqueData, player_pos: Vector2) -> bool:
	var radius: float = float(technique.params.get("radius", 110.0))
	var damage: float = m._scaled(enemy, technique.damage)
	enemy.technique_busy = technique.telegraph
	ctx.hazards.add_circle(player_pos, radius, technique.telegraph, damage, true, enemy.data.id)
	m._later(enemy, technique.telegraph, func() -> void:
		seals.append({"pos": player_pos, "radius": radius, "until": ctx.time + float(technique.params.get("duration", 5.0)),
			"damage": damage * float(technique.params.get("dot_ratio", 0.25)), "tick": 0.0, "source": enemy.data.id}))
	return true


func in_seal(pos: Vector2) -> bool:
	for seal: Dictionary in seals:
		if pos.distance_to(seal["pos"]) <= float(seal["radius"]):
			return true
	return false


func _step_seals(delta: float) -> void:
	var i: int = seals.size() - 1
	while i >= 0:
		var seal: Dictionary = seals[i]
		if ctx.time >= float(seal["until"]):
			seals.remove_at(i)
		else:
			seal["tick"] = float(seal["tick"]) - delta
			if float(seal["tick"]) <= 0.0 and ctx.player.alive \
					and ctx.player.global_position.distance_to(seal["pos"]) <= float(seal["radius"]) + ctx.player.radius:
				seal["tick"] = TICK
				ctx.combat.damage_player(float(seal["damage"]), seal["source"])
		i -= 1


# --- Armure de dalles (E27, Golem de pavés) ---------------------------------------------------------------------

## Des dalles le couvrent : il ne prend presque plus de dégâts, puis elles éclatent autour de lui (danger au sol) et
## le laissent à découvert quelques secondes.
func technique_slab_armor(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	var duration: float = float(technique.params.get("duration", 4.0))
	var radius: float = float(technique.params.get("radius", 150.0))
	var expose: float = float(technique.params.get("expose", 2.5))
	enemy.technique_busy = technique.telegraph
	m._later(enemy, technique.telegraph, func() -> void:
		enemy.extra_damage_taken = float(technique.params.get("armor_mult", 0.25))
		ctx.fx.burst(enemy.position, enemy.radius * 1.6, Color(STONE, 0.6)))
	m._later(enemy, technique.telegraph + duration - 0.8, func() -> void:
		ctx.hazards.add_circle(enemy.position, radius, 0.8, m._scaled(enemy, technique.damage), true, enemy.data.id))
	m._later(enemy, technique.telegraph + duration, func() -> void:
		enemy.extra_damage_taken = float(technique.params.get("expose_mult", 1.6))
		ctx.fx.debris(enemy.position, STONE, 14))
	m._later(enemy, technique.telegraph + duration + expose, func() -> void:
		enemy.extra_damage_taken = 1.0)
	return true


# --- Éveil des statues (E28, Gardienne des statues) -------------------------------------------------------------

## La Gardienne éveille des Statues autour d'elle (au plus max_active à la fois) : elles s'animent pendant
## `awaken` secondes, invulnérables, puis marchent sur le Chasseur.
func technique_awaken_statues(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	var statue: EnemyData = GameDB.enemy(StringName(technique.params.get("statue", "awakened_statue")))
	if statue == null:
		return false
	var active: int = 0
	for other: Enemy in ctx.enemies.list:
		if other.alive and other.data == statue:
			active += 1
	var count: int = mini(int(technique.params.get("count", 1)), int(technique.params.get("max_active", 2)) - active)
	if count <= 0:
		return false
	enemy.technique_busy = technique.telegraph
	var offset: float = ctx.rng.randf() * TAU
	for i: int in count:
		var pos: Vector2 = ctx.obstacles.push_out(enemy.position + Vector2.RIGHT.rotated(offset + TAU * i / count) * 140.0,
			statue.radius)
		ctx.fx.ring(pos, statue.radius * 1.4, Color(STONE, 0.8), technique.telegraph)
		m._later(enemy, technique.telegraph, func() -> void:
			awaken(statue, pos, float(technique.params.get("awaken", 1.2))))
	return true


## Fait surgir une Statue éveillée (aussi utilisé par les socles de la carte 24).
func awaken(statue: EnemyData, pos: Vector2, awaken_time: float) -> Enemy:
	var body: Enemy = m.spawn(statue, pos)
	body.technique_busy = awaken_time
	body.invulnerable_time = awaken_time
	body.visual.play_action(&"awaken")
	ctx.fx.debris(pos, STONE, 10)
	ctx.stats.add(&"statues_awakened")
	return body


# --- Onde de pierre (E29, Gardienne des statues) ----------------------------------------------------------------

## Ses mains frappent le sol : un anneau de pierre s'étend, avec des brèches où passer.
func technique_stone_wave(enemy: Enemy, technique: EnemyTechniqueData, _player_pos: Vector2) -> bool:
	enemy.technique_busy = technique.telegraph + 0.3
	ctx.hazards.add_ring(enemy.position, float(technique.params.get("speed", 260.0)),
		float(technique.params.get("max_radius", 520.0)), float(technique.params.get("thickness", 22.0)),
		m._scaled(enemy, technique.damage), true, enemy.data.id, [], 0.45, [], technique.telegraph,
		PixelFx.family_of(enemy))
	return true


# --- Bot et dessin ----------------------------------------------------------------------------------------------

## Bot : sortir des sceaux de corruption.
func danger(pos: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for seal: Dictionary in seals:
		var away: Vector2 = pos - (seal["pos"] as Vector2)
		if away.length() < float(seal["radius"]) + 30.0:
			push += (away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * 1.5
	return push


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	for seal: Dictionary in seals:
		var pos: Vector2 = seal["pos"]
		var radius: float = float(seal["radius"])
		draw_circle(pos, radius, Color(0.18, 0.04, 0.24, 0.45))
		draw_arc(pos, radius, 0.0, TAU, 48, Color(CORRUPTION, 0.55 + 0.35 * pulse), 3.0)
		for k: int in 5:
			var a: float = TAU * k / 5.0 + _time * 0.6
			draw_line(pos + Vector2.from_angle(a) * radius * 0.85, pos + Vector2.from_angle(a + TAU * 2.0 / 5.0) * radius * 0.85,
				Color(CORRUPTION, 0.5), 2.0)
	for link: Dictionary in soul_links:
		var source: Variant = link["source"]
		if not is_instance_valid(source):
			continue
		for ally: Variant in link["links"]:
			if is_instance_valid(ally) and (ally as Enemy).alive:
				draw_line((source as Enemy).position, (ally as Enemy).position, Color(CORRUPTION, 0.35 + 0.35 * pulse), 2.0)
				draw_arc((ally as Enemy).position, (ally as Enemy).radius + 6.0, 0.0, TAU, 20, Color(CORRUPTION, 0.6), 2.0)
