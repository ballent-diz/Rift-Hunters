extends TestCase
## Les choix doivent rester lisibles, défilables et cliquables après ouverture en pause.


func test_level_choices_remain_accessible_in_small_windows() -> void:
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(960, 720), Vector2i(640, 480)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		host.add_child(viewport)
		var run: RunController = RunFixture.create(viewport, &"mossback")
		run.ctx.setup.autopilot = false
		var panel: LevelUpPanel = run.level_up_panel
		panel.open()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var frame: PanelContainer = panel.get_node("ModalFrame")
		var scroll: ScrollContainer = frame.get_node("ModalScroll")
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(frame.get_global_rect()), "cadre dans %s" % resolution)
		check(frame.size.y >= 300, "panneau assez haut pour une carte")
		check_eq(panel._cards.get_child_count(), panel._offers.size(), "tous les choix conservés")
		for card: Button in panel._cards.get_children():
			check(card.size.x >= 240 and card.size.y >= 300, "carte lisible")
			scroll.ensure_control_visible(card)
			await host.get_tree().process_frame
			check(scroll.get_global_rect().intersects(card.get_global_rect()), "choix accessible en défilant")
		var closed_count := {"value": 0}
		panel.closed.connect(func() -> void: closed_count.value += 1)
		var first: Button = panel._cards.get_child(0)
		scroll.ensure_control_visible(first)
		await host.get_tree().process_frame
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = first.get_global_rect().get_center()
		viewport.push_input(press)
		var release: InputEventMouseButton = press.duplicate()
		release.pressed = false
		viewport.push_input(release)
		await host.get_tree().process_frame
		check_eq(closed_count.value, 1, "sélection appliquée une fois")
		check(not host.get_tree().paused, "partie reprise")
		RunFixture.dispose(run)
		viewport.queue_free()
		await host.get_tree().process_frame


func test_four_choices_wrap_and_stay_accessible() -> void:
	var run: RunController = RunFixture.create(host, &"mossback")
	run.ctx.setup.autopilot = false
	var panel: LevelUpPanel = run.level_up_panel
	panel.open()
	panel._offers.clear()
	for id: StringName in [&"might", &"cadence", &"vitality", &"swiftness"]:
		var offer := UpgradeOffer.new()
		offer.kind = UpgradeOffer.Kind.STAT
		offer.upgrade = GameDB.upgrade(id)
		panel._offers.append(offer)
	panel._refresh()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check_eq(panel._cards.get_child_count(), 4, "quatre choix affichés")
	check(panel.get_node("ModalFrame").size.y > 300, "cadre développé après refresh")
	RunFixture.dispose(run)
