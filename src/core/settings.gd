extends Node
## Options du joueur (user://settings.json), appliquées au démarrage.

signal changed

const FORMAT_VERSION := 1
const SUPPORTED_LOCALES: Array[String] = ["fr", "en"]

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
## Touches personnalisées du clavier : {action: [touches physiques]} (actions absentes : touches par défaut).
var bindings: Dictionary = {}
## Dernier périphérique utilisé : true = manette (visée assistée, navigation au pad).
var using_gamepad: bool = false
var load_status: SafeJsonStore.LoadStatus = SafeJsonStore.LoadStatus.MISSING


func _ready() -> void:
	InputSetup.ensure_actions()
	load_settings()
	apply()


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
		"bindings": bindings,
		"bindings_version": InputSetup.BINDINGS_VERSION,
	}
	return SafeJsonStore.new(path).save_data(data)


func apply() -> void:
	TranslationServer.set_locale(locale)
	InputSetup.apply_bindings(bindings)
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
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	changed.emit()


static func is_fullscreen_mode(mode: DisplayServer.WindowMode) -> bool:
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


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
