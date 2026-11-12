class_name DraftEffect
extends Sprite3D
## Lecture des feuilles PixelFX existantes dans le monde 3D (trait, impact), reprise du prototype KayKit.

var art: Dictionary
var loop: bool = false
var _frames: Array = []
var _clock: float = 0.0


func _ready() -> void:
	texture = load(str(art["sheet"]))
	_frames = art["frames"]
	region_enabled = true
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_show(0)


func _process(delta: float) -> void:
	_clock += delta
	var frame: int = int(_clock * float(art["fps"]))
	if frame >= _frames.size() and not loop:
		queue_free()
		return
	_show(frame % _frames.size())


func _show(index: int) -> void:
	var rect: Dictionary = _frames[index]
	region_rect = Rect2(float(rect["x"]), float(rect["y"]), float(rect["w"]), float(rect["h"]))
