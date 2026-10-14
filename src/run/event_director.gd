class_name EventDirector
extends RefCounted
## Déclenche les événements de partie (données de l'arène) : nuées, faille instable, chasse aux élites.

var ctx: RunContext
var _done: Dictionary = {}
var _active: Array[Dictionary] = []


func _init(p_ctx: RunContext) -> void:
	ctx = p_ctx


func step(delta: float) -> void:
	if ctx.arena.finale_radii.x > 0 and ctx.time >= ctx.arena.boss_time:
		_active.clear()
		return
	for i: int in ctx.arena.events.size():
		var event: RunEventData = ctx.arena.events[i]
		if not _done.has(i) and ctx.time >= event.time and ctx.boss == null:
			_done[i] = true
			_start(event)
	var j: int = _active.size() - 1
	while j >= 0:
		var active: Dictionary = _active[j]
		active["left"] = float(active["left"]) - delta
		active["next"] = float(active["next"]) - delta
		if float(active["next"]) <= 0.0:
			active["next"] = float(active["interval"])
			_tick_unstable(active)
		if float(active["left"]) <= 0.0:
			_active.remove_at(j)
		j -= 1


func _start(event: RunEventData) -> void:
	ctx.stats.add(&"events_seen")
	ctx.events.event_started.emit(event.name_key)
	var p: Dictionary = event.params
	match event.kind:
		&"swarm_ring":
			var enemy: EnemyData = GameDB.enemy(StringName(p.get("enemy", "skitterling")))
			var count: int = int(p.get("count", 30))
			var radius: float = float(p.get("radius", 420.0))
			var center: Vector2 = ctx.player.global_position
			for i: int in count:
				var pos: Vector2 = center + Vector2.RIGHT.rotated(TAU * i / count) * radius
				pos = pos.clamp(ctx.arena_rect().position + Vector2(30, 30), ctx.arena_rect().end - Vector2(30, 30))
				pos = ctx.obstacles.push_out(pos, 30.0)
				ctx.enemies.spawn(enemy, pos)
		&"unstable_rift":
			_active.append({"left": float(p.get("duration", 30.0)), "interval": float(p.get("interval", 2.0)),
				"next": 0.5, "params": p})
		&"elite_hunt":
			for i: int in int(p.get("count", 2)):
				ctx.spawner.spawn_elite()
		_:
			push_warning("Événement inconnu : %s" % event.kind)


func _tick_unstable(active: Dictionary) -> void:
	var p: Dictionary = active["params"]
	var player_pos: Vector2 = ctx.player.global_position
	for i: int in int(p.get("zones", 3)):
		var offset := Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * ctx.rng.randf_range(0.0, 220.0)
		var damage: float = float(p.get("damage", 14.0)) * ctx.difficulty.enemy_damage_mult
		ctx.hazards.add_circle(player_pos + offset, float(p.get("radius", 70.0)), float(p.get("delay", 1.1)), damage, true,
			&"unstable_rift")
