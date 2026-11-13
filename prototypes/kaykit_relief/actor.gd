extends CharacterBody3D
## Contrôleur de laboratoire uniquement. Aucun branchement sur la simulation 2D de campagne.

const SPEED := 5.2
const GRAVITY := 22.0
const PLAYER_ACCELERATION := 75.0
const PLAYER_BRAKING := 95.0
const FOLLOW_ACCELERATION := 24.0
const FOLLOW_BRAKING := 30.0
const TURN_CONFIRM_TIME := 0.12
const PATH_REFRESH_TIME := 0.25
const PATH_TARGET_DISTANCE := 0.8
var role := "hunter"
var art: Dictionary
var sprite: Sprite3D
var nav: NavigationAgent3D
var follow_target: Node3D
var visual_root: Node3D
var attack_time := 0.0
var dash_time := 0.0
var dash_cooldown := 0.0
var fire_cooldown := 0.0
var hp := 4
var active := true
var auto_direction := Vector3.ZERO
var automating := false
var tint_time := 0.0
var animation_name := "idle"
var facing_changes := 0
var _animation_time := 0.0
var _walk_phase := 0.0
var _idle_time := 0.0
var _previous_position := Vector3.ZERO
var _current_position := Vector3.ZERO
var _dash_direction := Vector3.ZERO
var _turn_candidate := false
var _turn_time := 0.0
var _following := false
var _path_elapsed := PATH_REFRESH_TIME
var _path_target := Vector3.ZERO
var _has_path_target := false
var _follow_speed := 0.0

func _ready() -> void:
	collision_layer = 2 if role == "enemy" else 4
	collision_mask = 1
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(48)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28 if role != "enemy" else 0.38
	capsule.height = 1.55 if role == "hunter" else 1.15
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = capsule.height / 2.0
	add_child(collision)
	# L'image est interpolée entre les positions physiques, sans arrondir ses coordonnées aux pixels.
	# Le corps reste à sa position exacte : collisions, tirs et navigation ne sont pas lissés visuellement.
	visual_root = Node3D.new()
	visual_root.top_level = true
	add_child(visual_root)
	sprite = Sprite3D.new()
	sprite.texture = load(art.sheet)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, Vector2(art.cell[0], art.cell[1]))
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	sprite.pixel_size = 0.037 * float(art.scale)
	sprite.offset = Vector2(float(art.cell[0]) * 0.5 - float(art.anchor[0]), 0)
	sprite.position.y = (float(art.anchor[1]) - float(art.cell[1]) * 0.5) * sprite.pixel_size + 0.04
	visual_root.add_child(sprite)
	# L'ombre est une vraie projection 3D du sprite découpé sur le sol.
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if role != "hunter":
		nav = NavigationAgent3D.new()
		nav.path_desired_distance = 0.5
		nav.target_desired_distance = 0.8
		nav.simplify_path = true
		nav.simplify_epsilon = 0.08
		nav.radius = 0.35
		add_child(nav)
	add_to_group("actors")
	if role == "enemy":
		add_to_group("enemies")
	reset_motion()

func reset_motion() -> void:
	velocity = Vector3.ZERO
	_previous_position = global_position
	_current_position = global_position
	visual_root.global_position = global_position
	_following = false
	_has_path_target = false
	_path_elapsed = PATH_REFRESH_TIME
	_turn_time = 0.0

func render_position() -> Vector3:
	var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	return _previous_position.lerp(_current_position, fraction)

func _process(_delta: float) -> void:
	visual_root.global_position = render_position()
	var clip: Dictionary = animation_clip(animation_name)
	var phase := _walk_phase if animation_name == "move" else _animation_time * float(clip.fps)
	var frame := int(phase)
	if bool(clip.get("loop", true)):
		frame %= int(clip.frames)
	else:
		frame = mini(frame, int(clip.frames) - 1)
	sprite.region_rect.position = Vector2(frame * int(art.cell[0]), int(clip.row) * int(art.cell[1]))

