class_name DraftGlauquemire
extends DraftBossMechanic
## Glauquemire, Dévoreur des Marais engloutis (chapitre 3, docs/design/DEVOREUR_CHAPITRE3.md, refonte du 11 novembre
## 2026), repris de `GlauquemireMechanics` pour le monde 3D. Rien ne retient ni n'enferme le Chasseur.
## - Phase 1 : vase qui ralentit puis durcit en murs solides (ils bloquent tout et arrêtent le rayon), racine
##   jaillissante là où se tenait le Chasseur, sangsues qui rampent vers le boss et le soignent (plafonné).
## - Phase 2 : carapace à quatre facettes (une face intacte ne laisse passer que 30 % des coups venus de son côté) et
##   miroirs ; **mécanique phare** : le rayon de prisme balaie l'arène ; un miroir l'arrête et, si le Chasseur se tient
##   à côté, le renvoie sur le boss (carapace brisée, étourdi, coups × 2).
## - Phase 3 : tourbillon qui aspire puis se referme, raz-de-marée (vagues à traverser d'une Ruée ou derrière la vase
##   durcie), rayon double. L'engloutissement d'un Écho (v1) devient l'engloutissement des Corrompus proches, qui le
##   soignent puis sont recrachés ; un gros coup l'interrompt.

const MUD := Color(0.32, 0.26, 0.16, 0.7)
const MUD_WALL := Color(0.36, 0.29, 0.18)
const CRYSTAL := Color(0.6, 0.95, 1.0)
const BEAM := Color(0.75, 1.0, 1.0, 0.85)
const MIRROR_SIZE := Vector3(2.2, 2.6, 0.35)
const BEAM_HEIGHT := 1.0
const BEAM_TICK := 0.4
## Côtés de la carapace (repère du monde, elle ne tourne pas) : droite, bas, gauche, haut.
const SIDES := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]

## Flaques et murs : {"pos", "radius", "harden_at", "crumble_at", "disc", "wall"}.
var puddles: Array[Dictionary] = []
var leeches: Array[DraftEnemies.Foe] = []
var healed: float = 0.0
## Facettes : PV restants par côté (vide : pas de carapace), repousse.
var facets: Array[float] = []
var mirrors: Array[Dictionary] = []
## Rayon en cours : {"angle", "speed", "until", "from", "beams", "damage", "ratio", "stun", "nodes", "reflected"}.
var beam: Dictionary = {}
var reflections: int = 0
var whirl: Dictionary = {}
var swallowed: Dictionary = {}
var _clock: float = 0.0
var _facet_ratio: float = 0.035
var _facet_mult: float = 0.3
var _facet_regrow: float = 14.0
var _facet_regrow_at: float = 0.0
var _exposed_left: float = 0.0
var _beam_tick: float = 0.0
var _facet_nodes: Array[MeshInstance3D] = []


func handles(kind: StringName) -> bool:
	return kind in [&"mud_wall", &"root_leash", &"leech_feed", &"prism_beam", &"whirlpool", &"tide_wave", &"swallow"]


func perform(pattern: BossPatternData) -> float:
	match pattern.kind:
		&"mud_wall":
			return _mud(pattern)
		&"root_leash":
			return _root(pattern)
		&"leech_feed":
			return _leeches(pattern)
		&"prism_beam":
			return _beam(pattern)
		&"whirlpool":
			return _whirlpool(pattern)
		&"tide_wave":
			return _tide(pattern)
		&"swallow":
			return _swallow(pattern)
	return 0.0


func on_phase(index: int) -> void:
	var p: BossPhaseData = brain.phase_data()
	var params: Dictionary = p.mechanic_params
	if p.mechanics.has(&"facets"):
		_facet_ratio = float(params.get("facet_ratio", _facet_ratio))
		_facet_mult = float(params.get("facet_mult", _facet_mult))
		_facet_regrow = float(params.get("facet_regrow", _facet_regrow))
		_grow_facets()
		intro("BOSS_FACETS_INTRO")
	elif index >= 2:
		_drop_facets()
	if p.mechanics.has(&"mirrors") and mirrors.is_empty():
		_place_mirrors(float(params.get("mirror_distance", 360.0)) * DraftHunter.UNIT)


