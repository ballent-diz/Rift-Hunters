extends TestCase
## Familles propres à la v2 (draft3d/foe_techniques.gd, docs/design/BOSS_V2.md) : techniques des normaux à technique et
## des élites jouées en 3D, annoncées au sol, volants qui survolent le décor.

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
	run.tuning.waves.assign([{"at": 0.0, "rate": 0.0, "cap": 40, "mix": {"skitterling": 1.0}}])
	run.tuning.guardian_time = INF
	run.tuning.swarm_every = INF
	run._swarm_at = INF
	run.hunter.god_mode = true


func _frames(count: int) -> void:
	for frame: int in count:
		await host.get_tree().physics_frame


func _spawn(id: StringName, offset := Vector3(3, 0, 0)) -> DraftEnemies.Foe:
	return run.enemies.spawn(GameDB.enemy(id), run.level.closest(run.hunter.global_position + offset))


func _technique(foe: DraftEnemies.Foe, kind: StringName) -> EnemyTechniqueData:
	for technique: EnemyTechniqueData in foe.data.techniques:
		if technique.kind == kind:
			return technique
	return null


func _aim(foe: DraftEnemies.Foe) -> Vector3:
	var aim: Vector3 = run.hunter.global_position - foe.pos
	aim.y = 0.0
	return aim.normalized()


