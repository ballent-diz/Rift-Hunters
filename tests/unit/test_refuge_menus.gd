extends TestCase
## Menus du refuge repensés : onglet Échos (arbre + fiche) et onglet Expédition (chapitres, résumé, départ),
## pilotés par leurs vrais boutons.

var _previous: ProfileData
var _previous_path: String
var _viewport: SubViewport
var _screen: Refuge


func before_each() -> void:
	_previous = Profile.profile
	_previous_path = Profile.path
	Profile.profile = ProfileData.new()
	Profile.path = "user://test_refuge_menus.json"
	Profile.profile.add_currency("shards", 5000)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	host.add_child(_viewport)
	_screen = load(Router.REFUGE).instantiate()
	_viewport.add_child(_screen)


func after_each() -> void:
	_screen.free()
	_viewport.queue_free()
	Profile.profile = _previous
	Profile.path = _previous_path
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://test_refuge_menus.json" + suffix)


func _settle() -> void:
	for frame: int in 3:
		await host.get_tree().process_frame


func test_echo_tab_learn_activate_and_equip() -> void:
	# Maîtrise 1 : le second sort s'ouvre (arbres des Échos v2).
	Profile.profile.mastery_entry(&"mossback")["xp"] = 20
	_screen.tabs.current_tab = 3
	await _settle()
	var tab: RefugeTab = _screen.tabs.get_child(3)
	(tab.find_child("Echo_mossback", true, false) as Button).pressed.emit()
	var might: Button = tab.find_child("mossback_might", true, false)
	check(might != null, "nœud Puissance affiché")
	might.pressed.emit()
	check(tab.find_child("EchoDetail", true, false) != null, "fiche de la compétence")
	(tab.find_child("LearnNode", true, false) as Button).pressed.emit()
	var node: SkillNodeData = EchoTree.node(&"mossback_might")
	check_eq(EchoTree.learned_rank(Profile.profile, node), 1, "apprentissage via la fiche")
	(tab.find_child("ActivateNode", true, false) as Button).pressed.emit()
	check_eq(EchoTree.active_rank(Profile.profile, node), 1, "activation via la fiche")
	(tab.find_child("mossback_spell_alt", true, false) as Button).pressed.emit()
	(tab.find_child("LearnNode", true, false) as Button).pressed.emit()
	(tab.find_child("ActivateNode", true, false) as Button).pressed.emit()
	check(EchoTree.chosen_technique(Profile.profile, &"mossback") != null, "second sort équipé")
	var board: EchoTreeBoard = tab.find_child("EchoBoard", true, false)
	check_eq(board._buttons.size(), 5, "cinq nœuds dans l'arbre de l'Écho")
	check(tab.find_child("TreeGuide", false, false) != null, "guide des Échos à la première visite")
	check(tab.find_child("MasteryChip", true, false) != null, "maîtrise affichée")


func test_expedition_tab_chapters_summary_and_departure() -> void:
	_screen.tabs.current_tab = 0
	await _settle()
	var tab: RefugeTab = _screen.tabs.get_child(0)
	var first: Button = tab.find_child("Map_three_rifts", true, false)
	var second: Button = tab.find_child("Map_storm_highlands", true, false)
	check(first != null and not first.disabled, "première carte jouable")
	check(second != null and second.disabled, "carte suivante verrouillée")
	check(tab.find_child("Map_fractured_plain", true, false) == null, "épreuves de survie cachées en mode Campagne")
	var nightmare: Button = tab.find_child("Difficulty_nightmare", true, false)
	check(nightmare.disabled, "Cauchemar verrouillé tant que la campagne n'est pas finie")
	(tab.find_child("Mode_survival", true, false) as Button).pressed.emit()
	await _settle()
	tab = _screen.tabs.get_child(0)
	check(tab.find_child("Map_three_rifts", true, false) == null, "mode Survie : la campagne principale est cachée")
	var trial: Button = tab.find_child("Map_survival_ruins", true, false)
	check(trial != null and trial.disabled, "deuxième épreuve verrouillée")
	var bonus: Button = tab.find_child("Map_endless_rift", true, false)
	check(bonus != null and bonus.disabled, "Faille sans fin verrouillée")
	(tab.find_child("Map_fractured_plain", true, false) as Button).pressed.emit()
	check_eq(Profile.profile.preference("arena", ""), "fractured_plain", "carte choisie")
	check(tab.find_child("DepartButton", true, false) != null, "départ toujours présent")
	if DisplayServer.get_name() != "headless":
		await _settle()
		var go: Control = tab.find_child("DepartButton", true, false)
		check(Rect2(Vector2.ZERO, Vector2(_viewport.size)).encloses(go.get_global_rect()), "départ visible sans défiler")


