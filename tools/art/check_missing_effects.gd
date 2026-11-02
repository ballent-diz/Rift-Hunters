extends SceneTree
## Contrôles du contrat natif : chargement, temps figé, boucle, retrait unique et réutilisation.
var failures: int = 0
var completions: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var catalog_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--catalog="):
			catalog_path = arg.trim_prefix("--catalog=")
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	_check(not entries.is_empty(), "Un catalogue vide ne valide aucun effet")
	for item: Dictionary in entries:
		var scene: PackedScene = load(item["scene"])
		_check(scene != null, "Scène absente : " + item["key"])
		if scene == null:
			continue
		var effect: Node2D = scene.instantiate()
		effect.destroy_on_finish = false
		root.add_child(effect)
		_check(effect.get_meta("visual_only", false), "Métadonnée visual_only absente")
		_check(effect.get_child_count() == 0, "Un effet doit rester un seul Node2D sans acteur de combat")
		effect.visual_finished.connect(func() -> void: completions += 1)
		var expected := completions
		var path := PackedVector2Array([Vector2.ZERO, Vector2(120, 0), Vector2(120, 90)])
		effect.set_path_local(path)
		_check(effect.path_points == path, "Le trajet confirmé a été modifié")
		effect.set_secondary_offsets(PackedVector2Array([Vector2(40, 10), Vector2(-40, 10)]))
		effect.set_visual_state(0.7, 0.8)
		effect.play(Vector2.DOWN)
		_check(is_equal_approx(effect.rotation, PI * 0.5), "Orientation incohérente")
		for time: float in [0.0, 0.25, 0.5, 0.85]:
			effect.seek_visual(time * effect.duration())
			await process_frame
		var frozen: float = effect._elapsed
		effect._process(0.1)
		_check(is_equal_approx(frozen, effect._elapsed), "seek_visual ne fige pas le temps")
		effect.loop_visual = true
		effect.play()
		effect._process(effect.duration() * 3)
		_check(completions == expected, "La boucle termine seule")
		effect.release()
		effect._process(0.23)
		effect._process(0.23)
		_check(completions == expected + 1, "Le retrait doit émettre exactement une fin")
		effect.loop_visual = false
		effect.play_from(effect.duration() * 0.8)
		effect._process(effect.duration())
		_check(completions == expected + 2, "La réutilisation ne termine pas")
		effect.free()
	print("EFFETS : %d scènes, %d fins vérifiées, %d erreurs" % [entries.size(), completions, failures])
	quit(0 if failures == 0 else 1)
