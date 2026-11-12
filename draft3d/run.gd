class_name DraftRun
extends Node3D
## Premier jet de la version 3D (docs/PREMIER_JET_3D.md) : une partie de survivor avec le Chasseur seul.
## Boucle : hordes → EXP → niveau → choix d'amélioration → puissance → boss. Aucun Écho, aucun système d'Écho.
## Tout l'état vit dans cette scène : recommencer la recharge. Le profil et les sauvegardes ne sont jamais écrits.
##
## Lancement : godot --path . res://draft3d/main.tscn
## Options (après --) : --bot (le jeu se joue seul) --passive (bot immobile : défaite) --god --seed=1
##   --boss-at=60 --time-scale=4 --perf=50,100,200 --shots=<dossier> --shot-times=20,90 --result (ligne RESULT)

enum State { LOADING, PLAYING, CHOOSING, WON, LOST }

const BOLT_SPEED := 16.8
const CAMERA_OFFSET := Vector3(0, 18, 17)

var tuning: DraftTuning
var boss_time: float = 480.0

var state: State = State.LOADING
var time: float = 0.0
var kills: int = 0
var damage_taken: float = 0.0
var level: DraftLevel
var hunter: DraftHunter
var enemies: DraftEnemies
var hazards: DraftHazards
var hud: DraftHud
var upgrades: DraftUpgrades
var camera: Camera3D
var rng := RandomNumberGenerator.new()
var balance: BalanceConfig
var bolts: Array[Dictionary] = []
var hostile: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var blocked_bolts: int = 0
var levels_gained: int = 0
var _offers: Array[UpgradeData] = []
var _pending_levels: int = 0
var _spawn_credit: float = 0.0
var _swarm_at: float = 60.0
var _boss_spawned: bool = false
var _camera_at := Vector3.ZERO
var _effects: Dictionary = {}
var _gem_mesh: MultiMeshInstance3D
var _options: Dictionary = {}
var _bot: bool = false
var _shot_times: Array[float] = []
var _end_delay: float = 0.0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		_options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	rng.seed = int(_options.get("seed", str(Time.get_ticks_usec())))
	balance = GameDB.balance
	tuning = load("res://draft3d/tuning.tres")
	boss_time = float(_options.get("boss-at", str(tuning.boss_time)))
	_swarm_at = tuning.swarm_every
	_effects = JSON.parse_string(FileAccess.get_file_as_string("res://draft3d/fx/effects.json"))
	_build_lighting()
	level = DraftLevel.new()
	add_child(level)
	level.build()
	upgrades = DraftUpgrades.new()
	hunter = DraftHunter.new()
	hunter.name = "Hunter"
	add_child(hunter)
	hunter.setup(balance)
	hunter.stats.add_modifier(StatKeys.DAMAGE, 0.0, tuning.hunter_damage_pct)
	hunter.stats.add_modifier(StatKeys.ATTACK_SPEED, 0.0, tuning.hunter_attack_speed_pct)
	hunter.global_position = DraftLevel.START
	hunter.reset_motion()
	hunter.god_mode = _options.has("god")
	hunter.leveled.connect(func(_l: int) -> void:
		_pending_levels += 1
		levels_gained += 1)
	hunter.hurt.connect(func(amount: float) -> void: damage_taken += amount)
	hunter.died.connect(_on_hunter_died)
	hazards = DraftHazards.new()
	hazards.hunter = hunter
	add_child(hazards)
	enemies = DraftEnemies.new()
	enemies.level = level
	enemies.hunter = hunter
	enemies.hazards = hazards
	enemies.run = self
	enemies.balance = balance
	enemies.rng.seed = rng.randi()
	enemies.boss_hp_mult = tuning.boss_hp_mult
	enemies.boss_damage_mult = tuning.boss_damage_mult
	add_child(enemies)
	_build_gems()
	_build_camera()
	hud = DraftHud.new()
	add_child(hud)
	hud.chosen.connect(choose)
	hud.restart_requested.connect(restart)
	_bot = _options.has("bot")
	hunter.automating = _bot
	for value: String in str(_options.get("shot-times", "")).split(",", false):
		_shot_times.append(float(value))
	Engine.time_scale = float(_options.get("time-scale", "1"))
	# Captures : seules les images demandées sont dessinées (le rendu logiciel des machines sans carte est lent).
	RenderingServer.render_loop_enabled = _shot_times.is_empty()
	await level.bake()
	state = State.PLAYING
	if _options.has("perf"):
		_run_perf()


