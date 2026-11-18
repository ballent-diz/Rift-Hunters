class_name DraftRootLeash
extends DraftBossMechanic
## Racine-laisse de l'Abyssarque (forme racines, docs/design/MONSTRES.md), demande du propriétaire du 17 novembre :
## une racine file vers le Chasseur et l'attache à un point du sol. Pendant quelques secondes, il ne peut pas
## s'éloigner de ce point au-delà de la longueur de la racine ; le boss prépare un coup sur ce point. Une Ruée tranche
## la racine : on s'en libère à tout moment (rien n'enferme le Chasseur, comme le veut la refonte du 11 novembre).
## Glauquemire garde sa racine jaillissante (DraftGlauquemire) ; cette mécanique ne sert qu'aux autres boss.

const ROOT := Color(0.42, 0.3, 0.18)
const THICKNESS := 0.16

## Laisse en cours : {"anchor", "length", "until"} (vide : aucune).
var leash: Dictionary = {}
var cut: int = 0
var _clock: float = 0.0
var _node: MeshInstance3D


func handles(kind: StringName) -> bool:
	return kind == &"root_leash"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var hunter: DraftHunter = brain.enemies.hunter
	var anchor: Vector3 = brain.enemies.level.closest(hunter.global_position)
	var foe: DraftEnemies.Foe = brain.foe
	var to_anchor: Vector3 = anchor - foe.pos
	to_anchor.y = 0.0
	# La racine file vers le Chasseur (ligne annoncée), puis l'attache.
	brain.enemies.hazards.line(foe.pos, to_anchor.normalized(), maxf(to_anchor.length(), 1.0), 0.6, pattern.telegraph, 0.0)
	var duration: float = float(params.get("duration", 3.0))
	leash = {"anchor": anchor, "length": clampf(float(params.get("length", 200.0)) * DraftHunter.UNIT, 3.0, 8.0),
		"from": _clock + pattern.telegraph, "until": _clock + pattern.telegraph + duration}
	var radius: float = clampf(float(params.get("slam_radius", 170.0)) * DraftHunter.UNIT, 2.5, 5.5)
	brain.enemies.hazards.circle(anchor, radius, pattern.telegraph + float(params.get("slam_delay", 2.4)),
		brain.damage(pattern.damage), brain.fx_at(&"earth_spike", radius))
	brain.play_clip([&"roots_attack", &"root_lash", &"roots", &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.4


func tied() -> bool:
	return not leash.is_empty() and _clock >= float(leash["from"])


func step(delta: float) -> void:
	_clock += delta
	if leash.is_empty():
		return
	if _clock >= float(leash["until"]):
		_release()
		return
	if not tied():
		return
	var hunter: DraftHunter = brain.enemies.hunter
	var anchor: Vector3 = leash["anchor"]
	if hunter.is_dashing():
		# Une Ruée tranche la racine.
		cut += 1
		brain.fx(&"spin_slash", hunter.chest(), 0.9)
		_release()
		return
	var offset: Vector3 = hunter.global_position - anchor
	offset.y = 0.0
	var length: float = leash["length"]
	if offset.length() > length:
		# Au bout de la racine : le Chasseur est ramené à sa longueur.
		var back: Vector3 = anchor + offset.normalized() * length
		hunter.move_and_collide(Vector3(back.x - hunter.global_position.x, 0.0, back.z - hunter.global_position.z))
	_draw(anchor, hunter.chest())


func _draw(anchor: Vector3, to: Vector3) -> void:
	if _node == null:
		_node = MeshInstance3D.new()
		_node.mesh = BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = ROOT
		_node.material_override = material
		_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		brain.enemies.add_child(_node)
	var from: Vector3 = anchor + Vector3.UP * 0.2
	var span: float = maxf(from.distance_to(to), 0.1)
	(_node.mesh as BoxMesh).size = Vector3(THICKNESS, THICKNESS, span)
	_node.global_position = (from + to) * 0.5
	if span > 0.1:
		_node.look_at(to, Vector3.UP)


func _release() -> void:
	leash = {}
	if _node != null:
		_node.queue_free()
		_node = null


func finish() -> void:
	_release()
