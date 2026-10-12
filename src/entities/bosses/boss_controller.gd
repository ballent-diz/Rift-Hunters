class_name BossController
extends RefCounted
## Pilote un Dévoreur : phases, choix d'attaques pondéré, mécaniques (absorption, cœur exposé, cristaux).
## Chaque attaque est une méthode _pattern_<kind> paramétrée par BossPatternData.

var ctx: RunContext
var boss: Enemy
var data: BossData
var phase_index: int = 0
var heart_time: float = 0.0
var absorb_time: float = 0.0
var busy_time: float = 0.0
var crystals: Array[Enemy] = []
var enraged: bool = false
var _next_pattern_time: float = 0.0
var _ready_at: Dictionary = {}
var _scheduled: Array[Dictionary] = []
var _crystal_pulse: float = 4.0
var _fight_time: float = 0.0
var _charge_time: float = 0.0
var _charge_dir := Vector2.ZERO
var _charge_speed: float = 0.0


func _init(p_ctx: RunContext, p_boss: Enemy) -> void:
	ctx = p_ctx
	boss = p_boss
	data = boss.boss_data
	_next_pattern_time = ctx.time + 2.5


func phase() -> BossPhaseData:
	return data.phases[phase_index]


func phase_threshold(index: int) -> float:
	var threshold: float = data.phases[index].hp_threshold
	if index == 1 and ctx.difficulty.boss_phase2_threshold > 0.0:
		threshold = ctx.difficulty.boss_phase2_threshold
	return threshold


func schedule(delay: float, action: Callable) -> void:
	_scheduled.append({"time": ctx.time + delay, "action": action})


func step(delta: float) -> void:
	if not boss.alive:
		return
	_run_scheduled()
	_fight_time += delta
	if not enraged and _fight_time >= ctx.balance.boss_enrage_time:
		enraged = true
		boss.contact_damage *= ctx.balance.boss_enrage_damage_mult
		boss.move_speed *= ctx.balance.boss_enrage_speed_mult
		boss.visual.set_tint(Color(1.0, 0.55, 0.55))
		ctx.events.event_started.emit("BOSS_ENRAGED")
	heart_time = maxf(heart_time - delta, 0.0)
	boss.extra_damage_taken = 2.0 if heart_time > 0.0 else 1.0
	if absorb_time > 0.0:
		absorb_time -= delta
		if absorb_time <= 0.0:
			_release_absorbed()
	_check_phase()
	busy_time = maxf(busy_time - delta, 0.0)
	var to_player: Vector2 = ctx.player.global_position - boss.position
	if _charge_time > 0.0:
		_charge_time -= delta
		boss.velocity = _charge_dir * _charge_speed
		boss.position += boss.velocity * delta
		var rect: Rect2 = ctx.arena_rect().grow(-boss.radius)
		boss.position = boss.position.clamp(rect.position, rect.end)
	elif busy_time <= 0.0 and boss.invulnerable_time <= 0.0 and absorb_time <= 0.0:
		if to_player.length() > boss.radius + 40.0:
			boss.velocity = to_player.normalized() * boss.move_speed * phase().move_speed_mult * boss.statuses.speed_mult()
			boss.position += boss.velocity * delta
		else:
			boss.velocity = Vector2.ZERO
	else:
		boss.velocity = Vector2.ZERO
	boss.visual.set_facing_left(to_player.x < 0.0)
	boss.visual.tick(delta, boss.velocity.length() > 2.0)
	_pulse_crystals(delta)
	if busy_time <= 0.0 and absorb_time <= 0.0 and boss.invulnerable_time <= 0.0 and ctx.time >= _next_pattern_time:
		var pattern: BossPatternData = _choose_pattern(to_player.length())
		if pattern:
			_ready_at[pattern.kind] = ctx.time + pattern.cooldown
			Audio.play_sfx(&"boss_telegraph")
			call("_pattern_" + String(pattern.kind), pattern)
			ctx.stats.add(&"boss_patterns")
		_next_pattern_time = ctx.time + phase().pattern_interval * (0.7 if enraged else 1.0)


func _run_scheduled() -> void:
	var i: int = _scheduled.size() - 1
	while i >= 0:
		if ctx.time >= float(_scheduled[i]["time"]):
			var action: Callable = _scheduled[i]["action"]
			_scheduled.remove_at(i)
			if boss.alive:
				action.call()
		i -= 1