func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101222")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b2b9d8")
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -35, 0)
	sun.light_color = Color("ffe4bc")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 145, 0)
	fill.light_color = Color("7b7cb5")
	fill.light_energy = 0.18
	add_child(fill)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.far = 150.0
	add_child(camera)
	_camera_at = hunter.global_position
	camera.position = _camera_at + CAMERA_OFFSET
	camera.look_at(_camera_at + Vector3.UP * 0.5)
	camera.current = true


func _build_gems() -> void:
	_gem_mesh = MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var shape := PrismMesh.new()
	shape.size = Vector3(0.22, 0.3, 0.22)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	shape.material = material
	multimesh.mesh = shape
	multimesh.instance_count = 600
	multimesh.visible_instance_count = 0
	_gem_mesh.multimesh = multimesh
	_gem_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gem_mesh)


func _process(delta: float) -> void:
	if hunter == null or camera == null:
		return
	# La caméra suit la position affichée du Chasseur (interpolée), pas sa position physique.
	var focus: Vector3 = hunter.view.render_position()
	# Près des bords, la caméra s'arrête avant de ne montrer que le vide derrière les limites.
	focus.x = clampf(focus.x, -DraftLevel.HALF.x + 12.0, DraftLevel.HALF.x - 12.0)
	focus.z = clampf(focus.z, -DraftLevel.HALF.y + 4.0, DraftLevel.HALF.y - 7.0)
	_camera_at = _camera_at.lerp(focus, 1.0 - exp(-8.0 * delta))
	camera.position = _camera_at + CAMERA_OFFSET
	hud.refresh(self, delta)
	_draw_gems()
	for shot: Dictionary in bolts + hostile:
		(shot["visual"] as Node3D).position = shot["at"]
	if not _shot_times.is_empty() and time >= _shot_times[0]:
		_shot_times.remove_at(0)
		_capture()


func _physics_process(delta: float) -> void:
	if state == State.WON or state == State.LOST:
		_end_delay -= delta
		if _end_delay <= 0.0 and _options.has("result"):
			_print_result()
		return
	if state != State.PLAYING:
		return
	time += delta
	enemies.hp_mult = 1.0 + tuning.enemy_hp_growth_per_min * time / 60.0
	enemies.damage_mult = (1.0 + balance.enemy_damage_growth_per_min * time / 60.0) * tuning.enemy_damage_scale
	_spawn_waves(delta)
	if _bot:
		_bot_step()
	_auto_attack()
	_step_bolts(delta)
	_step_hostile(delta)
	_step_gems(delta)
	if _pending_levels > 0:
		_open_offers()


# --- Vagues et boss -------------------------------------------------------------------------------------------

func wave() -> Dictionary:
	if _boss_spawned:
		return tuning.boss_wave
	var current: Dictionary = tuning.waves[0]
	for entry: Dictionary in tuning.waves:
		if time >= float(entry["at"]):
			current = entry
	return current


func _spawn_waves(delta: float) -> void:
	if not _boss_spawned and time >= boss_time:
		_boss_spawned = true
		var boss: BossData = GameDB.boss(tuning.boss_id)
		enemies.spawn_boss(boss, DraftLevel.BOSS_SPOT if hunter.global_position.distance_to(DraftLevel.BOSS_SPOT) > 8.0
			else level.spawn_point(rng, hunter.global_position))
		spawn_fx("hit", enemies.boss.pos + Vector3.UP, 4.0)
		hud.banner(tr("DRAFT_BOSS_WARNING") % tr(boss.name_key), 4.0)
	var current: Dictionary = wave()
	_spawn_credit += float(current["rate"]) * delta
	while _spawn_credit >= 1.0:
		_spawn_credit -= 1.0
		if enemies.count() < int(current["cap"]):
			enemies.spawn(_pick(current["mix"]), level.spawn_point(rng, hunter.global_position))
	if not _boss_spawned and time >= _swarm_at:
		_swarm_at += tuning.swarm_every
		var gate: Vector3 = level.spawn_point(rng, hunter.global_position, 16.0)
		for i: int in tuning.swarm_size + int(time / 60.0) * 2:
			enemies.spawn(GameDB.enemy(&"skitterling"), gate + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)))
		hud.banner(tr("DRAFT_SWARM"), 2.0)


