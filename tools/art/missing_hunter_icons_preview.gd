extends Node
## Écran réel en 1280×720, profil isolé en lecture seule ; aucune sauvegarde du propriétaire.
const OUT := "res://docs/previews/c5-icones-chasseur/"
var _viewport: SubViewport


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_window().unfocusable = true
	Profile.profile = ProfileData.new()
	Profile.read_only = true
	Profile.profile.add_currency("shards", 100000)
	Profile.profile.data["runs"]["won"] = 3
	for i: int in 14:
		HunterTree.record_victory(Profile.profile, "icons_preview_%d" % i)
	for pass_index: int in 8:
		for id: StringName in GameDB.sorted_ids(GameDB.skill_nodes):
			var node: SkillNodeData = GameDB.skill_node(id)
			while HunterTree.status(Profile.profile, node) == HunterTree.Status.LEARNABLE:
				HunterTree.learn(Profile.profile, node)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	DirAccess.make_dir_recursive_absolute(OUT)
	for branch: StringName in [&"blade", &"prism", &"abyss", &"bond", &"research"]:
		TranslationServer.set_locale("en" if branch == &"research" else "fr")
		var screen: Refuge = load(Router.REFUGE).instantiate()
		_viewport.add_child(screen)
		screen.tabs.current_tab = 1
		var tab: RefugeTab = screen.tabs.get_child(1)
		tab._focused_branch = branch if branch != &"research" else &"blade"
		tab._show_upgrades = branch == &"research"
		var selected := {&"blade": &"blade_honed_edge", &"prism": &"spec_pyromancer",
			&"abyss": &"spec_gravitationist", &"bond": &"echoes_pack_leader", &"research": &"research_fourth_option"}
		tab._selected = selected[branch]
		screen.refresh_all()
		for i: int in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_viewport.get_texture().get_image().save_png(OUT + String(branch) + ".png")
		print("Capture des icônes : ", branch)
		screen.queue_free()
		await get_tree().process_frame
	get_tree().quit()
