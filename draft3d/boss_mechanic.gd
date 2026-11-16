class_name DraftBossMechanic
extends RefCounted
## Mécanique phare d'un boss de la base 3D (docs/design/BOSS_V2.md) : état qui dure au-delà d'une attaque, greffé
## sur `DraftBossBrain`. Une mécanique peut prendre en charge certaines techniques des données (`handles`) ; les
## autres restent jouées par le cerveau commun. Elle est retirée à la mort du boss (`finish`).

var brain: DraftBossBrain


func setup(p_brain: DraftBossBrain) -> void:
	brain = p_brain


## Vrai si la mécanique joue elle-même cette technique des données.
func handles(_kind: StringName) -> bool:
	return false


## Joue la technique ; renvoie la durée pendant laquelle le boss reste occupé.
func perform(_pattern: BossPatternData) -> float:
	return 0.0


func step(_delta: float) -> void:
	pass


func on_phase(_index: int) -> void:
	pass


## Multiplicateur des coups reçus par le boss (carapace, voile, cœur exposé...).
func damage_mult() -> float:
	return 1.0


## Vrai tant que la mécanique retient le boss (ni déplacement ni attaque du cerveau commun).
func holds_boss() -> bool:
	return false


## Explication de la mécanique, une fois par partie (bandeau).
func intro(key: String) -> void:
	brain.banner_once(key)


func finish() -> void:
	pass
