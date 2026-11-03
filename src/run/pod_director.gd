class_name PodDirector
extends Node2D
## Brique B5 « éléments à utiliser » (docs/design/CARTES.md), deux habillages :
## - bulbes de braise (carte 7) : un coup du Chasseur ou d'un Écho les amorce ; alerte de pod_prime secondes, puis
##   éclatement qui ravage les Corrompus autour ; le Chasseur trop proche est touché aussi ;
## - cristaux-miroirs (carte 13) : un coup les charge ; ils éclatent en trois rayons de lumière (le premier dans le sens
##   du coup, les deux autres à 120°) qui transpercent les Corrompus sur leur ligne ; le Chasseur dans l'axe est touché.
## Structures immobiles (EnemyData.pod). La coque vide repousse ensuite. Occasion tactique : y attirer les hordes, ou
## placer le cristal entre soi et la horde avant de frapper.

signal beam_crossed(target: Enemy)

enum State { IDLE, PRIMED, EMPTY }

const POD_ID := &"ember_pod"
const CRYSTAL_ID := &"crystal_mirror"
const EMBER := Color(1.0, 0.5, 0.15)
const LIGHT := Color(0.65, 0.95, 1.0)
## Visuel des cristaux-miroirs (scène de Codex, PR 90) : états idle, charged, burst, hidden pilotés ici.
const CRYSTAL_SCENE := "res://assets/vfx/objects/mirror_crystal/mirror_crystal.tscn"

var ctx: RunContext
## {"enemy": Enemy, "state": State, "timer": float, "kind": StringName, "dir": Vector2}
var pods: Array[Dictionary] = []
var _time: float = 0.0
## Annonces déjà faites (bulbes, cristaux) : une seule fois, à l'approche du premier.
var _announced: Dictionary = {}


static func uses_pods(arena: ArenaData) -> bool:
	return not arena.ember_pods.is_empty() or not arena.crystal_mirrors.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Pods"
	z_index = -2
	for pos: Vector2 in ctx.arena.ember_pods:
		_spawn(POD_ID, pos)
	for pos: Vector2 in ctx.arena.crystal_mirrors:
		_spawn(CRYSTAL_ID, pos)


func _spawn(kind: StringName, pos: Vector2) -> void:
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(kind), pos)
	enemy.visual.play(&"idle")
	var pod: Dictionary = {"enemy": enemy, "state": State.IDLE, "timer": 0.0, "kind": kind, "dir": Vector2.RIGHT}
	pods.append(pod)
	if kind == CRYSTAL_ID and ResourceLoader.exists(CRYSTAL_SCENE):
		var crystal: Node2D = (load(CRYSTAL_SCENE) as PackedScene).instantiate()
		crystal.set("ray_length", ctx.arena.crystal_beam_length)
		crystal.set("duration", 0.5)
		enemy.add_child(crystal)
		enemy.visual.visible = false
		pod["visual"] = crystal
		# Fin de l'éclatement : rien ne reste jusqu'à la repousse.
		crystal.connect("finished", func() -> void:
			if pod["state"] == State.EMPTY:
				crystal.call("play", &"hidden"))


func _show(pod: Dictionary, state: StringName) -> void:
	if pod.has("visual"):
		(pod["visual"] as Node2D).call("play", state)


func _entry(enemy: Enemy) -> Dictionary:
	for pod: Dictionary in pods:
		if pod["enemy"] == enemy:
			return pod
	return {}


static func is_crystal(pod: Dictionary) -> bool:
	return pod["kind"] == CRYSTAL_ID


