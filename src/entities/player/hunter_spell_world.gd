class_name HunterSpellWorld
extends Node2D
## Sorts du Chasseur du lot C2b (docs/design/ARBRE_DU_CHASSEUR.md) et leurs objets persistants : cristaux, murs,
## portails, Égide, parade, minuteries. HunterSpells gère les emplacements, les touches et la recharge ; il
## délègue ici les sorts au-delà de Taille fendante et Lance prismatique.

const LEAP_STEP := 12.0
const RETURN_WINDOW := 3.0
const CRYSTAL_SPLIT_ANGLE := 20.0
const DOUBLE_CRYSTAL_GAP := 120.0
const FOCUS_HOMING := 7.0
const WALL_SEGMENT := 26.0
const WALL_TOUCH := 30.0
const PORTAL_COOLDOWN := 1.0
const EXILE_RADIUS := 60.0
const EXILE_DISTANCE := 260.0
const SWAP_THREAT := 80.0
const BLADE_EMPOWER := 1.5

var ctx: RunContext
var spells: HunterSpells
## Bond de faille (variante Retour) : point de départ et fin de la fenêtre de retour.
var return_point := Vector2.ZERO
var return_until: float = -1.0
## Contre-taille : le prochain sort de Lame est rechargé et renforcé.
var blade_empowered: bool = false
var crystals: Array[Dictionary] = []
var walls: Array[Dictionary] = []
## Failles jumelles : {entrance, exit, until, placing, variant, hit} ; vide si aucune.
var portals: Dictionary = {}
var horizon_wells: Array[Dictionary] = []
var aegis: Dictionary = {}
## Actions différées : [{time, action}].
var _timers: Array[Dictionary] = []
var _parry_spell: SpellData
var _parry_slot: int = -1
var _parry_variant: StringName = &""
var _next_id: int = 0


func setup(p_ctx: RunContext, p_spells: HunterSpells) -> void:
	ctx = p_ctx
	spells = p_spells
	z_index = 0
	ctx.combat.add_damage_modifier(_horizon_modifier)


## Lance un sort du lot C2b. Retourne faux si le sort n'a pas pu partir (aucune cible, aucun Écho…).
func cast(slot: int, spell: SpellData, variant: StringName, origin: Vector2, dir: Vector2, aim: Vector2,
		power: float) -> bool:
	var center: Vector2 = _clamp_aim(origin, aim, spell.spell_range)
	var ok: bool = false
	match spell.spell_kind:
		&"leap":
			ok = _leap(spell, variant, origin, dir, aim, power)
		&"parry":
			ok = _parry(slot, spell, variant)
		&"rupture":
			ok = _rupture(spell, variant, center, power)
		&"crystal":
			ok = _crystal(spell, variant, center, dir)
		&"singularity":
			ok = _singularity(spell, variant, center, power)
		&"wall":
			ok = _wall(spell, variant, center, dir)
		&"rifts":
			ok = _rifts(spell, variant, center)
		&"pack_call":
			ok = _pack_call(spell, variant, center, power)
		&"aegis":
			ok = _aegis(spell, variant)
		&"swap":
			ok = _swap(spell, variant, aim)
		_:
			push_error("Sort inconnu : %s" % spell.spell_kind)
	return ok


## Le prochain lancement ne consomme pas la recharge (Retour du Bond, sortie des Failles jumelles).
func free_recast(spell: SpellData) -> bool:
	if spell.spell_kind == &"leap" and ctx.time < return_until:
		return true
	return spell.spell_kind == &"rifts" and not portals.is_empty() and bool(portals["placing"])


func _clamp_aim(origin: Vector2, aim: Vector2, max_range: float) -> Vector2:
	var offset: Vector2 = aim - origin
	return origin + offset.limit_length(max_range) if max_range > 0.0 else aim


