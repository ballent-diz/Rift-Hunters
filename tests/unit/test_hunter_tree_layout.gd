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
	screen.tabs.current_tab = 2
	var tab: RefugeTab = screen.tabs.get_child(2)
	tab._focused_branch = &"blade"
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
					var expected: int = HunterTree.nodes_of_branch(&"trunk").size() + HunterTree.nodes_of_branch(&"blade").size()
					check_eq(plan._buttons.size(), expected, "tronc commun et voie entière présents")
				# Le moteur sans affichage fournit une police factice (hauteur 3× la taille).
				# Les assertions géométriques sont aussi exécutées avec le moteur graphique réel.
				if DisplayServer.get_name() == "headless":
					continue
				var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size))
				check(bounds.encloses(tab.get_global_rect()), "onglet contenu dans la fenêtre (%s) : %s" % [locale, tab.get_global_rect()])
				check(tab.get_combined_minimum_size().x <= tab.size.x, "aucun débordement horizontal")
				check(tab.get_combined_minimum_size().y <= tab.size.y, "aucun débordement vertical")
				for button: Node in tab.find_children("*", "Button", true, false):
					if button.is_ancestor_of(tab.find_child("DetailScroll", true, false)):
						continue
					if button.get_parent() is CenterContainer:
						continue
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
	screen.tabs.current_tab = 2
	var tab: RefugeTab = screen.tabs.get_child(2)
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
	check((tab.find_child("SpellSlot3", true, false) as Button).disabled, "4e emplacement fermé avant la fin du chapitre 1")
	var slot: Button = tab.find_child("SpellSlot1", true, false)
	slot.pressed.emit()
	check_eq(HunterTree.slot_of(Profile.profile, &"cleaving_slash"), 1, "équipement sur le 2e emplacement")
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
			var icon: Texture2D = HunterTreeSkin.icon(data)
			check(icon != null, "illustration du nœud : %s" % data.id)
			if icon:
				check(icon.get_width() >= 512 and icon.get_height() >= 512, "illustration HD : %s" % data.id)
	check_eq(count, 24, "12 sorts, 8 transformants et 4 clés de voûte")


func test_each_path_fits_without_scrolling() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	host.add_child(viewport)
	var screen: Refuge = load(Router.REFUGE).instantiate()
	viewport.add_child(screen)
	screen.tabs.current_tab = 2
	var tab: RefugeTab = screen.tabs.get_child(2)
	for branch: StringName in HunterTreeSkin.PATHS:
		tab._focused_branch = branch
		screen.refresh_current()
		await _settle()
		check(tab.find_child("TreeScroll", true, false) == null, "aucun défilement dans l'arbre : %s" % branch)
		var plan: HunterTreeBoard = tab.find_child("TreeBoard", true, false)
		for data: SkillNodeData in HunterTree.nodes_of_branch(branch):
			var button: HunterTreeNode = plan._buttons[data.id]
			check(not button.caption.text.is_empty(), "nom sous l'icône : %s" % data.id)
			# Police factice en mode sans affichage : la géométrie se vérifie avec le moteur graphique réel.
			if DisplayServer.get_name() != "headless":
				check(button.emblem_rect().size.x >= 40, "icône lisible : %s" % data.id)
				check(plan.get_global_rect().encloses(button.get_global_rect()), "nœud visible : %s" % data.id)
		check(tab.get_combined_minimum_size().x <= tab.size.x, "voie sans débordement horizontal")
		if DisplayServer.get_name() != "headless":
			check(tab.get_combined_minimum_size().y <= tab.size.y, "voie sans débordement vertical")
			check(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(tab.get_global_rect()), "voie dans la fenêtre")
	screen.queue_free()
	viewport.queue_free()
	await _settle()


func test_guide_opens_on_first_visit_and_is_remembered() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	host.add_child(viewport)
	var screen: Refuge = load(Router.REFUGE).instantiate()
	viewport.add_child(screen)
	screen.tabs.current_tab = 2
	var tab: RefugeTab = screen.tabs.get_child(2)
	var guide: TreeGuide = tab.find_child("TreeGuide", false, false)
	check(guide != null, "guide ouvert à la première visite")
	(guide.find_child("GuideNext", true, false) as Button).pressed.emit()
	check_eq(guide.page, 1, "page suivante")
	(guide.find_child("GuidePrev", true, false) as Button).pressed.emit()
	check_eq(guide.page, 0, "page précédente")
	for page: int in TreeGuide.PAGES:
		guide.open(page)
		check(guide.find_child("GuideArt", true, false) != null, "illustration de la page %d" % (page + 1))
	(guide.find_child("GuideNext", true, false) as Button).pressed.emit()
	check(tab.find_child("TreeGuide", false, false) == null, "guide fermé à la dernière page")
	check_eq(Profile.profile.preference("tree_guide_seen", ""), "1", "guide marqué comme vu dans le profil")
	screen.refresh_current()
	check(tab.find_child("TreeGuide", false, false) == null, "le guide ne revient pas tout seul")
	(tab.find_child("GuideButton", true, false) as Button).pressed.emit()
	check(tab.find_child("TreeGuide", false, false) != null, "bouton Guide : le guide revient")
	screen.queue_free()
	viewport.queue_free()
	await _settle()


