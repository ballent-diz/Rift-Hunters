class_name MasteryData
extends Resource
## Progression de maîtrise d'un Écho.

## XP cumulée nécessaire pour chaque niveau (index 0 = niveau 1).
@export var level_thresholds: Array[int] = [20, 60, 120, 200, 300]
@export var challenges: Array[MasteryChallengeData] = []
@export var rewards: Array[MasteryRewardData] = []
## XP par Technique utilisée et par déclenchement de synergie.
@export var xp_per_technique: float = 1.0
@export var xp_per_synergy_proc: float = 0.05
@export var max_xp_per_run_from_play: int = 40


func level_for_xp(xp: int) -> int:
	var level: int = 0
	for threshold: int in level_thresholds:
		if xp >= threshold:
			level += 1
	return level
