class_name DraftUpgrades
extends RefCounted
## Améliorations du premier jet : le Chasseur seul. Réutilise les cartes existantes (`UpgradeData` de data/upgrades/,
## effets `StatModifierEffect`, feuille `StatSheet`) et n'en garde que celles qui agissent sur le Chasseur.
## Aucune carte liée aux Échos ne peut entrer : `is_valid` refuse toute condition d'Écho, toute statistique d'équipe
## et tout effet qui a besoin de l'ancienne simulation.

## Sélection du premier jet : cartes de data/upgrades/ puis deux cartes propres à ce mode (draft3d/upgrades/).
const SHARED: Array[StringName] = [&"might", &"cadence", &"vitality", &"swiftness", &"magnetism", &"multishot",
	&"piercing", &"reflexes", &"regeneration", &"shatterbolt"]
const OWN: Array[String] = ["res://draft3d/upgrades/long_reach.tres", "res://draft3d/upgrades/bulwark.tres"]
## Statistiques que ce mode utilise réellement : une carte qui en touche une autre n'améliorerait rien.
const HUNTER_STATS: Array[StringName] = [StatKeys.MAX_HP, StatKeys.REGEN, StatKeys.MOVE_SPEED, StatKeys.PICKUP_RADIUS,
	StatKeys.DAMAGE, StatKeys.ATTACK_SPEED, StatKeys.PROJECTILE_COUNT, StatKeys.PIERCE, StatKeys.BOLT_SPLIT,
	StatKeys.BOLT_RANGE, StatKeys.DASH_COOLDOWN, StatKeys.DAMAGE_TAKEN]

const SPELL_STATS: Array[StringName] = [StatKeys.SPELL_DAMAGE, StatKeys.SPELL_COOLDOWN]
## Cartes de sort (draft3d/spells/, effets `DraftSpellEffect`) : apprendre un sort, ses variantes (une par sort) et
## ses rangs (dégâts, recharge, zone, portée).
const SPELL_CARDS: Array[String] = ["res://draft3d/spells/learn_cleaving_slash.tres",
	"res://draft3d/spells/learn_prismatic_lance.tres", "res://draft3d/spells/learn_rupture.tres",
	"res://draft3d/spells/learn_rift_leap.tres", "res://draft3d/spells/slash_whirlwind.tres",
	"res://draft3d/spells/slash_thrust.tres", "res://draft3d/spells/lance_fan.tres",
	"res://draft3d/spells/lance_overcharge.tres", "res://draft3d/spells/rupture_reaction.tres",
	"res://draft3d/spells/rupture_blaze.tres", "res://draft3d/spells/leap_return.tres",
	"res://draft3d/spells/leap_impact.tres", "res://draft3d/spells/slash_edge.tres",
	"res://draft3d/spells/slash_reach.tres", "res://draft3d/spells/lance_weight.tres",
	"res://draft3d/spells/lance_tempo.tres", "res://draft3d/spells/rupture_charge.tres",
	"res://draft3d/spells/rupture_wide.tres", "res://draft3d/spells/leap_heavy.tres",
	"res://draft3d/spells/leap_momentum.tres", "res://draft3d/spells/learn_parry.tres",
	"res://draft3d/spells/learn_singularity.tres", "res://draft3d/spells/learn_rift_wall.tres",
	"res://draft3d/spells/learn_aegis.tres", "res://draft3d/spells/learn_refracting_crystal.tres",
	"res://draft3d/spells/parry_mirror.tres", "res://draft3d/spells/parry_long_guard.tres",
	"res://draft3d/spells/singularity_horizon.tres", "res://draft3d/spells/singularity_collapse.tres",
	"res://draft3d/spells/wall_chains.tres", "res://draft3d/spells/wall_burning.tres",
	"res://draft3d/spells/aegis_riposte.tres", "res://draft3d/spells/aegis_second_wind.tres",
	"res://draft3d/spells/crystal_double.tres", "res://draft3d/spells/crystal_focus.tres",
	"res://draft3d/spells/parry_counter.tres", "res://draft3d/spells/singularity_depth.tres",
	"res://draft3d/spells/wall_lasting.tres", "res://draft3d/spells/aegis_quick.tres",
	"res://draft3d/spells/crystal_lasting.tres", "res://draft3d/spells/learn_hunter_mark.tres",
	"res://draft3d/spells/learn_void_rend.tres", "res://draft3d/spells/learn_rift_step.tres",
	"res://draft3d/spells/learn_stasis_wave.tres", "res://draft3d/spells/learn_shard_rain.tres",
	"res://draft3d/spells/learn_ash_veil.tres", "res://draft3d/spells/mark_execute.tres",
	"res://draft3d/spells/mark_hunt.tres", "res://draft3d/spells/rend_double.tres",
	"res://draft3d/spells/rend_pierce.tres", "res://draft3d/spells/step_charges.tres",
	"res://draft3d/spells/step_trap.tres", "res://draft3d/spells/stasis_shards.tres",
	"res://draft3d/spells/stasis_circle.tres", "res://draft3d/spells/rain_storm.tres",
	"res://draft3d/spells/rain_focus.tres", "res://draft3d/spells/veil_mobile.tres",
	"res://draft3d/spells/veil_recoil.tres", "res://draft3d/spells/mark_depth.tres",
	"res://draft3d/spells/rend_edge.tres", "res://draft3d/spells/step_quick.tres",
	"res://draft3d/spells/stasis_long.tres", "res://draft3d/spells/rain_wide.tres",
	"res://draft3d/spells/veil_long.tres"]