func _info(spell: SpellData, amount_mult: float, dir: Vector2 = Vector2.ZERO) -> DamageInfo:
	var stats: StatSheet = ctx.player.stats
	var amount: float = spell.damage * amount_mult * stats.get_value(StatKeys.DAMAGE) \
		* stats.get_value(StatKeys.SPELL_DAMAGE)
	var tags: Array[StringName] = [DamageInfo.TAG_SPELL]
	var info := DamageInfo.make(amount, DamageInfo.SourceKind.PLAYER, &"player", tags)
	info.knockback = spell.knockback
	info.direction = dir
	info.statuses = spell.statuses
	return info


func _blast(center: Vector2, radius: float, spell: SpellData, amount_mult: float,
		statuses: Array[StatusApplication] = []) -> int:
	var hits: int = 0
	for enemy: Enemy in ctx.enemies.query_radius(center, radius):
		var info: DamageInfo = _info(spell, amount_mult, (enemy.global_position - center).normalized())
		if not statuses.is_empty():
			info.statuses = statuses
		ctx.combat.deal_damage(enemy, info)
		hits += 1
	return hits


func _status(id: StringName, stacks: int = 1) -> Array[StatusApplication]:
	var application := StatusApplication.new()
	application.status_id = id
	application.stacks = stacks
	var list: Array[StatusApplication] = [application]
	return list


func _after(delay: float, action: Callable) -> void:
	_timers.append({"time": ctx.time + delay, "action": action})


## Contre-taille : renforce le prochain sort de Lame (appelé par le passif).
func empower_blade() -> void:
	if blade_empowered:
		return
	blade_empowered = true
	for i: int in spells.slots.size():
		if spells.slots[i] and spells.slots[i].path == &"blade":
			spells.cooldowns[i] = 0.0
	ctx.fx.ring(ctx.player.global_position, 30.0, Color(1.0, 0.8, 0.4, 0.8), 0.3)


## Multiplicateur du prochain sort (Contre-taille consommée par un sort de Lame).
func consume_power(spell: SpellData) -> float:
	if blade_empowered and spell.path == &"blade":
		blade_empowered = false
		return BLADE_EMPOWER
	return 1.0


# --- Lame

## Bond de faille : saut jusqu'au curseur, sans traverser le décor ni les barrières ; onde de choc à l'arrivée.
func _leap(spell: SpellData, variant: StringName, origin: Vector2, dir: Vector2, aim: Vector2, power: float) -> bool:
	if variant == &"return" and ctx.time < return_until:
		return_until = -1.0
		ctx.player.start_leap(return_point, float(spell.params.get("duration", 0.25)), func() -> void:
			ctx.fx.ring(return_point, 40.0, spell.color, 0.3))
		return true
	var target: Vector2 = _leap_target(origin, _clamp_aim(origin, aim, spell.spell_range))
	var impact: bool = variant == &"impact"
	if variant == &"return":
		return_point = origin
		return_until = ctx.time + RETURN_WINDOW + float(spell.params.get("duration", 0.25))
	ctx.player.facing = dir
	ctx.player.start_leap(target, float(spell.params.get("duration", 0.25)), func() -> void:
		var radius: float = spell.width * (2.0 if impact else 1.0)
		var statuses: Array[StatusApplication] = []
		if impact:
			statuses = _status(&"slow")
		_blast(target, radius, spell, power, statuses)
		ctx.fx.burst(target, radius, Color(spell.color, 0.5))
		Audio.play_sfx(&"enemy_hit"))
	return true


## Point d'arrivée du Bond : dernier point libre sur le trajet (ne franchit ni l'eau, ni les falaises, ni les barrières).
func _leap_target(origin: Vector2, wanted: Vector2) -> Vector2:
	var radius: float = ctx.player.radius
	var offset: Vector2 = wanted - origin
	var steps: int = maxi(int(offset.length() / LEAP_STEP), 1)
	var last: Vector2 = origin
	for i: int in range(1, steps + 1):
		var point: Vector2 = origin + offset * (float(i) / steps)
		if ctx.obstacles.blocks(point, radius * 0.6):
			break
		last = point
	var rect: Rect2 = ctx.arena_rect().grow(-radius)
	return last.clamp(rect.position, rect.end)


