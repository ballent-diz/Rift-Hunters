extends TestCase
## Sorts actifs du Chasseur dans la base 3D (draft3d/spells.gd, docs/design/SORTS_ACTIFS_V2.md) : emplacements et
## apprentissage, recharges, visée au clavier seul, effets de Taille, Lance, Rupture et Bond, cartes de sort du choix
## de niveau, lancement par le bot, barre de sorts et fenêtre des touches.

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


func _foe(offset: Vector3) -> DraftEnemies.Foe:
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + offset)
	foe.speed = 0.0
	return foe


func _hurt(foe: DraftEnemies.Foe) -> bool:
	return not foe.alive or foe.hp < foe.max_hp


func test_slots_learning_and_cooldowns() -> void:
	await _start()
	var spells: DraftSpells = run.spells
	check_eq(spells.slots.size(), DraftSpells.SLOTS, "quatre emplacements")
	check_eq(spells.slots[0].id, &"cleaving_slash", "Taille sur le premier emplacement")
	check_eq(spells.slots[1].id, &"prismatic_lance", "Lance sur le deuxième")
	check_eq(spells.free_slots(), 2, "deux emplacements libres")
	check(not spells.learn(&"cleaving_slash"), "un sort connu ne s'apprend pas deux fois")
	check(not spells.learn(&"parry"), "un sort non raccordé à la 3D est refusé")
	check(spells.learn(&"rupture") and spells.slot_of(&"rupture") == 2, "Rupture prend la première place libre")
	check(spells.learn(&"rift_leap"), "Bond appris")
	check_eq(spells.free_slots(), 0, "barre pleine")
	check(not spells.learn(&"rupture"), "plus de place")
	spells.cooldowns[0] = 0.0
	check(spells.cast(0, run.hunter.global_position + Vector3(3, 0, 0)), "le sort prêt part")
	check(is_equal_approx(spells.cooldowns[0], spells.cooldown_of(spells.slots[0])), "recharge complète")
	check(not spells.cast(0, run.hunter.global_position), "en recharge : rien ne part")
	check(spells.ready_ratio(0) < 0.05, "barre de recharge vide juste après")
	check(not spells.cast(3 + 1, Vector3.ZERO), "emplacement hors limites refusé")


func test_slash_hits_the_arc_in_front_only() -> void:
	await _start()
	var front: DraftEnemies.Foe = _foe(Vector3(2.5, 0, 0))
	var behind: DraftEnemies.Foe = _foe(Vector3(-3.0, 0, 0))
	await _frames(2)
	run.spells.cooldowns[0] = 0.0
	run.spells.cast(0, run.hunter.global_position + Vector3(4, 0, 0))
	check(_hurt(front), "l'ennemi dans l'arc est touché")
	check(not _hurt(behind), "l'ennemi derrière ne l'est pas")


func test_lance_pierces_the_line() -> void:
	await _start()
	var first: DraftEnemies.Foe = _foe(Vector3(3, 0, 0))
	var second: DraftEnemies.Foe = _foe(Vector3(6, 0, 0))
	var side: DraftEnemies.Foe = _foe(Vector3(0, 0, 4))
	run.spells.cooldowns[1] = 0.0
	check(run.spells.cast(1, run.hunter.global_position + Vector3(8, 0, 0)), "la Lance part")
	await _frames(40)
	check(_hurt(first) and _hurt(second), "la Lance traverse les deux ennemis alignés")
	check(not _hurt(side), "l'ennemi hors de la ligne est épargné")


func test_rupture_hits_the_area_at_the_aim() -> void:
	await _start()
	run.spells.learn(&"rupture")
	var slot: int = run.spells.slot_of(&"rupture")
	var center: DraftEnemies.Foe = _foe(Vector3(6, 0, 0))
	var near: DraftEnemies.Foe = _foe(Vector3(6, 0, 1.2))
	var far: DraftEnemies.Foe = _foe(Vector3(-5, 0, 0))
	await _frames(2)
	run.spells.cooldowns[slot] = 0.0
	check(run.spells.cast(slot, center.pos), "Rupture part")
	check(_hurt(center) and _hurt(near), "les ennemis de la zone sont touchés")
	check(not _hurt(far), "un ennemi loin de la zone est épargné")


