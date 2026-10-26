class_name ZoneDirector
extends RefCounted
## Mode « vagues par zone » (docs/design/MODE_VAGUES_PAR_ZONE.md) : la carte est découpée en zones fermées par
## des barrières. Dans chaque zone, le Chasseur nettoie une suite de vagues (nombre fini de Corrompus) ; à la fin
## de la dernière, les barrières de sortie s'ouvrent, une récompense tombe et la zone suivante démarre quand il y
## entre. Après la dernière zone, la finale (ArenaFinale) prend le relais : arène fermée et boss.
## Grande arène (ArenaData.open_arena) : les zones sont des paliers qui partagent toute la carte. Un palier peut finir
## par un gardien (élite en version boss, ou boss du chapitre qui finit la carte).

enum Phase { ENTER, START, WAVE, PAUSE, GUARDIAN, DONE }

## Délai entre la fin de la dernière vague d'un palier et l'arrivée de son gardien (alerte au sol).
const GUARDIAN_DELAY := 3.0
const GUARDIAN_DISTANCE := 480.0

## Délai avant la première vague d'une zone, et entre deux vagues (secondes).
const START_DELAY := 2.5
const WAVE_PAUSE := 3.0
## Traque : quand il reste peu de Corrompus (part de la vague, minimum absolu), ils accélèrent et sont signalés.
const HUNT_SHARE := 0.15
const HUNT_MIN := 4
const HUNT_SPEED := 1.6
## Traque : au-delà de cette distance du dernier Corrompu, la flèche de route mène à lui (cible mise à jour chaque seconde).
const HUNT_ROUTE_DISTANCE := 700.0
## Sécurité : si plus aucun Corrompu ne meurt pendant ce délai, les restants réapparaissent près du Chasseur.
const STALL_TIME := 20.0
## Distance d'apparition au Chasseur : hors de l'écran autant que possible, jamais sur lui.
const SPAWN_MIN := 420.0
const SPAWN_MAX := 950.0
const SPAWN_SAFE := 260.0

var ctx: RunContext
var phase: Phase = Phase.START
var zone_index: int = 0
var wave_index: int = 0
var hunting: bool = false
## Région (indice de zone, ou zones.size() pour l'arène) de chaque case de la navigation.
var labels := PackedInt32Array()
## Navigation vers l'objectif (zone suivante, arène) : flèche de direction et bot de test.
var guide: FlowField
var overlay: ZoneOverlay
var _timer: float = START_DELAY
var _queue: Array[StringName] = []
var _elites: Array[StringName] = []
var _budget: float = 0.0
var _wave_total: int = 0
var _stall: float = 0.0
var _hunt_goal := Vector2.INF
var _hunt_timer: float = 0.0
var _last_remaining: int = -1
var _zone_cells: Array[PackedInt32Array] = []
var _walls: Array[Array] = []
var _guardian: Enemy
var _guardian_pos := Vector2.INF


func _init(p_ctx: RunContext) -> void:
	ctx = p_ctx
	for zone: LevelZoneData in ctx.arena.zones:
		var ids: Array[int] = []
		for rect: Rect2 in zone.exit_walls:
			ids.append(ctx.obstacles.add_wall(rect))
		_walls.append(ids)
	if ctx.flow == null:
		ctx.flow = FlowField.new()
		ctx.flow.setup(ctx.obstacles, ctx.arena_rect(), ctx.arena.navigation_cell_size)
	ctx.flow.apply_walls(ctx.obstacles)
	var seeds: Array[Vector2] = []
	for zone: LevelZoneData in ctx.arena.zones:
		seeds.append(zone.anchor)
	if ctx.arena.open_arena:
		# Paliers : une seule région (toute la carte) partagée par toutes les zones.
		seeds.resize(1)
	if ctx.arena.has_finale():
		seeds.append(ctx.arena.finale_center)
	labels = ctx.flow.label_regions(seeds)
	for i: int in ctx.arena.zones.size():
		var cells := PackedInt32Array()
		var region: int = 0 if ctx.arena.open_arena else i
		for index: int in labels.size():
			if labels[index] == region:
				cells.append(index)
		_zone_cells.append(cells)
	# Guide fin (cases de 16) : suit aussi les passages étroits ; recalculé seulement quand l'objectif change.
	guide = FlowField.new()
	guide.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	zone_index = 0
	phase = Phase.START
	_timer = START_DELAY
	ctx.events.event_started.emit(tr_key(zone().name_key))


func zone() -> LevelZoneData:
	return ctx.arena.zones[zone_index] if zone_index < ctx.arena.zones.size() else null


func zone_count() -> int:
	return ctx.arena.zones.size()


func region_of(pos: Vector2) -> int:
	if ctx.arena.open_arena:
		return mini(zone_index, zone_count() - 1)
	return ctx.flow.region_at(labels, pos)


## Corrompus encore à éliminer dans la vague (présents + à venir).
func remaining() -> int:
	return ctx.enemies.count() + _queue.size() + _elites.size()


