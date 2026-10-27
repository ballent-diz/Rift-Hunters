extends Node
## Captures du véritable écran de l'arbre du Chasseur à 1280×720, sur des profils de démonstration isolés (jamais
## sauvegardés) : première visite (guide), départ, milieu de campagne, variantes, améliorations du refuge (anglais),
## voie du Prisme, pages du guide. Usage : xvfb-run -a godot --path . res://tools/art/c5_tree_preview.tscn
## [-- --out=/dossier] [--size=1600x900]

var out: String = "res://docs/previews/c5/tree/"
var _screen: Refuge
var _tab: RefugeTab
var _viewport: SubViewport


func _ready() -> void:
	var size := Vector2i(1280, 720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
		elif arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	Profile.read_only = true
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var display := TextureRect.new()
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	TranslationServer.set_locale("fr")
	# Première visite : le guide s'ouvre ; puis ses pages.
	Profile.profile = ProfileData.new()
	await _open()
	await _capture("01-premiere-visite-fr")
	for page: int in range(1, TreeGuide.PAGES):
		_tab.set("_guide_page", page)
		await _capture("02-guide-page%d-fr" % (page + 1))
	# Départ, guide fermé.
	Profile.profile.set_preference("tree_guide_seen", "1")
	_tab.set("_guide_page", -1)
	await _capture("03-depart-fr")
	# Milieu du chapitre 1 : quelques nœuds appris, un boss vaincu, des Éclats en poche.
	_mid_campaign(Profile.profile)
	_tab._selected = &"blade_rift_leap"
	await _capture("04-milieu-campagne-fr")
	_tab._selected = &"blade_slash_thrust"
	await _capture("05-variante-fr")
	_tab._selected = &"blade_parry"
	await _capture("06-niveau-ferme-fr")
	TranslationServer.set_locale("en")
	_tab._selected = &"blade_honed_edge"
	await _capture("07-passif-en")
	_tab._show_upgrades = true
	_tab._selected = &"research_fourth_option"
	await _capture("08-refuge-en")
	TranslationServer.set_locale("fr")
	_tab._show_upgrades = false
	_tab._focused_branch = &"prism"
	_tab._selected = &"prism_prismatic_lance"
	await _capture("09-prisme-fr")
	_screen.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _open() -> void:
	_screen = load(Router.REFUGE).instantiate()
	_viewport.add_child(_screen)
	_screen.tabs.current_tab = 2
	_tab = _screen.tabs.get_child(2)
	await get_tree().process_frame


## Profil d'exemple : 1 boss vaincu, 4 cartes gagnées, la Lame entamée.
func _mid_campaign(p: ProfileData) -> void:
	p.data["runs"]["won"] = 1
	for i: int in 4:
		HunterTree.record_victory(p, "preview_%d" % i)
	p.add_currency("shards", 2000)
	for id: StringName in [&"blade_honed_edge", &"blade_honed_edge", &"combat_shattering_dash", &"blade_slicing_dash",
			&"blade_rift_leap", &"blade_slash_whirlwind", &"trunk_vigor", &"combat_training"]:
		HunterTree.learn(p, GameDB.skill_node(id))
	for id: StringName in [&"blade_honed_edge", &"blade_honed_edge", &"blade_slash_whirlwind", &"blade_slicing_dash"]:
		HunterTree.activate(p, GameDB.skill_node(id))
	p.add_currency("shards", -p.shards() + 260)


func _capture(file: String) -> void:
	_screen.refresh_all()
	for i: int in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	var image: Image = _viewport.get_texture().get_image()
	image.save_webp(out + file + ".webp", true, 0.85)
	print("Capture arbre : ", file, " ", image.get_size())