func test_leap_moves_protects_and_strikes_on_landing() -> void:
	await _start()
	run.spells.learn(&"rift_leap")
	var slot: int = run.spells.slot_of(&"rift_leap")
	var hunter: DraftHunter = run.hunter
	var start: Vector3 = hunter.global_position
	var waiting: DraftEnemies.Foe = _foe(Vector3(5.5, 0, 0))
	await _frames(2)
	run.spells.cooldowns[slot] = 0.0
	check(run.spells.cast(slot, start + Vector3(5, 0, 0)), "le Bond part")
	check(hunter.is_leaping() and hunter.invulnerable > 0.0, "invulnérable pendant le saut")
	check(not run.spells.cast(0, start), "aucun autre sort pendant le saut")
	await _frames(30)
	check(not hunter.is_leaping(), "le saut est fini")
	var moved: float = hunter.global_position.distance_to(start)
	check(moved > 3.0, "le Chasseur a bondi (%.1f m)" % moved)
	check(_hurt(waiting), "l'onde d'arrivée frappe")
	check(hunter.global_position.distance_to(start) <= run.spells.reach_of(GameDB.spells[&"rift_leap"]) + 0.5,
		"portée du Bond respectée")


func test_keyboard_aim_picks_the_foe_in_front() -> void:
	await _start()
	var front: DraftEnemies.Foe = _foe(Vector3(5, 0, 0.5))
	var behind: DraftEnemies.Foe = _foe(Vector3(-3, 0, 0))
	await _frames(2)
	var here: Vector3 = run.hunter.global_position
	check(run.spells.facing_aim(Vector3.RIGHT).distance_to(front.pos) < 0.01, "vise l'ennemi devant")
	var empty: Vector3 = run.spells.facing_aim(Vector3(0, 0, 1))
	check(empty.distance_to(here + Vector3(0, 0, run.tuning.aim_distance)) < 0.01, "sans cible : droit devant")
	check(behind.pos.distance_to(run.spells.facing_aim(Vector3.RIGHT)) > 1.0, "jamais l'ennemi derrière")


func test_spell_cards_in_level_up_choice() -> void:
	await _start()
	var upgrades: DraftUpgrades = run.upgrades
	var learn_rupture: UpgradeData = load("res://draft3d/spells/learn_rupture.tres")
	var learn_slash: UpgradeData = load("res://draft3d/spells/learn_cleaving_slash.tres")
	check(upgrades.available().has(learn_rupture), "Rupture s'offre : place libre et sort inconnu")
	check(not upgrades.available().has(learn_slash), "Taille déjà connue : jamais offerte")
	check(upgrades.apply(learn_rupture, run.hunter.stats) and run.spells.has_spell(&"rupture"), "la carte apprend le sort")
	run.spells.learn(&"rift_leap")
	for data: UpgradeData in upgrades.available():
		check(not String(data.id).begins_with("learn_"), "barre pleine : plus aucune carte d'apprentissage (%s)" % data.id)
	var detached := DraftUpgrades.new()
	check(not detached.available().has(learn_rupture), "sans sorts branchés, aucune carte de sort")


func test_bot_casts_and_hud_shows_slots() -> void:
	await _start()
	run.spells.auto_cast = true
	var foe: DraftEnemies.Foe = _foe(Vector3(2, 0, 0))
	await _frames(240)
	check(run.spells.casts >= 1 and _hurt(foe), "le bot lance ses sorts (%d)" % run.spells.casts)
	var bar: DraftSpellBar = run.hud.find_child("SpellBar", true, false)
	check(bar != null and bar.spells == run.spells, "barre de sorts branchée")
	check(not run.spells.reticle.visible, "aucun anneau de visée pour le bot")
	run.spells.auto_cast = false
	await _frames(2)
	check(run.spells.reticle.visible, "anneau de visée au sol pour le joueur")