func test_echo_node_illustrations_are_hd_with_mipmaps() -> void:
	check_eq(GameDB.echo_nodes.size(), GameDB.monsters.size() * 5, "chaque Écho avec cinq illustrations")
	for n: SkillNodeData in GameDB.echo_nodes.values():
		var icon: Texture2D = EchoTreeBoard.node_icon(n)
		check(icon != null, "illustration du nœud : " + String(n.id))
		if icon:
			check_eq(icon.get_size(), Vector2(512, 512), "format HD : " + String(n.id))
			var settings := ConfigFile.new()
			check_eq(settings.load(icon.resource_path + ".import"), OK, "configuration d’import présente")
			check(settings.get_value("params", "mipmaps/generate", false), "mipmaps : " + String(n.id))


func test_expedition_art_keeps_departure_visible_in_both_languages() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	for locale: String in ["fr", "en"]:
		TranslationServer.set_locale(locale)
		for test_mode: bool in [false, true]:
			Profile.profile = ProfileData.new()
			if test_mode:
				HunterTree.unlock_all_for_testing(Profile.profile)
				Profile.profile.set_preference("arena", "storm_highlands")
				Profile.profile.set_preference("difficulty", "nightmare")
			_screen.tabs.current_tab = 0
			_screen.refresh_current()
			await _settle()
			var tab: RefugeTab = _screen.tabs.get_child(0)
			var summary: Control = tab.find_child("ExpeditionSummary", true, false)
			var previews: Array[Node] = summary.find_children("MapPreview_*", "TextureRect", true, false)
			check_eq(previews.size(), 1, "un aperçu dans le résumé")
			check((previews[0] as TextureRect).texture != null, "décor de la carte sélectionnée chargé")
			if DisplayServer.get_name() != "headless":
				var bounds := Rect2(Vector2.ZERO, Vector2(_viewport.size))
				check(bounds.encloses(summary.get_global_rect()), "résumé dans la fenêtre : " + locale)
				var go: Control = tab.find_child("DepartButton", true, false)
				check(bounds.encloses(go.get_global_rect()), "départ visible : " + locale)
	TranslationServer.set_locale(previous_locale)


## Outil de développement (jeu lancé depuis Godot) : le bouton « Test dev » des Options débloque tout (arbre, Échos,
## cartes, Cauchemar).
func test_options_dev_button_unlocks_everything() -> void:
	if not OS.is_debug_build():
		return
	var options: RefugeTab = _screen.tabs.get_child(8)
	options.refresh()
	var button: Button = null
	for node: Node in options.find_children("*", "Button", true, false):
		if (node as Button).text == tr("OPTIONS_TEST_DEV"):
			button = node
	check(button != null, "bouton « Test dev » présent")
	if button == null:
		return
	button.pressed.emit()
	for id: StringName in GameDB.monsters:
		check(Profile.profile.is_monster_unlocked(GameDB.monsters[id]), "%s débloqué depuis les Options" % id)
	for id: StringName in GameDB.arenas:
		check(Profile.profile.is_arena_unlocked(GameDB.arenas[id]), "carte %s débloquée" % id)
	check(Campaign.is_nightmare_unlocked(Profile.profile), "Cauchemar ouvert")
	check(HunterTree.points_total(Profile.profile) >= 200, "arbre du Chasseur et points de test")
	var echoes: RefugeTab = _screen.tabs.get_child(3)
	echoes.refresh()
	var list: Array[Node] = echoes.find_children("Echo_sunclaw", "Button", true, false)
	check(not list.is_empty() and (list[0] as Button).tooltip_text != tr("ECHO_TREE_LOCKED"),
		"Solgriffe n'est plus verrouillé dans l'onglet Échos")


