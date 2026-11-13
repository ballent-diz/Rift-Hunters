extends Sprite3D
## Lecture des feuilles PixelFX existantes, sans redessiner un effet de remplacement.

var art: Dictionary
var frames: Array
var clock := 0.0
var loop := false

func _ready() -> void:
	texture = load(art.sheet)
	frames = art.frames
	region_enabled = true
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	pixel_size = 0.024
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	show_frame(0)

func _process(delta: float) -> void:
	clock += delta
	var frame := int(clock * float(art.fps))
	if frame >= frames.size() and not loop:
		queue_free()
		return
	show_frame(frame % frames.size())

func show_frame(index: int) -> void:
	var rect: Dictionary = frames[index]
	region_rect = Rect2(rect.x, rect.y, rect.w, rect.h)
