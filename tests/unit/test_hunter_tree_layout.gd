extends TestCase
## Régression C5 : écran réel à 1280×720 dans les deux langues et actions via les boutons du refuge.

var _previous: ProfileData
var _previous_path: String
var _previous_read_only: bool
var _previous_locale: String


func before_each() -> void:
	_previous = Profile.profile
	_previous_path = Profile.path
	_previous_read_only = Profile.read_only
	_previous_locale = TranslationServer.get_locale()
	Profile.profile = ProfileData.new()
	Profile.path = "user://c5_test_tree_ui.json"
	Profile.read_only = false
	Profile.profile.add_currency("shards", 10000)


func after_each() -> void:
	Profile.profile = _previous
	Profile.path = _previous_path
	Profile.read_only = _previous_read_only
	TranslationServer.set_locale(_previous_locale)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://c5_test_tree_ui.json" + suffix)


func test_tree_and_upgrades_fit_720p_in_both_languages() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	host.add_child(viewport)
	var screen: Refuge = load(Router.REFUGE).instantiate()
	viewport.add_child(screen)
	screen.tabs.current_tab = 1
	var tab: RefugeTab = screen.tabs.get_child(1)
	for locale: String in ["fr", "en"]:
		TranslationServer.set_locale(locale)
		for utilities: bool in [false, true]:
			tab._show_upgrades = utilities
			for selected: StringName in [&"blade_cleaving_slash", &"blade_master", &"research_fourth_option"]:
				tab._selected = selected
				screen.refresh_current()
				await _settle()
				check(tab.find_child("TreeDetail", true, false) != null, "panneau de détail conservé")
				check_eq(tab.find_children("SpellSlot*", "Button", true, false).size(), 4, "quatre emplacements")
				if not utilities:
					var plan: HunterTreeBoard = tab.find_child("TreeBoard", true, false)
					var expected: int = 0
					for branch: StringName in [&"trunk"] + HunterTreeSkin.PATHS:
						expected += HunterTree.nodes_of_branch(branch).size()
					check_eq(plan._buttons.size(), expected, "tous les nœuds de combat présents")
				# Le moteur sans affichage fournit une police factice (hauteur 3× la taille).
				# Les assertions géométriques sont aussi exécutées avec le moteur graphique réel.
				if DisplayServer.get_name() == "headless":
					continue
				var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
				check(bounds.encloses(tab.get_global_rect()), "onglet contenu dans la fenêtre (%s) : %s" % [locale, tab.get_global_rect()])
				check(tab.get_combined_minimum_size().x <= tab.size.x, "aucun débordement horizontal")
				check(tab.get_combined_minimum_size().y <= tab.size.y, "aucun débordement vertical")
				for button: Node in tab.find_children("*", "Button", true, false):
					check(bounds.encloses(button.get_global_rect()), "bouton accessible : %s %s" % [button.name, button.get_global_rect()])
				if not utilities:
					var board: HunterTreeBoard = tab.find_child("TreeBoard", true, false)
					for node: HunterTreeNode in board._buttons.values():
						check(board.get_global_rect().encloses(node.get_global_rect()), "nœud visible : %s" % node.name)
	screen.queue_free()
	viewport.queue_free()
	await _settle()


func test_learning_activation_build_and_equipment_buttons() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	host.add_child(viewport)
	var screen: Refuge = load(Router.REFUGE).instantiate()
	viewport.add_child(screen)
	screen.tabs.current_tab = 1
	var tab: RefugeTab = screen.tabs.get_child(1)
	var data: SkillNodeData = GameDB.skill_node(&"blade_honed_edge")
	var node: Button = tab.find_child(str(data.id), true, false)
	node.pressed.emit()
	var learn: Button = tab.find_child("LearnNode", true, false)
	learn.pressed.emit()
	check_eq(HunterTree.learned_rank(Profile.profile, data), 1, "apprentissage transmis à HunterTree")
	var activate: Button = tab.find_child("ActivateNode", true, false)
	activate.pressed.emit()
	check_eq(HunterTree.active_rank(Profile.profile, data), 1, "activation dans le build")
	var deactivate: Button = tab.find_child("DeactivateNode", true, false)
	deactivate.pressed.emit()
	check_eq(HunterTree.active_rank(Profile.profile, data), 0, "retrait dans le build")
	tab._select(&"blade_cleaving_slash")
	var slot: Button = tab.find_child("SpellSlot3", true, false)
	slot.pressed.emit()
	check_eq(HunterTree.slot_of(Profile.profile, &"cleaving_slash"), 3, "équipement sur F")
	var builds: Array[Node] = tab.find_children("BuildSelect*", "Button", true, false)
	check_eq(builds.size(), HunterTree.BUILD_COUNT, "trois builds disponibles")
	(builds[1] as Button).pressed.emit()
	check_eq(HunterTree.active_index(Profile.profile), 1, "changement de build")
	check_eq(HunterTree.slot_of(Profile.profile, &"cleaving_slash"), 0, "équipement du second build conservé")
	screen.queue_free()
	viewport.queue_free()
	await _settle()


func _settle() -> void:
	for frame: int in 4:
		await host.get_tree().process_frame


func test_all_24_spell_and_talent_icons_are_imported() -> void:
	var count: int = 0
	for data: SkillNodeData in GameDB.skill_nodes.values():
		if data.kind in [SkillNodeData.Kind.SPELL, SkillNodeData.Kind.TRANSFORM, SkillNodeData.Kind.KEYSTONE]:
			count += 1
			check(HunterTreeSkin.icon(data) != null, "illustration du nœud : %s" % data.id)
	check_eq(count, 24, "12 sorts, 8 transformants et 4 clés de voûte")
