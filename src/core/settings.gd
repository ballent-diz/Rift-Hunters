extends Node
## Options du joueur (user://settings.json), appliquées au démarrage.

signal changed

const FORMAT_VERSION := 1
const SUPPORTED_LOCALES: Array[String] = ["fr", "en"]

## Fenêtre au démarrage : part de l'écran utilisable au plus, et taille minimale (fit_window).
const WINDOW_SCREEN_SHARE := 0.9
const WINDOW_MIN := Vector2i(960, 540)

var path: String = "user://settings.json"
var locale: String = ""
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var fullscreen: bool = false
var screen_shake: bool = true
var damage_numbers: bool = true
var vsync: bool = true
## Accessibilité : supprime les flashs et pulsations (photosensibilité).
var reduce_flashes: bool = false
var show_fps: bool = false
## Mini-carte : 0 = masquée, 1 = petite, 2 = moyenne, 3 = grande.
var minimap_size: int = 2
## Sorts du Chasseur : maintenir la touche affiche la zone, la relâcher lance (sinon lancement immédiat).
var spell_preview: bool = false
## Filtre pixel du décor dessiné : PixelFilter.OFF / FINE / GRAPHIC (BOLD reste interne).
var pixel_filter: String = PixelFilter.GRAPHIC
## Mode des Échos à l'essai (EchoMode : « current » par défaut, « relay », « solo ») ; appliqué à la partie suivante.
var echo_mode: String = "current"
## Mode de contrôle : « keyboard » (tout au clavier, visée dans la direction du Chasseur) ou « mouse » (clavier +
## souris, visée au curseur). Chaque mode a ses touches par défaut (InputSetup).
var control_scheme: String = "keyboard"
## Touches personnalisées du clavier : {action: [touches physiques]} (actions absentes : touches par défaut).
var bindings: Dictionary = {}
## Dernier périphérique utilisé : true = manette (visée assistée, navigation au pad).
var using_gamepad: bool = false
var load_status: SafeJsonStore.LoadStatus = SafeJsonStore.LoadStatus.MISSING


func _ready() -> void:
	InputSetup.ensure_actions()
	load_settings()
	apply()
	fit_window()


func load_settings() -> void:
	var store := SafeJsonStore.new(path)
	var data: Dictionary = store.load_data()
	load_status = store.last_status
	locale = str(data.get("locale", ""))
	master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(data.get("fullscreen", fullscreen))
	screen_shake = bool(data.get("screen_shake", screen_shake))
	damage_numbers = bool(data.get("damage_numbers", damage_numbers))
	vsync = bool(data.get("vsync", vsync))
	reduce_flashes = bool(data.get("reduce_flashes", reduce_flashes))
	show_fps = bool(data.get("show_fps", show_fps))
	minimap_size = clampi(int(data.get("minimap_size", minimap_size)), 0, 3)
	spell_preview = bool(data.get("spell_preview", spell_preview))
	var filter: String = str(data.get("pixel_filter", PixelFilter.GRAPHIC))
	pixel_filter = filter if PixelFilter.is_valid(filter) else PixelFilter.GRAPHIC
	echo_mode = String(EchoMode.sanitize(data.get("echo_mode", "current")))
	control_scheme = "mouse" if str(data.get("control_scheme", "keyboard")) == "mouse" else "keyboard"
	bindings = {}
	var saved: Variant = data.get("bindings", {})
	if int(data.get("bindings_version", 1)) < InputSetup.BINDINGS_VERSION:
		saved = {}
	if saved is Dictionary:
		for action: Variant in saved:
			if InputSetup.REBINDABLE.has(StringName(str(action))) and saved[action] is Array:
				bindings[str(action)] = saved[action]
	if locale == "":
		locale = "fr" if OS.get_locale_language() == "fr" else "en"
	if not SUPPORTED_LOCALES.has(locale):
		locale = "en"


func save_settings() -> Error:
	var data := {
		"format_version": FORMAT_VERSION,
		"locale": locale,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"screen_shake": screen_shake,
		"damage_numbers": damage_numbers,
		"vsync": vsync,
		"reduce_flashes": reduce_flashes,
		"show_fps": show_fps,
		"minimap_size": minimap_size,
		"spell_preview": spell_preview,
		"pixel_filter": pixel_filter,
		"control_scheme": control_scheme,
		"echo_mode": echo_mode,
		"bindings": bindings,
		"bindings_version": InputSetup.BINDINGS_VERSION,
	}
	return SafeJsonStore.new(path).save_data(data)


