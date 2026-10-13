extends TestCase
## Intégrité des données : chargement, identifiants, références croisées.


func test_no_load_errors() -> void:
	check(GameDB.load_errors.is_empty(), "erreurs de chargement : %s" % ", ".join(GameDB.load_errors))


func test_minimum_content() -> void:
	check(GameDB.monsters.size() >= 3, "au moins 3 Échos")
	check(GameDB.enemies.size() >= 4, "au moins 4 ennemis")
	check(GameDB.bosses.size() >= 1, "au moins un boss")
	check(GameDB.upgrades.size() >= 10, "au moins 10 améliorations")


func test_status_references() -> void:
	for app: StatusApplication in _all_status_applications():
		check(GameDB.status(app.status_id) != null, "statut inconnu : %s" % app.status_id)


func test_monsters_are_complete() -> void:
	for id: StringName in GameDB.monsters:
		var m: MonsterData = GameDB.monsters[id]
		check(m.attack != null and m.technique != null and m.visual != null, "%s : attaque/technique/visuel" % id)
		check(m.evolutions.size() >= 2, "%s : au moins deux évolutions" % id)
		check(m.mastery != null and m.mastery.challenges.size() >= 2, "%s : maîtrise et défis" % id)
		check(AllyBehaviors.create(m.behavior_id).get_script() != AllyBehavior, "%s : comportement connu" % id)
		for evo: EvolutionData in m.evolutions:
			for needed: StringName in evo.requires_monsters:
				check(GameDB.monster(needed) != null, "%s : évolution requiert un Écho inconnu" % evo.id)
			for relic: StringName in evo.requires_relics:
				check(GameDB.relic(relic) != null, "%s : évolution requiert une relique inconnue" % evo.id)


func test_monsters_play_differently() -> void:
	var signatures: Dictionary = {}
	for id: StringName in GameDB.monsters:
		var m: MonsterData = GameDB.monsters[id]
		var signature: String = "%s|%s|%s" % [m.behavior_id, m.technique.technique_kind, m.role]
		check(not signatures.has(signature), "%s duplique le gameplay de %s" % [id, signatures.get(signature, "")])
		signatures[signature] = id


func test_arena_references() -> void:
	for id: StringName in GameDB.arenas:
		var arena: ArenaData = GameDB.arenas[id]
		check(GameDB.boss(arena.boss_id) != null, "%s : boss inconnu" % id)
		check(not arena.waves.is_empty(), "%s : aucune vague" % id)
		for wave: WavePhaseData in arena.waves:
			check(wave.weights.size() == wave.enemies.size(), "%s : poids et ennemis alignés" % id)
			for enemy_id: StringName in wave.enemies:
				check(GameDB.enemy(enemy_id) != null, "%s : ennemi inconnu %s" % [id, enemy_id])


func test_boss_patterns_exist_in_code() -> void:
	var methods: Array[String] = []
	for method: Dictionary in (load("res://src/entities/bosses/boss_controller.gd") as Script).get_script_method_list():
		methods.append(method["name"])
	for id: StringName in GameDB.bosses:
		var boss: BossData = GameDB.bosses[id]
		check(boss.phases.size() >= 2, "%s : plusieurs phases" % id)
		for phase: BossPhaseData in boss.phases:
			for pattern: BossPatternData in phase.patterns:
				check(methods.has("_pattern_" + String(pattern.kind)),
					"%s : attaque %s non implémentée" % [id, pattern.kind])


func test_synergies_reference_monsters() -> void:
	for id: StringName in GameDB.synergies:
		var synergy: SynergyData = GameDB.synergies[id]
		check(not synergy.effects.is_empty(), "%s : aucun effet" % id)
		for monster: StringName in synergy.required_monsters:
			check(GameDB.monster(monster) != null, "%s : Écho inconnu %s" % [id, monster])


func test_difficulties_are_ordered() -> void:
	var levels: Array[DifficultyData] = GameDB.difficulties_by_level()
	check(not levels.is_empty() and levels[0].unlocked_by_default, "la Tension 0 est débloquée")
	for i: int in range(1, levels.size()):
		check(levels[i].reward_mult > levels[i - 1].reward_mult, "les récompenses montent avec la Tension")


func _all_status_applications() -> Array[StatusApplication]:
	var result: Array[StatusApplication] = []
	for id: StringName in GameDB.monsters:
		var m: MonsterData = GameDB.monsters[id]
		result.append_array(m.attack.statuses)
		result.append_array(m.technique.statuses)
		for evo: EvolutionData in m.evolutions:
			if evo.attack:
				result.append_array(evo.attack.statuses)
	return result
