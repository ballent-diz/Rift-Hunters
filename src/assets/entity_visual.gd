class_name EntityVisual
extends Node2D
## Affichage d'une entité : sprite animé si l'asset existe, sinon placeholder animé par le code.

var bob_amount: float = 0.06
var bob_speed: float = 9.0
## Rayon de l'ombre au sol (0 = pas d'ombre).
var shadow_radius: float = 0.0
var _sprite: Sprite2D
var _anim: AnimatedSprite2D
var _action: StringName = &""
var _moving: bool = false
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
	shadow_radius = visual.size * 0.36
	_add_shadow()
	var frames: SpriteFrames = Assets.get_sprite_frames(visual.visual_id)
	if frames:
		# Pixel art : filtrage net, 1 pixel d'art = scale unité(s) du monde.
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = frames
		_anim.centered = false
		_anim.offset = -Assets.anchor(visual.visual_id)
		_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_anim.scale = Vector2.ONE * Assets.pixel_scale(visual.visual_id)
		_anim.animation_finished.connect(_on_action_finished)
		add_child(_anim)
		play(&"idle")
		_base_scale = Vector2.ONE
		if primary.a > 0.0:
			# Palette de maîtrise sur un sprite final : teinte approchée (feuille dédiée à prévoir).
			set_tint(primary.lightened(0.45))
	else:
		var result: Array = Assets.placeholder(visual, primary, secondary)
		_sprite = Sprite2D.new()
		_sprite.texture = result[0]
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_sprite)
		_base_scale = Vector2.ONE * float(result[1])
		_sprite.scale = _base_scale


func has_sheet() -> bool:
	return _anim != null


func play(anim: StringName) -> void:
	if _anim and _anim.sprite_frames.has_animation(anim) and _anim.animation != anim:
		_anim.play(anim)


## Animation ponctuelle (attaque, Technique) ; retour automatique au repos ou à la course ensuite.
func play_action(anim: StringName) -> void:
	if _anim and _anim.sprite_frames.has_animation(anim):
		_action = anim
		_anim.play(anim)
		_anim.frame = 0


func _on_action_finished() -> void:
	if _action == &"death":
		return  # reste sur la dernière image (corps au sol)
	_action = &""
	play(&"move" if _moving else &"idle")


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
		_moving = moving
		if _action == &"":
			play(&"move" if moving else &"idle")


func _apply_modulate() -> void:
	var node: CanvasItem = _sprite if _sprite else _anim
	if node == null:
		return
	if _flash > 0.0:
		node.modulate = Color(2.2, 2.2, 2.2, _tint.a)
	else:
		node.modulate = _tint


## Ombre au sol dans un nœud placé sous toutes les entités de la même couche (z relatif −1), dessinée une fois.
func _add_shadow() -> void:
	var shadow := Node2D.new()
	shadow.z_index = -1
	var radius: float = shadow_radius
	shadow.draw.connect(func() -> void:
		shadow.draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.38))
		shadow.draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.03, 0.35)))
	add_child(shadow)