## Coup allié porté depuis `from` : amorce le bulbe ou charge le cristal (alerte au sol, puis éclatement).
func prime(enemy: Enemy, from: Vector2 = Vector2.INF) -> void:
	var pod: Dictionary = _entry(enemy)
	if pod.is_empty() or pod["state"] != State.IDLE:
		return
	pod["state"] = State.PRIMED
	_show(pod, &"charged")
	enemy.visual.play(&"primed")
	enemy.visual.flash()
	var damage_mult: float = ctx.difficulty.enemy_damage_mult
	if is_crystal(pod):
		pod["timer"] = ctx.arena.crystal_prime
		pod["dir"] = _aim(enemy.position, from)
		for dir: Vector2 in beams(pod):
			ctx.hazards.add_beam(enemy.position + dir * enemy.radius, dir, ctx.arena.crystal_beam_length,
				ctx.arena.crystal_beam_width, ctx.arena.crystal_prime, 0.15, ctx.arena.crystal_player_damage * damage_mult,
				CRYSTAL_ID)
		ctx.stats.add(&"crystals_primed")
		return
	pod["timer"] = ctx.arena.pod_prime
	ctx.hazards.add_circle(enemy.position, ctx.arena.pod_radius, ctx.arena.pod_prime,
		ctx.arena.pod_player_damage * damage_mult, true, POD_ID)
	ctx.stats.add(&"pods_primed")


## Premier rayon : dans le sens du coup ; aimanté vers un boss proche de l'axe (crystal_assist degrés).
func _aim(pos: Vector2, from: Vector2) -> Vector2:
	var dir: Vector2 = (pos - from).normalized() if from != Vector2.INF and from.distance_to(pos) > 1.0 \
		else Vector2.RIGHT.rotated(ctx.rng.randf() * TAU)
	var boss: Enemy = ctx.boss if ctx.boss and is_instance_valid(ctx.boss) and ctx.boss.alive else null
	if boss and boss.position.distance_to(pos) <= ctx.arena.crystal_beam_length:
		var to_boss: Vector2 = (boss.position - pos).normalized()
		if absf(dir.angle_to(to_boss)) <= deg_to_rad(ctx.arena.crystal_assist):
			dir = to_boss
	return dir


## Première approche d'un bulbe ou d'un cristal : son annonce (et sa fiche au Journal la première fois).
func _announce() -> void:
	if _announced.size() >= 2 or ctx.player == null:
		return
	for pod: Dictionary in pods:
		var held: Variant = pod["enemy"]
		var kind: StringName = pod["kind"]
		if _announced.has(kind) or not is_instance_valid(held):
			continue
		if (held as Enemy).position.distance_to(ctx.player.global_position) < 600.0:
			_announced[kind] = true
			ctx.events.event_started.emit("CRYSTAL_INTRO" if kind == CRYSTAL_ID else "POD_INTRO")


## Les trois rayons d'un cristal chargé.
static func beams(pod: Dictionary) -> Array[Vector2]:
	var dir: Vector2 = pod["dir"]
	var list: Array[Vector2] = [dir, dir.rotated(TAU / 3.0), dir.rotated(-TAU / 3.0)]
	return list


func step(delta: float) -> void:
	_time += delta
	_announce()
	for pod: Dictionary in pods:
		# Lu sans type : un bulbe retiré de la carte est libéré.
		var held: Variant = pod["enemy"]
		if pod["state"] == State.IDLE or not is_instance_valid(held):
			continue
		var enemy: Enemy = held
		pod["timer"] = float(pod["timer"]) - delta
		if float(pod["timer"]) > 0.0:
			continue
		if pod["state"] == State.PRIMED:
			if is_crystal(pod):
				_shatter(pod)
			else:
				_burst(pod)
		else:
			pod["state"] = State.IDLE
			_show(pod, &"idle")
			enemy.dormant = false
			enemy.visual.play(&"idle")
			enemy.visual.modulate.a = 1.0
	queue_redraw()


func _empty(pod: Dictionary, regrow: float) -> Enemy:
	var enemy: Enemy = pod["enemy"]
	pod["state"] = State.EMPTY
	pod["timer"] = regrow
	enemy.dormant = true
	enemy.visual.play_action(&"burst")
	if not enemy.visual.has_animation(&"burst"):
		enemy.visual.modulate.a = 0.35
	return enemy


