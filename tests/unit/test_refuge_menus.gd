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
	_screen.tabs.current_tab = 2
	await _settle()
	var tab: RefugeTab = _screen.tabs.get_child(2)
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


func test_expedition_tab_chapters_summary_and_departure() -> void:
	_screen.tabs.current_tab = 0
	await _settle()
	var tab: RefugeTab = _screen.tabs.get_child(0)
	var first: Button = tab.find_child("Map_three_rifts", true, false)
	var second: Button = tab.find_child("Map_storm_highlands", true, false)
	check(first != null and not first.disabled, "première carte jouable")
	check(second != null and second.disabled, "carte suivante verrouillée")
	check(tab.find_child("Map_fractured_plain", true, false) != null, "Survie hors campagne proposée")
	var nightmare: Button = tab.find_child("Difficulty_nightmare", true, false)
	check(nightmare.disabled, "Cauchemar verrouillé tant que la campagne n'est pas finie")
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


## Outil de développement (jeu lancé depuis Godot) : le bouton des Options débloque tous les Échos.
func test_options_test_button_unlocks_every_echo() -> void:
	if not OS.is_debug_build():
		return
	var options: RefugeTab = _screen.tabs.get_child(7)
	options.refresh()
	var button: Button = null
	for node: Node in options.find_children("*", "Button", true, false):
		if (node as Button).text == tr("OPTIONS_TEST_ECHOES"):
			button = node
	check(button != null, "bouton « débloquer tous les Échos » présent")
	if button == null:
		return
	button.pressed.emit()
	for id: StringName in GameDB.monsters:
		check(Profile.profile.is_monster_unlocked(GameDB.monsters[id]), "%s débloqué depuis les Options" % id)
	var echoes: RefugeTab = _screen.tabs.get_child(2)
	echoes.refresh()
	var list: Array[Node] = echoes.find_children("Echo_sunclaw", "Button", true, false)
	check(not list.is_empty() and (list[0] as Button).tooltip_text != tr("ECHO_TREE_LOCKED"),
		"Solgriffe n'est plus verrouillé dans l'onglet Échos")
