class_name PortalDirector
extends Node2D
## Miroirs-portails (brique B6, carte 14 « Puits des reflets », docs/design/CARTES.md) : paires de portails ; y entrer
## ramène au portail jumeau. Le Chasseur (et ses Échos) passe dès que la paire est rechargée ; les Corrompus les
## empruntent aussi, à débit limité. Raccourci pour revenir défendre l'autel, ou piège qui sépare la horde.
## Le gardien de la carte (PortalGuardian) saute de portail en portail. Aucune règle de gameplay dans le dessin.

const PAIR_COLORS: Array[Color] = [Color(0.45, 0.95, 1.0), Color(0.85, 0.6, 1.0), Color(0.55, 1.0, 0.75),
	Color(1.0, 0.8, 0.5)]
const ENEMY_CHECK := 0.1
## Arrivée : un peu à côté du jumeau, pour ne pas repartir aussitôt.
const ARRIVAL_OFFSET := 18.0
const INTRO_RANGE := 700.0
## Visuel des portails (scène de Codex, PR 90) : un nœud par portail, même teinte pour les deux jumeaux.
const VISUAL_SCENE := "res://assets/vfx/objects/mirror_portal/mirror_portal.tscn"
const VISUAL_RADIUS := 40.0
const TRANSIT_TIME := 0.65

## {"pos", "twin" (index), "pair", "budget"} ; la recharge est portée par la paire.
var portals: Array[Dictionary] = []
var pair_ready_at: Array[float] = []
## Portail de sortie annoncé par le gardien : index et instant de sortie (-1 : aucun).
var exit_index: int = -1
var exit_time: float = 0.0
var ctx: RunContext
var _enemy_cooldowns: Dictionary = {}
var _enemy_clock: float = 0.0
var _time: float = 0.0
var _announced: bool = false
## Portail où se tient le Chasseur (-1 : aucun) : on passe en y entrant, pas en y restant.
var _inside: int = -1


static func uses_portals(arena: ArenaData) -> bool:
	return arena.portal_pairs.size() >= 2


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Portals"
	z_index = -1
	var points: Array[Vector2] = ctx.arena.portal_pairs
	for i: int in points.size() / 2 * 2:
		var pair: int = i / 2
		portals.append({"pos": ctx.obstacles.push_out(points[i], ctx.arena.portal_radius), "twin": i + 1 - 2 * (i % 2),
			"pair": pair, "budget": 1.0, "shown": &"", "transit_until": 0.0})
		if i % 2 == 0:
			pair_ready_at.append(0.0)
	var scene: PackedScene = load(VISUAL_SCENE) if ResourceLoader.exists(VISUAL_SCENE) else null
	for portal: Dictionary in portals:
		if scene:
			var visual: Node2D = scene.instantiate()
			visual.position = portal["pos"]
			visual.set("radius", VISUAL_RADIUS)
			visual.set("tint", PAIR_COLORS[int(portal["pair"]) % PAIR_COLORS.size()])
			visual.set("duration", TRANSIT_TIME)
			add_child(visual)
			portal["visual"] = visual


func ready_for_player(index: int) -> bool:
	return ctx.time >= pair_ready_at[portals[index]["pair"]]


func step(delta: float) -> void:
	_time += delta
	if ctx.player == null:
		return
	var pos: Vector2 = ctx.player.global_position
	var inside: int = -1
	for i: int in portals.size():
		var portal: Dictionary = portals[i]
		if not _announced and pos.distance_to(portal["pos"]) < INTRO_RANGE:
			_announced = true
			ctx.events.event_started.emit("PORTAL_INTRO")
		if pos.distance_to(portal["pos"]) < ctx.arena.portal_radius:
			inside = i
	if inside >= 0 and inside != _inside and ready_for_player(inside):
		_send_player(inside)
		inside = -1
	_inside = inside
	_update_visuals()
	_enemy_clock -= delta
	if _enemy_clock <= 0.0:
		_enemy_clock = ENEMY_CHECK
		_send_enemies(ENEMY_CHECK)
	queue_redraw()


## État affiché : entrée ou sortie le temps du passage, puis actif ou en recharge selon la paire.
func _update_visuals() -> void:
	for i: int in portals.size():
		var portal: Dictionary = portals[i]
		if not portal.has("visual") or ctx.time < float(portal["transit_until"]):
			continue
		var wanted: StringName = &"active" if ready_for_player(i) else &"cooldown"
		if portal["shown"] != wanted:
			portal["shown"] = wanted
			(portal["visual"] as Node2D).call("set_state", wanted)


func _transit(index: int, state: StringName) -> void:
	var portal: Dictionary = portals[index]
	if portal.has("visual"):
		portal["shown"] = state
		portal["transit_until"] = ctx.time + TRANSIT_TIME
		(portal["visual"] as Node2D).call("set_state", state)