## Un clic qui reconstruit l'onglet (choisir un Écho, apprendre un nœud) ne fait pas remonter la liste.
func test_clicks_keep_the_scroll_position() -> void:
	_screen.tabs.current_tab = 3
	await _settle()
	var tab: RefugeTab = _screen.tabs.get_child(3)
	# Un Écho déjà choisi : la mise en page ne change plus de hauteur d'un clic à l'autre.
	(tab.find_child("Echo_glowmoth", true, false) as Button).pressed.emit()
	await _settle()
	var list: ScrollContainer = tab.find_children("*", "ScrollContainer", true, false)[0]
	list.scroll_vertical = 10000
	await _settle()
	var scrolled: int = list.scroll_vertical
	check(scrolled > 0, "la liste des 16 Échos défile")
	(tab.find_child("Echo_stormshell", true, false) as Button).pressed.emit()
	await _settle()
	list = tab.find_children("*", "ScrollContainer", true, false)[0]
	check_eq(list.scroll_vertical, _kept(list, scrolled), "choisir un Écho garde la position de la liste")
	(tab.find_child("stormshell_might", true, false) as Button).pressed.emit()
	await _settle()
	(tab.find_child("LearnNode", true, false) as Button).pressed.emit()
	await _settle()
	list = tab.find_children("*", "ScrollContainer", true, false)[0]
	check_eq(list.scroll_vertical, _kept(list, scrolled), "apprendre un nœud (sauvegarde) garde la position de la liste")


## Position attendue après reconstruction : l'ancienne, ou le bas de la liste si la nouvelle mise en page est plus
## courte ; jamais le haut.
func _kept(list: ScrollContainer, previous: int) -> int:
	var bar: VScrollBar = list.get_v_scroll_bar()
	var expected: int = mini(previous, int(bar.max_value - bar.page))
	check(expected > 0, "la liste reste défilée")
	return expected


func test_maximized_window_counts_as_windowed() -> void:
	check(not Settings.is_fullscreen_mode(DisplayServer.WINDOW_MODE_MAXIMIZED),
		"fenêtre agrandie : mode fenêtré, aucun redimensionnement forcé")
	check(not Settings.is_fullscreen_mode(DisplayServer.WINDOW_MODE_MINIMIZED), "fenêtre réduite : mode fenêtré")
	check(Settings.is_fullscreen_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN), "plein écran exclusif")


