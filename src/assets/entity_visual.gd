class_name EntityVisual
extends Node2D
## Affichage d'une entité : sprite animé si l'asset existe, sinon placeholder animé par le code.

var bob_amount: float = 0.06
var bob_speed: float = 9.0
var _sprite: Sprite2D
var _anim: AnimatedSprite2D
var _flash: float = 0.0
var _phase: float = 0.0
var _base_scale := Vector2.ONE
var _tint := Color.WHITE


func setup(visual: VisualData, primary: Color = Color(0, 0, 0, 0), secondary: Color = Color(0, 0, 0, 0)) -> void:
	for child: Node in get_children():
		child.queue_free()
	_sprite = null
	_anim = null
	_phase = randf() * TAU
	var frames: SpriteFrames = Assets.get_sprite_frames(visual.visual_id)
	if frames:
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = frames
		_anim.centered = false
		_anim.offset = -Assets.anchor(visual.visual_id)
		add_child(_anim)
		play(&"idle")
		_base_scale = Vector2.ONE
	else:
		var result: Array = Assets.placeholder(visual, primary, secondary)
		_sprite = Sprite2D.new()
		_sprite.texture = result[0]
		add_child(_sprite)
		_base_scale = Vector2.ONE * float(result[1])
		_sprite.scale = _base_scale


func play(anim: StringName) -> void:
	if _anim and _anim.sprite_frames.has_animation(anim) and _anim.animation != anim:
		_anim.play(anim)


func set_facing_left(left: bool) -> void:
	if _sprite:
		_sprite.flip_h = left
	elif _anim:
		_anim.flip_h = left


func set_tint(color: Color) -> void:
	_tint = color
	_apply_modulate()


func flash() -> void:
	_flash = 0.12


## Appelé par le manager chaque frame (pas de _process par entité).
func tick(delta: float, moving: bool) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_apply_modulate()
	if _sprite:
		_phase += delta * (bob_speed if moving else bob_speed * 0.4)
		var squash: float = sin(_phase) * (bob_amount if moving else bob_amount * 0.4)
		_sprite.scale = Vector2(_base_scale.x * (1.0 + squash), _base_scale.y * (1.0 - squash))
	elif _anim:
		play(&"move" if moving else &"idle")


func _apply_modulate() -> void:
	var node: CanvasItem = _sprite if _sprite else _anim
	if node == null:
		return
	if _flash > 0.0:
		node.modulate = Color(2.2, 2.2, 2.2, _tint.a)
	else:
		node.modulate = _tint
