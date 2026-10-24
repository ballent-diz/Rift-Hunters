class_name HumanBrain
extends PlayerBrain
## Commandes au clavier (ou à la manette). La souris ne sert plus à viser.

const TECHNIQUE_ACTIONS: Array[StringName] = [&"technique_1", &"technique_2", &"technique_3"]
const SPELL_ACTIONS: Array[StringName] = [&"spell_1", &"spell_2", &"spell_3", &"spell_4"]
const AIM_DISTANCE := 260.0
const AIM_RANGE := 520.0
## Cosinus du demi-angle du cône de visée (environ 37°).
const AIM_CONE := 0.8


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


## Les deux mains au clavier (décision du 24 octobre 2026) : sorts et Techniques partent dans la direction du
## Chasseur, vers l'ennemi le plus proche dans le cône devant lui, sinon à AIM_DISTANCE devant.
func aim_point() -> Vector2:
	var origin: Vector2 = ctx.player.global_position
	if Settings.using_gamepad:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.3:
			return origin + stick.normalized() * AIM_DISTANCE
	return facing_aim(ctx, origin)


static func facing_aim(p_ctx: RunContext, origin: Vector2) -> Vector2:
	var facing: Vector2 = p_ctx.player.facing
	var best: Enemy = null
	var best_distance: float = AIM_RANGE
	for enemy: Enemy in p_ctx.enemies.query_radius(origin, AIM_RANGE):
		var offset: Vector2 = enemy.global_position - origin
		var distance: float = offset.length()
		if distance < best_distance and distance > 1.0 and offset.dot(facing) / distance >= AIM_CONE \
				and p_ctx.obstacles.line_clear(origin, enemy.global_position):
			best = enemy
			best_distance = distance
	return best.global_position if best else origin + facing * AIM_DISTANCE
