class_name HumanBrain
extends PlayerBrain
## Commandes clavier + souris.

const TECHNIQUE_ACTIONS: Array[StringName] = [&"technique_1", &"technique_2", &"technique_3"]
const SPELL_ACTIONS: Array[StringName] = [&"spell_1", &"spell_2", &"spell_3", &"spell_4"]


func move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func wants_dash() -> bool:
	return Input.is_action_just_pressed(&"dash")


func technique_pressed(index: int) -> bool:
	return index < TECHNIQUE_ACTIONS.size() and Input.is_action_just_pressed(TECHNIQUE_ACTIONS[index])


func technique_held(index: int) -> bool:
	return index < TECHNIQUE_ACTIONS.size() and Input.is_action_pressed(TECHNIQUE_ACTIONS[index])


func technique_released(index: int) -> bool:
	return index < TECHNIQUE_ACTIONS.size() and Input.is_action_just_released(TECHNIQUE_ACTIONS[index])


func spell_pressed(slot: int) -> bool:
	return slot < SPELL_ACTIONS.size() and Input.is_action_just_pressed(SPELL_ACTIONS[slot])


func spell_held(slot: int) -> bool:
	return slot < SPELL_ACTIONS.size() and Input.is_action_pressed(SPELL_ACTIONS[slot])


func spell_released(slot: int) -> bool:
	return slot < SPELL_ACTIONS.size() and Input.is_action_just_released(SPELL_ACTIONS[slot])


func can_hold() -> bool:
	return true


func preview_casting() -> bool:
	return Settings.spell_preview


func focus_requested() -> bool:
	return Input.is_action_just_pressed(&"focus_order")


func aim_point() -> Vector2:
	if not Settings.using_gamepad:
		return ctx.player.get_global_mouse_position()
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var origin: Vector2 = ctx.player.global_position
	if stick.length() > 0.3:
		return origin + stick.normalized() * 260.0
	var target: Enemy = ctx.enemies.find_nearest(origin, 450.0)
	return target.global_position if target else origin + ctx.player.facing * 200.0