func seconds_left() -> float:
	return maxf(_timer, 0.0)


func step(delta: float) -> void:
	match phase:
		Phase.ENTER:
			if region_of(ctx.player.global_position) == zone_index:
				phase = Phase.START
				_timer = START_DELAY
				ctx.events.event_started.emit(tr_key(zone().name_key))
		Phase.START, Phase.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_begin_wave()
		Phase.WAVE:
			_spawn(delta)
			_watch_wave(delta)
		Phase.GUARDIAN:
			_watch_guardian(delta)
	ctx.enemies.hunt_speed_mult = HUNT_SPEED if hunting else 1.0
	if overlay:
		overlay.queue_redraw()


## Position visée par le Chasseur : la zone suivante, puis l'arène (INF si rien à rejoindre).
func objective() -> Vector2:
	if phase == Phase.ENTER:
		return zone().anchor
	if phase == Phase.DONE and ctx.finale and ctx.finale.state == ArenaFinale.State.TRAVEL:
		return ctx.arena.finale_center
	# Gardien de palier loin du Chasseur : la flèche mène à lui.
	if phase == Phase.GUARDIAN and _guardian != null and is_instance_valid(_guardian) and _guardian.alive \
			and ctx.player.global_position.distance_to(_guardian.position) > HUNT_ROUTE_DISTANCE * 0.6:
		return _guardian.position
	if hunting and _hunt_goal != Vector2.INF \
			and ctx.player.global_position.distance_to(_hunt_goal) > HUNT_ROUTE_DISTANCE:
		return _hunt_goal
	return Vector2.INF


## Direction de la route vers l'objectif depuis `pos` (zéro si aucun objectif).
func objective_direction(pos: Vector2) -> Vector2:
	var goal: Vector2 = objective()
	if goal == Vector2.INF:
		return Vector2.ZERO
	guide.apply_walls(ctx.obstacles)
	guide.update(goal)
	return guide.direction(pos, (goal - pos).normalized())


func _begin_wave() -> void:
	var wave: ZoneWaveData = zone().waves[wave_index]
	_queue.clear()
	for i: int in wave.count:
		_queue.append(_pick(wave))
	_elites = wave.elites.duplicate()
	_wave_total = wave.count + wave.elites.size()
	_budget = 0.0
	_stall = 0.0
	_last_remaining = -1
	hunting = false
	phase = Phase.WAVE
	ctx.events.event_started.emit(tr_key("ZONE_WAVE_BANNER") % [wave_index + 1, zone().waves.size()])


func _pick(wave: ZoneWaveData) -> StringName:
	var total: float = 0.0
	for i: int in wave.enemies.size():
		total += wave.weights[i] if i < wave.weights.size() else 1.0
	var roll: float = ctx.rng.randf() * total
	for i: int in wave.enemies.size():
		roll -= wave.weights[i] if i < wave.weights.size() else 1.0
		if roll <= 0.0:
			return wave.enemies[i]
	return wave.enemies.back()


func _spawn(delta: float) -> void:
	var wave: ZoneWaveData = zone().waves[wave_index]
	_budget = minf(_budget + wave.spawn_rate * ctx.difficulty.spawn_rate_mult * delta, 6.0)
	# Les élites ouvrent la vague : la difficulté monte dès son début.
	while not _elites.is_empty() and ctx.enemies.count() < wave.max_alive:
		ctx.spawner.spawn_elite(_elites.pop_back(), spawn_position())
	while _budget >= 1.0 and not _queue.is_empty() and ctx.enemies.count() < wave.max_alive:
		_budget -= 1.0
		var data: EnemyData = GameDB.enemy(_queue.pop_back())
		if data:
			ctx.enemies.spawn(data, spawn_position())


func _watch_wave(delta: float) -> void:
	var left: int = remaining()
	if left == 0:
		_end_wave()
		return
	var spawned_all: bool = _queue.is_empty() and _elites.is_empty()
	hunting = spawned_all and left <= maxi(HUNT_MIN, ceili(_wave_total * HUNT_SHARE))
	if not spawned_all:
		return
	_hunt_timer -= delta
	if _hunt_timer <= 0.0:
		_hunt_timer = 1.0
		_hunt_goal = _nearest_remaining()
	# Traque bornée : après STALL_TIME secondes de traque (ou sans élimination), les derniers Corrompus sont ramenés
	# près du Chasseur, même s'ils tombent un à un (une fin de vague ne traîne jamais).
	if left == _last_remaining or hunting:
		_stall += delta
	else:
		_stall = 0.0
		_last_remaining = left
	if _stall >= STALL_TIME:
		_stall = 0.0
		for enemy: Enemy in ctx.enemies.list:
			if enemy.alive and not enemy.is_boss and not enemy.is_obstacle:
				enemy.position = spawn_position(SPAWN_SAFE + 120.0, SPAWN_MIN + 200.0)
				ctx.fx.ring(enemy.position, enemy.radius * 1.8, Color(0.75, 0.45, 1.0, 0.9), 0.4)


