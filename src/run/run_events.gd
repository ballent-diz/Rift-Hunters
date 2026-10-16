class_name RunEvents
extends Node
## Bus d'événements d'une partie. Les effets s'y abonnent ; le combat ignore qui écoute.

signal enemy_damaged(enemy: Enemy, info: DamageInfo, amount: float)
signal enemy_killed(enemy: Enemy, info: DamageInfo)
signal status_applied(target: Combatant, status_id: StringName, added: int, source_id: StringName)
signal detonation(enemy: Enemy, stacks: int, source_id: StringName)
signal player_hurt(amount: float)
signal player_dashed(from: Vector2, to: Vector2)
## Un coup a été évité pendant la Ruée.
signal player_dodged
signal technique_cast(monster_id: StringName, technique_kind: StringName)
signal spell_cast(spell_id: StringName)
signal well_tick(enemies: Array, source_id: StringName)
signal team_changed
signal synergy_activated(synergy_id: StringName)
signal synergy_proc(synergy_id: StringName)
signal level_up(level: int)
signal upgrade_taken(id: StringName)
signal relic_gained(id: StringName)
signal evolution_taken(monster_id: StringName, evolution_id: StringName)
signal elite_spawned(enemy: Enemy)
signal event_started(name_key: String)
signal boss_spawned(boss: Enemy)
signal boss_phase_changed(phase: int)
signal boss_defeated(boss: Enemy)
signal chest_collected
signal capture_completed(monster_id: StringName)
signal run_finished(victory: bool)
