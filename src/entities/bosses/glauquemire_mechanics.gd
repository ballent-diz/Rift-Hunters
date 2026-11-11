class_name GlauquemireMechanics
extends BossMechanics
## Glauquemire, Dévoreur des Marais engloutis (docs/design/DEVOREUR_CHAPITRE3.md) : mécaniques qu'aucun boss n'a avant
## lui. Phase 1 : vase qui durcit en murs, racine jaillissante, sangsues nourricières (soin plafonné). Phase 2 :
## carapace à facettes et miroirs (mécanique phare : le rayon de prisme balaie l'arène ; un miroir l'arrête, et le
## renvoie sur le boss si le Chasseur se tient à côté : carapace brisée, boss étourdi).
## Phase 3 : tourbillon, raz-de-marée (vagues qui partent du boss : les traverser d'une Ruée ou s'abriter derrière la
## vase durcie), engloutissement d'un Écho (le libérer en frappant le boss).
## Refonte du 11 novembre 2026 : plus rien ne retient ni n'enferme le Chasseur (laisse et anneau de marée retirés).

const MUD := Color(0.36, 0.3, 0.2)
const CRYSTAL := Color(0.6, 0.95, 1.0)
const WATER := Color(0.2, 0.55, 0.6)
const ROOT := Color(0.5, 0.38, 0.22)
const MIRROR_RADIUS := 30.0
## Distance à laquelle le Chasseur « tient » un miroir : il renvoie alors le rayon sur le boss.
const MIRROR_HOLD := 120.0
## Côtés de la carapace : droite, bas, gauche, haut (repère du monde, la carapace ne tourne pas).
const SIDES := 4
## Effets peints de Glauquemire (assets/vfx/bosses/glauquemire/, docs/art/MARAIS_SORTS_GODOT.md).
const VFX := "vfx.boss.glauquemire."

## Flaques de vase : {"pos", "radius", "harden_at", "crumble_at", "wall"} (wall : indice du mur, -1 avant durcissement).
var puddles: Array[Dictionary] = []
## Racine jaillissante en cours : {"from", "anchor", "until"} (vide : aucune). Elle ne retient pas le Chasseur.
var root: Dictionary = {}
var leeches: Array[Enemy] = []
## Carapace : PV restants par côté (vide : pas de carapace) et instant de repousse.
var facets: Array[float] = []
## Miroirs : {"pos", "arrow", "flash", "held"} (held : le Chasseur est à côté, le miroir renvoie le rayon).
var mirrors: Array[Dictionary] = []
## Rayon de prisme en cours (vide : aucun).
var beam: Dictionary = {}
var whirl: Dictionary = {}
## Raz-de-marée : vagues {"center", "radius", "speed", "max", "damage", "width", "push", "start"}.
var waves: Array[Dictionary] = []
## Écho englouti : {"ally", "until", "dealt", "need", "stun", "daze"}.
var swallowed: Dictionary = {}
var _wall_pool: Array[int] = []
var _leech_heal: float = 0.005
## Soin total que les sangsues peuvent encore rendre au boss (plafond du combat : il reste toujours tuable).
var _leech_budget: float = -1.0
var _facet_max: float = 0.0
var _facet_regrow: Array[float] = []
var _facet_regrow_time: float = 14.0
var _facet_mult: float = 0.3
var _swallow_mark: Dictionary = {}
## Étiquettes des boucles peintes affichées (le dessin provisoire correspondant s'efface).
var _shown: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "GlauquemireMechanics"
	ctx.combat.add_damage_modifier(_facet_modifier)
	ctx.events.enemy_damaged.connect(_on_enemy_damaged)


func on_phase(index: int, phase: BossPhaseData) -> void:
	var params: Dictionary = phase.mechanic_params
	if index > 0:
		_play(VFX + "phase_transition", boss().position)
	if phase.mechanics.has(&"facets"):
		_facet_max = boss().max_hp * float(params.get("facet_ratio", 0.035))
		_facet_regrow_time = float(params.get("facet_regrow", 14.0))
		_facet_mult = float(params.get("facet_mult", 0.3))
		facets.assign([_facet_max, _facet_max, _facet_max, _facet_max])
		_facet_regrow.assign([0.0, 0.0, 0.0, 0.0])
		intro("BOSS_FACETS_INTRO")
	else:
		facets.clear()
	if phase.mechanics.has(&"mirrors"):
		if mirrors.is_empty():
			_place_mirrors(float(params.get("mirror_distance", 360.0)))
	else:
		mirrors.clear()


func step(delta: float) -> void:
	super.step(delta)
	_step_puddles()
	_step_root()
	_step_leeches()
	_step_facets()
	_step_mirrors(delta)
	_step_beam(delta)
	_step_whirl(delta)
	_step_waves(delta)
	_step_swallow()
	_sync_vfx()
	queue_redraw()


