extends Node
## Captures 720p du refuge réel sur profils isolés ; aucune sauvegarde du joueur.

const OUT := "res://docs/previews/echo-expedition/"

var _screen: Refuge
var _viewport: SubViewport


func _ready() -> void:
	Profile.read_only = true
	Profile.profile = ProfileData.new()
	TranslationServer.set_locale("fr")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	await _rebuild(0)
	await _capture("03-expedition-profil-neuf")
	HunterTree.unlock_all_for_testing(Profile.profile)
	for id: StringName in GameDB.monsters:
		Profile.profile.unlock("monster:" + String(id))
	Profile.profile.set_preference("arena", "storm_highlands")
	Profile.profile.set_preference("difficulty", "nightmare")
	await _rebuild(0)
	await _capture("04-expedition-mode-test")
	await _rebuild(2)
	var tab: RefugeTab = _screen.tabs.get_child(3)
	tab._monster = &"ashblade"
	tab._selected = &"ashblade_spell_alt"
	_screen.refresh_current()
	await _capture("01-echos-cendrelame")
	tab._monster = &"mossback"
	tab._selected = &"mossback_signature"
	_screen.refresh_current()
	await _capture("02-echos-mousseroc")
	TranslationServer.set_locale("en")
	await _rebuild(0)
	await _capture("05-expedition-en")
	_screen.queue_free()
	_viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _rebuild(index: int) -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
		await get_tree().process_frame
	_screen = load(Router.REFUGE).instantiate()
	_viewport.add_child(_screen)
	_screen.tabs.current_tab = index
	for i: int in 5:
		await get_tree().process_frame


func _capture(file: String) -> void:
	for i: int in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(OUT + file + ".png")
	print("Capture : ", file)
