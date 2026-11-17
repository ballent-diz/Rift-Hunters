extends TestCase
## Combos du lot 6 (draft3d/combos.gd) : déclenchés par de vrais lancers, jamais avec un ingrédient en réserve,
## jamais hors de leur fenêtre, sans réaction récursive ni multiplication de projectiles.

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


func _settle() -> void:
	for frame: int in 90:
		if not run.hunter.is_leaping():
			break
		await host.get_tree().physics_frame
	await _frames(2)


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


func _mutate(path: String) -> void:
	var effect: DraftSpellEffect = (load(path) as UpgradeData).effects[0] as DraftSpellEffect
	check(run.spells.add_mutation(effect), "mutation %s" % path.get_file())


func test_every_combo_is_named_and_needs_equipped_spells() -> void:
	await _start([] as Array[StringName])
	check_eq(DraftCombos.RECIPES.size(), 12, "douze combos")
	for combo: StringName in DraftCombos.RECIPES:
		var key: String = DraftCombos.NAME_KEYS[combo]
		check(tr(key) != key and tr(key.replace("_NAME", "_DESC")) != key.replace("_NAME", "_DESC"), "texte de %s" % combo)
		for id: StringName in DraftCombos.RECIPES[combo]:
			check(DraftSpells.supported(id), "%s : sort %s raccordé" % [combo, id])


# --- Marque et Rupture ----------------------------------------------------------------------------------------------

func test_dimensional_hunt() -> void:
	await _start([&"hunter_mark", &"void_rend"] as Array[StringName])
	var here: Vector3 = run.hunter.global_position
	var foe: DraftEnemies.Foe = _foe(Vector3(3, 0, 0))
	await _frames(2)
	check(_cast(&"void_rend", here + Vector3(6, 0, 0)), "Fente sans marque")
	await _settle()
	check_eq(_count(DraftCombos.HUNT), 0, "sans marque : rien")
	check(_cast(&"hunter_mark", foe.pos), "Marque")
	check(run.spells.rift.marked == foe, "ennemi marqué")
	var hp: float = foe.hp
	check(_cast(&"void_rend", foe.pos - (run.hunter.global_position - foe.pos)), "Fente à travers la cible")
	await _settle()
	check_eq(_count(DraftCombos.HUNT), 1, "Chasse dimensionnelle déclenchée")
	check(hp > foe.hp, "frappe secondaire")
	run.spells.stash(run.spells.slot_of(&"hunter_mark"))
	run.combos.on_rend([foe] as Array[DraftEnemies.Foe], 10.0, Vector3.RIGHT, 4.0, 0.5, false)
	check_eq(_count(DraftCombos.HUNT), 1, "Marque en réserve : rien")


func test_tracker_rupture() -> void:
	await _start([&"hunter_mark", &"rupture"] as Array[StringName])
	var foe: DraftEnemies.Foe = _foe(Vector3(4, 0, 0))
	await _frames(2)
	var hp: float = foe.hp
	_cast(&"rupture", foe.pos)
	var plain: float = hp - foe.hp
	check_eq(_count(DraftCombos.TRACKER), 0, "cible non marquée : rien")
	check(_cast(&"hunter_mark", foe.pos), "Marque")
	hp = foe.hp
	_cast(&"rupture", foe.pos)
	check_eq(_count(DraftCombos.TRACKER), 1, "Rupture du traqueur déclenchée")
	var exposure: float = 1.0 + foe.exposed
	check(hp - foe.hp > plain * exposure * 1.5, "explosion concentrée en plus")
	run.spells.stash(run.spells.slot_of(&"hunter_mark"))
	run.combos.on_rupture([foe] as Array[DraftEnemies.Foe], 10.0)
	check_eq(_count(DraftCombos.TRACKER), 1, "Marque en réserve : rien")


