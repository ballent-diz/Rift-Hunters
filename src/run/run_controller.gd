class_name RunController
extends Node
## Racine d'une partie : construit le monde, orchestre la boucle (ordre fixe) et les écrans.

signal finished(result: Dictionary)

## Défaite : temps laissé à l'animation de chute du personnage avant l'écran de résultats (présentation).
const DEFEAT_DELAY := 1.4

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
## Temps fort atteint (ou touche « choix ») : les choix de niveau en réserve s'ouvrent l'un après l'autre.
var release_choices: bool = false
var _pending_chests: int = 0
var _victory_timer: float = -1.0
var _defeat_timer: float = -1.0
var _shake: float = 0.0
var _modal_open: bool = false
var _hitstop: float = 0.0


func _ready() -> void:
	if ctx == null:
		var setup: RunSetup = Router.pending_setup if Router.pending_setup else Profile.make_run_setup(&"")
		start(setup)


func start(setup: RunSetup) -> void:
	ctx = RunContext.new()
	ctx.setup = setup
	ctx.balance = GameDB.balance
	ctx.arena = setup.arena_override if setup.arena_override else GameDB.arena(setup.arena_id)
	ctx.difficulty = RunController.combine_difficulty(GameDB.difficulty(setup.difficulty_id), setup.modifier_ids)
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
	for effect: GameplayEffect in ctx.arena.rule_effects:
		effect.install(ctx, &"")
	for modifier_id: StringName in setup.modifier_ids:
		var modifier: RunModifierData = GameDB.modifier(modifier_id)
		if modifier:
			for effect: GameplayEffect in modifier.player_effects:
				effect.install(ctx, &"")
	_spawn_start_obstacles()
	ctx.stats.set_value(&"modifiers_count", float(setup.modifier_ids.size()))
	if setup.starter_id != &"":
		ctx.allies.add_monster(setup.starter_id, setup.starter_rank, setup.starter_variant)
	for id: StringName in setup.companion_ids:
		if ctx.allies.has_free_slot():
			ctx.allies.add_monster(id, int(setup.companion_ranks.get(id, 1)), bool(setup.companion_variants.get(id, false)))
	spawner = SpawnDirector.new(ctx)
	ctx.spawner = spawner
	if ctx.arena.has_finale():
		ctx.finale = ArenaFinale.new()
		ctx.finale.setup(ctx)
		ctx.world.add_child(ctx.finale)
	if not ctx.arena.zones.is_empty():
		ctx.zones = ZoneDirector.new(ctx)
	if not ctx.arena.rift_points.is_empty():
		ctx.rifts = RiftDirector.new()
		ctx.world.add_child(ctx.rifts)
		ctx.rifts.setup(ctx)
	if ctx.arena.altar_waves > 0 and ctx.zones == null and ctx.rifts == null:
		ctx.altar = AltarDirector.new()
		ctx.world.add_child(ctx.altar)
		ctx.altar.setup(ctx)
	# Barrières (zones, arène murée) et flèche de route.
	if ctx.zones or ctx.rifts or ctx.altar or not ctx.arena.finale_walls.is_empty():
		var overlay := ZoneOverlay.new()
		overlay.setup(ctx)
		if ctx.zones:
			ctx.zones.overlay = overlay
		ctx.world.add_child(overlay)
	event_director = EventDirector.new(ctx)
	ctx.events.boss_spawned.connect(func(boss: Enemy) -> void:
		ctx.stats.set_value(&"boss_spawned_at", ctx.time)
		boss_controller = BossController.new(ctx, boss)
		Audio.play_context("boss")
		Audio.play_sfx(&"boss_roar")
		_shake = 0.6)
	ctx.events.boss_phase_changed.connect(func(_phase: int) -> void:
		hitstop(0.25)
		_shake = 0.6
		Audio.play_context("boss_phase2")
		Audio.play_sfx(&"boss_roar"))
	ctx.events.synergy_proc.connect(func(_id: StringName) -> void: ctx.stats.add(&"synergy_procs"))
	ctx.events.level_up.connect(func(level: int) -> void:
		Audio.play_sfx(&"level_up")
		# Campagne : pas de niveaux, seulement des jalons.
		var text: String = tr("MILESTONE_FLOAT") if ctx.milestones() else tr("LEVELUP_TITLE") % level
		ctx.fx.text(ctx.player.global_position + Vector2(0, -60), text, UiKit.ACCENT))
	ctx.events.milestone_reached.connect(func() -> void:
		if ctx.milestones():
			ctx.stats.add(&"milestones")
			ctx.player.stats.add_modifier(StatKeys.DAMAGE, 0.0, ctx.balance.milestone_damage_pct)
			ctx.player.heal(ctx.player.max_hp * ctx.balance.milestone_heal_ratio)
			ctx.player.grant_level()
			release_choices = true)
	ctx.events.event_started.connect(func(key: String) -> void:
		if key == "FINALE_OPENING":
			release_choices = true)
	ctx.events.boss_spawned.connect(func(_boss: Enemy) -> void: release_choices = true)
	ctx.events.evolution_taken.connect(func(_id: StringName, _evo: StringName) -> void: Audio.play_sfx(&"evolution"))
	ctx.events.elite_spawned.connect(func(_enemy: Enemy) -> void: Audio.play_sfx(&"elite_spawn"))
	ctx.events.technique_cast.connect(func(_id: StringName, _kind: StringName) -> void: Audio.play_sfx(&"technique"))
	ctx.events.detonation.connect(func(_e: Enemy, _s: int, _id: StringName) -> void: Audio.play_sfx(&"detonation"))
	ctx.events.player_dashed.connect(func(_a: Vector2, _b: Vector2) -> void: Audio.play_sfx(&"dash"))
	ctx.events.capture_completed.connect(func(_id: StringName) -> void: Audio.play_sfx(&"evolution"))
	if not setup.autopilot:
		Profile.profile.set_preference("starter", String(setup.starter_id))
	Audio.play_context("run")
	ctx.events.boss_defeated.connect(_on_boss_defeated)
	ctx.events.chest_collected.connect(func() -> void:
		if not ctx.balance.feature_enabled(&"chests"):
			return
		_pending_chests += 1
		release_choices = true
		Audio.play_sfx(&"chest_open"))
	ctx.events.player_hurt.connect(func(_amount: float) -> void:
		_shake = maxf(_shake, 0.25)
		Audio.play_sfx(&"player_hurt"))
	# Relique au départ (arbre, boutique) : mode survie seulement ; la campagne n'en donne qu'aux jalons et coffres.
	if ctx.player.stats.get_int(StatKeys.STARTING_RELIC_CHOICE) > 0 and not ctx.milestones() \
			and ctx.balance.feature_enabled(&"relics"):
		chest_panel.open.call_deferred(true)
	# Boutique (objets de survie) : niveaux gagnés au départ, choisis tout de suite.
	for i: int in setup.start_levels:
		ctx.player.grant_level()
	if setup.start_levels > 0:
		release_choices = true


