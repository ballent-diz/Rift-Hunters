extends TestCase
## Salle d'entraînement (lot 6 des menus) : mannequins, aucune vague, mesure des dégâts, profil intact.

var _previous: ProfileData


func before_each() -> void:
	_previous = Profile.profile
	Profile.profile = ProfileData.new()


func after_each() -> void:
	Profile.profile = _previous


func test_training_setup_spends_nothing() -> void:
	var flask: ShopItemData = GameDB.shop_items[&"vigor_flask"]
	Profile.profile.data["shop"]["stock"] = {"vigor_flask": 1}
	(Profile.profile.data["shop"]["packed"] as Array).append("vigor_flask")
	var setup: RunSetup = Profile.make_training_setup()
	check(setup.training, "partie d'entraînement")
	check_eq(setup.arena_id, &"training_grounds", "arène des mannequins")
	check(setup.shop_items.is_empty(), "aucun consommable emporté")
	check_eq(Shop.stock(Profile.profile, flask.id), 1, "le stock de la boutique reste intact")
	check(not Profile.profile.is_arena_unlocked(GameDB.arena(&"training_grounds")), "jamais proposée comme carte")


func test_dummies_take_hits_and_the_meter_reads_them() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"training_grounds"
	setup.training = true
	setup.starter_id = &"ashblade"
	setup.autopilot = true
	setup.unlocked_monsters = GameDB.sorted_ids(GameDB.monsters)
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	var dummies: Array = run.ctx.enemies.list.filter(func(e: Enemy) -> bool: return e.data.id == &"training_dummy")
	check_eq(dummies.size(), 4, "quatre mannequins")
	var meter: TrainingMeter = run.find_child("TrainingMeter", true, false)
	check(meter != null, "compteur de dégâts affiché")
	var dummy: Enemy = dummies[0]
	run.ctx.combat.deal_damage(dummy, RunFixture.info(500.0))
	check(dummy.hp > 0.0, "un mannequin encaisse sans tomber")
	var dealt: Dictionary = TrainingMeter.dealt_by_source(run.ctx.stats.damage_by_source)
	check_eq(int(dealt.get("player", 0.0)), 500, "dégâts du Chasseur comptés")
	var samples: Array[Vector2] = [Vector2(0, 0), Vector2(5, 1000)]
	check_eq(int(TrainingMeter.dps(samples)), 200, "dégâts par seconde sur la fenêtre")
	for i: int in 120:
		run.ctx.time += 0.5
		run.ctx.spawner.step(0.5)
	var others: int = run.ctx.enemies.list.filter(func(e: Enemy) -> bool: return e.data.id != &"training_dummy").size()
	check_eq(others, 0, "aucune vague")
	RunFixture.dispose(run)
