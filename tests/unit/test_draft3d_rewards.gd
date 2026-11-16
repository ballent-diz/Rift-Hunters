extends TestCase
## Récompenses de la v2 (docs/design/GAMEPLAY_V2_ARCHITECTURE.md, lot 3) : tirage sans cartes de statistique, raretés et
## anti-frustration, deux mutations par sort avec incompatibilités et remplacement explicite, passifs techniques,
## 5e emplacement légendaire unique, XP ralentie et croissance automatique.

var run: DraftRun
var _profile: ProfileData


func before_each() -> void:
	_profile = Profile.profile
	Profile.profile = ProfileData.new()


func after_each() -> void:
	Profile.profile = _profile
	if run != null:
		host.get_tree().paused = false
		run.queue_free()
		run = null


func _start() -> void:
	run = (load("res://draft3d/main.tscn") as PackedScene).instantiate()
	host.add_child(run)
	for frame: int in 600:
		if run.state == DraftRun.State.PLAYING:
			break
		await host.get_tree().physics_frame
	run.boss_time = INF
	run.tuning = run.tuning.duplicate()
	run.tuning.waves.assign([{"at": 0.0, "rate": 0.0, "cap": 0, "mix": {"skitterling": 1.0}}])
	run.tuning.swarm_every = INF
	run._swarm_at = INF
	run.hunter.attack_timer = 100000.0
	run.hunter.god_mode = true


func _frames(count: int) -> void:
	for frame: int in count:
		await host.get_tree().physics_frame


func _card(path: String) -> UpgradeData:
	return load(path)


func _effect(path: String) -> DraftSpellEffect:
	return _card(path).effects[0] as DraftSpellEffect


func test_pool_has_no_stat_cards_and_shows_rarities() -> void:
	await _start()
	var upgrades: DraftUpgrades = run.upgrades
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rarities: Dictionary = {}
	for i: int in 40:
		for data: UpgradeData in upgrades.roll(rng, 3):
			check(not upgrades.catalog.has(data), "aucune carte de statistique : %s" % data.id)
			var effect := data.effects[0] as DraftSpellEffect
			check(effect.kind != DraftSpellEffect.Kind.MODIFY, "aucun rang chiffré : %s" % data.id)
			rarities[DraftCard.rarity_of(data)] = true
	check(rarities.has(DraftCard.Rarity.COMMON) and rarities.has(DraftCard.Rarity.RARE), "raretés variées")
	upgrades.dry_offers = 0
	var epic: UpgradeData = _card("res://draft3d/spells/slash_whirlwind.tres")
	var normal: float = upgrades._weight(epic)
	upgrades.dry_offers = run.tuning.pity_after
	check_near(upgrades._weight(epic), normal * run.tuning.pity_mult, 0.001, "anti-frustration réglable")
	check_eq(DraftCard.rarity_of(_card("res://draft3d/rewards/rule_extra_slot.tres")), DraftCard.Rarity.LEGENDARY,
		"5e emplacement légendaire")


func test_two_mutations_incompatibilities_and_replacement() -> void:
	await _start()
	var spells: DraftSpells = run.spells
	var upgrades: DraftUpgrades = run.upgrades
	var stats: StatSheet = run.hunter.stats
	check(upgrades.apply(_card("res://draft3d/spells/lance_fan.tres"), stats), "Éventail pris")
	var overcharge: UpgradeData = _card("res://draft3d/spells/lance_overcharge.tres")
	check_eq(spells.replaceable_mutations(overcharge.effects[0] as DraftSpellEffect), [&"fan"] as Array[StringName],
		"Surcharge incompatible avec Éventail : seul Éventail peut partir")
	check(not upgrades.apply(overcharge, stats), "jamais d'écrasement silencieux")
	var slash: SpellData = DraftSpells.spell(&"cleaving_slash")
	check(upgrades.apply(_card("res://draft3d/spells/slash_whirlwind.tres"), stats), "Tourbillon pris")
	check(not upgrades.can_offer(_card("res://draft3d/spells/slash_whirlwind.tres")), "une mutation une seule fois")
	spells.learn(&"rupture")
	check(upgrades.apply(_card("res://draft3d/spells/rupture_reaction.tres"), stats), "Réaction prise")
	check(upgrades.apply(_card("res://draft3d/spells/rupture_blaze.tres"), stats), "Brasier pris : deux mutations")
	var rupture: SpellData = DraftSpells.spell(&"rupture")
	check(spells.has_variant(rupture, &"reaction") and spells.has_variant(rupture, &"blaze"), "les deux actives")
	check_near(spells.param(rupture, "burn", 0.0), 0.15, 0.001, "réglages de chaque mutation lus séparément")
	check_near(spells.param(rupture, "damage", 0.0), 0.5, 0.001, "sans collision de clés")
	check_eq(spells.mutation_labels[&"rupture"].size(), 2, "noms des deux mutations pour l'arsenal")
	check(spells.has_variant(slash, &"whirlwind"), "Tourbillon actif")
	spells.mutation_to_replace = &"fan"
	check(upgrades.apply(overcharge, stats), "remplacement explicite d'Éventail par Surcharge")
	var lance: SpellData = DraftSpells.spell(&"prismatic_lance")
	check(spells.has_variant(lance, &"overcharge") and not spells.has_variant(lance, &"fan"), "Éventail remplacé")


