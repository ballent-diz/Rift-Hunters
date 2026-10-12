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
	}
	return SafeJsonStore.new(path).save_data(data)


func apply() -> void:
	TranslationServer.set_locale(locale)
	var bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	for pair: Array in [["Music", music_volume], ["SFX", sfx_volume]]:
		var index: int = AudioServer.get_bus_index(pair[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(pair[1]), 0.0001)))
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


func set_locale(value: String) -> void:
	locale = value if SUPPORTED_LOCALES.has(value) else "en"
	apply()
	save_settings()
