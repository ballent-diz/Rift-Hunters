extends TestCase
## Dévoreurs propres à la v2 (docs/design/BOSS_V2.md, section 9) : l'Ourdisseur et son Barrage de chaîne, Faïron et
## son Choc d'émail. Saumor et le socle commun sont dans test_boss3d.gd.

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


func _bring_to(foe: DraftEnemies.Foe, ratio: float) -> void:
	foe.hp = foe.max_hp * ratio
	for i: int in foe.boss.phases.size():
		foe.brain._check_phase()


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


func test_loom_devourer_warp_barrage() -> void:
	var tower: DraftRoster = DraftRoster.for_chapter(6)
	check_eq(tower.boss.id, &"loom_devourer", "Tour de la Faille : l'Ourdisseur en Dévoreur")
	check_eq(tower.enemies[0].id, &"biting_bobbin", "bestiaire des Rapiécés")
	check(not tower.guardians.has(GameDB.boss(&"pyrevorn")), "Pyrevorn n'est plus un doublon à la Tour")
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"loom_devourer", 8.0)
	check(foe.view.has_clip(&"warp_gate") and foe.view.has_clip(&"reverse_weave"), "Ourdisseur : feuille raccordée")
	foe.brain._next_at = INF
	await _frames(int(foe.brain._busy * 60) + 5)
	var loom := _mechanic(foe, &"warp_barrage") as DraftLoomDevourer
	check(loom != null, "Ourdisseur : Barrage de chaîne")
	check_eq(loom.next_kind(&"warp_barrage"), &"shuttle_reel", "barrage → navette")
	check(not loom.allows(&"warp_barrage", 25.0), "pas de barrage de l'autre bout de la carte")
	var pattern: BossPatternData = _pattern(foe.boss, &"warp_barrage")
	var lines: int = run.hazards._items.size()
	foe.brain._busy = loom.perform(pattern)
	check_eq(loom.threads.size(), 2, "deux fils")
	check_eq(loom.posts.size() + loom.decor_anchors, 2, "chaque fil s'accroche au décor ou à un montant posé")
	check_eq(run.hazards._items.size() - lines, int(pattern.params["steps"]) * 2, "pistes du balayage annoncées")
	check(loom.holds_boss(), "il tient les fils")
	# Métier tendu : les fils se referment vers le milieu.
	check(absf(float(loom.threads[0]["to"])) < absf(float(loom.threads[0]["from"])), "phase 1 : les fils se referment")
	await _frames(int((pattern.telegraph + 1.6) * 60))
	check(loom.threads.is_empty() and not loom.holds_boss(), "barrage terminé : fils retirés")
	# Navette : le Chasseur touché est ramené vers lui.
	run.hunter.global_position = run.level.closest(foe.pos + Vector3(7, 0, 0))
	var reel: BossPatternData = _pattern(foe.boss, &"shuttle_reel")
	# La navette tire le Chasseur quand elle le blesse : pas de mode dieu le temps du coup.
	run.hunter.god_mode = false
	run.hunter.invulnerable = 0.0
	run.hunter.hp = 1000.0
	var before: float = run.hunter.global_position.distance_to(foe.pos)
	loom.perform(reel)
	await _frames(int(reel.telegraph * 60) + 4)
	run.hunter.god_mode = true
	if bool(run.sight_clear(foe.pos + Vector3.UP * 0.8, run.hunter.chest())):
		check(run.hunter.global_position.distance_to(foe.pos) < before - 1.0, "navette : ramené vers l'Ourdisseur")
	_bring_to(foe, 0.4)
	foe.brain._transition = 0.0
	check_eq(foe.brain.phase, 1, "sous 50 % : trame inversée")
	var inverse: BossPatternData = foe.boss.phases[1].patterns[1]
	loom.perform(inverse)
	check(absf(float(loom.threads[0]["to"])) > absf(float(loom.threads[0]["from"])), "trame inversée : les fils s'ouvrent")
	run.enemies.hit(foe, 1000000.0)
	check(loom.threads.is_empty() and loom.posts.is_empty(), "mort : fils et montants retirés")


func test_fairon_enamel_shock() -> void:
	var cliffs: DraftRoster = DraftRoster.for_chapter(9)
	check_eq(cliffs.boss.id, &"fairon", "Corniches : Faïron en Dévoreur")
	check_eq(cliffs.enemies[0].id, &"hopping_shard", "bestiaire des Vernissés")
	check(cliffs.guardians.has(GameDB.boss(&"herald_lord")), "le Grand Héraldiste redevient un gardien")
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"fairon", 8.0)
	check(foe.view.has_clip(&"enamel_shock") and foe.view.has_clip(&"phase2_idle"), "Faïron : feuille raccordée")
	foe.brain._next_at = INF
	await _frames(int(foe.brain._busy * 60) + 5)
	var kiln := _mechanic(foe, &"enamel_shock") as DraftFairon
	check(kiln != null, "Faïron : Choc d'émail")
	check_eq(foe.brain.combat_family(), &"reflets", "coque de porcelaine : matière d'émail")
	check_eq(kiln.next_kind(&"enamel_line"), &"enamel_shock", "pose d'émail → choc")
	var pattern: BossPatternData = _pattern(foe.boss, &"enamel_shock")
	foe.brain._busy = kiln.perform(pattern)
	check_eq(kiln.bands.size(), int(pattern.params["count"]), "bandes glacées")
	check(kiln.holds_boss(), "concentré pendant le marquage")
	# Marquées une à une, fendues dans le même ordre.
	var order_ok: bool = true
	for i: int in range(1, kiln.bands.size()):
		order_ok = order_ok and float(kiln.bands[i]["mark_at"]) > float(kiln.bands[i - 1]["mark_at"]) \
			and float(kiln.bands[i]["crack_at"]) > float(kiln.bands[i - 1]["crack_at"])
	check(order_ok, "ordre de marquage = ordre des fissures")
	await _frames(int((float(kiln.bands[0]["crack_at"]) - kiln._clock) * 60) + 3)
	check(bool(kiln.bands[0]["done"]) and not bool(kiln.bands[1]["done"]), "la première bande se fend, la suivante tient encore")
	await _frames(int((float(kiln.bands.back()["crack_at"]) - kiln._clock) * 60) + 5)
	check(kiln.cracked == int(pattern.params["count"]), "toutes les bandes fendues (%d)" % kiln.cracked)
	# Pose d'émail : traînée qui ralentit.
	var zones: int = run.hazards.zones()
	var line: BossPatternData = _pattern(foe.boss, &"enamel_line")
	kiln.perform(line)
	await _frames(int(line.telegraph * 60) + 30)
	check(run.hazards.zones() >= zones + 2, "traînée d'émail au sol")
	_bring_to(foe, 0.4)
	foe.brain._transition = 0.0
	check_eq(foe.brain.phase, 1, "sous 50 % : four ouvert")
	check_eq(foe.brain.combat_family(), &"calcines", "four ouvert : matière du four")
	check_eq(kiln.next_kind(&"enamel_shock"), &"kiln_spit", "four ouvert : choc → projection du four")
	kiln.perform(foe.boss.phases[1].patterns[1])
	check_eq(kiln.bands.size(), int(pattern.params["count"]) + 1, "four ouvert : une bande de plus")
	run.enemies.hit(foe, 1000000.0)
	check(kiln.bands.is_empty() and not kiln.holds_boss(), "mort : choc interrompu")