func test_tabs_switch_from_the_keyboard_and_show_what_needs_attention() -> void:
	_screen.tabs.current_tab = 0
	var key := InputEventKey.new()
	key.keycode = KEY_PAGEDOWN
	key.pressed = true
	_screen._unhandled_input(key)
	var order: Array[int] = _screen.visible_order()
	check_eq(_screen.tabs.current_tab, order[1], "Page suivante : onglet suivant de la navigation")
	key.keycode = KEY_PAGEUP
	_screen._unhandled_input(key)
	_screen._unhandled_input(key)
	check_eq(_screen.tabs.current_tab, order[-1], "Page précédente : boucle sur le dernier")
	check_eq(_screen.group_of(order[1]), 1, "après l'Expédition vient le groupe Progression")
	# 5000 Éclats : des nœuds du Chasseur à apprendre.
	_screen.refresh_all()
	check(_screen.tabs.get_tab_title(2).ends_with("●"), "repère sur l'arbre du Chasseur")
	Profile.profile.add_currency("shards", -Profile.profile.shards())
	HunterTree.deactivate(Profile.profile, GameDB.skill_node(&"blade_cleaving_slash"))
	HunterTree.deactivate(Profile.profile, GameDB.skill_node(&"prism_prismatic_lance"))
	_screen.refresh_all()
	check(_screen.tabs.get_tab_title(2).ends_with("●"), "sorts de départ à réactiver : repère")
	HunterTree.activate(Profile.profile, GameDB.skill_node(&"blade_cleaving_slash"))
	HunterTree.activate(Profile.profile, GameDB.skill_node(&"prism_prismatic_lance"))
	_screen.refresh_all()
	check(not _screen.tabs.get_tab_title(2).ends_with("●"), "rien à faire sans Éclats ni points : pas de repère")


func test_expedition_lists_owned_echoes_first_with_the_map_of_the_others() -> void:
	_screen.tabs.current_tab = 0
	await _settle()
	var tab: RefugeTab = _screen.tabs.get_child(0)
	var numbers: Array[int] = []
	var hidden: Node = tab.find_child("EchoesToFind", true, false)
	check(hidden != null, "rangée des Échos à découvrir")
	for tile: Node in hidden.find_children("*", "Button", true, false):
		check((tile as Button).tooltip_text.begins_with(tr("EXPEDITION_ECHO_AT_MAP").get_slice("%", 0)) \
			or (tile as Button).tooltip_text.begins_with(tr("EXPEDITION_ECHO_LATER")), "infobulle : la carte qui le donne")
		var text: String = (tile.find_children("*", "Label", true, false)[0] as Label).text
		var where: String = (tile as Button).tooltip_text.get_slice("\n", 0)
		if where.get_slice(" ", where.get_slice_count(" ") - 1).is_valid_int():
			numbers.append(int(where.get_slice(" ", where.get_slice_count(" ") - 1)))
		check(text != tr("MONSTER_ASHBLADE_NAME"), "Échos débloqués hors de la rangée à découvrir")
	check(not numbers.is_empty(), "Échos à gagner : la carte qui les donne")
	var sorted: Array[int] = numbers.duplicate()
	sorted.sort()
	check_eq(numbers, sorted, "Échos à gagner dans l'ordre des cartes")


func test_objectives_show_progress_bars() -> void:
	_screen.tabs.current_tab = 6
	await _settle()
	var tab: RefugeTab = _screen.tabs.get_child(6)
	check(not tab.find_children("ObjectiveBar", "ProgressBar", true, false).is_empty(), "barres de progression")


func test_refuge_groups_reveal_tabs_as_the_player_progresses() -> void:
	Profile.profile.data["runs"]["played"] = 0
	Profile.profile.add_currency("essence", -Profile.profile.essence())
	(Profile.profile.data["research"] as Array).clear()
	(Profile.profile.data.get_or_add("journal", []) as Array).clear()
	_screen.refresh_all()
	var shop: int = _screen.tab_index("shop_tab")
	check(not _screen.visible_order().has(shop), "pas encore de Boutique avant la première expédition")
	check(not _screen.visible_order().has(_screen.tab_index("journal_tab")), "Journal vide : onglet caché")
	check_eq(str(_screen.next_step()["tab"]), "expedition_tab", "premier pas : partir en expédition")
	Profile.profile.data["runs"]["played"] = 1
	Profile.profile.add_currency("essence", 5)
	_screen.refresh_all()
	check(_screen.visible_order().has(shop), "Boutique ouverte après un retour")
	check(_screen.visible_order().has(_screen.tab_index("lab_tab")), "Laboratoire ouvert avec de l'Essence")
	_screen.select_tab(shop)
	check_eq(_screen.tabs.current_tab, shop, "un onglet ouvert se sélectionne")
	var subtabs: Control = _screen.find_child("SubTabs", true, false)
	check(subtabs.visible, "groupe Marché : rangée des sous-onglets visible")
	Profile.profile.data["runs"]["played"] = Refuge.GUIDE_RUNS
	_screen.refresh_all()
	check(_screen.next_step().is_empty(), "le guide s'efface après les premières parties")