## Chaque technique des familles v2 a un style 3D et le clip de la feuille du même nom.
func _check_family(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		var data: EnemyData = GameDB.enemy(id)
		check(data != null and DraftRoster.usable(data), "%s : jouable en 3D" % id)
		if data == null:
			continue
		for technique: EnemyTechniqueData in data.techniques:
			check(DraftFoeTechniques.style_of(technique.kind) != &"", "%s : %s a un style 3D" % [id, technique.kind])
			check((Assets.entry(data.visual.visual_id).get("animations", {}) as Dictionary).has(technique.anim),
				"%s : clip %s" % [id, technique.anim])


func test_saumatres_techniques() -> void:
	_check_family([&"salt_scuttler", &"rope_drowned", &"brine_skate", &"salt_siphon", &"floodgate_keeper",
		&"brine_choir", &"salt_dredger"])
	await _start()
	var techniques: DraftFoeTechniques = run.enemies.techniques
	# Jet de saumure : ligne annoncée.
	var siphon: DraftEnemies.Foe = _spawn(&"salt_siphon")
	var items: int = run.hazards._items.size()
	var busy: float = techniques.perform(siphon, _technique(siphon, &"brine_jet"), _aim(siphon))
	check(busy > 0.5 and run.hazards._items.size() == items + 1, "jet de saumure annoncé en ligne")
	# Garde de l'écluse : de face seulement, puis le maillet est prêt.
	var keeper: DraftEnemies.Foe = _spawn(&"floodgate_keeper", Vector3(-3, 0, 0))
	techniques.perform(keeper, _technique(keeper, &"lock_guard"), _aim(keeper))
	check(keeper.guard_left > 0.0 and keeper.acting > 2.0, "garde enracinée")
	check_near(run.enemies.guard_factor(keeper), 0.15, 0.001, "de face : coups arrêtés par la vanne")
	keeper.guard_dir = -keeper.guard_dir
	check_near(run.enemies.guard_factor(keeper), 1.0, 0.001, "de dos : coups pleins")
	check(float(keeper.tech_ready[&"mallet_slam"]) <= keeper.tech_clock + keeper.acting + 0.01, "maillet après la garde")
	items = run.hazards._items.size()
	techniques.perform(keeper, _technique(keeper, &"mallet_slam"), _aim(keeper))
	check_eq(run.hazards._items.size(), items + 1, "maillet annoncé au sol")
	# Chantre : cloches et bénédiction.
	var choir: DraftEnemies.Foe = _spawn(&"brine_choir", Vector3(0, 0, 3))
	var count: int = run.enemies.count()
	techniques.perform(choir, _technique(choir, &"bell_call"), _aim(choir))
	check_eq(run.enemies.count(), count + 3, "les cloches appellent trois Griffe-sel")
	await _frames(2)
	techniques.perform(choir, _technique(choir, &"brine_blessing"), _aim(choir))
	check(keeper.boost_left > 0.0 and keeper.boost_mult > 1.0, "bénédiction : alliés proches galvanisés")
	# Dragueur : charge annoncée, puis course ; croûte qui éclate.
	var dredger: DraftEnemies.Foe = _spawn(&"salt_dredger", Vector3(0, 0, -6))
	techniques.perform(dredger, _technique(dredger, &"scoop_charge"), _aim(dredger))
	check(not dredger.dash.is_empty(), "charge au godet lancée")
	var start: Vector3 = dredger.pos
	await _frames(150)
	check(dredger.dash.is_empty(), "la charge s'achève")
	check(dredger.pos.distance_to(start) > 1.0, "le Dragueur a foncé")
	items = run.hazards._items.size()
	techniques.perform(dredger, _technique(dredger, &"salt_crust_burst"), _aim(dredger))
	check_eq(run.hazards._items.size(), items + 1, "croûte de sel qui éclate autour de lui")
	check(techniques.played.size() >= 7, "les sept techniques jouées (%s)" % [techniques.played.keys()])


func test_flying_foes_hover_and_cross_the_scenery() -> void:
	await _start()
	var skate: DraftEnemies.Foe = _spawn(&"brine_skate", Vector3(10, 0, 0))
	check(skate.data.flying, "Raie des saumures : volante")
	await _frames(30)
	check(skate.view.hop > 0.4, "elle vole au-dessus du sol")
	check(skate.path.is_empty(), "sans chemin de navigation : elle survole le décor")
	var before: float = skate.pos.distance_to(run.hunter.global_position)
	await _frames(60)
	check(skate.pos.distance_to(run.hunter.global_position) < before, "elle approche du Chasseur")


func test_skilled_foes_use_their_techniques_alone() -> void:
	await _start()
	var siphon: DraftEnemies.Foe = _spawn(&"salt_siphon", Vector3(4, 0, 0))
	check(siphon.skilled, "Siphon de sel : technique propre")
	await _frames(360)
	check(int(run.enemies.techniques.played.get(&"brine_jet", 0)) >= 1, "il lance son jet seul")
	var militia: DraftEnemies.Foe = _spawn(&"slag_matron", Vector3(-4, 0, 0))
	check(not militia.skilled, "monstres de la campagne inchangés (techniques v1 non jouées en 3D)")


func test_rapieces_techniques() -> void:
	_check_family([&"biting_bobbin", &"patch_mender", &"veil_moth", &"split_puppet", &"war_shuttle",
		&"shroud_spinner", &"tapestry_ram"])
	check(GameDB.enemy(&"veil_moth").flying, "Mite du voile : volante")
	await _start()
	var techniques: DraftFoeTechniques = run.enemies.techniques
	# Coup de pied à ressort : le Chasseur touché est repoussé.
	var puppet: DraftEnemies.Foe = _spawn(&"split_puppet", Vector3(1.6, 0, 0))
	run.hunter.god_mode = false
	run.hunter.hp = 1000.0
	var before: float = run.hunter.global_position.distance_to(puppet.pos)
	techniques.perform(puppet, _technique(puppet, &"spring_kick"), _aim(puppet))
	await _frames(int(_technique(puppet, &"spring_kick").telegraph * 60) + 4)
	check(run.hunter.global_position.distance_to(puppet.pos) > before + 1.0, "coup de pied : repoussé")
	run.enemies.vanish(puppet)
	# Fil de la Fileuse : tiré vers elle.
	var spinner: DraftEnemies.Foe = _spawn(&"shroud_spinner", Vector3(-8, 0, 0))
	before = run.hunter.global_position.distance_to(spinner.pos)
	techniques.perform(spinner, _technique(spinner, &"thread_gather"), _aim(spinner))
	await _frames(int(_technique(spinner, &"thread_gather").telegraph * 60) + 4)
	if bool(run.sight_clear(spinner.pos + Vector3.UP * 0.8, run.hunter.chest())):
		check(run.hunter.global_position.distance_to(spinner.pos) < before - 1.0, "fil : tiré vers la Fileuse")
	run.hunter.god_mode = true
	# Linceul : seulement blessée, garde et soin.
	spinner.hp = spinner.max_hp * 0.5
	techniques.perform(spinner, _technique(spinner, &"shroud"), _aim(spinner))
	check(spinner.hp > spinner.max_hp * 0.55 and spinner.guard_left > 0.0, "linceul : repli et soin")
	check_near(run.enemies.guard_factor(spinner), 0.3, 0.001, "linceul : coups réduits de tous côtés")
	# Navette : garde frontale puis frappe verticale en ligne.
	var shuttle: DraftEnemies.Foe = _spawn(&"war_shuttle", Vector3(0, 0, 4))
	techniques.perform(shuttle, _technique(shuttle, &"braced_shuttle"), _aim(shuttle))
	check(shuttle.guard_dir != Vector3.ZERO, "navette : garde frontale")
	var items: int = run.hazards._items.size()
	techniques.perform(shuttle, _technique(shuttle, &"loom_strike"), _aim(shuttle))
	check_eq(run.hazards._items.size(), items + 1, "frappe verticale annoncée")
	var ram: DraftEnemies.Foe = _spawn(&"tapestry_ram", Vector3(0, 0, -6))
	techniques.perform(ram, _technique(ram, &"bow_and_ram"), _aim(ram))
	check(not ram.dash.is_empty(), "bélier : charge tête basse")
	techniques.perform(ram, _technique(ram, &"fringe_bristle"), _aim(ram))
	check(techniques.played.size() >= 7, "les sept techniques jouées (%s)" % [techniques.played.keys()])
