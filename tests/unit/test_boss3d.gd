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
	for i: int in foe.boss.phases.size():
		foe.brain._check_phase()


func test_every_data_technique_has_a_3d_gesture() -> void:
	for boss: BossData in GameDB.bosses.values():
		if DraftRoster.EXCLUDED_BOSSES.has(boss.id):
			# Nébulorax : supprimé de la v2, aucune de ses techniques n'y est jouée.
			check(not DraftBossBrain.GESTURES.has(&"absorb"), "Nébulorax : absorption absente de la v2")
			continue
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


func test_ash_guardians() -> void:
	await _start()
	# Gardien du bûcher : charge longue des données, assommé contre le décor.
	var pyre: DraftEnemies.Foe = _spawn(&"pyre_guardian", 6.0)
	var ram: BossPatternData = _pattern(pyre.boss, &"pyre_ram")
	pyre.brain._gesture_charge(ram, Vector3(0, 0, -1))
	check_near(float(pyre.brain._move["speed"]), float(ram.params["speed"]) * DraftHunter.UNIT, 0.01,
		"charge du bûcher : vitesse des données")
	run.enemies.hit(pyre, 1000000.0)
	# Chevalier calciné : cercle du duel.
	var knight: DraftEnemies.Foe = _spawn(&"cinder_champion", 4.0)
	var duel := _mechanic(knight, &"duel_circle") as DraftDuelCircle
	knight.brain._next_at = INF
	duel.perform(_pattern(knight.boss, &"duel_circle"))
	await _frames(90)
	check(duel.active(), "cercle du duel tracé")
	check_near(duel.damage_mult(), 1.5, 0.001, "dedans : coups × 1,5")
	run.hunter.god_mode = false
	run.hunter.global_position = duel.circle["center"] + Vector3(float(duel.circle["radius"]) + 3.0, 0, 0)
	await _frames(60)
	check(duel.burns >= 1, "dehors : le Chasseur brûle")
	run.hunter.god_mode = true
	run.enemies.hit(knight, 1000000.0)
	run.hunter.global_position = Vector3(0, 0.2, 0)
	run.hunter.reset_motion()
	await _frames(5)
	# Reine-veuve : fils tendus.
	var widow: DraftEnemies.Foe = _spawn(&"widow_queen", 8.0)
	var silk := _mechanic(widow, &"silk_threads") as DraftSilkThreads
	widow.brain._next_at = INF
	silk.perform(_pattern(widow.boss, &"silk_threads"))
	check(silk.threads.size() >= 4, "fils tendus autour du Chasseur")
	var thread: Dictionary = silk.threads[0]
	run.hunter.global_position = ((thread["a"] as Vector3) + (thread["b"] as Vector3)) * 0.5 + Vector3.UP * 0.1
	await _frames(3)
	check(silk.caught >= 1 and run.hunter.stuck_left > 0.0, "un fil touché colle sur place")
	await _frames(10)
	check(widow.brain.airborne(), "la Reine bondit sur sa proie")
	var count: int = silk.threads.size()
	run.hunter.dash_time = 0.2
	var other: Dictionary = silk.threads[silk.threads.size() - 1]
	run.hunter.global_position = ((other["a"] as Vector3) + (other["b"] as Vector3)) * 0.5 + Vector3.UP * 0.1
	await _frames(2)
	check(silk.threads.size() < count, "une Ruée tranche le fil")
	run.enemies.hit(widow, 1000000.0)
	# Matrone des scories : carapace fendue par une roche qui tombe sur elle.
	var matron: DraftEnemies.Foe = _spawn(&"slag_matriarch", 5.0)
	var shell := _mechanic(matron, &"slag_rain") as DraftSlagShell
	check_near(matron.brain.damage_mult(), 0.15, 0.001, "carapace : coups × 0,15")
	shell._rock_lands(matron.pos, 2.5)
	check(shell.cracked() and matron.brain.stunned(), "roche tombée sur elle : carapace fendue, sonnée")
	check(matron.brain.damage_mult() >= 1.5, "fendue : coups × 1,5")


