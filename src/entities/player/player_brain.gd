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


func focus_requested() -> bool:
	return false


## Point visé dans le monde (curseur) pour les techniques et l'ordre de focus.
func aim_point() -> Vector2:
	return ctx.player.global_position