func test_controls_window_rebinds_spells() -> void:
	var options := DraftOptions.new()
	host.add_child(options)
	await host.get_tree().process_frame
	var keys: Button = options.find_child("Keys", true, false)
	check(keys != null, "bouton Touches et visée dans les options")
	keys.pressed.emit()
	await host.get_tree().process_frame
	var window: DraftControls = options.get_node_or_null("ControlsWindow")
	check(window != null, "fenêtre des touches ouverte")
	for action: StringName in [&"spell_1", &"spell_2", &"spell_3", &"spell_4", &"dash"]:
		check(window.find_child(String(action), true, false) is KeyBindButton, "touche reconfigurable : %s" % action)
	options.queue_free()


func _card(id: String) -> UpgradeData:
	return load("res://draft3d/spells/%s.tres" % id)


func test_rank_and_variant_cards_follow_the_rules() -> void:
	await _start()
	var upgrades: DraftUpgrades = run.upgrades
	var slash: SpellData = GameDB.spells[&"cleaving_slash"]
	check_eq(upgrades.spell_cards.size(), 20, "vingt cartes : 4 sorts, 8 variantes, 8 rangs")
	for data: UpgradeData in upgrades.spell_cards:
		check(tr(data.name_key) != data.name_key and tr(data.desc_key) != data.desc_key, "%s : textes traduits" % data.id)
	check(not upgrades.available().has(_card("rupture_wide")), "aucun rang pour un sort inconnu")
	check(not upgrades.available().has(_card("leap_impact")), "aucune variante pour un sort inconnu")
	var base_damage: float = run.spells.damage_of(slash)
	var base_cooldown: float = run.spells.cooldown_of(GameDB.spells[&"prismatic_lance"])
	check(upgrades.apply(_card("slash_edge"), run.hunter.stats), "rang de dégâts pris")
	check_near(run.spells.damage_of(slash), base_damage * 1.2, 0.01, "dégâts de la Taille +20 %")
	upgrades.apply(_card("lance_tempo"), run.hunter.stats)
	check_near(run.spells.cooldown_of(GameDB.spells[&"prismatic_lance"]), base_cooldown * 0.85, 0.01, "recharge −15 %")
	check(upgrades.apply(_card("slash_whirlwind"), run.hunter.stats), "variante prise")
	check_eq(run.spells.variant_of(slash), &"whirlwind", "Tourbillon actif")
	check(not upgrades.can_offer(_card("slash_thrust")), "une seule variante par sort")
	check(not upgrades.apply(_card("slash_thrust"), run.hunter.stats), "l'autre variante est refusée")


func test_slash_variants() -> void:
	await _start()
	run.upgrades.apply(_card("slash_whirlwind"), run.hunter.stats)
	var behind: DraftEnemies.Foe = _foe(Vector3(-2.5, 0, 0))
	await _frames(2)
	run.spells.cooldowns[0] = 0.0
	run.spells.cast(0, run.hunter.global_position + Vector3(4, 0, 0))
	check(_hurt(behind), "Tourbillon : l'ennemi derrière est touché")
	run.queue_free()
	run = null
	await _start()
	run.upgrades.apply(_card("slash_thrust"), run.hunter.stats)
	var far: DraftEnemies.Foe = _foe(Vector3(8, 0, 0))
	var aside: DraftEnemies.Foe = _foe(Vector3(3, 0, 2.5))
	await _frames(2)
	run.spells.cooldowns[0] = 0.0
	run.spells.cast(0, run.hunter.global_position + Vector3(4, 0, 0))
	check(_hurt(far), "Estoc : la ligne longue atteint l'ennemi à 8 m")
	check(not _hurt(aside), "Estoc : étroit, l'ennemi à côté est épargné")


