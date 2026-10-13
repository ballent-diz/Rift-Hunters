class_name PickupManager
extends Node2D
## Gemmes d'XP, coffres et soins. Attirés vers le Chasseur dans son rayon de ramassage.

enum Kind { XP, CHEST, HEAL, CAPTURE }

const MAX_GEMS := 350
## Taille d'affichage des gemmes d'XP (1 = taille d'origine).
const GEM_SCALE := 1.3

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
	# value : part des PV max rendue au ramassage (calculée à ce moment-là).
	items.append({"kind": Kind.HEAL, "pos": pos, "value": ctx.balance.heal_amount_ratio, "magnet": false, "speed": 0.0})


func spawn_capture(pos: Vector2, monster_id: StringName) -> void:
	items.append({"kind": Kind.CAPTURE, "pos": pos, "value": 0, "magnet": false, "speed": 0.0, "monster": monster_id,
		"progress": 0.0, "life": ctx.balance.capture_lifetime})
	ctx.fx.text(pos + Vector2(0, -30), tr("CAPTURE_APPEARS"), Color(0.8, 1.0, 0.9))


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
		if item["kind"] == Kind.CAPTURE:
			if not _step_capture(item, dist, delta):
				items[i] = items[items.size() - 1]
				items.pop_back()
			i -= 1
			continue
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


## Rite de lien : rester au contact remplit la jauge ; s'éloigner la vide lentement.
func _step_capture(item: Dictionary, dist: float, delta: float) -> bool:
	item["life"] = float(item["life"]) - delta
	if dist < ctx.balance.capture_radius:
		item["progress"] = float(item["progress"]) + delta
	else:
		item["progress"] = maxf(float(item["progress"]) - delta * 0.5, 0.0)
	if float(item["progress"]) >= ctx.balance.capture_time:
		_complete_capture(item["monster"])
		return false
	return float(item["life"]) > 0.0


func _complete_capture(monster_id: StringName) -> void:
	ctx.build.captures.append(monster_id)
	ctx.stats.add(&"captures")
	var monster: MonsterData = GameDB.monster(monster_id)
	if ctx.allies.has_free_slot():
		ctx.allies.add_monster(monster_id, ctx.player.stats.get_int(StatKeys.RECRUIT_RANK))
		ctx.fx.text(ctx.player.global_position + Vector2(0, -40), tr("CAPTURE_JOINED") % tr(monster.name_key), Color(0.7, 1.0, 0.8))
	else:
		ctx.stats.add(&"essence_earned_raw", 2.0)
		ctx.fx.text(ctx.player.global_position + Vector2(0, -40), tr("CAPTURE_SENT_TO_REFUGE") % tr(monster.name_key),
			Color(0.7, 1.0, 0.8))
	ctx.events.capture_completed.emit(monster_id)


func _collect(item: Dictionary) -> void:
	match item["kind"]:
		Kind.XP:
			ctx.player.gain_xp(float(item["value"]))
			Audio.play_sfx(&"xp_pickup")
		Kind.HEAL:
			ctx.player.heal(ctx.player.max_hp * float(item["value"]))
			ctx.fx.ring(ctx.player.global_position, 26.0, Color(1.0, 0.45, 0.55, 0.7), 0.3)
		Kind.CHEST:
			ctx.stats.add(&"chests_opened")
			ctx.events.chest_collected.emit()


