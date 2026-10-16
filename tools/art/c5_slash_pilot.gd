extends Node
## Démonstrateur visuel isolé : ne lance pas de partie et ne modifie aucune sauvegarde.
var stage: Node2D
var elapsed: float = 0.0
var capture := false

func _ready() -> void:
	var output := "res://docs/previews/c5/pilot"
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--capture":
			capture = true
		elif argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	stage = load("res://tools/art/c5_slash_pilot_stage.gd").new()
	viewport.add_child(stage)
	var display := TextureRect.new()
	add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if not capture:
		return
	DirAccess.make_dir_recursive_absolute(output)
	var shots := {"arming":.59,"cut":.68,"impact":.72,"recovery":.94}
	for shot: String in shots:
		stage.call("sample",float(shots[shot]))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output+"/"+shot+".png")
		print("C5 pilote : ",shot)
	for frame: int in 60:
		stage.call("sample",float(frame)/30.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output+"/frame_%02d.png" % frame)
	print("C5 pilote : 60 images natives, cycle de 2 secondes")
	get_tree().quit()

func _process(delta: float) -> void:
	if not capture and stage != null:
		elapsed += delta
		stage.call("sample",elapsed)
