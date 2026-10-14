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