func _pick(mix: Dictionary) -> EnemyData:
	var total: float = 0.0
	for id: String in mix:
		total += float(mix[id])
	var roll: float = rng.randf() * total
	for id: String in mix:
		roll -= float(mix[id])
		if roll <= 0.0:
			return GameDB.enemy(StringName(id))
	return GameDB.enemy(&"skitterling")


func boss_summon(boss: DraftEnemies.Foe, amount: int) -> void:
	for i: int in amount:
		var at: Vector3 = boss.pos + Vector3.RIGHT.rotated(Vector3.UP, TAU * i / amount) * 3.0
		enemies.spawn(GameDB.enemy(&"skitterling"), at)
		spawn_fx("hit", level.closest(at) + Vector3.UP * 0.4)


# --- Attaque automatique du Chasseur -----------------------------------------------------------------------------

## Vue dégagée entre deux points : aucun décor entre eux. Règle unique pour viser, tirer et cracher, à plat comme
## entre deux hauteurs : on touche ce que l'on voit (du haut de la terrasse vers la cour et inversement), jamais
## à travers un mur, un pilier, une caisse ou le rebord de la terrasse.
func sight_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func target() -> DraftEnemies.Foe:
	var candidates: Array[DraftEnemies.Foe] = enemies.near(hunter.global_position, hunter.attack_range())
	var origin: Vector3 = hunter.chest()
	candidates.sort_custom(func(a: DraftEnemies.Foe, b: DraftEnemies.Foe) -> bool:
		return a.pos.distance_squared_to(origin) < b.pos.distance_squared_to(origin))
	for i: int in mini(candidates.size(), 8):
		if sight_clear(origin, _aim_point(candidates[i])):
			return candidates[i]
	return null


func _aim_point(foe: DraftEnemies.Foe) -> Vector3:
	return foe.pos + Vector3.UP * minf(0.6, foe.radius + 0.2)


func _auto_attack() -> void:
	if not hunter.alive or hunter.attack_timer > 0.0:
		return
	var foe: DraftEnemies.Foe = target()
	if foe == null:
		return
	hunter.attack_timer = hunter.attack_interval()
	hunter.view.play_action(&"attack", 0.2)
	var origin: Vector3 = hunter.chest()
	var aim: Vector3 = origin.direction_to(_aim_point(foe))
	hunter.view.face_left(aim.dot(camera.global_basis.x) < 0.0)
	var count: int = maxi(hunter.stats.get_int(StatKeys.PROJECTILE_COUNT), 1)
	for i: int in count:
		var angle: float = deg_to_rad(9.0) * (i - (count - 1) * 0.5)
		fire_bolt(origin, aim.rotated(Vector3.UP, angle), hunter.bolt_damage(), hunter.attack_range(),
			hunter.stats.get_int(StatKeys.PIERCE), hunter.stats.get_int(StatKeys.BOLT_SPLIT))


func fire_bolt(origin: Vector3, direction: Vector3, damage: float, reach: float, pierce: int, split: int) -> void:
	var visual: Sprite3D = spawn_fx("fireball", origin, 0.75 if split >= 0 else 0.5, true)
	visual.flip_h = direction.dot(camera.global_basis.x) < 0.0
	bolts.append({"at": origin, "dir": direction, "left": reach, "damage": damage, "pierce": pierce, "split": split,
		"hit": [], "visual": visual})