## Copie de la Tension combinée aux modificateurs de partie (multiplicateurs et bonus de récompense).
static func combine_difficulty(base: DifficultyData, modifier_ids: Array[StringName]) -> DifficultyData:
	var combined: DifficultyData = base.duplicate()
	var bonus: float = 0.0
	for id: StringName in modifier_ids:
		var modifier: RunModifierData = GameDB.modifier(id)
		if modifier == null:
			continue
		combined.enemy_hp_mult *= modifier.enemy_hp_mult
		combined.enemy_damage_mult *= modifier.enemy_damage_mult
		combined.enemy_speed_mult *= modifier.enemy_speed_mult
		combined.spawn_rate_mult *= modifier.spawn_rate_mult
		combined.elite_interval_mult *= modifier.elite_interval_mult
		combined.elite_affix_count += modifier.extra_elite_affixes
		bonus += modifier.reward_bonus
	combined.reward_mult *= 1.0 + bonus
	return combined


func _spawn_start_obstacles() -> void:
	var rect: Rect2 = ctx.arena_rect().grow(-120.0)
	for enemy_id: Variant in ctx.arena.start_obstacles:
		var data: EnemyData = GameDB.enemy(StringName(enemy_id))
		if data == null:
			continue
		for i: int in int(ctx.arena.start_obstacles[enemy_id]):
			var pos := Vector2(ctx.rng.randf_range(rect.position.x, rect.end.x), ctx.rng.randf_range(rect.position.y, rect.end.y))
			var away: Vector2 = pos - ctx.player.global_position
			if away.length() < 260.0:
				pos = ctx.player.global_position + (away.normalized() * 260.0 if away.length() > 1.0 else Vector2(260, 0))
			ctx.enemies.spawn(data, pos)