## Cartes de passifs techniques et d'altération des règles (draft3d/rewards/).
const REWARD_CARDS: Array[String] = ["res://draft3d/rewards/passive_dash_blade.tres",
	"res://draft3d/rewards/passive_void_wake.tres", "res://draft3d/rewards/passive_counter_cut.tres",
	"res://draft3d/rewards/passive_anchor.tres", "res://draft3d/rewards/rule_extra_slot.tres"]

## Cartes de statistiques (hors tirage normal de la v2, tuning.stat_cards_in_pool).
var catalog: Array[UpgradeData] = []
## Cartes de sort, offertes seulement quand `spells` est branché et qu'elles servent.
var spell_cards: Array[UpgradeData] = []
var spells: DraftSpells
## Passifs techniques de l'expédition (cartes PASSIVE) ; réglages du tirage (raretés, cartes retirées du tirage).
var passives: DraftPassives
var tuning: DraftTuning
## Choix de niveau consécutifs sans carte Épique ou Légendaire (anti-frustration, réglable).
var dry_offers: int = 0
## Déblocages permanents : seuls les sorts et les mutations débloqués sont tirés (null : tout le contenu).
var unlocks: DraftUnlocks
var stacks: Dictionary = {}
var _groups: Dictionary = {}


func _init() -> void:
	tuning = load("res://draft3d/tuning.tres")
	for id: StringName in SHARED:
		var data: UpgradeData = GameDB.upgrades.get(id)
		if data != null and is_valid(data):
			catalog.append(data)
	for path: String in OWN:
		var data: UpgradeData = load(path)
		if data != null and is_valid(data):
			catalog.append(data)
	for path: String in SPELL_CARDS + REWARD_CARDS:
		var data: UpgradeData = load(path)
		if data != null and is_spell_card(data):
			spell_cards.append(data)


## Carte de sort : uniquement des effets `DraftSpellEffect` sur un sort raccordé à la 3D.
static func is_spell_card(data: UpgradeData) -> bool:
	if data.effects.is_empty() or not data.requires_any_monster.is_empty():
		return false
	for effect: GameplayEffect in data.effects:
		var spell := effect as DraftSpellEffect
		if spell == null:
			return false
		var needs_spell: bool = spell.kind != DraftSpellEffect.Kind.PASSIVE and spell.kind != DraftSpellEffect.Kind.RULE
		if needs_spell and not DraftSpells.supported(spell.spell_id):
			return false
	return true


