class_name DraftFrostGuardians
extends DraftBossMechanic
## Mécaniques phares des gardiens du chapitre 4 (docs/design/MONSTRES.md), reprises de `BossController` et
## `FrostElder` pour le monde 3D. Une instance par gardien ; elle ne joue que la technique de sa signature.
## - Avalanche (Patriarche des cimes) : boules de neige en éventail, annoncées par des lignes ; elles grossissent en
##   roulant et éclatent contre le décor (un abri les arrête).
## - Grand gel (Chaman ancestral) : pas de braseros en 3D ; un refuge de chaleur s'allume près du Chasseur, puis une
##   vague de gel frappe tout ce qui est dehors : dégâts et prison de glace (une Ruée la brise).
## - Chasse dans la tempête (Loup alpha des tempêtes) : il disparaît dans la neige et charge plusieurs fois, chaque
##   fois d'un autre côté du Chasseur, sur une ligne annoncée ; vulnérable entre deux charges.
## - Séisme de banquise (Colosse de la banquise) : onde autour de lui ; les plaques sous le Chasseur se fendent puis
##   s'ouvrent sur l'eau noire quelques secondes (dégâts et ralenti).

const SNOW := Color(0.92, 0.96, 1.0)
const WARM := Color(1.0, 0.6, 0.25, 0.4)
const WATER := Color(0.08, 0.12, 0.2, 0.75)
const CRACK := Color(0.7, 0.85, 1.0, 0.45)

var kind: StringName
## Boules en vol : {"node", "pos", "dir", "speed", "radius", "max", "damage", "left"}.
var balls: Array[Dictionary] = []
var freeze: Dictionary = {}
var hunt: Dictionary = {}
## Plaques : {"pos", "size", "opens", "closes", "node", "damage"}.
var plates: Array[Dictionary] = []
var frozen: int = 0
var _clock: float = 0.0
var _tick: float = 0.0


func _init(p_kind: StringName = &"") -> void:
	kind = p_kind


func handles(p_kind: StringName) -> bool:
	return p_kind == kind


func perform(pattern: BossPatternData) -> float:
	match kind:
		&"avalanche":
			return _avalanche(pattern)
		&"deep_freeze":
			return _deep_freeze(pattern)
		&"storm_hunt":
			return _storm_hunt(pattern)
		&"floe_quake":
			return _floe_quake(pattern)
	return 0.0


func holds_boss() -> bool:
	return not hunt.is_empty()


func hides_boss() -> bool:
	return not hunt.is_empty() and bool(hunt["hidden"])


func step(delta: float) -> void:
	_clock += delta
	_tick = maxf(_tick - delta, 0.0)
	_step_balls(delta)
	_step_freeze()
	_step_hunt()
	_step_plates()


# --- Avalanche -----------------------------------------------------------------------------------------------------

