class_name UpgradeOffers
extends RefCounted
## Construit et applique les offres de niveau et de coffre. Fonctions pures autour du RunContext (testables).

const WEIGHT_RECRUIT := 1.6
const WEIGHT_EMPOWER := 1.0
const WEIGHT_EVOLVE := 4.0
## Jalons de campagne : reliques proposées à chaque choix (en plus des mutations et des Échos).
const MILESTONE_RELICS := 2
const WEIGHT_RELIC := 1.2


static func is_upgrade_unlocked(ctx: RunContext, upgrade: UpgradeData) -> bool:
	if ctx.setup.unlocked_upgrades.is_empty():
		return upgrade.unlocked_by_default
	return ctx.setup.unlocked_upgrades.has(upgrade.id)


static func is_monster_unlocked(ctx: RunContext, monster: MonsterData) -> bool:
	if ctx.setup.unlocked_monsters.is_empty():
		return monster.unlocked_by_default
	return ctx.setup.unlocked_monsters.has(monster.id)


static func is_relic_unlocked(ctx: RunContext, relic: RelicData) -> bool:
	if ctx.setup.unlocked_relics.is_empty():
		return relic.unlocked_by_default
	return ctx.setup.unlocked_relics.has(relic.id)


static func _requires_ok(ctx: RunContext, required: Array[StringName]) -> bool:
	if required.is_empty():
		return true
	for id: StringName in required:
		if ctx.has_monster(id):
			return true
	return false


static func candidates(ctx: RunContext) -> Array[UpgradeOffer]:
	var result: Array[UpgradeOffer] = []
	var mutation_weight: float = ctx.player.stats.get_value(StatKeys.MUTATION_WEIGHT)
	for id: StringName in GameDB.sorted_ids(GameDB.upgrades):
		var upgrade: UpgradeData = GameDB.upgrades[id]
		var offer_key: String = "up:" + String(id)
		if ctx.build.banished.has(StringName(offer_key)) or not is_upgrade_unlocked(ctx, upgrade):
			continue
		if ctx.build.stacks_of(id) >= upgrade.max_stacks or ctx.build.is_blocked_by_exclusive(upgrade):
			continue
		if not _requires_ok(ctx, upgrade.requires_any_monster):
			continue
		# Campagne : pas de petites caractéristiques (l'arbre du Chasseur les donne), seulement les mutations.
		if ctx.milestones() and upgrade.kind != UpgradeData.Kind.MUTATION:
			continue
		var offer := UpgradeOffer.new()
		offer.kind = UpgradeOffer.Kind.MUTATION if upgrade.kind == UpgradeData.Kind.MUTATION else UpgradeOffer.Kind.STAT
		offer.key = offer_key
		offer.upgrade = upgrade
		offer.weight = upgrade.weight * (mutation_weight if upgrade.kind == UpgradeData.Kind.MUTATION else 1.0)
		result.append(offer)
	if ctx.allies.has_free_slot():
		for id: StringName in GameDB.sorted_ids(GameDB.monsters):
			var monster: MonsterData = GameDB.monsters[id]
			var key: String = "recruit:" + String(id)
			if ctx.has_monster(id) or not is_monster_unlocked(ctx, monster) or ctx.build.banished.has(StringName(key)):
				continue
			result.append(_dynamic(UpgradeOffer.Kind.RECRUIT, key, id, null, WEIGHT_RECRUIT))
	for ally: Ally in ctx.allies.team:
		var id: StringName = ally.data.id
		if ally.rank < ctx.balance.ally_rank_max and not ctx.build.banished.has(StringName("empower:" + String(id))):
			result.append(_dynamic(UpgradeOffer.Kind.EMPOWER, "empower:" + String(id), id, null, WEIGHT_EMPOWER))
		for evo: EvolutionData in ctx.allies.available_evolutions(ally):
			result.append(_dynamic(UpgradeOffer.Kind.EVOLVE, "evolve:" + String(evo.id), id, evo, WEIGHT_EVOLVE))
	if ctx.milestones() and ctx.balance.feature_enabled(&"relics"):
		for relic: RelicData in relic_choices(ctx, MILESTONE_RELICS):
			var offer: UpgradeOffer = _dynamic(UpgradeOffer.Kind.RELIC, "relic:" + String(relic.id), &"", null, WEIGHT_RELIC)
			offer.relic = relic
			result.append(offer)
	return result


