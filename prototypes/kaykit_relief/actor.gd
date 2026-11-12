extends CharacterBody3D
## Contrôleur de laboratoire uniquement. Aucun branchement sur la simulation 2D de campagne.

const SPEED := 5.2
const GRAVITY := 22.0
var role := "hunter"
var art: Dictionary
var sprite: Sprite3D
var nav: NavigationAgent3D
var follow_target: Node3D
var clock := 0.0
var attack_time := 0.0
var dash_time := 0.0
var dash_cooldown := 0.0
var fire_cooldown := 0.0
var hp := 4
var active := true
var auto_direction := Vector3.ZERO
var automating := false
var tint_time := 0.0

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
	add_child(sprite)
	# L'ombre est une vraie projection 3D du sprite découpé sur le sol.
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if role != "hunter":
		nav = NavigationAgent3D.new()
		nav.path_desired_distance = 0.35
		nav.target_desired_distance = 1.0 if role == "echo" else 0.8
		nav.radius = 0.35
		add_child(nav)
	add_to_group("actors")
	if role == "enemy":
		add_to_group("enemies")

func _physics_process(delta: float) -> void:
	clock += delta
	attack_time = maxf(0, attack_time - delta)
	dash_time = maxf(0, dash_time - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	fire_cooldown = maxf(0, fire_cooldown - delta)
	tint_time = maxf(0, tint_time - delta)
	sprite.modulate = Color(2.0, 0.75, 0.8) if tint_time > 0 else Color.WHITE
	if not active:
		velocity = Vector3.ZERO
		return
	var direction := Vector3.ZERO
	if role == "hunter":
		if automating:
			direction = auto_direction
		else:
			var x := float(key_down([KEY_D, KEY_RIGHT])) - float(key_down([KEY_A, KEY_Q, KEY_LEFT]))
			var z := float(key_down([KEY_S, KEY_DOWN])) - float(key_down([KEY_W, KEY_Z, KEY_UP]))
			direction = Vector3(x, 0, z).normalized()
			if Input.is_physical_key_pressed(KEY_SPACE) and dash_cooldown <= 0 and direction.length() > 0:
				dash_time = 0.17
				dash_cooldown = 0.65
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0:
				get_parent().shoot()
				fire_cooldown = 0.24
				attack_time = 0.2
	elif is_instance_valid(follow_target) and get_parent().navigation_ready:
		var destination := follow_target.global_position
		if role == "echo":
			destination += Vector3(-1.4, 0, 1.5)
		if Engine.get_physics_frames() % 18 == 0:
			nav.target_position = destination
		if global_position.distance_to(destination) > (1.8 if role == "echo" else 2.5):
			if not nav.is_navigation_finished():
				direction = global_position.direction_to(nav.get_next_path_position())
				direction.y = 0
				direction = direction.normalized()
	var speed := SPEED
	if role == "enemy":
		speed = 1.7
	if dash_time > 0:
		speed *= 2.8
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.15
	move_and_slide()
	if direction.x != 0:
		sprite.flip_h = direction.x < 0
	animate("attack" if attack_time > 0 else ("move" if direction.length() > 0.05 else "idle"))
	if global_position.y < -8:
		global_position = Vector3(0, 1, 9)
		velocity = Vector3.ZERO

func key_down(keys: Array) -> bool:
	for key: int in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false

func animate(animation: String) -> void:
	var clip: Dictionary = art.animations.get(animation, art.animations.get("move", {}))
	var frame := int(clock * float(clip.fps)) % int(clip.frames)
	sprite.region_rect.position = Vector2(frame * int(art.cell[0]), int(clip.row) * int(art.cell[1]))

func hit() -> void:
	if role != "enemy":
		return
	hp -= 1
	tint_time = 0.12
	get_parent().enemy_hits += 1
	if hp <= 0:
		get_parent().spawn_fx("hit", global_position + Vector3.UP * 0.6)
		queue_free()