func _send_player(index: int) -> void:
	var portal: Dictionary = portals[index]
	var twin: Dictionary = portals[portal["twin"]]
	var color: Color = PAIR_COLORS[int(portal["pair"]) % PAIR_COLORS.size()]
	var from: Vector2 = ctx.player.global_position
	var to: Vector2 = _arrival(twin["pos"], from - portal["pos"])
	pair_ready_at[portal["pair"]] = ctx.time + ctx.arena.portal_cooldown
	_transit(index, &"enter")
	_transit(int(portal["twin"]), &"exit")
	ctx.fx.burst(from, 70.0, Color(color, 0.6))
	ctx.player.global_position = to
	ctx.fx.burst(to, 70.0, Color(color, 0.6))
	for ally: Ally in ctx.allies.team:
		ally.blink_to_player()
	ctx.stats.add(&"portal_jumps")
	Audio.play_sfx(&"dash")


## Corrompus qui entrent dans un portail : envoyés au jumeau, chacun au plus une fois par portal_enemy_cooldown.
func _send_enemies(delta: float) -> void:
	for portal: Dictionary in portals:
		portal["budget"] = minf(float(portal["budget"]) + ctx.arena.portal_enemy_rate * delta, 2.0)
		if float(portal["budget"]) < 1.0:
			continue
		for enemy: Enemy in ctx.enemies.query_radius(portal["pos"], ctx.arena.portal_radius):
			if not enemy.alive or enemy.is_boss or enemy.is_obstacle or (enemy.data and enemy.data.structure):
				continue
			var id: int = enemy.get_instance_id()
			if ctx.time < float(_enemy_cooldowns.get(id, -1.0)):
				continue
			var twin: Dictionary = portals[portal["twin"]]
			enemy.position = _arrival(twin["pos"], enemy.position - portal["pos"])
			if ctx.time >= float(twin["transit_until"]):
				_transit(int(portal["twin"]), &"exit")
			_enemy_cooldowns[id] = ctx.time + ctx.arena.portal_enemy_cooldown
			ctx.fx.burst(enemy.position, enemy.radius * 1.6, Color(PAIR_COLORS[int(portal["pair"]) % PAIR_COLORS.size()],
				0.5))
			portal["budget"] = float(portal["budget"]) - 1.0
			if float(portal["budget"]) < 1.0:
				break
	if _enemy_cooldowns.size() > 400:
		for id: Variant in _enemy_cooldowns.keys():
			if ctx.time >= float(_enemy_cooldowns[id]):
				_enemy_cooldowns.erase(id)


func _arrival(center: Vector2, came_from: Vector2) -> Vector2:
	var side: Vector2 = came_from.normalized() if came_from.length() > 1.0 else Vector2.DOWN
	return ctx.obstacles.push_out(center + side * (ctx.arena.portal_radius + ARRIVAL_OFFSET), 16.0)


## Raccourci (flèche de route, bot) : portail prêt, assez proche, dont le jumeau est bien plus près du but sur la
## carte de navigation `field` (coût de Dial : 2 par case de 16 unités, soit 8 unités par point). INF : aucun.
func shortcut(from: Vector2, field: FlowField) -> Vector2:
	var here: float = float(field.cost_at(from)) * 8.0
	if here >= float(FlowField.UNREACHED):
		return Vector2.INF
	var best := Vector2.INF
	var best_total: float = here - 400.0
	for i: int in portals.size():
		if not ready_for_player(i):
			continue
		var pos: Vector2 = portals[i]["pos"]
		var walk: float = from.distance_to(pos)
		if walk > 1100.0:
			continue
		var after: int = field.cost_at(portals[portals[i]["twin"]]["pos"])
		if after >= FlowField.UNREACHED:
			continue
		var total: float = walk * 1.15 + float(after) * 8.0
		if total < best_total:
			best_total = total
			best = pos
	return best


## Gardien : annonce du portail de sortie (dessiné en surbrillance jusqu'à sa sortie).
func mark_exit(index: int, at: float) -> void:
	exit_index = index
	exit_time = at


## Sous le portail de Codex : seuil discret (zone d'entrée), arc de recharge, sortie annoncée de la gardienne.
func _draw() -> void:
	if ctx == null:
		return
	var radius: float = ctx.arena.portal_radius
	for i: int in portals.size():
		var portal: Dictionary = portals[i]
		var center: Vector2 = portal["pos"]
		var color: Color = PAIR_COLORS[int(portal["pair"]) % PAIR_COLORS.size()]
		var ready: bool = ready_for_player(i)
		draw_arc(center, radius, 0.0, TAU, 40, Color(color, 0.55 if ready else 0.2), 2.0, true)
		if not portal.has("visual"):
			draw_circle(center, radius * 0.75, Color(color, 0.18 if ready else 0.06))
		if not ready:
			var left: float = clampf((pair_ready_at[portal["pair"]] - ctx.time) / maxf(ctx.arena.portal_cooldown, 0.01), 0.0,
				1.0)
			draw_arc(center, radius + 8.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 40, Color(color, 0.7), 3.0, true)
		if i == exit_index and ctx.time < exit_time:
			var pulse: float = 0.5 + 0.5 * sin(_time * 10.0)
			draw_arc(center, radius * (1.35 + 0.1 * pulse), 0.0, TAU, 48, Color(1.0, 0.95, 0.6, 0.6 + 0.4 * pulse), 5.0, true)
