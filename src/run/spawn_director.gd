class_name SpawnDirector
extends RefCounted
## Fait apparaître les vagues (données de l'arène), les élites et le boss.

## Marge au bord d'une zone infranchissable pour un point d'apparition.
const SPAWN_CLEARANCE := 20.0

var ctx: RunContext
var boss_spawned: bool = false
var _budget: float = 0.0
var _next_elite_time: float = 0.0


func _init(p_ctx: RunContext) -> void:
	ctx = p_ctx
	_next_elite_time = ctx.arena.elite_first_time


func current_wave() -> WavePhaseData:
	var current: WavePhaseData = null
	for wave: WavePhaseData in ctx.arena.waves:
		if ctx.time >= wave.start_time:
			current = wave
	return current


func step(delta: float) -> void:
	var wave: WavePhaseData = current_wave()
	if wave == null:
		return
	var rate: float = wave.spawn_rate * ctx.difficulty.spawn_rate_mult * (0.35 if boss_spawned else 1.0)
	var cap: int = current_cap()
	_budget = minf(_budget + rate * delta, 6.0)
	var alive: int = ctx.enemies.count()
	while _budget >= 1.0 and alive < cap:
		_budget -= 1.0
		var data: EnemyData = pick_enemy(wave)
		if data:
			ctx.enemies.spawn(data, spawn_position())
			alive += 1
	if not boss_spawned and ctx.time >= _next_elite_time:
		_next_elite_time += ctx.arena.elite_interval * ctx.difficulty.elite_interval_mult
		spawn_elite()
	if not boss_spawned and ctx.time >= ctx.arena.boss_time:
		spawn_boss()


## Densité maximale autorisée en ce moment (vague en cours, réduite pendant le boss).
func current_cap() -> int:
	var wave: WavePhaseData = current_wave()
	var cap: int = mini(wave.max_alive if wave else 80, ctx.balance.max_enemies_hard_cap)
	return mini(cap, ctx.balance.boss_fight_enemy_cap) if boss_spawned else cap


func pick_enemy(wave: WavePhaseData) -> EnemyData:
	var total: float = 0.0
	for i: int in wave.enemies.size():
		total += wave.weights[i] if i < wave.weights.size() else 1.0
	var roll: float = ctx.rng.randf() * total
	for i: int in wave.enemies.size():
		roll -= wave.weights[i] if i < wave.weights.size() else 1.0
		if roll <= 0.0:
			return GameDB.enemy(wave.enemies[i])
	return GameDB.enemy(wave.enemies.back()) if not wave.enemies.is_empty() else null


func spawn_position() -> Vector2:
	var player_pos: Vector2 = ctx.player.global_position
	var rect: Rect2 = ctx.arena_rect().grow(-40.0)
	var best: Vector2 = player_pos
	for attempt: int in 8:
		var angle: float = ctx.rng.randf() * TAU
		var dist: float = ctx.rng.randf_range(ctx.balance.spawn_distance_min, ctx.balance.spawn_distance_max)
		var pos: Vector2 = (player_pos + Vector2.RIGHT.rotated(angle) * dist).clamp(rect.position, rect.end)
		# Map dessinée : on évite d'apparaître au fond d'une zone infranchissable (forêt, eau).
		if ctx.obstacles.blocks(pos, SPAWN_CLEARANCE):
			best = ctx.obstacles.push_out(pos, SPAWN_CLEARANCE)
			continue
		if pos.distance_to(player_pos) >= ctx.balance.spawn_distance_min * 0.8:
			return pos
		best = pos
	return best


func spawn_elite(enemy_id: StringName = &"") -> Enemy:
	var data: EnemyData = GameDB.enemy(enemy_id) if enemy_id != &"" else null
	if data == null:
		var wave: WavePhaseData = current_wave()
		var candidates: Array[EnemyData] = []
		for id: StringName in wave.enemies:
			var e: EnemyData = GameDB.enemy(id)
			if e and e.can_be_elite:
				candidates.append(e)
		if candidates.is_empty():
			return null
		data = candidates[ctx.rng.randi() % candidates.size()]
	var affix_ids: Array[StringName] = GameDB.sorted_ids(GameDB.affixes)
	var chosen: Array[EliteAffixData] = []
	for i: int in mini(ctx.difficulty.elite_affix_count, affix_ids.size()):
		var pick: StringName = affix_ids[ctx.rng.randi() % affix_ids.size()]
		affix_ids.erase(pick)
		chosen.append(GameDB.affix(pick))
	ctx.stats.add(&"elites_spawned")
	return ctx.enemies.spawn(data, spawn_position(), chosen)


func spawn_boss() -> void:
	boss_spawned = true
	var data: BossData = GameDB.boss(ctx.arena.boss_id)
	if data == null:
		push_error("Boss introuvable : %s" % ctx.arena.boss_id)
		return
	var player_pos: Vector2 = ctx.player.global_position
	var rect: Rect2 = ctx.arena_rect().grow(-data.radius - 60.0)
	var pos: Vector2 = (player_pos + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * 380.0).clamp(rect.position, rect.end)
	var boss: Enemy = ctx.enemies.spawn_boss(data, pos)
	ctx.boss = boss
	ctx.events.boss_spawned.emit(boss)