## Carte de variante d'un sort (variante de l'arbre du profil appliquée au départ), ou null.
func variant_card(spell_id: StringName, variant: StringName) -> UpgradeData:
	for data: UpgradeData in spell_cards:
		for effect: GameplayEffect in data.effects:
			var spell := effect as DraftSpellEffect
			if spell.kind == DraftSpellEffect.Kind.VARIANT and spell.spell_id == spell_id and spell.variant == variant:
				return data
	return null


func all_cards() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = catalog.duplicate()
	result.append_array(spell_cards)
	return result


## Carte utilisable par le Chasseur seul : aucune condition d'Écho, que des modificateurs de ses statistiques.
static func is_valid(data: UpgradeData) -> bool:
	if not data.requires_any_monster.is_empty() or data.effects.is_empty():
		return false
	for effect: GameplayEffect in data.effects:
		var modifier := effect as StatModifierEffect
		if modifier == null or modifier.target != StatModifierEffect.Target.PLAYER or not HUNTER_STATS.has(modifier.stat):
			return false
	return true


## Statistiques de base du Chasseur, lues dans l'équilibrage commun (data/balance/balance_config.tres).
static func base_stats(balance: BalanceConfig) -> StatSheet:
	var sheet := StatSheet.new()
	var bases := {
		StatKeys.MAX_HP: balance.player_max_hp, StatKeys.REGEN: balance.player_regen,
		StatKeys.MOVE_SPEED: balance.player_move_speed, StatKeys.PICKUP_RADIUS: balance.pickup_radius,
		StatKeys.DAMAGE: 1.0, StatKeys.ATTACK_SPEED: 1.0,
		StatKeys.PROJECTILE_COUNT: float(balance.bolt.projectile_count), StatKeys.PIERCE: float(balance.bolt.pierce),
		StatKeys.BOLT_SPLIT: float(balance.bolt.split), StatKeys.BOLT_RANGE: balance.bolt.attack_range,
		StatKeys.DASH_COOLDOWN: balance.dash_cooldown, StatKeys.DAMAGE_TAKEN: 1.0,
		StatKeys.SPELL_DAMAGE: 1.0, StatKeys.SPELL_COOLDOWN: 1.0,
	}
	for key: StringName in bases:
		sheet.set_base(key, float(bases[key]))
	return sheet


## Arbre de compétences du profil (HunterTree.effects_for, lecture seule) : seuls les nœuds qui modifient une
## statistique du Chasseur ou de ses sorts s'appliquent ici. Renvoie le nombre d'effets appliqués.
static func apply_tree(stats: StatSheet, effects: Array[GameplayEffect]) -> int:
	var applied: int = 0
	for effect: GameplayEffect in effects:
		var modifier := effect as StatModifierEffect
		if modifier != null and modifier.target == StatModifierEffect.Target.PLAYER \
				and (HUNTER_STATS.has(modifier.stat) or SPELL_STATS.has(modifier.stat)):
			stats.add_modifier(modifier.stat, modifier.flat, modifier.pct)
			applied += 1
	return applied


func stacks_of(id: StringName) -> int:
	return int(stacks.get(id, 0))


func can_offer(data: UpgradeData) -> bool:
	if stacks_of(data.id) >= data.max_stacks:
		return false
	if data.exclusive_group != &"" and _groups.get(data.exclusive_group, data.id) != data.id:
		return false
	if spell_cards.has(data):
		if spells == null:
			return false
		for effect: GameplayEffect in data.effects:
			if not _applicable(effect as DraftSpellEffect) or not _unlocked(data, effect as DraftSpellEffect):
				return false
	return true


func _applicable(effect: DraftSpellEffect) -> bool:
	match effect.kind:
		DraftSpellEffect.Kind.PASSIVE:
			return passives != null and not passives.has(effect.passive)
		DraftSpellEffect.Kind.RULE:
			return effect.rule == &"extra_slot" and spells.slots.size() < DraftSpells.MAX_SLOTS
	return spells.can_apply(effect)


