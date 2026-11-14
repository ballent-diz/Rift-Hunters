class_name DraftMenu
extends Node3D
## Menu principal de la version 3D : écran titre sur la Cour des Veilleurs vue en caméra lente, boutons Jouer /
## Options / Quitter, navigation clavier, souris et manette (actions ui_* de Godot). Jouer ouvre la partie
## (draft3d/main.tscn) sur le choix du chapitre. Aucune règle de jeu ici ; les options sont celles de `Settings`.
##
## Lancement : scène de démarrage du projet. Options (après --) : --options (ouvre les options),
##   --locale=fr|en (langue de cette session, non sauvegardée), --shot=<fichier.png> --shot-frames=8 (capture puis quitte).

const RUN_SCENE := "res://draft3d/main.tscn"
const SCENE := "res://draft3d/menu.tscn"
## Centre de l'orbite de la caméra (Cour des Veilleurs) et vitesse de rotation (radians par seconde).
const ORBIT_CENTER := Vector3(0, 0, 6)
const ORBIT_SPEED := 0.035
const ORBIT_RADIUS := 26.0
const ORBIT_HEIGHT := 19.0
const INK := Color("f0e8d7")
const GOLD := Color("ffd9a0")

## Lance la partie ; remplaçable par les essais (aucun changement de scène pendant les tests).
var launcher: Callable = func(path: String) -> void: Router.goto_scene(path)
var camera: Camera3D
var level: DraftLevel
var ui: Control
var buttons: Array[Button] = []
var options_panel: Control
var _yaw: float = 0.6
var _options: Dictionary = {}
var _frames: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		_options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _options.has("locale"):
		TranslationServer.set_locale(String(_options["locale"]))
	_build_backdrop()
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	ui = Control.new()
	ui.name = "Root"
	ui.theme = UiKit.theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	build_ui()
	Audio.play_context("menu")
	if _options.has("options"):
		open_options()


func _process(delta: float) -> void:
	_yaw += ORBIT_SPEED * delta
	_place_camera()
	if _options.has("shot"):
		_frames += 1
		if _frames == int(_options.get("shot-frames", "8")):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(String(_options["shot"]))
			get_tree().quit()


# --- Décor : la Cour des Veilleurs, sans ennemis ni navigation -------------------------------------------------

func _build_backdrop() -> void:
	level = DraftLevel.create(1)
	add_child(level)
	level.build()
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = level.sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = level.ambient
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -35, 0)
	sun.light_color = level.sun
	sun.light_energy = level.sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	camera.far = 160.0
	add_child(camera)
	camera.current = true
	_place_camera()


func _place_camera() -> void:
	if camera == null:
		return
	camera.position = ORBIT_CENTER + Vector3(sin(_yaw) * ORBIT_RADIUS, ORBIT_HEIGHT, cos(_yaw) * ORBIT_RADIUS)
	camera.look_at(ORBIT_CENTER)


# --- Interface -------------------------------------------------------------------------------------------------

func build_ui() -> void:
	UiKit.clear(ui)
	buttons.clear()
	options_panel = null
	# Voile sombre à gauche : le titre et les boutons restent lisibles sur le décor.
	var veil := TextureRect.new()
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x: int in 256:
		var t: float = x / 255.0
		image.set_pixel(x, 0, Color(0.02, 0.02, 0.06, 0.9 * clampf(1.0 - t / 0.75, 0.0, 1.0)))
	veil.name = "Veil"
	veil.texture = ImageTexture.create_from_image(image)
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(veil)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.anchor_left = 0.07
	column.anchor_top = 0.5
	column.anchor_right = 0.07
	column.anchor_bottom = 0.5
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	ui.add_child(column)
	var title: Label = UiKit.title(tr("MENU3D_TITLE"), 76, GOLD)
	title.name = "Title"
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.16, 0.9))
	column.add_child(title)
	var tagline: Label = UiKit.label(tr("MENU3D_TAGLINE"), 20, INK)
	tagline.name = "Tagline"
	_outline(tagline)
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	column.add_child(gap)
	for entry: Array in [["Play", "MENU3D_PLAY", play], ["Options", "MENU_OPTIONS", open_options],
			["Quit", "MENU_QUIT", quit]]:
		var button: Button = UiKit.button(tr(entry[1]), entry[2], 340)
		button.name = entry[0]
		button.custom_minimum_size.y = 54
		button.add_theme_font_size_override("font_size", 24)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.mouse_entered.connect(button.grab_focus)
		column.add_child(button)
		buttons.append(button)
	_chain_focus(buttons)
	var version: Label = UiKit.caption("v" + str(ProjectSettings.get_setting("application/config/version")), 14)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 20
	version.offset_top = -34
	ui.add_child(version)
	var hint: Label = UiKit.label(tr("MENU3D_NAV_HINT"), 15, UiKit.MUTED)
	hint.name = "Hint"
	_outline(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -700
	hint.offset_right = -20
	hint.offset_top = -34
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.add_child(hint)
	buttons[0].grab_focus.call_deferred()


static func _outline(label: Label) -> void:
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))


func play() -> void:
	DraftRun.chosen_chapter = 0
	launcher.call(RUN_SCENE)


func quit() -> void:
	get_tree().quit()


func open_options() -> void:
	if options_panel != null:
		return
	options_panel = DraftOptions.new()
	options_panel.name = "Options"
	ui.add_child(options_panel)
	options_panel.closed.connect(close_options)
	options_panel.language_changed.connect(func() -> void:
		build_ui()
		open_options())


func close_options() -> void:
	if options_panel == null:
		return
	options_panel.queue_free()
	options_panel = null
	buttons[1].grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if options_panel != null and event.is_action_pressed(&"ui_cancel"):
		close_options()
		get_viewport().set_input_as_handled()


## Haut/bas en boucle (clavier, croix et stick de la manette).
static func _chain_focus(list: Array[Button]) -> void:
	for index: int in list.size():
		var previous: NodePath = list[index].get_path_to(list[posmod(index - 1, list.size())])
		var next: NodePath = list[index].get_path_to(list[(index + 1) % list.size()])
		list[index].focus_neighbor_top = previous
		list[index].focus_previous = previous
		list[index].focus_neighbor_bottom = next
		list[index].focus_next = next
		list[index].focus_neighbor_left = list[index].get_path_to(list[index])
		list[index].focus_neighbor_right = list[index].get_path_to(list[index])