func test_glauquemire_three_phases() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"glauquemire", 9.0)
	var glauque := _mechanic(foe, &"prism_beam") as DraftGlauquemire
	check(glauque != null, "Glauquemire : mécaniques du Dévoreur")
	foe.brain._next_at = INF
	# Phase 1 : vase qui durcit en mur solide.
	var mud: BossPatternData = _pattern(foe.boss, &"mud_wall")
	glauque.perform(mud)
	check_eq(glauque.puddles.size(), int(mud.params["count"]), "jets de vase")
	await _frames(int((mud.telegraph + float(mud.params["harden"])) * 60) + 10)
	check(glauque.puddles[0]["wall"] is StaticBody3D, "la vase durcit en mur solide")
	# Sangsues : rampent vers le boss et le soignent, plafonné.
	foe.hp = foe.max_hp * 0.8
	glauque.perform(_pattern(foe.boss, &"leech_feed"))
	check(glauque.leeches.size() >= 1 and glauque.leeches[0].follow == foe, "les sangsues rejoignent le boss")
	glauque.heal(foe.max_hp)
	check_near(glauque.healed, foe.max_hp * 0.06, 1.0, "soin plafonné à 6 % sur le combat")
	# Phase 2 : facettes et miroirs.
	_bring_to(foe, 0.6)
	check_eq(glauque.facets.size(), 4, "carapace à quatre facettes")
	check_eq(glauque.mirrors.size(), 4, "quatre miroirs")
	foe.brain._transition = 0.0
	check_near(foe.brain.damage_mult(), 0.3, 0.001, "face intacte : 30 % des coups")
	# Rayon de prisme renvoyé par un miroir tenu : boss étourdi.
	# Le boss reste en place pendant le rayon, comme quand il le lance lui-même.
	foe.brain._busy = 100.0
	# Miroir en vue directe du boss (le décor de la carte peut en cacher un).
	var mirror: Dictionary = glauque.mirrors[0]
	var space: PhysicsDirectSpaceState3D = run.get_world_3d().direct_space_state
	for candidate: Dictionary in glauque.mirrors:
		var origin: Vector3 = foe.pos + Vector3.UP * DraftGlauquemire.BEAM_HEIGHT
		var target: Vector3 = (candidate["pos"] as Vector3) + Vector3.UP * DraftGlauquemire.BEAM_HEIGHT
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, target, 1))
		if not hit.is_empty() and hit["collider"] == candidate["body"]:
			mirror = candidate
			break
	var outward: Vector3 = ((mirror["pos"] as Vector3) - foe.pos).normalized()
	run.hunter.global_position = run.level.closest((mirror["pos"] as Vector3) + outward.cross(Vector3.UP) * 1.8) \
		+ Vector3.UP * 0.2
	run.hunter.reset_motion()
	await _frames(3)
	var beam: BossPatternData = _pattern(foe.boss, &"prism_beam")
	glauque.perform(beam)
	var hp: float = foe.hp
	for frame: int in int((beam.telegraph + float(beam.params["sweep_time"])) * 60) + 30:
		await host.get_tree().physics_frame
		if glauque.reflections > 0:
			break
	check(glauque.reflections >= 1, "un miroir tenu renvoie le rayon")
	check(foe.hp < hp and foe.brain.stunned(), "rayon renvoyé : blessé et étourdi")
	# Phase 3 : facettes tombées, tourbillon qui aspire.
	_bring_to(foe, 0.3)
	check(glauque.facets.is_empty(), "phase 3 : carapace fendue")
	var far: Vector3 = run.hunter.global_position
	glauque.perform(_pattern(foe.boss, &"whirlpool"))
	await _frames(120)
	check(run.hunter.global_position.distance_to(foe.pos) < far.distance_to(foe.pos), "le tourbillon aspire")
	foe.brain.die()
	check(glauque.mirrors.is_empty() and glauque.puddles.is_empty(), "tout est retiré à la mort")