func _build_world() -> void:
	ctx.world = Node2D.new()
	ctx.world.name = "World"
	add_child(ctx.world)
	var ground := ArenaGround.new()
	ground.setup(ctx.arena, ctx.rng.seed)
	ctx.world.add_child(ground)
	ctx.obstacles = ground.obstacle_field()
	if not ctx.obstacles.is_empty():
		ctx.flow = FlowField.new()
		ctx.flow.setup(ctx.obstacles, ctx.arena_rect(),ctx.arena.navigation_cell_size)
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
	if TerrainDirector.uses_terrain(ctx.arena):
		ctx.terrain = TerrainDirector.new()
		ctx.world.add_child(ctx.terrain)
		ctx.terrain.setup(ctx)
	if not ctx.arena.flood_lanes.is_empty():
		ctx.flood = FloodDirector.new()
		ctx.world.add_child(ctx.flood)
		ctx.flood.setup(ctx)
	# Sol brûlant : plaques de la carte ou laissées par des Corrompus (toujours prêt, coût nul sans plaque).
	ctx.burn = BurnDirector.new()
	ctx.world.add_child(ctx.burn)
	ctx.burn.setup(ctx)
	if RockfallDirector.uses_rockfall(ctx.arena):
		ctx.rockfall = RockfallDirector.new()
		ctx.world.add_child(ctx.rockfall)
		ctx.rockfall.setup(ctx)
	if NestDirector.uses_nests(ctx.arena):
		ctx.nests = NestDirector.new()
		ctx.world.add_child(ctx.nests)
		ctx.nests.setup(ctx)
	if TideDirector.uses_tide(ctx.arena):
		ctx.tide = TideDirector.new()
		ctx.world.add_child(ctx.tide)
		ctx.tide.setup(ctx)
	if PodDirector.uses_pods(ctx.arena):
		ctx.pods = PodDirector.new()
		ctx.world.add_child(ctx.pods)
		ctx.pods.setup(ctx)
	if ctx.arena.night > 0.0:
		# Juste après les Corrompus : le voile les couvre, pas les Échos, le Chasseur ni les dangers.
		ctx.night = NightDirector.new()
		ctx.world.add_child(ctx.night)
		ctx.night.setup(ctx)
	ctx.allies = AllyManager.new()
	ctx.allies.z_index = 3
	ctx.allies.setup(ctx)
	ctx.world.add_child(ctx.allies)
	ctx.player = Player.new()
	ctx.player.z_index = 4
	ctx.world.add_child(ctx.player)
	var brain: PlayerBrain = AutopilotBrain.new() if ctx.setup.autopilot else HumanBrain.new()
	ctx.player.setup(ctx, brain)
	ctx.player.global_position = ground.player_start()
	ctx.projectiles = ProjectileManager.new()
	ctx.projectiles.setup(ctx)
	ctx.world.add_child(ctx.projectiles)
	ctx.fx = FxRenderer.new()
	ctx.fx.setup(ctx)
	ctx.world.add_child(ctx.fx)
	ctx.spells = HunterSpells.new()
	ctx.spells.setup(ctx, ctx.setup.spell_ids if not ctx.setup.spell_ids.is_empty() else ctx.balance.default_spells,
		ctx.setup.spell_variants)
	ctx.world.add_child(ctx.spells)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2.ONE * ctx.balance.camera_zoom
	if ground.environment != null and ground.environment.is_map():
		# Arène dessinée : la caméra s'arrête aux bords de la map.
		var rect: Rect2 = ctx.arena_rect()
		camera.limit_left = int(rect.position.x)
		camera.limit_top = int(rect.position.y)
		camera.limit_right = int(rect.end.x)
		camera.limit_bottom = int(rect.end.y)
	ctx.player.add_child(camera)
	camera.make_current.call_deferred()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	layer.add_child(root)
	hud = Hud.new()
	root.add_child(hud)
	hud.setup(ctx)
	level_up_panel = LevelUpPanel.new()
	root.add_child(level_up_panel)
	level_up_panel.setup(ctx)
	level_up_panel.closed.connect(func() -> void:
		_modal_open = false
		if ctx.player.pending_levels == 0:
			release_choices = false)
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


