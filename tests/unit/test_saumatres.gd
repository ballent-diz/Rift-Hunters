extends TestCase
## Saumâtres et Saumor (draft3d/foe_techniques.gd, draft3d/bosses/saumor.gd, docs/design/TECHNIQUES_ENNEMIS_V2.md) :
## bestiaire du chapitre, sept techniques jouées par de vrais monstres, garde de face, bénédiction plafonnée, charge
## avec récupération, deux phases de Saumor et ses quatre techniques.

var run: DraftRun


func after_each() -> void:
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


## Monstre immobile à `distance` m du Chasseur, prêt à jouer `kind` tout de suite (les autres techniques attendent).
func _foe(id: StringName, distance: float, kind: StringName) -> DraftEnemies.Foe:
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(id), run.level.closest(
		run.hunter.global_position + Vector3(distance, 0, 0)))
	foe.speed = 0.0
	for technique: EnemyTechniqueData in foe.data.techniques:
		foe.tech_ready[technique.kind] = 0.0 if technique.kind == kind else INF
	return foe


func _played(kind: StringName) -> int:
	return int(run.enemies.techniques.played.get(kind, 0))


func _wait_for(kind: StringName, frames: int = 120) -> void:
	for frame: int in frames:
		if _played(kind) > 0:
			return
		await host.get_tree().physics_frame


func test_family_enters_the_tide_marsh_bestiary() -> void:
	var order: int = 0
	for data: ChapterData in DraftRoster.chapters():
		if data.id == &"tide_marsh":
			order = data.order
	var roster: DraftRoster = DraftRoster.for_chapter(order)
	var ids: Array[StringName] = []
	for data: EnemyData in roster.enemies:
		ids.append(data.id)
	for id: StringName in [&"salt_scuttler", &"rope_drowned", &"brine_skate", &"salt_siphon", &"floodgate_keeper",
			&"brine_choir", &"salt_dredger"]:
		check(ids.has(id), "%s dans le bestiaire" % id)
	check(ids.size() <= DraftRoster.MAX_ENEMIES, "plafond du bestiaire")
	check(ids.find(&"salt_dredger") > ids.find(&"salt_scuttler"), "élites après les normaux")
	check(roster.guardians.has(GameDB.boss(&"saumor")), "Saumor parmi les gardiens")
	check(roster.boss != GameDB.boss(&"saumor"), "le Dévoreur du chapitre reste le boss final")
	for id: StringName in ids:
		check(DraftRoster.usable(GameDB.enemy(id)), "%s jouable (feuille présente)" % id)


func test_siphon_jet_leaves_a_slowing_pool() -> void:
	await _start()
	var zones: int = run.hazards.zones()
	_foe(&"salt_siphon", 5.0, &"brine_jet")
	await _wait_for(&"brine_jet")
	check_eq(_played(&"brine_jet"), 1, "Jet de saumure lancé")
	await _frames(70)
	check(run.hazards.zones() > zones, "flaque ralentissante au bout du jet")


func test_keeper_guard_front_and_back_then_mallet() -> void:
	await _start()
	var keeper: DraftEnemies.Foe = _foe(&"floodgate_keeper", 3.0, &"lock_guard")
	await _wait_for(&"lock_guard")
	check(keeper.guard_left > 0.0, "vanne levée")
	var hp: float = keeper.hp
	run.enemies.hit(keeper, 100.0)
	var front: float = hp - keeper.hp
	run.hunter.global_position = keeper.pos + (keeper.pos - run.hunter.global_position)
	hp = keeper.hp
	run.enemies.hit(keeper, 100.0)
	var back: float = hp - keeper.hp
	check(front > 0.0 and back > front * 3.0, "de face : %.1f, de dos : %.1f" % [front, back])
	var slam: DraftEnemies.Foe = _foe(&"floodgate_keeper", 2.0, &"mallet_slam")
	slam.tech_busy = 0.0
	await _wait_for(&"mallet_slam", 200)
	check_eq(_played(&"mallet_slam"), 1, "Frappe du maillet")


func test_choir_bells_and_blessing_capped_to_three() -> void:
	await _start()
	var allies: Array[DraftEnemies.Foe] = []
	for i: int in 5:
		allies.append(_foe(&"salt_scuttler", 8.0 + i * 0.4, &""))
	var choir: DraftEnemies.Foe = _foe(&"brine_choir", 8.0, &"brine_blessing")
	await _wait_for(&"brine_blessing")
	var warded: int = 0
	for ally: DraftEnemies.Foe in allies:
		warded += 1 if ally.ward_left > 0.0 else 0
	check_eq(warded, 3, "trois alliés protégés au plus")
	check(choir.ward_left <= 0.0, "le chantre ne se bénit pas")
	choir.tech_busy = 0.0
	choir.tech_ready[&"bell_call"] = 0.0
	var rings: int = run.hazards.get_child_count()
	await _wait_for(&"bell_call", 200)
	check_eq(_played(&"bell_call"), 1, "Appel des cloches")
	check(run.hazards.get_child_count() >= rings + 2, "deux ondes annoncées")