func test_marsh_guardians() -> void:
	await _start()
	# Gardien d'écorce : bouclier frontal.
	var bark: DraftEnemies.Foe = _spawn(&"bark_colossus", 5.0)
	var guard := _mechanic(bark, &"bark_guard") as DraftBarkGuard
	bark.brain._next_at = INF
	guard.perform(_pattern(bark.boss, &"bark_guard"))
	check(guard.guarding(), "garde levée")
	check_near(bark.brain.damage_mult(), 0.1, 0.001, "de face : × 0,1")
	run.hunter.global_position = bark.pos - (run.hunter.global_position - bark.pos)
	check_near(bark.brain.damage_mult(), 1.5, 0.001, "de dos : × 1,5")
	run.enemies.hit(bark, 1000000.0)
	run.hunter.global_position = Vector3(0, 0.2, 0)
	run.hunter.reset_motion()
	# Gueule des marais : plongée, sortie sonnée.
	var maw: DraftEnemies.Foe = _spawn(&"marsh_maw_guardian", 6.0)
	var dive := _mechanic(maw, &"maw_dive") as DraftMawDive
	maw.brain._next_at = INF
	var pattern: BossPatternData = _pattern(maw.boss, &"maw_dive")
	dive.perform(pattern)
	await _frames(int(pattern.telegraph * 60) + 5)
	check(dive.submerged() and maw.brain.airborne(), "sous la surface : intouchable, sans contact")
	await _frames(int((float(pattern.params["chase"]) + float(pattern.params["warning"])) * 60) + 10)
	check(dive.surfaced == 1 and maw.brain.stunned(), "elle ressurgit, sonnée")
	check(maw.brain.damage_mult() >= 1.99, "sortie : coups × 2")
	run.enemies.hit(maw, 1000000.0)
	# Mère des spores : cristal frappé d'une Ruée, voile brûlé.
	var spore: DraftEnemies.Foe = _spawn(&"spore_matriarch", 6.0)
	var veil := _mechanic(spore, &"spore_veil") as DraftSporeVeil
	spore.brain._next_at = INF
	check_eq(veil.crystals.size(), 3, "trois cristaux autour d'elle")
	check_near(spore.brain.damage_mult(), 0.2, 0.001, "voile : × 0,2")
	veil._fire(veil.crystals[0])
	var clear: bool = veil.burns == 1
	if not clear:
		veil._fire(veil.crystals[1])
	if veil.burns == 0:
		veil._fire(veil.crystals[2])
	check(veil.burns == 1 and spore.brain.stunned(), "rayon de cristal : voile brûlé, sonnée")
	run.enemies.hit(spore, 1000000.0)
	# Dame des portails : piégée dans le portail de sortie.
	var lady: DraftEnemies.Foe = _spawn(&"portal_lady", 6.0)
	var portal := _mechanic(lady, &"portal_hop") as DraftPortalHop
	lady.brain._next_at = INF
	check_eq(portal.portals.size(), 3, "trois portails")
	var hop: BossPatternData = _pattern(lady.boss, &"portal_hop")
	portal.perform(hop)
	run.hunter.global_position = portal.portals[int(portal.hop["exit"])]["pos"] + Vector3.UP * 0.2
	run.hunter.reset_motion()
	await _frames(int((hop.telegraph + float(hop.params["dive"])) * 60) + 10)
	check(portal.trapped == 1 and lady.brain.stunned(), "Chasseur dans le portail : elle sort piégée")


func test_nivorath_spell_capture() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"nivorath", 6.0)
	var capture := _mechanic(foe, &"spell_capture") as DraftSpellCapture
	check(capture != null, "Nivorath : écho des sorts")
	foe.brain._next_at = INF
	var pattern: BossPatternData = _pattern(foe.boss, &"spell_capture")
	capture.perform(pattern)
	await _frames(int((pattern.telegraph + float(pattern.params["duration"])) * 60) + 10)
	check(capture.choked == 1 and foe.brain.stunned(), "aucun sort lancé : il s'étouffe")
	await _frames(int(float(pattern.params["stun"]) * 60) + 70)
	capture.perform(pattern)
	await _frames(int(pattern.telegraph * 60) + 5)
	run.spells.casts += 2
	var shots: int = run.hostile.size()
	await _frames(int(float(pattern.params["duration"]) * 60) + 10)
	check(capture.released == 2, "sorts aspirés puis renvoyés")
	check(run.hostile.size() > shots, "couronnes de tirs")
	_bring_to(foe, 0.3)
	check_eq(foe.brain.phase, 2, "Nivorath : trois phases")


