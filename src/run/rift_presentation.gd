class_name RiftPresentation
extends Node2D
## Réactions et sorties de Corrompus ; abonné aux événements, sans PV, RNG ni cadence de spawn.

var ctx: RunContext
var _births: Array[Dictionary] = []
var _closures: Array[Dictionary] = []


func setup(context: RunContext) -> void:
	ctx = context
	z_index = 2
	ctx.events.enemy_damaged.connect(_on_damaged)
	ctx.events.enemy_killed.connect(_on_killed)
	ctx.events.elite_spawned.connect(emerge)


func emerge(enemy: Enemy) -> void:
	if enemy == null or enemy.visual == null:
		return
	var target: Vector2 = enemy.visual.scale
	enemy.visual.scale = target * 0.72
	var tween: Tween = enemy.visual.create_tween()
	tween.tween_property(enemy.visual, "scale", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _births.size() < 32:
		_births.append({"position": enemy.position, "remaining": 0.4})


func _on_damaged(enemy: Enemy, _info: DamageInfo, _amount: float) -> void:
	if enemy.data != null and enemy.data.id == &"rift_breach":
		enemy.visual.play_action(&"hurt")


func _on_killed(enemy: Enemy, _info: DamageInfo) -> void:
	if enemy.data == null or enemy.data.id != &"rift_breach":
		return
	_closures.append({"position": enemy.position, "remaining": 2.0 / 3.0})
	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames = Assets.get_sprite_frames(&"enemy.rift_breach")
	if ghost.sprite_frames == null:
		ghost.queue_free()
		return
	ghost.position = enemy.position
	ghost.centered = false
	ghost.offset = -Assets.anchor(&"enemy.rift_breach")
	ghost.scale = Vector2.ONE * Assets.pixel_scale(&"enemy.rift_breach")
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.z_index = 3
	ghost.animation_finished.connect(ghost.queue_free)
	ctx.world.add_child(ghost)
	ghost.play(&"death")


func _process(delta: float) -> void:
	for i: int in range(_closures.size() - 1, -1, -1):
		_closures[i]["remaining"] = float(_closures[i]["remaining"]) - delta
		if float(_closures[i]["remaining"]) <= 0.0:
			_closures.remove_at(i)
	for i: int in range(_births.size() - 1, -1, -1):
		_births[i]["remaining"] = float(_births[i]["remaining"]) - delta
		if float(_births[i]["remaining"]) <= 0.0:
			_births.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for closure: Dictionary in _closures:
		var remaining: float = float(closure["remaining"]) * 1.5
		RiftArt.ground(self, closure["position"], 92.0 * (0.65 + 0.35 * remaining), remaining, remaining)
	for birth: Dictionary in _births:
		var remaining: float = float(birth["remaining"]) / 0.4
		RiftArt.ground(self, birth["position"], 16.0 + (1.0 - remaining) * 26.0, remaining, remaining)
