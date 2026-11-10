class_name TutorialTips
extends RefCounted
## Astuces de la première expédition (lot 2 des menus) : chacune arrive quand elle devient utile, d'après ce que fait
## le joueur, et non plus à heure fixe. Une à la fois, chacune une seule fois ; les suivantes attendent leur tour.

const SHOW_TIME := 6.5
const GAP := 0.8
## Touches citées par une astuce (libellés selon la disposition du clavier et le mode de contrôle).
const TIP_KEYS := {
	"TIP_MOVE": [&"move_up", &"move_left", &"move_down", &"move_right"],
	"TIP_TECHNIQUES": [&"technique_1", &"technique_2", &"technique_3"],
	"TIP_RELAY": [&"technique_1", &"echo_relay"],
}

var text: String = ""
var time: float = 0.0
var _ctx: RunContext
var _queue: Array[String] = []
var _done: Dictionary = {}
var _gap: float = 0.0
var _start := Vector2.INF
var _check: float = 0.0


func setup(p_ctx: RunContext) -> void:
	_ctx = p_ctx
	_trigger("TIP_MOVE")
	_ctx.events.player_hurt.connect(func(_amount: float) -> void: _trigger("TIP_DASH"))
	_ctx.events.technique_cast.connect(func(_id: StringName, _kind: StringName) -> void: _trigger("TIP_COOLDOWNS"))
	_ctx.events.milestone_reached.connect(func() -> void: _trigger("TIP_MILESTONE"))
	_ctx.events.elite_spawned.connect(func(_enemy: Enemy) -> void: _trigger("TIP_ELITE"))
	_ctx.events.boss_spawned.connect(func(_boss: Enemy) -> void: _trigger("TIP_BOSS"))
	_ctx.events.event_started.connect(func(key: String) -> void:
		if key == "ZONE_CLEARED_BANNER":
			_trigger("TIP_ZONE"))


func active() -> bool:
	return _ctx != null


func step(delta: float) -> void:
	if _ctx == null:
		return
	time = maxf(time - delta, 0.0)
	_gap = maxf(_gap - delta, 0.0)
	_check -= delta
	if _check <= 0.0 and _ctx.player:
		_check = 0.5
		_watch()
	if time <= 0.0 and _gap <= 0.0 and not _queue.is_empty():
		_show(_queue.pop_front())


## Déclencheurs qui se lisent dans la partie : premiers pas, premier ennemi proche, premières éliminations.
func _watch() -> void:
	var pos: Vector2 = _ctx.player.global_position
	if _start == Vector2.INF:
		_start = pos
	if pos.distance_to(_start) > 250.0 or _ctx.time > 12.0:
		_trigger("TIP_AUTO_ATTACK")
	if _done.has("TIP_AUTO_ATTACK") and _ctx.enemies.find_nearest(pos, 350.0) != null:
		_trigger("TIP_SPELLS")
	if _ctx.stats.get_value(&"kills") >= 8.0:
		# Modes des Échos à l'essai : Relais (une Technique + touche de relais), Solo (aucune Technique).
		match _ctx.setup.echo_mode:
			EchoMode.RELAY:
				_trigger("TIP_RELAY")
			EchoMode.CURRENT:
				_trigger("TIP_TECHNIQUES")


func _trigger(key: String) -> void:
	if _done.has(key):
		return
	_done[key] = true
	_queue.append(key)


func _show(key: String) -> void:
	text = TranslationServer.translate(key + "_MOUSE") if key == "TIP_SPELLS" and Settings.uses_mouse() \
		else TranslationServer.translate(key)
	var labels: Array = []
	for action: StringName in TIP_KEYS.get(key, []):
		labels.append(InputSetup.key_label(action))
	if not labels.is_empty():
		text = text % labels
	time = SHOW_TIME
	_gap = SHOW_TIME + GAP
