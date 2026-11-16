class_name DraftSourceOrbs
extends DraftBossMechanic
## Orbes de source, mécanique phare du Dévoreur des Sources (chapitre 1, docs/design/MONSTRES.md), reprise de
## `BossSignatures.source_orb` pour le monde 3D : orbes lents qui suivent le Chasseur à hauteur de poitrine. Une Ruée
## (ou une Parade) dedans le renvoie sur le boss, qui perd une part de ses PV ; l'orbe doré l'étourdit. Touché sans
## Ruée : dégâts. Le décor arrête un orbe (comme un trait) : on peut s'en abriter.

const COLOR := Color(0.45, 0.85, 1.0)
const GOLD := Color(1.0, 0.85, 0.35)
## Rayon d'un orbe (m) et marge de la Ruée pour le renvoyer.
const RADIUS := 0.55
const DASH_MARGIN := 0.4
const RETURN_SPEED_MULT := 4.0
const HEIGHT := 0.9

## Orbes en vol : {"node", "pos", "vel", "speed", "life", "damage", "golden", "reflected", "stun", "ratio"}.
var orbs: Array[Dictionary] = []
var reflected: int = 0
var hits: int = 0


func handles(kind: StringName) -> bool:
	return kind == &"source_orb"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var count: int = int(params.get("count", 1))
	var golden: int = int(params.get("golden", 0))
	var spread: float = float(params.get("spread", 0.55))
	var speed: float = float(params.get("speed", 120.0)) * DraftHunter.UNIT
	var foe: DraftEnemies.Foe = brain.foe
	var to_hunter: Vector3 = brain.enemies.hunter.global_position - foe.pos
	to_hunter.y = 0.0
	var aim: Vector3 = to_hunter.normalized() if to_hunter.length() > 0.01 else Vector3.FORWARD
	brain.play_clip([StringName(str(params.get("anim", "rift_breath"))), &"attack"], pattern.telegraph + 0.3)
	brain.fx(&"ring_charge", mouth(), 1.4)
	intro("BOSS_ORB_INTRO")
	for i: int in count:
		var angle: float = (i - (count - 1) * 0.5) * spread
		orbs.append({"node": null, "pos": mouth(), "vel": aim.rotated(Vector3.UP, angle) * speed, "speed": speed,
			"life": float(params.get("life", 7.0)), "damage": brain.damage(pattern.damage), "golden": i == golden,
			"reflected": false, "stun": float(params.get("stun", 2.0)), "ratio": float(params.get("reflect_ratio", 0.03)),
			"wait": pattern.telegraph})
	return pattern.telegraph + float(params.get("recovery", 0.4))


## Bouche du Dévoreur : devant lui, à mi-hauteur.
func mouth() -> Vector3:
	var foe: DraftEnemies.Foe = brain.foe
	return foe.pos + Vector3.UP * HEIGHT


func step(delta: float) -> void:
	var hunter: DraftHunter = brain.enemies.hunter
	var i: int = orbs.size() - 1
	while i >= 0:
		var orb: Dictionary = orbs[i]
		if float(orb["wait"]) > 0.0:
			orb["wait"] = float(orb["wait"]) - delta
			if float(orb["wait"]) <= 0.0:
				orb["pos"] = mouth()
				orb["node"] = _make_node(bool(orb["golden"]))
			i -= 1
			continue
		if not _step_orb(orb, hunter, delta):
			(orb["node"] as Node3D).queue_free()
			orbs.remove_at(i)
		else:
			(orb["node"] as Node3D).global_position = orb["pos"]
		i -= 1


## Avance un orbe ; faux s'il disparaît.
func _step_orb(orb: Dictionary, hunter: DraftHunter, delta: float) -> bool:
	orb["life"] = float(orb["life"]) - delta
	var before: Vector3 = orb["pos"]
	var foe: DraftEnemies.Foe = brain.foe
	if orb["reflected"]:
		var to_boss: Vector3 = mouth() - before
		orb["pos"] = before + to_boss.normalized() * float(orb["speed"]) * RETURN_SPEED_MULT * delta
		if to_boss.length() < foe.radius + RADIUS + 0.3:
			_hit_boss(orb)
			return false
		return float(orb["life"]) > 0.0
	var to_hunter: Vector3 = hunter.chest() - before
	var wanted: Vector3 = to_hunter.normalized() * float(orb["speed"])
	orb["vel"] = (orb["vel"] as Vector3).lerp(wanted, clampf(1.6 * delta, 0.0, 1.0))
	orb["pos"] = before + (orb["vel"] as Vector3) * delta
	var reach: float = RADIUS + DraftHunter.RADIUS
	if to_hunter.length() < reach + DASH_MARGIN and (hunter.is_dashing() or hunter.guard_left > 0.0):
		orb["reflected"] = true
		orb["life"] = 4.0
		reflected += 1
		brain.fx(&"mana_burst", orb["pos"], 1.0)
		return true
	if to_hunter.length() < reach:
		if hunter.take_damage(float(orb["damage"])) > 0.0:
			hits += 1
			hunter.hinder(0.6, 1.5)
			brain.enemies.run.call("on_hunter_hit", foe)
		brain.fx(&"splash", orb["pos"], 1.0)
		return false
	if float(orb["life"]) <= 0.0 or not bool(brain.enemies.run.call("sight_clear", before, orb["pos"])):
		brain.fx(&"splash", orb["pos"], 0.8)
		return false
	return true


func _hit_boss(orb: Dictionary) -> void:
	var foe: DraftEnemies.Foe = brain.foe
	brain.strike_boss(float(orb["ratio"]))
	brain.fx(&"dark_explosion", foe.pos + Vector3.UP * 1.0, foe.radius * 1.4)
	if orb["golden"] and foe.alive:
		brain.stun(float(orb["stun"]))


func _make_node(golden: bool) -> Node3D:
	return make_orb(GOLD if golden else COLOR, RADIUS)


func finish() -> void:
	for orb: Dictionary in orbs:
		if orb["node"] != null:
			(orb["node"] as Node3D).queue_free()
	orbs.clear()
