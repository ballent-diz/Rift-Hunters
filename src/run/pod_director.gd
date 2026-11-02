class_name PodDirector
extends Node2D
## Brique B5 « éléments à utiliser », habillage bulbes de braise (carte 7, docs/design/CARTES.md) : des bulbes poussent
## sur la carte (structures immobiles, EnemyData.pod). Un coup du Chasseur ou d'un Écho les amorce : alerte de
## pod_prime secondes, puis éclatement qui ravage les Corrompus autour ; le Chasseur trop proche est touché aussi.
## La coque vide repousse au bout de pod_regrow secondes. Occasion tactique : y attirer les hordes, puis amorcer.

enum State { IDLE, PRIMED, EMPTY }

const POD_ID := &"ember_pod"
const EMBER := Color(1.0, 0.5, 0.15)

var ctx: RunContext
## {"enemy": Enemy, "state": State, "timer": float}
var pods: Array[Dictionary] = []
var _time: float = 0.0


static func uses_pods(arena: ArenaData) -> bool:
	return not arena.ember_pods.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Pods"
	z_index = -2
	var data: EnemyData = GameDB.enemy(POD_ID)
	for pos: Vector2 in ctx.arena.ember_pods:
		var enemy: Enemy = ctx.enemies.spawn(data, pos)
		enemy.visual.play(&"idle")
		pods.append({"enemy": enemy, "state": State.IDLE, "timer": 0.0})


func _entry(enemy: Enemy) -> Dictionary:
	for pod: Dictionary in pods:
		if pod["enemy"] == enemy:
			return pod
	return {}


## Coup allié : amorce le bulbe (alerte au sol, puis éclatement).
func prime(enemy: Enemy) -> void:
	var pod: Dictionary = _entry(enemy)
	if pod.is_empty() or pod["state"] != State.IDLE:
		return
	pod["state"] = State.PRIMED
	pod["timer"] = ctx.arena.pod_prime
	enemy.visual.play(&"primed")
	enemy.visual.flash()
	ctx.hazards.add_circle(enemy.position, ctx.arena.pod_radius, ctx.arena.pod_prime,
		ctx.arena.pod_player_damage * ctx.difficulty.enemy_damage_mult, true, POD_ID)
	ctx.stats.add(&"pods_primed")


func step(delta: float) -> void:
	_time += delta
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
			_burst(pod)
		else:
			pod["state"] = State.IDLE
			enemy.dormant = false
			enemy.visual.play(&"idle")
			enemy.visual.modulate.a = 1.0
	queue_redraw()


func _burst(pod: Dictionary) -> void:
	var enemy: Enemy = pod["enemy"]
	pod["state"] = State.EMPTY
	pod["timer"] = ctx.arena.pod_regrow
	enemy.dormant = true
	enemy.visual.play_action(&"burst")
	if not enemy.visual.has_animation(&"burst"):
		enemy.visual.modulate.a = 0.35
	ctx.fx.burst(enemy.position, ctx.arena.pod_radius, Color(EMBER, 0.55))
	ctx.fx.debris(enemy.position, EMBER, 18)
	var hits: int = 0
	for target: Enemy in ctx.enemies.query_radius(enemy.position, ctx.arena.pod_radius):
		if not target.alive or target.is_obstacle or target.position.distance_to(enemy.position) > ctx.arena.pod_radius:
			continue
		var ratio: float = 0.0 if target.is_boss else ctx.arena.pod_damage_ratio * (0.5 if target.is_elite else 1.0)
		var info := DamageInfo.make(ctx.arena.pod_damage + target.max_hp * ratio, DamageInfo.SourceKind.ENVIRONMENT,
			POD_ID)
		ctx.combat.deal_damage(target, info)
		hits += 1
	ctx.stats.set_max(&"pod_best_hits", float(hits))
	Audio.play_sfx(&"detonation")


## Bulbe au repos : légère pulsation de braise ; amorcé : anneau qui se resserre (en plus du télégraphe du danger).
func _draw() -> void:
	for pod: Dictionary in pods:
		var held: Variant = pod["enemy"]
		if not is_instance_valid(held):
			continue
		var enemy: Enemy = held
		match pod["state"]:
			State.IDLE:
				var pulse: float = 0.5 + 0.5 * sin(_time * 2.5 + enemy.position.x)
				draw_circle(enemy.position, enemy.radius * (1.1 + 0.15 * pulse), Color(EMBER, 0.12 + 0.1 * pulse))
			State.PRIMED:
				var left: float = clampf(float(pod["timer"]) / ctx.arena.pod_prime, 0.0, 1.0)
				draw_arc(enemy.position, enemy.radius * (1.4 + 2.0 * left), 0.0, TAU, 32, Color(EMBER, 0.9), 3.0)