func test_lance_variants() -> void:
	await _start()
	run.upgrades.apply(_card("lance_fan"), run.hunter.stats)
	var before: int = run.bolts.size()
	run.spells.cooldowns[1] = 0.0
	run.spells.cast(1, run.hunter.global_position + Vector3(5, 0, 0))
	check_eq(run.bolts.size() - before, 3, "Éventail : trois lances")
	var fan_damage: float = float(run.bolts[run.bolts.size() - 1]["damage"])
	check_near(fan_damage, run.spells.damage_of(GameDB.spells[&"prismatic_lance"]) * 0.8, 0.01, "80 % des dégâts")
	run.queue_free()
	run = null
	await _start()
	run.upgrades.apply(_card("lance_overcharge"), run.hunter.stats)
	var lance: SpellData = GameDB.spells[&"prismatic_lance"]
	run.spells.charge_time = 0.0
	check_near(run.spells.charge_power(lance), 1.0, 0.01, "Surcharge à vide : ×1")
	run.spells.charge_time = 5.0
	check_near(run.spells.charge_power(lance), 2.5, 0.01, "Surcharge pleine : ×2,5")
	run.spells.cooldowns[1] = 0.0
	run.spells.cast(1, run.hunter.global_position + Vector3(5, 0, 0), 2.5)
	check_near(float(run.bolts[run.bolts.size() - 1]["damage"]), run.spells.damage_of(lance) * 2.5, 0.01, "lance chargée")


func test_rupture_variants() -> void:
	await _start()
	run.spells.learn(&"rupture")
	var slot: int = run.spells.slot_of(&"rupture")
	run.upgrades.apply(_card("rupture_reaction"), run.hunter.stats)
	var center: DraftEnemies.Foe = _foe(Vector3(5, 0, 0))
	var chained: DraftEnemies.Foe = _foe(Vector3(9, 0, 0))
	await _frames(2)
	run.spells.cooldowns[slot] = 0.0
	run.spells.cast(slot, center.pos)
	check(_hurt(chained), "Réaction : la détonation rebondit sur l'ennemi voisin")
	run.queue_free()
	run = null
	await _start()
	run.spells.learn(&"rupture")
	slot = run.spells.slot_of(&"rupture")
	run.upgrades.apply(_card("rupture_blaze"), run.hunter.stats)
	run.spells.cooldowns[slot] = 0.0
	var spot: Vector3 = run.hunter.global_position + Vector3(5, 0, 0)
	run.spells.cast(slot, spot)
	var walker: DraftEnemies.Foe = _foe(Vector3(5, 0, 0))
	await _frames(45)
	check(_hurt(walker), "Brasier : le sol brûle encore après la détonation")
	await _frames(200)
	check(run.spells._zones.is_empty(), "le Brasier s'éteint")


func test_leap_variants() -> void:
	await _start()
	run.spells.learn(&"rift_leap")
	var slot: int = run.spells.slot_of(&"rift_leap")
	run.upgrades.apply(_card("leap_return"), run.hunter.stats)
	var start: Vector3 = run.hunter.global_position
	run.spells.cooldowns[slot] = 0.0
	run.spells.cast(slot, start + Vector3(5, 0, 0))
	await _frames(30)
	check(run.hunter.global_position.distance_to(start) > 3.0, "le Bond est parti")
	check(run.spells.leap_back(), "Retour : la touche ramène au départ")
	await _frames(30)
	check(run.hunter.global_position.distance_to(start) < 1.0, "revenu au point de départ")
	check(not run.spells.leap_back(), "un seul retour")
	run.queue_free()
	run = null
	await _start()
	run.spells.learn(&"rift_leap")
	slot = run.spells.slot_of(&"rift_leap")
	run.upgrades.apply(_card("leap_impact"), run.hunter.stats)
	var leap: SpellData = GameDB.spells[&"rift_leap"]
	check_near(run.spells.area_of(leap), leap.width * DraftHunter.UNIT * 2.0, 0.01, "Impact : onde 2× plus large")
	var tough: DraftEnemies.Foe = _foe(Vector3(6, 0, 0))
	tough.hp = 100000.0
	tough.max_hp = 100000.0
	await _frames(2)
	run.spells.cooldowns[slot] = 0.0
	run.spells.cast(slot, run.hunter.global_position + Vector3(5, 0, 0))
	await _frames(30)
	check(tough.slow_left > 0.0 and is_equal_approx(tough.slow_factor, 0.5), "Impact : l'ennemi est ralenti")