static func _dynamic(kind: UpgradeOffer.Kind, key: String, monster_id: StringName, evo: EvolutionData,
		weight: float) -> UpgradeOffer:
	var offer := UpgradeOffer.new()
	offer.kind = kind
	offer.key = key
	offer.monster_id = monster_id
	offer.evolution = evo
	offer.weight = weight
	return offer


## Tirage pondéré sans remise. Retourne des offres de secours si le réservoir est vide.
static func roll(ctx: RunContext, count: int) -> Array[UpgradeOffer]:
	var pool: Array[UpgradeOffer] = candidates(ctx)
	var picked: Array[UpgradeOffer] = []
	while picked.size() < count and not pool.is_empty():
		var total: float = 0.0
		for offer: UpgradeOffer in pool:
			total += offer.weight
		var roll_value: float = ctx.rng.randf() * total
		var index: int = pool.size() - 1
		for i: int in pool.size():
			roll_value -= pool[i].weight
			if roll_value <= 0.0:
				index = i
				break
		picked.append(pool[index])
		pool.remove_at(index)
	if picked.is_empty():
		picked.append(_dynamic(UpgradeOffer.Kind.HEAL, "heal", &"", null, 1.0))
		picked.append(_dynamic(UpgradeOffer.Kind.SHARDS, "shards", &"", null, 1.0))
	return picked


static func apply(ctx: RunContext, offer: UpgradeOffer) -> void:
	match offer.kind:
		UpgradeOffer.Kind.STAT, UpgradeOffer.Kind.MUTATION:
			ctx.build.add_upgrade(offer.upgrade)
			for effect: GameplayEffect in offer.upgrade.effects:
				effect.install(ctx, &"")
			if offer.kind == UpgradeOffer.Kind.MUTATION:
				ctx.stats.add(&"mutations_taken")
			ctx.events.upgrade_taken.emit(offer.upgrade.id)
		UpgradeOffer.Kind.RECRUIT:
			ctx.allies.add_monster(offer.monster_id, ctx.player.stats.get_int(StatKeys.RECRUIT_RANK))
		UpgradeOffer.Kind.EMPOWER:
			ctx.allies.empower(offer.monster_id)
		UpgradeOffer.Kind.EVOLVE:
			ctx.allies.evolve(offer.monster_id, offer.evolution)
		UpgradeOffer.Kind.HEAL:
			ctx.player.heal(ctx.player.max_hp * 0.3)
		UpgradeOffer.Kind.SHARDS:
			ctx.stats.add(&"shards_earned_raw", 15.0)
		UpgradeOffer.Kind.RELIC:
			apply_relic(ctx, offer.relic)
	ctx.stats.add(&"upgrades_taken")


static func relic_choices(ctx: RunContext, count: int) -> Array[RelicData]:
	var pool: Array[RelicData] = []
	for id: StringName in GameDB.sorted_ids(GameDB.relics):
		var relic: RelicData = GameDB.relics[id]
		if ctx.build.relics.has(id) or not is_relic_unlocked(ctx, relic):
			continue
		if not _requires_ok(ctx, relic.requires_any_monster):
			continue
		pool.append(relic)
	var picked: Array[RelicData] = []
	while picked.size() < count and not pool.is_empty():
		picked.append(pool.pop_at(ctx.rng.randi() % pool.size()))
	return picked


static func apply_relic(ctx: RunContext, relic: RelicData) -> void:
	ctx.build.relics.append(relic.id)
	for effect: GameplayEffect in relic.effects:
		effect.install(ctx, &"")
	ctx.stats.add(&"relics_taken")
	ctx.events.relic_gained.emit(relic.id)
