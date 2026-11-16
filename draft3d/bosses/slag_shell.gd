class_name DraftSlagShell
extends DraftBossMechanic
## Carapace à fendre, mécanique phare de la Matrone des scories (chapitre 2, docs/design/MONSTRES.md), reprise de
## `AshGuardians` pour le monde 3D : dès son arrivée, sa carapace arrête presque tous les coups. Sa pluie de scories
## fait tomber des roches autour du Chasseur ; une roche qui tombe sur elle fend la carapace (coups × 1,5, sonnée 1 s)
## pendant 10 s. Il faut l'attirer sous les ombres des roches.

var shell_mult: float = 0.15
var cracked_mult: float = 1.5
var crack_time: float = 10.0
var crack_stun: float = 1.0
var cracks: int = 0
var _cracked_left: float = 0.0


func setup(p_brain: DraftBossBrain) -> void:
	super.setup(p_brain)
	var params: Dictionary = brain.data.signature_params
	shell_mult = float(params.get("shell_mult", shell_mult))
	cracked_mult = float(params.get("cracked_mult", cracked_mult))
	crack_time = float(params.get("crack_time", crack_time))
	crack_stun = float(params.get("stun", crack_stun))


func handles(kind: StringName) -> bool:
	return kind == &"slag_rain"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var rng: RandomNumberGenerator = brain.enemies.rng
	var radius: float = clampf(float(params.get("radius", 95.0)) * DraftHunter.UNIT, 2.0, 3.5)
	var count: int = int(params.get("count", 3)) + mini(brain.phase, 1)
	var center: Vector3 = brain.enemies.hunter.global_position
	for n: int in count:
		var offset := Vector3.ZERO if n == 0 else Vector3(rng.randf_range(-5.0, 5.0), 0, rng.randf_range(-5.0, 5.0))
		var at: Vector3 = brain.enemies.level.closest(center + offset)
		brain.enemies.hazards.circle(at, radius, pattern.telegraph + 0.15 * n, brain.damage(pattern.damage),
			func(spot: Vector3) -> void: _rock_lands(spot, radius))
	brain.play_clip([StringName(str(params.get("anim", "slag_molt"))), &"attack"], 0.8)
	intro("BOSS_SHELL_INTRO")
	return 0.8


func cracked() -> bool:
	return _cracked_left > 0.0


func damage_mult() -> float:
	return cracked_mult if cracked() else shell_mult


func step(delta: float) -> void:
	if _cracked_left > 0.0:
		_cracked_left -= delta
		if _cracked_left <= 0.0:
			brain.foe.view.set_tint(Color.WHITE)


## Une roche touche le sol : si la Matrone est dessous, la carapace se fend.
func _rock_lands(spot: Vector3, radius: float) -> void:
	brain.fx(&"boulder", spot + Vector3.UP * 0.6, radius * 0.7)
	var foe: DraftEnemies.Foe = brain.foe
	var offset: Vector3 = foe.pos - spot
	if foe.alive and Vector2(offset.x, offset.z).length() <= radius + foe.radius * 0.5 and absf(offset.y) < 1.2:
		crack()


func crack() -> void:
	cracks += 1
	_cracked_left = crack_time
	brain.stun(crack_stun)
	brain.enemies.run.call("boss_banner", "BOSS_SHELL_CRACKED")
