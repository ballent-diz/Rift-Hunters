class_name RiftArt
extends RefCounted
## Vocabulaire visuel violet/indigo commun aux failles, indépendant des règles du niveau.

const VIOLET := Color(0.48, 0.32, 1.0)
const LIGHT := Color(0.78, 0.78, 1.0)


static func ground(canvas: CanvasItem, center: Vector2, radius: float, clock: float, alpha: float = 1.0) -> void:
	# Fissures courtes et irrégulières ; aucun cercle ni disque au sol.
	for i: int in 5:
		var angle: float = i * 2.399 + 0.12 * sin(clock * 1.7 + i)
		var direction := Vector2(cos(angle), sin(angle) * 0.42)
		var side: Vector2 = direction.orthogonal() * 7.0
		var points := PackedVector2Array([center, center + direction * radius * 0.23 + side,
			center + direction * radius * 0.44 - side * 0.5, center + direction * radius * 0.65])
		canvas.draw_polyline(points, Color(VIOLET, 0.22 * alpha), 4.0, true)
		canvas.draw_polyline(points, Color(LIGHT, 0.42 * alpha), 1.0, true)


static func portal(canvas: CanvasItem, foot: Vector2, height: float, clock: float, alpha: float = 1.0) -> void:
	var frames: SpriteFrames = Assets.get_sprite_frames(&"enemy.rift_breach")
	if frames == null:
		return
	var index: int = int(clock * 10.0) % frames.get_frame_count(&"idle")
	var texture: Texture2D = frames.get_frame_texture(&"idle", index)
	var factor: float = height / 128.0
	var size: Vector2 = texture.get_size() * factor
	var anchor: Vector2 = Assets.anchor(&"enemy.rift_breach") * factor
	canvas.draw_texture_rect(texture, Rect2(foot - anchor, size), false, Color(1.0, 1.0, 1.0, alpha))
