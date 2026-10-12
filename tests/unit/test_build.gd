extends TestCase

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host, &"ashblade")


func after_each() -> void:
	RunFixture.dispose(run)


func _keys(offers: Array[UpgradeOffer]) -> Array[String]:
	var keys: Array[String] = []
	for offer: UpgradeOffer in offers:
		keys.append(offer.key)
	return keys


func test_offer_count_and_uniqueness() -> void:
	var offers: Array[UpgradeOffer] = UpgradeOffers.roll(run.ctx, 3)
	check_eq(offers.size(), 3, "3 choix proposés")
	var keys: Array[String] = _keys(offers)
	for key: String in keys:
		check_eq(keys.count(key), 1, "pas de doublon (%s)" % key)


func test_max_stacks_respected() -> void:
	var might: UpgradeData = GameDB.upgrade(&"might")
	for i: int in might.max_stacks:
		run.ctx.build.add_upgrade(might)
	check(not _keys(UpgradeOffers.candidates(run.ctx)).has("up:might"), "Puissance retirée au maximum")


func test_exclusive_mutations() -> void:
	UpgradeOffers.apply(run.ctx, _offer_for(&"shatterbolt"))
	var keys: Array[String] = _keys(UpgradeOffers.candidates(run.ctx))
	check(not keys.has("up:marking_bolt") and not keys.has("up:breaking_bolt"), "mutations exclusives entre elles")
	check_eq(run.ctx.player.stats.get_int(StatKeys.BOLT_SPLIT), 2, "Éclatement : 2 éclats")


func test_locked_upgrade_not_offered() -> void:
	check(not _keys(UpgradeOffers.candidates(run.ctx)).has("up:breaking_bolt"), "mutation verrouillée absente")


func test_recruit_requires_free_slot() -> void:
	check(_keys(UpgradeOffers.candidates(run.ctx)).has("recruit:mossback"), "Pacte proposé avec un emplacement libre")
	run.ctx.allies.add_monster(&"mossback")
	var keys: Array[String] = _keys(UpgradeOffers.candidates(run.ctx))
	check(not keys.has("recruit:glimmerwing"), "plus de Pacte quand l'équipe est pleine (2 emplacements)")


func test_evolution_offered_at_rank_three() -> void:
	var keys: Array[String] = _keys(UpgradeOffers.candidates(run.ctx))
	check(not keys.has("evolve:eclipse_blade"), "pas d'évolution au rang 1")
	run.ctx.allies.empower(&"ashblade")
	run.ctx.allies.empower(&"ashblade")
	keys = _keys(UpgradeOffers.candidates(run.ctx))
	check(keys.has("evolve:eclipse_blade") and keys.has("evolve:pyrefang"), "deux branches proposées au rang 3")


func test_evolution_changes_behaviour() -> void:
	var ally: Ally = run.ctx.allies.get_ally(&"ashblade")
	var base_chain: int = ally.attack.chain
	var evo: EvolutionData = GameDB.monster(&"ashblade").evolutions[0]
	run.ctx.allies.evolve(&"ashblade", evo)
	check(ally.attack.chain > base_chain, "Lame-Éclipse : frappes en chaîne")
	check_eq(run.ctx.build.evolutions.get(&"ashblade"), evo.id, "évolution enregistrée")
	check(run.ctx.allies.available_evolutions(ally).is_empty(), "une seule évolution par Écho")


func test_pyrefang_becomes_area_and_burns() -> void:
	var ally: Ally = run.ctx.allies.get_ally(&"ashblade")
	run.ctx.allies.evolve(&"ashblade", GameDB.monster(&"ashblade").evolutions[1])
	check(ally.attack.radius > 0.0, "Brasier-Croc frappe en zone")
	var burns: bool = false
	for application: StatusApplication in ally.attack.statuses:
		burns = burns or application.status_id == &"burn"
	check(burns, "Brasier-Croc inflige Brûlure")


func test_secret_evolution_conditions() -> void:
	run.ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 1.0)
	run.ctx.allies.add_monster(&"glimmerwing", 3)
	var ally: Ally = run.ctx.allies.get_ally(&"glimmerwing")
	var ids: Array[StringName] = []
	for evo: EvolutionData in run.ctx.allies.available_evolutions(ally):
		ids.append(evo.id)
	check(not ids.has(&"prismatic_eclipse"), "secrète indisponible sans le trio et le Prisme fêlé")
	run.ctx.allies.add_monster(&"mossback")
	UpgradeOffers.apply_relic(run.ctx, GameDB.relic(&"cracked_prism"))
	ids.clear()
	for evo: EvolutionData in run.ctx.allies.available_evolutions(ally):
		ids.append(evo.id)
	check(ids.has(&"prismatic_eclipse"), "secrète débloquée : trio + Prisme fêlé")


func test_relic_tradeoff() -> void:
	var player: Player = run.ctx.player
	var max_hp: float = player.max_hp
	var dash: float = player.stats.get_value(StatKeys.DASH_COOLDOWN)
	UpgradeOffers.apply_relic(run.ctx, GameDB.relic(&"cracked_hourglass"))
	check(player.stats.get_value(StatKeys.DASH_COOLDOWN) < dash, "Ruée plus fréquente")
	check(player.max_hp < max_hp, "contrepartie : PV maximum réduits")
	var choices: Array[RelicData] = UpgradeOffers.relic_choices(run.ctx, 10)
	for relic: RelicData in choices:
		check(relic.id != &"cracked_hourglass", "relique possédée non reproposée")


func test_empower_increases_damage() -> void:
	var ally: Ally = run.ctx.allies.get_ally(&"ashblade")
	var before: float = ally.damage_mult()
	run.ctx.allies.empower(&"ashblade")
	check(ally.damage_mult() > before, "l'Éveil augmente les dégâts")


func _offer_for(id: StringName) -> UpgradeOffer:
	var offer := UpgradeOffer.new()
	offer.upgrade = GameDB.upgrade(id)
	offer.kind = UpgradeOffer.Kind.MUTATION if offer.upgrade.kind == UpgradeData.Kind.MUTATION else UpgradeOffer.Kind.STAT
	offer.key = "up:" + String(id)
	return offer
