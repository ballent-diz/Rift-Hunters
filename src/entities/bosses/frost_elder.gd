class_name FrostElder
extends BossMechanics
## Mécanique phare du Chaman ancestral (gardien de la carte 17 « Col des braseros », docs/design/MONSTRES.md) :
## - Grand gel (`deep_freeze`) : il souffle tous les braseros proches sauf un, qui flamboie ; après l'annonce, une vague
##   de gel frappe tout ce qui n'est pas dans la chaleur d'un brasero allumé : dégâts et Prison de glace (une Ruée la
##   brise). Il faut courir au dernier brasero, ou briser la prison.
## Sans brasero sur la carte (tests, autre arène), le Chasseur trouve refuge dans un cercle posé près de lui.

const RIME := Color(0.72, 0.9, 1.0)
const FIRE := Color(1.0, 0.62, 0.22)

## Grand gel en cours : {"at", "keep" (index du brasero gardé, -1 : cercle de repli), "pos", "radius", "damage",
## "prison", "bot"} ; vide : aucun.
var freeze: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "FrostElder"


func deep_freeze(pattern: BossPatternData) -> void:
	intro("BOSS_DEEP_FREEZE_INTRO")
	var reach: float = float(pattern.params.get("reach", 1400.0))
	var delay: float = pattern.telegraph
	var keep: int = -1
	var pos: Vector2 = ctx.player.global_position + Vector2(260, 0).rotated(ctx.rng.randf() * TAU)
	var radius: float = float(pattern.params.get("refuge_radius", 170.0))
	if ctx.cold and not ctx.arena.braziers.is_empty():
		var near: Array[int] = []
		for i: int in ctx.arena.braziers.size():
			if ctx.arena.braziers[i].distance_to(boss().position) <= reach:
				near.append(i)
		if not near.is_empty():
			# Le brasero gardé : le plus loin du Chasseur parmi les proches (il faut courir), rallumé s'il était éteint.
			near.sort_custom(func(a: int, b: int) -> bool:
				return ctx.arena.braziers[a].distance_to(ctx.player.global_position) \
					> ctx.arena.braziers[b].distance_to(ctx.player.global_position))
			keep = near[0]
			ctx.cold.out_until[keep] = 0.0
			for i: int in near:
				if i != keep:
					ctx.cold.snuff(i)
					ctx.cold.out_until[i] = maxf(ctx.cold.out_until[i], ctx.time + delay + 1.0)
			pos = ctx.arena.braziers[keep]
			radius = ctx.arena.brazier_radius
	brain.busy_time = delay + 0.4
	freeze = {"at": ctx.time + delay, "keep": keep, "pos": pos, "radius": radius, "damage": brain._damage(pattern),
		"prison": float(pattern.params.get("prison", 2.0)),
		"bot": ctx.rng.randf() < float(pattern.params.get("bot_reach", 0.75))}
	brain.schedule(delay, _release)


func _release() -> void:
	if freeze.is_empty():
		return
	var pos: Vector2 = freeze["pos"]
	var sheltered: bool = ctx.player.global_position.distance_to(pos) <= float(freeze["radius"])
	ctx.fx.ring(boss().position, 900.0, Color(RIME, 0.7), 0.5)
	ctx.fx.debris(ctx.player.global_position, RIME, 12)
	if ctx.player.alive and not sheltered:
		ctx.combat.damage_player(float(freeze["damage"]), boss().boss_data.id)
		ctx.frost.imprison(float(freeze["prison"]))
	ctx.stats.add(&"deep_freezes")
	if sheltered:
		ctx.stats.add(&"deep_freezes_sheltered")
	freeze = {}
	queue_redraw()


func step(delta: float) -> void:
	super.step(delta)
	if not freeze.is_empty():
		queue_redraw()


func finish() -> void:
	freeze = {}
	queue_redraw()


## Bot : rejoindre le refuge (s'il y arrive, selon sa réussite d'essai), puis briser la prison d'une Ruée.
func bot_move(pos: Vector2) -> Vector2:
	if freeze.is_empty() or not bool(freeze["bot"]):
		return Vector2.ZERO
	var target: Vector2 = freeze["pos"]
	if pos.distance_to(target) < float(freeze["radius"]) * 0.5:
		return Vector2.ZERO
	return (target - pos).normalized()


func bot_dash() -> bool:
	return ctx.frost.imprisoned()


func _draw() -> void:
	if freeze.is_empty():
		return
	var left: float = maxf(float(freeze["at"]) - ctx.time, 0.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 8.0)
	var pos: Vector2 = freeze["pos"]
	var radius: float = freeze["radius"]
	draw_circle(pos, radius, Color(FIRE, 0.12 + 0.08 * pulse))
	draw_arc(pos, radius, 0.0, TAU, 64, Color(FIRE, 0.85), 4.0)
	draw_arc(pos, radius * (0.4 + 0.6 * left / maxf(left + 0.01, 1.0)), 0.0, TAU, 48, Color(FIRE, 0.5), 2.0)
	draw_arc(boss().position, 160.0 + 40.0 * pulse, 0.0, TAU, 48, Color(RIME, 0.6), 3.0)
