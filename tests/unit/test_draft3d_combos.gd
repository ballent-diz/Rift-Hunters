extends TestCase
## Combos MVP de la v2 (docs/design/GAMEPLAY_V2_ARCHITECTURE.md, lot 4) : déclenchés par de vrais lancers dans une
## partie, jamais avec un ingrédient en réserve, jamais hors de leur fenêtre.

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


func _start(extra: Array[StringName]) -> void:
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
	for id: StringName in extra:
		run.spells.learn(id)


func _frames(count: int) -> void:
	for frame: int in count:
		await host.get_tree().physics_frame


## Ennemi immobile et robuste à `offset` du Chasseur.
func _foe(offset: Vector3) -> DraftEnemies.Foe:
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + offset)
	foe.speed = 0.0
	foe.defense = 0.0
	foe.max_hp = 100000.0
	foe.hp = foe.max_hp
	return foe


func _cast(id: StringName, aim: Vector3) -> bool:
	var slot: int = run.spells.slot_of(id)
	if slot < 0:
		return false
	run.spells.cooldowns[slot] = 0.0
	return run.spells.cast(slot, aim)


func _count(combo: StringName) -> int:
	return int(run.combos.counts.get(combo, 0))


func test_prismatic_execution() -> void:
	await _start([&"rupture"] as Array[StringName])
	var combos: DraftCombos = run.combos
	var foe: DraftEnemies.Foe = _foe(Vector3(4, 0, 0))
	await _frames(2)
	check(_cast(&"rupture", foe.pos), "Rupture seule")
	check_eq(_count(DraftCombos.EXECUTION), 0, "sans Lance : pas de combo")
	check(_cast(&"prismatic_lance", foe.pos), "Lance")
	for frame: int in 60:
		if combos.lance_hits.has(foe):
			break
		await host.get_tree().physics_frame
	check(combos.lance_hits.has(foe), "la Lance a touché l'ennemi")
	var hp: float = foe.hp
	check(_cast(&"rupture", foe.pos), "Rupture dans la fenêtre")
	check_eq(_count(DraftCombos.EXECUTION), 1, "Exécution prismatique déclenchée")
	check(foe.max_hp - foe.hp > 0.0 and hp > foe.hp, "détonation secondaire")
	check(not combos.lance_hits.has(foe), "cible consommée")
	_cast(&"rupture", foe.pos)
	check_eq(_count(DraftCombos.EXECUTION), 1, "une Rupture de plus sans nouvelle Lance : rien")
	combos.on_lance_hit(foe)
	combos.step(run.tuning.combo_window + 0.1)
	_cast(&"rupture", foe.pos)
	check_eq(_count(DraftCombos.EXECUTION), 1, "hors fenêtre : rien")
	combos.on_lance_hit(foe)
	run.spells.stash(run.spells.slot_of(&"prismatic_lance"))
	_cast(&"rupture", foe.pos)
	check_eq(_count(DraftCombos.EXECUTION), 1, "Lance en réserve : rien")
	run.spells.equip(&"prismatic_lance", 1)
	var weak: DraftEnemies.Foe = _foe(Vector3(-3, 0, 0))
	weak.hp = weak.max_hp * 0.15
	combos.on_lance_hit(weak)
	check_eq(combos.on_rupture([weak] as Array[DraftEnemies.Foe], 10.0), 1, "cible affaiblie")
	check(not weak.alive, "achevée sous le seuil")


func test_prismatic_deluge() -> void:
	await _start([&"refracting_crystal"] as Array[StringName])
	var here: Vector3 = run.hunter.global_position
	check(_cast(&"refracting_crystal", here + Vector3(4, 0, 0)), "Cristal posé")
	check(not run.spells.world.crystals.is_empty(), "cristal dans le monde")
	await _frames(2)
	check(_cast(&"prismatic_lance", here + Vector3(12, 0, 0)), "Lance à travers le cristal")
	await _frames(30)
	check_eq(_count(DraftCombos.DELUGE), 1, "Déluge prismatique déclenché")
	check_eq(int(run.spells.world.crystals[0].get("deluge_left", -1)),
		run.tuning.combo_deluge_cap - run.tuning.combo_deluge_split, "gerbe décomptée du plafond du cristal")
	run.spells.stash(run.spells.slot_of(&"refracting_crystal"))
	_cast(&"prismatic_lance", here + Vector3(12, 0, 0))
	await _frames(30)
	check_eq(_count(DraftCombos.DELUGE), 1, "Cristal en réserve : réfraction ordinaire")
	var plain: Dictionary = run.combos.refraction({"lance": true}, {"at": here})
	check_eq(int(plain["split"]), run.tuning.crystal_split, "réglages ordinaires")
	run.spells.equip(&"refracting_crystal", 2)
	var crystal := {"at": here, "deluge_left": 1}
	check_eq(int(run.combos.refraction({"lance": true}, crystal)["split"]), 1, "plafond par cristal")
	check_eq(int(run.combos.refraction({"lance": true}, crystal)["split"]), run.tuning.crystal_split,
		"plafond atteint : réfraction ordinaire")
	check_eq(int(run.combos.refraction({}, {"at": here})["split"]), run.tuning.crystal_split,
		"un trait ordinaire ne déclenche pas le Déluge")


func test_gravity_blade() -> void:
	await _start([&"singularity"] as Array[StringName])
	var here: Vector3 = run.hunter.global_position
	var foe: DraftEnemies.Foe = _foe(Vector3(2.5, 0, 0))
	await _frames(2)
	check(_cast(&"cleaving_slash", here + Vector3(4, 0, 0)), "Taille sans puits")
	check_eq(_count(DraftCombos.GRAVITY_BLADE), 0, "sans puits : rien")
	check(_cast(&"singularity", foe.pos), "Singularité")
	check(not run.spells.world.wells.is_empty(), "puits actif")
	await _frames(2)
	check(_cast(&"cleaving_slash", here + Vector3(4, 0, 0)), "Taille dans le puits")
	check_eq(_count(DraftCombos.GRAVITY_BLADE), 1, "Lame gravitationnelle déclenchée")
	check(foe.exposed_left > 0.0, "ennemis du puits exposés")
	_cast(&"cleaving_slash", here + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.GRAVITY_BLADE), 1, "une onde par puits")
	_cast(&"singularity", foe.pos)
	_cast(&"cleaving_slash", here + Vector3(-4, 0, 0))
	check_eq(_count(DraftCombos.GRAVITY_BLADE), 1, "puits hors de l'arc : rien")
	run.spells.stash(run.spells.slot_of(&"singularity"))
	_cast(&"cleaving_slash", here + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.GRAVITY_BLADE), 1, "Singularité en réserve : rien")


func test_dedicated_effects_fall_back_until_delivered() -> void:
	await _start([] as Array[StringName])
	check(DraftPixelFx.has_sheet(&"ring_burst"), "effet existant reconnu")
	var width: float = DraftPixelFx.size_for(&"ring_burst", 2.0) * DraftPixelFx.PIXEL \
		* (DraftPixelFx.sheet(&"ring_burst", DraftPixelFx.DEFAULT_FAMILY)["rects"] as Array[Rect2])[0].size.x
	check_near(width, 2.0, 0.001, "effet livré mis à la largeur de la fiche")
	for id: StringName in [&"combo_prismatic_execution", &"combo_prismatic_deluge", &"combo_gravity_blade"]:
		if not DraftPixelFx.has_sheet(id):
			var node: Sprite3D = run.fx_or(id, 2.0, &"ring_burst", &"reflets", run.hunter.global_position)
			check(node is DraftPixelFx, "repli sur l'effet existant : %s" % id)