func _step_bolts(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for i: int in range(bolts.size() - 1, -1, -1):
		var shot: Dictionary = bolts[i]
		var from: Vector3 = shot["at"]
		var step: float = minf(BOLT_SPEED * delta, float(shot["left"]))
		var to: Vector3 = from + (shot["dir"] as Vector3) * step
		var wall: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		var spent: bool = false
		if not wall.is_empty():
			to = wall["position"]
			blocked_bolts += 1
			spent = true
		for foe: DraftEnemies.Foe in enemies.near(to, 0.25):
			# Le trait touche à sa hauteur : il passe au-dessus d'un ennemi en contrebas et sous une terrasse.
			if (shot["hit"] as Array).has(foe) or absf(_aim_point(foe).y - to.y) > foe.radius + 0.6:
				continue
			(shot["hit"] as Array).append(foe)
			spawn_fx("hit", to)
			enemies.hit(foe, float(shot["damage"]), (shot["dir"] as Vector3) * balance.bolt.knockback * DraftHunter.UNIT * 3.0)
			if int(shot["split"]) > 0:
				for n: int in int(shot["split"]):
					var side: float = deg_to_rad(40.0) * (1.0 if n % 2 == 0 else -1.0) * (1 + n / 2)
					fire_bolt(to, (shot["dir"] as Vector3).rotated(Vector3.UP, side), float(shot["damage"]) * 0.5, 5.0, 0, -1)
					(bolts[bolts.size() - 1]["hit"] as Array).append(foe)
				shot["split"] = 0
			if int(shot["pierce"]) <= 0:
				spent = true
				break
			shot["pierce"] = int(shot["pierce"]) - 1
		shot["at"] = to
		shot["left"] = float(shot["left"]) - step
		if spent or float(shot["left"]) <= 0.0:
			if spent and not wall.is_empty():
				spawn_fx("hit", to, 0.7)
			(shot["visual"] as Node).queue_free()
			bolts.remove_at(i)


# --- Tirs ennemis ------------------------------------------------------------------------------------------------

func enemy_shot(foe: DraftEnemies.Foe) -> void:
	var origin: Vector3 = foe.pos + Vector3.UP * 0.6
	var visual: Sprite3D = spawn_fx("fireball", origin, 0.6, true)
	visual.modulate = Color(0.6, 1.3, 0.5)
	hostile.append({"at": origin, "dir": origin.direction_to(hunter.chest()),
		"speed": foe.data.attack.projectile_speed * DraftHunter.UNIT * 1.4, "left": 4.0,
		"damage": foe.data.attack.damage * enemies.damage_mult, "visual": visual})


func _step_hostile(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for i: int in range(hostile.size() - 1, -1, -1):
		var shot: Dictionary = hostile[i]
		var from: Vector3 = shot["at"]
		var to: Vector3 = from + (shot["dir"] as Vector3) * float(shot["speed"]) * delta
		shot["left"] = float(shot["left"]) - delta
		var done: bool = float(shot["left"]) <= 0.0 \
			or not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()
		if not done and to.distance_to(hunter.chest()) < 0.55:
			hunter.take_damage(float(shot["damage"]))
			done = true
		shot["at"] = to
		if done:
			spawn_fx("hit", to, 0.7)
			(shot["visual"] as Node).queue_free()
			hostile.remove_at(i)


# --- EXP ---------------------------------------------------------------------------------------------------------

func on_foe_killed(foe: DraftEnemies.Foe) -> void:
	kills += 1
	spawn_fx("hit", foe.pos + Vector3.UP * 0.5, 1.4)
	if foe.boss != null:
		_finish(true)
		return
	drop_gem(foe.pos, float(foe.xp))
	if rng.randf() < balance.heal_drop_chance * (balance.heal_low_hp_mult if hunter.hp < hunter.max_hp() * 0.35 else 1.0):
		gems.append({"at": foe.pos + Vector3(0.4, 0.25, 0), "value": 0.0, "heal": true, "pulled": false})


func on_hunter_hit(_foe: DraftEnemies.Foe) -> void:
	spawn_fx("hit", hunter.chest(), 0.8)


func drop_gem(at: Vector3, value: float) -> void:
	# Au-delà de la réserve affichable, l'EXP rejoint un cristal voisin : rien n'est perdu.
	if gems.size() >= 590:
		gems[rng.randi() % gems.size()]["value"] = float(gems[rng.randi() % gems.size()]["value"]) + value
		return
	gems.append({"at": at + Vector3.UP * 0.25, "value": value, "heal": false, "pulled": false})


func _step_gems(delta: float) -> void:
	var center: Vector3 = hunter.chest()
	var reach: float = hunter.pickup_radius()
	for i: int in range(gems.size() - 1, -1, -1):
		var gem: Dictionary = gems[i]
		var distance: float = (gem["at"] as Vector3).distance_to(center)
		if not gem["pulled"] and distance <= reach and hunter.alive:
			gem["pulled"] = true
		if gem["pulled"]:
			gem["at"] = (gem["at"] as Vector3).move_toward(center, balance.magnet_speed * DraftHunter.UNIT * delta)
			if distance < 0.45:
				if gem["heal"]:
					hunter.heal(hunter.max_hp() * balance.heal_amount_ratio)
				else:
					hunter.gain_xp(float(gem["value"]))
				gems.remove_at(i)


func _draw_gems() -> void:
	var multimesh: MultiMesh = _gem_mesh.multimesh
	multimesh.visible_instance_count = mini(gems.size(), multimesh.instance_count)
	var spin: float = float(Time.get_ticks_msec()) * 0.004
	for i: int in multimesh.visible_instance_count:
		var gem: Dictionary = gems[i]
		var size: float = 1.6 if gem["heal"] else clampf(0.9 + float(gem["value"]) * 0.12, 0.9, 1.8)
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, spin + i).scaled(Vector3.ONE * size), gem["at"]))
		multimesh.set_instance_color(i, Color(1.0, 0.35, 0.4) if gem["heal"] else
			(Color(0.45, 0.95, 1.0) if float(gem["value"]) < 3.0 else Color(0.75, 0.6, 1.0)))


