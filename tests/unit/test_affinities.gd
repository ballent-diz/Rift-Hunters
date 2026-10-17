extends TestCase
## Lot C6 : 3 Échos maximum, 8 affinités (2 par Écho), bonus d'affinité à 2 et 3 Échos.

const AFFINITIES: Array[StringName] = [&"ember", &"storm", &"light", &"void", &"stone", &"nature", &"predator",
	&"guardian"]

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func test_every_echo_has_two_of_the_eight_affinities() -> void:
	for id: StringName in GameDB.monsters:
		var monster: MonsterData = GameDB.monsters[id]
		check_eq(monster.affinities.size(), 2, "%s : 2 affinités" % id)
		for affinity: StringName in monster.affinities:
			check(AFFINITIES.has(affinity), "%s : affinité connue (%s)" % [id, affinity])
		for evo: EvolutionData in monster.evolutions:
			for affinity: StringName in evo.added_affinities:
				check(AFFINITIES.has(affinity), "%s : affinité d'évolution connue (%s)" % [evo.id, affinity])


func test_each_affinity_has_two_tiers_of_bonus() -> void:
	for affinity: StringName in AFFINITIES:
		for count: int in [2, 3]:
			var found: bool = false
			for id: StringName in GameDB.synergies:
				var synergy: SynergyData = GameDB.synergies[id]
				if int(synergy.required_affinities.get(String(affinity), 0)) == count and not synergy.effects.is_empty():
					found = true
			check(found, "bonus %s à %d Échos" % [affinity, count])


func test_team_is_capped_at_three() -> void:
	run = RunFixture.create(host, &"ashblade")
	run.ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 5.0, 0.0)
	check_eq(run.ctx.allies.team_slots(), 3, "3 emplacements au maximum, même avec des bonus")


func test_affinity_bonus_at_two_then_three() -> void:
	run = RunFixture.create(host, &"ashblade")
	run.ctx.player.stats.add_modifier(StatKeys.TEAM_SLOTS, 1.0, 0.0)
	run.ctx.allies.add_monster(&"gloommaw")
	check(run.ctx.build.active_synergies.has(&"predators"), "Prédateur (2) : Cendrelame + Gueule-d'ombre")
	check(not run.ctx.build.active_synergies.has(&"affinity_predator_3"), "pas encore le palier 3")
	var elite: float = run.ctx.player.stats.get_value(StatKeys.ELITE_DAMAGE)
	run.ctx.allies.add_monster(&"voltwisp")
	check(run.ctx.build.active_synergies.has(&"affinity_predator_3"), "Prédateur (3) avec Fulgurine")
	check(run.ctx.player.stats.get_value(StatKeys.ELITE_DAMAGE) > elite, "bonus contre les élites appliqué")