func test_dredger_charge_moves_then_recovers_and_burst() -> void:
	await _start()
	var dredger: DraftEnemies.Foe = _foe(&"salt_dredger", 7.0, &"scoop_charge")
	var start: Vector3 = dredger.pos
	await _wait_for(&"scoop_charge")
	check(not dredger.charge.is_empty(), "charge annoncée")
	# Annonce 0,85 s puis course de 9 m à 13 m/s (≈ 92 images), puis 1,3 s de récupération.
	await _frames(105)
	check(dredger.pos.distance_to(start) > 2.0, "course droite (%.1f m)" % dredger.pos.distance_to(start))
	check(dredger.charge.is_empty() and dredger.tech_busy > 0.0, "récupération après la charge")
	var burst: DraftEnemies.Foe = _foe(&"salt_dredger", 2.5, &"salt_crust_burst")
	await _wait_for(&"salt_crust_burst")
	check_eq(_played(&"salt_crust_burst"), 1, "Éclatement salin")
	check(burst.tech_busy > 0.0, "fenêtre de récupération")


func test_techniques_need_sight_and_same_level() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _foe(&"salt_siphon", 5.0, &"brine_jet")
	run.hunter.global_position += Vector3.UP * 3.0
	await _frames(20)
	check_eq(_played(&"brine_jet"), 0, "autre niveau : rien")
	check(foe.tech_busy <= 0.0, "aucune annonce")


func test_saumor_two_phases_and_signature() -> void:
	await _start()
	var at: Vector3 = run.level.closest(run.hunter.global_position + Vector3(5, 0, 0))
	var foe: DraftEnemies.Foe = run.enemies.spawn_boss(GameDB.boss(&"saumor"), at)
	var brain: DraftBossBrain = foe.brain
	var saumor: DraftSaumor = null
	for mechanic: DraftBossMechanic in brain.mechanics:
		if mechanic is DraftSaumor:
			saumor = mechanic
	check(saumor != null, "mécanique de Saumor branchée")
	var kinds: Array[StringName] = []
	for pattern: BossPatternData in GameDB.boss(&"saumor").phases[0].patterns:
		kinds.append(pattern.kind)
	check(kinds.has(&"gate_pull") and kinds.has(&"shoulder_slam"), "phase 1 : aspiration et épaule")
	var pull: BossPatternData = GameDB.boss(&"saumor").phases[0].patterns[0]
	var before: float = run.hunter.global_position.distance_to(foe.pos)
	brain._perform(pull, run.hunter.global_position - foe.pos, before)
	await _frames(int((pull.telegraph + 1.0) * 60.0))
	check(run.hunter.global_position.distance_to(foe.pos) < before - 0.5 or saumor.pulls_broken > 0,
		"aspiré vers le siphon (%.1f → %.1f m)" % [before, run.hunter.global_position.distance_to(foe.pos)])
	await _frames(120)
	run.hunter.global_position = foe.pos + Vector3(8, 0, 0)
	brain._perform(pull, run.hunter.global_position - foe.pos, 8.0)
	await _frames(int(pull.telegraph * 60.0) + 2)
	run.hunter.dash_time = 0.2
	await _frames(2)
	check(saumor.pull.is_empty() and saumor.pulls_broken >= 1, "une Ruée rompt l'aspiration")
	foe.hp = foe.max_hp * 0.45
	brain._check_phase()
	check_eq(brain.phase, 1, "phase 2 sous la moitié des PV")
	check_eq(foe.view.idle_clip, &"phase2_idle", "repos de phase 2")
	check_eq(foe.view.move_clip, &"phase2_move", "marche de phase 2")
	var hazards: int = run.hazards.get_child_count()
	for pattern: BossPatternData in GameDB.boss(&"saumor").phases[1].patterns:
		brain._perform(pattern, run.hunter.global_position - foe.pos, 5.0)
	check(run.hazards.get_child_count() >= hazards + 7 + 11, "balayage en couloirs et deux pulsations annoncés")
	check(brain.kinds_played.has(&"brine_sweep") and brain.kinds_played.has(&"core_burst"), "phase 2 jouée")
