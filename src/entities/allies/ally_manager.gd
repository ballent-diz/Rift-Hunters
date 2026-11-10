class_name AllyManager
extends Node2D
## Équipe d'Échos : recrutement, rangs, évolutions, Techniques, ordre de focus et synergies.

var ctx: RunContext
## Échos sur le terrain (ceux qui se déplacent, attaquent et lancent leur Technique).
var team: Array[Ally] = []
## Équipe complète équipée, dans l'ordre (terrain et réserve) : affinités, bonus passifs, améliorations.
## Mode actuel : identique à `team`. Relais : un seul Écho sur le terrain. Solo : aucun.
var roster: Array[Ally] = []
## Mode des Échos (EchoMode) et état du relais.
var mode: StringName = EchoMode.CURRENT
var active_index: int = 0
var relay_cd: float = 0.0
var focus_point := Vector2.ZERO
var focus_time: float = 0.0
## Effets peints des Échos (présentation).
var vfx := EchoVfx.new()
## Aperçu de visée d'un sort d'Écho (option « aperçu ») : emplacement maintenu et indicateur affiché.
var preview_index: int = -1
var _preview_fx: Node2D
## Bonus temporaires des sorts (Essaim de lucioles) : [{stat, pct, until}] sur la feuille du Chasseur.
var _timed_buffs: Array[Dictionary] = []


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	mode = EchoMode.sanitize(ctx.setup.echo_mode) if ctx.setup else EchoMode.CURRENT
	vfx.setup(ctx, self)


## Bonus temporaire d'une statistique du Chasseur (vitesse, cadence des Échos...) ; le même sort ne se cumule pas.
func add_timed_buff(key: String, stat: StringName, pct: float, duration: float) -> void:
	for buff: Dictionary in _timed_buffs:
		if buff["key"] == key and buff["stat"] == stat:
			buff["until"] = ctx.time + duration
			return
	ctx.player.stats.add_modifier(stat, 0.0, pct)
	_timed_buffs.append({"key": key, "stat": stat, "pct": pct, "until": ctx.time + duration})


func timed_buff_active(key: String) -> bool:
	for buff: Dictionary in _timed_buffs:
		if buff["key"] == key:
			return true
	return false


func _expire_buffs() -> void:
	for i: int in range(_timed_buffs.size() - 1, -1, -1):
		var buff: Dictionary = _timed_buffs[i]
		if ctx.time >= float(buff["until"]):
			ctx.player.stats.remove_modifier(buff["stat"], 0.0, float(buff["pct"]))
			_timed_buffs.remove_at(i)


func team_size() -> int:
	return roster.size()


func team_slots() -> int:
	return mini(ctx.player.stats.get_int(StatKeys.TEAM_SLOTS), ctx.balance.max_team_slots)


func has_free_slot() -> bool:
	return roster.size() < team_slots()


func get_ally(id: StringName) -> Ally:
	for ally: Ally in roster:
		if ally.data.id == id:
			return ally
	return null


func team_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for ally: Ally in roster:
		ids.append(ally.data.id)
	return ids


func add_monster(id: StringName, rank: int = 1, use_variant: bool = false) -> Ally:
	var data: MonsterData = GameDB.monster(id)
	if data == null or get_ally(id) != null:
		return null
	var ally := Ally.new()
	ally.slot_index = team.size() if mode == EchoMode.CURRENT else 0
	add_child(ally)
	ally.setup(ctx, data, clampi(rank, 1, ctx.balance.ally_rank_max))
	var chosen: TechniqueData = ctx.setup.echo_techniques.get(id)
	if chosen:
		ally.technique = chosen
		ally.technique_locked = true
	ally.global_position = ctx.player.global_position + Vector2(30, 0).rotated(team.size() * 2.0)
	roster.append(ally)
	if mode == EchoMode.CURRENT or (mode == EchoMode.RELAY and team.is_empty()):
		team.append(ally)
		active_index = roster.size() - 1
	else:
		_bench(ally)
	for effect: GameplayEffect in data.passive_effects:
		effect.install(ctx, id)
	for effect: GameplayEffect in ctx.setup.monster_meta_effects.get(id, []):
		effect.install(ctx, id)
	if use_variant and data.variant:
		ally.variant = data.variant
		ally.apply_modifier(data.variant)
	ctx.stats.add(&"recruits")
	ctx.stats.set_max(&"max_team_size", roster.size())
	ctx.events.team_changed.emit()
	refresh_synergies()
	return ally