## Parade : fenêtre de garde ; un coup reçu pendant la fenêtre déclenche on_parry().
func _parry(slot: int, spell: SpellData, variant: StringName) -> bool:
	_parry_spell = spell
	_parry_slot = slot
	_parry_variant = variant
	ctx.player.parry_time = float(spell.params.get("window", 0.4))
	ctx.fx.ring(ctx.player.global_position, 34.0, spell.color, 0.25)
	return true


## Coup paré : aucun dégât, contre-attaque autour du Chasseur, ennemis étourdis, recharge remise à zéro.
func on_parry() -> void:
	var player: Player = ctx.player
	player.parry_time = 0.0
	player.grant_iframes(0.3)
	if _parry_spell == null:
		return
	var spell: SpellData = _parry_spell
	var center: Vector2 = player.global_position
	var power: float = float(spell.params.get("counter", 4.0)) * consume_power(spell)
	_blast(center, spell.width, spell, power)
	ctx.fx.burst(center, spell.width, Color(spell.color, 0.6))
	if _parry_variant == &"mirror":
		var template: DamageInfo = _info(spell, 1.0)
		ctx.projectiles.reflect_hostiles(center, spell.width + 60.0, template, spell.color)
	elif _parry_variant == &"pack_guard":
		for ally: Ally in ctx.allies.team:
			if ally.global_position.distance_to(center) <= spell.width + 120.0:
				_blast(ally.global_position, 100.0, spell, 2.0)
				ctx.fx.burst(ally.global_position, 100.0, Color(spell.color, 0.45))
	if _parry_slot >= 0 and _parry_slot < spells.cooldowns.size():
		spells.cooldowns[_parry_slot] = 0.0
	ctx.stats.add(&"parries")
	Audio.play_sfx(&"evolution")


# --- Prisme

## Rupture : fait détoner les Marques dans une zone au curseur.
func _rupture(spell: SpellData, variant: StringName, center: Vector2, power: float) -> bool:
	var per_stack: float = _info(spell, power).amount
	var detonated: Array[Enemy] = []
	for enemy: Enemy in ctx.enemies.query_radius(center, spell.width):
		if enemy.statuses.get_stacks(&"mark") > 0:
			detonated.append(enemy)
	for enemy: Enemy in detonated:
		var pos: Vector2 = enemy.global_position
		ctx.status_system.detonate(enemy, per_stack, &"player")
		if variant == &"reaction":
			var next: Enemy = ctx.enemies.find_nearest(pos, 120.0, {enemy.get_instance_id(): true})
			if next:
				ctx.status_system.apply(next, &"mark", 1, &"player")
		elif variant == &"blaze":
			ctx.hazards.add_zone(pos, 55.0, 3.0, per_stack * 0.3, &"player", _status(&"burn"), Color(1.0, 0.55, 0.2))
	ctx.fx.ring(center, spell.width, spell.color, 0.35)
	return true


## Cristal réfracteur : chaque tir allié qui le traverse se divise en 3 et marque.
func _crystal(spell: SpellData, variant: StringName, center: Vector2, dir: Vector2) -> bool:
	var duration: float = float(spell.params.get("duration", 8.0))
	_add_crystal(center, spell, variant, duration)
	if variant == &"double":
		_add_crystal(center + dir * DOUBLE_CRYSTAL_GAP, spell, variant, duration)
	return true


func _add_crystal(pos: Vector2, spell: SpellData, variant: StringName, duration: float) -> void:
	_next_id += 1
	crystals.append({"id": "crystal_%d" % _next_id, "pos": pos, "radius": spell.width, "until": ctx.time + duration,
		"variant": variant, "color": spell.color})


