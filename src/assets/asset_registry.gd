extends Node
## Registre d'assets (autoload « Assets »). Lit assets/asset_manifest.json.
## Si la feuille de sprites d'un identifiant n'existe pas, on utilise un placeholder généré.

const MANIFEST_PATH := "res://assets/asset_manifest.json"

var manifest: Dictionary = {}
var _frames_cache: Dictionary = {}
var _placeholder_cache: Dictionary = {}


func _ready() -> void:
	load_manifest()


func load_manifest() -> void:
	manifest = {}
	var res: Resource = load(MANIFEST_PATH) if ResourceLoader.exists(MANIFEST_PATH) else null
	var data: Variant = (res as JSON).data if res is JSON else null
	if data is Dictionary and (data as Dictionary).get("entries") is Dictionary:
		manifest = data["entries"]
	else:
		push_warning("Manifeste d'assets absent ou invalide : placeholders partout.")
	_frames_cache.clear()


func entry(visual_id: StringName) -> Dictionary:
	return manifest.get(String(visual_id), {})


## Vrai si une feuille de sprites utilisable existe pour cet identifiant.
func has_sheet(visual_id: StringName) -> bool:
	var e: Dictionary = entry(visual_id)
	if e.is_empty() or str(e.get("status", "planned")) == "planned":
		return false
	return ResourceLoader.exists(str(e.get("sheet", "")))


func get_sprite_frames(visual_id: StringName) -> SpriteFrames:
	if _frames_cache.has(visual_id):
		return _frames_cache[visual_id]
	var frames: SpriteFrames = null
	if has_sheet(visual_id):
		frames = build_frames(entry(visual_id))
	_frames_cache[visual_id] = frames
	return frames


static func build_frames(e: Dictionary) -> SpriteFrames:
	var texture: Texture2D = load(str(e["sheet"]))
	if texture == null:
		return null
	var cell: Array = e.get("cell", [64, 64])
	var cell_size := Vector2(float(cell[0]), float(cell[1]))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var animations: Dictionary = e.get("animations", {})
	for anim_name: String in animations:
		var anim: Dictionary = animations[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(anim.get("fps", 10)))
		frames.set_animation_loop(anim_name, bool(anim.get("loop", true)))
		var row: int = int(anim.get("row", 0))
		for i: int in int(anim.get("frames", 1)):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(i, row) * cell_size, cell_size)
			frames.add_frame(anim_name, atlas)
	return frames


func anchor(visual_id: StringName) -> Vector2:
	var e: Dictionary = entry(visual_id)
	var a: Array = e.get("anchor", [])
	if a.size() == 2:
		return Vector2(float(a[0]), float(a[1]))
	var cell: Array = e.get("cell", [64, 64])
	return Vector2(float(cell[0]), float(cell[1])) * 0.5


## Unités du monde par pixel d'art (1 par défaut ; voir docs/ART_BIBLE.md).
func pixel_scale(visual_id: StringName) -> float:
	return float(entry(visual_id).get("scale", 1.0))


## Retourne [Texture2D, échelle].
func placeholder(visual: VisualData, primary: Color = Color(0, 0, 0, 0), secondary: Color = Color(0, 0, 0, 0)) -> Array:
	var pri: Color = visual.primary if primary.a == 0.0 else primary
	var sec: Color = visual.secondary if secondary.a == 0.0 else secondary
	var key: String = "%d|%.1f|%s|%s|%s" % [visual.shape, visual.size, pri.to_html(), sec.to_html(), visual.accent.to_html()]
	if not _placeholder_cache.has(key):
		_placeholder_cache[key] = PlaceholderFactory.make(visual, pri, sec)
	return _placeholder_cache[key]


func icon(visual_id: StringName) -> Texture2D:
	var path: String = str(entry(visual_id).get("icon", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null