func finish() -> void:
	for puddle: Dictionary in puddles:
		if int(puddle["wall"]) >= 0:
			ctx.obstacles.set_wall_enabled(int(puddle["wall"]), false)
	puddles.clear()
	_apply_walls()
	root = {}
	beam = {}
	whirl = {}
	waves.clear()
	facets.clear()
	mirrors.clear()
	if not swallowed.is_empty():
		_release(false)
	queue_redraw()


# --- Phase 1 : vase qui durcit, racine-laisse, sangsues --------------------------------------------------------

func mud_wall(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var radius: float = float(params.get("radius", 75.0))
	var spread: float = float(params.get("spread", 150.0))
	var count: int = int(params.get("count", 3))
	var base: Vector2 = ctx.player.global_position
	var area: Rect2 = ctx.arena_rect().grow(-radius * 2.0)
	for i: int in count:
		var pos: Vector2 = base if i == 0 else base + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * spread
		pos = ctx.obstacles.push_out(pos.clamp(area.position, area.end), radius)
		ctx.hazards.add_circle(pos, radius, pattern.telegraph, brain._damage(pattern), true, brain.data.id)
		brain.schedule(pattern.telegraph, func() -> void:
			_play(VFX + "mud_impact", pos, Vector2.RIGHT, {"radius": radius})
			puddles.append({"pos": pos, "radius": radius, "born": ctx.time, "harden_at": ctx.time + float(params.get("harden", 2.5)),
				"crumble_at": ctx.time + float(params.get("harden", 2.5)) + float(params.get("wall_time", 7.0)), "wall": -1}))
	intro("BOSS_MUD_WALL_INTRO")
	brain.busy_time = pattern.telegraph + 0.4


func _step_puddles() -> void:
	var changed: bool = false
	var player: Player = ctx.player
	var i: int = puddles.size() - 1
	while i >= 0:
		var puddle: Dictionary = puddles[i]
		var pos: Vector2 = puddle["pos"]
		if int(puddle["wall"]) < 0:
			if player.global_position.distance_to(pos) < float(puddle["radius"]):
				player.hinder(0.3, 0.55)
			if ctx.time >= float(puddle["harden_at"]):
				puddle["wall"] = _wall_for(pos, float(puddle["radius"]) * 0.75)
				changed = true
		elif ctx.time >= float(puddle["crumble_at"]):
			ctx.obstacles.set_wall_enabled(int(puddle["wall"]), false)
			_wall_pool.append(int(puddle["wall"]))
			ctx.fx.debris(pos, MUD, 10)
			puddles.remove_at(i)
			changed = true
		i -= 1
	if changed:
		_apply_walls()


## Mur carré de vase durcie (réutilise les murs déjà retombés) ; ceux qui sont dessus sont repoussés.
func _wall_for(pos: Vector2, half: float) -> int:
	var rect := Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0)
	var id: int
	if _wall_pool.is_empty():
		id = ctx.obstacles.add_wall(rect)
	else:
		id = _wall_pool.pop_back()
		ctx.obstacles.walls[id] = rect
		ctx.obstacles.set_wall_enabled(id, true)
	ctx.player.global_position = ctx.obstacles.push_out(ctx.player.global_position, ctx.player.radius)
	for enemy: Enemy in ctx.enemies.query_radius(pos, half * 2.0):
		if enemy.alive and not enemy.is_boss:
			enemy.position = ctx.obstacles.push_out(enemy.position, enemy.radius)
	ctx.fx.burst(pos, half * 1.4, Color(MUD, 0.5))
	return id


func _apply_walls() -> void:
	if ctx.flow:
		ctx.flow.apply_walls(ctx.obstacles)


func wall_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for puddle: Dictionary in puddles:
		if int(puddle["wall"]) >= 0:
			rects.append(ctx.obstacles.walls[int(puddle["wall"])])
	return rects