func test_prismatic_convergence_chain_is_bounded() -> void:
	await _start([&"refracting_crystal", &"rupture"] as Array[StringName])
	var here: Vector3 = run.hunter.global_position
	check(_cast(&"refracting_crystal", here + Vector3(4, 0, 0)), "Cristal")
	var foe: DraftEnemies.Foe = _foe(Vector3(8, 0, 0))
	await _frames(2)
	check(_cast(&"prismatic_lance", here + Vector3(12, 0, 0)), "Lance à travers le cristal")
	for frame: int in 60:
		if run.combos.prism_hits.has(foe):
			break
		await host.get_tree().physics_frame
	check(run.combos.prism_hits.has(foe), "cible de la Lance réfractée")
	_cast(&"rupture", foe.pos)
	check_eq(_count(DraftCombos.CONVERGENCE), 1, "Convergence prismatique déclenchée")
	check(not run.combos.prism_hits.has(foe), "cible consommée")
	# Chaîne : une file d'ennemis à 3 m les uns des autres, hors de la Rupture ; jamais plus de sauts que réglé.
	var line: Array[DraftEnemies.Foe] = []
	for i: int in 8:
		line.append(_foe(Vector3(-3.0 * (i + 1), 0, 6)))
	await _frames(2)
	run.combos.on_prism_hit(line[0])
	var bolts: int = run.bolts.size()
	run.combos.on_rupture([line[0]] as Array[DraftEnemies.Foe], 10.0)
	var touched: int = 0
	for other: DraftEnemies.Foe in line:
		touched += 1 if other.hp < other.max_hp else 0
	check_eq(touched, run.tuning.combo_convergence_jumps + 1, "arc limité aux sauts réglés")
	check_eq(run.bolts.size(), bolts, "aucun projectile ajouté")
	run.combos.on_prism_hit(line[0])
	run.combos.step(run.tuning.combo_window + 0.1)
	run.combos.on_rupture([line[0]] as Array[DraftEnemies.Foe], 10.0)
	check_eq(_count(DraftCombos.CONVERGENCE), 2, "hors fenêtre : rien")
	run.combos.on_prism_hit(line[0])
	run.spells.stash(run.spells.slot_of(&"refracting_crystal"))
	run.combos.on_rupture([line[0]] as Array[DraftEnemies.Foe], 10.0)
	check_eq(_count(DraftCombos.CONVERGENCE), 2, "Cristal en réserve : rien")


func test_rupture_combos_trigger_once_per_cast_with_reaction() -> void:
	await _start([&"hunter_mark", &"rupture"] as Array[StringName])
	_mutate("res://draft3d/spells/rupture_reaction.tres")
	var foe: DraftEnemies.Foe = _foe(Vector3(4, 0, 0))
	_foe(Vector3(6, 0, 1))
	_foe(Vector3(7, 0, -1))
	await _frames(2)
	_cast(&"hunter_mark", foe.pos)
	_cast(&"rupture", foe.pos)
	check_eq(_count(DraftCombos.TRACKER), 1, "Réaction (mutation) : une seule explosion concentrée par Rupture")


# --- Fenêtres -------------------------------------------------------------------------------------------------------

func test_rift_counter() -> void:
	await _start([&"parry"] as Array[StringName])
	var here: Vector3 = run.hunter.global_position
	var behind: DraftEnemies.Foe = _foe(Vector3(-2, 0, 0))
	await _frames(2)
	_cast(&"cleaving_slash", here + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.COUNTER), 0, "sans Parade : rien")
	check(behind.hp == behind.max_hp, "arc simple : l'ennemi derrière est épargné")
	_cast(&"parry", here)
	run.hunter.parried.emit()
	check(run.combos.counter_left > 0.0, "fenêtre ouverte par la Parade réussie")
	_cast(&"cleaving_slash", here + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.COUNTER), 1, "Contre-faille déclenchée")
	check(behind.hp < behind.max_hp, "contre-attaque élargie tout autour")
	_cast(&"cleaving_slash", here + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.COUNTER), 1, "une contre-attaque par Parade")
	run.combos.on_parried()
	run.combos.step(run.tuning.combo_window + 0.1)
	_cast(&"cleaving_slash", here + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.COUNTER), 1, "hors fenêtre : rien")
	run.combos.on_parried()
	run.spells.stash(run.spells.slot_of(&"parry"))
	_cast(&"cleaving_slash", here + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.COUNTER), 1, "Parade en réserve : rien")