func test_frost_guardians() -> void:
	await _start()
	var yeti: DraftEnemies.Foe = _spawn(&"peak_patriarch", 7.0)
	var avalanche := _mechanic(yeti, &"avalanche") as DraftFrostGuardians
	yeti.brain._next_at = INF
	avalanche.perform(_pattern(yeti.boss, &"avalanche"))
	check(avalanche.balls.size() >= 3, "boules de neige en éventail")
	await _frames(400)
	check(avalanche.balls.is_empty(), "elles éclatent contre le décor ou s'épuisent")
	run.enemies.hit(yeti, 1000000.0)
	var shaman: DraftEnemies.Foe = _spawn(&"rime_elder", 7.0)
	var freeze := _mechanic(shaman, &"deep_freeze") as DraftFrostGuardians
	shaman.brain._next_at = INF
	run.hunter.god_mode = false
	var pattern: BossPatternData = _pattern(shaman.boss, &"deep_freeze")
	freeze.perform(pattern)
	await _frames(int(pattern.telegraph * 60) + 5)
	check(freeze.frozen == 1 and run.hunter.stuck_left > 0.0, "hors du refuge : gelé, prisonnier")
	run.hunter.god_mode = true
	run.hunter.stuck_left = 0.0
	run.enemies.hit(shaman, 1000000.0)
	var wolf: DraftEnemies.Foe = _spawn(&"blizzard_alpha", 7.0)
	var hunt := _mechanic(wolf, &"storm_hunt") as DraftFrostGuardians
	wolf.brain._next_at = INF
	var charges: int = int(_pattern(wolf.boss, &"storm_hunt").params["count"])
	hunt.perform(_pattern(wolf.boss, &"storm_hunt"))
	var seen: int = 0
	var charging: bool = false
	for frame: int in 900:
		await host.get_tree().physics_frame
		if wolf.brain.moves_itself() and not charging:
			seen += 1
		charging = wolf.brain.moves_itself()
		if hunt.hunt.is_empty():
			break
	check(seen >= charges, "charges successives (%d)" % seen)
	run.enemies.hit(wolf, 1000000.0)
	var colossus: DraftEnemies.Foe = _spawn(&"floe_colossus", 7.0)
	var quake := _mechanic(colossus, &"floe_quake") as DraftFrostGuardians
	colossus.brain._next_at = INF
	quake.perform(_pattern(colossus.boss, &"floe_quake"))
	check(quake.plates.size() >= 2, "plaques fendues sous le Chasseur")
	await _frames(int((1.0 + 1.6) * 60) + 10)
	check(run.hunter.slow_left > 0.0, "plaque ouverte : ralenti dans l'eau noire")


func test_abyssarch_echoes_of_worlds() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"abyssarch", 7.0)
	var echoes := _mechanic(foe, &"abyss_echoes") as DraftAbyssEchoes
	check(echoes != null, "Abyssarque : Échos des mondes")
	foe.brain._next_at = INF
	var pattern: BossPatternData = _pattern(foe.boss, &"abyss_echoes")
	echoes.perform(pattern)
	check_eq(echoes.world, 1, "premier monde rappelé")
	check(echoes.pending.size() >= 4, "apparitions annoncées")
	await _frames(int(pattern.telegraph * 60) + 5)
	check(echoes.summoned >= 3, "Corrompus du premier monde surgis (%d)" % echoes.summoned)
	echoes.perform(pattern)
	check_eq(echoes.world, 2, "mondes rappelés tour à tour")


func test_city_guardians() -> void:
	await _start()
	run.enemies.spawn(GameDB.enemy(&"fallen_militia"), run.hunter.global_position + Vector3(3, 0, 0))
	var commander: DraftEnemies.Foe = _spawn(&"fallen_commander", 5.0)
	await _frames(2)
	var cry := _mechanic(commander, &"war_cry") as DraftCityGuardians
	commander.brain._next_at = INF
	var count: int = run.enemies.count()
	cry.perform(_pattern(commander.boss, &"war_cry"))
	check(not cry.rallied.is_empty(), "Corrompus proches ralliés")
	check(run.enemies.count() >= count + 3, "miliciens appelés")
	await _frames(80)
	check(commander.brain.moves_itself() or commander.brain.stunned() or commander.brain.busy(), "il charge après le cri")
	run.enemies.hit(commander, 1000000.0)
	var golem: DraftEnemies.Foe = _spawn(&"sanctum_golem", 6.0)
	var runes := _mechanic(golem, &"rune_barrage") as DraftCityGuardians
	golem.brain._next_at = INF
	runes.perform(_pattern(golem.boss, &"rune_barrage"))
	check(runes.seals.size() >= 3, "sceaux autour du Chasseur")
	check_near(golem.brain.damage_mult(), DraftCityGuardians.SLAB_MULT, 0.001, "armure de dalles")
	await _frames(90)
	check(run.hunter.slow_left > 0.0, "un sceau ralentit")
	run.enemies.hit(golem, 1000000.0)
	var keeper: DraftEnemies.Foe = _spawn(&"pantheon_keeper", 6.0)
	var wake := _mechanic(keeper, &"pantheon_wake") as DraftCityGuardians
	keeper.brain._next_at = INF
	wake.perform(_pattern(keeper.boss, &"pantheon_wake"))
	check(wake.woken >= 2, "statues éveillées")
	run.enemies.hit(keeper, 1000000.0)
	var herald: DraftEnemies.Foe = _spawn(&"herald_lord", 4.0)
	await _frames(2)
	var chain := _mechanic(herald, &"soul_chain") as DraftCityGuardians
	herald.brain._next_at = INF
	chain.perform(_pattern(herald.boss, &"soul_chain"))
	check(not chain.linked.is_empty(), "Corrompus liés à l'Héraldiste")
	var linked: DraftEnemies.Foe = chain.linked[0]
	var hp: float = linked.hp
	run.enemies.hit(linked, 10.0)
	check(hp - linked.hp < 10.0 * 0.5 * CombatSystem.defense_multiplier(linked.defense) + 0.01, "lié : dégâts × 0,4")
	herald.brain.die()
	check(chain.linked.is_empty(), "liens rompus à sa mort")

