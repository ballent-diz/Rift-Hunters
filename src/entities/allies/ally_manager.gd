class_name AllyManager
extends Node2D
## Équipe d'Échos : recrutement, rangs, évolutions, Techniques, ordre de focus et synergies.

var ctx: RunContext
var team: Array[Ally] = []
var focus_point := Vector2.ZERO
var focus_time: float = 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx


func team_size() -> int:
	return team.size()


func team_slots() -> int:
	return mini(ctx.player.stats.get_int(StatKeys.TEAM_SLOTS), ctx.balance.max_team_slots)


func has_free_slot() -> bool:
	return team.size() < team_slots()


func get_ally(id: StringName) -> Ally:
	for ally: Ally in team:
		if ally.data.id == id:
			return ally
	return null


func team_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for ally: Ally in team:
		ids.append(ally.data.id)
	return ids


func add_monster(id: StringName, rank: int = 1, use_variant: bool = false) -> Ally:
	var data: MonsterData = GameDB.monster(id)
	if data == null or get_ally(id) != null:
		return null
	var ally := Ally.new()
	ally.slot_index = team.size()
	add_child(ally)
	ally.setup(ctx, data, clampi(rank, 1, ctx.balance.ally_rank_max))
	var chosen: TechniqueData = ctx.setup.echo_techniques.get(id)
	if chosen:
		ally.technique = chosen
		ally.technique_locked = true
	ally.global_position = ctx.player.global_position + Vector2(30, 0).rotated(team.size() * 2.0)
	team.append(ally)
	for effect: GameplayEffect in data.passive_effects:
		effect.install(ctx, id)
	for effect: GameplayEffect in ctx.setup.monster_meta_effects.get(id, []):
		effect.install(ctx, id)
	if use_variant and data.variant:
		ally.variant = data.variant
		ally.apply_modifier(data.variant)
	ctx.stats.add(&"recruits")
	ctx.stats.set_max(&"max_team_size", team.size())
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
	if ally.evolution != null:
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
		for ally: Ally in team:
			if ally.affinities.has(affinity):
				count += 1
		if count < int(synergy.required_affinities[affinity]):
			return false
	return true


func step(delta: float) -> void:
	var brain: PlayerBrain = ctx.player.brain
	focus_time = maxf(focus_time - delta, 0.0)
	if brain.focus_requested():
		focus_point = brain.aim_point()
		focus_time = ctx.balance.focus_duration
		ctx.stats.add(&"focus_orders")
		ctx.fx.ring(focus_point, ctx.balance.focus_radius, Color(1.0, 0.9, 0.4, 0.6), 0.5)
	for i: int in team.size():
		var ally: Ally = team[i]
		ally.technique_cd = maxf(ally.technique_cd - delta, 0.0)
		ally.behavior.tick(ally, ctx, delta)
		if ally.technique_cd <= 0.0 and brain.technique_pressed(i):
			Techniques.cast(ally, ctx, brain.aim_point())
	queue_redraw()


func _draw() -> void:
	if focus_time > 0.0:
		var alpha: float = clampf(focus_time / ctx.balance.focus_duration, 0.2, 1.0)
		draw_arc(focus_point, 26.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.4, alpha), 2.5)
		draw_line(focus_point + Vector2(-10, 0), focus_point + Vector2(10, 0), Color(1.0, 0.9, 0.4, alpha), 2.0)
		draw_line(focus_point + Vector2(0, -10), focus_point + Vector2(0, 10), Color(1.0, 0.9, 0.4, alpha), 2.0)
