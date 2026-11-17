class_name DraftSourceDevourer
extends DraftBossMechanic
## Style de combat du Dévoreur des Sources (chapitre 1), amélioration du 17 novembre 2026 (premier boss final vu par
## tout joueur, retour « boss pas assez dynamiques ») :
## - enchaînement propre : griffes ou balayage → souffle → orbes de source (le joueur apprend à lire la suite) ;
## - souffle qui balaie : la gueule tourne d'un côté à l'autre, le décor l'arrête toujours ;
## - seconde phase : chaque écrasement est suivi d'une charge vers le Chasseur (les orbes passent en double salve,
##   DraftSourceOrbs).

## Balayage du souffle : arc (degrés), traits et durée.
const BREATH_ARC := 100.0
const BREATH_STEPS := 7
const BREATH_SWEEP := 1.0
const BREATH_LENGTH := 13.0
## Délai entre l'écrasement et la charge qui le suit (seconde phase).
const CHARGE_DELAY := 1.1

var breaths: int = 0
var charges: int = 0
var _clock: float = 0.0
var _charge_at: float = -1.0
var _charge_damage: float = 0.0


func handles(kind: StringName) -> bool:
	return kind == &"breath"


func next_kind(last: StringName) -> StringName:
	match last:
		&"claw", &"sweep":
			return &"breath"
		&"breath":
			return &"source_orb"
	return &""


func perform(pattern: BossPatternData) -> float:
	breaths += 1
	var foe: DraftEnemies.Foe = brain.foe
	var to_hunter: Vector3 = brain.enemies.hunter.global_position - foe.pos
	to_hunter.y = 0.0
	var aim: Vector3 = to_hunter.normalized() if to_hunter.length() > 0.01 else Vector3.RIGHT
	var side: float = 1.0 if brain.enemies.rng.randf() < 0.5 else -1.0
	var arc: float = deg_to_rad(BREATH_ARC + 20.0 * brain.phase)
	for i: int in BREATH_STEPS:
		var direction: Vector3 = aim.rotated(Vector3.UP, side * (-arc * 0.5 + arc * i / (BREATH_STEPS - 1)))
		# Le décor arrête le souffle : on s'abrite derrière un rocher, un mur ou une colonne.
		brain.enemies.hazards.line(foe.pos, direction, BREATH_LENGTH, 2.2,
			pattern.telegraph + BREATH_SWEEP * i / (BREATH_STEPS - 1), brain.damage(pattern.damage), true)
	var names: Array = []
	if pattern.params.has("vfx"):
		names.append(str(pattern.params["vfx"]))
	names.append("rift_breath")
	if not brain.painted(names, foe.pos, aim, DraftBossBrain.CONTACT_STRIKE):
		brain.fx(&"fire_breath", foe.pos + aim * (foe.radius + 2.0) + Vector3.UP, 2.0)
	brain.play_clip([StringName(str(pattern.params.get("anim", "rift_breath"))), &"rift_breath", &"attack"],
		pattern.telegraph + BREATH_SWEEP)
	return pattern.telegraph + BREATH_SWEEP + 0.3


func after(kind: StringName) -> void:
	if kind == &"slam" and brain.phase >= 1:
		_charge_at = _clock + CHARGE_DELAY
		_charge_damage = brain.data.damage


func step(delta: float) -> void:
	_clock += delta
	if _charge_at < 0.0 or _clock < _charge_at:
		return
	_charge_at = -1.0
	if brain.stunned() or brain.moves_itself() or not brain.foe.alive:
		return
	var aim: Vector3 = brain.enemies.hunter.global_position - brain.foe.pos
	aim.y = 0.0
	if aim.length() < 2.0:
		return
	charges += 1
	var charge := BossPatternData.new()
	charge.kind = &"charge"
	charge.telegraph = 0.55
	charge.damage = _charge_damage
	brain.charge(charge, aim.normalized())


func finish() -> void:
	_charge_at = -1.0