func test_floor_change_clears_boss_mechanics() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"glauquemire", 8.0)
	var glauque := _mechanic(foe, &"prism_beam") as DraftGlauquemire
	foe.brain._next_at = INF
	glauque.perform(_pattern(foe.boss, &"mud_wall"))
	check(not glauque.puddles.is_empty(), "flaques de vase posées")
	run.enemies.clear_all()
	check(glauque.puddles.is_empty() and run.enemies.boss == null, "changement d'étage : boss et vase retirés")


func test_painted_effects_in_3d() -> void:
	await _start()
	var foe: DraftEnemies.Foe = _spawn(&"source_devourer", 6.0)
	foe.brain._next_at = INF
	var before: int = DraftPaintedFx.active(run)
	check(before >= 1, "rugissement d'entrée peint")
	check(foe.brain.painted(["claw"], foe.pos, Vector3.RIGHT, DraftBossBrain.CONTACT_STRIKE), "griffes peintes du Dévoreur")
	var painted: Array[Node] = run.get_tree().get_nodes_in_group(&"draft_painted_fx")
	check_eq(painted.size(), before + 1, "un effet peint de plus dans le monde 3D")
	var node := painted[painted.size() - 1] as DraftPaintedFx
	check(node.find_children("*", "SubViewport", true, false).size() == 1, "dessiné dans un rendu intermédiaire")
	check(not foe.brain.painted(["introuvable"], foe.pos), "scène absente : l'effet PixelFX reste")
	_bring_to(foe, 0.4)
	check(run.get_tree().get_nodes_in_group(&"draft_painted_fx").size() >= 2, "transition peinte")
	for i: int in 10:
		foe.brain.painted(["heavy_slam"], foe.pos)
	check(DraftPaintedFx.active(run) <= DraftPaintedFx.MAX_ACTIVE, "plafond d'effets peints")
	await _frames(150)
	check(DraftPaintedFx.active(run) == 0, "les effets se retirent seuls")
	var glauque: DraftEnemies.Foe = _spawn(&"glauquemire", 8.0)
	check(glauque.brain.painted(["mud_impact"], glauque.pos), "vase peinte de Glauquemire")
	var astravorn: DraftEnemies.Foe = _spawn(&"astravorn", 8.0)
	check(not astravorn.brain.painted(["claw"], astravorn.pos), "sans dossier peint : rien")


func test_boss_hp_follows_the_chapter_not_the_campaign() -> void:
	await _start()
	var previous: float = 0.0
	for order: int in range(1, 6):
		run.chapter = order
		var boss: BossData = DraftRoster.for_chapter(order).boss
		var effective: float = boss.max_hp * CombatSystem.defense_multiplier(boss.defense) * run.hp_scale(boss,
			run.tuning.boss_effective_hp)
		check_near(effective, run.tuning.boss_effective_hp * (1.0 + run.tuning.boss_chapter_growth * (order - 1)), 1.0,
			"chapitre %d : PV effectifs du Dévoreur" % order)
		check(effective > previous, "chapitre %d : un peu plus résistant que le précédent" % order)
		previous = effective
	run.chapter = 1
	check_near(run.hp_scale(GameDB.boss(&"source_devourer"), run.tuning.boss_effective_hp), 1.0, 0.01,
		"Dévoreur des Sources : référence inchangée")


func test_nebulorax_never_comes_back() -> void:
	for order: int in range(1, DraftRoster.chapters().size() + 1):
		var roster: DraftRoster = DraftRoster.for_chapter(order)
		for boss: BossData in roster.guardians + [roster.boss]:
			check(boss.id != &"nebulorax", "chapitre %d : Nébulorax absent" % order)
	check(DraftBossBrain.mechanics_for(GameDB.boss(&"nebulorax")).is_empty(), "aucune mécanique 3D pour Nébulorax")
