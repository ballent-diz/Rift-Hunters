class_name DraftPixelFx
extends Sprite3D
## Effets PixelFX de la campagne (assets/vfx/pixelfx/<effet>/<famille>.png + .json) joués dans le monde 3D.
## Même catalogue que le jeu 2D (techniques.json : effet de tir et d'impact par famille de monstres) ; les feuilles
## sont lues telles quelles, dans la palette de la famille. Un effet absent pour une famille n'affiche rien.

const ROOT := "res://assets/vfx/pixelfx/%s/%s"
const CATALOG := "res://assets/vfx/pixelfx/techniques.json"
const DEFAULT_FAMILY := &"violet"
## Mètres par pixel d'effet.
const PIXEL := 0.03
## Zone qui tombe du ciel (pluie du boss) : un effet par famille.
const RAIN := {&"violet": &"star_fall", &"highlands": &"lightning_strike", &"calcines": &"flame_pillar",
	&"magma": &"meteor", &"enlises": &"geyser", &"reflets": &"ice_shatter", &"givres": &"icicle_fall",
	&"silence": &"ice_spikes", &"fallen": &"dark_explosion", &"riftborn": &"dark_explosion"}

static var _sheets: Dictionary = {}
static var _catalog: Dictionary = {}

var loop: bool = false
var _sheet: Dictionary = {}
var _clock: float = 0.0


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return _catalog


static func enemy_family(data: EnemyData) -> StringName:
	return data.family if data != null and data.family != &"" else DEFAULT_FAMILY


static func boss_family(data: BossData) -> StringName:
	return StringName(str((catalog().get("boss_families", {}) as Dictionary).get(String(data.id), DEFAULT_FAMILY)))


## Effet de vol (`flights`) ou d'impact (`shots`) des tirs d'une famille.
static func shot_effect(table: String, family: StringName) -> StringName:
	return StringName(str((catalog().get(table, {}) as Dictionary).get(String(family), "mana_burst")))


static func sheet(effect: StringName, family: StringName) -> Dictionary:
	var key: String = "%s/%s" % [effect, family]
	if _sheets.has(key):
		return _sheets[key]
	var result: Dictionary = {}
	var base: String = ROOT % [effect, family]
	if ResourceLoader.exists(base + ".png") and FileAccess.file_exists(base + ".json"):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		if data is Dictionary:
			var rects: Array[Rect2] = []
			var frames: Variant = data["frames"]
			for frame: Variant in (frames if frames is Array else (frames as Dictionary).values()):
				var r: Dictionary = frame["frame"]
				rects.append(Rect2(r["x"], r["y"], r["w"], r["h"]))
			var meta: Dictionary = data["meta"]["pixelfx"]
			result = {"texture": load(base + ".png"), "rects": rects, "fps": float(meta["fps"])}
	_sheets[key] = result
	return result


## Joue l'effet à `at` (null si la feuille n'existe pas pour cette famille, après repli sur la famille par défaut).
static func play(parent: Node, effect: StringName, family: StringName, at: Vector3, size: float = 1.0,
		looping: bool = false) -> DraftPixelFx:
	var data: Dictionary = sheet(effect, family)
	if data.is_empty():
		data = sheet(effect, DEFAULT_FAMILY)
	if data.is_empty():
		return null
	var node := DraftPixelFx.new()
	node._sheet = data
	node.loop = looping
	node.texture = data["texture"]
	node.region_enabled = true
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.shaded = false
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.pixel_size = PIXEL * size
	node.position = at
	node.region_rect = (data["rects"] as Array[Rect2])[0]
	parent.add_child(node)
	return node


func _process(delta: float) -> void:
	_clock += delta
	var rects: Array[Rect2] = _sheet["rects"]
	var frame: int = int(_clock * float(_sheet["fps"]))
	if frame >= rects.size() and not loop:
		queue_free()
		return
	region_rect = rects[frame % rects.size()]
