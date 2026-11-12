class_name DraftSpriteView
extends Node3D
## Sprite 2D d'origine affiché dans le monde 3D (premier jet, docs/PREMIER_JET_3D.md).
## Reprend les corrections de fluidité du prototype KayKit : image interpolée entre deux pas physiques, orientation
## gauche/droite confirmée, cycle de marche lié à la distance réellement parcourue.
## Le nœud est `top_level` : son propriétaire lui donne les positions physiques avec `push_position`.

## Mètres par pixel d'art pour une échelle de manifeste de 1 (même valeur que le prototype).
const PIXEL := 0.037
const TURN_CONFIRM_TIME := 0.12

var sprite: Sprite3D
var entry: Dictionary = {}
var animation: StringName = &"idle"
## Vitesse de référence du cycle de marche (m/s) : une boucle de `move` par seconde de marche à cette vitesse.
var walk_speed: float = 5.0
var facing_changes: int = 0
var _time: float = 0.0
var _walk_phase: float = 0.0
var _idle_time: float = 0.0
var _previous := Vector3.ZERO
var _current := Vector3.ZERO
var _turn_candidate: bool = false
var _turn_time: float = 0.0
var _action: StringName = &""
var _action_left: float = 0.0
var _flash: float = 0.0
var _tint := Color.WHITE


func setup(visual_id: StringName, size_mult: float = 1.0) -> void:
	top_level = true
	entry = Assets.entry(visual_id)
	sprite = Sprite3D.new()
	sprite.texture = load(str(entry["sheet"]))
	var cell: Array = entry["cell"]
	var anchor: Array = entry["anchor"]
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, float(cell[0]), float(cell[1]))
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	sprite.pixel_size = PIXEL * float(entry.get("scale", 1.0)) * size_mult
	sprite.offset = Vector2(float(cell[0]) * 0.5 - float(anchor[0]), 0)
	sprite.position.y = (float(anchor[1]) - float(cell[1]) * 0.5) * sprite.pixel_size + 0.04
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(sprite)
	if not has_clip(animation):
		animation = &"move"


func has_clip(id: StringName) -> bool:
	return (entry.get("animations", {}) as Dictionary).has(String(id))


func clip(id: StringName) -> Dictionary:
	var clips: Dictionary = entry.get("animations", {})
	return clips.get(String(id), clips.get("move", clips.get("idle", {})))


## Téléportation ou apparition : aucune traînée entre l'ancienne et la nouvelle position.
func snap_to(pos: Vector3) -> void:
	_previous = pos
	_current = pos
	global_position = pos


## Nouveau pas physique : l'image glissera de l'ancienne position vers celle-ci.
func push_position(pos: Vector3, delta: float, turn: bool = true) -> void:
	_previous = _current
	_current = pos
	var travel: Vector3 = _current - _previous
	travel.y = 0.0
	if delta <= 0.0:
		return
	if turn:
		_update_facing(travel / delta, delta)
	_update_animation(travel.length(), delta)


func render_position() -> Vector3:
	return _previous.lerp(_current, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))


## Animation ponctuelle (attaque, esquive, technique) jouée une fois par-dessus la marche.
func play_action(id: StringName, duration: float = -1.0) -> void:
	if not has_clip(id):
		return
	var c: Dictionary = clip(id)
	_action = id
	_action_left = duration if duration > 0.0 else float(c["frames"]) / maxf(float(c["fps"]), 1.0)
	animation = id
	_time = 0.0


func flash(seconds: float = 0.12) -> void:
	_flash = seconds


func set_tint(color: Color) -> void:
	_tint = color


func face_left(left: bool) -> void:
	sprite.flip_h = left
	_turn_time = 0.0


func _process(delta: float) -> void:
	global_position = render_position()
	_flash = maxf(_flash - delta, 0.0)
	sprite.modulate = Color(2.2, 1.4, 1.4) if _flash > 0.0 else _tint
	var c: Dictionary = clip(animation)
	if c.is_empty():
		return
	var phase: float = _walk_phase if animation == &"move" else _time * float(c["fps"])
	var frame: int = int(phase)
	if bool(c.get("loop", true)) and _action == &"":
		frame %= int(c["frames"])
	else:
		frame = mini(frame, int(c["frames"]) - 1)
	var cell: Array = entry["cell"]
	sprite.region_rect.position = Vector2(frame * int(cell[0]), int(c["row"]) * int(cell[1]))


func _update_facing(velocity: Vector3, delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var horizontal: float = velocity.x if camera == null else velocity.dot(camera.global_basis.x)
	# Trajet presque vertical ou petite correction : l'orientation est gardée.
	if absf(horizontal) < 0.5 or absf(horizontal) < velocity.length() * 0.22:
		_turn_time = 0.0
		return
	var flipped: bool = horizontal < 0.0
	if flipped == sprite.flip_h:
		_turn_time = 0.0
	elif flipped != _turn_candidate:
		_turn_candidate = flipped
		_turn_time = delta
	else:
		_turn_time += delta
	if _turn_time >= TURN_CONFIRM_TIME:
		sprite.flip_h = flipped
		facing_changes += 1
		_turn_time = 0.0


func _update_animation(distance: float, delta: float) -> void:
	_time += delta
	if _action != &"":
		_action_left -= delta
		if _action_left > 0.0:
			return
		_action = &""
	var speed: float = distance / delta
	_idle_time = _idle_time + delta if speed < 0.15 else 0.0
	var moving: bool = speed > 0.3 or (animation == &"move" and _idle_time < 0.1)
	var next: StringName = &"move" if moving or not has_clip(&"idle") else &"idle"
	if next != animation:
		animation = next
		_time = 0.0
	if next == &"move":
		var c: Dictionary = clip(&"move")
		# Le cycle avance avec le terrain parcouru : aucun piétinement contre un obstacle.
		_walk_phase = fmod(_walk_phase + distance * float(c["fps"]) / maxf(walk_speed, 0.1), float(c["frames"]))
