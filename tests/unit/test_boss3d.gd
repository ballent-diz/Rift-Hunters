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


func _orb_pattern(boss: BossData, golden: int) -> BossPatternData:
	for p: BossPhaseData in boss.phases:
		for pattern: BossPatternData in p.patterns:
			if pattern.kind == &"source_orb" and int(pattern.params.get("golden", 0)) == golden \
					and int(pattern.params.get("count", 1)) == (1 if golden == 0 else 3):
				return pattern
	return null


func test_source_orbs_are_sent_back_by_a_dash() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"source_devourer", 7.0)
	var orbs: DraftSourceOrbs = null
	for mechanic: DraftBossMechanic in foe.brain.mechanics:
		if mechanic is DraftSourceOrbs:
			orbs = mechanic
	check(orbs != null, "Dévoreur des Sources : mécanique des orbes")
	foe.brain._next_at = INF
	var single: BossPatternData = _orb_pattern(foe.boss, 0)
	check(single != null, "orbe simple dans les données")
	orbs.perform(single)
	await _frames(30)
	check_eq(orbs.orbs.size(), 1, "un orbe en vol")
	var hp: float = foe.hp
	# Ruée continue : l'orbe qui arrive est renvoyé sur le boss.
	for frame: int in 400:
		run.hunter.dash_time = 0.2
		await host.get_tree().physics_frame
		if orbs.reflected > 0 and orbs.orbs.is_empty():
			break
	check(orbs.reflected >= 1, "une Ruée renvoie l'orbe")
	check(foe.hp < hp, "l'orbe renvoyé blesse le Dévoreur")
	var salvo: BossPatternData = _orb_pattern(foe.boss, 1)
	orbs.perform(salvo)
	await _frames(30)
	check_eq(orbs.orbs.size(), 3, "salve de trois orbes")
	var golden: Dictionary = {}
	for orb: Dictionary in orbs.orbs:
		if orb["golden"]:
			golden = orb
	golden["reflected"] = true
	for frame: int in 200:
		await host.get_tree().physics_frame
		if foe.brain.stunned():
			break
	check(foe.brain.stunned(), "l'orbe doré renvoyé l'étourdit")
	foe.brain.die()
	check(orbs.orbs.is_empty(), "orbes retirés à la mort")


func _mechanic(foe: DraftEnemies.Foe, kind: StringName) -> DraftBossMechanic:
	for mechanic: DraftBossMechanic in foe.brain.mechanics:
		if mechanic.handles(kind):
			return mechanic
	return null


func _pattern(boss: BossData, kind: StringName) -> BossPatternData:
	for p: BossPhaseData in boss.phases:
		for pattern: BossPatternData in p.patterns:
			if pattern.kind == kind:
				return pattern
	return null


func test_star_crown_rewards_getting_inside() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"astravorn", 2.0)
	var crown := _mechanic(foe, &"star_crown") as DraftStarCrown
	check(crown != null, "Astravorn : couronne d'astres")
	foe.brain._next_at = INF
	var pattern: BossPatternData = _pattern(foe.boss, &"star_crown")
	crown.perform(pattern)
	check_eq(crown.star_positions().size(), 12, "16 étoiles moins 2 brèches de 2")
	await _frames(int((pattern.telegraph + 0.3) * 60))
	check(crown.active() and crown.holds_boss(), "couronne levée : le boss se concentre")
	check_near(crown.damage_mult(), 1.0, 0.001, "de l'intérieur : coups pleins")
	run.hunter.global_position = foe.pos + Vector3(14, 0, 0)
	check_near(crown.damage_mult(), 0.15, 0.001, "de l'extérieur : coups absorbés à 85 %")
	run.hunter.global_position = foe.pos + Vector3(2, 0, 0)
	var shots: int = run.hostile.size()
	await _frames(int(float(pattern.params.get("duration", 9.0)) * 60) + 30)
	check(not crown.holds_boss(), "la couronne se termine")
	check(run.hostile.size() > shots, "les étoiles partent vers l'extérieur")


func test_mist_veil_lanterns() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"mist_chimera", 6.0)
	var veil := _mechanic(foe, &"mist_veil") as DraftMistVeil
	check(veil != null, "Chimère : voile de brume")
	foe.brain._next_at = INF
	veil.perform(_pattern(foe.boss, &"mist_veil"))
	check(veil.veiled() and veil.lanterns.size() == 3, "trois lanternes allumées")
	check(foe.brain.damage_mult() <= 0.06, "sous le voile : coups sans effet ou presque")
	for lantern: DraftEnemies.Foe in veil.lanterns.duplicate():
		run.enemies.hit(lantern, 100000.0)
	await _frames(2)
	check(not veil.veiled() and veil.broken == 1, "lanternes brisées : voile levé")
	check(foe.brain.stunned(), "la Chimère se fige")
	check(foe.brain.damage_mult() >= 2.0, "figée : coups × 2 au moins")


func test_quake_rings_grow_with_phases() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"root_sentinel", 6.0)
	var pattern: BossPatternData = _pattern(foe.boss, &"quake")
	var before: int = run.hazards._items.size()
	foe.brain._gesture_quake(pattern, Vector3.RIGHT)
	check_eq(run.hazards._items.size() - before, int(pattern.params.get("waves", 2)), "Séisme : anneaux des données")


func test_pyrevorn_craters_skyfall_and_escorts() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"pyrevorn", 8.0)
	var craters := _mechanic(foe, &"crater_sequence") as DraftCraterSequence
	check(craters != null, "Pyrevorn : séquence des cratères")
	foe.brain._next_at = INF
	var pattern: BossPatternData = _pattern(foe.boss, &"crater_sequence")
	craters.perform(pattern)
	check_eq(craters.cells.size(), 9, "grille de 3 × 3")
	check_eq(craters.steps.size(), int(pattern.params.get("steps", 4)), "cases de la séquence")
	await _frames(int((float(craters.steps.back()["erupt_at"]) - craters._clock) * 60) + 40)
	check_eq(craters.eruptions, int(pattern.params.get("steps", 4)), "chaque case allumée entre en éruption")
	check(not craters.active(), "la grille disparaît après la dernière éruption")
	var skyfall: BossPatternData = _pattern(foe.boss, &"skyfall")
	foe.brain._gesture_leap(skyfall, Vector3.RIGHT)
	await _frames(40)
	check(foe.brain.airborne() and foe.view.hop > 10.0, "envol : hors de l'écran")
	check(foe.brain.damage_mult() < 0.5, "en l'air : coups réduits")
	await _frames(int((float(skyfall.params.get("airborne", 1.6)) + skyfall.telegraph) * 60) + 40)
	check(not foe.brain.airborne() and foe.view.hop == 0.0, "chute : de retour au sol")
	check(foe.pos.distance_to(run.hunter.global_position) < 3.0, "il retombe là où se tenait le Chasseur")
	var count: int = run.enemies.count()
	_bring_to(foe, 0.4)
	check_eq(craters.escorts.size(), 2, "seconde phase : Titan de caldeira et Wyrmeau de flammes")
	check(run.enemies.count() >= count + 2, "escorte dans la partie")
