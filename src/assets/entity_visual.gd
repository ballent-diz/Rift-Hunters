class_name EntityVisual
extends Node2D
## Affichage d'une entité : sprite animé si l'asset existe, sinon placeholder animé par le code.

const FLIP_HOLD := 0.22
const FACING_MIN_SPEED := 14.0

var bob_amount: float = 0.06
var bob_speed: float = 9.0
## Rayon de l'ombre au sol (0 = pas d'ombre).
var shadow_radius: float = 0.0
## Animation de repos (un boss passe à « phase2_idle » après sa transformation).
var idle_animation: StringName = &"idle"
var _sprite: Sprite2D
var _anim: AnimatedSprite2D
var _action: StringName = &""
var _moving: bool = false
var _flash: float = 0.0
var _phase: float = 0.0
var _base_scale := Vector2.ONE
var _tint := Color.WHITE
## Caches : on n'écrit dans le sprite que ce qui change (appelé chaque frame pour des centaines d'ennemis).
var _current: StringName = &""
var _facing_left: bool = false
## Anti-scintillement : après un retournement, le sprite garde son sens un court instant (FLIP_HOLD).
var _flip_hold: float = 0.0
## Marche (feuille animée) : distance parcourue par cycle de l'animation « move » (unités du monde) ; l'animation
## suit la vitesse réelle pour que les pattes « accrochent » le sol.
var _stride: float = 0.0
var _move_cycle: float = 1.0
## Balancement de pas : hauteur du petit rebond (unités du monde) et bascule (radians), 2 pas par cycle.
var _step_bob: float = 0.0
var _step_rock: float = 0.0


func setup(visual: VisualData, primary: Color = Color(0, 0, 0, 0), secondary: Color = Color(0, 0, 0, 0)) -> void:
	for child: Node in get_children():
		child.queue_free()
	_sprite = null
	_anim = null
	_current = &""
	_facing_left = false
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
		var shader_path: String = str(Assets.entry(visual.visual_id).get("shader", ""))
		if shader_path != "" and ResourceLoader.exists(shader_path):
			var effect := ShaderMaterial.new()
			effect.shader = load(shader_path) as Shader
			_anim.material = effect
		_anim.animation_finished.connect(_on_action_finished)
		add_child(_anim)
		_setup_gait(visual.visual_id, frames)
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


func _setup_gait(visual_id: StringName, frames: SpriteFrames) -> void:
	var e: Dictionary = Assets.entry(visual_id)
	var height: float = Assets.anchor(visual_id).y * Assets.pixel_scale(visual_id)
	_stride = float(e.get("stride", height * 2.0))
	if frames.has_animation(&"move"):
		_move_cycle = frames.get_frame_count(&"move") / maxf(frames.get_animation_speed(&"move"), 0.1)
	# Joueur et boss ont un vrai cycle de marche dessiné : pas de balancement ajouté par défaut.
	var creature: bool = not (String(visual_id).begins_with("player.") or String(visual_id).begins_with("boss."))
	_step_bob = float(e.get("step_bob", 1.5 if creature else 0.0))
	_step_rock = float(e.get("step_rock", 0.05 if creature else 0.0))


func has_sheet() -> bool:
	return _anim != null


func sprite_frames() -> SpriteFrames:
	return _anim.sprite_frames if _anim else null


func has_animation(anim: StringName) -> bool:
	return _anim != null and _anim.sprite_frames.has_animation(anim)


func play(anim: StringName) -> void:
	if _current == anim or _anim == null or not _anim.sprite_frames.has_animation(anim):
		return
	_current = anim
	_anim.play(anim)


## Animation ponctuelle (attaque, Technique) ; retour automatique au repos ou à la course ensuite.
func play_action(anim: StringName) -> void:
	if _anim and _anim.sprite_frames.has_animation(anim):
		_action = anim
		_current = anim
		_anim.speed_scale = 1.0
		_anim.play(anim)
		_anim.frame = 0


func _on_action_finished() -> void:
	if _action == &"death":
		return  # reste sur la dernière image (corps au sol)
	_action = &""
	play(&"move" if _moving else idle_animation)


## Sens d'après la vitesse horizontale : ignoré sous FACING_MIN_SPEED (déplacement presque vertical, petits
## ajustements autour du Chasseur), sinon le sprite se retournerait à chaque image.
func face_velocity(vx: float) -> void:
	if absf(vx) >= FACING_MIN_SPEED:
		set_facing_left(vx < 0.0)


## `force` : retournement immédiat (Chasseur piloté par le joueur).
func set_facing_left(left: bool, force: bool = false) -> void:
	if left == _facing_left or (_flip_hold > 0.0 and not force):
		return
	_facing_left = left
	_flip_hold = FLIP_HOLD
	if _sprite:
		_sprite.flip_h = left
	elif _anim:
		_anim.flip_h = left


func tint() -> Color:
	return _tint


func set_tint(color: Color) -> void:
	_tint = color
	_apply_modulate()


func flash() -> void:
	_flash = 0.12


## Appelé par le manager chaque frame (pas de _process par entité). `speed` : vitesse réelle (unités/s),
## négative si inconnue (animation à sa cadence nominale).
func tick(delta: float, moving: bool, speed: float = -1.0) -> void:
	_flip_hold = maxf(_flip_hold - delta, 0.0)
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
			play(&"move" if moving else idle_animation)
		_gait(delta, moving and _action == &"", speed)


func _gait(delta: float, walking: bool, speed: float) -> void:
	if not walking:
		_anim.position = _anim.position.lerp(Vector2.ZERO, minf(delta * 12.0, 1.0))
		_anim.rotation = lerpf(_anim.rotation, 0.0, minf(delta * 12.0, 1.0))
		if _action == &"":
			_anim.speed_scale = 1.0
		return
	# Cycles par seconde : vitesse / foulée (cadence nominale si la vitesse est inconnue).
	var cycles: float = speed / _stride if speed >= 0.0 and _stride > 0.0 else 1.0 / _move_cycle
	var scale_value: float = clampf(cycles * _move_cycle, 0.5, 2.2)
	if absf(_anim.speed_scale - scale_value) > 0.05:
		_anim.speed_scale = scale_value
	_phase = fmod(_phase + delta * cycles * TAU, TAU * 8.0)
	# Deux pas par cycle : rebond à chaque pas, bascule gauche/droite d'un pas à l'autre.
	var step: float = sin(_phase * 2.0)
	if _step_bob > 0.0 or _step_rock > 0.0:
		_anim.position = Vector2(0.0, -absf(step) * _step_bob)
		_anim.rotation = sin(_phase) * _step_rock * (-1.0 if _facing_left else 1.0)


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
