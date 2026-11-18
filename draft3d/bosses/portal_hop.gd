class_name DraftPortalHop
extends DraftBossMechanic
## Saut de portail, mécanique phare de la Dame des portails (chapitre 3, docs/design/MONSTRES.md), reprise de
## `PortalGuardian` pour le monde 3D. Les miroirs-portails de la carte 14 n'existent pas en 3D : elle en ouvre trois
## autour d'elle à son arrivée. Elle plonge dans un miroir et ressort par le portail le plus proche du Chasseur (jamais
## le sien), qui s'illumine. Le Chasseur qui se tient dans ce portail quand elle ressort la piège : elle sort sonnée et
## vulnérable. Sinon, elle surgit dans une onde de prisme.

const PORTAL := Color(0.75, 0.55, 1.0)
const PORTAL_RADIUS := 1.8
const PORTAL_DISTANCE := 10.0

var portals: Array[Dictionary] = []
var hop: Dictionary = {}
var trapped: int = 0
var trap_stun: float = 5.0
var _clock: float = 0.0
var _exposed_left: float = 0.0


func setup(p_brain: DraftBossBrain) -> void:
	super.setup(p_brain)
	trap_stun = float(brain.data.signature_params.get("trap_stun", trap_stun))
	for k: int in 3:
		var angle: float = TAU * k / 3.0 + brain.enemies.rng.randf()
		var at: Vector3 = brain.enemies.level.closest(brain.foe.pos + Vector3(cos(angle), 0, sin(angle)) * PORTAL_DISTANCE)
		portals.append({"pos": at, "disc": make_disc(at, PORTAL_RADIUS, Color(PORTAL, 0.25))})


func handles(kind: StringName) -> bool:
	return kind == &"portal_hop"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var hunter: Vector3 = brain.enemies.hunter.global_position
	var mine: int = _nearest(foe.pos, -1)
	var exit: int = _nearest(hunter, mine)
	hop = {"exit": exit, "from": _clock + pattern.telegraph, "at": _clock + pattern.telegraph + float(params.get("dive", 2.4)),
		"radius": float(params.get("radius", 210.0)) * DraftHunter.UNIT, "damage": brain.damage(pattern.damage), "warned": false}
	_light(exit, 0.8)
	brain.fx(&"blink_out", foe.pos + Vector3.UP * 0.8, 1.6)
	brain.play_clip([StringName(str(params.get("anim", "blink"))), &"attack"], pattern.telegraph)
	return pattern.telegraph


func _nearest(at: Vector3, skip: int) -> int:
	var best: int = -1
	for k: int in portals.size():
		if k != skip and (best < 0 or at.distance_to(portals[k]["pos"]) < at.distance_to(portals[best]["pos"])):
			best = k
	return best


func _light(index: int, alpha: float) -> void:
	var disc: MeshInstance3D = portals[index]["disc"]
	(disc.material_override as StandardMaterial3D).albedo_color = Color(PORTAL, alpha)


func diving() -> bool:
	return not hop.is_empty() and _clock >= float(hop["from"])


func hides_boss() -> bool:
	return diving()


func holds_boss() -> bool:
	return not hop.is_empty()


func damage_mult() -> float:
	if diving():
		return 0.2
	return 2.0 / DraftBossBrain.STUN_DAMAGE_MULT if _exposed_left > 0.0 else 1.0


func step(delta: float) -> void:
	_clock += delta
	_exposed_left = maxf(_exposed_left - delta, 0.0)
	if not diving():
		return
	var foe: DraftEnemies.Foe = brain.foe
	foe.view.visible = false
	var exit: Vector3 = portals[int(hop["exit"])]["pos"]
	var hunter: DraftHunter = brain.enemies.hunter
	if _clock < float(hop["at"]):
		return
	_light(int(hop["exit"]), 0.25)
	foe.pos = exit
	foe.view.snap_to(exit)
	foe.view.visible = true
	brain.fx(&"blink_in", exit + Vector3.UP * 0.8, 1.6)
	if hunter.global_position.distance_to(exit) < PORTAL_RADIUS + DraftHunter.RADIUS:
		# Piégée : le Chasseur tient le portail de sortie.
		trapped += 1
		_exposed_left = trap_stun + 1.0
		brain.stun(trap_stun)
	else:
		brain.enemies.hazards.ring(exit, 9.0, float(hop["radius"]) + 4.0, 0.15, float(hop["damage"]),
			brain.fx_at(&"ring_burst", 2.0))
	hop = {}


func finish() -> void:
	for portal: Dictionary in portals:
		(portal["disc"] as Node).queue_free()
	portals.clear()
	if not hop.is_empty():
		brain.foe.view.visible = true
	hop = {}
