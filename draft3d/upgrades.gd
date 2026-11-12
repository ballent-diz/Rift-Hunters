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

var catalog: Array[UpgradeData] = []
var stacks: Dictionary = {}
var _groups: Dictionary = {}


func _init() -> void:
	for id: StringName in SHARED:
		var data: UpgradeData = GameDB.upgrades.get(id)
		if data != null and is_valid(data):
			catalog.append(data)
	for path: String in OWN:
		var data: UpgradeData = load(path)
		if data != null and is_valid(data):
			catalog.append(data)


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
	}
	for key: StringName in bases:
		sheet.set_base(key, float(bases[key]))
	return sheet


func stacks_of(id: StringName) -> int:
	return int(stacks.get(id, 0))


func can_offer(data: UpgradeData) -> bool:
	if stacks_of(data.id) >= data.max_stacks:
		return false
	if data.exclusive_group != &"" and _groups.get(data.exclusive_group, data.id) != data.id:
		return false
	return true


func available() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for data: UpgradeData in catalog:
		if can_offer(data):
			result.append(data)
	return result


## Jusqu'à `count` cartes distinctes, tirées selon leur poids parmi celles qui servent encore.
func roll(rng: RandomNumberGenerator, count: int = 3) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = available()
	var offers: Array[UpgradeData] = []
	while offers.size() < count and not pool.is_empty():
		var total: float = 0.0
		for data: UpgradeData in pool:
			total += maxf(data.weight, 0.01)
		var pick: float = rng.randf() * total
		var index: int = pool.size() - 1
		for i: int in pool.size():
			pick -= maxf(pool[i].weight, 0.01)
			if pick <= 0.0:
				index = i
				break
		offers.append(pool[index])
		pool.remove_at(index)
	return offers


func apply(data: UpgradeData, stats: StatSheet) -> bool:
	if not catalog.has(data) or not can_offer(data):
		return false
	for effect: GameplayEffect in data.effects:
		var modifier := effect as StatModifierEffect
		stats.add_modifier(modifier.stat, modifier.flat, modifier.pct)
	stacks[data.id] = stacks_of(data.id) + 1
	if data.exclusive_group != &"":
		_groups[data.exclusive_group] = data.id
	return true
