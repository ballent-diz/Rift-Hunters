extends Node
## Aperçus visuels : caméra et sprites réels, sans logique ni collisions.
var root: Window
var stage: Node2D
var background: Sprite2D
var records: Array

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root = get_window()
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	root.unfocusable = true
	root.position = Vector2i(-20000, -20000)
	stage = Node2D.new()
	root.add_child(stage)
	background = Sprite2D.new()
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	stage.add_child(background)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * GameDB.balance.camera_zoom
	stage.add_child(camera)
	var hunter := EntityVisual.new()
	stage.add_child(hunter)
	hunter.setup(GameDB.balance.player_visual)
	var echo := EntityVisual.new()
	stage.add_child(echo)
	echo.position = Vector2(55, 20)
	echo.setup(GameDB.monster(&"mossback").visual)
	for actor: EntityVisual in [hunter, echo]:
		actor.z_index = 2
		if actor._anim:
			actor._anim.pause()
			actor._anim.frame = 0
	records = JSON.parse_string(FileAccess.get_file_as_string("res://docs/previews/gue-des-brumes/comparaison.json"))
	for record: Dictionary in records:
		var image := Image.load_from_file(ProjectSettings.globalize_path(record.crop))
		assert(image != null and not image.is_empty())
		background.texture = ImageTexture.create_from_image(image)
		background.scale = Vector2(1280, 720) / GameDB.balance.camera_zoom / Vector2(image.get_size())
		background.material = null
		if float(record.get("detail_strength", 0.0)) > 0.0:
			var detail := ShaderMaterial.new()
			detail.shader = load("res://assets/shaders/map_detail.gdshader")
			detail.set_shader_parameter("strength", record.detail_strength)
			background.material = detail
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := root.get_texture().get_image()
		assert(output.get_size() == Vector2i(1280, 720))
		assert(output.save_png(ProjectSettings.globalize_path(record.capture)) == OK)
		print("CAPTURE_OK ", record.id)
	get_tree().quit()