## Effets des sorts sur un projectile allié (cristaux, portails). Appelé à chaque pas de chaque projectile allié.
func affect_projectile(p: Projectile) -> void:
	if p.info == null or p.info.source_kind != DamageInfo.SourceKind.PLAYER:
		return
	for crystal: Dictionary in crystals:
		var key: String = crystal["id"]
		if p.hit_ids.has(key) or p.position.distance_to(crystal["pos"]) > float(crystal["radius"]):
			continue
		p.hit_ids[key] = true
		_refract(p, crystal)
	if not portals.is_empty() and not bool(portals["placing"]) and not p.hit_ids.has("portal"):
		if p.position.distance_to(portals["entrance"]) <= 34.0:
			p.hit_ids["portal"] = true
			p.position = portals["exit"]
			if portals["variant"] == &"loop":
				var copy: Projectile = _copy_projectile(p, deg_to_rad(8.0))
				copy.hit_ids["portal"] = true


func _refract(p: Projectile, crystal: Dictionary) -> void:
	var marked: DamageInfo = p.info.duplicate_info()
	var statuses: Array[StatusApplication] = []
	statuses.append_array(marked.statuses)
	statuses.append_array(_status(&"mark"))
	marked.statuses = statuses
	p.info = marked
	var focus: Enemy = _toughest(p.position) if crystal["variant"] == &"focus" else null
	for angle: float in [-CRYSTAL_SPLIT_ANGLE, CRYSTAL_SPLIT_ANGLE]:
		var copy: Projectile = _copy_projectile(p, deg_to_rad(angle))
		if focus:
			copy.homing = FOCUS_HOMING
			copy.target = focus
	if focus:
		p.homing = FOCUS_HOMING
		p.target = focus
	ctx.fx.spark(crystal["pos"], crystal["color"], 10.0)


func _copy_projectile(p: Projectile, angle: float) -> Projectile:
	var copy: Projectile = ctx.projectiles.spawn_friendly(p.position, p.velocity.rotated(angle), p.velocity.length(),
		p.info.duplicate_info(), {"pierce": p.pierce_left, "radius": p.radius, "life": p.life, "color": p.color})
	copy.hit_ids = p.hit_ids.duplicate()
	return copy


func _toughest(pos: Vector2) -> Enemy:
	var best: Enemy = null
	for enemy: Enemy in ctx.enemies.query_radius(pos, 600.0):
		if best == null or enemy.hp > best.hp:
			best = enemy
	return best


# --- Abîme

## Singularité : puits de gravité au curseur, puis implosion.
func _singularity(spell: SpellData, variant: StringName, center: Vector2, power: float) -> bool:
	var radius: float = spell.width * (1.4 if variant == &"horizon" else 1.0)
	var duration: float = float(spell.params.get("duration", 3.0)) * (0.5 if variant == &"collapse" else 1.0)
	var implode: DamageInfo = _info(spell, power * (2.0 if variant == &"collapse" else 1.0))
	ctx.hazards.add_well(center, radius, duration, float(spell.params.get("pull", 260.0)), implode, &"player")
	if variant == &"horizon":
		horizon_wells.append({"pos": center, "radius": radius, "until": ctx.time + duration})
	return true


## Horizon : les ennemis dans la Singularité subissent +15 % de dégâts.
func _horizon_modifier(enemy: Enemy, _info_unused: DamageInfo) -> float:
	for well: Dictionary in horizon_wells:
		if enemy.global_position.distance_to(well["pos"]) <= float(well["radius"]):
			return 1.15
	return 1.0


## Mur de faille : mur perpendiculaire à la visée, centré sur le curseur (segments d'obstacle alignés).
func _wall(spell: SpellData, variant: StringName, center: Vector2, dir: Vector2) -> bool:
	var axis: Vector2 = dir.orthogonal()
	var half: float = spell.width * 0.5
	var ids: Array[int] = []
	var count: int = maxi(int(spell.width / WALL_SEGMENT), 1)
	for i: int in count:
		var point: Vector2 = center + axis * (-half + WALL_SEGMENT * (i + 0.5))
		if point.distance_to(ctx.player.global_position) < ctx.player.radius + WALL_SEGMENT:
			continue
		ids.append(ctx.obstacles.add_wall(Rect2(point - Vector2.ONE * WALL_SEGMENT * 0.5, Vector2.ONE * WALL_SEGMENT)))
	if ctx.flow:
		ctx.flow.apply_walls(ctx.obstacles)
	walls.append({"from": center - axis * half, "to": center + axis * half, "ids": ids, "variant": variant,
		"until": ctx.time + float(spell.params.get("duration", 4.0)), "tick": 0.0, "touched": {}, "spell": spell})
	return true