func _check_phase() -> void:
	var next: int = phase_index + 1
	if next >= data.phases.size():
		return
	if boss.hp / boss.max_hp > phase_threshold(next):
		return
	phase_index = next
	var p: BossPhaseData = phase()
	if p.defense_override >= 0.0:
		boss.base_defense = p.defense_override
	boss.invulnerable_time = p.transition_time
	absorb_time = 0.0
	boss.absorb_radius = 0.0
	busy_time = p.transition_time
	_next_pattern_time = ctx.time + p.transition_time + 1.0
	ctx.hazards.add_ring(boss.position, 520.0, 700.0, 30.0, 10.0 * ctx.difficulty.enemy_damage_mult, true, data.id,
		[ctx.rng.randf() * TAU], 0.5, [], p.transition_time * 0.5)
	ctx.fx.burst(boss.position, boss.radius * 2.0, Color(0.8, 0.3, 1.0, 0.5))
	ctx.events.boss_phase_changed.emit(phase_index)


func _choose_pattern(distance: float) -> BossPatternData:
	var options: Array[BossPatternData] = []
	var total: float = 0.0
	for pattern: BossPatternData in phase().patterns:
		if ctx.time < float(_ready_at.get(pattern.kind, 0.0)):
			continue
		if pattern.kind == &"claw" and distance > float(pattern.params.get("range", 200.0)):
			continue
		options.append(pattern)
		total += pattern.weight
	if options.is_empty():
		return null
	var roll: float = ctx.rng.randf() * total
	for pattern: BossPatternData in options:
		roll -= pattern.weight
		if roll <= 0.0:
			return pattern
	return options.back()


func _damage(pattern: BossPatternData) -> float:
	return pattern.damage * ctx.difficulty.enemy_damage_mult * (ctx.balance.boss_enrage_damage_mult if enraged else 1.0)


