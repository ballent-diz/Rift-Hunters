class_name DraftSilkThreads
extends DraftBossMechanic
## Fils tendus, mécanique phare de la Reine-veuve (chapitre 2, docs/design/MONSTRES.md), reprise de
## `AshGuardians.silk_threads` pour le monde 3D : elle tend des fils de soie autour du Chasseur. En toucher un colle sur
## place (seule une Ruée libère) et la Reine bondit sur la proie engluée. Une Ruée à travers un fil le tranche.

const SILK := Color(0.92, 0.9, 0.85)
const THICKNESS := 0.12

## Fils : {"a", "b", "node"} (extrémités au sol).
var threads: Array[Dictionary] = []
var cut: int = 0
var caught: int = 0
var _until: float = 0.0
var _clock: float = 0.0
var _stick: float = 1.2
var _pounce: BossPatternData
var _cooldown: float = 0.0


func handles(kind: StringName) -> bool:
	return kind == &"silk_threads"


func perform(pattern: BossPatternData) -> float:
	_clear()
	var params: Dictionary = pattern.params
	var rng: RandomNumberGenerator = brain.enemies.rng
	var level: DraftLevel = brain.enemies.level
	var center: Vector3 = brain.enemies.hunter.global_position
	var length: float = float(params.get("length", 420.0)) * DraftHunter.UNIT
	var count: int = int(params.get("count", 4)) + (2 if brain.phase >= 1 else 0)
	for i: int in count:
		var angle: float = TAU * i / count + rng.randf_range(-0.3, 0.3)
		var middle: Vector3 = center + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(2.0, 4.5)
		var along := Vector3(cos(angle + PI * 0.5), 0, sin(angle + PI * 0.5))
		var a: Vector3 = level.closest(middle - along * length * 0.5)
		var b: Vector3 = level.closest(middle + along * length * 0.5)
		threads.append({"a": a, "b": b, "node": _thread(a, b)})
	_until = _clock + float(params.get("duration", 14.0))
	_stick = float(params.get("stick", 1.2))
	_pounce = BossPatternData.new()
	_pounce.kind = &"pounce"
	_pounce.telegraph = 0.35
	_pounce.damage = float(params.get("pounce_damage", 20.0))
	_pounce.params = {"radius": float(params.get("pounce_radius", 120.0)) * 0.6}
	brain.play_clip([StringName(str(params.get("anim", "soot_web"))), &"attack"], pattern.telegraph)
	intro("BOSS_THREADS_INTRO")
	return pattern.telegraph + 0.3


## Distance à plat du point au fil.
static func distance_to(point: Vector3, a: Vector3, b: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	return Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(p)


func step(delta: float) -> void:
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if threads.is_empty():
		return
	if _clock >= _until:
		_clear()
		return
	var hunter: DraftHunter = brain.enemies.hunter
	var here: Vector3 = hunter.global_position
	for i: int in range(threads.size() - 1, -1, -1):
		var thread: Dictionary = threads[i]
		var a: Vector3 = thread["a"]
		if distance_to(here, a, thread["b"]) > DraftHunter.RADIUS + THICKNESS or absf(here.y - a.y) > 1.0:
			continue
		if hunter.is_dashing():
			cut += 1
			brain.fx(&"spin_slash", here + Vector3.UP * 0.6, 0.8)
			(thread["node"] as Node).queue_free()
			threads.remove_at(i)
		elif hunter.stuck_left <= 0.0 and _cooldown <= 0.0 and hunter.alive:
			caught += 1
			_cooldown = _stick + 1.0
			hunter.stick(_stick)
			brain.pounce(_pounce)


func _thread(a: Vector3, b: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(THICKNESS, THICKNESS, a.distance_to(b))
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SILK
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain.enemies.add_child(node)
	node.global_position = (a + b) * 0.5 + Vector3.UP * 0.35
	node.look_at(b + Vector3.UP * 0.35, Vector3.UP)
	return node


func _clear() -> void:
	for thread: Dictionary in threads:
		(thread["node"] as Node).queue_free()
	threads.clear()


func finish() -> void:
	_clear()