func test_shop_bestiary_and_lab_are_visual() -> void:
	Profile.profile.data["runs"]["played"] = 1
	Profile.profile.add_currency("shards", -Profile.profile.shards())
	Profile.profile.add_currency("essence", 2)
	_screen.refresh_all()
	_screen.select_tab(_screen.tab_index("shop_tab"))
	await _settle()
	var shop: RefugeTab = _screen.tabs.get_child(_screen.tab_index("shop_tab"))
	check(shop.find_child("ItemArt", true, false) != null, "Boutique : objets illustrés")
	check(shop.find_child("Missing", true, false) != null, "Boutique : « il manque » quand c'est trop cher")
	_screen.select_tab(_screen.tab_index("bestiary_tab"))
	await _settle()
	var bestiary: RefugeTab = _screen.tabs.get_child(_screen.tab_index("bestiary_tab"))
	check(bestiary.find_child("Echo_ashblade", true, false) != null, "Bestiaire : vignettes d'Échos")
	bestiary._show("monster:ashblade")
	check(bestiary.find_child("StatChips", true, false).get_child_count() >= 3, "Bestiaire : chiffres en pastilles")
	check(bestiary.find_child("MasteryBar", true, false).get_child_count() == 2, "Bestiaire : barre de maîtrise")
	(bestiary.find_child("Section_enemies", true, false) as Button).pressed.emit()
	check(bestiary.find_child("Echo_ashblade", true, false) == null, "rubrique Corrompus : plus de vignettes d'Échos")
	_screen.select_tab(_screen.tab_index("lab_tab"))
	await _settle()
	var lab: RefugeTab = _screen.tabs.get_child(_screen.tab_index("lab_tab"))
	var branch: Node = lab.find_child("Branch_corrupted_study", true, false)
	check(branch != null and branch.find_child("Research_elite_dossier", true, false) != null,
		"Laboratoire : les suites d'une recherche sur sa branche")


func test_main_menu_continue_options_and_key_guide() -> void:
	var menu: Control = load(Router.MAIN_MENU).instantiate()
	_viewport.add_child(menu)
	await _settle()
	var play: Button = menu.find_child("Play", true, false)
	check_eq(play.text, tr("MENU_PLAY"), "premier lancement : entrer au refuge")
	Profile.profile.data["runs"]["played"] = 2
	Profile.save()
	await _settle()
	play = menu.find_child("Play", true, false)
	check_eq(play.text, tr("MENU_CONTINUE"), "joueur de retour : Continuer")
	(menu.find_child("Options", true, false) as Button).pressed.emit()
	await _settle()
	check(menu.find_child("OptionsWindow", true, false) != null, "Options : fenêtre ouverte depuis le menu")
	check(menu.find_child("ControlScheme", true, false) != null, "Options complètes (mode de contrôle)")
	Settings.apply()
	await _settle()
	check(menu.find_child("OptionsWindow", true, false) != null, "la fenêtre survit à un changement de réglage")
	menu.close_options()
	await _settle()
	check(menu.find_child("OptionsWindow", true, false) == null, "Fermer : retour au menu")
	menu.free()
	var guide: GridContainer = KeyGuide.build()
	check_eq(guide.get_child_count(), (KeyGuide.ROWS.size() + 1) * 3, "aide-mémoire : une ligne par action")
	check_eq(KeyGuide.pad_label(&"technique_1"), "X", "glyphe manette d'une technique")
	guide.free()