## Griffe du vide : frappe télégraphiée devant le boss.
func _pattern_claw(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var radius: float = float(pattern.params.get("radius", 110.0))
	ctx.hazards.add_circle(boss.position + dir * boss.radius * 0.9, radius, pattern.telegraph, _damage(pattern), true, data.id)
	busy_time = pattern.telegraph + 0.3


## Vague d'ombres : anneau(x) en expansion avec brèches sûres.
func _pattern_shadow_wave(pattern: BossPatternData) -> void:
	var waves: int = int(pattern.params.get("waves", 1))
	for w: int in waves:
		schedule(w * float(pattern.params.get("wave_gap", 0.9)), func() -> void:
			var gaps: Array = []
			for g: int in int(pattern.params.get("gaps", 2)):
				gaps.append(ctx.rng.randf() * TAU)
			ctx.hazards.add_ring(boss.position, float(pattern.params.get("speed", 230.0)), 1000.0,
				float(pattern.params.get("thickness", 26.0)), _damage(pattern), true, data.id, gaps,
				float(pattern.params.get("gap_width", 0.38)), [], pattern.telegraph)
		)
	busy_time = pattern.telegraph + 0.4


## Invocation : portails télégraphiés puis apparition de Corrompus.
func _pattern_summon(pattern: BossPatternData) -> void:
	var enemy_ids: Array = pattern.params.get("enemies", ["skitterling"])
	var count: int = mini(int(pattern.params.get("count", 6)), ctx.spawner.current_cap() - ctx.enemies.count())
	if count <= 0:
		return
	for i: int in count:
		var pos: Vector2 = boss.position + Vector2.RIGHT.rotated(TAU * i / count + ctx.rng.randf()) * (boss.radius + 70.0)
		ctx.fx.ring(pos, 22.0, Color(0.8, 0.3, 1.0, 0.8), pattern.telegraph)
		var id: StringName = StringName(enemy_ids[i % enemy_ids.size()])
		schedule(pattern.telegraph, func() -> void:
			var enemy: EnemyData = GameDB.enemy(id)
			if enemy:
				ctx.enemies.spawn(enemy, pos)
		)
	busy_time = pattern.telegraph + 0.2


## Absorption : avale les projectiles alliés, puis les recrache et expose son cœur.
func _pattern_absorb(pattern: BossPatternData) -> void:
	absorb_time = float(pattern.params.get("duration", 4.0))
	boss.absorb_radius = float(pattern.params.get("radius", 150.0))
	boss.absorbed_count = 0
	busy_time = absorb_time
	_ready_at[&"absorb_release"] = pattern.damage


func _release_absorbed() -> void:
	boss.absorb_radius = 0.0
	var count: int = clampi(boss.absorbed_count / 2 + 6, 6, 28)
	var damage: float = float(_ready_at.get(&"absorb_release", 12.0)) * ctx.difficulty.enemy_damage_mult
	var offset: float = ctx.rng.randf() * TAU
	for i: int in count:
		var dir := Vector2.RIGHT.rotated(offset + TAU * i / count)
		ctx.projectiles.spawn_hostile(boss.position + dir * boss.radius, dir, 170.0, damage, data.id, 9.0, 6.0)
	ctx.stats.set_max(&"boss_absorbed_max", float(boss.absorbed_count))
	heart_time = 3.0
	Audio.play_sfx(&"heart_exposed")
	ctx.fx.text(boss.position + Vector2(0, -boss.radius - 20.0), tr("BOSS_HEART_EXPOSED"), Color(1.0, 0.8, 1.0))
	ctx.fx.burst(boss.position, boss.radius * 0.6, Color(1.0, 0.6, 1.0, 0.5))


## Rayon du vide : laser télégraphié verrouillé sur la position du Chasseur.
func _pattern_void_beam(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var beams: int = int(pattern.params.get("beams", 1))
	for b: int in beams:
		var angle: float = (b - (beams - 1) * 0.5) * float(pattern.params.get("spread", 0.5))
		ctx.hazards.add_beam(boss.position, dir.rotated(angle), float(pattern.params.get("length", 950.0)),
			float(pattern.params.get("width", 34.0)), pattern.telegraph, float(pattern.params.get("duration", 1.2)),
			_damage(pattern), data.id)
	busy_time = pattern.telegraph + float(pattern.params.get("duration", 1.2))


## Cristaux de faille : obstacles destructibles qui pulsent (l'arène change).
func _pattern_crystals(pattern: BossPatternData) -> void:
	var crystal: EnemyData = GameDB.enemy(StringName(pattern.params.get("enemy", "rift_crystal")))
	if crystal == null:
		return
	var count: int = int(pattern.params.get("count", 4))
	var player_pos: Vector2 = ctx.player.global_position
	for i: int in count:
		var pos: Vector2 = player_pos + Vector2.RIGHT.rotated(TAU * i / count + ctx.rng.randf()) * ctx.rng.randf_range(180.0, 300.0)
		pos = pos.clamp(ctx.arena_rect().position + Vector2(60, 60), ctx.arena_rect().end - Vector2(60, 60))
		ctx.fx.ring(pos, 30.0, Color(0.8, 0.4, 1.0, 0.9), pattern.telegraph)
		schedule(pattern.telegraph, func() -> void:
			if crystals.size() < int(pattern.params.get("max", 8)):
				crystals.append(ctx.enemies.spawn(crystal, pos))
		)
	_ready_at[&"crystal_damage"] = pattern.damage
	busy_time = pattern.telegraph


func _pulse_crystals(delta: float) -> void:
	crystals.assign(crystals.filter(func(c: Variant) -> bool: return is_instance_valid(c) and (c as Enemy).alive))
	if crystals.is_empty():
		return
	_crystal_pulse -= delta
	if _crystal_pulse > 0.0:
		return
	_crystal_pulse = 4.0
	var damage: float = float(_ready_at.get(&"crystal_damage", 12.0)) * ctx.difficulty.enemy_damage_mult
	for crystal: Enemy in crystals:
		ctx.hazards.add_circle(crystal.position, 95.0, 1.1, damage, true, &"rift_crystal")


## Pluie de roches : impacts télégraphiés en salves autour du Chasseur.
func _pattern_rock_rain(pattern: BossPatternData) -> void:
	var waves: int = int(pattern.params.get("waves", 3))
	var per_wave: int = int(pattern.params.get("count", 6))
	var radius: float = float(pattern.params.get("radius", 70.0))
	for w: int in waves:
		schedule(w * float(pattern.params.get("wave_gap", 0.6)), func() -> void:
			var center: Vector2 = ctx.player.global_position
			for i: int in per_wave:
				var offset := Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * ctx.rng.randf_range(0.0, 260.0)
				if i == 0:
					offset = Vector2.ZERO
				ctx.hazards.add_circle(center + offset, radius, pattern.telegraph, _damage(pattern), true, data.id)
		)
	busy_time = 0.6


## Charge : ligne télégraphiée puis ruée à travers l'arène.
func _pattern_charge(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var speed: float = float(pattern.params.get("speed", 620.0))
	var duration: float = float(pattern.params.get("duration", 0.9))
	ctx.fx.danger_line(boss.position, boss.position + dir * speed * duration, boss.radius * 1.6, pattern.telegraph)
	busy_time = pattern.telegraph + duration
	schedule(pattern.telegraph, func() -> void:
		_charge_dir = dir
		_charge_speed = speed
		_charge_time = duration
	)


## Séisme : anneaux sans brèche, à franchir avec la Ruée (invulnérabilité).
func _pattern_quake(pattern: BossPatternData) -> void:
	for w: int in int(pattern.params.get("waves", 1)):
		schedule(w * float(pattern.params.get("wave_gap", 0.8)), func() -> void:
			ctx.hazards.add_ring(boss.position, float(pattern.params.get("speed", 200.0)), 900.0,
				float(pattern.params.get("thickness", 18.0)), _damage(pattern), true, data.id, [], 0.0, [], pattern.telegraph)
		)
	busy_time = pattern.telegraph + 0.3