func _environment_hit(target: Enemy, flat: float, ratio: float, source: StringName) -> void:
	var share: float = 0.0 if target.is_boss else ratio * (0.5 if target.is_elite else 1.0)
	ctx.combat.deal_damage(target, DamageInfo.make(flat + target.max_hp * share, DamageInfo.SourceKind.ENVIRONMENT, source))


func _burst(pod: Dictionary) -> void:
	var enemy: Enemy = _empty(pod, ctx.arena.pod_regrow)
	ctx.fx.burst(enemy.position, ctx.arena.pod_radius, Color(EMBER, 0.55))
	ctx.fx.debris(enemy.position, EMBER, 18)
	var hits: int = 0
	for target: Enemy in ctx.enemies.query_radius(enemy.position, ctx.arena.pod_radius):
		if not target.alive or target.is_obstacle or target.position.distance_to(enemy.position) > ctx.arena.pod_radius:
			continue
		_environment_hit(target, ctx.arena.pod_damage, ctx.arena.pod_damage_ratio, POD_ID)
		hits += 1
	ctx.stats.set_max(&"pod_best_hits", float(hits))
	Audio.play_sfx(&"detonation")


## Cristal : trois rayons coupés par le décor ; chaque Corrompu sur une ligne est transpercé (une fois).
func _shatter(pod: Dictionary) -> void:
	var enemy: Enemy = _empty(pod, ctx.arena.crystal_regrow)
	if pod.has("visual"):
		(pod["visual"] as Node2D).set("direction", pod["dir"])
	_show(pod, &"burst")
	var origin: Vector2 = enemy.position
	var half: float = ctx.arena.crystal_beam_width * 0.5
	var hit: Dictionary = {}
	for dir: Vector2 in beams(pod):
		var length: float = ctx.obstacles.clear_distance(origin, dir, ctx.arena.crystal_beam_length)
		var end: Vector2 = origin + dir * length
		ctx.fx.danger_line(origin, end, ctx.arena.crystal_beam_width, 0.25)
		for target: Enemy in ctx.enemies.query_radius(origin + dir * length * 0.5, length * 0.5 + half):
			if not target.alive or target.is_obstacle or hit.has(target.get_instance_id()):
				continue
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target.position, origin, end)
			if closest.distance_to(target.position) > half + target.radius:
				continue
			hit[target.get_instance_id()] = true
			_environment_hit(target, ctx.arena.crystal_damage, ctx.arena.crystal_damage_ratio, CRYSTAL_ID)
			if target.is_boss:
				beam_crossed.emit(target)
	ctx.fx.burst(origin, 60.0, Color(LIGHT, 0.6))
	ctx.fx.debris(origin, LIGHT, 14)
	ctx.stats.set_max(&"crystal_best_hits", float(hit.size()))
	Audio.play_sfx(&"detonation")


## Au repos : bulbe qui pulse ou cristal qui scintille ; amorcé : anneau qui se resserre (en plus du télégraphe).
func _draw() -> void:
	for pod: Dictionary in pods:
		var held: Variant = pod["enemy"]
		if not is_instance_valid(held):
			continue
		var enemy: Enemy = held
		var color: Color = LIGHT if is_crystal(pod) else EMBER
		match pod["state"]:
			State.IDLE:
				if pod.has("visual"):
					continue
				var pulse: float = 0.5 + 0.5 * sin(_time * 2.5 + enemy.position.x)
				draw_circle(enemy.position, enemy.radius * (1.1 + 0.15 * pulse), Color(color, 0.12 + 0.1 * pulse))
			State.PRIMED:
				var total: float = ctx.arena.crystal_prime if is_crystal(pod) else ctx.arena.pod_prime
				var left: float = clampf(float(pod["timer"]) / total, 0.0, 1.0)
				draw_arc(enemy.position, enemy.radius * (1.4 + 2.0 * left), 0.0, TAU, 32, Color(color, 0.9), 3.0)
