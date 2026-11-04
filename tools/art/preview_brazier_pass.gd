extends Node
## Captures graphiques statiques : aucune modification du niveau ou du profil.

const ROOT := "res://assets/environments/brazier_pass/"

var _world: Node2D
var _layer: Node2D
var _hunter: EntityVisual
var _echo: EntityVisual
var _caption: Label
var _out: String


func _ready() -> void:
	Profile.read_only = true
	call_deferred("_capture")


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			return arg.trim_prefix(key + "=")
	return fallback


func _actor(visual: VisualData, animation: StringName = &"idle", frame: int = 0) -> EntityVisual:
	var entity := EntityVisual.new()
	_layer.add_child(entity)
	entity.setup(visual)
	assert(entity.has_sheet(), "Feuille absente : " + String(visual.visual_id))
	for child: Node in entity.get_children():
		if child is AnimatedSprite2D:
			if not child.sprite_frames.has_animation(animation):
				animation = &"move"
			child.play(animation)
			child.pause()
			child.frame = frame % child.sprite_frames.get_frame_count(animation)
	return entity


func _image(image: Image, at: Vector2, scale_value: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2.ONE * scale_value
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_world.add_child(sprite)


func _camera(center: Vector2) -> void:
	var zoom: float = GameDB.balance.camera_zoom
	_world.scale = Vector2.ONE * zoom
	_world.position = Vector2(640, 360) - center * zoom
	_hunter.position = center + Vector2(-100, 60)
	_echo.position = center + Vector2(-155, 75)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	assert(image.get_size() == Vector2i(1280, 720))
	assert(image.save_png(_out.path_join(name)) == OK)


func _capture() -> void:
	_out = _arg("--out", "/tmp/rift-brazier-pass")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	_world = Node2D.new()
	add_child(_world)
	_caption = Label.new()
	_caption.position = Vector2(15, 12)
	_caption.add_theme_font_size_override("font_size", 17)
	_caption.add_theme_color_override("font_outline_color", Color("132039"))
	_caption.add_theme_constant_override("outline_size", 7)
	add_child(_caption)
	var sample := _arg("--sample", "")
	if not sample.is_empty():
		var image := Image.load_from_file(sample)
		assert(image != null)
		_image(image, Vector2.ZERO, 1.0 / 2.25)
	else:
		for i: int in 3:
			var suffix := "" if i == 0 else "_%d" % i
			var image := Image.load_from_file(ProjectSettings.globalize_path(ROOT + "map%s.webp" % suffix))
			assert(image != null and image.get_size() == Vector2i(3762, 11286))
			_image(image, Vector2(i * 1672, 0), 1.0 / 2.25)
		_world.scale = Vector2.ONE * (640.0 / 5016.0)
		_world.position = Vector2(320, 60)
		_caption.text = "CARTE 17 · COL DES BRASEROS · DÉTAIL ENTIER · CONTRÔLE GRAPHIQUE HORS PARTIE"
		await _save("apercu_720p.png")
	_layer = Node2D.new()
	_layer.y_sort_enabled = true
	_layer.z_index = 2
	_world.add_child(_layer)
	_hunter = _actor(GameDB.balance.player_visual)
	_echo = _actor(GameDB.enemy(&"snow_wraith").visual)
	if not sample.is_empty():
		_camera(Vector2(500, 740))
		_caption.text = "CARTE 17 · TÉMOIN DU POSTE DE GARDE · CAMÉRA RÉELLE · CHASSEUR ET ÉCHO"
		await _save("temoin_poste_zoom_jeu.png")
	else:
		for spec: Array in [["camp", Vector2(1988, 4324)], ["pont", Vector2(2172, 3260)],
				["corniche", Vector2(2628, 2584)], ["raccourci", Vector2(2640, 2200)],
				["surplomb", Vector2(2400, 1828)], ["poste", Vector2(4048, 720)],
				["poste_ouest", Vector2(1712, 340)], ["poste_nord", Vector2(2500, 340)],
				["sommet", Vector2(2709, 752)]]:
			_camera(spec[1])
			_caption.text = "COL DES BRASEROS · %s · ZOOM DU JEU · CHASSEUR ET ÉCHO" % String(spec[0]).to_upper()
			await _save(String(spec[0]) + "_zoom_jeu.png")
		var brazier := VisualData.new()
		brazier.visual_id = &"object.brazier"
		brazier.size = 48
		var fire := _actor(brazier, &"lit", 2)
		fire.position = Vector2(2172, 3260)
		_camera(fire.position)
		_caption.text = "FOYER + SPRITE BRASERO EXISTANT · APERÇU STATIQUE · AUCUN BRASERO PEINT DANS LA CARTE"
		await _save("brasero_lit_zoom_jeu.png")
		fire.queue_free()
		var center := Vector2(1320, 3460)
		_camera(center)
		_hunter.position = center + Vector2(0, 210)
		_echo.visible = false
		var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/chapitre4_catalogue.json"))
		for i: int in 7:
			var visual: VisualData
			for enemy: EnemyData in GameDB.enemies.values():
				if String(enemy.visual.visual_id) == catalog[i]["visual_id"]:
					visual = enemy.visual
					break
			assert(visual != null)
			var entity := _actor(visual, &"move", i % 6)
			entity.position = center + Vector2((i * 140 - 210) if i < 4 else ((i - 4) * 140 - 140),
				-80 if i < 4 else 100)
		_caption.text = "GIVRÉS · 7 SPRITES LIVRÉS · TAILLE DU MANIFESTE · ZOOM RÉEL ×%.4f" % GameDB.balance.camera_zoom
		await _save("givres_zoom_jeu.png")
		for child: Node in _layer.get_children():
			if child != _hunter and child != _echo:
				child.queue_free()
		for child: Node in _world.get_children():
			if child != _layer:
				child.queue_free()
		await get_tree().process_frame
		for i: int in 3:
			var suffix := "" if i == 0 else "_%d" % i
			var path := "res://assets/environments/cascade_ruins/map%s.webp" % suffix
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			assert(image != null)
			_image(image, Vector2(i * 1672, 0), 1.0 / 2.25)
		_echo.visible = true
		_camera(Vector2(2700, 500))
		_caption.text = "RUINES DES CASCADES · MÊME ZOOM, CHASSEUR ET ÉCHO · RÉFÉRENCE D’ÉCHELLE"
		await _save("reference_ruines_zoom_jeu.png")
	print("BRAZIER_PASS_PREVIEW_OK · témoin : ", not sample.is_empty())
	get_tree().quit(0)
