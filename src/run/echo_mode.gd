class_name EchoMode
extends RefCounted
## Modes des Échos à l'essai (retour du propriétaire, 9 novembre 2026 : « trop de monde autour du Chasseur, trop de
## sorts à gérer »). Le mode actuel reste le défaut ; les deux prototypes s'activent dans les options.
## - CURRENT : les trois Échos sur le terrain, une touche de Technique chacun.
## - RELAY : l'équipe reste composée de trois Échos, un seul combat ; une touche fait entrer le suivant (attaque
##   d'entrée = sa Technique, lancée gratuitement), les deux autres attendent en réserve.
## - SOLO : aucun Écho sur le terrain ; le Chasseur est renforcé (BalanceConfig) et garde les bonus passifs et les
##   affinités des Échos équipés.

const CURRENT := &"current"
const RELAY := &"relay"
const SOLO := &"solo"
const ALL: Array[StringName] = [CURRENT, RELAY, SOLO]


static func is_valid(mode: StringName) -> bool:
	return ALL.has(mode)


static func sanitize(mode: Variant) -> StringName:
	var value := StringName(str(mode))
	return value if is_valid(value) else CURRENT


static func next(mode: StringName) -> StringName:
	return ALL[(ALL.find(sanitize(mode)) + 1) % ALL.size()]


## Clé de traduction du nom du mode (options, pause, rapport).
static func name_key(mode: StringName) -> String:
	return "ECHO_MODE_" + String(sanitize(mode)).to_upper()


## Mode Solo : renforts du Chasseur, installés une fois au départ (bonus en pourcentage cumulés aux autres ; les
## dégâts comptent aussi pour les sorts du Chasseur).
static func install_hunter_bonus(ctx: RunContext) -> void:
	if ctx.setup.echo_mode != SOLO:
		return
	var b: BalanceConfig = ctx.balance
	var stats: StatSheet = ctx.player.stats
	stats.add_modifier(StatKeys.DAMAGE, 0.0, b.solo_damage_pct)
	stats.add_modifier(StatKeys.MAX_HP, 0.0, b.solo_max_hp_pct)
	stats.add_modifier(StatKeys.ATTACK_SPEED, 0.0, b.solo_attack_speed_pct)
	stats.add_modifier(StatKeys.SPELL_COOLDOWN, 0.0, -b.solo_spell_cooldown_pct)
