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
	check_eq(_screen.tabs.current_tab, 1, "Page suivante : onglet suivant")
	key.keycode = KEY_PAGEUP
	_screen._unhandled_input(key)
	_screen._unhandled_input(key)
	check_eq(_screen.tabs.current_tab, _screen.tabs.get_tab_count() - 1, "Page précédente : boucle sur le dernier")
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
	var owned_after_locked := false
	var seen_locked := false
	for tile: Node in tab.find_children("*", "Button", true, false):
		var labels: Array[Node] = tile.find_children("*", "Label", true, false)
		for label: Node in labels:
			var text: String = (label as Label).text
			if text.begins_with(tr("EXPEDITION_ECHO_AT_MAP").to_upper().get_slice("%", 0)):
				seen_locked = true
				numbers.append(int(text.get_slice(" ", text.get_slice_count(" ") - 1)))
			elif seen_locked and text == tr("MONSTER_ASHBLADE_NAME"):
				owned_after_locked = true
	check(not numbers.is_empty(), "Échos à gagner : la carte qui les donne")
	check(not owned_after_locked, "Échos débloqués avant ceux à gagner")
	var sorted: Array[int] = numbers.duplicate()
	sorted.sort()
	check_eq(numbers, sorted, "Échos à gagner dans l'ordre des cartes")


func test_objectives_show_progress_bars() -> void:
	_screen.tabs.current_tab = 6
	await _settle()
	var tab: RefugeTab = _screen.tabs.get_child(6)
	check(not tab.find_children("ObjectiveBar", "ProgressBar", true, false).is_empty(), "barres de progression")
