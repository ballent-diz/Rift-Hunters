extends Node
## Contrôle de chargement/rendu en un seul passage. Aucune capture ou vidéo produite.

func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/vfx/hunter/remaining_catalog.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var count := 0
	for entry: Dictionary in catalog.effects:
		var scene_path: String = "res://assets/vfx/hunter/"+entry.id+"/"+entry.id+".tscn"
		var scene: PackedScene = load(scene_path)
		if scene == null:
			get_tree().quit(1)
			return
		for variant: String in entry.variants:
			var effect: Node2D = scene.instantiate()
			effect.set("destroy_on_finish",false)
			viewport.add_child(effect)
			effect.position = Vector2(480,350)
			effect.call("play",Vector2.RIGHT,StringName(variant))
			var seconds: float = float(effect.call("duration"))
			if not is_equal_approx(seconds,float(entry.variants[variant])):
				push_error("Durée incohérente : "+str(entry.id)+" / "+variant)
				get_tree().quit(1)
				return
			effect.call("set_secondary_offsets",PackedVector2Array([
				Vector2(-100,-65),Vector2(-120,55),Vector2(65,90)]))
			effect.call("set_secondary_colors",PackedColorArray([
				Color("e5b88f"),Color("9edcba"),Color("b1c7eb")]))
			for phase: float in [0.0,.06,.28,.65,.97]:
				effect.call("seek_visual",seconds*phase)
				effect.call("trigger_pulse",Vector2.ZERO,Vector2.RIGHT)
				effect.set("_pulse_age",.08)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
			effect.call("play_between",Vector2(480,350),Vector2(600,440),StringName(variant))
			effect.call("release")
			await RenderingServer.frame_post_draw
			effect.queue_free()
			await get_tree().process_frame
			count += 1
		print("C5 chargé : ",entry.id," / 3 variantes")
	print("C5 : ",count," configurations chargées et rendues ; aucune image exportée.")
	get_tree().quit(0 if count == 30 else 1)
