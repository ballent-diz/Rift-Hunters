class_name DamageBonusEffect
extends GameplayEffect
## Bonus de dégâts conditionnel (cible sous un statut, cible élite/boss...).

@export var source_filter: StringName = &"any"
@export var required_tag: StringName = &""
## Statut que la cible doit avoir (vide = aucun).
@export var target_status: StringName = &""
@export var only_elites_and_bosses: bool = false
## Bonus seulement si la cible a moins de ce ratio de PV (1 = toujours).
@export_range(0.0, 1.0) var target_hp_below: float = 1.0
@export var bonus_pct: float = 0.5


func install(ctx: RunContext, owner_id: StringName) -> void:
	ctx.combat.add_damage_modifier(func(enemy: Enemy, info: DamageInfo) -> float:
		if not GameplayEffect.matches_source(source_filter, owner_id, info):
			return 1.0
		if required_tag != &"" and not info.has_tag(required_tag):
			return 1.0
		if target_status != &"" and not enemy.statuses.has(target_status):
			return 1.0
		if only_elites_and_bosses and not (enemy.is_elite or enemy.is_boss):
			return 1.0
		if target_hp_below < 1.0 and enemy.hp > enemy.max_hp * target_hp_below:
			return 1.0
		return 1.0 + bonus_pct
	)
