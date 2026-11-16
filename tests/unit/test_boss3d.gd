extends TestCase
## Boss de la base 3D (draft3d/boss_brain.gd, docs/design/BOSS_V2.md) : techniques des données toutes jouables,
## phases et seuils d'origine, changement de feuille par phase, rapprochements et enchaînements, étourdissement,
## mort dédiée.

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
	run.hunter.god_mode = true


func _frames(count: int) -> void:
	for frame: int in count:
		await host.get_tree().physics_frame


func _spawn(id: StringName, distance: float = 6.0) -> DraftEnemies.Foe:
	var at: Vector3 = run.level.closest(run.hunter.global_position + Vector3(distance, 0, 0))
	return run.enemies.spawn_boss(GameDB.boss(id), at)


## Coups qui amènent le boss sous une part de ses PV, quel que soit le multiplicateur du moment.
func _bring_to(foe: DraftEnemies.Foe, ratio: float) -> void:
	foe.hp = foe.max_hp * ratio
	foe.brain._check_phase()


func test_every_data_technique_has_a_3d_gesture() -> void:
	for boss: BossData in GameDB.bosses.values():
		for p: BossPhaseData in boss.phases:
			for pattern: BossPatternData in p.patterns:
				check(DraftBossBrain.GESTURES.has(pattern.kind), "%s : technique %s jouable en 3D" % [boss.id, pattern.kind])


func test_phases_follow_the_data() -> void:
	await _start()
	var glauquemire: DraftEnemies.Foe = _spawn(&"glauquemire")
	check_eq(glauquemire.brain.phase, 0, "Glauquemire commence en phase 1")
	_bring_to(glauquemire, 0.6)
	check_eq(glauquemire.brain.phase, 1, "sous 66 % : phase 2")
	check(glauquemire.brain.damage_mult() < 0.5, "transition : coups réduits")
	check(glauquemire.brain.damage_mult() > 0.0, "jamais totalement invulnérable")
	_bring_to(glauquemire, 0.3)
	check_eq(glauquemire.brain.phase, 2, "sous 33 % : phase 3")
	run.enemies.hit(glauquemire, 1000000.0)
	var abyssarch: DraftEnemies.Foe = _spawn(&"abyssarch")
	var sheets: Dictionary = {}
	for ratio: float in [1.0, 0.8, 0.6, 0.4, 0.25, 0.1]:
		_bring_to(abyssarch, ratio)
		sheets[str(abyssarch.view.entry["sheet"])] = true
	check_eq(abyssarch.brain.phase, 5, "Abyssarque : six formes")
	check_eq(sheets.size(), 6, "une feuille par forme (swap_visual)")
	var source: DraftEnemies.Foe = _spawn(&"source_devourer")
	_bring_to(source, 0.4)
	check_eq(source.view.idle_clip, &"phase2_idle", "Dévoreur des Sources : repos de seconde phase")


func test_far_boss_closes_in_and_chains() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"source_devourer", 16.0)
	foe.brain._next_at = 0.0
	foe.brain._closer_at = 0.0
	await _frames(240)
	var moves: int = 0
	for gesture: StringName in [&"charge", &"leap", &"blink"]:
		moves += int(foe.brain.gestures_played.get(gesture, 0))
	check(moves >= 1, "de loin, il se rapproche (charge, bond ou saut de faille)")
	await _frames(900)
	check(foe.brain.patterns_played >= 4, "techniques des données jouées (%d)" % foe.brain.patterns_played)
	check(foe.brain.gestures_played.size() >= 3, "gestes variés (%s)" % [foe.brain.gestures_played.keys()])


func test_charge_into_wall_stuns() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"pyre_guardian", 5.0)
	foe.brain.stun(1.0)
	check(foe.brain.stunned() and foe.brain.busy(), "étourdi : ni marche ni attaque")
	check_near(foe.brain.damage_mult(), DraftBossBrain.STUN_DAMAGE_MULT, 0.001, "étourdi : coups × 1,5")
	await _frames(80)
	check(not foe.brain.stunned(), "l'étourdissement passe")
	# Charge droit sur le rempart : elle s'arrête contre le décor et l'assomme.
	foe.brain._move = {"kind": &"charge", "dir": Vector3(0, 0, -1), "wait": 0.0, "left": 30.0, "damage": 0.0, "hit": true}
	var stunned: bool = false
	for frame: int in 600:
		await host.get_tree().physics_frame
		if foe.brain.stunned():
			stunned = true
			break
	check(stunned, "une charge contre le décor l'assomme")


func test_boss_death_plays_its_own_animation() -> void:
	await _start()
	var abyssarch: DraftEnemies.Foe = _spawn(&"abyssarch")
	var length: float = abyssarch.brain.die()
	check(str(abyssarch.view.entry["sheet"]).contains("death"), "Abyssarque : feuille de mort dédiée")
	check(length >= 0.6, "clip de mort joué en entier (%.2f s)" % length)
	check_eq(abyssarch.brain.die(), 0.0, "une seule mort")