## Racine jaillissante : une racine file vers le Chasseur puis jaillit là où il se tenait. Rien ne le retient.
func root_leash(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var delay: float = float(params.get("slam_delay", 1.3))
	ctx.fx.danger_line(boss().position, ctx.player.global_position, 10.0, pattern.telegraph)
	intro("BOSS_LEASH_INTRO")
	brain.schedule(pattern.telegraph, func() -> void:
		var anchor: Vector2 = ctx.player.global_position
		root = {"from": boss().position, "anchor": anchor, "until": ctx.time + delay}
		ctx.hazards.add_circle(anchor, float(params.get("slam_radius", 130.0)), delay, brain._damage(pattern), true,
			brain.data.id))
	brain.busy_time = pattern.telegraph + delay + 0.3


func _step_root() -> void:
	if not root.is_empty() and ctx.time >= float(root["until"]):
		ctx.fx.debris(root["anchor"], ROOT, 10)
		root = {}


func leech_feed(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var data: EnemyData = GameDB.enemy(StringName(params.get("enemy", "mire_leech")))
	_leech_heal = float(params.get("heal_ratio", 0.005))
	if _leech_budget < 0.0:
		_leech_budget = boss().max_hp * float(params.get("heal_cap", 0.06))
	leeches.assign(leeches.filter(func(e: Variant) -> bool: return is_instance_valid(e) and (e as Enemy).alive))
	var count: int = mini(int(params.get("count", 4)), int(params.get("max_active", 6)) - leeches.size())
	var distance: float = float(params.get("distance", 430.0))
	var offset: float = ctx.rng.randf() * TAU
	for i: int in maxi(count, 0):
		var pos: Vector2 = boss().position + Vector2.RIGHT.rotated(offset + TAU * i / count) * distance
		pos = ctx.obstacles.push_out(pos.clamp(ctx.arena_rect().position + Vector2(60, 60),
			ctx.arena_rect().end - Vector2(60, 60)), 20.0)
		ctx.fx.ring(pos, 24.0, Color(0.5, 0.9, 0.5, 0.8), pattern.telegraph)
		brain.schedule(pattern.telegraph, func() -> void:
			if data == null:
				return
			var leech: Enemy = ctx.enemies.spawn(data, pos)
			leech.taunt_target = boss()
			leech.taunt_time = 60.0
			leeches.append(leech))
	intro("BOSS_LEECH_INTRO")
	brain.busy_time = pattern.telegraph + 0.3


## Une sangsue qui atteint le boss le soigne un peu et disparaît ; le soin total du combat est plafonné.
func _step_leeches() -> void:
	for leech: Enemy in leeches:
		if not is_instance_valid(leech) or not leech.alive:
			continue
		if leech.position.distance_to(boss().position) < boss().radius + leech.radius + 8.0:
			var before: float = boss().hp
			var heal: float = minf(boss().max_hp * _leech_heal, maxf(_leech_budget, 0.0))
			boss().hp = minf(boss().max_hp, boss().hp + heal)
			_leech_budget -= boss().hp - before
			ctx.stats.add(&"boss_leech_healed", boss().hp - before)
			ctx.fx.burst(boss().position, boss().radius, Color(0.5, 1.0, 0.5, 0.4))
			_play(VFX + "leech_feed", boss().position, leech.position - boss().position)
			ctx.enemies.marsh.vanish(leech)


# --- Phase 2 : carapace à facettes et miroirs à orienter -------------------------------------------------------

func side_of(from: Vector2) -> int:
	var angle: float = (from - boss().position).angle()
	return posmod(int(roundf(angle / (PI * 0.5))), SIDES)


func _facet_modifier(enemy: Enemy, info: DamageInfo) -> float:
	if facets.is_empty() or brain == null or enemy != boss() or not info.is_friendly() or info.is_proc:
		return 1.0
	var side: int = side_of(source_position(info))
	if facets[side] <= 0.0:
		return 1.0
	facets[side] -= info.amount
	if facets[side] <= 0.0:
		_break_facet(side)
	else:
		ctx.fx.spark(boss().position + Vector2.RIGHT.rotated(side * PI * 0.5) * boss().radius, CRYSTAL, 8.0)
	return _facet_mult


func _break_facet(side: int) -> void:
	facets[side] = 0.0
	_facet_regrow[side] = ctx.time + _facet_regrow_time
	ctx.fx.debris(boss().position + Vector2.RIGHT.rotated(side * PI * 0.5) * boss().radius, CRYSTAL, 12)
	_play(VFX + "facet_break", boss().position + Vector2.RIGHT.rotated(side * PI * 0.5) * boss().radius,
		Vector2.RIGHT.rotated(side * PI * 0.5))
	ctx.stats.add(&"boss_facets_broken")


func _step_facets() -> void:
	for side: int in facets.size():
		if facets[side] <= 0.0 and ctx.time >= _facet_regrow[side]:
			facets[side] = _facet_max


func _place_mirrors(distance: float) -> void:
	var area: Rect2 = ctx.arena_rect().grow(-MIRROR_RADIUS * 3.0)
	for i: int in 4:
		var pos: Vector2 = boss().position + Vector2.RIGHT.rotated(PI * 0.25 + i * PI * 0.5) * distance
		pos = ctx.obstacles.push_out(pos.clamp(area.position, area.end), MIRROR_RADIUS)
		mirrors.append({"pos": pos, "arrow": Vector2.UP, "flash": 0.6, "held": false})
	intro("BOSS_MIRROR_INTRO")


## Un miroir tenu (Chasseur à côté) se tourne vers le boss : il lui renverra le rayon. Seul, il ne fait que l'arrêter.
func _step_mirrors(delta: float) -> void:
	var player: Player = ctx.player
	for mirror: Dictionary in mirrors:
		mirror["flash"] = maxf(float(mirror["flash"]) - delta, 0.0)
		var pos: Vector2 = mirror["pos"]
		var held: bool = player.alive and player.global_position.distance_to(pos) <= MIRROR_HOLD
		if held and not mirror["held"]:
			mirror["flash"] = 0.4
			ctx.stats.add(&"boss_mirrors_turned")
		mirror["held"] = held
		var aim: Vector2 = (boss().position - pos).normalized() if held else Vector2.UP
		mirror["arrow"] = (mirror["arrow"] as Vector2).slerp(aim, minf(delta * 10.0, 1.0)).normalized()


func prism_beam(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	if mirrors.is_empty():
		_place_mirrors(float(params.get("mirror_distance", 360.0)))
	var start: float = (ctx.player.global_position - boss().position).angle()
	beam = {"start": ctx.time + pattern.telegraph, "end": ctx.time + pattern.telegraph + float(params.get("sweep_time", 3.2)),
		"angle": start, "side": 1.0 if ctx.rng.randf() < 0.5 else -1.0, "beams": int(params.get("beams", 1)),
		"arc": deg_to_rad(float(params.get("arc", 360.0))), "length": float(params.get("length", 1100.0)),
		"width": float(params.get("width", 36.0)), "damage": brain._damage(pattern), "tick": 0.0, "returned": false,
		"ratio": float(params.get("return_ratio", 0.04)), "stun": float(params.get("stun", 3.0)), "paths": []}
	ctx.fx.danger_line(boss().position, boss().position + Vector2.RIGHT.rotated(start) * 600.0, 30.0, pattern.telegraph)
	brain.busy_time = pattern.telegraph + float(params.get("sweep_time", 3.2)) + float(params.get("recovery", 0.6))


func beam_firing() -> bool:
	return not beam.is_empty() and ctx.time >= float(beam["start"])


func _step_beam(delta: float) -> void:
	if beam.is_empty():
		return
	if ctx.time >= float(beam["end"]):
		beam = {}
		return
	if not beam_firing():
		return
	var progress: float = (ctx.time - float(beam["start"])) / maxf(float(beam["end"]) - float(beam["start"]), 0.01)
	var paths: Array = []
	var returned: bool = false
	for b: int in int(beam["beams"]):
		var angle: float = float(beam["angle"]) + float(beam["side"]) * float(beam["arc"]) * progress + b * TAU / int(beam["beams"])
		var traced: Dictionary = trace(boss().position, Vector2.RIGHT.rotated(angle), float(beam["length"]))
		paths.append(traced["points"])
		returned = returned or bool(traced["returned"])
	beam["paths"] = paths
	beam["tick"] = float(beam["tick"]) - delta
	if float(beam["tick"]) <= 0.0:
		beam["tick"] = 0.25
		for path: PackedVector2Array in paths:
			if _near_path(path, ctx.player.global_position, float(beam["width"]) * 0.5 + ctx.player.radius):
				ctx.combat.damage_player(float(beam["damage"]), brain.data.id)
				ctx.stats.add(&"boss_beam_hits")
				break
	if returned and not beam["returned"]:
		_beam_returned()


## Trajet du rayon : arrêté par le décor, la vase durcie et les miroirs ; un miroir tenu par le Chasseur le renvoie
## droit sur le boss : returned.
func trace(origin: Vector2, dir: Vector2, length: float) -> Dictionary:
	var points := PackedVector2Array([origin])
	var from: Vector2 = origin + dir * boss().radius * 0.8
	var remaining: float = length
	var used: Dictionary = {}
	for bounce: int in 4:
		var hit: float = ctx.obstacles.clear_distance(from, dir, remaining)
		for rect: Rect2 in wall_rects():
			hit = minf(hit, _ray_rect(from, dir, rect))
		var mirror_index: int = -1
		for i: int in mirrors.size():
			if used.has(i):
				continue
			var to_mirror: Vector2 = (mirrors[i]["pos"] as Vector2) - from
			var along: float = to_mirror.dot(dir)
			if along > 0.0 and along < hit and (to_mirror - dir * along).length() < MIRROR_RADIUS:
				hit = along
				mirror_index = i
		if bounce > 0:
			var to_boss: Vector2 = boss().position - from
			var along_boss: float = to_boss.dot(dir)
			if along_boss > 0.0 and along_boss < hit and (to_boss - dir * along_boss).length() < boss().radius:
				points.append(from + dir * along_boss)
				return {"points": points, "returned": true}
		points.append(from + dir * hit)
		if mirror_index < 0:
			break
		used[mirror_index] = true
		var mirror: Dictionary = mirrors[mirror_index]
		mirror["flash"] = 0.15
		if not mirror["held"]:
			break
		from = mirror["pos"]
		dir = (boss().position - from).normalized()
		remaining = length
	return {"points": points, "returned": false}


## Distance le long d'un rayon jusqu'à un rectangle (INF s'il le manque).
static func _ray_rect(from: Vector2, dir: Vector2, rect: Rect2) -> float:
	var t_min: float = 0.0
	var t_max: float = INF
	for axis: int in 2:
		if absf(dir[axis]) < 0.0001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return INF
			continue
		var t1: float = (rect.position[axis] - from[axis]) / dir[axis]
		var t2: float = (rect.end[axis] - from[axis]) / dir[axis]
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
	return t_min if t_min <= t_max else INF


static func _near_path(path: PackedVector2Array, pos: Vector2, reach: float) -> bool:
	for i: int in path.size() - 1:
		if Geometry2D.get_closest_point_to_segment(pos, path[i], path[i + 1]).distance_to(pos) < reach:
			return true
	return false


## Rayon renvoyé : la carapace vole en éclats, le boss est étourdi et prend double dégâts le temps de se reprendre.
func _beam_returned() -> void:
	beam["returned"] = true
	for side: int in facets.size():
		if facets[side] > 0.0:
			_break_facet(side)
	strike_boss(float(beam["ratio"]))
	brain.stun(float(beam["stun"]))
	brain.heart_time = float(beam["stun"])
	ctx.fx.burst(boss().position, boss().radius * 2.0, Color(CRYSTAL, 0.6))
	ctx.fx.text(boss().position + Vector2(0, -boss().radius - 30.0), tr("BOSS_PRISM_RETURNED"), CRYSTAL)
	ctx.stats.add(&"boss_prism_returned")
	beam["end"] = ctx.time


# --- Phase 3 : tourbillon, anneau de marée, engloutissement ----------------------------------------------------

func whirlpool(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var duration: float = float(params.get("duration", 4.5))
	whirl = {"start": ctx.time + pattern.telegraph, "until": ctx.time + pattern.telegraph + duration,
		"pull": float(params.get("pull", 120.0)), "enemy_pull": float(params.get("enemy_pull", 90.0))}
	ctx.fx.ring(boss().position, 120.0, Color(WATER, 0.8), pattern.telegraph)
	brain.schedule(pattern.telegraph + duration - float(params.get("collapse_delay", 0.9)), func() -> void:
		ctx.hazards.add_circle(boss().position, float(params.get("collapse_radius", 190.0)),
			float(params.get("collapse_delay", 0.9)), brain._damage(pattern), true, brain.data.id))
	intro("BOSS_WHIRLPOOL_INTRO")
	brain.busy_time = pattern.telegraph + 0.4


func whirl_active() -> bool:
	return not whirl.is_empty() and ctx.time >= float(whirl["start"])


func _step_whirl(delta: float) -> void:
	if whirl.is_empty():
		return
	if ctx.time >= float(whirl["until"]):
		whirl = {}
		return
	if not whirl_active():
		return
	var center: Vector2 = boss().position
	var player: Player = ctx.player
	if not player.is_dashing():
		var offset: Vector2 = center - player.global_position
		if offset.length() > boss().radius + player.radius:
			var moved: Vector2 = player.global_position + offset.normalized() * float(whirl["pull"]) * delta
			player.global_position = ctx.obstacles.push_out(moved, player.radius)
	for enemy: Enemy in ctx.enemies.query_radius(center, 900.0):
		if enemy.alive and not enemy.is_boss and not enemy.is_obstacle:
			var to_center: Vector2 = center - enemy.position
			if to_center.length() > boss().radius + enemy.radius:
				enemy.position += to_center.normalized() * float(whirl["enemy_pull"]) * delta


## Raz-de-marée : des vagues partent du boss et traversent l'arène. Une Ruée les traverse, la vase durcie en abrite.
func tide_wave(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var count: int = int(params.get("waves", 2))
	var gap: float = float(params.get("gap", 1.1))
	var center: Vector2 = boss().position
	ctx.fx.ring(center, float(params.get("width", 40.0)) * 3.0, Color(WATER, 0.9), pattern.telegraph)
	for i: int in count:
		waves.append({"center": center, "radius": boss().radius, "speed": float(params.get("speed", 300.0)),
			"max": float(params.get("reach", 1100.0)), "damage": brain._damage(pattern),
			"width": float(params.get("width", 40.0)), "push": float(params.get("push", 90.0)),
			"start": ctx.time + pattern.telegraph + gap * i})
	intro("BOSS_TIDE_RING_INTRO")
	brain.busy_time = pattern.telegraph + gap * (count - 1) + 0.6


## La vague frappe le Chasseur quand son front le croise, sauf en pleine Ruée ou à l'abri d'un mur de vase.
func _step_waves(delta: float) -> void:
	var player: Player = ctx.player
	var i: int = waves.size() - 1
	while i >= 0:
		var wave: Dictionary = waves[i]
		if ctx.time >= float(wave["start"]):
			var center: Vector2 = wave["center"]
			var before: float = wave["radius"]
			wave["radius"] = before + float(wave["speed"]) * delta
			var offset: Vector2 = player.global_position - center
			var dist: float = offset.length()
			if dist > before and dist <= float(wave["radius"]) and not player.is_dashing() \
					and not sheltered(center, player.global_position):
				if ctx.combat.damage_player(float(wave["damage"]), brain.data.id) > 0.0:
					ctx.stats.add(&"boss_tide_hits")
					player.hinder(0.6, 0.6)
					player.global_position = ctx.obstacles.push_out(player.global_position
						+ offset.normalized() * float(wave["push"]), player.radius)
			if float(wave["radius"]) >= float(wave["max"]):
				waves.remove_at(i)
		i -= 1


## Un mur de vase durcie entre `from` et `pos` : la vague (comme le rayon) ne passe pas.
func sheltered(from: Vector2, pos: Vector2) -> bool:
	var dir: Vector2 = pos - from
	var length: float = dir.length()
	if length < 1.0:
		return false
	for rect: Rect2 in wall_rects():
		if _ray_rect(from, dir / length, rect) < length:
			return true
	return false


func _on_enemy_damaged(enemy: Enemy, info: DamageInfo, amount: float) -> void:
	if brain == null or enemy != boss() or not info.is_friendly():
		return
	if not swallowed.is_empty():
		swallowed["dealt"] = float(swallowed["dealt"]) + amount
		if float(swallowed["dealt"]) >= float(swallowed["need"]):
			_release(true)


func swallow(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	if not swallowed.is_empty() or ctx.allies == null or ctx.allies.team.is_empty():
		brain.busy_time = 0.3
		return
	var target: Ally = null
	for ally: Ally in ctx.allies.team:
		if target == null or ally.global_position.distance_to(boss().position) < target.global_position.distance_to(boss().position):
			target = ally
	_swallow_mark = {"ally": target, "until": ctx.time + pattern.telegraph}
	intro("BOSS_SWALLOW_INTRO")
	brain.schedule(pattern.telegraph, func() -> void:
		_swallow_mark = {}
		if not is_instance_valid(target) or target.global_position.distance_to(boss().position) > float(params.get("reach", 380.0)):
			return
		target.swallowed = true
		ctx.stats.add(&"boss_echo_swallowed")
		target.visible = false
		swallowed = {"ally": target, "until": ctx.time + float(params.get("duration", 8.0)), "dealt": 0.0,
			"need": boss().max_hp * float(params.get("free_ratio", 0.05)), "stun": float(params.get("stun", 1.5)),
			"daze": float(params.get("daze", 4.0))}
		ctx.fx.burst(boss().position, boss().radius * 1.4, Color(WATER, 0.5)))
	brain.busy_time = pattern.telegraph + 0.5


func _step_swallow() -> void:
	if swallowed.is_empty():
		return
	var ally: Ally = swallowed["ally"]
	if is_instance_valid(ally):
		ally.global_position = boss().position
	if ctx.time >= float(swallowed["until"]):
		_release(false)


## Libéré à temps : le boss est sonné. Sinon, l'Écho ressort sonné (ni attaque ni sort quelques secondes).
func _release(freed: bool) -> void:
	var ally: Ally = swallowed["ally"]
	var daze: float = float(swallowed["daze"])
	var stun: float = float(swallowed["stun"])
	swallowed = {}
	if not is_instance_valid(ally):
		return
	ally.swallowed = false
	ally.visible = true
	ally.global_position = ctx.obstacles.push_out(boss().position + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU)
		* (boss().radius + 40.0), Ally.BODY_RADIUS)
	ctx.fx.burst(ally.global_position, 40.0, Color(WATER, 0.6))
	_play(VFX + "echo_release", ally.global_position, ally.global_position - boss().position)
	if freed:
		brain.stun(stun)
		ctx.fx.text(boss().position + Vector2(0, -boss().radius - 30.0), tr("BOSS_ECHO_FREED"), Color(0.7, 1.0, 0.9))
		ctx.stats.add(&"boss_echo_freed")
	else:
		ally.attack_cd = maxf(ally.attack_cd, daze)
		ally.technique_cd = maxf(ally.technique_cd, daze)


# --- Bot -------------------------------------------------------------------------------------------------------

func danger(pos: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for puddle: Dictionary in puddles:
		var away: Vector2 = pos - (puddle["pos"] as Vector2)
		if int(puddle["wall"]) < 0 and away.length() < float(puddle["radius"]) + 20.0:
			result += away.normalized()
	if whirl_active():
		result += (pos - boss().position).normalized() * 1.5
	return result


## Rayon de prisme annoncé : se placer derrière le miroir le plus proche (côté opposé au boss) et y rester.
func bot_move(pos: Vector2) -> Vector2:
	var spot: Vector2 = _bot_mirror_spot(pos)
	if spot == Vector2.INF or pos.distance_to(spot) <= 18.0:
		return Vector2.ZERO
	return (spot - pos).normalized()


## Raz-de-marée : une Ruée quand le front de la vague arrive (sauf à l'abri).
func bot_dash() -> bool:
	var pos: Vector2 = ctx.player.global_position
	for wave: Dictionary in waves:
		var gap: float = pos.distance_to(wave["center"]) - float(wave["radius"])
		if ctx.time >= float(wave["start"]) and gap > 0.0 and gap < 45.0 and not sheltered(wave["center"], pos):
			return true
	return false


func _bot_mirror_spot(pos: Vector2) -> Vector2:
	if beam.is_empty() or mirrors.is_empty() or bool(beam["returned"]):
		return Vector2.INF
	var best: Dictionary = {}
	for mirror: Dictionary in mirrors:
		if best.is_empty() or (mirror["pos"] as Vector2).distance_to(pos) < (best["pos"] as Vector2).distance_to(pos):
			best = mirror
	if (best["pos"] as Vector2).distance_to(pos) > 520.0:
		return Vector2.INF
	var to_boss: Vector2 = boss().position - (best["pos"] as Vector2)
	return (best["pos"] as Vector2) - to_boss.normalized() * (MIRROR_RADIUS + 34.0)


# --- Effets peints (présentation seulement : géométrie et durées viennent des mécaniques) ------------------------

func _painted() -> PaintedVfx:
	return ctx.painted if ctx.painted and is_instance_valid(ctx.painted) else null


func _play(key: String, pos: Vector2, dir: Vector2 = Vector2.RIGHT, props: Dictionary = {}) -> void:
	if _painted():
		_painted().play(key, pos, dir, props)


## Boucles recalées chaque image sur l'état réel : vase et murs (durcissement), racine-laisse, carapace, miroirs,
## rayons (trajets déjà tracés), tourbillon, marée, Écho englouti, cœur exposé. Un état disparu dissipe sa boucle.
func _sync_vfx() -> void:
	_shown.clear()
	var painted: PaintedVfx = _painted()
	if painted == null or brain == null:
		return
	var center: Vector2 = boss().position
	for puddle: Dictionary in puddles:
		var pos: Vector2 = puddle["pos"]
		var radius: float = puddle["radius"]
		var hardening: float = clampf(inverse_lerp(float(puddle.get("born", 0.0)), float(puddle["harden_at"]), ctx.time),
			0.0, 1.0)
		var tag: String = "glq_mud_%d_%d" % [int(pos.x), int(pos.y)]
		_show(painted.sync(tag, VFX + "mud_wall", pos, {"radius": radius, "width": radius * 1.5}), tag, [1.0, hardening])
	if not root.is_empty():
		var anchor: Vector2 = root["anchor"]
		var fx: Node2D = painted.sync("glq_leash", VFX + "root_leash", anchor)
		if _show(fx, "glq_leash"):
			fx.call("set_path_local", PackedVector2Array([Vector2.ZERO, (root["from"] as Vector2) - anchor]))
	if not facets.is_empty():
		var fx: Node2D = painted.sync("glq_facets", VFX + "facets", center, {"radius": boss().radius + 10.0})
		if _show(fx, "glq_facets"):
			var values := PackedFloat32Array()
			for side: int in SIDES:
				values.append(facets[side] / maxf(_facet_max, 1.0))
			fx.call("set_facet_strengths", values)
	for i: int in mirrors.size():
		var fx: Node2D = painted.sync("glq_mirror%d" % i, VFX + "mirror", mirrors[i]["pos"], {"radius": MIRROR_RADIUS})
		if _show(fx, "glq_mirror%d" % i):
			fx.rotation = (mirrors[i]["arrow"] as Vector2).angle()
	if beam_firing():
		var paths: Array = beam["paths"]
		for b: int in paths.size():
			var fx: Node2D = painted.sync("glq_beam%d" % b, VFX + "prism_beam", center, {"width": float(beam["width"])})
			if _show(fx, "glq_beam%d" % b):
				var local := PackedVector2Array()
				for point: Vector2 in paths[b]:
					local.append(point - center)
				fx.call("set_path_local", local)
	if whirl_active():
		_show(painted.sync("glq_whirl", VFX + "whirlpool", center), "glq_whirl")
	for wave: Dictionary in waves:
		if ctx.time >= float(wave["start"]):
			var tag: String = "glq_tide%d" % int(float(wave["start"]) * 10.0)
			_show(painted.sync(tag, VFX + "tide_ring", wave["center"], {"radius": float(wave["radius"])}), tag)
	if not swallowed.is_empty():
		_show(painted.sync("glq_swallow", VFX + "swallow", center, {"radius": boss().radius * 0.45}), "glq_swallow")
	if brain.heart_time > 0.0 and boss().alive:
		_show(painted.sync("glq_heart", VFX + "heart_pulse", center, {"radius": boss().radius * 0.5}), "glq_heart")
	painted.prune("glq_")


## Note la boucle comme affichée ; `state` : intensité et durcissement transmis à l'effet.
func _show(fx: Node2D, tag: String, state: Array = []) -> bool:
	if fx == null:
		return false
	_shown[tag] = true
	if state.size() == 2:
		fx.call("set_visual_state", float(state[0]), float(state[1]))
	return true


# --- Dessin ----------------------------------------------------------------------------------------------------

func _draw() -> void:
	for wave: Dictionary in waves:
		if ctx.time < float(wave["start"]):
			continue
		var fade: float = clampf((float(wave["max"]) - float(wave["radius"])) / 200.0, 0.0, 1.0)
		draw_arc(wave["center"], float(wave["radius"]) - float(wave["width"]) * 0.5, 0.0, TAU, 96, Color(WATER, 0.5 * fade),
			float(wave["width"]))
		draw_arc(wave["center"], float(wave["radius"]), 0.0, TAU, 96, Color(0.85, 1.0, 0.97, 0.85 * fade), 4.0)
	for puddle: Dictionary in puddles:
		var pos: Vector2 = puddle["pos"]
		if _shown.has("glq_mud_%d_%d" % [int(pos.x), int(pos.y)]):
			continue
		if int(puddle["wall"]) < 0:
			var left: float = clampf((float(puddle["harden_at"]) - ctx.time) / 2.5, 0.0, 1.0)
			draw_circle(puddle["pos"], float(puddle["radius"]), Color(MUD, 0.55))
			draw_arc(puddle["pos"], float(puddle["radius"]) * (0.3 + 0.7 * left), 0.0, TAU, 32, Color(0.75, 0.6, 0.4, 0.8), 2.0)
		else:
			var rect: Rect2 = ctx.obstacles.walls[int(puddle["wall"])]
			draw_rect(rect, Color(0.28, 0.25, 0.18, 0.95))
			draw_rect(rect, Color(0.55, 0.48, 0.32), false, 3.0)
	if not root.is_empty() and not _shown.has("glq_leash"):
		draw_line(root["from"], root["anchor"], ROOT, 6.0)
		draw_circle(root["anchor"], 12.0, ROOT)
	if not _shown.has("glq_facets"):
		_draw_facets()
	for i: int in mirrors.size():
		_draw_mirror(mirrors[i], _shown.has("glq_mirror%d" % i))
	if not beam.is_empty():
		if beam_firing() and not _shown.has("glq_beam0"):
			for path: PackedVector2Array in beam["paths"]:
				draw_polyline(path, Color(CRYSTAL, 0.5), float(beam["width"]))
				draw_polyline(path, Color(1.0, 1.0, 1.0, 0.9), float(beam["width"]) * 0.3)
	if whirl_active() and not _shown.has("glq_whirl"):
		for k: int in 3:
			var r: float = fmod(_time * 160.0 + k * 140.0, 420.0) + 60.0
			draw_arc(boss().position, 480.0 - r, _time * 3.0 + k, _time * 3.0 + k + PI * 1.2, 24, Color(WATER, 0.6), 3.0)
	if not _swallow_mark.is_empty() and is_instance_valid(_swallow_mark["ally"]):
		draw_arc((_swallow_mark["ally"] as Ally).global_position, 30.0, 0.0, TAU, 24, Color(1.0, 0.3, 0.5, 0.9), 3.0)
	if not swallowed.is_empty():
		var progress: float = clampf(float(swallowed["dealt"]) / maxf(float(swallowed["need"]), 1.0), 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
		if not _shown.has("glq_swallow"):
			draw_circle(boss().position + Vector2(0, boss().radius * 0.3), 22.0 + 6.0 * pulse, Color(0.9, 1.0, 0.8, 0.45))
		draw_arc(boss().position, boss().radius + 18.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(0.7, 1.0, 0.9), 5.0)


func _draw_facets() -> void:
	if facets.is_empty():
		return
	for side: int in SIDES:
		if facets[side] <= 0.0:
			continue
		var center: float = side * PI * 0.5
		var strength: float = facets[side] / maxf(_facet_max, 1.0)
		draw_arc(boss().position, boss().radius + 10.0, center - 0.6, center + 0.6, 16, Color(CRYSTAL, 0.35 + 0.5 * strength), 7.0)


## Miroir provisoire ; peint, seuls les repères de jeu restent dessinés : zone où se tenir pendant un rayon, et trait
## vers le boss quand le miroir est tenu.
func _draw_mirror(mirror: Dictionary, painted: bool) -> void:
	var pos: Vector2 = mirror["pos"]
	var glow: float = float(mirror["flash"])
	var held: bool = mirror["held"]
	if not painted:
		var points := PackedVector2Array([pos + Vector2(0, -MIRROR_RADIUS), pos + Vector2(MIRROR_RADIUS * 0.7, 0),
			pos + Vector2(0, MIRROR_RADIUS), pos + Vector2(-MIRROR_RADIUS * 0.7, 0)])
		draw_colored_polygon(points, Color(CRYSTAL.lerp(Color.WHITE, glow), 0.75))
		points.append(points[0])
		draw_polyline(points, Color(0.3, 0.6, 0.8), 2.0)
	if beam.is_empty() and not held:
		return
	draw_arc(pos, MIRROR_HOLD, 0.0, TAU, 48, Color(CRYSTAL, 0.75 if held else 0.3), 3.0 if held else 2.0)
	if held:
		var to_boss: Vector2 = boss().position - pos
		draw_dashed_line(pos, pos + to_boss.normalized() * maxf(to_boss.length() - boss().radius, 0.0),
			Color(1.0, 1.0, 1.0, 0.55), 3.0, 14.0)