## Les murs de faille arrêtent les projectiles ennemis.
func blocks_projectile(pos: Vector2) -> bool:
	for wall: Dictionary in walls:
		if Geometry2D.get_closest_point_to_segment(pos, wall["from"], wall["to"]).distance_to(pos) < WALL_SEGMENT * 0.6:
			return true
	return false


## Failles jumelles : premier appui = entrée, second appui (ou fin du délai) = sortie.
func _rifts(spell: SpellData, variant: StringName, wanted: Vector2) -> bool:
	# Un portail se pose toujours sur un sol praticable (jamais dans l'eau ni dans le décor).
	var point: Vector2 = ctx.obstacles.push_out(wanted, 24.0)
	if not portals.is_empty() and bool(portals["placing"]):
		_open_rifts(point)
		return true
	portals = {"entrance": point, "exit": point, "placing": true, "variant": variant, "spell": spell,
		"until": ctx.time + float(spell.params.get("place_time", 4.0)), "cooldowns": {}}
	return true


func _open_rifts(exit_point: Vector2) -> void:
	var spell: SpellData = portals["spell"]
	portals["exit"] = exit_point
	portals["placing"] = false
	portals["until"] = ctx.time + float(spell.params.get("duration", 6.0))
	ctx.fx.ring(exit_point, 34.0, spell.color, 0.3)


func _step_rifts() -> void:
	if portals.is_empty():
		return
	if ctx.time >= float(portals["until"]):
		if bool(portals["placing"]):
			_open_rifts(ctx.obstacles.push_out(ctx.player.global_position, 24.0))
		else:
			portals = {}
		return
	if bool(portals["placing"]):
		return
	var entrance: Vector2 = portals["entrance"]
	var exit_point: Vector2 = portals["exit"]
	var cooldowns: Dictionary = portals["cooldowns"]
	var spell: SpellData = portals["spell"]
	var player: Player = ctx.player
	if player.is_dashing() and player.global_position.distance_to(entrance) < 34.0 + player.radius:
		player.global_position = exit_point
	for ally: Ally in ctx.allies.team:
		var id: int = ally.get_instance_id()
		if ally.global_position.distance_to(entrance) < 34.0 and ctx.time >= float(cooldowns.get(id, 0.0)):
			ally.global_position = exit_point
			cooldowns[id] = ctx.time + PORTAL_COOLDOWN
	for gate: Vector2 in [entrance, exit_point]:
		for enemy: Enemy in ctx.enemies.query_radius(gate, 34.0):
			var id: int = enemy.get_instance_id()
			if ctx.time < float(cooldowns.get(id, 0.0)):
				continue
			cooldowns[id] = ctx.time + PORTAL_COOLDOWN
			for application: StatusApplication in spell.statuses:
				ctx.status_system.apply(enemy, application.status_id, application.stacks, &"player")
	if portals["variant"] == &"exile":
		for enemy: Enemy in ctx.enemies.query_radius(entrance, EXILE_RADIUS):
			if enemy.is_elite or enemy.is_boss or enemy.is_obstacle:
				continue
			var away: Vector2 = Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * EXILE_DISTANCE
			enemy.position = ctx.obstacles.push_out(exit_point + away, enemy.radius)
			ctx.status_system.apply(enemy, &"slow", 1, &"player")
			ctx.fx.spark(enemy.position, spell.color, 8.0)


# --- Lien