## Gel très bref de la simulation pour souligner un impact (élite, boss). L'affichage continue.
func hitstop(duration: float) -> void:
	if not ctx.setup.autopilot:
		_hitstop = maxf(_hitstop, duration)


func _physics_process(delta: float) -> void:
	if ctx == null or ctx.finished:
		return
	if _hitstop > 0.0:
		_hitstop -= delta
		ctx.fx.step(delta * 0.2)
		_update_camera(delta)
		return
	ctx.time += delta
	if ctx.finale:
		ctx.finale.step(delta)
	if ctx.zones:
		ctx.zones.step(delta)
	if ctx.rifts:
		ctx.rifts.step(delta)
	if ctx.altar:
		ctx.altar.step(delta)
	if ctx.terrain:
		ctx.terrain.step(delta)
	if ctx.flood:
		ctx.flood.step(delta)
	ctx.burn.step(delta)
	if ctx.pods:
		ctx.pods.step(delta)
	if ctx.rockfall:
		ctx.rockfall.step(delta)
	if ctx.tide:
		ctx.tide.step(delta)
	if ctx.nests:
		ctx.nests.step(delta)
	if ctx.night:
		ctx.night.step(delta)
	spawner.step(delta)
	event_director.step(delta)
	ctx.player.step(delta)
	ctx.spells.step(delta)
	ctx.allies.step(delta)
	ctx.enemies.step(delta)
	if ctx.finale:
		ctx.finale.enforce_boundary()
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
	# Défaite : Chasseur tombé, ou autel détruit (mode défense d'autel).
	if not ctx.player.alive or (ctx.altar and ctx.altar.destroyed):
		if _defeat_timer < 0.0:
			_defeat_timer = DEFEAT_DELAY if ctx.player.visual.has_sheet() else 0.0
		_defeat_timer -= delta
		if _defeat_timer <= 0.0:
			_finish(false)
		return
	_open_modals()


func _open_modals() -> void:
	if _modal_open or get_tree().paused:
		return
	if ctx.player.pending_levels == 0:
		release_choices = false
	if ctx.player.pending_levels >= ctx.balance.level_reserve_cap:
		release_choices = true  # réserve pleine : elle s'ouvre en entier, en une seule pause
	if ctx.player.pending_levels > 0 and release_choices:
		_modal_open = true
		level_up_panel.open()
	elif _pending_chests > 0:
		_pending_chests -= 1
		_modal_open = true
		chest_panel.open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_choices") and not get_tree().paused and ctx.player.pending_levels > 0:
		release_choices = true
		get_viewport().set_input_as_handled()


func _update_camera(delta: float) -> void:
	_shake = maxf(_shake - delta, 0.0)
	if _shake > 0.0 and Settings.screen_shake:
		camera.offset = Vector2(ctx.rng.randf_range(-1, 1), ctx.rng.randf_range(-1, 1)) * 6.0 * _shake / 0.25
	else:
		camera.offset = Vector2.ZERO


func _on_boss_defeated(_boss: Enemy) -> void:
	# Durée du combat contre le Dévoreur (objectifs de carte).
	ctx.stats.set_value(&"boss_fight_time", ctx.time - ctx.stats.get_value(&"boss_spawned_at"))
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
	if victory:
		ctx.stats.set_value(&"victories", 1.0)
	result = build_result()
	if not skip_profile:
		rewards = Profile.apply_run_result(result)
	else:
		rewards = RunRewards.compute(result, ctx.balance)
	ctx.events.run_finished.emit(victory)
	Audio.play_context("victory" if victory else "defeat")
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
	var captures: Array[String] = []
	for id: StringName in ctx.build.captures:
		captures.append(String(id))
	var modifiers: Array[String] = []
	for id: StringName in ctx.setup.modifier_ids:
		modifiers.append(String(id))
	return {
		"victory": ctx.victory,
		"time": ctx.time,
		"level": ctx.player.level,
		"milestones": ctx.milestones(),
		"kills": int(ctx.stats.get_value(&"kills")),
		"endless_wave": ctx.endless_wave() if ctx.arena.endless else 0,
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
		"captures": captures,
		"modifiers": modifiers,
		"stats": ctx.stats.to_dict(),
	}
