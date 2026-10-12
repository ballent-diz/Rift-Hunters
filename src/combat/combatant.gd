class_name Combatant
extends Node2D
## Base commune du Chasseur, des ennemis et des boss : PV, défense, statuts.

var max_hp: float = 10.0
var hp: float = 10.0
var base_defense: float = 0.0
var radius: float = 12.0
var alive: bool = true
var statuses := StatusContainer.new()
## Multiplicateur de dégâts subis propre à l'entité (ex. cœur exposé du boss).
var extra_damage_taken: float = 1.0
var visual: EntityVisual


func is_alive() -> bool:
	return alive


func get_defense() -> float:
	return base_defense + statuses.defense_add()


func get_damage_taken_mult() -> float:
	return statuses.damage_taken_mult() * extra_damage_taken


func is_invulnerable() -> bool:
	return false


## Applique des dégâts déjà calculés. Retourne true si la cible meurt.
func apply_damage(amount: float) -> bool:
	hp -= amount
	if visual:
		visual.flash()
	if hp <= 0.0 and alive:
		hp = 0.0
		alive = false
		return true
	return false
