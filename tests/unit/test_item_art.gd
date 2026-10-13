extends TestCase
## Couverture du contenu et clics conservés malgré les illustrations natives.


func test_every_upgrade_and_relic_has_a_distinct_illustration() -> void:
	var paths: PackedStringArray = []
	for kind: String in ["upgrade", "relic"]:
		var collection: Dictionary = GameDB.upgrades if kind == "upgrade" else GameDB.relics
		for id: StringName in collection:
			var image: Texture2D = ItemArt.texture(kind, id)
			check(image != null, "%s.%s : visuel présent" % [kind, id])
			if image:
				check(not paths.has(image.resource_path), "%s.%s : visuel distinct" % [kind, id])
				paths.append(image.resource_path)
	check(ItemArt.texture("offer", &"heal") != null, "soin illustré")
	check(ItemArt.texture("offer", &"shards") != null, "Éclats illustrés")
	check_eq(ItemArt.entries().size(), GameDB.upgrades.size() + GameDB.relics.size() + 2, "catalogue complet")


func test_illustrations_keep_transparency_and_readable_size() -> void:
	for key: String in ItemArt.entries():
		var entry: Dictionary = ItemArt.entries()[key]
		var texture: Texture2D = load(entry["image"])
		var image: Image = texture.get_image()
		check(image.get_width() >= 256 and image.get_height() >= 256, "%s : résolution suffisante" % key)
		check(image.detect_alpha() != Image.ALPHA_NONE, "%s : canal alpha" % key)
		for point: Vector2i in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0),
				Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
			check(image.get_pixelv(point).a < 0.01, "%s : coin transparent" % key)


func test_art_does_not_intercept_card_clicks() -> void:
	var offer := UpgradeOffer.new()
	offer.kind = UpgradeOffer.Kind.STAT
	offer.upgrade = GameDB.upgrades[&"might"]
	var clicks: Dictionary = {"count": 0}
	var card: Button = UiKit.card(offer.category(), offer.title(), offer.description(), offer.color(),
		func() -> void: clicks["count"] += 1)
	host.add_child(card)
	ItemArt.add_to_card(card, "upgrade", &"might", offer.color())
	var box: VBoxContainer = card.get_child(0)
	var panel: PanelContainer = box.get_child(1)
	var image: TextureRect = panel.get_child(0)
	check_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "cadre sans interception")
	check_eq(image.mouse_filter, Control.MOUSE_FILTER_IGNORE, "image sans interception")
	check_eq(image.texture, ItemArt.texture("upgrade", &"might"), "bonne illustration")
	card.pressed.emit()
	check_eq(clicks["count"], 1, "callback existant appelé une fois")
	card.free()


func test_illustrated_choices_apply_the_original_upgrade_and_relic() -> void:
	var run: RunController = RunFixture.create(host, &"ashblade")
	var offer := UpgradeOffer.new()
	offer.upgrade = GameDB.upgrade(&"might")
	offer.kind = UpgradeOffer.Kind.STAT
	offer.key = "up:might"
	run.level_up_panel._offers.clear()
	run.level_up_panel._offers.append(offer)
	run.level_up_panel.visible = true
	run.level_up_panel._refresh()
	await host.get_tree().process_frame
	(run.level_up_panel._cards.get_child(0) as Button).pressed.emit()
	check_eq(run.ctx.build.stacks_of(&"might"), 1, "amélioration existante appliquée une fois")
	run.chest_panel._relics.clear()
	run.chest_panel._relics.append(GameDB.relic(&"hunters_eye"))
	run.chest_panel.visible = true
	run.chest_panel._refresh_cards()
	await host.get_tree().process_frame
	(run.chest_panel._cards.get_child(0) as Button).pressed.emit()
	check(run.ctx.build.relics.has(&"hunters_eye"), "relique existante acquise")
	check(not host.get_tree().paused, "fermeture du choix après acquisition")
	RunFixture.dispose(run)


func test_undiscovered_relic_stays_hidden_in_bestiary() -> void:
	var original: ProfileData = Profile.profile
	Profile.profile = ProfileData.new()
	var refuge: Refuge = load("res://scenes/refuge.tscn").instantiate()
	host.add_child(refuge)
	refuge.tabs.current_tab = 2
	await host.get_tree().process_frame
	var bestiary: RefugeTab = refuge.tabs.get_child(2)
	bestiary._show("relic:cracked_hourglass")
	check(not bestiary._portrait_host.visible, "relique inconnue sans illustration")
	Profile.profile.discover("relics", "cracked_hourglass")
	bestiary._show("relic:cracked_hourglass")
	check(bestiary._portrait_host.visible, "illustration après découverte")
	refuge.free()
	Profile.profile = original