# --- Phase 1 -------------------------------------------------------------------------------------------------------

func _mud(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var rng: RandomNumberGenerator = brain.enemies.rng
	var radius: float = float(params.get("radius", 75.0)) * DraftHunter.UNIT
	var spread: float = float(params.get("spread", 150.0)) * DraftHunter.UNIT
	var center: Vector3 = brain.enemies.hunter.global_position
	for i: int in int(params.get("count", 3)):
		var angle: float = TAU * i / int(params.get("count", 3)) + rng.randf() * 0.6
		var at: Vector3 = brain.enemies.level.closest(center + Vector3(cos(angle), 0, sin(angle)) * spread * rng.randf_range(0.4, 1.0))
		brain.enemies.hazards.circle(at, radius, pattern.telegraph, brain.damage(pattern.damage),
			brain.painted_at(["mud_impact"], Vector3.RIGHT, 0.1, &"splash", radius))
		puddles.append({"pos": at, "radius": radius, "harden_at": _clock + pattern.telegraph + float(params.get("harden", 2.5)),
			"crumble_at": _clock + pattern.telegraph + float(params.get("harden", 2.5)) + float(params.get("wall_time", 7.0)),
			"disc": make_disc(at, radius, MUD), "wall": null})
	brain.play_clip([&"mud_spit", &"attack"], pattern.telegraph)
	intro("BOSS_MUD_WALL_INTRO")
	return pattern.telegraph + 0.3


func _step_mud() -> void:
	var hunter: DraftHunter = brain.enemies.hunter
	for i: int in range(puddles.size() - 1, -1, -1):
		var puddle: Dictionary = puddles[i]
		var offset: Vector3 = hunter.global_position - (puddle["pos"] as Vector3)
		var inside: bool = Vector2(offset.x, offset.z).length() < float(puddle["radius"]) + DraftHunter.RADIUS
		if puddle["wall"] == null:
			if inside:
				hunter.hinder(0.55, 0.3)
			if _clock >= float(puddle["harden_at"]):
				# La vase durcit en mur : le Chasseur qui s'y tenait est repoussé au bord.
				if inside:
					var away: Vector3 = Vector3(offset.x, 0, offset.z).normalized() if offset.length() > 0.05 else Vector3.RIGHT
					hunter.global_position = brain.enemies.level.closest((puddle["pos"] as Vector3)
						+ away * (float(puddle["radius"]) + 0.8)) + Vector3.UP * 0.1
				var side: float = float(puddle["radius"]) * 1.6
				puddle["wall"] = make_block(puddle["pos"], Vector3(side, 2.2, side), MUD_WALL)
				var radius_px: float = float(puddle["radius"]) / DraftHunter.UNIT
				brain.painted(["mud_wall"], puddle["pos"], Vector3.RIGHT, -1.0, float(puddle["crumble_at"]) - _clock,
					{"radius": radius_px, "width": radius_px * 1.5})
				(puddle["disc"] as Node).queue_free()
				puddle["disc"] = null
		elif _clock >= float(puddle["crumble_at"]):
			brain.fx(&"dirt_explosion", (puddle["pos"] as Vector3) + Vector3.UP, float(puddle["radius"]))
			(puddle["wall"] as Node).queue_free()
			puddles.remove_at(i)


func _root(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var target: Vector3 = brain.enemies.level.closest(brain.enemies.hunter.global_position)
	var foe: DraftEnemies.Foe = brain.foe
	var to_target: Vector3 = target - foe.pos
	to_target.y = 0.0
	var delay: float = float(params.get("slam_delay", 1.3))
	var radius: float = float(params.get("slam_radius", 130.0)) * DraftHunter.UNIT
	brain.enemies.hazards.line(foe.pos, to_target.normalized(), maxf(to_target.length(), 1.0), 0.6, pattern.telegraph, 0.0)
	brain.enemies.hazards.circle(target, radius, pattern.telegraph + delay, brain.damage(pattern.damage),
		brain.painted_at(["root_leash"], to_target, 0.6, &"root_snare", radius))
	brain.play_clip([&"root_lash", &"attack"], pattern.telegraph)
	intro("BOSS_LEASH_INTRO")
	return pattern.telegraph + 0.4


func _leeches(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var data: EnemyData = GameDB.enemy(StringName(str(params.get("enemy", "mire_leech"))))
	if not DraftRoster.usable(data):
		return 0.0
	var alive: int = 0
	for leech: DraftEnemies.Foe in leeches:
		alive += 1 if leech.alive else 0
	var foe: DraftEnemies.Foe = brain.foe
	var distance: float = float(params.get("distance", 430.0)) * DraftHunter.UNIT
	var spin: float = brain.enemies.rng.randf() * TAU
	var count: int = mini(int(params.get("count", 4)), int(params.get("max_active", 6)) - alive)
	for i: int in count:
		var angle: float = spin + TAU * i / maxi(count, 1)
		var at: Vector3 = brain.enemies.level.closest(foe.pos + Vector3(cos(angle), 0, sin(angle)) * distance)
		var leech: DraftEnemies.Foe = brain.enemies.spawn(data, at)
		leech.follow = foe
		leech.set_meta(&"heal", float(params.get("heal_ratio", 0.005)))
		leech.set_meta(&"cap", float(params.get("heal_cap", 0.06)))
		leeches.append(leech)
		brain.fx(&"summon_rise", at + Vector3.UP * 0.4, 1.0)
	brain.play_clip([&"leech_call", &"summon", &"attack"], pattern.telegraph)
	intro("BOSS_LEECH_INTRO")
	return pattern.telegraph + 0.2


func _step_leeches() -> void:
	var foe: DraftEnemies.Foe = brain.foe
	for i: int in range(leeches.size() - 1, -1, -1):
		var leech: DraftEnemies.Foe = leeches[i]
		if not leech.alive:
			leeches.remove_at(i)
			continue
		if leech.pos.distance_to(foe.pos) < foe.radius + leech.radius + 0.4:
			heal(foe.max_hp * float(leech.get_meta(&"heal")), float(leech.get_meta(&"cap")))
			brain.painted(["leech_feed"], leech.pos, Vector3.RIGHT)
			brain.enemies.vanish(leech)
			leeches.remove_at(i)


## Soin du boss, plafonné sur tout le combat.
func heal(amount: float, cap: float = 0.06) -> void:
	var foe: DraftEnemies.Foe = brain.foe
	var room: float = maxf(foe.max_hp * cap - healed, 0.0)
	var gained: float = minf(amount, room)
	if gained <= 0.0:
		return
	healed += gained
	foe.hp = minf(foe.max_hp, foe.hp + gained)
	brain.fx(&"healing_bloom", foe.pos + Vector3.UP, 1.5)


# --- Phase 2 : facettes, miroirs, rayon de prisme ------------------------------------------------------------------

func _grow_facets() -> void:
	facets.clear()
	for side: int in 4:
		facets.append(brain.foe.max_hp * _facet_ratio)
	if _facet_nodes.is_empty():
		for side: int in 4:
			_facet_nodes.append(make_orb(CRYSTAL, 0.45))


func _drop_facets() -> void:
	facets.clear()
	for node: MeshInstance3D in _facet_nodes:
		node.queue_free()
	_facet_nodes.clear()


## Côté de la carapace tourné vers le Chasseur.
func facing_side() -> int:
	var offset: Vector3 = brain.enemies.hunter.global_position - brain.foe.pos
	if absf(offset.x) >= absf(offset.z):
		return 0 if offset.x >= 0.0 else 2
	return 1 if offset.z >= 0.0 else 3


func damage_mult() -> float:
	var mult: float = 2.0 if _exposed_left > 0.0 else 1.0
	if not facets.is_empty() and facets[facing_side()] > 0.0:
		mult *= _facet_mult
	return mult


func on_hit(dealt: float) -> void:
	if facets.is_empty():
		return
	var side: int = facing_side()
	if facets[side] <= 0.0:
		return
	facets[side] -= dealt / maxf(_facet_mult, 0.01)
	if facets[side] <= 0.0:
		if not brain.painted(["facet_break"], brain.foe.pos + (SIDES[side] as Vector3) * brain.foe.radius, SIDES[side]):
			brain.fx(&"ice_shatter", brain.foe.pos + (SIDES[side] as Vector3) * brain.foe.radius + Vector3.UP, 1.4)
		_facet_regrow_at = _clock + _facet_regrow


func _place_mirrors(distance: float) -> void:
	var foe: DraftEnemies.Foe = brain.foe
	var space: PhysicsDirectSpaceState3D = brain.enemies.get_world_3d().direct_space_state
	var origin: Vector3 = foe.pos + Vector3.UP * BEAM_HEIGHT
	for k: int in 4:
		# Place en vue directe du boss (le rayon doit pouvoir l'atteindre), en tournant un peu si le décor gêne.
		var at := Vector3.INF
		for attempt: int in 8:
			var angle: float = TAU * k / 4.0 + PI * 0.25 + floorf((attempt + 1) * 0.5) * 0.2 * (1.0 if attempt % 2 == 0 else -1.0)
			var spot: Vector3 = brain.enemies.level.closest(foe.pos + Vector3(cos(angle), 0, sin(angle)) * distance)
			if at == Vector3.INF:
				at = spot
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, spot + Vector3.UP * BEAM_HEIGHT, 1)).is_empty():
				at = spot
				break
		var body: StaticBody3D = make_block(at, MIRROR_SIZE, CRYSTAL)
		body.look_at(Vector3(foe.pos.x, body.global_position.y, foe.pos.z), Vector3.UP)
		var zone: MeshInstance3D = make_disc(at, 3.6, Color(CRYSTAL, 0.0))
		mirrors.append({"pos": at, "body": body, "zone": zone})
	intro("BOSS_MIRROR_INTRO")


func _beam(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var to_hunter: Vector3 = brain.enemies.hunter.global_position - foe.pos
	var start: float = atan2(to_hunter.z, to_hunter.x) + PI * 0.5
	var arc: float = deg_to_rad(float(params.get("arc", 360.0)))
	var sweep: float = float(params.get("sweep_time", 3.2))
	var beams: int = int(params.get("beams", 1))
	var nodes: Array[MeshInstance3D] = []
	for b: int in beams:
		nodes.append(_beam_node())
	beam = {"angle": start, "speed": arc / sweep * (1.0 if brain.enemies.rng.randf() < 0.5 else -1.0),
		"from": _clock + pattern.telegraph, "until": _clock + pattern.telegraph + sweep, "beams": beams,
		"length": float(params.get("length", 1100.0)) * DraftHunter.UNIT, "width": float(params.get("width", 36.0)) * DraftHunter.UNIT,
		"damage": brain.damage(pattern.damage), "ratio": float(params.get("return_ratio", 0.04)),
		"stun": float(params.get("stun", 3.0)), "nodes": nodes, "reflected": false}
	for mirror: Dictionary in mirrors:
		((mirror["zone"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(CRYSTAL, 0.18)
	brain.play_clip([&"prism_beam", &"attack"], pattern.telegraph + sweep)
	intro("BOSS_MIRROR_INTRO")
	return pattern.telegraph + sweep + 0.3


func beaming() -> bool:
	return not beam.is_empty() and _clock >= float(beam["from"])


func _step_beam(delta: float) -> void:
	if beam.is_empty():
		return
	var foe: DraftEnemies.Foe = brain.foe
	if beaming():
		beam["angle"] = float(beam["angle"]) + float(beam["speed"]) * delta
	_beam_tick = maxf(_beam_tick - delta, 0.0)
	var space: PhysicsDirectSpaceState3D = brain.enemies.get_world_3d().direct_space_state
	var origin: Vector3 = foe.pos + Vector3.UP * BEAM_HEIGHT
	var hunter: DraftHunter = brain.enemies.hunter
	for b: int in int(beam["beams"]):
		var angle: float = float(beam["angle"]) + PI * b
		var direction := Vector3(cos(angle), 0, sin(angle))
		var length: float = beam["length"]
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * length, 1))
		var mirror: Dictionary = {}
		if not hit.is_empty():
			length = origin.distance_to(hit["position"])
			for candidate: Dictionary in mirrors:
				if hit["collider"] == candidate["body"]:
					mirror = candidate
		var node: MeshInstance3D = (beam["nodes"] as Array)[b]
		node.global_position = origin + direction * length * 0.5
		node.look_at(origin + direction * length, Vector3.UP)
		(node.mesh as BoxMesh).size = Vector3(float(beam["width"]) if beaming() else 0.15, 0.2, length)
		if not beaming():
			continue
		# Le Chasseur dans le rayon, avant l'obstacle : touché.
		var offset: Vector3 = hunter.chest() - origin
		var along: float = offset.dot(direction)
		var side: float = (Vector3(offset.x, 0, offset.z) - direction * along).length()
		if along > 0.0 and along < length and side < float(beam["width"]) * 0.5 + DraftHunter.RADIUS \
				and absf(offset.y) < 1.5 and _beam_tick <= 0.0 and hunter.alive:
			_beam_tick = BEAM_TICK
			hunter.take_damage(float(beam["damage"]))
		# Miroir tenu (Chasseur à côté) : le rayon repart sur le boss.
		if not mirror.is_empty() and not bool(beam["reflected"]) \
				and hunter.global_position.distance_to(mirror["pos"]) < 3.6:
			beam["reflected"] = true
			_reflect(mirror)
			return
	if _clock >= float(beam["until"]):
		_end_beam()


func _reflect(mirror: Dictionary) -> void:
	reflections += 1
	var foe: DraftEnemies.Foe = brain.foe
	brain.fx(&"arcane_beam", ((mirror["pos"] as Vector3) + foe.pos) * 0.5 + Vector3.UP, 2.5)
	brain.strike_boss(float(beam["ratio"]))
	for side: int in facets.size():
		facets[side] = 0.0
	_facet_regrow_at = _clock + _facet_regrow
	_exposed_left = float(beam["stun"]) + 1.0
	if foe.alive:
		brain.stun(float(beam["stun"]))
	_end_beam()


func _end_beam() -> void:
	for node: MeshInstance3D in beam.get("nodes", []):
		node.queue_free()
	for mirror: Dictionary in mirrors:
		((mirror["zone"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(CRYSTAL, 0.0)
	beam = {}


func _beam_node() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.2, 1.0)
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = BEAM
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain.enemies.add_child(node)
	return node


# --- Phase 3 -------------------------------------------------------------------------------------------------------

func _whirlpool(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var duration: float = float(params.get("duration", 4.5))
	var radius: float = float(params.get("collapse_radius", 190.0)) * DraftHunter.UNIT
	whirl = {"from": _clock + pattern.telegraph, "until": _clock + pattern.telegraph + duration,
		"pull": float(params.get("pull", 120.0)) * DraftHunter.UNIT}
	brain.painted(["whirlpool"], brain.foe.pos, Vector3.RIGHT, -1.0, pattern.telegraph + duration)
	brain.enemies.hazards.circle(brain.foe.pos, radius, pattern.telegraph + duration + float(params.get("collapse_delay", 0.9)),
		brain.damage(pattern.damage), brain.fx_at(&"splash", radius))
	brain.play_clip([&"whirlpool", &"attack"], pattern.telegraph + duration)
	intro("BOSS_WHIRLPOOL_INTRO")
	return pattern.telegraph + duration + 0.4


func holds_boss() -> bool:
	return not whirl.is_empty()


func _step_whirl(delta: float) -> void:
	if whirl.is_empty():
		return
	if _clock >= float(whirl["until"]):
		whirl = {}
		return
	if _clock < float(whirl["from"]):
		return
	var hunter: DraftHunter = brain.enemies.hunter
	var to_boss: Vector3 = brain.foe.pos - hunter.global_position
	to_boss.y = 0.0
	if to_boss.length() > brain.foe.radius + 0.6 and not hunter.is_dashing():
		hunter.move_and_collide(to_boss.normalized() * float(whirl["pull"]) * delta)


func _tide(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var speed: float = float(params.get("speed", 300.0)) * DraftHunter.UNIT
	var reach: float = float(params.get("reach", 1100.0)) * DraftHunter.UNIT
	for w: int in int(params.get("waves", 2)):
		brain.enemies.hazards.ring(brain.foe.pos, speed, reach, pattern.telegraph + float(params.get("gap", 1.1)) * w,
			brain.damage(pattern.damage), brain.fx_at(&"splash", 2.0) if w == 0 else Callable())
	brain.play_clip([&"whirlpool", &"roar", &"attack"], pattern.telegraph)
	intro("BOSS_TIDE_RING_INTRO")
	return pattern.telegraph + 0.5


func _swallow(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var eaten: int = 0
	for other: DraftEnemies.Foe in brain.enemies.near(foe.pos, float(params.get("reach", 380.0)) * DraftHunter.UNIT):
		if other.brain != null or eaten >= 4:
			continue
		brain.fx(&"splash", other.pos + Vector3.UP * 0.5, 1.0)
		brain.enemies.vanish(other)
		eaten += 1
	swallowed = {"count": eaten, "until": _clock + pattern.telegraph + 1.5, "hp": foe.hp,
		"free": foe.max_hp * float(params.get("free_ratio", 0.05)), "stun": float(params.get("stun", 1.5)),
		"damage": brain.damage(14.0)}
	brain.play_clip([&"swallow", &"attack"], pattern.telegraph + 1.5)
	brain.painted(["swallow"], foe.pos, Vector3.RIGHT, -1.0, pattern.telegraph + 1.5,
		{"radius": foe.radius / DraftHunter.UNIT * 0.45})
	intro("BOSS_SWALLOW_INTRO_3D")
	return pattern.telegraph + 1.6


func _step_swallow() -> void:
	if swallowed.is_empty():
		return
	var foe: DraftEnemies.Foe = brain.foe
	if float(swallowed["hp"]) - foe.hp >= float(swallowed["free"]):
		# Assez de coups pendant la digestion : il s'étrangle, sonné, sans soin ni crachat.
		swallowed = {}
		brain.stun(1.5)
		brain.painted(["echo_release"], foe.pos, Vector3.RIGHT)
		return
	if _clock < float(swallowed["until"]):
		return
	var count: int = swallowed["count"]
	heal(foe.max_hp * 0.005 * count)
	var to_hunter: Vector3 = brain.enemies.hunter.chest() - (foe.pos + Vector3.UP)
	for k: int in count * 2:
		var aim: Vector3 = to_hunter.normalized().rotated(Vector3.UP, deg_to_rad(-30.0 + 60.0 * k / maxi(count * 2 - 1, 1)))
		brain.enemies.run.call("hostile_shot", foe.pos + Vector3.UP, aim, 9.0, float(swallowed["damage"]), brain.family())
	swallowed = {}


# --- Boucle --------------------------------------------------------------------------------------------------------

func step(delta: float) -> void:
	_clock += delta
	_exposed_left = maxf(_exposed_left - delta, 0.0)
	_step_mud()
	_step_leeches()
	_step_beam(delta)
	_step_whirl(delta)
	_step_swallow()
	if not facets.is_empty():
		if _facet_regrow_at > 0.0 and _clock >= _facet_regrow_at:
			_facet_regrow_at = 0.0
			_grow_facets()
		var foe: DraftEnemies.Foe = brain.foe
		for side: int in _facet_nodes.size():
			_facet_nodes[side].visible = facets[side] > 0.0
			_facet_nodes[side].global_position = foe.pos + (SIDES[side] as Vector3) * (foe.radius + 0.3) + Vector3.UP * 1.0


func finish() -> void:
	for puddle: Dictionary in puddles:
		if puddle["disc"] != null:
			(puddle["disc"] as Node).queue_free()
		if puddle["wall"] != null:
			(puddle["wall"] as Node).queue_free()
	puddles.clear()
	for leech: DraftEnemies.Foe in leeches:
		brain.enemies.vanish(leech)
	leeches.clear()
	_end_beam()
	_drop_facets()
	for mirror: Dictionary in mirrors:
		(mirror["body"] as Node).queue_free()
		(mirror["zone"] as Node).queue_free()
	mirrors.clear()
	whirl = {}
	swallowed = {}