## Appel de meute : les Échos bondissent vers le curseur et frappent ensemble.
func _pack_call(spell: SpellData, variant: StringName, center: Vector2, power: float) -> bool:
	var team: Array[Ally] = ctx.allies.team
	if team.is_empty():
		return false
	var mult: float = power * (1.0 + 0.25 * (team.size() - 1))
	for i: int in team.size():
		var ally: Ally = team[i]
		var spot: Vector2 = center + Vector2.RIGHT.rotated(TAU * i / team.size()) * 40.0
		spot = ctx.obstacles.push_out(spot, 14.0)
		ctx.fx.line(ally.global_position, spot, spell.color, 3.0, 0.25)
		ally.global_position = spot
		for enemy: Enemy in ctx.enemies.query_radius(spot, spell.width):
			var quarry: float = 2.0 if variant == &"quarry" and (enemy.is_elite or enemy.is_boss) else 1.0
			ctx.combat.deal_damage(enemy, _info(spell, mult * quarry, (enemy.global_position - spot).normalized()))
	ctx.fx.burst(center, spell.width, Color(spell.color, 0.45))
	if variant == &"rally":
		ctx.player.stats.add_modifier(StatKeys.ALLY_ATTACK_SPEED, 0.0, 0.25)
		_after(4.0, func() -> void: ctx.player.stats.add_modifier(StatKeys.ALLY_ATTACK_SPEED, 0.0, -0.25))
	return true


## Égide de faille : bouclier du Chasseur (plus fort avec des Échos), retiré à la fin de la durée.
func _aegis(spell: SpellData, variant: StringName) -> bool:
	var player: Player = ctx.player
	var ratio: float = spell.width * (1.0 + float(spell.params.get("per_echo", 0.05)) * ctx.allies.team.size())
	var amount: float = player.max_hp * ratio * (0.5 if variant == &"share" else 1.0)
	if variant == &"share":
		player.heal(player.max_hp * 0.15)
	player.add_shield(amount, player.shield + amount)
	aegis = {"amount": amount, "until": ctx.time + float(spell.params.get("duration", 4.0)), "variant": variant,
		"spell": spell}
	ctx.fx.ring(player.global_position, 40.0, spell.color, 0.35)
	return true


func _step_aegis() -> void:
	if aegis.is_empty():
		return
	var player: Player = ctx.player
	if player.shield <= 0.0:
		if aegis["variant"] == &"riposte":
			var spell: SpellData = aegis["spell"]
			_blast(player.global_position, 140.0, spell, 1.0)
			ctx.fx.burst(player.global_position, 140.0, Color(spell.color, 0.6))
		aegis = {}
	elif ctx.time >= float(aegis["until"]):
		player.shield = maxf(player.shield - float(aegis["amount"]), 0.0)
		aegis = {}


## Permutation : échange de place avec l'Écho le plus proche du curseur, qui provoque les ennemis proches.
func _swap(spell: SpellData, variant: StringName, aim: Vector2) -> bool:
	var player: Player = ctx.player
	var ally: Ally = null
	for candidate: Ally in ctx.allies.team:
		if ally == null or candidate.global_position.distance_to(aim) < ally.global_position.distance_to(aim):
			ally = candidate
	if ally == null or ally.global_position.distance_to(player.global_position) > spell.spell_range:
		return false
	var perfect: bool = _threat_near(player.global_position)
	var from: Vector2 = player.global_position
	player.global_position = ally.global_position
	ally.global_position = from
	ctx.fx.line(from, player.global_position, spell.color, 3.0, 0.25)
	for enemy: Enemy in ctx.enemies.query_radius(from, spell.width):
		enemy.taunt_target = ally
		enemy.taunt_time = float(spell.params.get("taunt", 2.0))
	if perfect:
		player.grant_iframes(0.4)
		for i: int in spells.cooldowns.size():
			spells.cooldowns[i] *= 0.5
		ctx.fx.ring(player.global_position, 30.0, Color.WHITE, 0.3)
	if variant == &"relay" and ally.technique:
		ally.technique_cd = 0.0
		Techniques.cast(ally, ctx, aim)
	elif variant == &"sanctuary":
		player.heal(player.max_hp * 0.12)
	return true


