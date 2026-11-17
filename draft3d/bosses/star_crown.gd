class_name DraftStarCrown
extends DraftBossMechanic
## Couronne d'astres, mécanique phare d'Astravorn (chapitre 1, docs/design/MONSTRES.md), reprise de
## `BossSignatures.star_crown` pour le monde 3D : un anneau d'étoiles tourne autour du boss avec des brèches, rétrécit et
## accélère. Les étoiles blessent au contact. Tant qu'elle tourne, le boss se concentre (il n'attaque plus) et les
## coups portés de l'extérieur sont presque tous absorbés : entrer par une brèche et frapper de près. À la fin, les
## étoiles partent vers l'extérieur : rester près du boss protège.

const COLOR := Color(1.0, 0.92, 0.55)
const STAR_RADIUS := 0.45
const HEIGHT := 0.8

## Couronne en cours (vide : aucune).
var crown: Dictionary = {}
var reversals: int = 0
var _nodes: Array[MeshInstance3D] = []
var _hit_cooldown: float = 0.0


func handles(kind: StringName) -> bool:
	return kind == &"star_crown"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var stars: int = int(params.get("stars", 16))
	var gap_count: int = int(params.get("gaps", 2))
	var gap_width: int = int(params.get("gap_width", 2))
	var gaps: Dictionary = {}
	var first: int = brain.enemies.rng.randi() % stars
	for g: int in gap_count:
		for w: int in gap_width:
			gaps[(first + g * stars / gap_count + w) % stars] = true
	var start: float = float(params.get("start_radius", 380.0)) * DraftHunter.UNIT
	crown = {"stars": stars, "gaps": gaps, "angle": brain.enemies.rng.randf() * TAU, "start": start,
		"end": float(params.get("end_radius", 150.0)) * DraftHunter.UNIT, "radius": start,
		"spin": float(params.get("spin", 0.8)), "spin_end": float(params.get("spin_end", 1.8)),
		"rise": pattern.telegraph, "total": float(params.get("duration", 9.0)), "elapsed": 0.0,
		"damage": brain.damage(pattern.damage), "outside": float(params.get("outside_mult", 0.15)),
		"burst_speed": float(params.get("burst_speed", 210.0)) * DraftHunter.UNIT, "reverse": brain.phase >= 1}
	for s: int in stars:
		var node: MeshInstance3D = make_orb(COLOR, STAR_RADIUS)
		node.visible = not gaps.has(s)
		_nodes.append(node)
	_place()
	brain.play_clip([&"phase2_attack", &"attack"], pattern.telegraph)
	intro("BOSS_CROWN_INTRO")
	return 0.0


## Après la couronne, le rayon du vide (seconde phase) : on sort de la couronne pour se faire balayer.
func next_kind(last: StringName) -> StringName:
	return &"void_beam" if last == &"star_crown" else &""


func active() -> bool:
	return not crown.is_empty() and float(crown["elapsed"]) >= float(crown["rise"])


## Concentré sur sa couronne : ni marche ni autre attaque, c'est la fenêtre pour entrer et frapper.
func holds_boss() -> bool:
	return not crown.is_empty()


## Coups du Chasseur : pleins de l'intérieur de la couronne, presque tous absorbés de l'extérieur.
func damage_mult() -> float:
	if not active():
		return 1.0
	var offset: Vector3 = brain.enemies.hunter.global_position - brain.foe.pos
	return 1.0 if Vector2(offset.x, offset.z).length() <= float(crown["radius"]) else float(crown["outside"])


func star_positions() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if crown.is_empty():
		return points
	var stars: int = crown["stars"]
	for s: int in stars:
		if not (crown["gaps"] as Dictionary).has(s):
			points.append(_star(s))
	return points


func _star(index: int) -> Vector3:
	var angle: float = float(crown["angle"]) + TAU * index / int(crown["stars"])
	return brain.foe.pos + Vector3(cos(angle), 0, sin(angle)) * float(crown["radius"]) + Vector3.UP * HEIGHT


func _place() -> void:
	for s: int in _nodes.size():
		_nodes[s].global_position = _star(s)


func step(delta: float) -> void:
	if crown.is_empty():
		return
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	crown["elapsed"] = float(crown["elapsed"]) + delta
	var t: float = clampf((float(crown["elapsed"]) - float(crown["rise"])) / float(crown["total"]), 0.0, 1.0)
	crown["radius"] = lerpf(crown["start"], crown["end"], t)
	# Seconde phase : la couronne change de sens à mi-course (il faut relire la brèche).
	var turn: float = -1.0 if bool(crown.get("reverse", false)) and t >= 0.5 else 1.0
	if turn < 0.0 and not bool(crown.get("reversed", false)):
		crown["reversed"] = true
		reversals += 1
		brain.fx(&"ring_charge", brain.foe.pos + Vector3.UP * 0.4, 1.6)
	crown["angle"] = float(crown["angle"]) + lerpf(crown["spin"], crown["spin_end"], t) * delta * turn
	_place()
	if not active():
		return
	var hunter: DraftHunter = brain.enemies.hunter
	if _hit_cooldown <= 0.0 and hunter.alive:
		for point: Vector3 in star_positions():
			var offset: Vector3 = hunter.chest() - point
			if Vector2(offset.x, offset.z).length() < STAR_RADIUS + DraftHunter.RADIUS and absf(offset.y) < 1.2:
				_hit_cooldown = 0.5
				hunter.take_damage(float(crown["damage"]))
				break
	if t >= 1.0:
		_burst()


## Fin de la couronne : chaque étoile part vers l'extérieur.
func _burst() -> void:
	var family: StringName = brain.family()
	for point: Vector3 in star_positions():
		var away: Vector3 = point - brain.foe.pos
		away.y = 0.0
		brain.enemies.run.call("hostile_shot", point, away.normalized(), float(crown["burst_speed"]),
			float(crown["damage"]) * 0.7, family, 3.0)
	brain.fx(&"ring_burst", brain.foe.pos + Vector3.UP * 0.5, float(crown["radius"]) * 0.5)
	_clear()


func _clear() -> void:
	for node: MeshInstance3D in _nodes:
		node.queue_free()
	_nodes.clear()
	crown = {}


func finish() -> void:
	_clear()
