class_name PickupManager
extends Node2D
## Gemmes d'XP, coffres et soins. Attirés vers le Chasseur dans son rayon de ramassage.

enum Kind { XP, CHEST, HEAL }

const MAX_GEMS := 350

var ctx: RunContext
var items: Array[Dictionary] = []


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	z_index = 1


func spawn_xp(pos: Vector2, value: int) -> void:
	if value <= 0:
		return
	if items.size() >= MAX_GEMS:
		# Fusionne avec une gemme existante plutôt que de créer un nouvel objet.
		for item: Dictionary in items:
			if item["kind"] == Kind.XP:
				item["value"] = int(item["value"]) + value
				return
	items.append({"kind": Kind.XP, "pos": pos, "value": value, "magnet": false, "speed": 0.0})


func spawn_chest(pos: Vector2) -> void:
	items.append({"kind": Kind.CHEST, "pos": pos, "value": 1, "magnet": false, "speed": 0.0})


func spawn_heal(pos: Vector2) -> void:
	items.append({"kind": Kind.HEAL, "pos": pos, "value": 20, "magnet": false, "speed": 0.0})


func nearest_position(pos: Vector2, max_range: float) -> Vector2:
	var best := Vector2.INF
	var best_d: float = max_range * max_range
	for item: Dictionary in items:
		var d: float = (item["pos"] as Vector2).distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = item["pos"]
	return best


## Attire toutes les gemmes d'XP (fin de boss).
func magnet_all() -> void:
	for item: Dictionary in items:
		if item["kind"] == Kind.XP:
			item["magnet"] = true


func step(delta: float) -> void:
	var player: Player = ctx.player
	if not player.alive:
		return
	var ppos: Vector2 = player.global_position
	var pickup_r: float = player.stats.get_value(StatKeys.PICKUP_RADIUS)
	var i: int = items.size() - 1
	while i >= 0:
		var item: Dictionary = items[i]
		var pos: Vector2 = item["pos"]
		var dist: float = pos.distance_to(ppos)
		if not item["magnet"] and dist < pickup_r:
			item["magnet"] = true
		if item["magnet"]:
			item["speed"] = minf(float(item["speed"]) + ctx.balance.magnet_speed * 3.0 * delta, ctx.balance.magnet_speed * 2.0)
			item["pos"] = pos.move_toward(ppos, float(item["speed"]) * delta)
		if dist < player.radius + 10.0:
			_collect(item)
			items[i] = items[items.size() - 1]
			items.pop_back()
		i -= 1
	queue_redraw()


func _collect(item: Dictionary) -> void:
	match item["kind"]:
		Kind.XP:
			ctx.player.gain_xp(float(item["value"]))
		Kind.HEAL:
			ctx.player.heal(float(item["value"]))
		Kind.CHEST:
			ctx.stats.add(&"chests_opened")
			ctx.events.chest_collected.emit()


func _draw() -> void:
	var t: float = ctx.time if ctx else 0.0
	for item: Dictionary in items:
		var pos: Vector2 = item["pos"]
		match item["kind"]:
			Kind.XP:
				var value: int = item["value"]
				var s: float = 4.0 if value < 5 else (6.0 if value < 20 else 8.5)
				var color := Color(0.4, 0.95, 0.75) if value < 5 else (Color(0.4, 0.7, 1.0) if value < 20 else Color(1.0, 0.85, 0.3))
				draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -s), pos + Vector2(s * 0.7, 0),
					pos + Vector2(0, s), pos + Vector2(-s * 0.7, 0)]), color)
			Kind.HEAL:
				draw_circle(pos, 7.0, Color(0.3, 0.9, 0.4))
				draw_rect(Rect2(pos - Vector2(1.5, 4.5), Vector2(3, 9)), Color.WHITE)
				draw_rect(Rect2(pos - Vector2(4.5, 1.5), Vector2(9, 3)), Color.WHITE)
			Kind.CHEST:
				var bob: float = sin(t * 4.0) * 3.0
				var p: Vector2 = pos + Vector2(0, bob)
				draw_circle(pos, 24.0, Color(1.0, 0.8, 0.3, 0.18))
				draw_rect(Rect2(p - Vector2(14, 10), Vector2(28, 20)), Color(0.05, 0.03, 0.02))
				draw_rect(Rect2(p - Vector2(12, 8), Vector2(24, 16)), Color(0.75, 0.5, 0.2))
				draw_rect(Rect2(p - Vector2(12, 2), Vector2(24, 3)), Color(0.4, 0.25, 0.1))
				draw_circle(p + Vector2(0, 2), 3.0, Color(1.0, 0.9, 0.4))