func test_spectral_rebound() -> void:
	await _start([&"rift_step", &"void_rend"] as Array[StringName])
	var start: Vector3 = run.hunter.global_position
	var foe: DraftEnemies.Foe = _foe(Vector3(2, 0, 0))
	await _frames(2)
	check(_cast(&"rift_step", start + Vector3(0, 0, 5)), "Pas de faille")
	await _frames(2)
	var hp: float = foe.hp
	check(_cast(&"void_rend", run.hunter.global_position + Vector3(4, 0, 0)), "Fente dans la fenêtre")
	check_eq(_count(DraftCombos.SPECTRAL), 1, "Rebond spectral déclenché")
	check(hp > foe.hp, "la copie part de l'ombre et frappe")
	await _settle()
	_cast(&"void_rend", run.hunter.global_position + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.SPECTRAL), 1, "une copie par Pas")
	await _settle()
	run.combos.on_blink(start)
	run.combos.step(run.tuning.combo_window + 0.1)
	_cast(&"void_rend", run.hunter.global_position + Vector3(-4, 0, 0))
	check_eq(_count(DraftCombos.SPECTRAL), 1, "hors fenêtre : rien")
	await _settle()
	run.combos.on_blink(start)
	run.spells.stash(run.spells.slot_of(&"rift_step"))
	_cast(&"void_rend", run.hunter.global_position + Vector3(4, 0, 0))
	check_eq(_count(DraftCombos.SPECTRAL), 1, "Pas en réserve : rien")


func test_spectral_rebound_with_double_rend() -> void:
	await _start([&"rift_step", &"void_rend"] as Array[StringName])
	_mutate("res://draft3d/spells/rend_double.tres")
	var start: Vector3 = run.hunter.global_position
	await _frames(2)
	_cast(&"rift_step", start + Vector3(0, 0, 5))
	await _frames(2)
	var slot: int = run.spells.slot_of(&"void_rend")
	run.spells.cooldowns[slot] = 0.0
	check(run.spells.cast(slot, run.hunter.global_position + Vector3(4, 0, 0)), "première fente")
	await _settle()
	check(run.spells.cast(slot, run.hunter.global_position + Vector3(4, 0, 0)), "seconde fente gratuite (Double fente)")
	check_eq(_count(DraftCombos.SPECTRAL), 1, "Double fente : une seule copie")
	check(run.spells.cooldowns[slot] > 0.0, "recharge de la Fente préservée")


func test_vengeful_aegis() -> void:
	await _start([&"parry", &"aegis"] as Array[StringName])
	var here: Vector3 = run.hunter.global_position
	var foe: DraftEnemies.Foe = _foe(Vector3(1.5, 0, 0))
	await _frames(2)
	_cast(&"aegis", here)
	check(run.hunter.shield > 0.0, "bouclier levé")
	run.hunter.shield_broken.emit()
	check(foe.hp == foe.max_hp, "sans Riposte ni combo : le bouclier cède sans onde")
	_cast(&"aegis", here)
	_cast(&"parry", here)
	run.hunter.parried.emit()
	check(run.combos.aegis_empowered, "Parade réussie sous l'Égide")
	run.hunter.shield_broken.emit()
	check_eq(_count(DraftCombos.AEGIS), 1, "Égide vengeresse déclenchée")
	var plain_wave: float = foe.max_hp - foe.hp
	check(plain_wave > 0.0, "onde même sans Riposte")
	_mutate("res://draft3d/spells/aegis_riposte.tres")
	_cast(&"aegis", here)
	var hp: float = foe.hp
	run.hunter.shield_broken.emit()
	var riposte: float = hp - foe.hp
	_cast(&"aegis", here)
	_cast(&"parry", here)
	run.hunter.parried.emit()
	hp = foe.hp
	run.hunter.shield_broken.emit()
	check_near((hp - foe.hp) / riposte, 1.0 + run.tuning.combo_aegis_bonus, 0.01, "Riposte (mutation) renforcée")
	_cast(&"aegis", here)
	_cast(&"parry", here)
	run.hunter.parried.emit()
	run.spells.stash(run.spells.slot_of(&"parry"))
	hp = foe.hp
	run.hunter.shield_broken.emit()
	check_near(hp - foe.hp, riposte, 0.01, "Parade en réserve : riposte ordinaire")
	check_eq(_count(DraftCombos.AEGIS), 2, "pas de combo de plus")


