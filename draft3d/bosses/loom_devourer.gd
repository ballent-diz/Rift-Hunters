class_name DraftLoomDevourer
extends DraftBossMechanic
## L'Ourdisseur, Dévoreur des Linceuls (chapitre 6, docs/art/OURDISSEUR.md) : « Barrage de chaîne ». Il tend deux fils
## qui s'accrochent au décor de part et d'autre du Chasseur (un pilier, un mur ; à défaut, un montant de noyer sort du
## sol), puis les met en tension : les fils balaient le sol.
## - Métier tendu (phase 1) : les fils se referment l'un vers l'autre ; on sort du coin qu'ils dessinent.
## - Trame inversée (phase 2) : ils s'ouvrent vers l'extérieur ; on prend le passage entre les deux.
## Le geste annonce le sens (`warp_gate` ou `reverse_weave`), les pistes du balayage s'allument au sol, le décor
## arrête un fil. Aucun texte ne l'explique. Enchaînement : barrage → navette tirée vers lui → balayage du bras.

const WALNUT := Color(0.42, 0.29, 0.18)
const SLACK := Color(0.78, 0.74, 0.64)
const TAUT := Color(0.86, 0.22, 0.24)
const POST := Vector3(0.55, 2.8, 0.55)
const THICKNESS := 0.1
## Distance au-delà de laquelle il ne lance ni barrage ni navette : il se rapproche d'abord (m).
const REACH := 16.0

## Barrages et navettes joués, ancrages pris sur le décor ou posés (essais).
var barrages: int = 0
var reels: int = 0
var decor_anchors: int = 0
var posts: Array[Dictionary] = []
## Fils : {"node", "side", "from", "to", "length"} (angles autour de `_aim`, en radians).
var threads: Array[Dictionary] = []
var _clock: float = 0.0
var _aim := Vector3.RIGHT
var _tension_at: float = -1.0
var _end_at: float = -1.0
var _sweep: float = 1.0


func handles(kind: StringName) -> bool:
	return kind == &"warp_barrage" or kind == &"shuttle_reel"


func allows(kind: StringName, distance: float) -> bool:
	return not handles(kind) or distance <= REACH


func next_kind(last: StringName) -> StringName:
	match last:
		&"warp_barrage":
			return &"shuttle_reel"
		&"shuttle_reel":
			return &"sweep"
	return &""


func holds_boss() -> bool:
	return _end_at >= 0.0 and _clock < _end_at


func perform(pattern: BossPatternData) -> float:
	if pattern.kind == &"shuttle_reel":
		return _reel(pattern)
	return _barrage(pattern)


func _barrage(pattern: BossPatternData) -> float:
	_clear_threads()
	barrages += 1
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var hunter: Vector3 = brain.enemies.hunter.global_position
	var to_hunter: Vector3 = hunter - foe.pos
	to_hunter.y = 0.0
	_aim = to_hunter.normalized() if to_hunter.length() > 0.01 else Vector3.RIGHT
	var reach: float = clampf(to_hunter.length() + 5.0, 10.0, float(params.get("length", 520.0)) * DraftHunter.UNIT)
	var half: float = deg_to_rad(float(params.get("half_angle", 32.0)))
	var arc: float = deg_to_rad(float(params.get("arc", 45.0)))
	var reverse: bool = bool(params.get("reverse", false))
	var steps: int = clampi(int(params.get("steps", 6)), 3, 10)
	_sweep = float(params.get("sweep_time", 1.0))
	_tension_at = _clock + pattern.telegraph
	_end_at = _tension_at + _sweep + 0.4
	for side: float in [-1.0, 1.0]:
		var from: float = side * half
		var to: float = side * (half + arc) if reverse else 0.0
		var length: float = _anchor(_aim.rotated(Vector3.UP, from), reach)
		threads.append({"node": _thread(), "side": side, "from": from, "to": to, "length": length})
		for k: int in steps:
			var angle: float = lerpf(from, to, float(k) / (steps - 1))
			brain.enemies.hazards.line(foe.pos, _aim.rotated(Vector3.UP, angle), length, 1.2,
				pattern.telegraph + _sweep * k / (steps - 1), brain.damage(pattern.damage), true,
				minf(pattern.telegraph, 0.48), 0.5)
	_place_threads()
	brain.play_clip([StringName(str(params.get("anim", "warp_gate"))), &"warp_gate", &"attack"],
		pattern.telegraph + _sweep)
	return pattern.telegraph + _sweep + 0.4


