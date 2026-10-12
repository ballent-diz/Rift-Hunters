class_name StatusSystem
extends RefCounted
## Applique les statuts en tenant compte des bonus du Chasseur (durée, cumuls, amplification).

var ctx: RunContext


func _init(p_ctx: RunContext) -> void:
	ctx = p_ctx


func max_stacks_for(status_id: StringName) -> int:
	var data: StatusData = GameDB.status(status_id)
	if data == null:
		return 0
	var bonus: int = 0
	if status_id == &"mark":
		bonus = ctx.player.stats.get_int(StatKeys.MARK_MAX_STACKS)
	return data.max_stacks + bonus


func duration_for(status_id: StringName) -> float:
	var data: StatusData = GameDB.status(status_id)
	if data == null:
		return 0.0
	match status_id:
		&"mark":
			return data.duration + ctx.player.stats.get_value(StatKeys.MARK_DURATION)
		&"fracture":
			return data.duration + ctx.player.stats.get_value(StatKeys.FRACTURE_DURATION)
	return data.duration


func apply(target: Combatant, status_id: StringName, stacks: int, source_id: StringName) -> int:
	if target == null or not target.is_alive() or stacks <= 0:
		return 0
	var data: StatusData = GameDB.status(status_id)
	if data == null:
		push_warning("Statut inconnu : %s" % status_id)
		return 0
	if status_id == &"fracture":
		target.statuses.fracture_amp_bonus = ctx.player.stats.get_value(StatKeys.FRACTURE_AMP)
	var added: int = target.statuses.apply(data, stacks, duration_for(status_id), max_stacks_for(status_id), source_id)
	if added > 0:
		ctx.stats.add(StringName("status_" + status_id), added)
		ctx.stats.add(StringName("%s_applied_%s" % [source_id, status_id]), added)
		ctx.events.status_applied.emit(target, status_id, added, source_id)
	return added


## Multiplicateurs de dégâts sur la durée (Brûlure renforcée par l'arbre / les reliques).
func dot_multipliers() -> Dictionary:
	return {&"burn": ctx.player.stats.get_value(StatKeys.BURN_DPS)}


## Fait détoner les Marques d'un ennemi. Retourne le nombre de cumuls consommés.
func detonate(enemy: Enemy, damage_per_stack: float, source_id: StringName) -> int:
	var stacks: int = enemy.statuses.get_stacks(&"mark")
	if stacks <= 0:
		return 0
	enemy.statuses.remove(&"mark")
	var tags: Array[StringName] = [DamageInfo.TAG_DETONATION]
	var info := DamageInfo.make(damage_per_stack * stacks, DamageInfo.SourceKind.ALLY, source_id, tags)
	ctx.events.detonation.emit(enemy, stacks, source_id)
	ctx.stats.add(&"marks_detonated", stacks)
	ctx.fx.burst(enemy.global_position, 26.0 + stacks * 4.0, Color(0.7, 0.95, 1.0, 0.55))
	ctx.combat.deal_damage(enemy, info)
	return stacks
