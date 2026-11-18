class_name DraftPyrevornStyle
extends DraftBossMechanic
## Style de combat de Pyrevorn (chapitre 2), amélioration du 18 novembre 2026 :
## - enchaînement propre : balayage → séquence des cratères → envol et chute (pluie de roches en première phase) →
##   Œil de la Faille ; tant que son escorte est en vie, il revient plus souvent à l'Œil (il couvre ses gardiens) ;
## - Œil de la Faille qui balaie aller-retour en seconde phase (arrêté par le décor) ;
## - flaques de lave laissées par chaque éruption (DraftCraterSequence).

## Durée du retour de l'Œil après le premier balayage (s).
const RETURN_GAP := 0.35

var craters: DraftCraterSequence
var double_sweeps: int = 0


func _init(p_craters: DraftCraterSequence = null) -> void:
	craters = p_craters


func handles(kind: StringName) -> bool:
	return kind == &"eye_beam"


func next_kind(last: StringName) -> StringName:
	match last:
		&"sweep":
			return &"crater_sequence"
		&"crater_sequence":
			return &"skyfall" if brain.phase >= 1 else &"rock_rain"
		&"skyfall":
			return &"eye_beam"
	if escorts_alive() > 0 and last != &"eye_beam":
		return &"eye_beam"
	return &""


func escorts_alive() -> int:
	var alive: int = 0
	if craters != null:
		for escort: DraftEnemies.Foe in craters.escorts:
			alive += 1 if escort.alive else 0
	return alive


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var to_hunter: Vector3 = brain.enemies.hunter.global_position - foe.pos
	to_hunter.y = 0.0
	var aim: Vector3 = to_hunter.normalized() if to_hunter.length() > 0.01 else Vector3.RIGHT
	var side: float = 1.0 if brain.enemies.rng.randf() < 0.5 else -1.0
	var sweep: float = float(params.get("sweep_time", 2.2))
	_sweep(pattern, aim, side, pattern.telegraph)
	var total: float = pattern.telegraph + sweep
	if brain.phase >= 1:
		# Seconde phase : l'Œil revient sur ses pas, il faut relire le sens du balayage.
		_sweep(pattern, aim, -side, total + RETURN_GAP)
		total += RETURN_GAP + sweep
		double_sweeps += 1
	brain.play_clip([&"rift_eye", &"ray_sweep", &"phase2_attack", &"attack"], total)
	return total + 0.3


func _sweep(pattern: BossPatternData, aim: Vector3, side: float, start: float) -> void:
	var params: Dictionary = pattern.params
	var arc: float = deg_to_rad(float(params.get("arc", 130.0)))
	var steps: int = clampi(int(params.get("steps", 12)), 3, 14)
	var sweep: float = float(params.get("sweep_time", 2.2))
	var length: float = clampf(float(params.get("length", 950.0)) * DraftHunter.UNIT, 14.0, 28.0)
	for i: int in steps:
		var direction: Vector3 = aim.rotated(Vector3.UP, side * (-arc * 0.5 + arc * i / (steps - 1)))
		brain.enemies.hazards.line(brain.foe.pos, direction, length, 1.8, start + sweep * i / (steps - 1),
			brain.damage(pattern.damage * 0.8), true)
