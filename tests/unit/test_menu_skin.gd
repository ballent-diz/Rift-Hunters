extends TestCase
## Les menus utilisent les mêmes assets que la partie et conservent les onglets/actions.

const REFUGE_SCENE := preload("res://scenes/refuge.tscn")

var _profile: ProfileData
var _refuge: Refuge


func before_each() -> void:
	_profile = Profile.profile
	Profile.profile = ProfileData.new()


func after_each() -> void:
	if is_instance_valid(_refuge):
		_refuge.free()
	Profile.profile = _profile


func test_refuge_keeps_all_tabs_and_hides_unknown_portraits() -> void:
	_refuge = REFUGE_SCENE.instantiate()
	host.add_child(_refuge)
	await host.get_tree().process_frame
	check_eq(_refuge.tabs.get_tab_count(), 8, "les huit onglets (dont Échos)")
	for i: int in 7:
		_refuge.tabs.current_tab = i
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		check(_refuge.tabs.get_child(i).get_child_count() > 0, "onglet construit : %d" % i)
		check(_refuge.tabs.position.x + _refuge.tabs.size.x <= _refuge.size.x + 1, "onglet sans débordement : %d" % i)
	_refuge.tabs.current_tab = 3
	await host.get_tree().process_frame
	var bestiary: RefugeTab = _refuge.tabs.get_child(3)
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		bestiary._show("monster:" + String(id))
		var known: bool = Profile.profile.is_monster_unlocked(GameDB.monster(id))
		check_eq(bestiary._portrait_host.visible, known, "portrait visible seulement si découvert : %s" % id)


func test_echo_portrait_reuses_actual_game_sprite_and_palette() -> void:
	var run: RunController = RunFixture.create(host, &"ashblade")
	var ally: Ally = run.ctx.allies.get_ally(&"ashblade")
	var portrait := EchoPortrait.new()
	host.add_child(portrait)
	portrait.setup(ally.data)
	check_eq(portrait.visual._anim.sprite_frames, ally.visual._anim.sprite_frames, "même feuille et animations que la partie")
	check_eq(portrait.visual._anim.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "pixels nets")
	portrait.free()
	var palette: Array = [Color(0.4, 0.8, 0.3), Color(0.9, 0.8, 0.2)]
	run.ctx.setup.palettes[ally.data.id] = palette
	ally._refresh_visual()
	portrait = EchoPortrait.new()
	host.add_child(portrait)
	portrait.setup(ally.data, palette)
	check_eq(portrait.visual._tint, ally.visual._tint, "même palette que l'allié")
	portrait.free()
	RunFixture.dispose(run)


func test_menu_theme_does_not_change_shared_hud_theme() -> void:
	var original: StyleBox = UiKit.theme().get_stylebox("normal", "Button")
	check(MenuSkin.theme() != UiKit.theme(), "thème local indépendant")
	check_eq(UiKit.theme().get_stylebox("normal", "Button"), original, "thème partagé conservé")


func test_pause_and_results_keep_existing_callbacks() -> void:
	var run: RunController = RunFixture.create(host, &"mossback")
	run.pause_panel.open()
	check(host.get_tree().paused, "pause de la partie")
	await host.get_tree().process_frame
	var resume: Button = run.pause_panel._box.get_child(1)
	resume.pressed.emit()
	check(not host.get_tree().paused, "reprendre par le bouton existant")
	var calls: Dictionary = {"refuge": false, "replay": false}
	# Isole les signaux du panneau pour ne pas remplacer la scène du lanceur de tests.
	for connection: Dictionary in run.results_panel.refuge_requested.get_connections():
		run.results_panel.refuge_requested.disconnect(connection["callable"])
	for connection: Dictionary in run.results_panel.replay_requested.get_connections():
		run.results_panel.replay_requested.disconnect(connection["callable"])
	run.results_panel.refuge_requested.connect(func() -> void: calls["refuge"] = true)
	run.results_panel.replay_requested.connect(func() -> void: calls["replay"] = true)
	run.results_panel.show_result({}, {})
	await host.get_tree().process_frame
	var box: VBoxContainer = run.results_panel._box
	var buttons: HBoxContainer = box.get_child(box.get_child_count() - 1)
	(buttons.get_child(0) as Button).pressed.emit()
	(buttons.get_child(1) as Button).pressed.emit()
	check(calls["refuge"] and calls["replay"], "signaux de résultat conservés")
	RunFixture.dispose(run)


func test_refuge_tab_keeps_scroll_after_rebuild() -> void:
	_refuge = REFUGE_SCENE.instantiate()
	host.add_child(_refuge)
	_refuge.tabs.current_tab = 0
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var tab: RefugeTab = _refuge.tabs.get_child(0)
	var scroll: ScrollContainer = tab.get_child(0) as ScrollContainer
	scroll.scroll_vertical = 300
	check_eq(scroll.scroll_vertical, 300, "onglet défilé")
	tab.refresh()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var rebuilt: ScrollContainer = tab.get_child(0) as ScrollContainer
	check(rebuilt != scroll, "contenu reconstruit")
	check_eq(rebuilt.scroll_vertical, 300, "un clic ne fait plus remonter en haut du menu")
