class_name DraftHunter
extends CharacterBody3D
## Le Chasseur du premier jet : déplacement, Ruée, PV, EXP et niveaux. Statistiques dans une `StatSheet` commune
## avec la campagne (mêmes clés, mêmes valeurs de base). L'attaque automatique est tirée par `DraftRun`.

signal hurt(amount: float)
signal died
signal leveled(level: int)

## Mètres par unité de l'ancien monde 2D : vitesses, portées et rayons de l'équilibrage sont convertis ainsi.
const UNIT := 0.03
const GRAVITY := 22.0
const ACCELERATION := 75.0
const BRAKING := 95.0
const RADIUS := 0.3
const HEIGHT := 1.5

var balance: BalanceConfig
var stats: StatSheet
var view: DraftSpriteView
var hp: float = 100.0
var level: int = 1
var xp: float = 0.0
var alive: bool = true
var active: bool = true
var attack_timer: float = 0.4
var dash_time: float = 0.0
var dash_cooldown_left: float = 0.0
var invulnerable: float = 0.0
## Pilotage par le bot ou les vérifications (aucune touche lue).
var automating: bool = false
var auto_direction := Vector3.ZERO
var auto_dash: bool = false
var god_mode: bool = false
var _dash_direction := Vector3.ZERO
var _dash_held: bool = false


func setup(p_balance: BalanceConfig) -> void:
	balance = p_balance
	stats = DraftUpgrades.base_stats(balance)
	hp = max_hp()
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(48.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = HEIGHT * 0.5
	add_child(collision)
	view = DraftSpriteView.new()
	add_child(view)
	view.setup(balance.player_visual.visual_id)
	view.walk_speed = move_speed()


func max_hp() -> float:
	return stats.get_value(StatKeys.MAX_HP)


func move_speed() -> float:
	return stats.get_value(StatKeys.MOVE_SPEED) * UNIT


func pickup_radius() -> float:
	return stats.get_value(StatKeys.PICKUP_RADIUS) * UNIT


func attack_range() -> float:
	return stats.get_value(StatKeys.BOLT_RANGE) * UNIT


func attack_interval() -> float:
	return balance.bolt.cooldown / maxf(stats.get_value(StatKeys.ATTACK_SPEED), 0.1)


func bolt_damage() -> float:
	return balance.bolt.damage * stats.get_value(StatKeys.DAMAGE)


func dash_cooldown() -> float:
	return maxf(stats.get_value(StatKeys.DASH_COOLDOWN), 0.4)


func is_dashing() -> bool:
	return dash_time > 0.0


func chest() -> Vector3:
	return global_position + Vector3.UP * 0.8


func xp_needed() -> int:
	return balance.xp_to_next(level)


func gain_xp(amount: float) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled.emit(level)


func heal(amount: float) -> void:
	hp = minf(max_hp(), hp + amount)


## Renvoie les dégâts réellement subis (0 pendant la Ruée ou l'invulnérabilité qui suit un coup).
func take_damage(amount: float) -> float:
	if not alive or invulnerable > 0.0 or god_mode:
		return 0.0
	var final: float = maxf(amount * stats.get_value(StatKeys.DAMAGE_TAKEN), 1.0)
	hp -= final
	invulnerable = balance.hurt_iframes
	view.flash(0.18)
	hurt.emit(final)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		active = false
		view.play_action(&"death", 30.0)
		died.emit()
	return final


func reset_motion() -> void:
	velocity = Vector3.ZERO
	view.snap_to(global_position)


func _physics_process(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)
	dash_time = maxf(dash_time - delta, 0.0)
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	invulnerable = maxf(invulnerable - delta, 0.0)
	if alive:
		heal(stats.get_value(StatKeys.REGEN) * delta)
	var direction := Vector3.ZERO
	var wants_dash: bool = false
	if active:
		if automating:
			direction = auto_direction.normalized()
			wants_dash = auto_dash
			auto_dash = false
		else:
			var x: float = float(_down([KEY_D, KEY_RIGHT])) - float(_down([KEY_A, KEY_Q, KEY_LEFT]))
			var z: float = float(_down([KEY_S, KEY_DOWN])) - float(_down([KEY_W, KEY_Z, KEY_UP]))
			direction = Vector3(x, 0, z).normalized()
			var held: bool = _down([KEY_SPACE, KEY_SHIFT])
			wants_dash = held and not _dash_held
			_dash_held = held
	if wants_dash and dash_cooldown_left <= 0.0 and direction.length_squared() > 0.0:
		dash_time = balance.dash_duration
		dash_cooldown_left = dash_cooldown()
		invulnerable = maxf(invulnerable, balance.dash_iframes)
		_dash_direction = direction
		view.play_action(&"dash", balance.dash_duration)
		Audio.play_sfx(&"dash")
	var speed: float = move_speed()
	view.walk_speed = speed
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if dash_time > 0.0:
		horizontal = _dash_direction * (balance.dash_distance * UNIT / balance.dash_duration)
	elif direction.length_squared() < 0.001:
		horizontal = horizontal.move_toward(Vector3.ZERO, BRAKING * delta)
	else:
		horizontal = horizontal.move_toward(direction * speed, ACCELERATION * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.15 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	if global_position.y < -8.0:
		global_position = DraftLevel.START
		reset_motion()
	view.push_position(global_position, delta)


static func _down(keys: Array) -> bool:
	for key: int in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false
