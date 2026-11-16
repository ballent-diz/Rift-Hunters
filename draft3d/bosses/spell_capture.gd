class_name DraftSpellCapture
extends DraftBossMechanic
## Écho des sorts, mécanique phare de Nivorath (chapitre 4, docs/design/MONSTRES.md), reprise de
## `NivorathMechanics` pour le monde 3D : il ouvre sa gueule de cristal. Chaque sort que le Chasseur lance pendant ce
## temps est aspiré puis renvoyé, amplifié, en couronnes de tirs. Si aucun sort n'a été lancé, il s'étouffe : sonné et
## vulnérable. Gueule ouverte, tous les coups ne portent qu'à moitié (le Chasseur 3D ne distingue pas encore les coups
## de sort des traits).

const RIFT := Color(0.6, 0.5, 1.0)
const OPEN_MULT := 0.5

var capture: Dictionary = {}
var choked: int = 0
var released: int = 0
var _clock: float = 0.0
var _exposed_left: float = 0.0
var _glow: MeshInstance3D


func handles(kind: StringName) -> bool:
	return kind == &"spell_capture"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var duration: float = float(params.get("duration", 3.5))
	capture = {"opens": _clock + pattern.telegraph, "until": _clock + pattern.telegraph + duration,
		"casts": _casts(), "damage": brain.damage(pattern.damage), "per": int(params.get("per_spell", 12)),
		"stun": float(params.get("stun", 3.0))}
	_glow = make_orb(Color(RIFT, 1.0), brain.foe.radius * 0.6)
	brain.fx(&"ring_charge", brain.foe.pos + Vector3.UP * 0.4, brain.foe.radius * 2.0)
	brain.play_clip([StringName(str(params.get("anim", "spell_capture"))), &"attack"], pattern.telegraph + duration)
	intro("BOSS_CAPTURE_INTRO")
	return pattern.telegraph + duration + 0.6


## Sorts lancés par le Chasseur depuis le début de la partie.
func _casts() -> int:
	var spells: Object = brain.enemies.run.get("spells")
	return int(spells.get("casts")) if spells != null else 0


func capturing() -> bool:
	return not capture.is_empty() and _clock >= float(capture["opens"])


## Sorts aspirés depuis l'ouverture de la gueule.
func swallowed() -> int:
	return _casts() - int(capture["casts"]) if not capture.is_empty() else 0


func damage_mult() -> float:
	if capturing():
		return OPEN_MULT
	return 2.0 / DraftBossBrain.STUN_DAMAGE_MULT if _exposed_left > 0.0 else 1.0


func step(delta: float) -> void:
	_clock += delta
	_exposed_left = maxf(_exposed_left - delta, 0.0)
	if capture.is_empty():
		return
	if _glow != null:
		_glow.global_position = brain.foe.pos + Vector3.UP * 1.2
		var size: float = 1.0 + 0.25 * swallowed()
		_glow.scale = Vector3.ONE * size
	if _clock >= float(capture["until"]):
		_release()


func _release() -> void:
	var count: int = swallowed()
	var damage: float = capture["damage"]
	var per: int = capture["per"]
	var stun: float = capture["stun"]
	capture = {}
	if _glow != null:
		_glow.queue_free()
		_glow = null
	var foe: DraftEnemies.Foe = brain.foe
	if not foe.alive:
		return
	if count == 0:
		# Rien à renvoyer : il s'étouffe, sonné et vulnérable.
		choked += 1
		_exposed_left = stun + 1.0
		brain.stun(stun)
		brain.fx(&"ice_shatter", foe.pos + Vector3.UP, foe.radius * 1.6)
		return
	released += count
	brain.play_clip([&"spell_release", &"attack"], 0.8)
	var family: StringName = brain.family()
	for wave: int in mini(count, 3):
		var offset: float = brain.enemies.rng.randf() * TAU + wave * 0.3
		for i: int in per:
			var direction := Vector3.RIGHT.rotated(Vector3.UP, offset + TAU * i / per)
			brain.enemies.run.call("hostile_shot", foe.pos + Vector3.UP * 0.8 + direction * foe.radius, direction,
				9.0 - wave * 1.5, damage * (1.0 + 0.25 * (count - 1)), family, 4.0)
	brain.fx(&"ring_burst", foe.pos + Vector3.UP * 0.5, foe.radius * 2.0)


func finish() -> void:
	capture = {}
	if _glow != null:
		_glow.queue_free()
		_glow = null