func empower(id: StringName) -> void:
	var ally: Ally = get_ally(id)
	if ally and ally.rank < ctx.balance.ally_rank_max:
		ally.rank += 1
		ctx.fx.ring(ally.global_position, 40.0, Color(1.0, 0.9, 0.5, 0.7), 0.4)


func evolve(id: StringName, evolution: EvolutionData) -> void:
	var ally: Ally = get_ally(id)
	if ally == null or ally.evolution != null:
		return
	ally.evolution = evolution
	ally.apply_modifier(evolution)
	ctx.build.evolutions[id] = evolution.id
	ctx.stats.add(&"evolutions")
	ctx.stats.set_value(StringName(String(id) + "_evolved"), 1.0)
	ctx.stats.add(StringName("evolution_" + String(evolution.id)))
	ctx.events.evolution_taken.emit(id, evolution.id)
	ctx.fx.burst(ally.global_position, 70.0, Color(1.0, 0.95, 0.6, 0.5))
	refresh_synergies()


## Évolutions proposables pour un Écho (rang atteint, conditions de combinaison remplies).
func available_evolutions(ally: Ally) -> Array[EvolutionData]:
	var result: Array[EvolutionData] = []
	if ally.evolution != null or not ctx.balance.feature_enabled(&"evolutions"):
		return result
	var required_offset: int = ctx.player.stats.get_int(StatKeys.EVOLUTION_RANK) - 3
	for evo: EvolutionData in ally.data.evolutions:
		if ally.rank < maxi(evo.required_rank + required_offset, 1):
			continue
		var ok: bool = true
		for needed: StringName in evo.requires_monsters:
			if get_ally(needed) == null:
				ok = false
		for relic: StringName in evo.requires_relics:
			if not ctx.build.relics.has(relic):
				ok = false
		if ok:
			result.append(evo)
	return result


func refresh_synergies() -> void:
	var ids: Array[StringName] = team_ids()
	for synergy_id: StringName in GameDB.sorted_ids(GameDB.synergies):
		if ctx.build.active_synergies.has(synergy_id):
			continue
		var synergy: SynergyData = GameDB.synergies[synergy_id]
		if not _synergy_satisfied(synergy, ids):
			continue
		ctx.build.active_synergies.append(synergy_id)
		for effect: GameplayEffect in synergy.effects:
			effect.install(ctx, &"")
		ctx.stats.add(&"synergies_activated")
		ctx.events.synergy_activated.emit(synergy_id)


func _synergy_satisfied(synergy: SynergyData, ids: Array[StringName]) -> bool:
	for needed: StringName in synergy.required_monsters:
		if not ids.has(needed):
			return false
	for affinity: StringName in synergy.required_affinities:
		var count: int = 0
		for ally: Ally in roster:
			if ally.affinities.has(affinity):
				count += 1
		if count < int(synergy.required_affinities[affinity]):
			return false
	return true


func step(delta: float) -> void:
	var brain: PlayerBrain = ctx.player.brain
	focus_time = maxf(focus_time - delta, 0.0)
	if not _timed_buffs.is_empty():
		_expire_buffs()
	relay_cd = maxf(relay_cd - delta, 0.0)
	for ally: Ally in roster:
		if ally.benched:
			# Réserve : sa Technique se recharge, et il « suit » le Chasseur (bonus passifs centrés sur lui).
			ally.technique_cd = maxf(ally.technique_cd - delta, 0.0)
			ally.global_position = ctx.player.global_position
	if mode == EchoMode.RELAY and brain.relay_requested():
		relay(brain.aim_point())
	if brain.focus_requested():
		focus_point = brain.aim_point()
		focus_time = ctx.balance.focus_duration
		ctx.stats.add(&"focus_orders")
		ctx.fx.ring(focus_point, ctx.balance.focus_radius, Color(1.0, 0.9, 0.4, 0.6), 0.5)
	for i: int in team.size():
		var ally: Ally = team[i]
		if ally.swallowed:
			continue
		ally.technique_cd = maxf(ally.technique_cd - delta, 0.0)
		ally.behavior.tick(ally, ctx, delta)
		if ally.technique_cd > 0.0:
			if preview_index == i:
				_end_preview()
			continue
		if not brain.preview_casting():
			if brain.technique_pressed(i):
				Techniques.cast(ally, ctx, brain.aim_point())
		elif brain.technique_held(i) and (preview_index == -1 or preview_index == i):
			_show_preview(ally, i, brain.aim_point())
		elif preview_index == i and brain.technique_released(i):
			_end_preview()
			Techniques.cast(ally, ctx, brain.aim_point())
	queue_redraw()