func _avalanche(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var aim: Vector3 = brain.enemies.hunter.global_position - foe.pos
	aim.y = 0.0
	aim = aim.normalized()
	var count: int = int(params.get("count", 3)) + (1 if brain.phase >= 1 else 0)
	for i: int in count:
		var direction: Vector3 = aim.rotated(Vector3.UP, (i - (count - 1) * 0.5) * float(params.get("spread", 0.35)))
		brain.enemies.hazards.line(foe.pos, direction, 24.0, 1.6, pattern.telegraph, 0.0)
		balls.append({"node": null, "pos": foe.pos + direction * (foe.radius + 0.5), "dir": direction, "wait": pattern.telegraph,
			"speed": float(params.get("speed", 300.0)) * DraftHunter.UNIT, "radius": float(params.get("radius", 24.0)) * DraftHunter.UNIT,
			"max": float(params.get("max_radius", 80.0)) * DraftHunter.UNIT, "damage": brain.damage(pattern.damage), "left": 4.0})
	brain.play_clip([StringName(str(params.get("anim", "avalanche"))), &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.3


func _step_balls(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = brain.enemies.get_world_3d().direct_space_state
	var hunter: DraftHunter = brain.enemies.hunter
	for i: int in range(balls.size() - 1, -1, -1):
		var ball: Dictionary = balls[i]
		if float(ball["wait"]) > 0.0:
			ball["wait"] = float(ball["wait"]) - delta
			continue
		if ball["node"] == null:
			ball["node"] = make_orb(SNOW, 1.0)
		var radius: float = minf(float(ball["radius"]) + delta * 0.6, float(ball["max"]))
		ball["radius"] = radius
		var from: Vector3 = (ball["pos"] as Vector3) + Vector3.UP * 0.6
		var to: Vector3 = from + (ball["dir"] as Vector3) * float(ball["speed"]) * delta
		ball["left"] = float(ball["left"]) - delta
		var done: bool = float(ball["left"]) <= 0.0 \
			or not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to + (ball["dir"] as Vector3) * radius, 1)).is_empty()
		ball["pos"] = to - Vector3.UP * 0.6
		var offset: Vector3 = hunter.global_position - (ball["pos"] as Vector3)
		if not done and Vector2(offset.x, offset.z).length() < radius + DraftHunter.RADIUS and absf(offset.y) < 1.2:
			if hunter.take_damage(float(ball["damage"])) > 0.0:
				brain.enemies.run.call("on_hunter_hit", brain.foe)
			done = true
		var node: MeshInstance3D = ball["node"]
		node.global_position = (ball["pos"] as Vector3) + Vector3.UP * radius
		node.scale = Vector3.ONE * radius
		if done:
			brain.fx(&"snowflake_burst", (ball["pos"] as Vector3) + Vector3.UP * 0.6, radius * 1.4)
			node.queue_free()
			balls.remove_at(i)


# --- Grand gel -----------------------------------------------------------------------------------------------------

func _deep_freeze(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var hunter: Vector3 = brain.enemies.hunter.global_position
	var angle: float = brain.enemies.rng.randf() * TAU
	var refuge: Vector3 = brain.enemies.level.closest(hunter + Vector3(cos(angle), 0, sin(angle)) * 7.0)
	freeze = {"at": _clock + pattern.telegraph, "pos": refuge, "radius": 2.6, "damage": brain.damage(pattern.damage),
		"prison": float(params.get("prison", 2.0)), "disc": make_disc(refuge, 2.6, WARM)}
	brain.fx(&"torch", refuge + Vector3.UP * 0.8, 1.6)
	brain.play_clip([StringName(str(params.get("anim", "snuff"))), &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.4


func _step_freeze() -> void:
	if freeze.is_empty() or _clock < float(freeze["at"]):
		return
	var hunter: DraftHunter = brain.enemies.hunter
	var offset: Vector3 = hunter.global_position - (freeze["pos"] as Vector3)
	brain.fx(&"frost_nova", brain.foe.pos + Vector3.UP * 0.5, 4.0)
	if Vector2(offset.x, offset.z).length() > float(freeze["radius"]) + DraftHunter.RADIUS and hunter.alive:
		frozen += 1
		hunter.take_damage(float(freeze["damage"]))
		hunter.stick(float(freeze["prison"]))
		brain.fx(&"freeze", hunter.chest(), 1.4)
	(freeze["disc"] as Node).queue_free()
	freeze = {}


# --- Chasse dans la tempête ----------------------------------------------------------------------------------------

func _storm_hunt(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	hunt = {"left": int(params.get("count", 3)) + (1 if brain.phase >= 1 else 0), "gap": float(params.get("gap", 1.6)),
		"next": _clock + pattern.telegraph, "reach": float(params.get("reach", 520.0)) * DraftHunter.UNIT,
		"speed": float(params.get("speed", 760.0)), "damage": pattern.damage, "spin": brain.enemies.rng.randf() * TAU,
		"hidden": false}
	brain.fx(&"blizzard", brain.foe.pos + Vector3.UP * 0.8, 2.0)
	brain.play_clip([StringName(str(params.get("anim", "slide"))), &"attack"], pattern.telegraph)
	return pattern.telegraph


func _step_hunt() -> void:
	if hunt.is_empty() or brain.moves_itself() or brain.stunned():
		return
	var foe: DraftEnemies.Foe = brain.foe
	foe.view.visible = true
	hunt["hidden"] = false
	if _clock < float(hunt["next"]):
		return
	if int(hunt["left"]) <= 0:
		hunt = {}
		return
	# Nouvelle charge depuis un autre côté du Chasseur.
	hunt["left"] = int(hunt["left"]) - 1
	hunt["spin"] = float(hunt["spin"]) + TAU / 3.0 + brain.enemies.rng.randf_range(-0.4, 0.4)
	var hunter: Vector3 = brain.enemies.hunter.global_position
	var spin: float = hunt["spin"]
	var start: Vector3 = brain.enemies.level.closest(hunter + Vector3(cos(spin), 0, sin(spin)) * float(hunt["reach"]))
	brain.fx(&"blink_out", foe.pos + Vector3.UP * 0.6, 1.4)
	foe.pos = start
	foe.view.snap_to(start)
	var aim: Vector3 = hunter - start
	aim.y = 0.0
	var charge := BossPatternData.new()
	charge.kind = &"charge"
	charge.telegraph = 0.75
	charge.damage = float(hunt["damage"])
	charge.params = {"speed": float(hunt["speed"]), "length": float(hunt["reach"]) * 2.0 / DraftHunter.UNIT, "stun": 1.2}
	brain.charge(charge, aim.normalized())
	hunt["next"] = _clock + 0.75 + float(hunt["reach"]) * 2.0 / clampf(float(hunt["speed"]) * DraftHunter.UNIT, 10.0, 22.0) \
		+ float(hunt["gap"])


# --- Séisme de banquise --------------------------------------------------------------------------------------------

func _floe_quake(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	brain.enemies.hazards.ring(foe.pos, 8.0, 14.0, pattern.telegraph, brain.damage(pattern.damage), brain.fx_at(&"ice_shatter", 2.0))
	var size: float = clampf(float(params.get("radius", 260.0)) * DraftHunter.UNIT * 0.4, 2.5, 4.0)
	var hunter: Vector3 = brain.enemies.hunter.global_position
	for p: int in int(params.get("plates", 2)) + (1 if brain.phase >= 1 else 0):
		var offset := Vector3.ZERO if p == 0 else Vector3(brain.enemies.rng.randf_range(-6, 6), 0, brain.enemies.rng.randf_range(-6, 6))
		var at: Vector3 = brain.enemies.level.closest(hunter + offset)
		plates.append({"pos": at, "size": size, "opens": _clock + pattern.telegraph + float(params.get("warning", 1.6)),
			"closes": _clock + pattern.telegraph + float(params.get("warning", 1.6)) + 4.0, "node": make_disc(at, size, CRACK),
			"damage": brain.damage(pattern.damage), "open": false})
	brain.play_clip([StringName(str(params.get("anim", "ice_crack"))), &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.4


func _step_plates() -> void:
	var hunter: DraftHunter = brain.enemies.hunter
	for i: int in range(plates.size() - 1, -1, -1):
		var plate: Dictionary = plates[i]
		if _clock >= float(plate["closes"]):
			(plate["node"] as Node).queue_free()
			plates.remove_at(i)
			continue
		if _clock < float(plate["opens"]):
			continue
		if not bool(plate["open"]):
			plate["open"] = true
			DraftCombatFx.tint(plate["node"], WATER)
			brain.fx(&"splash", (plate["pos"] as Vector3) + Vector3.UP * 0.4, float(plate["size"]))
		var offset: Vector3 = hunter.global_position - (plate["pos"] as Vector3)
		if Vector2(offset.x, offset.z).length() < float(plate["size"]) and absf(offset.y) < 1.0:
			hunter.hinder(0.5, 0.4)
			if _tick <= 0.0:
				_tick = 0.6
				hunter.take_damage(float(plate["damage"]) * 0.5)


func finish() -> void:
	for ball: Dictionary in balls:
		if ball["node"] != null:
			(ball["node"] as Node).queue_free()
	balls.clear()
	if not freeze.is_empty():
		(freeze["disc"] as Node).queue_free()
	freeze = {}
	hunt = {}
	brain.foe.view.visible = true
	for plate: Dictionary in plates:
		(plate["node"] as Node).queue_free()
	plates.clear()
