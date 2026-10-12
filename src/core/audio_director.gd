extends Node
## Audio (autoload « Audio ») : musiques par contexte (fondu enchaîné), effets sonores par événement,
## et signal de tempo (beat) calculé à partir du BPM déclaré dans le manifeste.
## Formats acceptés : MP3, OGG, WAV. Un fichier absent est ignoré silencieusement (le jeu reste jouable).

signal beat(index: int)

const MANIFEST_PATH := "res://assets/audio/audio_manifest.json"
## Dossiers scannés automatiquement : chaque fichier audio déposé est joué dans le contexte du dossier.
## Le BPM peut être indiqué dans le nom du fichier (ex. « assaut_165bpm.mp3 »).
const MUSIC_FOLDERS := {
	"res://assets/audio/music/menu": ["menu", "refuge"],
	"res://assets/audio/music/refuge": ["refuge"],
	"res://assets/audio/music/run": ["run"],
	"res://assets/audio/music/boss": ["boss", "boss_phase2"],
	"res://assets/audio/music/boss_phase2": ["boss_phase2"],
	"res://assets/audio/music/victory": ["victory"],
	"res://assets/audio/music/defeat": ["defeat"],
}
const AUDIO_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]
const FADE_TIME := 1.2
const SFX_VOICES := 16

var music_tracks: Dictionary = {}
var sfx_events: Dictionary = {}
var current_context: String = ""
var current_track_id: String = ""
var current_bpm: float = 0.0
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _fade: float = 0.0
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _sfx_last_time: Dictionary = {}
var _stream_cache: Dictionary = {}
var _last_beat: int = -1
var _rng := RandomNumberGenerator.new()
var _available_sfx: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	for i: int in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		_sfx_players.append(voice)
	load_manifest()
	_rng.randomize()


func load_manifest() -> void:
	var res: Resource = load(MANIFEST_PATH) if ResourceLoader.exists(MANIFEST_PATH) else null
	var data: Variant = (res as JSON).data if res is JSON else {}
	if data is Dictionary:
		music_tracks = data.get("music", {})
		sfx_events = data.get("sfx", {})
	music_tracks.merge(scan_music_folders(), false)
	_available_sfx.clear()
	for event_id: String in sfx_events:
		var files: Array = (sfx_events[event_id] as Dictionary).get("files", [])
		var present: Array = files.filter(func(p: Variant) -> bool: return ResourceLoader.exists(str(p)))
		if not present.is_empty():
			_available_sfx[StringName(event_id)] = present


## Découvre les musiques déposées dans les dossiers de MUSIC_FOLDERS (gère les fichiers importés des exports).
static func scan_music_folders() -> Dictionary:
	var found: Dictionary = {}
	var bpm_regex := RegEx.create_from_string("(\\d{2,3})\\s*bpm")
	for folder: String in MUSIC_FOLDERS:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		var files: PackedStringArray = dir.get_files()
		files.sort()
		for file_name: String in files:
			var clean: String = file_name.trim_suffix(".remap").trim_suffix(".import")
			if not AUDIO_EXTENSIONS.has(clean.get_extension().to_lower()):
				continue
			var path: String = folder.path_join(clean)
			var id: String = folder.get_file() + "/" + clean.get_basename()
			if found.has(id):
				continue
			var bpm_match: RegExMatch = bpm_regex.search(clean.to_lower())
			found[id] = {"path": path, "bpm": int(bpm_match.get_string(1)) if bpm_match else 0,
				"contexts": MUSIC_FOLDERS[folder], "loop": not (folder.ends_with("victory") or folder.ends_with("defeat"))}
	return found


static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


## Morceaux disponibles (fichier présent) pour un contexte : menu, refuge, run, boss, boss_phase2, victory, defeat.
func tracks_for(context: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in music_tracks:
		var track: Dictionary = music_tracks[id]
		if (track.get("contexts", []) as Array).has(context) and ResourceLoader.exists(str(track.get("path", ""))):
			ids.append(id)
	ids.sort()
	return ids


func play_context(context: String) -> void:
	if context == current_context:
		return
	current_context = context
	var ids: Array[String] = tracks_for(context)
	if ids.is_empty():
		_fade_out_all()
		return
	var id: String = ids[_rng.randi() % ids.size()]
	if id == current_track_id and _players[_active].playing:
		return
	_play_track(id)


func _play_track(id: String) -> void:
	var track: Dictionary = music_tracks[id]
	var stream: AudioStream = _load_stream(str(track["path"]), bool(track.get("loop", true)))
	if stream == null:
		return
	current_track_id = id
	current_bpm = float(track.get("bpm", 0.0))
	_last_beat = -1
	_active = 1 - _active
	var player: AudioStreamPlayer = _players[_active]
	player.stream = stream
	player.volume_db = -40.0
	player.play()
	_fade = FADE_TIME


func _fade_out_all() -> void:
	current_track_id = ""
	current_bpm = 0.0
	_active = 1 - _active
	_players[_active].stop()
	_fade = FADE_TIME


func _load_stream(path: String, loop: bool) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV and loop:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_stream_cache[path] = stream
	return stream


## Joue l'effet associé à un événement (s'il existe), avec variation de hauteur et limitation de fréquence.
func play_sfx(event_id: StringName, volume_offset_db: float = 0.0) -> void:
	if not _available_sfx.has(event_id):
		return
	var event: Dictionary = sfx_events.get(String(event_id), {})
	var now: float = Time.get_ticks_msec() / 1000.0
	var min_gap: float = float(event.get("min_interval", 0.05))
	if now - float(_sfx_last_time.get(event_id, -10.0)) < min_gap:
		return
	var available: Array = _available_sfx[event_id]
	_sfx_last_time[event_id] = now
	var stream: AudioStream = _load_stream(str(available[_rng.randi() % available.size()]), false)
	var voice: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	voice.stream = stream
	voice.volume_db = float(event.get("volume_db", 0.0)) + volume_offset_db
	var variance: float = float(event.get("pitch_variance", 0.05))
	voice.pitch_scale = 1.0 + _rng.randf_range(-variance, variance)
	voice.play()


func _process(delta: float) -> void:
	if _fade > 0.0:
		_fade = maxf(_fade - delta, 0.0)
		var t: float = 1.0 - _fade / FADE_TIME
		_players[_active].volume_db = linear_to_db(maxf(t, 0.0001))
		var other: AudioStreamPlayer = _players[1 - _active]
		other.volume_db = linear_to_db(maxf(1.0 - t, 0.0001))
		if _fade <= 0.0:
			other.stop()
	var player: AudioStreamPlayer = _players[_active]
	if current_bpm > 0.0 and player.playing:
		var position: float = player.get_playback_position() + AudioServer.get_time_since_last_mix()
		var index: int = int(position * current_bpm / 60.0)
		if index != _last_beat:
			_last_beat = index
			beat.emit(index)
