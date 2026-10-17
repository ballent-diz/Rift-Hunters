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
