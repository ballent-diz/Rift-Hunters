extends Node2D
## Plafond local partagé par l'équipe. Refuse le décor excédentaire, jamais une action de jeu.
@export_range(1, 32) var max_effects: int = 24


func _ready() -> void:
	child_exiting_tree.connect(func(_child: Node) -> void: _refresh_budget.call_deferred())


func emit_effect(scene: PackedScene, origin: Vector2, direction: Vector2, parameters: Dictionary = {}) -> Node2D:
	if get_child_count() >= clampi(max_effects, 1, 32):
		return null
	var effect: Node2D = scene.instantiate()
	for key: String in parameters:
		if key in ["radius", "visual_duration", "travel_distance", "color", "accent",
				"particle_budget", "target_shape", "loop_visual"]:
			effect.set(key, parameters[key])
	add_child(effect)
	effect.set_meta("desired_particle_budget", effect.get("particle_budget"))
	_refresh_budget()
	effect.global_position = origin
	effect.call("play", direction)
	return effect


func _refresh_budget() -> void:
	var count: int = get_child_count()
	var budget: int = 18 if count <= 6 else (8 if count <= 12 else 4)
	for effect: Node in get_children():
		effect.set("particle_budget", mini(int(effect.get_meta("desired_particle_budget", 18)), budget))
		effect.set("detail_level", 1 if count <= 6 else 0)
