class_name CombatSystem
extends Node
## Calcule et applique les dégâts. Ordre : modificateurs d'effets → élites → défense → statuts.

var ctx: RunContext
var _damage_modifiers: Array[Callable] = []
var _player_damage_modifiers: Array[Callable] = []
var _queue: Array[Callable] = []


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx


## modifier(enemy: Enemy, info: DamageInfo) -> float (multiplicateur).
func add_damage_modifier(modifier: Callable) -> void:
	_damage_modifiers.append(modifier)


## modifier(amount: float) -> float (multiplicateur) pour les dégâts subis par le Chasseur.
func add_player_damage_modifier(modifier: Callable) -> void:
	_player_damage_modifiers.append(modifier)


## Action différée en fin de frame (évite les récursions d'effets en chaîne).
func queue(action: Callable) -> void:
	_queue.append(action)


func flush_queue() -> void:
	var guard: int = 0
	while not _queue.is_empty() and guard < 8:
		var actions: Array[Callable] = _queue.duplicate()
		_queue.clear()
		for action: Callable in actions:
			action.call()
		guard += 1


static func defense_multiplier(defense: float) -> float:
	return 100.0 / (100.0 + maxf(defense, 0.0))


func compute_damage(enemy: Enemy, info: DamageInfo) -> float:
	var amount: float = info.amount
	for modifier: Callable in _damage_modifiers:
		amount *= float(modifier.call(enemy, info))
	if (enemy.is_elite or enemy.is_boss) and info.is_friendly():
		amount *= ctx.player.stats.get_value(StatKeys.ELITE_DAMAGE)
	amount *= defense_multiplier(enemy.get_defense())
	amount *= enemy.get_damage_taken_mult()
	return maxf(amount, 1.0) if amount > 0.0 else 0.0


## Inflige des dégâts à un ennemi. Retourne les dégâts réellement infligés.
func deal_damage(enemy: Enemy, info: DamageInfo) -> float:
	if enemy == null or not enemy.is_alive() or enemy.is_invulnerable():
		return 0.0
	var amount: float = compute_damage(enemy, info)
	if amount <= 0.0:
		return 0.0
	var died: bool = enemy.apply_damage(amount)
	ctx.stats.record_damage(info.source_id, amount)
	if info.knockback > 0.0 and not enemy.is_boss:
		enemy.push(info.direction * info.knockback * (1.0 - enemy.data_knockback_resist()))
	ctx.fx.damage_number(enemy.global_position, amount, info)
	for application: StatusApplication in info.statuses:
		if application.chance >= 1.0 or ctx.rng.randf() <= application.chance:
			ctx.status_system.apply(enemy, application.status_id, application.stacks, info.source_id)
	ctx.events.enemy_damaged.emit(enemy, info, amount)
	if died:
		ctx.stats.record_kill(info.source_id)
		ctx.events.enemy_killed.emit(enemy, info)
		ctx.enemies.on_enemy_died(enemy, info)
	return amount


## Dégâts subis par le Chasseur (contact, projectiles, zones).
func damage_player(amount: float, source_id: StringName) -> float:
	var player: Player = ctx.player
	if not player.can_be_hurt():
		return 0.0
	var final: float = amount * player.stats.get_value(StatKeys.DAMAGE_TAKEN)
	for modifier: Callable in _player_damage_modifiers:
		final *= float(modifier.call(final))
	final = maxf(final, 1.0)
	player.receive_damage(final)
	ctx.stats.add(&"damage_taken", final)
	ctx.stats.record_damage(StringName("taken_" + source_id), final)
	ctx.events.player_hurt.emit(final)
	return final