func _physics_process(delta: float) -> void:
	# Une téléportation (recommencer, vérificateur) ne doit pas dessiner un trajet entre les deux lieux.
	if global_position.distance_squared_to(_current_position) > 0.000001:
		reset_motion()
	_previous_position = _current_position
	attack_time = maxf(0, attack_time - delta)
	dash_time = maxf(0, dash_time - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	fire_cooldown = maxf(0, fire_cooldown - delta)
	tint_time = maxf(0, tint_time - delta)
	sprite.modulate = Color(2.0, 0.75, 0.8) if tint_time > 0 else Color.WHITE
	if not active:
		velocity = Vector3.ZERO
		_current_position = global_position
		return
	var direction := Vector3.ZERO
	if role == "hunter":
		if automating:
			direction = auto_direction.normalized()
		else:
			var x := float(key_down([KEY_D, KEY_RIGHT])) - float(key_down([KEY_A, KEY_Q, KEY_LEFT]))
			var z := float(key_down([KEY_S, KEY_DOWN])) - float(key_down([KEY_W, KEY_Z, KEY_UP]))
			direction = Vector3(x, 0, z).normalized()
			if Input.is_physical_key_pressed(KEY_SPACE) and dash_cooldown <= 0 and direction.length() > 0:
				dash_time = 0.17
				dash_cooldown = 0.65
				_dash_direction = direction
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0:
				get_parent().shoot()
				fire_cooldown = 0.24
				attack_time = 0.2
	elif is_instance_valid(follow_target) and get_parent().navigation_ready:
		direction = follow_direction(delta)
	var speed := nominal_speed() if role == "hunter" else _follow_speed
	if dash_time > 0:
		speed *= 2.8
		direction = _dash_direction
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var acceleration := PLAYER_ACCELERATION if role == "hunter" else FOLLOW_ACCELERATION
	if direction.length_squared() < 0.001:
		acceleration = PLAYER_BRAKING if role == "hunter" else FOLLOW_BRAKING
	horizontal = direction * speed if dash_time > 0 else horizontal.move_toward(direction * speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.15
	move_and_slide()
	_current_position = global_position
	var travel := _current_position - _previous_position
	travel.y = 0
	update_facing(travel / delta, delta)
	update_animation(travel.length(), delta)
	if global_position.y < -8:
		global_position = Vector3(0, 1, 9)
		reset_motion()

func nominal_speed() -> float:
	return 1.7 if role == "enemy" else SPEED

func follow_direction(delta: float) -> Vector3:
	var destination := follow_target.global_position
	if role == "echo":
		destination += Vector3(-1.4, 0, 1.5)
	var distance := global_position.distance_to(destination)
	var stop_distance := 1.5 if role == "echo" else 2.3
	var resume_distance := 2.4 if role == "echo" else 3.0
	if _following and distance <= stop_distance + 0.08:
		_following = false
	elif not _following and distance >= resume_distance:
		_following = true
	_path_elapsed += delta
	_follow_speed = 0.0
	if not _following:
		return Vector3.ZERO
	if not _has_path_target or (_path_elapsed >= PATH_REFRESH_TIME
		and destination.distance_to(_path_target) >= PATH_TARGET_DISTANCE):
		nav.target_position = destination
		_path_target = destination
		_has_path_target = true
		_path_elapsed = 0.0
	if nav.is_navigation_finished():
		return Vector3.ZERO
	var direction := nav.get_next_path_position() - global_position
	direction.y = 0
	if direction.length_squared() < 0.0001:
		return Vector3.ZERO
	_follow_speed = minf(nominal_speed(), maxf(0, distance - stop_distance) * 4.0)
	return direction.normalized()

func update_facing(actual_velocity: Vector3, delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var horizontal := actual_velocity.x if camera == null else actual_velocity.dot(camera.global_basis.x)
	# Garder l'orientation dans les trajets presque verticaux et pendant les petites corrections de navigation.
	if absf(horizontal) < 0.5 or absf(horizontal) < actual_velocity.length() * 0.22:
		_turn_time = 0.0
		return
	var flipped := horizontal < 0
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

func update_animation(distance: float, delta: float) -> void:
	_animation_time += delta
	var actual_speed := distance / delta
	_idle_time = _idle_time + delta if actual_speed < 0.15 else 0.0
	var moving := actual_speed > 0.3 or (animation_name == "move" and _idle_time < 0.1)
	var next := "move" if moving else "idle"
	if attack_time > 0:
		next = "attack"
	if dash_time > 0:
		next = "dash"
	if next != animation_name:
		animation_name = next
		_animation_time = 0.0
	if next == "move":
		var clip := animation_clip("move")
		# Le cycle avance avec le terrain parcouru : aucun piétinement quand un pilier bloque le corps.
		_walk_phase = fmod(_walk_phase + distance * float(clip.fps) / nominal_speed(), float(clip.frames))

func animation_clip(animation: String) -> Dictionary:
	return art.animations.get(animation, art.animations.get("move", {}))

func key_down(keys: Array) -> bool:
	for key: int in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false

func hit() -> void:
	if role != "enemy":
		return
	hp -= 1
	tint_time = 0.12
	get_parent().enemy_hits += 1
	if hp <= 0:
		get_parent().spawn_fx("hit", global_position + Vector3.UP * 0.6)
		queue_free()
