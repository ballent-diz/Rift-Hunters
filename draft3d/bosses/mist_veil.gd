class_name DraftMistVeil
extends DraftBossMechanic
## Voile de brume, mécanique phare de la Chimère des brumes (chapitre 1, docs/design/MONSTRES.md), reprise de
## `GuardianSignatures.mist_veil` pour le monde 3D : la Chimère allume des lanternes autour d'elle et devient brume
## (coups presque tous sans effet) tant qu'une lanterne brûle. Les briser toutes la fige : sonnée, coups × 2 quelques
## secondes. Un voile qui tient jusqu'au bout lui rend des PV. Les lanternes sont des cibles de l'attaque automatique.

const MIST := Color(0.75, 0.85, 1.25)
## Part des coups qui traverse la brume (jamais zéro : un boss n'est jamais totalement invulnérable).
const VEILED_MULT := 0.05
const EXPOSED_MULT := 2.0

## Voile en cours : {"until", "heal", "stun", "exposed"} (vide : aucun).
var veil: Dictionary = {}
var lanterns: Array[DraftEnemies.Foe] = []
var broken: int = 0
var _exposed_left: float = 0.0
var _clock: float = 0.0


func handles(kind: StringName) -> bool:
	return kind == &"mist_veil"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var data: EnemyData = GameDB.enemy(StringName(str(params.get("lantern", "mist_lantern"))))
	if data == null:
		return 0.0
	var count: int = int(params.get("count", 3))
	var distance: float = float(params.get("distance", 380.0)) * DraftHunter.UNIT
	var foe: DraftEnemies.Foe = brain.foe
	var offset: float = brain.enemies.rng.randf() * TAU
	lanterns.clear()
	for i: int in count:
		var angle: float = offset + TAU * i / count
		var at: Vector3 = brain.enemies.level.closest(foe.pos + Vector3(cos(angle), 0, sin(angle)) * distance)
		var lantern: DraftEnemies.Foe = brain.enemies.spawn(data, at)
		lantern.xp = 0
		lanterns.append(lantern)
		brain.fx(&"fog", at + Vector3.UP * 0.5, 1.4)
	veil = {"until": _clock + pattern.telegraph + float(params.get("duration", 12.0)),
		"heal": float(params.get("heal_ratio", 0.04)), "stun": float(params.get("stun", 2.5)),
		"exposed": float(params.get("exposed", 4.0))}
	foe.view.set_tint(MIST)
	brain.fx(&"fog", foe.pos + Vector3.UP * 0.8, foe.radius * 2.0)
	brain.play_clip([&"attack"], pattern.telegraph)
	intro("BOSS_VEIL_INTRO")
	return pattern.telegraph + 0.3


func veiled() -> bool:
	return not veil.is_empty()


func damage_mult() -> float:
	if veiled():
		return VEILED_MULT
	return EXPOSED_MULT if _exposed_left > 0.0 else 1.0


func lanterns_alive() -> Array[DraftEnemies.Foe]:
	var alive: Array[DraftEnemies.Foe] = []
	for lantern: DraftEnemies.Foe in lanterns:
		if lantern.alive:
			alive.append(lantern)
	return alive


func step(delta: float) -> void:
	_clock += delta
	_exposed_left = maxf(_exposed_left - delta, 0.0)
	if veil.is_empty():
		return
	var foe: DraftEnemies.Foe = brain.foe
	if lanterns_alive().is_empty():
		# Dernière lanterne brisée : la Chimère se fige, sonnée et vulnérable.
		var stun: float = veil["stun"]
		_exposed_left = float(veil["exposed"])
		broken += 1
		_end()
		brain.stun(stun)
		brain.fx(&"ring_burst", foe.pos + Vector3.UP * 0.5, foe.radius * 2.0)
	elif _clock >= float(veil["until"]):
		var heal: float = veil["heal"]
		_end()
		foe.hp = minf(foe.max_hp, foe.hp + foe.max_hp * heal)
		brain.fx(&"healing_bloom", foe.pos + Vector3.UP * 0.8, foe.radius * 1.5)


func _end() -> void:
	for lantern: DraftEnemies.Foe in lanterns_alive():
		brain.enemies.vanish(lantern)
	lanterns.clear()
	veil = {}
	if brain.foe.view != null:
		brain.foe.view.set_tint(Color.WHITE)


func finish() -> void:
	_end()
