class_name PlayerBrain
extends RefCounted
## Source des commandes du Chasseur (humain ou bot de test).

var ctx: RunContext


func move_vector() -> Vector2:
	return Vector2.ZERO


func wants_dash() -> bool:
	return false


func technique_pressed(_index: int) -> bool:
	return false


## Sorts du Chasseur (emplacement 0 à 3) : touche enfoncée à cette image, maintenue, relâchée.
func spell_pressed(_slot: int) -> bool:
	return false


func spell_held(_slot: int) -> bool:
	return false


func spell_released(_slot: int) -> bool:
	return false


## Peut maintenir une touche (Surcharge) : le bot de test lance sans charger.
func can_hold() -> bool:
	return false


## Option « aperçu » : maintenir montre la zone, relâcher lance (sinon la touche lance immédiatement).
func preview_casting() -> bool:
	return false


func focus_requested() -> bool:
	return false


## Point visé dans le monde (curseur) pour les techniques et l'ordre de focus.
func aim_point() -> Vector2:
	return ctx.player.global_position
