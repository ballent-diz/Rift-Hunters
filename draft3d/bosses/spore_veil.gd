class_name DraftSporeVeil
extends DraftBossMechanic
## Voile de spores, mécanique phare de la Mère des spores (chapitre 3, docs/design/MONSTRES.md), reprise de
## `SporeGuardian` pour le monde 3D. Le voile se lève dès son arrivée : les coups ne portent presque pas. Les
## cristaux-miroirs de la carte 13 n'existent pas en 3D : elle en fait pousser trois autour d'elle. Une Ruée dans un
## cristal en tire un rayon aimanté vers elle ; s'il l'atteint (aucun décor entre les deux), le voile brûle : sonnée,
## coups × 2, puis il repousse. Son tapis de spores fait éclater des bouffées autour du Chasseur.

const CRYSTAL := Color(0.55, 0.95, 1.0)
const SPORES := Color(0.6, 0.85, 0.35)
const CRYSTAL_SIZE := Vector3(1.2, 2.2, 1.2)
const CRYSTAL_DISTANCE := 9.0
const DASH_REACH := 1.6

var veil_mult: float = 0.2
var regrow: float = 12.0
var stun_time: float = 5.0
var burns: int = 0
var crystals: Array[Dictionary] = []
var _down_until: float = 0.0
var _clock: float = 0.0
var _crystal_ready_at: float = 0.0
var _cloud: MeshInstance3D


func setup(p_brain: DraftBossBrain) -> void:
	super.setup(p_brain)
	var params: Dictionary = brain.data.signature_params
	veil_mult = float(params.get("veil_mult", veil_mult))
	regrow = float(params.get("regrow", regrow))
	_cloud = make_orb(Color(SPORES, 1.0), brain.foe.radius + 0.6)
	((_cloud.material_override) as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	((_cloud.material_override) as StandardMaterial3D).albedo_color = Color(SPORES, 0.25)
	for k: int in 3:
		var angle: float = TAU * k / 3.0 + brain.enemies.rng.randf()
		var at: Vector3 = brain.enemies.level.closest(brain.foe.pos + Vector3(cos(angle), 0, sin(angle)) * CRYSTAL_DISTANCE)
		crystals.append({"pos": at, "body": make_block(at, CRYSTAL_SIZE, CRYSTAL)})


func handles(kind: StringName) -> bool:
	return kind == &"spore_veil"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var rng: RandomNumberGenerator = brain.enemies.rng
	var radius: float = float(params.get("radius", 90.0)) * DraftHunter.UNIT
	var spread: float = float(params.get("spread", 170.0)) * DraftHunter.UNIT
	var center: Vector3 = brain.enemies.hunter.global_position
	for n: int in int(params.get("count", 3)):
		var offset := Vector3.ZERO if n == 0 else Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		brain.enemies.hazards.circle(brain.enemies.level.closest(center + offset), radius, pattern.telegraph + 0.15 * n,
			brain.damage(pattern.damage), brain.fx_at(&"spore_burst", radius))
	brain.play_clip([StringName(str(params.get("anim", "spore_carpet"))), &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.3


func veiled() -> bool:
	return _clock >= _down_until


func damage_mult() -> float:
	if veiled():
		return veil_mult
	return 2.0 / DraftBossBrain.STUN_DAMAGE_MULT if brain.stunned() else 1.0


func step(delta: float) -> void:
	_clock += delta
	var foe: DraftEnemies.Foe = brain.foe
	_cloud.visible = veiled()
	_cloud.global_position = foe.pos + Vector3.UP * 1.0
	var hunter: DraftHunter = brain.enemies.hunter
	if not hunter.is_dashing() or _clock < _crystal_ready_at:
		return
	for crystal: Dictionary in crystals:
		if hunter.global_position.distance_to(crystal["pos"]) < DASH_REACH + CRYSTAL_SIZE.x * 0.5:
			_crystal_ready_at = _clock + 1.0
			_fire(crystal)
			return


## Rayon du cristal, aimanté vers la Mère : il brûle le voile s'il l'atteint.
func _fire(crystal: Dictionary) -> void:
	var foe: DraftEnemies.Foe = brain.foe
	var from: Vector3 = (crystal["pos"] as Vector3) + Vector3.UP * 1.0
	var to: Vector3 = foe.pos + Vector3.UP * 1.0
	brain.fx(&"arcane_beam", from.lerp(to, 0.5), 2.0)
	var space: PhysicsDirectSpaceState3D = brain.enemies.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [(crystal["body"] as StaticBody3D).get_rid()])
	if not space.intersect_ray(query).is_empty() or not veiled():
		return
	burns += 1
	_down_until = _clock + regrow
	brain.stun(stun_time)


func finish() -> void:
	for crystal: Dictionary in crystals:
		(crystal["body"] as Node).queue_free()
	crystals.clear()
	if _cloud != null:
		_cloud.queue_free()
		_cloud = null