# --- Niveaux et améliorations ------------------------------------------------------------------------------------

func _open_offers() -> void:
	_offers = upgrades.roll(rng, balance.upgrade_choices)
	if _offers.is_empty():
		# Catalogue épuisé : le niveau soigne au lieu d'ouvrir un choix vide.
		_pending_levels -= 1
		hunter.heal(hunter.max_hp() * 0.2)
		return
	state = State.CHOOSING
	get_tree().paused = true
	hud.show_offers(hunter.level - _pending_levels + 1, _offers, upgrades)
	if _bot:
		choose.call_deferred(rng.randi() % _offers.size())


func choose(index: int) -> void:
	if state != State.CHOOSING or index < 0 or index >= _offers.size():
		return
	var before: float = hunter.max_hp()
	upgrades.apply(_offers[index], hunter.stats)
	# Les PV gagnés avec le maximum sont donnés tout de suite.
	hunter.heal(maxf(hunter.max_hp() - before, 0.0))
	_pending_levels -= 1
	_offers = []
	hud.hide_offers()
	hud.show_build(upgrades)
	get_tree().paused = false
	state = State.PLAYING


# --- Fin de partie -----------------------------------------------------------------------------------------------

func _on_hunter_died() -> void:
	_finish(false)


func _finish(victory: bool) -> void:
	if state == State.WON or state == State.LOST:
		return
	state = State.WON if victory else State.LOST
	hunter.active = false
	hunter.god_mode = victory
	_end_delay = 1.0
	hud.show_end(victory, tr("DRAFT_SUMMARY") % ["%d:%02d" % [int(time) / 60, int(time) % 60], hunter.level, kills])