func _draw() -> void:
	var t: float = ctx.time if ctx else 0.0
	for item: Dictionary in items:
		var pos: Vector2 = item["pos"]
		match item["kind"]:
			Kind.XP:
				_draw_gem(pos, int(item["value"]), t)
			Kind.HEAL:
				_draw_heart(pos, t)
			Kind.CAPTURE:
				var monster: MonsterData = GameDB.monster(item["monster"])
				var color: Color = monster.visual.primary.lightened(0.3) if monster else Color.WHITE
				var pulse: float = 0.5 + 0.5 * sin(t * 5.0)
				draw_circle(pos, ctx.balance.capture_radius, Color(color, 0.10 + 0.08 * pulse))
				draw_arc(pos, ctx.balance.capture_radius, 0.0, TAU, 48, Color(color, 0.7), 2.0)
				var ratio: float = float(item["progress"]) / ctx.balance.capture_time
				draw_arc(pos, ctx.balance.capture_radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 48, Color(0.8, 1.0, 0.9), 4.0)
				draw_circle(pos, 10.0 + 3.0 * pulse, Color(color, 0.9))
			Kind.CHEST:
				var bob: float = sin(t * 4.0) * 3.0
				var p: Vector2 = pos + Vector2(0, bob)
				draw_circle(pos, 24.0, Color(1.0, 0.8, 0.3, 0.18))
				draw_rect(Rect2(p - Vector2(14, 10), Vector2(28, 20)), Color(0.05, 0.03, 0.02))
				draw_rect(Rect2(p - Vector2(12, 8), Vector2(24, 16)), Color(0.75, 0.5, 0.2))
				draw_rect(Rect2(p - Vector2(12, 2), Vector2(24, 3)), Color(0.4, 0.25, 0.1))
				draw_circle(p + Vector2(0, 2), 3.0, Color(1.0, 0.9, 0.4))


## Gemme d'XP facettée : contour sombre, face claire en haut-gauche, reflet qui scintille.
func _draw_gem(pos: Vector2, value: int, t: float) -> void:
	var s: float = (4.0 if value < 5 else (6.0 if value < 20 else 8.5)) * GEM_SCALE
	var color := Color(0.4, 0.95, 0.75) if value < 5 else (Color(0.4, 0.7, 1.0) if value < 20 else Color(1.0, 0.85, 0.3))
	var p: Vector2 = pos + Vector2(0, sin(t * 3.0 + pos.x * 0.05) * 1.2)
	var top := p + Vector2(0, -s)
	var right := p + Vector2(s * 0.7, 0)
	var bottom := p + Vector2(0, s)
	var left := p + Vector2(-s * 0.7, 0)
	var o: float = 1.6
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -o), right + Vector2(o, 0), bottom + Vector2(0, o),
		left + Vector2(-o, 0)]), Color(0.04, 0.05, 0.08, 0.9))
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([top, p, left]), color.lightened(0.35))
	draw_colored_polygon(PackedVector2Array([top, right, p]), color)
	var sparkle: float = maxf(sin(t * 4.0 + pos.y * 0.07), 0.0)
	if sparkle > 0.6:
		draw_circle(p + Vector2(-s * 0.2, -s * 0.4), 1.2 * GEM_SCALE, Color(1, 1, 1, sparkle))


## Soin : cœur rouge qui bat, contour sombre, halo et reflet (bien visible dans la foule).
func _draw_heart(pos: Vector2, t: float) -> void:
	var beat: float = 1.0 + 0.12 * maxf(sin(t * 6.0), 0.0)
	var p: Vector2 = pos + Vector2(0, sin(t * 2.5) * 1.5)
	draw_circle(p, 15.0 * beat, Color(1.0, 0.3, 0.4, 0.16))
	for pass_index: int in 2:
		var k: float = (7.0 if pass_index == 0 else 5.6) * beat
		var color := Color(0.12, 0.02, 0.05) if pass_index == 0 else Color(0.95, 0.2, 0.3)
		draw_circle(p + Vector2(-k * 0.5, -k * 0.25), k * 0.58, color)
		draw_circle(p + Vector2(k * 0.5, -k * 0.25), k * 0.58, color)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-k * 1.05, -k * 0.05), p + Vector2(k * 1.05, -k * 0.05),
			p + Vector2(0, k * 1.0)]), color)
	draw_circle(p + Vector2(-3.0, -3.0) * beat, 1.6, Color(1.0, 0.85, 0.88))
