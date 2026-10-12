class_name RunController
extends Node
## Racine d'une partie : construit le monde, orchestre la boucle (ordre fixe) et les écrans.

signal finished(result: Dictionary)

var ctx: RunContext
var spawner: SpawnDirector
var event_director: EventDirector
var boss_controller: BossController
var camera: Camera2D
var hud: Hud
var level_up_panel: LevelUpPanel
var chest_panel: ChestPanel
var pause_panel: PausePanel
var results_panel: ResultsPanel
var result: Dictionary = {}
var rewards: Dictionary = {}
## Tests : ne pas appliquer la progression au profil.
var skip_profile: bool = false
var _pending_chests: int = 0
var _victory_timer: float = -1.0
var _shake: float = 0.0
var _modal_open: bool = false


func _ready() -> void:
	if ctx == null:
		var setup: RunSetup = Router.pending_setup if Router.pending_setup else Profile.make_run_setup(&"")
		start(setup)


func start(setup: RunSetup) -> void:
	ctx = RunContext.new()
	ctx.setup = setup
	ctx.balance = GameDB.balance
	ctx.arena = GameDB.arena(setup.arena_id)
	ctx.difficulty = GameDB.difficulty(setup.difficulty_id)
	ctx.rng.seed = setup.run_seed if setup.run_seed != 0 else randi()
	ctx.root = self
	ctx.events = RunEvents.new()
	add_child(ctx.events)
	ctx.combat = CombatSystem.new()
	ctx.combat.setup(ctx)
	add_child(ctx.combat)
	ctx.status_system = StatusSystem.new(ctx)
	_build_world()
	_build_ui()
	for effect: GameplayEffect in setup.meta_effects:
		effect.install(ctx, &"")
	if setup.starter_id != &"":
		ctx.allies.add_monster(setup.starter_id, setup.starter_rank, setup.starter_variant)
	spawner = SpawnDirector.new(ctx)
	ctx.spawner = spawner
	event_director = EventDirector.new(ctx)
	ctx.events.boss_spawned.connect(func(boss: Enemy) -> void:
		boss_controller = BossController.new(ctx, boss)
		_shake = 0.6)
	ctx.events.boss_defeated.connect(_on_boss_defeated)
	ctx.events.chest_collected.connect(func() -> void: _pending_chests += 1)
	ctx.events.player_hurt.connect(func(_amount: float) -> void: _shake = maxf(_shake, 0.25))
	if ctx.player.stats.get_int(StatKeys.STARTING_RELIC_CHOICE) > 0:
		chest_panel.open.call_deferred(true)


func _build_world() -> void:
	ctx.world = Node2D.new()
	ctx.world.name = "World"
	add_child(ctx.world)
	var ground := ArenaGround.new()
	ground.setup(ctx.arena, ctx.rng.seed)
	ctx.world.add_child(ground)
	ctx.hazards = HazardManager.new()
	ctx.hazards.setup(ctx)
	ctx.world.add_child(ctx.hazards)
	ctx.pickups = PickupManager.new()
	ctx.pickups.setup(ctx)
	ctx.world.add_child(ctx.pickups)
	ctx.enemies = EnemyManager.new()
	ctx.enemies.z_index = 2
	ctx.enemies.setup(ctx)
	ctx.world.add_child(ctx.enemies)
	ctx.allies = AllyManager.new()
	ctx.allies.z_index = 3
	ctx.allies.setup(ctx)
	ctx.world.add_child(ctx.allies)
	ctx.player = Player.new()
	ctx.player.z_index = 4
	ctx.world.add_child(ctx.player)
	var brain: PlayerBrain = AutopilotBrain.new() if ctx.setup.autopilot else HumanBrain.new()
	ctx.player.setup(ctx, brain)
	ctx.projectiles = ProjectileManager.new()
	ctx.projectiles.setup(ctx)
	ctx.world.add_child(ctx.projectiles)
	ctx.fx = FxRenderer.new()
	ctx.fx.setup(ctx)
	ctx.world.add_child(ctx.fx)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2.ONE * ctx.balance.camera_zoom
	ctx.player.add_child(camera)
	camera.make_current.call_deferred()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	layer.add_child(root)
	hud = Hud.new()
	root.add_child(hud)
	hud.setup(ctx)
	level_up_panel = LevelUpPanel.new()
	root.add_child(level_up_panel)
	level_up_panel.setup(ctx)
	level_up_panel.closed.connect(func() -> void: _modal_open = false)
	chest_panel = ChestPanel.new()
	root.add_child(chest_panel)
	chest_panel.setup(ctx)
	chest_panel.closed.connect(func() -> void: _modal_open = false)
	pause_panel = PausePanel.new()
	root.add_child(pause_panel)
	pause_panel.setup(ctx)
	pause_panel.abandon_requested.connect(func() -> void:
		ctx.stats.add(&"abandoned")
		_finish(false))
	results_panel = ResultsPanel.new()
	root.add_child(results_panel)
	results_panel.setup()
	results_panel.refuge_requested.connect(func() -> void: Router.goto_refuge())
	results_panel.replay_requested.connect(func() -> void: Router.start_run(Profile.make_run_setup(ctx.setup.starter_id, ctx.setup)))


