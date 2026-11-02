class_name SporeGuardian
extends BossMechanics
## Mécanique phare du gardien de la carte 13 (Mère-spore, docs/design/MONSTRES.md) :
## - Voile de spores (`spore_veil`) : un nuage de spores l'enveloppe ; les coups ne portent presque pas (× veil_mult).
##   Un rayon de cristal-miroir qui la traverse brûle le voile : elle est sonnée et prend double dégâts quelques
##   secondes, puis le voile repousse. Il faut donc frapper un cristal aligné avec elle (le premier rayon part dans le
##   sens du coup, aimanté vers elle à quelques degrés près).
## - Floraison : quand le voile est déjà là, il se densifie et des bouffées de spores éclatent autour du Chasseur.

const SPORE := Color(0.62, 0.92, 0.45)

## Voile : {"mult", "burn", "regrow", "down_until"} ; down_until > temps de partie : voile brûlé (vide : aucun voile).
var veil: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "SporeGuardian"
	ctx.combat.add_damage_modifier(_damage_modifier)
	if ctx.pods:
		ctx.pods.beam_crossed.connect(_on_beam_crossed)


## Le voile se lève dès l'arrivée du gardien (réglages : BossData.signature_params).
func begin_veil(params: Dictionary) -> void:
	veil = {"mult": float(params.get("veil_mult", 0.2)), "burn": float(params.get("burn", 5.0)),
		"regrow": float(params.get("regrow", 14.0)), "down_until": 0.0}
	intro("BOSS_SPORE_VEIL_INTRO")


func veiled() -> bool:
	return not veil.is_empty() and ctx.time >= float(veil["down_until"])


func step(delta: float) -> void:
	super.step(delta)
	queue_redraw()


func finish() -> void:
	veil = {}
	queue_redraw()


func _damage_modifier(enemy: Enemy, info: DamageInfo) -> float:
	if brain == null or enemy != boss() or not info.is_friendly() or not veiled():
		return 1.0
	ctx.fx.spark(enemy.position, SPORE, 6.0)
	ctx.stats.add(&"boss_veil_blocked")
	return float(veil["mult"])


## Rayon de cristal-miroir qui traverse le gardien : le voile brûle.
func _on_beam_crossed(target: Enemy) -> void:
	if brain == null or target != boss() or not veiled() or not boss().alive:
		return
	burn()


func burn() -> void:
	var seconds: float = float(veil["burn"])
	veil["down_until"] = ctx.time + seconds + float(veil["regrow"])
	brain.stun(seconds)
	brain.heart_time = seconds
	ctx.fx.burst(boss().position, boss().radius * 2.2, Color(SPORE, 0.6))
	ctx.fx.text(boss().position + Vector2(0, -boss().radius - 30.0), tr("BOSS_VEIL_BURNED"), Color(1.0, 0.95, 0.6))
	ctx.stats.add(&"boss_veil_burned")


## Floraison : bouffées de spores autour du Chasseur (et le voile, s'il est brûlé depuis assez longtemps, revient plus
## vite d'un tiers du délai restant).
func spore_veil(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var radius: float = float(params.get("radius", 90.0))
	var count: int = int(params.get("count", 3))
	var spread: float = float(params.get("spread", 170.0))
	var area: Rect2 = ctx.arena_rect().grow(-radius)
	for i: int in count:
		var offset: Vector2 = Vector2.ZERO if i == 0 else Vector2.RIGHT.rotated(TAU * i / count + ctx.rng.randf()) * spread
		var pos: Vector2 = ctx.obstacles.push_out((ctx.player.global_position + offset).clamp(area.position, area.end), radius)
		ctx.hazards.add_circle(pos, radius, pattern.telegraph, brain._damage(pattern), true, brain.data.id)
	if not veil.is_empty() and not veiled():
		var left: float = float(veil["down_until"]) - ctx.time
		if left < float(veil["regrow"]):
			veil["down_until"] = ctx.time + left * 0.66
	brain.busy_time = pattern.telegraph + 0.3


# --- Bot ------------------------------------------------------------------------------------------------------

## Voile levé : se placer derrière un cristal au repos aligné avec le gardien (pour que le rayon parte vers lui).
func bot_move(pos: Vector2) -> Vector2:
	var spot: Vector2 = bot_crystal_spot(pos)
	if spot == Vector2.INF:
		return Vector2.ZERO
	# Arrivé derrière le cristal : rester collé à lui, le temps que les coups le chargent.
	return (spot - pos).normalized() if pos.distance_to(spot) >= 18.0 else (boss().position - pos).normalized() * 0.2


func bot_crystal_spot(pos: Vector2) -> Vector2:
	if not veiled() or ctx.pods == null or brain == null or not boss().alive:
		return Vector2.INF
	var best: Vector2 = Vector2.INF
	for pod: Dictionary in ctx.pods.pods:
		var held: Variant = pod["enemy"]
		if not PodDirector.is_crystal(pod) or pod["state"] != PodDirector.State.IDLE or not is_instance_valid(held):
			continue
		var crystal: Enemy = held
		var to_boss: Vector2 = boss().position - crystal.position
		if to_boss.length() > ctx.arena.crystal_beam_length * 0.9:
			continue
		var spot: Vector2 = crystal.position - to_boss.normalized() * (crystal.radius + 34.0)
		if best == Vector2.INF or pos.distance_to(spot) < pos.distance_to(best):
			best = spot
	return best


# --- Dessin ---------------------------------------------------------------------------------------------------

func _draw() -> void:
	if brain == null or not boss().alive or veil.is_empty():
		return
	if veiled():
		for k: int in 10:
			var angle: float = _time * 0.8 + TAU * k / 10.0
			var r: float = boss().radius * (1.25 + 0.12 * sin(_time * 3.0 + k))
			draw_circle(boss().position + Vector2.RIGHT.rotated(angle) * r, 9.0 + 3.0 * sin(_time * 4.0 + k),
				Color(SPORE, 0.35))
		draw_arc(boss().position, boss().radius * 1.35, 0.0, TAU, 40, Color(SPORE, 0.5), 3.0)
	else:
		var left: float = clampf((float(veil["down_until"]) - ctx.time) / maxf(float(veil["regrow"]) + float(veil["burn"]),
			0.01), 0.0, 1.0)
		draw_arc(boss().position, boss().radius * 1.35, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 40,
			Color(SPORE, 0.3), 2.0)
