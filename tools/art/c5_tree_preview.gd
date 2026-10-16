extends Node
## Captures du véritable écran C5 à 1280×720, sur un profil de démonstration isolé (jamais sauvegardé).

const OUT := "res://docs/previews/c5/tree/"

var _screen: Refuge
var _tab: RefugeTab
var _viewport: SubViewport


func _ready() -> void:
	Profile.profile = ProfileData.new()
	Profile.read_only = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var display := TextureRect.new()
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen = load(Router.REFUGE).instantiate()
	_viewport.add_child(_screen)
	_screen.tabs.current_tab = 1
	_tab = _screen.tabs.get_child(1)
	TranslationServer.set_locale("fr")
	await _capture("01-depart-fr")
	_prepare_build()
	_tab._selected = &"blade_master"
	await _capture("02-build-fr")
	_tab._selected = &"blade_slash_whirlwind"
	await _capture("03-variantes-fr")
	TranslationServer.set_locale("en")
	_screen.queue_free()
	await get_tree().process_frame
	_screen = load(Router.REFUGE).instantiate()
	_viewport.add_child(_screen)
	_screen.tabs.current_tab = 1
	_tab = _screen.tabs.get_child(1)
	_tab._show_upgrades = true
	_tab._selected = &"research_fourth_option"
	await _capture("04-refuge-en")
	_screen.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _prepare_build() -> void:
	var p: ProfileData = Profile.profile
	p.add_currency("shards", 100000)
	p.data["runs"]["won"] = 3
	for i: int in 14:
		HunterTree.record_victory(p, "preview_%d" % i)
	for pass_index: int in 8:
		for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
			var node: SkillNodeData = GameDB.skill_node(id)
			while HunterTree.status(p, node) == HunterTree.Status.LEARNABLE:
				HunterTree.learn(p, node)
	for id: StringName in [&"blade_rift_leap", &"abyss_rift_wall", &"blade_slash_whirlwind", &"blade_master",
		&"blade_slicing_dash", &"blade_honed_edge"]:
		HunterTree.activate(p, GameDB.skill_node(id))


func _capture(file: String) -> void:
	_screen.refresh_all()
	for i: int in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	var image: Image = _viewport.get_texture().get_image()
	image.save_png(OUT + file + ".png")
	print("Capture C5 : ", file, " ", image.get_size())