func _physics_process(delta: float) -> void:
	if ctx == null or ctx.finished:
		return
	ctx.time += delta
	spawner.step(delta)
	event_director.step(delta)
	ctx.player.step(delta)
	ctx.allies.step(delta)
	ctx.enemies.step(delta)
	if boss_controller:
		boss_controller.step(delta)
	ctx.projectiles.step(delta)
	ctx.pickups.step(delta)
	ctx.hazards.step(delta)
	ctx.combat.flush_queue()
	ctx.fx.step(delta)
	_update_camera(delta)
	if _victory_timer >= 0.0:
		_victory_timer -= delta
		if _victory_timer < 0.0:
			_finish(true)
		return
	if not ctx.player.alive:
		_finish(false)
		return
	_open_modals()


func _open_modals() -> void:
	if _modal_open or get_tree().paused:
		return
	if ctx.player.pending_levels > 0:
		_modal_open = true
		level_up_panel.open()
	elif _pending_chests > 0:
		_pending_chests -= 1
		_modal_open = true
		chest_panel.open()


func _update_camera(delta: float) -> void:
	_shake = maxf(_shake - delta, 0.0)
	if _shake > 0.0 and Settings.screen_shake:
		camera.offset = Vector2(ctx.rng.randf_range(-1, 1), ctx.rng.randf_range(-1, 1)) * 6.0 * _shake / 0.25
	else:
		camera.offset = Vector2.ZERO


func _on_boss_defeated(_boss: Enemy) -> void:
	_victory_timer = 2.5
	ctx.enemies.clear_all()
	ctx.projectiles.clear_hostile()
	ctx.hazards.clear_hostile()
	ctx.pickups.magnet_all()
	ctx.player.god_mode = true
	_shake = 0.8


func _finish(victory: bool) -> void:
	if ctx.finished:
		return
	ctx.finished = true
	ctx.victory = victory
	ctx.stats.set_value(&"time_survived", ctx.time)
	result = build_result()
	if not skip_profile:
		rewards = Profile.apply_run_result(result)
	else:
		rewards = RunRewards.compute(result, ctx.balance)
	ctx.events.run_finished.emit(victory)
	pause_panel.blocked = true
	level_up_panel.visible = false
	chest_panel.visible = false
	results_panel.show_result(result, rewards)
	get_tree().paused = true
	finished.emit(result)


func build_result() -> Dictionary:
	var team: Array[String] = []
	for id: StringName in ctx.allies.team_ids():
		team.append(String(id))
	var evolutions: Array[String] = []
	for id: StringName in ctx.build.evolutions:
		evolutions.append(String(ctx.build.evolutions[id]))
	var relics: Array[String] = []
	for id: StringName in ctx.build.relics:
		relics.append(String(id))
	var synergies: Array[String] = []
	for id: StringName in ctx.build.active_synergies:
		synergies.append(String(id))
	return {
		"victory": ctx.victory,
		"time": ctx.time,
		"level": ctx.player.level,
		"kills": int(ctx.stats.get_value(&"kills")),
		"arena": String(ctx.arena.id),
		"difficulty": String(ctx.difficulty.id),
		"difficulty_level": ctx.difficulty.level,
		"reward_mult": ctx.difficulty.reward_mult,
		"shard_gain": ctx.player.stats.get_value(StatKeys.SHARD_GAIN),
		"boss_shards": GameDB.boss(ctx.arena.boss_id).shard_reward if GameDB.boss(ctx.arena.boss_id) else 0,
		"boss_essence": GameDB.boss(ctx.arena.boss_id).essence_reward if GameDB.boss(ctx.arena.boss_id) else 0,
		"starter": String(ctx.setup.starter_id),
		"team": team,
		"evolutions": evolutions,
		"relics": relics,
		"synergies": synergies,
		"stats": ctx.stats.to_dict(),
	}
