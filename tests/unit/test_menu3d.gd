extends TestCase
## Menu principal de la version 3D (draft3d/menu.gd) : scène de démarrage, navigation au clavier et à la manette,
## options, lancement de la partie, pause et retour au menu depuis la partie, noms des chapitres en FR et en EN.

var menu: DraftMenu
var run: DraftRun
var _locale: String
var _launched: Array[String] = []


func before_each() -> void:
	_locale = Settings.locale
	_launched.clear()


func after_each() -> void:
	host.get_tree().paused = false
	if menu != null:
		menu.free()
		menu = null
	if run != null:
		run.queue_free()
		run = null
	Settings.set_locale(_locale)


func _open_menu() -> void:
	menu = (load(DraftMenu.SCENE) as PackedScene).instantiate()
	menu.launcher = func(path: String) -> void: _launched.append(path)
	host.add_child(menu)
	await host.get_tree().process_frame
	await host.get_tree().process_frame


func _press(action: StringName) -> void:
	# Appui puis relâchement : les boutons s'activent au relâchement (comme au clavier et à la manette).
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		host.get_viewport().push_input(event)
		await host.get_tree().process_frame


func test_menu_is_the_startup_scene() -> void:
	check_eq(ProjectSettings.get_setting("application/run/main_scene"), DraftMenu.SCENE, "le menu démarre le jeu")


func test_keyboard_and_gamepad_navigation() -> void:
	await _open_menu()
	check_eq(menu.buttons.size(), 3, "Jouer, Options, Quitter")
	check(menu.buttons[0].has_focus(), "Jouer a le focus à l'ouverture (manette utilisable tout de suite)")
	await _press(&"ui_down")
	check(menu.buttons[1].has_focus(), "bas : Options")
	await _press(&"ui_down")
	await _press(&"ui_down")
	check(menu.buttons[0].has_focus(), "la liste boucle")
	await _press(&"ui_up")
	check(menu.buttons[2].has_focus(), "haut depuis Jouer : Quitter")


func test_play_launches_the_run_on_chapter_choice() -> void:
	await _open_menu()
	DraftRun.chosen_chapter = 3
	menu.buttons[0].grab_focus()
	await _press(&"ui_accept")
	check_eq(_launched, [DraftMenu.RUN_SCENE] as Array[String], "Jouer ouvre la partie 3D")
	check_eq(DraftRun.chosen_chapter, 0, "le choix du chapitre s'affiche")


func test_options_open_close_and_switch_language() -> void:
	Settings.set_locale("fr")
	await _open_menu()
	menu.buttons[1].pressed.emit()
	await host.get_tree().process_frame
	check(menu.options_panel != null, "les options s'ouvrent")
	for id: String in ["Language", "Master", "Music", "Sfx", "Fullscreen", "Vsync", "Close"]:
		check(menu.options_panel.find_child(id, true, false) != null, "option présente : %s" % id)
	check_eq(menu.buttons[0].text, "Jouer")
	var language: Button = menu.options_panel.find_child("Language", true, false)
	language.pressed.emit()
	await host.get_tree().process_frame
	check_eq(Settings.locale, "en", "langue suivante")
	check_eq(menu.buttons[0].text, "Play", "menu retraduit")
	check(menu.options_panel != null, "les options restent ouvertes après le changement de langue")
	await host.get_tree().process_frame
	await _press(&"ui_cancel")
	await host.get_tree().process_frame
	check(menu.options_panel == null, "Échap / B ferme les options")


func test_pause_and_return_to_menu_from_the_run() -> void:
	run = (load(DraftMenu.RUN_SCENE) as PackedScene).instantiate()
	run.leave = func(path: String) -> void: _launched.append(path)
	host.add_child(run)
	for frame: int in 600:
		if run.state == DraftRun.State.PLAYING:
			break
		await host.get_tree().physics_frame
	run.boss_time = INF
	run.toggle_pause()
	check(host.get_tree().paused and run.hud.pause_open(), "Échap met en pause")
	for id: String in ["Resume", "Options", "Restart", "Menu", "Quit"]:
		check(run.hud.find_child(id, true, false) != null, "bouton de pause : %s" % id)
	run.toggle_pause()
	check(not host.get_tree().paused and not run.hud.pause_open(), "reprise")
	run.toggle_pause()
	run.hud.menu_requested.emit()
	check_eq(_launched, [DraftMenu.SCENE] as Array[String], "retour au menu depuis la pause")
	check(not host.get_tree().paused, "le menu ne reste pas en pause")
	run._finish(false)
	check(run.hud.end_open() and run.hud.find_child("Menu", true, false) != null, "menu depuis la fin de partie")
	run.toggle_pause()
	check(not run.hud.pause_open(), "pas de pause après la fin")


func test_v2_chapter_names_are_translated_and_new() -> void:
	var fr: Translation = TranslationServer.get_translation_object("fr")
	var en: Translation = TranslationServer.get_translation_object("en")
	var names: Dictionary = {}
	for data: ChapterData in DraftRoster.chapters():
		for key: String in [DraftRoster.name_key(data), DraftRoster.desc_key(data)]:
			check(String(fr.get_message(key)) not in ["", key], "%s : français" % key)
			check(String(en.get_message(key)) not in ["", key], "%s : anglais" % key)
		var v2: String = String(fr.get_message(DraftRoster.name_key(data)))
		check(v2 != String(fr.get_message(data.name_key)), "%s : nom propre à la version 3D" % data.id)
		check(not names.has(v2), "%s : nom unique" % data.id)
		names[v2] = true
	check_eq(names.size(), 5, "cinq chapitres nommés")