## Un coup est imminent : projectile ennemi ou ennemi en train de frapper tout près.
func _threat_near(pos: Vector2) -> bool:
	for p: Projectile in ctx.projectiles.hostile:
		if p.position.distance_to(pos) < SWAP_THREAT:
			return true
	for enemy: Enemy in ctx.enemies.query_radius(pos, SWAP_THREAT):
		if enemy.state == Enemy.State.WINDUP or enemy.state == Enemy.State.CHARGE:
			return true
	return false


# --- Boucle

func step(delta: float) -> void:
	var now: float = ctx.time
	var i: int = _timers.size() - 1
	while i >= 0:
		if now >= float(_timers[i]["time"]):
			var action: Callable = _timers[i]["action"]
			_timers.remove_at(i)
			action.call()
		i -= 1
	crystals.assign(crystals.filter(func(c: Dictionary) -> bool: return now < float(c["until"])))
	horizon_wells.assign(horizon_wells.filter(func(w: Dictionary) -> bool: return now < float(w["until"])))
	_step_walls(now, delta)
	_step_rifts()
	_step_aegis()
	queue_redraw()


func _step_walls(now: float, delta: float) -> void:
	var changed: bool = false
	var i: int = walls.size() - 1
	while i >= 0:
		var wall: Dictionary = walls[i]
		if now >= float(wall["until"]):
			for id: int in wall["ids"]:
				ctx.obstacles.set_wall_enabled(id, false)
			walls.remove_at(i)
			changed = true
		elif wall["variant"] != &"":
			_wall_contact(wall, delta)
		i -= 1
	if changed and ctx.flow:
		ctx.flow.apply_walls(ctx.obstacles)


## Variantes du mur : Chaînes (enracine une fois), Rempart ardent (Brûlure et Fracture toutes les 0,5 s).
func _wall_contact(wall: Dictionary, delta: float) -> void:
	var from: Vector2 = wall["from"]
	var to: Vector2 = wall["to"]
	var middle: Vector2 = (from + to) * 0.5
	var burning: bool = wall["variant"] == &"burning"
	if burning:
		wall["tick"] = float(wall["tick"]) - delta
		if float(wall["tick"]) > 0.0:
			return
		wall["tick"] = 0.5
	for enemy: Enemy in ctx.enemies.query_radius(middle, from.distance_to(to) * 0.5 + WALL_TOUCH):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
		if closest.distance_to(enemy.global_position) > WALL_TOUCH + enemy.radius:
			continue
		if burning:
			ctx.status_system.apply(enemy, &"burn", 1, &"player")
			ctx.status_system.apply(enemy, &"fracture", 1, &"player")
		elif not (wall["touched"] as Dictionary).has(enemy.get_instance_id()):
			wall["touched"][enemy.get_instance_id()] = true
			ctx.status_system.apply(enemy, &"root", 1, &"player")


func _draw() -> void:
	for crystal: Dictionary in crystals:
		var pos: Vector2 = crystal["pos"]
		var r: float = float(crystal["radius"])
		var diamond := PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r * 0.6, 0), pos + Vector2(0, r),
			pos + Vector2(-r * 0.6, 0)])
		draw_colored_polygon(diamond, Color(crystal["color"], 0.55))
		draw_arc(pos, r, 0.0, TAU, 24, Color(crystal["color"], 0.8), 1.5)
	for wall: Dictionary in walls:
		var spell: SpellData = wall["spell"]
		draw_line(wall["from"], wall["to"], Color(spell.color, 0.45), WALL_SEGMENT)
		draw_line(wall["from"], wall["to"], Color(spell.color, 0.95), 3.0)
	if not portals.is_empty():
		var spell: SpellData = portals["spell"]
		draw_arc(portals["entrance"], 34.0, 0.0, TAU, 28, Color(spell.color, 0.9), 3.0)
		if not bool(portals["placing"]):
			draw_arc(portals["exit"], 34.0, 0.0, TAU, 28, Color(spell.color.lightened(0.3), 0.9), 3.0)
			draw_dashed_line(portals["entrance"], portals["exit"], Color(spell.color, 0.35), 2.0, 10.0)