func apply() -> void:
	TranslationServer.set_locale(locale)
	InputSetup.apply_bindings(bindings, control_scheme)
	var bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	for pair: Array in [["Music", music_volume], ["SFX", sfx_volume]]:
		var index: int = AudioServer.get_bus_index(pair[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(pair[1]), 0.0001)))
	if DisplayServer.get_name() != "headless":
		var current: DisplayServer.WindowMode = DisplayServer.window_get_mode()
		if fullscreen != is_fullscreen_mode(current):
			# Fenêtre agrandie ou réduite = mode fenêtré : on ne la remet pas à sa taille d'origine à chaque réglage.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)
			if not fullscreen:
				fit_window()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	changed.emit()


## Fenêtre entièrement visible et centrée (retour de test : sur un petit écran ou avec une mise à l'échelle Windows,
## la fenêtre de 1600 × 900 débordait et une partie des menus était hors de portée).
func fit_window() -> void:
	if DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen: int = DisplayServer.window_get_current_screen()
	var rect: Rect2i = fitted_window(DisplayServer.screen_get_usable_rect(screen), DisplayServer.window_get_size())
	DisplayServer.window_set_size(rect.size)
	DisplayServer.window_set_position(rect.position)


## Taille et position d'une fenêtre `wanted` dans la zone utile de l'écran `usable` : réduite au besoin (90 % de la
## zone au plus, rapport 16:9 gardé, jamais sous 960 × 540 si l'écran le permet), puis centrée.
static func fitted_window(usable: Rect2i, wanted: Vector2i) -> Rect2i:
	var room := Vector2(usable.size) * WINDOW_SCREEN_SHARE
	var ratio: float = minf(1.0, minf(room.x / maxf(wanted.x, 1.0), room.y / maxf(wanted.y, 1.0)))
	var size := Vector2i((Vector2(wanted) * ratio).round())
	size = size.max(WINDOW_MIN.min(usable.size))
	return Rect2i(usable.position + (usable.size - size) / 2, size)


static func is_fullscreen_mode(mode: DisplayServer.WindowMode) -> bool:
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Change le filtre pixel, sauvegarde et prévient les abonnés (le sol de la partie en cours se met à jour).
func set_pixel_filter(value: String) -> void:
	pixel_filter = value if PixelFilter.is_valid(value) else PixelFilter.GRAPHIC
	save_settings()
	changed.emit()


## Passe au mode des Échos suivant (Actuel → Relais → Solo) et sauvegarde.
func cycle_echo_mode() -> void:
	echo_mode = String(EchoMode.next(StringName(echo_mode)))
	save_settings()
	changed.emit()


func set_locale(value: String) -> void:
	locale = value if SUPPORTED_LOCALES.has(value) else "en"
	apply()
	save_settings()


## Attribue une touche à une action ; si une autre action l'utilisait, elle prend l'ancienne touche (échange).
func bind_key(action: StringName, keycode: int) -> void:
	var previous: Array[int] = InputSetup.keys_of(action)
	for other: StringName in InputSetup.REBINDABLE:
		if other != action and InputSetup.keys_of(other).has(keycode):
			var keys: Array[int] = InputSetup.keys_of(other)
			keys.erase(keycode)
			if not previous.is_empty() and not keys.has(previous[0]):
				keys.push_front(previous[0])
			bindings[String(other)] = keys
	# La touche choisie devient la principale ; les touches secondaires (flèches…) sont gardées.
	var keys: Array[int] = [keycode]
	for key: int in previous.slice(1):
		if key != keycode:
			keys.append(key)
	bindings[String(action)] = keys
	apply()
	save_settings()


## Change de mode de contrôle : les touches reprennent les défauts du nouveau mode.
func set_control_scheme(scheme: String) -> void:
	control_scheme = "mouse" if scheme == "mouse" else "keyboard"
	bindings = {}
	apply()
	save_settings()


func uses_mouse() -> bool:
	return control_scheme == "mouse" and not using_gamepad


func reset_bindings() -> void:
	bindings = {}
	apply()
	save_settings()


func _input(event: InputEvent) -> void:
	var joy_motion: bool = event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4
	if event is InputEventJoypadButton or joy_motion:
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		using_gamepad = false