func test_card_walks_through_learn_activate_equip() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	host.add_child(viewport)
	Profile.profile.set_preference("tree_guide_seen", "1")
	Profile.profile.data["runs"]["won"] = 1
	var screen: Refuge = load(Router.REFUGE).instantiate()
	viewport.add_child(screen)
	screen.tabs.current_tab = 2
	var tab: RefugeTab = screen.tabs.get_child(2)
	var leap: SkillNodeData = GameDB.skill_node(&"blade_rift_leap")
	var p: ProfileData = Profile.profile
	var states: Callable = func() -> Array:
		return tab.steps_of(p, leap).map(func(step: Dictionary) -> String: return step["state"])
	check_eq(states.call(), ["next", "todo", "todo"], "à apprendre : la première étape est la suivante")
	tab._select(leap.id)
	check_eq(_first_action(tab), "LearnNode", "action conseillée : apprendre")
	(tab.find_child("LearnNode", true, false) as Button).pressed.emit()
	check_eq(states.call(), ["done", "next", "todo"], "appris : activer ensuite")
	check_eq(_first_action(tab), "ActivateNode", "action conseillée : activer")
	# Sorts de départ actifs (4 points sur 6) : le Bond (2 points) s'active ; les deux emplacements ouverts sont pris.
	(tab.find_child("ActivateNode", true, false) as Button).pressed.emit()
	check_eq(states.call(), ["done", "done", "next"], "actif : reste à l'équiper")
	check(tab.find_child("EquipNode", true, false) == null, "aucun emplacement libre : pas de bouton Équiper")
	(tab.find_child("SpellSlot1", true, false) as Button).pressed.emit()
	check_eq(HunterTree.slot_of(p, &"rift_leap"), 1, "équipé en cliquant l'emplacement")
	check_eq(states.call(), ["done", "done", "done"], "actif et équipé")
	var parry: SkillNodeData = GameDB.skill_node(&"blade_parry")
	var first: Dictionary = tab.steps_of(p, parry)[0]
	check_eq(first["state"], "blocked", "Parade scellée tant que 3 boss ne sont pas vaincus")
	check(str(first["detail"]).contains("3"), "la fiche dit combien de boss vaincre")
	screen.queue_free()
	viewport.queue_free()
	await _settle()


func test_board_places_variants_under_their_spell() -> void:
	for branch: StringName in HunterTreeSkin.PATHS:
		var cells: Dictionary = {}
		for data: SkillNodeData in HunterTree.nodes_of_branch(branch):
			var cell: Vector2i = HunterTreeBoard.slot_of(data)
			if data.kind == SkillNodeData.Kind.VARIANT:
				var spell: SkillNodeData = HunterTree.spell_node(data.spell_id)
				check_eq(cell, HunterTreeBoard.slot_of(spell) + Vector2i(0, 1), "%s sous son sort" % data.id)
			elif data.kind in [SkillNodeData.Kind.SPELL, SkillNodeData.Kind.KEYSTONE, SkillNodeData.Kind.TRANSFORM]:
				check(not cells.has(cell), "%s : une case par sort, talent ou clé" % data.id)
				cells[cell] = data.id
	var board := HunterTreeBoard.new()
	board.focus_branch = &"blade"
	board.setup(Profile.profile, &"")
	check(board.find_child("BoardLegend", true, false) != null, "légende des états sur le plateau")
	check_eq(board.column_gate(3), 1, "2e sort : 1 boss à vaincre")
	check_eq(board.column_gate(4), 3, "3e sort : 3 boss")
	var whirlwind: HunterTreeNode = board._buttons[&"blade_slash_whirlwind"]
	check(whirlwind.tag == "", "variante scellée : pas de coût affiché")
	var honed: HunterTreeNode = board._buttons[&"blade_honed_edge"]
	check(honed.tag.contains("40"), "passif à apprendre : coût en Éclats sur le nœud")
	board.free()


func _first_action(tab: RefugeTab) -> String:
	var card: Node = tab.find_child("TreeDetail", true, false)
	var buttons: Array[Node] = card.find_children("*Node", "Button", true, false)
	return buttons[0].name if not buttons.is_empty() else ""


func test_node_tooltip_and_compact_card() -> void:
	var node := HunterTreeNode.new()
	node.setup(Profile.profile, GameDB.skill_node(&"blade_cleaving_slash"), &"")
	var tip: Control = node._make_custom_tooltip(node.tooltip_text)
	check(tip != null and tip.find_children("*", "RichTextLabel", true, false).size() == 1, "infobulle compacte au survol")
	tip.free()
	node.free()
	check(SkillCard.highlight("+8 % et 3 s").contains("[color="), "chiffres clés mis en couleur")
	check(SkillCard.highlight("[b]").begins_with("[lb]"), "texte traduit échappé du BBCode")
