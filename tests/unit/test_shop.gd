extends TestCase
## Boutique (lot M3) : achats en éclats, consommables emportés, avantages de survie, Échos en vente.

var profile: ProfileData
var run: RunController


func before_each() -> void:
	profile = ProfileData.new()
	profile.add_currency("shards", 10000)


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _win(arena: StringName) -> void:
	Campaign._mode_entry(profile, arena, Campaign.NORMAL)["wins"] = 1


func test_consumable_is_bought_packed_and_used_once() -> void:
	var flask: ShopItemData = GameDB.shop_items[&"vigor_flask"]
	check(Shop.buy(profile, flask) and Shop.buy(profile, flask), "deux fioles achetées")
	check_eq(profile.shards(), 10000 - 2 * flask.price, "éclats dépensés")
	check_eq(Shop.stock(profile, &"vigor_flask"), 2, "en stock")
	Shop.toggle_packed(profile, &"vigor_flask")
	check(Shop.is_packed(profile, &"vigor_flask"), "emportée")
	var prepared: Dictionary = Shop.prepare_run(profile, GameDB.arena(&"three_rifts"))
	check_eq(prepared["items"], [&"vigor_flask"] as Array[StringName], "utilisée au départ")
	check_eq(Shop.stock(profile, &"vigor_flask"), 1, "une unité consommée")
	check(Shop.is_packed(profile, &"vigor_flask"), "reste emportée tant qu'il en reste")
	Shop.prepare_run(profile, GameDB.arena(&"three_rifts"))
	check_eq(Shop.stock(profile, &"vigor_flask"), 0, "stock épuisé")
	check(not Shop.is_packed(profile, &"vigor_flask"), "plus rien à emporter")


func test_flask_raises_max_hp_in_the_run() -> void:
	Shop.buy(profile, GameDB.shop_items[&"vigor_flask"])
	Shop.toggle_packed(profile, &"vigor_flask")
	var setup := RunSetup.new()
	setup.arena_id = &"three_rifts"
	setup.starter_id = &"ashblade"
	setup.autopilot = true
	var prepared: Dictionary = Shop.prepare_run(profile, GameDB.arena(&"three_rifts"))
	setup.meta_effects.assign(prepared["effects"])
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	check_near(run.ctx.player.stats.get_value(StatKeys.MAX_HP), run.ctx.balance.player_max_hp * 1.3, 0.5, "PV max +30 %")


func test_survival_perks_are_gated_owned_once_and_survival_only() -> void:
	var drill: ShopItemData = GameDB.shop_items[&"survival_drill"]
	check(not Shop.can_buy(profile, drill), "pas en vente avant la Plaine fracturée")
	_win(&"fractured_plain")
	check(Shop.buy(profile, drill), "acheté")
	check(not Shop.can_buy(profile, drill), "acquis une seule fois")
	check_eq(int(Shop.prepare_run(profile, GameDB.arena(&"three_rifts"))["start_levels"]), 0, "rien en campagne")
	check_eq(int(Shop.prepare_run(profile, GameDB.arena(&"fractured_plain"))["start_levels"]), 1, "niveau 2 en survie")


func test_shop_echo_goes_on_sale_after_its_map() -> void:
	var echo: MonsterData = null
	for monster: MonsterData in GameDB.monsters.values():
		if monster.discovery == EchoCollection.SHOP and GameDB.arena(monster.discovery_arena) != null:
			echo = monster
	check(echo != null, "un Écho en vente sur une carte jouable")
	check(not Shop.buy_echo(profile, echo), "pas avant sa carte")
	_win(echo.discovery_arena)
	check(Shop.buy_echo(profile, echo), "acheté")
	check(profile.is_monster_unlocked(echo), "débloqué")
	check_eq(profile.shards(), 10000 - echo.shop_price, "prix payé")


func test_relic_cache_is_kept_for_survival() -> void:
	_win(&"storm_highlands")
	Shop.buy(profile, GameDB.shop_items[&"relic_cache"])
	Shop.toggle_packed(profile, &"relic_cache")
	var campaign: Dictionary = Shop.prepare_run(profile, GameDB.arena(&"three_rifts"))
	check(not (campaign["items"] as Array).has(&"relic_cache"), "pas utilisé en campagne")
	check_eq(Shop.stock(profile, &"relic_cache"), 1, "ni consommé")
	var survival: Dictionary = Shop.prepare_run(profile, GameDB.arena(&"fractured_plain"))
	check((survival["items"] as Array).has(&"relic_cache"), "utilisé en survie")


func test_no_starting_relic_in_the_campaign() -> void:
	for arena_id: StringName in [&"three_rifts", &"fractured_plain"]:
		var setup := RunSetup.new()
		setup.arena_id = arena_id
		setup.starter_id = &"ashblade"
		# Sans bot : il choisirait la relique aussitôt et le panneau se refermerait.
		setup.autopilot = false
		setup.meta_effects.assign(GameDB.shop_items[&"relic_cache"].effects)
		run = load(Router.RUN).instantiate()
		run.skip_profile = true
		run.start(setup)
		host.add_child(run)
		run.set_physics_process(false)
		await host.get_tree().process_frame
		var survival: bool = arena_id == &"fractured_plain"
		check_eq(run.chest_panel.visible, survival, "%s : relique au départ seulement en survie" % arena_id)
		get_tree_paused_reset()
		RunFixture.dispose(run)
		run = null


func get_tree_paused_reset() -> void:
	host.get_tree().paused = false
