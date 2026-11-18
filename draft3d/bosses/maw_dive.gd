class_name DraftMawDive
extends DraftBossMechanic
## Plongée, mécanique phare de la Gueule des marais (chapitre 3, docs/design/MONSTRES.md), reprise de
## `MarshGuardians.maw_dive` pour le monde 3D : elle plonge, intouchable ; une ride suit le Chasseur quelques secondes,
## l'onde de sortie s'annonce, puis elle ressurgit : sonnée et vulnérable (coups × 2).

const RIPPLE := Color(0.35, 0.6, 0.55, 0.55)
const SUBMERGED_MULT := 0.2
const ICE := Color(0.7, 0.9, 1.0, 0.55)

## Technique jouée : `maw_dive` (Gueule des marais) ou `frozen_dive` (Nivorath, plongée sous la banquise).
var dive_kind: StringName = &"maw_dive"

var dive: Dictionary = {}
var surfaced: int = 0
var _clock: float = 0.0
var _exposed_left: float = 0.0
var _ripple: MeshInstance3D


func _init(p_kind: StringName = &"maw_dive") -> void:
	dive_kind = p_kind


func handles(kind: StringName) -> bool:
	return kind == dive_kind


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	dive = {"from": _clock + pattern.telegraph, "chase_until": _clock + pattern.telegraph + float(params.get("chase", 2.5)),
		"warning": float(params.get("warning", 0.9)), "speed": float(params.get("speed", 230.0)) * DraftHunter.UNIT,
		"radius": float(params.get("radius", 150.0)) * DraftHunter.UNIT, "stun": float(params.get("stun", 2.0)),
		"damage": brain.damage(pattern.damage), "warned": false}
	brain.play_clip([StringName(str(params.get("anim", "dive"))), &"attack"], pattern.telegraph)
	brain.fx(&"splash", foe.pos + Vector3.UP * 0.4, foe.radius * 1.5)
	return pattern.telegraph


func submerged() -> bool:
	return not dive.is_empty() and _clock >= float(dive["from"])


func hides_boss() -> bool:
	return submerged()


func holds_boss() -> bool:
	return not dive.is_empty()


func damage_mult() -> float:
	if submerged():
		return SUBMERGED_MULT
	return 2.0 / DraftBossBrain.STUN_DAMAGE_MULT if _exposed_left > 0.0 else 1.0


func step(delta: float) -> void:
	_clock += delta
	_exposed_left = maxf(_exposed_left - delta, 0.0)
	if not submerged():
		return
	var foe: DraftEnemies.Foe = brain.foe
	foe.view.visible = false
	if _ripple == null:
		_ripple = make_disc(foe.pos, foe.radius + 0.4, ICE if dive_kind == &"frozen_dive" else RIPPLE)
	if _clock < float(dive["chase_until"]):
		# La ride suit le Chasseur.
		var to_hunter: Vector3 = brain.enemies.hunter.global_position - foe.pos
		to_hunter.y = 0.0
		if to_hunter.length() > 0.3:
			foe.pos = brain.enemies.level.closest(foe.pos + to_hunter.normalized() * minf(float(dive["speed"]) * delta,
				to_hunter.length()))
			foe.view.snap_to(foe.pos)
	elif not bool(dive["warned"]):
		dive["warned"] = true
		brain.enemies.hazards.circle(foe.pos, float(dive["radius"]), float(dive["warning"]), float(dive["damage"]),
			brain.fx_at(&"ice_shatter" if dive_kind == &"frozen_dive" else &"splash", float(dive["radius"])))
	elif _clock >= float(dive["chase_until"]) + float(dive["warning"]):
		_surface()
	if _ripple != null:
		_ripple.global_position = foe.pos + Vector3.UP * 0.06


func _surface() -> void:
	var foe: DraftEnemies.Foe = brain.foe
	surfaced += 1
	foe.view.visible = true
	_exposed_left = float(dive["stun"]) + 1.0
	dive = {}
	if _ripple != null:
		_ripple.queue_free()
		_ripple = null
	brain.stun(float(_exposed_left - 1.0))


func finish() -> void:
	if _ripple != null:
		_ripple.queue_free()
		_ripple = null
	if not dive.is_empty():
		brain.foe.view.visible = true
	dive = {}
