class_name DraftBarkGuard
extends DraftBossMechanic
## Garde d'écorce, mécanique phare du Gardien d'écorce (chapitre 3, docs/design/MONSTRES.md), reprise de
## `MarshGuardians.bark_guard` pour le monde 3D : il s'enracine et lève son bouclier, qui pivote lentement vers le
## Chasseur. De face, les coups ne portent presque pas ; de dos ou de flanc, ils portent davantage. Des racines
## ralentissent le Chasseur au moment où il lève la garde.

const BARK := Color(0.45, 0.32, 0.2)
## Demi-angle de la face couverte par le bouclier.
const FRONT := deg_to_rad(60.0)

var guard: Dictionary = {}
var _clock: float = 0.0
var _shield: MeshInstance3D


func handles(kind: StringName) -> bool:
	return kind == &"bark_guard"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var to_hunter: Vector3 = brain.enemies.hunter.global_position - brain.foe.pos
	to_hunter.y = 0.0
	guard = {"facing": to_hunter.normalized() if to_hunter.length() > 0.01 else Vector3.RIGHT,
		"until": _clock + pattern.telegraph + float(params.get("duration", 7.0)) + (1.0 if brain.phase >= 1 else 0.0),
		"turn": float(params.get("turn_speed", 0.9)), "front": float(params.get("front_mult", 0.1)),
		"back": float(params.get("back_mult", 1.5))}
	_shield = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(brain.foe.radius * 2.4, 2.4, 0.3)
	_shield.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = BARK
	_shield.material_override = material
	brain.enemies.add_child(_shield)
	brain.enemies.hunter.hinder(0.5, 1.5)
	brain.fx(&"root_snare", brain.enemies.hunter.global_position + Vector3.UP * 0.3, 1.2)
	brain.play_clip([StringName(str(params.get("anim", "bark_shield"))), &"attack"], pattern.telegraph)
	return pattern.telegraph


func guarding() -> bool:
	return not guard.is_empty()


func holds_boss() -> bool:
	return guarding()


## Le Chasseur est-il devant le bouclier ?
func in_front() -> bool:
	var to_hunter: Vector3 = brain.enemies.hunter.global_position - brain.foe.pos
	to_hunter.y = 0.0
	return to_hunter.length() < 0.01 or (guard["facing"] as Vector3).angle_to(to_hunter.normalized()) <= FRONT


func damage_mult() -> float:
	if not guarding():
		return 1.0
	return float(guard["front"]) if in_front() else float(guard["back"])


func step(delta: float) -> void:
	_clock += delta
	if guard.is_empty():
		return
	if _clock >= float(guard["until"]):
		finish()
		return
	var foe: DraftEnemies.Foe = brain.foe
	var to_hunter: Vector3 = brain.enemies.hunter.global_position - foe.pos
	to_hunter.y = 0.0
	var facing: Vector3 = guard["facing"]
	if to_hunter.length() > 0.01:
		var wanted: float = facing.signed_angle_to(to_hunter.normalized(), Vector3.UP)
		guard["facing"] = facing.rotated(Vector3.UP, clampf(wanted, -float(guard["turn"]) * delta, float(guard["turn"]) * delta))
	facing = guard["facing"]
	_shield.global_position = foe.pos + facing * (foe.radius + 0.4) + Vector3.UP * 1.2
	_shield.look_at(_shield.global_position + facing, Vector3.UP)


func finish() -> void:
	if _shield != null:
		_shield.queue_free()
		_shield = null
	guard = {}
