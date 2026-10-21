class_name EnemyManager
extends Node2D
## Gère tous les ennemis : apparition, IA, séparation, contact, statuts, mort.

const SEPARATION_CHECKS := 10
## Rafraîchissement de la carte de flux (secondes) : un seul calcul pour tous les ennemis.
const FLOW_REFRESH := 0.25

## Nuit (NightDirector) : seuls les ennemis visibles peuvent être ciblés ; vide = tout est visible.
var visibility: Callable
var ctx: RunContext
var list: Array[Enemy] = []
var obstacles: Array[Enemy] = []
var grid := SpatialGrid.new(64.0)
## Mode « vagues par zone » : les derniers Corrompus d'une vague accélèrent (traque).
var hunt_speed_mult: float = 1.0
var _buffer: Array = []
var _overlay: Node2D
var _dirty_removal: bool = false
var _frame: int = 0
var _flow_timer: float = 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	_overlay = Node2D.new()
	_overlay.z_index = 6
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func count() -> int:
	return list.size()


## Ennemis vivants dans un rayon (copie : sûre même si la liste change ensuite).
func query_radius(pos: Vector2, query_radius_px: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	_buffer.clear()
	grid.query(pos, query_radius_px + 80.0, _buffer)
	for item: Variant in _buffer:
		var enemy: Enemy = item
		if enemy.alive and enemy.position.distance_to(pos) <= query_radius_px + enemy.radius:
			result.append(enemy)
	return result


func find_nearest(pos: Vector2, max_range: float, exclude: Dictionary = {}) -> Enemy:
	# Recherche par rayons croissants : la plupart du temps, la cible est proche.
	var search: float = minf(160.0, max_range)
	while true:
		var best: Enemy = _nearest_within(pos, search, exclude)
		if best or search >= max_range:
			return best
		search = minf(search * 2.0, max_range)
	return null


func _nearest_within(pos: Vector2, max_range: float, exclude: Dictionary) -> Enemy:
	var best: Enemy = null
	var best_d: float = max_range * max_range
	_buffer.clear()
	grid.query(pos, max_range, _buffer)
	for item: Variant in _buffer:
		var enemy: Enemy = item
		if not enemy.alive or not enemy.is_target() or exclude.has(enemy.get_instance_id()):
			continue
		if visibility.is_valid() and not bool(visibility.call(enemy)):
			continue
		var d: float = enemy.position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func spawn(data: EnemyData, pos: Vector2, elite_affixes: Array[EliteAffixData] = []) -> Enemy:
	var enemy := Enemy.new()
	enemy.data = data
	enemy.position = ctx.obstacles.push_out(pos, data.radius)
	enemy.spawn_time = ctx.time
	var minutes: float = ctx.minutes()
	var hp_mult: float = (1.0 + ctx.balance.enemy_hp_growth_per_min * minutes) * ctx.difficulty.enemy_hp_mult
	var dmg_mult: float = (1.0 + ctx.balance.enemy_damage_growth_per_min * minutes) * ctx.difficulty.enemy_damage_mult
	var speed_mult: float = ctx.difficulty.enemy_speed_mult
	enemy.base_defense = data.defense
	enemy.radius = data.radius
	enemy.xp_value = maxi(1, roundi(data.xp_value * ctx.arena.xp_mult))
	var tint := Color.WHITE
	if not elite_affixes.is_empty():
		enemy.is_elite = true
		enemy.affixes = elite_affixes
		hp_mult *= ctx.balance.elite_hp_mult
		enemy.radius *= ctx.balance.elite_size_mult
		enemy.xp_value = int(data.xp_value * ctx.balance.elite_xp_mult * ctx.arena.xp_mult)
		for affix: EliteAffixData in elite_affixes:
			hp_mult *= affix.hp_mult
			dmg_mult *= affix.damage_mult
			speed_mult *= affix.speed_mult
			enemy.base_defense += affix.defense_add
			tint = tint * affix.tint
	enemy.max_hp = data.max_hp * hp_mult
	enemy.hp = enemy.max_hp
	enemy.contact_damage = data.damage * dmg_mult
	enemy.move_speed = data.move_speed * speed_mult
	enemy.attack_timer = ctx.rng.randf_range(0.5, 2.0)
	enemy.visual = EntityVisual.new()
	enemy.add_child(enemy.visual)
	enemy.visual.setup(data.visual)
	if enemy.is_elite:
		enemy.visual.scale = Vector2.ONE * ctx.balance.elite_size_mult
		enemy.visual.set_tint(tint)
	add_child(enemy)
	list.append(enemy)
	grid.insert(enemy, enemy.position)
	if data.brain == EnemyData.Brain.STATIC:
		enemy.is_obstacle = true
		obstacles.append(enemy)
	if enemy.is_elite:
		ctx.events.elite_spawned.emit(enemy)
	return enemy


func spawn_boss(data: BossData, pos: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.boss_data = data
	enemy.is_boss = true
	enemy.position = pos
	enemy.max_hp = data.max_hp * ctx.difficulty.enemy_hp_mult
	enemy.hp = enemy.max_hp
	enemy.base_defense = data.defense
	enemy.radius = data.radius
	enemy.contact_damage = data.damage * ctx.difficulty.enemy_damage_mult
	enemy.move_speed = data.move_speed
	enemy.visual = EntityVisual.new()
	enemy.add_child(enemy.visual)
	enemy.visual.setup(data.visual)
	enemy.visual.scale = Vector2.ONE * data.visual_scale
	enemy.visual.bob_amount = 0.03
	add_child(enemy)
	list.append(enemy)
	grid.insert(enemy, enemy.position)
	return enemy


func step(delta: float) -> void:
	_frame += 1
	var player: Player = ctx.player
	var player_pos: Vector2 = player.global_position
	var player_alive: bool = player.alive
	var player_radius: float = player.radius
	var dot_mults: Dictionary = ctx.status_system.dot_multipliers()
	var view: Rect2 = _view_rect()
	var arena: Rect2 = ctx.arena_rect()
	var contact_interval: float = ctx.balance.contact_damage_interval
	var parity: int = _frame % 2
	var drifting: bool = ctx.flood != null or (ctx.terrain != null and not ctx.arena.currents.is_empty())
	if ctx.flow != null:
		_flow_timer -= delta
		if _flow_timer <= 0.0:
			_flow_timer = FLOW_REFRESH
			ctx.flow.update(player_pos)
	var count: int = list.size()
	for i: int in count:
		var enemy: Enemy = list[i]
		if not enemy.alive:
			continue
		if enemy.invulnerable_time > 0.0:
			enemy.invulnerable_time = maxf(enemy.invulnerable_time - delta, 0.0)
		if enemy.touch_cooldown > 0.0:
			enemy.touch_cooldown -= delta
		if not enemy.statuses.is_empty():
			for dot: Array in enemy.statuses.tick(delta, dot_mults):
				_apply_dot(enemy, dot)
			if not enemy.alive:
				continue
		if enemy.is_obstacle:
			continue
		if not enemy.is_boss:
			_tick_brain(enemy, delta, player_pos)
			# Séparation : une moitié des ennemis par frame (alternance), correction complète.
			if i % 2 == parity:
				_separate(enemy)
		var pos: Vector2 = enemy.position
		if drifting and not enemy.is_boss:
			# Courants et crues : les Corrompus lourds (résistance au recul) dérivent moins.
			pos += ctx.terrain_drift(pos) * (1.0 - enemy.data_knockback_resist() * 0.5) * delta
		if enemy.push_velocity.length_squared() > 1.0:
			pos += enemy.push_velocity * delta
			enemy.push_velocity *= maxf(1.0 - 8.0 * delta, 0.0)
		var r: float = enemy.radius
		if not enemy.is_boss:
			pos = ctx.obstacles.push_out(pos, r)
		pos = pos.clamp(arena.position + Vector2(r, r), arena.end - Vector2(r, r))
		enemy.position = pos
		if player_alive and enemy.touch_cooldown <= 0.0 and enemy.contact_damage > 0.0:
			var reach: float = r + player_radius
			if pos.distance_squared_to(player_pos) < reach * reach:
				enemy.touch_cooldown = contact_interval
				if not misses(enemy):
					ctx.combat.damage_player(enemy.contact_damage, enemy.data.id if enemy.data else &"boss")
		if view.has_point(pos):
			enemy.visual.set_facing_left(enemy.velocity.x < -1.0)
			enemy.visual.tick(delta, enemy.velocity.length_squared() > 4.0, enemy.velocity.length())
	if _dirty_removal:
		_remove_dead()
	rebuild_grid()
	queue_redraw()
	_overlay.queue_redraw()


## Ennemi aveuglé : son attaque rate (contact ou tir).
func misses(enemy: Enemy) -> bool:
	var chance: float = enemy.statuses.miss_chance()
	return chance > 0.0 and ctx.rng.randf() < chance


## Reconstruit la grille après les déplacements et les retraits : elle ne référence jamais un ennemi libéré.
func rebuild_grid() -> void:
	grid.clear()
	for enemy: Enemy in list:
		if enemy.alive:
			grid.insert(enemy, enemy.position)


func _apply_dot(enemy: Enemy, dot: Array) -> void:
	var source_id: StringName = dot[1]
	var kind := DamageInfo.SourceKind.PLAYER if source_id == &"player" else DamageInfo.SourceKind.ALLY
	var tags: Array[StringName] = [DamageInfo.TAG_DOT]
	var info := DamageInfo.make(float(dot[0]), kind, source_id, tags)
	ctx.combat.deal_damage(enemy, info)


func _tick_brain(enemy: Enemy, delta: float, player_pos: Vector2) -> void:
	var target_pos: Vector2 = player_pos
	if enemy.taunt_time > 0.0 and is_instance_valid(enemy.taunt_target):
		enemy.taunt_time -= delta
		target_pos = enemy.taunt_target.global_position
	var to_target: Vector2 = target_pos - enemy.position
	var dist: float = to_target.length()
	var dir: Vector2 = to_target / maxf(dist, 0.001)
	# Déplacement : pente de la carte de flux vers le Chasseur (contourne le décor) ; visée : ligne droite (dir).
	var nav: Vector2 = dir
	if ctx.flow != null and target_pos == player_pos:
		nav = ctx.flow.direction(enemy.position, dir)
	elif enemy.goal_flow != null and target_pos != player_pos:
		nav = enemy.goal_flow.direction(enemy.position, dir)
	var speed: float = enemy.move_speed * enemy.statuses.speed_mult() * hunt_speed_mult * ctx.terrain_speed(enemy.position)
	match enemy.data.brain:
		EnemyData.Brain.CHASER:
			enemy.velocity = nav * speed
		EnemyData.Brain.RANGED:
			_tick_ranged(enemy, delta, dir, nav, dist, speed)
		EnemyData.Brain.CHARGER:
			_tick_charger(enemy, delta, dir, nav, dist, speed)
		EnemyData.Brain.SUMMONER:
			_tick_summoner(enemy, delta, dir, nav, dist, speed)
		EnemyData.Brain.BLINKER:
			_tick_blinker(enemy, delta, dir, nav, dist, speed, target_pos)
		EnemyData.Brain.WARDEN:
			_tick_warden(enemy, delta, dir, nav, dist, speed)
	enemy.position += enemy.velocity * delta


func _tick_ranged(enemy: Enemy, delta: float, dir: Vector2, nav: Vector2, dist: float, speed: float) -> void:
	var attack: AttackData = enemy.data.attack
	var keep: float = float(attack.params.get("keep_distance", 260.0))
	if enemy.state == Enemy.State.WINDUP:
		enemy.velocity = Vector2.ZERO
		enemy.state_timer -= delta
		if enemy.state_timer <= 0.0:
			enemy.state = Enemy.State.MOVE
			var dmg: float = attack.damage * enemy.contact_damage / maxf(enemy.data.damage, 0.001)
			if not misses(enemy):
				ctx.projectiles.spawn_hostile(enemy.position, enemy.aim_dir, attack.projectile_speed, dmg, enemy.data.id, 7.0)
		return
	if dist > keep + 40.0:
		enemy.velocity = nav * speed
	elif dist < keep - 40.0:
		enemy.velocity = -dir * speed * 0.8
	else:
		enemy.velocity = dir.orthogonal() * speed * 0.4
	enemy.attack_timer -= delta
	if enemy.attack_timer <= 0.0 and dist < attack.attack_range:
		enemy.attack_timer = attack.cooldown
		enemy.state = Enemy.State.WINDUP
		enemy.state_timer = float(attack.params.get("windup", 0.35))
		enemy.aim_dir = dir
		enemy.visual.play_action(&"attack")
		enemy.visual.flash()


func _tick_charger(enemy: Enemy, delta: float, dir: Vector2, nav: Vector2, dist: float, speed: float) -> void:
	var attack: AttackData = enemy.data.attack
	match enemy.state:
		Enemy.State.MOVE:
			enemy.velocity = nav * speed
			enemy.attack_timer -= delta
			if enemy.attack_timer <= 0.0 and dist < attack.attack_range:
				enemy.state = Enemy.State.WINDUP
				enemy.state_timer = float(attack.params.get("windup", 0.6))
				enemy.aim_dir = dir
				var length: float = float(attack.params.get("charge_speed", 420.0)) * float(attack.params.get("charge_time", 0.45))
				ctx.fx.danger_line(enemy.position, enemy.position + dir * length, enemy.radius * 1.6, enemy.state_timer)
		Enemy.State.WINDUP:
			enemy.velocity = Vector2.ZERO
			enemy.state_timer -= delta
			if enemy.state_timer <= 0.0:
				enemy.state = Enemy.State.CHARGE
				enemy.state_timer = float(attack.params.get("charge_time", 0.45))
		Enemy.State.CHARGE:
			enemy.velocity = enemy.aim_dir * float(attack.params.get("charge_speed", 420.0)) * enemy.statuses.speed_mult()
			enemy.state_timer -= delta
			if enemy.state_timer <= 0.0:
				enemy.state = Enemy.State.RECOVER
				enemy.state_timer = 0.5
		Enemy.State.RECOVER:
			enemy.velocity = nav * speed * 0.3
			enemy.state_timer -= delta
			if enemy.state_timer <= 0.0:
				enemy.state = Enemy.State.MOVE
				enemy.attack_timer = attack.cooldown


## Invocatrice : garde ses distances et fait éclore des Corrompus (plafonné).
func _tick_summoner(enemy: Enemy, delta: float, dir: Vector2, nav: Vector2, dist: float, speed: float) -> void:
	var attack: AttackData = enemy.data.attack
	var keep: float = float(attack.params.get("keep_distance", 240.0))
	enemy.velocity = nav * speed if dist > keep else -dir * speed * 0.5
	enemy.attack_timer -= delta
	if enemy.attack_timer > 0.0:
		return
	enemy.attack_timer = attack.cooldown
	var spawned: EnemyData = GameDB.enemy(StringName(attack.params.get("enemy", "skitterling")))
	if spawned == null or list.size() >= ctx.spawner.current_cap():
		return
	for i: int in int(attack.params.get("count", 3)):
		spawn(spawned, enemy.position + Vector2.RIGHT.rotated(TAU * i / 3.0 + ctx.rng.randf()) * (enemy.radius + 14.0))
	ctx.fx.ring(enemy.position, enemy.radius * 1.6, Color(0.8, 0.4, 0.9, 0.6), 0.3)


## Rôdeur : se fige, télégraphie un point derrière le Chasseur puis s'y téléporte.
func _tick_blinker(enemy: Enemy, delta: float, dir: Vector2, nav: Vector2, dist: float, speed: float,
		target_pos: Vector2) -> void:
	var attack: AttackData = enemy.data.attack
	match enemy.state:
		Enemy.State.MOVE:
			enemy.velocity = nav * speed
			enemy.attack_timer -= delta
			if enemy.attack_timer <= 0.0 and dist < attack.attack_range and dist > 90.0:
				enemy.state = Enemy.State.WINDUP
				enemy.state_timer = float(attack.params.get("windup", 0.6))
				enemy.aim_dir = target_pos + dir * float(attack.params.get("behind", 70.0))
				ctx.fx.ring(enemy.aim_dir, enemy.radius + 8.0, Color(1.0, 0.25, 0.6, 0.9), enemy.state_timer)
				enemy.visual.modulate.a = 0.45
		Enemy.State.WINDUP:
			enemy.velocity = Vector2.ZERO
			enemy.state_timer -= delta
			if enemy.state_timer <= 0.0:
				enemy.position = enemy.aim_dir
				enemy.state = Enemy.State.RECOVER
				enemy.state_timer = 0.4
				enemy.visual.modulate.a = 1.0
				ctx.fx.burst(enemy.position, enemy.radius * 1.5, Color(0.6, 0.2, 0.8, 0.5))
		_:
			enemy.velocity = Vector2.ZERO
			enemy.state_timer -= delta
			if enemy.state_timer <= 0.0:
				enemy.state = Enemy.State.MOVE
				enemy.attack_timer = attack.cooldown


## Gardien : avance derrière les autres et protège ses alliés proches (statut « Égide »).
func _tick_warden(enemy: Enemy, delta: float, _dir: Vector2, nav: Vector2, dist: float, speed: float) -> void:
	var attack: AttackData = enemy.data.attack
	enemy.velocity = nav * speed if dist > float(attack.params.get("keep_distance", 160.0)) else Vector2.ZERO
	enemy.attack_timer -= delta
	if enemy.attack_timer > 0.0:
		return
	enemy.attack_timer = attack.cooldown
	for other: Enemy in query_radius(enemy.position, attack.radius):
		if other != enemy and not other.is_boss:
			ctx.status_system.apply(other, &"warded", 1, enemy.data.id)


func _separate(enemy: Enemy) -> void:
	var pos: Vector2 = enemy.position
	var radius: float = enemy.radius
	var checks: int = 0
	for item: Variant in grid.cell_at(pos):
		var other: Enemy = item
		if other == enemy:
			continue
		checks += 1
		if checks > SEPARATION_CHECKS:
			break
		var offset: Vector2 = pos - other.position
		var min_dist: float = radius + other.radius
		var d2: float = offset.length_squared()
		if d2 < min_dist * min_dist and other.alive:
			var d: float = sqrt(d2)
			var push_dir: Vector2 = offset / d if d > 0.01 else Vector2.RIGHT.rotated(float(enemy.get_instance_id() % 628) / 100.0)
			var share: float = 1.0 if (other.is_obstacle or other.is_boss) else 0.5
			pos += push_dir * (min_dist - d) * share
	enemy.position = pos


## Appelé par CombatSystem quand un ennemi meurt (après l'émission de enemy_killed).
func on_enemy_died(enemy: Enemy, info: DamageInfo) -> void:
	_dirty_removal = true
	var pos: Vector2 = enemy.position
	var tint: Color = enemy.data.visual.primary.lightened(0.3) if enemy.data else Color(0.8, 0.5, 1.0)
	ctx.fx.debris(pos, tint, 14 if (enemy.is_elite or enemy.is_boss) else 4)
	if enemy.is_elite or enemy.is_boss:
		ctx.fx.burst(pos, enemy.radius * 1.6, Color(0.75, 0.45, 1.0, 0.45))
		ctx.root.hitstop(0.06 if enemy.is_elite else 0.35)
	Audio.play_sfx(&"enemy_death")
	if enemy.is_boss:
		ctx.stats.add(&"bosses_killed")
		ctx.stats.add(StringName("boss_%s_killed" % enemy.boss_data.id))
		ctx.events.boss_defeated.emit(enemy)
		return
	# Campagne (jalons) : pas d'XP à ramasser.
	var drops_xp: bool = not ctx.milestones()
	if enemy.is_obstacle:
		if drops_xp:
			ctx.pickups.spawn_xp(pos, enemy.xp_value)
		return
	ctx.stats.add(StringName("kills_" + enemy.data.id))
	if drops_xp:
		ctx.pickups.spawn_xp(pos, enemy.xp_value)
	ctx.stats.add(&"shards_earned_raw", ctx.balance.shards_per_kill)
	var heal_chance: float = ctx.balance.heal_drop_chance
	if ctx.player.hp < ctx.player.max_hp * ctx.balance.heal_low_hp_ratio:
		heal_chance *= ctx.balance.heal_low_hp_mult
	if (enemy.is_elite and ctx.balance.elite_heal_drop) or ctx.rng.randf() < heal_chance:
		ctx.pickups.spawn_heal(pos + Vector2(10, 6))
	if enemy.is_elite:
		ctx.stats.add(&"elites_killed")
		ctx.stats.add(&"shards_earned_raw", ctx.balance.shards_per_elite)
		if ctx.arena.milestone_on_elite:
			ctx.events.milestone_reached.emit()
		ctx.stats.add(&"essence_earned_raw", ctx.balance.essence_per_elite + ctx.player.stats.get_value(StatKeys.ESSENCE_GAIN))
		ctx.pickups.spawn_chest(pos)
		_maybe_spawn_capture(pos)
		for affix: EliteAffixData in enemy.affixes:
			_on_affix_death(enemy, affix, info)


func _on_affix_death(enemy: Enemy, affix: EliteAffixData, _info: DamageInfo) -> void:
	match affix.on_death:
		&"explode":
			var radius: float = float(affix.params.get("radius", 90.0))
			var damage: float = float(affix.params.get("damage", 20.0)) * ctx.difficulty.enemy_damage_mult
			ctx.hazards.add_circle(enemy.position, radius, float(affix.params.get("delay", 0.9)), damage, true, &"volatile")
		&"split":
			var child: EnemyData = GameDB.enemy(StringName(affix.params.get("enemy", "skitterling")))
			if child:
				for i: int in int(affix.params.get("count", 3)):
					spawn(child, enemy.position + Vector2.RIGHT.rotated(TAU * i / 3.0) * 20.0)


## Rite de lien : un Écho errant peut apparaître à la mort d'une élite (capture en restant à son contact).
func _maybe_spawn_capture(pos: Vector2) -> void:
	if ctx.rng.randf() > ctx.balance.capture_chance:
		return
	var candidates: Array[StringName] = []
	var weights: Array[float] = []
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		if ctx.has_monster(id) or ctx.build.captures.has(id):
			continue
		candidates.append(id)
		weights.append(1.0 if ctx.setup.unlocked_monsters.has(id) else ctx.balance.capture_locked_weight)
	if candidates.is_empty():
		return
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = ctx.rng.randf() * total
	for i: int in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			ctx.pickups.spawn_capture(pos + Vector2(30, 0), candidates[i])
			return


func _remove_dead() -> void:
	_dirty_removal = false
	var kept: Array[Enemy] = []
	for enemy: Enemy in list:
		if enemy.alive:
			kept.append(enemy)
		elif enemy.is_boss:
			# Le boss reste en mémoire (ctx.boss) mais quitte la simulation ; son animation de mort reste visible.
			enemy.visible = enemy.visual.has_animation(&"death")
			enemy.visual.play_action(&"death")
		else:
			if enemy.is_obstacle:
				obstacles.erase(enemy)
			enemy.queue_free()
	list = kept


func clear_all() -> void:
	for enemy: Enemy in list:
		if not enemy.is_boss:
			enemy.alive = false
	_dirty_removal = true


func _view_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size
	var center: Vector2 = ctx.player.global_position
	return Rect2(center - size * 0.6, size * 1.2)


func _draw() -> void:
	# Halos sous les élites et le boss (lisibilité de la menace).
	for enemy: Enemy in list:
		if enemy.alive and (enemy.is_elite or enemy.is_boss):
			var color := Color(1.0, 0.35, 0.8, 0.55) if enemy.is_boss else Color(1.0, 0.75, 0.25, 0.6)
			draw_arc(enemy.position + Vector2(0, enemy.radius * 0.3), enemy.radius + 6.0, 0.0, TAU, 40, color, 3.0)
		if enemy.alive and enemy.data and enemy.data.brain == EnemyData.Brain.WARDEN:
			draw_arc(enemy.position, enemy.data.attack.radius, 0.0, TAU, 48, Color(0.55, 0.75, 1.0, 0.35), 2.0)
		if enemy.alive and enemy.absorb_radius > 0.0:
			draw_circle(enemy.position, enemy.absorb_radius, Color(0.35, 0.1, 0.6, 0.25))
			draw_arc(enemy.position, enemy.absorb_radius, 0.0, TAU, 64, Color(0.85, 0.5, 1.0, 0.8), 3.0)


func _draw_overlay() -> void:
	# Marqueurs de statuts au-dessus des ennemis visibles (Fracture, Marques, Brûlure, Entrave).
	var view: Rect2 = _view_rect()
	if ctx.setup.info_unlocks.has("affixes"):
		var font: Font = ThemeDB.fallback_font
		for enemy: Enemy in list:
			if enemy.alive and enemy.is_elite and view.has_point(enemy.position):
				var names: PackedStringArray = []
				for affix: EliteAffixData in enemy.affixes:
					names.append(tr(affix.name_key))
				var top: Vector2 = enemy.position + Vector2(-60, -enemy.radius - 18.0)
				_overlay.draw_string_outline(font, top, " · ".join(names), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 3, Color.BLACK)
				_overlay.draw_string(font, top, " · ".join(names), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1.0, 0.8, 0.4))
	for enemy: Enemy in list:
		if not enemy.alive or enemy.statuses.is_empty() or not view.has_point(enemy.position):
			continue
		var top: Vector2 = enemy.position + Vector2(0, -enemy.radius - 7.0)
		var x: float = -8.0
		if enemy.statuses.has(&"fracture"):
			_overlay.draw_line(top + Vector2(x - 3, -3), top + Vector2(x + 3, 3), Color(1.0, 0.55, 0.15), 2.0)
			_overlay.draw_line(top + Vector2(x + 3, -3), top + Vector2(x - 1, 2), Color(1.0, 0.55, 0.15), 2.0)
			x += 8.0
		var marks: int = enemy.statuses.get_stacks(&"mark")
		for m: int in mini(marks, 8):
			_overlay.draw_circle(top + Vector2(x + m * 5.0, 0), 2.2, Color(0.55, 0.95, 1.0))
		if marks > 0:
			x += mini(marks, 8) * 5.0 + 3.0
		if enemy.statuses.has(&"burn"):
			_overlay.draw_circle(top + Vector2(x, 0), 3.0, Color(1.0, 0.4, 0.1))
			x += 7.0
		if enemy.statuses.has(&"slow"):
			_overlay.draw_circle(top + Vector2(x, 0), 3.0, Color(0.6, 0.7, 1.0))
			x += 7.0
		if enemy.statuses.has(&"root"):
			_overlay.draw_rect(Rect2(top + Vector2(x - 3, -3), Vector2(6, 6)), Color(0.45, 0.85, 0.35))
			x += 8.0
		if enemy.statuses.has(&"static"):
			_overlay.draw_line(top + Vector2(x - 3, -3), top + Vector2(x + 3, 3), Color(1.0, 0.95, 0.4), 2.0)
			x += 8.0
		if enemy.statuses.has(&"warded"):
			_overlay.draw_arc(top + Vector2(x, 0), 4.0, 0.0, TAU, 12, Color(0.55, 0.75, 1.0), 2.0)
