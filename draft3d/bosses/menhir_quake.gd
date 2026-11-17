class_name DraftMenhirQuake
extends DraftBossMechanic
## Séisme et menhirs de la Sentinelle des racines (chapitre 1), amélioration du 17 novembre 2026 : avant chaque
## séisme, des menhirs solides sortent du sol autour du Chasseur (élite `menhir_warden` en version boss). Les anneaux
## sans brèche sont coupés par le décor : un menhir abrite qui se tient derrière lui, une Ruée les traverse toujours.
## Les menhirs retombent quelques secondes plus tard.

const STONE := Color(0.5, 0.5, 0.46)
const SIZE := Vector3(1.3, 2.6, 1.3)
const COUNT := 3
## Distance des menhirs au Chasseur (m) et durée sur le terrain (s).
const DISTANCE := 3.2
const LIFETIME := 6.0

## Menhirs dressés : {"body", "pos", "until"}.
var menhirs: Array[Dictionary] = []
var raised: int = 0
var _clock: float = 0.0


func handles(kind: StringName) -> bool:
	return kind == &"quake"


func perform(pattern: BossPatternData) -> float:
	var foe: DraftEnemies.Foe = brain.foe
	var hunter: Vector3 = brain.enemies.hunter.global_position
	var away: Vector3 = hunter - foe.pos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	# Un menhir entre le boss et le Chasseur, deux sur les côtés : il faut s'y placer avant les anneaux.
	for k: int in COUNT:
		var angle: float = PI + (k - (COUNT - 1) * 0.5) * 1.1
		var at: Vector3 = brain.enemies.level.closest(hunter + away.rotated(Vector3.UP, angle) * DISTANCE)
		if at.distance_to(hunter) < 1.0:
			continue
		menhirs.append({"body": make_block(at, SIZE, STONE), "pos": at, "until": _clock + LIFETIME})
		raised += 1
		brain.fx(&"earth_spike", at + Vector3.UP * 0.6, 1.2)
	return float(brain.call("_gesture_quake", pattern, away)) + 0.2


func step(delta: float) -> void:
	_clock += delta
	for i: int in range(menhirs.size() - 1, -1, -1):
		if _clock >= float(menhirs[i]["until"]):
			brain.fx(&"dirt_explosion", (menhirs[i]["pos"] as Vector3) + Vector3.UP, 1.2)
			(menhirs[i]["body"] as Node).queue_free()
			menhirs.remove_at(i)


func finish() -> void:
	for menhir: Dictionary in menhirs:
		(menhir["body"] as Node).queue_free()
	menhirs.clear()
