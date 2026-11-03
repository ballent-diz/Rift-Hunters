class_name PortalGuardian
extends BossMechanics
## Mécanique phare de la Dame des portails (gardienne de la carte 14 « Puits des reflets », docs/design/MONSTRES.md) :
## - Saut de portail (`portal_hop`) : elle plonge dans le miroir et ressort par un miroir-portail de la carte (celui
##   qui est le plus près du Chasseur, jamais le plus proche d'elle). Le portail de sortie s'illumine pendant la plongée.
## - Le Chasseur qui se tient dans le portail illuminé quand elle ressort la piège : elle sort sonnée et prend double
##   dégâts quelques secondes. Sinon, elle surgit dans une onde de prisme (cercle télégraphié autour du portail).
## Sans miroirs-portails sur la carte (tests, autre arène), elle se téléporte près du Chasseur.

const PRISM := Color(0.75, 0.95, 1.0)

## Saut en cours : {"exit" (index du portail), "at" (instant de sortie), "bot_trap" (le bot tente le piège)} ; vide : aucun.
var hop: Dictionary = {}
var _params: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "PortalGuardian"


func begin(params: Dictionary) -> void:
	_params = params
	intro("BOSS_PORTAL_INTRO")


func portal_hop(pattern: BossPatternData) -> void:
	var dive: float = float(pattern.params.get("dive", 2.2))
	var exit: int = _pick_exit()
	brain.busy_time = dive + 0.6
	boss().invulnerable_time = dive
	boss().visual.modulate.a = 0.25
	ctx.fx.burst(boss().position, boss().radius * 2.0, Color(PRISM, 0.6))
	hop = {"exit": exit, "at": ctx.time + dive, "bot_trap": ctx.rng.randf() < float(_params.get("bot_trap", 0.7)),
		"damage": brain._damage(pattern), "radius": float(pattern.params.get("radius", 210.0))}
	if exit >= 0:
		ctx.portals.mark_exit(exit, ctx.time + dive)
	brain.schedule(dive, _emerge)


func step(delta: float) -> void:
	super.step(delta)
	queue_redraw()


func finish() -> void:
	hop = {}
	if ctx.portals:
		ctx.portals.mark_exit(-1, 0.0)
	queue_redraw()


func exit_position() -> Vector2:
	if hop.is_empty():
		return Vector2.INF
	var exit: int = int(hop["exit"])
	if exit >= 0 and ctx.portals:
		return ctx.portals.portals[exit]["pos"]
	return hop.get("fallback", Vector2.INF)


## Portail de sortie : le plus proche du Chasseur parmi ceux qui ne sont pas le plus proche d'elle (-1 : aucun).
func _pick_exit() -> int:
	if ctx.portals == null or ctx.portals.portals.is_empty():
		return -1
	var spots: Array[Vector2] = []
	for portal: Dictionary in ctx.portals.portals:
		spots.append(portal["pos"])
	var nearest_boss: int = 0
	for i: int in spots.size():
		if spots[i].distance_to(boss().position) < spots[nearest_boss].distance_to(boss().position):
			nearest_boss = i
	var best: int = -1
	var player: Vector2 = ctx.player.global_position
	for i: int in spots.size():
		if i != nearest_boss and (best < 0 or spots[i].distance_to(player) < spots[best].distance_to(player)):
			best = i
	return best


func _emerge() -> void:
	if hop.is_empty() or not boss().alive:
		hop = {}
		return
	var target: Vector2 = exit_position()
	if target == Vector2.INF:
		target = ctx.obstacles.push_out(ctx.player.global_position + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * 260.0,
			boss().radius)
	var trapped: bool = ctx.player.global_position.distance_to(target) < ctx.arena.portal_radius * 1.4 \
		and int(hop["exit"]) >= 0
	boss().position = ctx.obstacles.push_out(target, boss().radius)
	boss().visual.modulate.a = 1.0
	boss().invulnerable_time = 0.0
	if ctx.portals:
		ctx.portals.mark_exit(-1, 0.0)
	if trapped:
		var seconds: float = float(_params.get("trap_stun", 5.0))
		brain.stun(seconds)
		brain.heart_time = seconds
		ctx.fx.burst(boss().position, boss().radius * 2.4, Color(1.0, 0.95, 0.6, 0.7))
		ctx.fx.text(boss().position + Vector2(0, -boss().radius - 34.0), tr("BOSS_PORTAL_TRAPPED"), Color(1.0, 0.95, 0.6))
		ctx.stats.add(&"boss_portal_trapped")
	else:
		ctx.hazards.add_circle(boss().position, float(hop["radius"]), 0.55, float(hop["damage"]), true, brain.data.id)
		ctx.fx.burst(boss().position, float(hop["radius"]), Color(PRISM, 0.45))
	hop = {}


# --- Bot ------------------------------------------------------------------------------------------------------

## Plongée en cours : le bot va se placer dans le portail de sortie (sept fois sur dix, joueur moyen-bon).
func bot_move(pos: Vector2) -> Vector2:
	if hop.is_empty() or not bool(hop["bot_trap"]):
		return Vector2.ZERO
	var target: Vector2 = exit_position()
	if target == Vector2.INF or int(hop["exit"]) < 0:
		return Vector2.ZERO
	return (target - pos).normalized() if pos.distance_to(target) > 14.0 else Vector2.ZERO


# --- Dessin ---------------------------------------------------------------------------------------------------

func _draw() -> void:
	if hop.is_empty():
		return
	var target: Vector2 = exit_position()
	if target == Vector2.INF:
		return
	var left: float = clampf((float(hop["at"]) - ctx.time) / 2.2, 0.0, 1.0)
	draw_arc(target, float(hop["radius"]), -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 48, Color(PRISM, 0.55), 3.0, true)
