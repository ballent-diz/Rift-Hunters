extends TestCase
## Mini-carte et grande carte : fond, cadrage, repères d'objectif, nuit et touche de la carte.

var run: RunController
var _saved_size: int


func before_each() -> void:
	_saved_size = Settings.minimap_size
	Settings.minimap_size = 2


func after_each() -> void:
	Settings.minimap_size = _saved_size
	if run:
		RunFixture.dispose(run)
		run = null


func _start(arena_id: StringName, features: Array[String] = []) -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = arena_id
	setup.starter_id = &"mossback"
	setup.autopilot = true
	setup.arena_override = TestArena.build(arena_id, &"", features)
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_every_drawn_map_has_a_minimap_background() -> void:
	for arena_id: StringName in GameDB.sorted_ids(GameDB.arenas):
		var env_id: StringName = GameDB.arena(arena_id).environment_id
		var path: String = str(Assets.entry(env_id).get("minimap", ""))
		check(path != "" and ResourceLoader.exists(path), "%s : fond de mini-carte présent" % arena_id)


func test_view_follows_the_hunter_inside_the_arena() -> void:
	var ctx: RunContext = _start(&"storm_highlands")
	var minimap: Minimap = run.hud.minimap
	check(minimap.texture != null, "fond chargé")
	var frame: Rect2 = minimap.frame_rect()
	check(frame.size.x > 0.0, "mini-carte affichée")
	ctx.player.global_position = Vector2.ZERO
	var view: Rect2 = minimap.view_rect(frame)
	check(view.size.x < ctx.arena_rect().size.x, "grande carte : vue partielle")
	check(view.has_point(Vector2.ZERO), "le Chasseur est dans la vue")
	ctx.player.global_position = ctx.arena_rect().end - Vector2(10, 10)
	view = minimap.view_rect(frame)
	check(ctx.arena_rect().encloses(view), "la vue ne sort pas de l'arène")
	Settings.minimap_size = 0
	check_eq(minimap.frame_rect().size, Vector2.ZERO, "mini-carte masquée par l'option")


func test_objectives_follow_the_mode() -> void:
	var ctx: RunContext = _start(&"storm_highlands")
	var rifts: Array[Vector2] = run.hud.minimap.objectives()
	check_eq(rifts.size(), ctx.rifts.open_rifts().size(), "une marque par faille ouverte")
	RunFixture.dispose(run)
	ctx = _start(&"fractured_plain", ["altar"])
	check(run.hud.minimap.objectives().has(ctx.altar.position), "l'autel est marqué")


func test_toggle_key_opens_the_full_map() -> void:
	_start(&"three_rifts")
	var minimap: Minimap = run.hud.minimap
	check(InputMap.has_action(&"toggle_map"), "action de la carte créée")
	check(not minimap.expanded, "fermée au départ")
	var press := InputEventAction.new()
	press.action = &"toggle_map"
	press.pressed = true
	minimap._unhandled_input(press)
	check(minimap.expanded, "la touche ouvre la grande carte")
	minimap._unhandled_input(press)
	check(not minimap.expanded, "et la referme")
