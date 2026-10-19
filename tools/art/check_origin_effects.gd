extends Node
## Compatibilité des ressources C5-ter avec le raccordement existant et la couche de C5-bis.
const Layer = preload("res://assets/vfx/echoes/effect_layer.gd")


func _ready() -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/echoes/origin_scenes.json"))
	var layer := Layer.new()
	add_child(layer)
	for item: Dictionary in catalog:
		var scene: PackedScene = load(item.scene)
		assert(scene != null, item.scene)
		var effect: Node2D = layer.emit_effect(scene, Vector2.ZERO, Vector2.ZERO)
		assert(effect.get_child_count() == 0, "Aucun nœud par particule.")
		assert(is_zero_approx(effect.rotation))
		effect.set("destroy_on_finish", false)
		effect.call("set_secondary_offsets", PackedVector2Array([Vector2(10, 0), Vector2(50, 30)]))
		for fraction: float in [0.0, 0.08, 0.4, 0.9, 1.0]:
			effect.call("seek_visual", float(item.duration) * fraction)
		effect.call("play", Vector2.RIGHT)
		effect.call("release")
		effect.call("_process", 1.0)
		assert(not effect.get("_playing"), "release doit terminer aussi les boucles.")
		layer.remove_child(effect)
		effect.free()
	for id: String in ["ashblade", "gloommaw", "mirrorling"]:
		assert(not ResourceLoader.exists("res://assets/vfx/echoes/%s/status.tscn" % id))
	var reflection: Node2D = load("res://assets/vfx/echoes/mirrorling/reflection.tscn").instantiate()
	add_child(reflection)
	reflection.call("play")
	reflection.call("_process", 2.1)
	assert(reflection.get("_playing"), "Le miroir reste actif jusqu'au retrait de la garde par C7.")
	reflection.free()
	var sample: PackedScene = load(catalog[0].scene)
	for i: int in 24:
		assert(layer.emit_effect(sample, Vector2.ZERO, Vector2.RIGHT) != null)
	assert(layer.emit_effect(sample, Vector2.ZERO, Vector2.RIGHT) == null)
	assert(layer.get_child(0).get("particle_budget") == 4)
	layer.free()
	print("C5-ter : 32 scènes, contrat, boucle miroir, absences de statut et plafond partagé vérifiés.")
	get_tree().quit()
