class_name HumanBrain
extends PlayerBrain
## Commandes clavier + souris.

const TECHNIQUE_ACTIONS: Array[StringName] = [&"technique_1", &"technique_2", &"technique_3"]


func move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func wants_dash() -> bool:
	return Input.is_action_just_pressed(&"dash")


func technique_pressed(index: int) -> bool:
	return index < TECHNIQUE_ACTIONS.size() and Input.is_action_just_pressed(TECHNIQUE_ACTIONS[index])


func focus_requested() -> bool:
	return Input.is_action_just_pressed(&"focus_order")


func aim_point() -> Vector2:
	return ctx.player.get_global_mouse_position()