func restart() -> void:
	if state != State.WON and state != State.LOST and state != State.PLAYING:
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(11.0, camera.size - 1.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(26.0, camera.size + 1.0)
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
		get_tree().quit()


func spawn_fx(id: String, at: Vector3, size: float = 1.0, looping: bool = false) -> Sprite3D:
	var effect := DraftEffect.new()
	effect.art = _effects[id]
	effect.loop = looping
	effect.position = at
	effect.pixel_size = 0.024 * size
	add_child(effect)
	return effect


# --- Bot, mesures et captures ------------------------------------------------------------------------------------

## Bot de vérification : s'écarte des ennemis et des zones annoncées, ramasse l'EXP, revient vers le centre.
func _bot_step() -> void:
	if _options.has("passive"):
		hunter.auto_direction = Vector3.ZERO
		return
	var here: Vector3 = hunter.global_position
	var wish := Vector3.ZERO
	var close: int = 0
	for foe: DraftEnemies.Foe in enemies.near(here, 7.0):
		var away: Vector3 = here - foe.pos
		away.y = 0.0
		var distance: float = maxf(away.length() - foe.radius, 0.3)
		wish += away.normalized() * (3.0 if foe.boss != null else 1.0) / (distance * distance) * 6.0
		if distance < 1.6:
			close += 1
	var best := Vector3.INF
	for gem: Dictionary in gems:
		if (gem["at"] as Vector3).distance_squared_to(here) < best.distance_squared_to(here):
			best = gem["at"]
	if best != Vector3.INF and best.distance_to(here) < 9.0:
		wish += (best - here).normalized() * 0.8
	# Tour de piste autour de la cour (rayon 11 m) : les hordes s'étirent derrière le Chasseur.
	var radial := Vector3(here.x, 0, here.z - 2.0)
	var ring: float = radial.length()
	if ring > 0.1:
		wish += Vector3(-radial.z, 0, radial.x) / ring * 1.2 + radial / ring * clampf((11.0 - ring) * 0.25, -1.0, 1.0)
	wish.y = 0.0
	hunter.auto_direction = wish
	hunter.auto_dash = close >= 3 or hazards.get_child_count() > 0 and rng.randf() < 0.04


func _print_result() -> void:
	_options.erase("result")
	var boss_ratio: float = enemies.boss.hp / enemies.boss.max_hp if enemies.boss != null else 1.0
	print("RESULT|%s|temps %d|niveau %d|éliminations %d|dégâts subis %d|PV boss %.2f|améliorations %s|chemins %d" % [
		"VICTOIRE" if state == State.WON else "DÉFAITE", int(time), hunter.level, kills, int(damage_taken),
		maxf(boss_ratio, 0.0), upgrades.stacks, enemies.path_requests])
	get_tree().quit()


func _capture() -> void:
	RenderingServer.render_loop_enabled = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder: String = str(_options.get("shots", "user://"))
	DirAccess.make_dir_recursive_absolute(folder)
	get_viewport().get_texture().get_image().save_png(folder.path_join("premier_jet_%03ds.png" % int(time)))
	RenderingServer.render_loop_enabled = _shot_times.is_empty()
	if _shot_times.is_empty() and _options.has("quit-after-shots"):
		get_tree().quit()


## Mesure en temps réel : paliers d'ennemis croissants, 6 s chacun, images par seconde et coût du pas physique.
func _run_perf() -> void:
	hunter.god_mode = true
	boss_time = INF
	for step: String in str(_options["perf"]).split(",", false):
		var wanted: int = int(step)
		while enemies.count() < wanted:
			enemies.spawn(_pick(tuning.waves[tuning.waves.size() - 1]["mix"]), level.spawn_point(rng, hunter.global_position, 0.0))
		_spawn_credit = -1000000.0
		await get_tree().create_timer(2.0, true, false, true).timeout
		var frames: int = Engine.get_frames_drawn()
		var physics: float = 0.0
		var samples: int = 0
		var start: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 6000:
			await get_tree().process_frame
			physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			samples += 1
		var seconds: float = float(Time.get_ticks_msec() - start) / 1000.0
		print("PERF|ennemis %d|%.1f images/s|pas physique %.2f ms|traits %d|cristaux %d" % [enemies.count(),
			float(Engine.get_frames_drawn() - frames) / seconds, physics / maxi(samples, 1) * 1000.0, bolts.size(), gems.size()])
	get_tree().quit()