func test_mutation_replacement_choice_in_level_up() -> void:
	await _start()
	run.spells.learn(&"rupture")
	run.upgrades.apply(_card("res://draft3d/spells/rupture_reaction.tres"), run.hunter.stats)
	run.upgrades.apply(_card("res://draft3d/spells/rupture_blaze.tres"), run.hunter.stats)
	run.upgrades.unlocks = null
	var unlock_wide: UpgradeData = _card("res://draft3d/spells/rupture_wide.tres")
	check(not run.upgrades.in_pool(unlock_wide), "rang chiffré hors du tirage")
	run.spells.learn(&"rift_leap")
	run.upgrades.apply(_card("res://draft3d/spells/leap_return.tres"), run.hunter.stats)
	run.upgrades.apply(_card("res://draft3d/spells/leap_heavy.tres"), run.hunter.stats)
	var impact: UpgradeData = _card("res://draft3d/spells/leap_impact.tres")
	run._offers = [impact] as Array[UpgradeData]
	run.state = DraftRun.State.CHOOSING
	host.get_tree().paused = true
	run.choose(0)
	await host.get_tree().process_frame
	check(run.hud.find_child("Choice", true, false) == null, "une case de mutation libre : pas de question")
	check(run.spells.has_variant(DraftSpells.spell(&"rift_leap"), &"impact"), "Impact pris en 2e mutation")
	var parry_mirror: UpgradeData = _card("res://draft3d/spells/rupture_reaction.tres")
	check(not run.upgrades.can_offer(parry_mirror), "déjà prise")


func test_passives_and_extra_slot() -> void:
	await _start()
	var upgrades: DraftUpgrades = run.upgrades
	var stats: StatSheet = run.hunter.stats
	check(upgrades.apply(_card("res://draft3d/rewards/passive_dash_blade.tres"), stats), "Ruée tranchante prise")
	check(not upgrades.can_offer(_card("res://draft3d/rewards/passive_dash_blade.tres")), "un passif une fois")
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + Vector3(1.5, 0, 0))
	foe.speed = 0.0
	await _frames(2)
	run.hunter.automating = true
	run.hunter.auto_direction = Vector3.RIGHT
	run.hunter.auto_dash = true
	await _frames(20)
	check(not foe.alive or foe.hp < foe.max_hp, "la Ruée blesse l'ennemi traversé")
	upgrades.apply(_card("res://draft3d/rewards/passive_counter_cut.tres"), stats)
	run.hunter.god_mode = false
	run.hunter.dash_time = 0.2
	run.hunter.invulnerable = 0.2
	run.hunter.take_damage(10.0)
	check_near(run.passives.power(), run.tuning.counter_cut_power, 0.001, "esquive pendant la Ruée : sort renforcé")
	run.spells.cooldowns[0] = 0.0
	run.spells.cast(0, run.hunter.global_position + Vector3(3, 0, 0))
	check_near(run.passives.power(), 1.0, 0.001, "consommé par le sort suivant")
	var rule: UpgradeData = _card("res://draft3d/rewards/rule_extra_slot.tres")
	check(upgrades.can_offer(rule), "5e emplacement proposable")
	check(upgrades.apply(rule, stats) and run.spells.slots.size() == 5, "5e emplacement ouvert")
	check(not upgrades.can_offer(rule), "une seule fois par expédition")


func test_slower_levels_and_automatic_growth() -> void:
	await _start()
	var hunter: DraftHunter = run.hunter
	check_eq(hunter.xp_needed(), int(ceil(GameDB.balance.xp_to_next(1) * run.tuning.xp_scale)), "seuil ralenti")
	var damage: float = hunter.stats.get_value(StatKeys.DAMAGE)
	var max_hp: float = hunter.max_hp()
	hunter.gain_xp(float(hunter.xp_needed()))
	check(hunter.stats.get_value(StatKeys.DAMAGE) > damage, "dégâts en hausse automatique")
	check_near(hunter.max_hp(), max_hp + run.tuning.level_max_hp, 0.001, "PV max en hausse automatique")