## Point d'accroche d'un fil : le premier obstacle du décor sur sa ligne, sinon un montant de noyer posé au bout.
## Renvoie la longueur du fil.
func _anchor(direction: Vector3, reach: float) -> float:
	var foe: DraftEnemies.Foe = brain.foe
	var origin: Vector3 = foe.pos + Vector3.UP * 0.8
	var space: PhysicsDirectSpaceState3D = brain.enemies.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * reach, 1))
	if not hit.is_empty() and origin.distance_to(hit["position"]) > foe.radius + 3.0:
		decor_anchors += 1
		brain.fx(&"dirt_explosion", (hit["position"] as Vector3), 0.9)
		return origin.distance_to(hit["position"])
	var at: Vector3 = brain.enemies.level.closest(foe.pos + direction * reach)
	posts.append({"body": make_block(at, POST, WALNUT), "pos": at, "until": _end_at + 1.0})
	brain.fx(&"dirt_explosion", at + Vector3.UP * 0.4, 1.2)
	var flat := Vector3(at.x - foe.pos.x, 0, at.z - foe.pos.z)
	return maxf(flat.length() - POST.x, 4.0)


## Navette tirée vers lui : une ligne annoncée ; touché, le Chasseur est ramené de `pull` m vers le boss.
func _reel(pattern: BossPatternData) -> float:
	reels += 1
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var hunter: DraftHunter = brain.enemies.hunter
	var aim: Vector3 = hunter.global_position - foe.pos
	aim.y = 0.0
	aim = aim.normalized() if aim.length() > 0.01 else Vector3.RIGHT
	var length: float = float(params.get("length", 520.0)) * DraftHunter.UNIT
	var pull: float = float(params.get("pull", 3.5))
	brain.enemies.hazards.line(foe.pos, aim, length, float(params.get("width", 50.0)) * DraftHunter.UNIT,
		pattern.telegraph, brain.damage(pattern.damage), true, 0.0, 0.7, func() -> void:
			var toward: Vector3 = brain.foe.pos - hunter.global_position
			toward.y = 0.0
			if toward.length() > brain.foe.radius + 1.5:
				hunter.move_and_collide(toward.normalized() * minf(pull, toward.length() - brain.foe.radius - 1.2)))
	brain.play_clip([StringName(str(params.get("anim", "shuttle_reel"))), &"attack"], pattern.telegraph + 0.3)
	return pattern.telegraph + 0.4


func step(delta: float) -> void:
	_clock += delta
	for i: int in range(posts.size() - 1, -1, -1):
		if _clock >= float(posts[i]["until"]):
			brain.fx(&"dirt_explosion", (posts[i]["pos"] as Vector3) + Vector3.UP * 0.5, 1.0)
			(posts[i]["body"] as Node).queue_free()
			posts.remove_at(i)
	if threads.is_empty():
		return
	if _clock >= _end_at:
		_clear_threads()
		_end_at = -1.0
		return
	_place_threads()


## Fils entre le boss et leur accroche ; en tension, ils suivent le balayage.
func _place_threads() -> void:
	var progress: float = clampf((_clock - _tension_at) / maxf(_sweep, 0.01), 0.0, 1.0)
	var taut: bool = _clock >= _tension_at
	var origin: Vector3 = brain.foe.pos + Vector3.UP * 0.5
	for thread: Dictionary in threads:
		var node: MeshInstance3D = thread["node"]
		var angle: float = lerpf(float(thread["from"]), float(thread["to"]), progress)
		var end: Vector3 = origin + _aim.rotated(Vector3.UP, angle) * float(thread["length"])
		(node.mesh as BoxMesh).size = Vector3(THICKNESS, THICKNESS, origin.distance_to(end))
		(node.material_override as StandardMaterial3D).albedo_color = TAUT if taut else SLACK
		node.global_position = (origin + end) * 0.5
		node.look_at(end, Vector3.UP)


func _thread() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(THICKNESS, THICKNESS, 1.0)
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SLACK
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain.enemies.add_child(node)
	return node


func _clear_threads() -> void:
	for thread: Dictionary in threads:
		(thread["node"] as Node).queue_free()
	threads.clear()


func finish() -> void:
	_clear_threads()
	_end_at = -1.0
	for post: Dictionary in posts:
		(post["body"] as Node).queue_free()
	posts.clear()