## Corrompu restant le plus proche du Chasseur (INF s'il n'y en a pas).
func _nearest_remaining() -> Vector2:
	var best := Vector2.INF
	var best_d: float = INF
	var from: Vector2 = ctx.player.global_position
	for enemy: Enemy in ctx.enemies.list:
		if enemy.alive and not enemy.is_boss and not enemy.is_obstacle:
			var d: float = from.distance_squared_to(enemy.position)
			if d < best_d:
				best_d = d
				best = enemy.position
	return best


func _end_wave() -> void:
	ctx.events.milestone_reached.emit()
	hunting = false
	_hunt_goal = Vector2.INF
	wave_index += 1
	if wave_index < zone().waves.size():
		phase = Phase.PAUSE
		_timer = WAVE_PAUSE
		return
	if zone().guardian_enemy != &"" or zone().guardian_boss != &"":
		_announce_guardian()
		return
	_clear_zone()


## Gardien de palier : alerte au sol devant le Chasseur, puis apparition.
func _announce_guardian() -> void:
	phase = Phase.GUARDIAN
	_guardian = null
	_timer = GUARDIAN_DELAY
	var dir := Vector2.RIGHT.rotated(ctx.rng.randf() * TAU)
	var pos: Vector2 = ctx.player.global_position + dir * GUARDIAN_DISTANCE
	var area: Rect2 = ctx.arena_rect().grow(-150.0)
	_guardian_pos = ctx.obstacles.push_out(pos.clamp(area.position, area.end), 60.0)
	ctx.fx.ring(_guardian_pos, 120.0, Color(1.0, 0.45, 0.15, 0.9), GUARDIAN_DELAY)
	ctx.events.event_started.emit("GUARDIAN_INCOMING")


func _watch_guardian(delta: float) -> void:
	if _guardian == null:
		_timer -= delta
		if _timer > 0.0:
			return
		_spawn_guardian()
		return
	if zone().guardian_boss != &"":
		return  # la mort du boss finit la carte (RunController)
	if not _guardian.alive:
		ctx.mini_boss = null
		_guardian = null
		Audio.play_context("run")
		_clear_zone()


func _spawn_guardian() -> void:
	var cleared: LevelZoneData = zone()
	if cleared.guardian_boss != &"":
		var data: BossData = GameDB.boss(cleared.guardian_boss)
		ctx.spawner.boss_spawned = true
		_guardian = ctx.enemies.spawn_boss(data, _guardian_pos)
		ctx.boss = _guardian
		ctx.events.boss_spawned.emit(_guardian)
		return
	_guardian = ctx.enemies.spawn_mini_boss(GameDB.enemy(cleared.guardian_enemy), _guardian_pos,
		cleared.guardian_hp_mult, cleared.guardian_scale)
	Audio.play_context("boss")
	Audio.play_sfx(&"boss_roar")
	ctx.events.event_started.emit(TranslationServer.translate("GUARDIAN_ARRIVED") % _guardian.display_name())


func _clear_zone() -> void:
	var cleared: LevelZoneData = zone()
	for id: int in _walls[zone_index]:
		ctx.obstacles.set_wall_enabled(id, false)
		if overlay:
			overlay.dissolve(id)
	ctx.flow.apply_walls(ctx.obstacles)
	ctx.player.heal(ctx.player.max_hp * cleared.heal_ratio)
	if cleared.reward_chest:
		ctx.events.chest_collected.emit()
	ctx.stats.add(&"zones_cleared")
	Audio.play_sfx(&"evolution")
	ctx.events.event_started.emit("ZONE_CLEARED_BANNER")
	zone_index += 1
	wave_index = 0
	if zone_index < zone_count():
		phase = Phase.ENTER
	else:
		phase = Phase.DONE
		if ctx.finale:
			ctx.finale.start_travel()


## Point d'apparition dans la zone active, à bonne distance du Chasseur et hors du décor.
func spawn_position(min_dist: float = SPAWN_MIN, max_dist: float = SPAWN_MAX) -> Vector2:
	var cells: PackedInt32Array = _zone_cells[mini(zone_index, _zone_cells.size() - 1)]
	var player_pos: Vector2 = ctx.player.global_position
	var best := Vector2.INF
	var best_score: float = -INF
	if cells.is_empty():
		return player_pos
	for attempt: int in 24:
		var index: int = cells[ctx.rng.randi() % cells.size()]
		var pos: Vector2 = ctx.flow.cell_center(Vector2i(index % ctx.flow.size.x, index / ctx.flow.size.x))
		var dist: float = pos.distance_to(player_pos)
		if dist >= min_dist and dist <= max_dist and not ctx.obstacles.blocks(pos, 14.0):
			return pos
		# Repli : le point le plus proche de la plage voulue, jamais sur le Chasseur.
		var score: float = -absf(clampf(dist, min_dist, max_dist) - dist) - (1e6 if dist < SPAWN_SAFE else 0.0)
		if score > best_score:
			best_score = score
			best = pos
	return best


## Clé de traduction (ou texte déjà traduit) transmise à l'interface.
static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)
