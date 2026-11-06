extends TestCase
## Mise en page des écrans construits DANS l'arbre de scène, comme en jeu (Router change de scène) :
## les écrans plein écran doivent couvrir tout l'écran, jamais 0×0 (fenêtres réduites en haut à gauche).


func test_run_ui_fills_screen_when_built_in_tree() -> void:
	var previous: RunSetup = Router.pending_setup
	var setup: RunSetup = Profile.make_run_setup(&"mossback")
	setup.autopilot = true
	setup.run_seed = 7
	Router.pending_setup = setup
	var run: RunController = load(Router.RUN).instantiate()
	run.skip_profile = true
	host.add_child(run)  # _ready → start() dans l'arbre, comme après Router.start_run
	run.set_physics_process(false)
	var screen: Vector2 = run.hud.get_parent().size
	check(screen.x > 100.0 and screen.y > 100.0, "interface de partie à la taille de l'écran (%s)" % screen)
	for panel: Control in [run.hud, run.level_up_panel, run.chest_panel, run.pause_panel, run.results_panel]:
		check(panel.size.is_equal_approx(screen), "%s couvre l'écran (%s)" % [panel.get_class(), panel.size])
	Router.pending_setup = previous
	RunFixture.dispose(run)


func test_menus_fill_screen_when_built_in_tree() -> void:
	for path: String in [Router.MAIN_MENU, Router.REFUGE]:
		var screen: Control = (load(path) as PackedScene).instantiate()
		host.add_child(screen)
		var expected: Vector2 = host.get_viewport().get_visible_rect().size
		check(screen.size.is_equal_approx(expected), "%s couvre l'écran (%s / %s)" % [path, screen.size, expected])
		screen.queue_free()


## Retour de test : la fenêtre tient dans l'écran utilisable et y est centrée (petit écran, mise à l'échelle Windows).
func test_window_fits_and_is_centered_on_small_screens() -> void:
	var laptop := Rect2i(0, 0, 1366, 728)
	var rect: Rect2i = Settings.fitted_window(laptop, Vector2i(1600, 900))
	check(laptop.encloses(rect), "fenêtre entièrement dans l'écran : %s" % rect)
	check(absi(rect.get_center().x - laptop.get_center().x) <= 1 and absi(rect.get_center().y - laptop.get_center().y) <= 1,
		"fenêtre centrée")
	check(absf(float(rect.size.x) / rect.size.y - 16.0 / 9.0) < 0.02, "rapport 16:9 gardé")
	var scaled := Rect2i(0, 0, 1280, 680)
	check(scaled.encloses(Settings.fitted_window(scaled, Vector2i(1600, 900))), "écran mis à l'échelle 150 % : tient")
	var big := Rect2i(0, 0, 2560, 1400)
	check_eq(Settings.fitted_window(big, Vector2i(1600, 900)).size, Vector2i(1600, 900), "grand écran : taille d'origine")


## L'écran titre ne laisse pas de bandes noires sur un écran d'un autre format (fond recadré derrière l'image).
func test_main_menu_backdrop_covers_the_screen() -> void:
	var menu: Control = load(Router.MAIN_MENU).instantiate()
	host.add_child(menu)
	var backdrop: TextureRect = menu.get_node("Backdrop")
	check(backdrop != null and backdrop.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "fond recadré qui couvre")
	menu.queue_free()