# --- Terrain --------------------------------------------------------------------------------------------------------

func test_rift_prison() -> void:
	await _start([&"singularity", &"rift_wall"] as Array[StringName])
	var here: Vector3 = run.hunter.global_position
	check(_cast(&"rift_wall", here + Vector3(4, 0, 0)), "Mur")
	var near_wall: DraftEnemies.Foe = _foe(Vector3(5.2, 0, 0))
	var far: DraftEnemies.Foe = _foe(Vector3(8.5, 0, 0))
	await _frames(2)
	check(_cast(&"singularity", here + Vector3(5.5, 0, 0)), "Singularité près du mur")
	await _frames(3)
	check_eq(_count(DraftCombos.PRISON), 1, "Prison de faille déclenchée")
	check(near_wall.slow_left > 0.0 and near_wall.slow_factor == 0.0, "ennemi attiré près du mur entravé")
	check(far.slow_left <= 0.0, "ennemi loin du mur libre")
	await _frames(10)
	check_eq(_count(DraftCombos.PRISON), 1, "une annonce par puits")
	run.spells.world.wells.clear()
	near_wall.slow_left = 0.0
	run.spells.stash(run.spells.slot_of(&"rift_wall"))
	_cast(&"singularity", here + Vector3(5.5, 0, 0))
	await _frames(3)
	check(near_wall.slow_left <= 0.0, "Mur en réserve : rien")


func test_shattering_rampart() -> void:
	await _start([&"rift_leap", &"rift_wall"] as Array[StringName])
	var here: Vector3 = run.hunter.global_position
	check(_cast(&"rift_wall", here + Vector3(6, 0, 0)), "Mur")
	var foe: DraftEnemies.Foe = _foe(Vector3(7.5, 0, 0))
	await _frames(2)
	check(_cast(&"rift_leap", here + Vector3(4.5, 0, 0)), "Bond près du mur")
	await _settle()
	check_eq(_count(DraftCombos.RAMPART), 1, "Rempart fracassant déclenché")
	check(foe.hp < foe.max_hp, "onde du mur")
	check_eq(run.combos.on_landed(run.hunter.global_position, 10.0), 0, "une onde par mur")
	run.spells.stash(run.spells.slot_of(&"rift_wall"))
	run.spells.world.walls[0]["rampart"] = false
	check_eq(run.combos.on_landed(run.hunter.global_position, 10.0), 0, "Mur en réserve : rien")


func test_still_storm_is_capped() -> void:
	await _start([&"stasis_wave", &"shard_rain"] as Array[StringName])
	var foe: DraftEnemies.Foe = _foe(Vector3(2.5, 0, 0))
	await _frames(2)
	check(_cast(&"shard_rain", foe.pos), "Pluie sans stase")
	await _frames(40)
	check_eq(_count(DraftCombos.STORM), 0, "ennemi libre : rien")
	check(_cast(&"stasis_wave", foe.pos), "Onde de stase")
	check(run.combos.stasis_hits.has(foe), "ennemi figé")
	await _frames(40)
	check(_count(DraftCombos.STORM) >= 1, "Tempête immobile déclenchée")
	var crowd: Array[DraftEnemies.Foe] = []
	for i: int in 10:
		crowd.append(_foe(Vector3(2.5 + 0.3 * (i % 3), 0, 0.3 * (i / 3))))
	await _frames(2)
	for other: DraftEnemies.Foe in crowd:
		run.combos.on_stasis(other, 3.0)
	check_eq(run.combos.on_rain_tick(foe.pos, 3.0, 10.0), run.tuning.combo_storm_cap, "éclats plafonnés par coup")
	check_eq(run.bolts.size(), 0, "aucun projectile ajouté")
	run.spells.stash(run.spells.slot_of(&"stasis_wave"))
	check_eq(run.combos.on_rain_tick(foe.pos, 3.0, 10.0), 0, "Onde en réserve : rien")
	run.spells.equip(&"stasis_wave", 0)
	run.combos.step(10.0)
	check_eq(run.combos.on_rain_tick(foe.pos, 3.0, 10.0), 0, "stase finie : rien")
