extends Node
## Contrôle du contrat visuel, sans données ni résultat de combat.
const Layer = preload("res://assets/vfx/echoes/effect_layer.gd")


func _ready() -> void:
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/echoes/effects_catalog.json"))
	for item: Dictionary in items:
		var scene: PackedScene = load(item.scene)
		assert(scene != null, item.scene)
		var effect: Node2D = scene.instantiate()
		add_child(effect)
		assert(effect.get_child_count() == 0, "Un émetteur = un nœud ; aucun nœud par particule.")
		effect.set("destroy_on_finish", false)
		effect.call("play", Vector2.ZERO)
		assert(is_zero_approx(effect.rotation))
		for fraction: float in [0.0, 0.1, 0.4, 0.8, 1.0]:
			effect.call("seek_visual", float(item.duration) * fraction)
			assert(not effect.get("_playing"))
		effect.call("release")
		effect.call("_process", 1.0)
		assert(not effect.get("_playing"))
		effect.free()
	var layer := Layer.new()
	layer.max_effects = 3
	add_child(layer)
	var sample: PackedScene = load(items[0].scene)
	for i: int in 3:
		assert(layer.emit_effect(sample, Vector2.ZERO, Vector2.RIGHT) != null)
	assert(layer.emit_effect(sample, Vector2.ZERO, Vector2.RIGHT) == null, "Le plafond doit refuser le décor excédentaire.")
	assert(layer.get_child_count() == 3)
	var looping: Node2D = layer.get_child(0)
	looping.set("loop_visual", true)
	looping.call("play", Vector2.RIGHT)
	looping.call("_process", 0.8)
	assert(looping.get("_playing"), "Une persistance reste graphique jusqu'à son retrait par C7.")
	looping.call("release")
	looping.call("_process", 0.4)
	assert(not looping.get("_playing"), "Retirer une persistance termine aussi sa boucle visuelle.")
	layer.free()
	var busy := Layer.new()
	add_child(busy)
	for i: int in 24:
		assert(busy.emit_effect(sample, Vector2.ZERO, Vector2.RIGHT) != null)
	assert(busy.get_child(0).get("particle_budget") == 4)
	assert(busy.get_child(0).get("detail_level") == 0)
	for i: int in 18:
		busy.get_child(0).free()
	busy._refresh_budget()
	assert(busy.get_child(0).get("particle_budget") == 18)
	assert(busy.get_child(0).get("detail_level") == 1)
	busy.free()
	print("C5-bis : 45 scènes chargées, fin de lecture et plafond de présentation vérifiés.")
	get_tree().quit()