## Carte présente au tirage normal de la v2 : ni carte de statistique, ni rang chiffré (réglable dans tuning.tres).
func in_pool(data: UpgradeData) -> bool:
	if catalog.has(data):
		return tuning.stat_cards_in_pool
	for effect: GameplayEffect in data.effects:
		var spell := effect as DraftSpellEffect
		if spell != null and spell.kind == DraftSpellEffect.Kind.MODIFY and not tuning.rank_cards_in_pool:
			return false
	return true


func _unlocked(data: UpgradeData, effect: DraftSpellEffect) -> bool:
	if unlocks == null:
		return true
	match effect.kind:
		DraftSpellEffect.Kind.LEARN:
			return unlocks.is_unlocked(effect.spell_id)
		DraftSpellEffect.Kind.VARIANT:
			return unlocks.is_unlocked(data.id)
	return true


func available() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for data: UpgradeData in all_cards():
		if in_pool(data) and can_offer(data):
			result.append(data)
	return result


## Jusqu'à `count` cartes distinctes, tirées selon leur poids parmi celles qui servent encore.
func roll(rng: RandomNumberGenerator, count: int = 3) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = available()
	var offers: Array[UpgradeData] = []
	while offers.size() < count and not pool.is_empty():
		var total: float = 0.0
		for data: UpgradeData in pool:
			total += _weight(data)
		var pick: float = rng.randf() * total
		var index: int = pool.size() - 1
		for i: int in pool.size():
			pick -= _weight(pool[i])
			if pick <= 0.0:
				index = i
				break
		offers.append(pool[index])
		pool.remove_at(index)
	var rare_found: bool = offers.any(func(d: UpgradeData) -> bool: return DraftCard.rarity_of(d) >= DraftCard.Rarity.EPIC)
	dry_offers = 0 if rare_found else dry_offers + 1
	return offers


## Poids de tirage : poids de la carte × poids de sa rareté (tuning) ; après `pity_after` choix sans Épique ni
## Légendaire, ces raretés pèsent `pity_mult` fois plus (anti-frustration mesuré, jamais garanti).
func _weight(data: UpgradeData) -> float:
	var rarity: int = DraftCard.rarity_of(data)
	var weight: float = maxf(data.weight, 0.01) * float(tuning.rarity_weights[mini(rarity, 3)])
	if rarity >= DraftCard.Rarity.EPIC and dry_offers >= tuning.pity_after:
		weight *= tuning.pity_mult
	return maxf(weight, 0.0001)


func apply(data: UpgradeData, stats: StatSheet) -> bool:
	if not (catalog.has(data) or spell_cards.has(data)) or not can_offer(data):
		return false
	for effect: GameplayEffect in data.effects:
		var modifier := effect as StatModifierEffect
		if modifier != null:
			stats.add_modifier(modifier.stat, modifier.flat, modifier.pct)
		else:
			var spell_effect := effect as DraftSpellEffect
			match spell_effect.kind:
				DraftSpellEffect.Kind.PASSIVE:
					passives.add(spell_effect.passive)
				DraftSpellEffect.Kind.RULE:
					spells.add_slot()
				DraftSpellEffect.Kind.VARIANT:
					# Remplacement explicite seulement (choix du joueur), jamais d'écrasement silencieux.
					var replace: StringName = spells.mutation_to_replace
					spells.mutation_to_replace = &""
					var replaced_label: String = str(spells.mutation_label_of.get(replace, ""))
					if not spells.add_mutation(spell_effect, replace):
						return false
					if replace != &"":
						var kept: Array = spells.mutation_labels.get(spell_effect.spell_id, [])
						kept.erase(replaced_label)
						spells.mutation_labels[spell_effect.spell_id] = kept
					spells.mutation_label_of[spell_effect.variant] = data.name_key
					var labels: Array = spells.mutation_labels.get(spell_effect.spell_id, [])
					labels.append(data.name_key)
					spells.mutation_labels[spell_effect.spell_id] = labels
				_:
					spells.apply_effect(spell_effect)
	stacks[data.id] = stacks_of(data.id) + 1
	if data.exclusive_group != &"":
		_groups[data.exclusive_group] = data.id
	return true