## Multiplicateur de dégâts des Échos selon le mode (Relais : l'Écho actif compense ses deux équipiers en réserve).
func field_damage_mult() -> float:
	return ctx.balance.relay_damage_mult if mode == EchoMode.RELAY else 1.0


## Écho actif du mode Relais (null en Solo ou sans équipe).
func active() -> Ally:
	return team[0] if not team.is_empty() else null


## Écho qui entrera au prochain relais (null s'il n'y en a pas).
func next_in_line() -> Ally:
	if mode != EchoMode.RELAY or roster.size() < 2:
		return null
	return roster[(active_index + 1) % roster.size()]


func relay_ready() -> bool:
	var current: Ally = active()
	return next_in_line() != null and relay_cd <= 0.0 and (current == null or not current.swallowed)


## Relais : l'Écho actif passe en réserve, le suivant entre près du Chasseur et lance son attaque d'entrée (sa
## Technique, gratuite : sa recharge n'est pas touchée).
func relay(aim: Vector2) -> bool:
	if not relay_ready():
		return false
	var leaving: Ally = active()
	var entering: Ally = next_in_line()
	if leaving:
		_bench(leaving)
	if preview_index != -1:
		_end_preview()
	team.clear()
	active_index = roster.find(entering)
	entering.benched = false
	entering.visible = true
	entering.slot_index = 0
	entering.attack_cd = 0.0
	entering.global_position = ctx.obstacles.push_out(ctx.player.global_position + Vector2(0, -24), Ally.BODY_RADIUS)
	team.append(entering)
	relay_cd = ctx.balance.relay_cooldown
	ctx.fx.ring(entering.global_position, 46.0, Color(0.75, 0.45, 1.0, 0.9), 0.4)
	if entering.technique:
		var saved_cd: float = entering.technique_cd
		entering.entry_mult = ctx.balance.relay_entry_power
		Techniques.cast(entering, ctx, aim)
		entering.entry_mult = 1.0
		entering.technique_cd = saved_cd
	ctx.stats.add(&"echo_relays")
	ctx.events.team_changed.emit()
	return true


func _bench(ally: Ally) -> void:
	ally.benched = true
	ally.visible = false
	ally.velocity = Vector2.ZERO
	ally.memory.clear()
	team.erase(ally)


## Indicateur de visée (Codex) : zone au curseur, ligne ou cône depuis le Chasseur.
func _show_preview(ally: Ally, index: int, aim: Vector2) -> void:
	preview_index = index
	var tech: TechniqueData = ally.technique
	var shape: StringName = Techniques.aim_shape(tech)
	# Bond, piqué et flamme errante partent de l'Écho ; les autres sorts, du Chasseur.
	var from_echo: bool = tech.technique_kind in [&"cinder_dash", &"bouncing_bolt", &"mirror_shards"]
	var origin: Vector2 = ally.global_position if from_echo else ctx.player.global_position
	var pos: Vector2 = Techniques.preview_point(ctx, aim) if shape == &"area" else origin
	var dir: Vector2 = (aim - origin).normalized() if aim.distance_to(origin) > 4.0 else Vector2.RIGHT
	if not is_instance_valid(_preview_fx):
		_preview_fx = vfx.play(ally.data.id, &"indicator", pos, dir, {"radius": tech.radius,
			"travel_distance": Techniques.aim_length(tech), "target_shape": shape, "loop_visual": true,
			"visual_duration": 30.0})
	if is_instance_valid(_preview_fx):
		_preview_fx.global_position = pos
		_preview_fx.rotation = dir.angle()


func _end_preview() -> void:
	preview_index = -1
	if is_instance_valid(_preview_fx) and _preview_fx.has_method("release"):
		_preview_fx.call("release")
	_preview_fx = null


func _draw() -> void:
	if focus_time > 0.0:
		var alpha: float = clampf(focus_time / ctx.balance.focus_duration, 0.2, 1.0)
		draw_arc(focus_point, 26.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, alpha), 2.5)
		draw_line(focus_point + Vector2(-10, 0), focus_point + Vector2(10, 0), Color(1.0, 0.9, 0.4, alpha), 2.0)
		draw_line(focus_point + Vector2(0, -10), focus_point + Vector2(0, 10), Color(1.0, 0.9, 0.4, alpha), 2.0)
