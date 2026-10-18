class_name EchoVfx
extends RefCounted
## Raccordement des effets peints des Échos (Codex, docs/art/ECHOS_C7_EFFETS.md). Présentation seulement :
## les positions, rayons et durées viennent des règles ; un effet refusé (plafond atteint) ne change rien au jeu.
## Scènes : res://assets/vfx/echoes/<écho>/<nom>.tscn (attack, status, indicator et un fichier par sort).

const ROOT := "res://assets/vfx/echoes/%s/%s.tscn"
const LAYER := preload("res://assets/vfx/echoes/effect_layer.gd")
## Délai minimal entre deux effets de statut d'un même Écho (lisibilité et plafond partagé).
const STATUS_INTERVAL := 0.35

var ctx: RunContext
var layer: Node2D
var _scenes: Dictionary = {}
## Écho → statut dont l'application joue son effet « status » (premier statut de son attaque).
var _status_of: Dictionary = {}
var _status_ready: Dictionary = {}


func setup(p_ctx: RunContext, parent: Node) -> void:
	ctx = p_ctx
	layer = Node2D.new()
	layer.name = "EchoEffects"
	layer.set_script(LAYER)
	layer.z_as_relative = false
	layer.z_index = 1
	parent.add_child(layer)
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var monster: MonsterData = GameDB.monsters[id]
		# params.status_vfx = false : l'effet « status » est joué par le comportement (flaques de Scoriade).
		if scene(id, &"status") and monster.attack and not monster.attack.statuses.is_empty() \
				and bool(monster.attack.params.get("status_vfx", true)):
			_status_of[id] = monster.attack.statuses[0].status_id
	ctx.events.status_applied.connect(_on_status_applied)


func scene(echo_id: StringName, effect: StringName) -> PackedScene:
	var path: String = ROOT % [echo_id, effect]
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


## Vrai si l'Écho a ses effets peints (les zones au sol ne gardent alors qu'un repère discret).
func has_effects(echo_id: StringName) -> bool:
	return scene(echo_id, &"attack") != null


## Joue un effet ; retourne null s'il n'existe pas pour cet Écho ou si le plafond est atteint.
func play(echo_id: StringName, effect: StringName, origin: Vector2, direction: Vector2,
		parameters: Dictionary = {}) -> Node2D:
	var packed: PackedScene = scene(echo_id, effect)
	if packed == null or layer == null:
		return null
	return layer.call("emit_effect", packed, origin, direction, parameters) as Node2D


## Attaque : trajet de l'Écho (ou du point de tir) jusqu'à la cible.
func attack(ally: Ally, from: Vector2, to: Vector2, duration: float = 0.45) -> Node2D:
	return play(ally.data.id, &"attack", from, to - from, {"travel_distance": from.distance_to(to),
		"visual_duration": duration, "radius": 30.0})


## Sort : nom de scène = params["vfx"] ou identifiant du sort.
func spell(ally: Ally, tech: TechniqueData, origin: Vector2, direction: Vector2, radius: float, duration: float,
		travel: float = -1.0) -> Node2D:
	var parameters: Dictionary = {"radius": radius, "visual_duration": maxf(duration, 0.4)}
	if travel >= 0.0:
		parameters["travel_distance"] = travel
	return play(ally.data.id, StringName(tech.params.get("vfx", String(tech.id))), origin, direction, parameters)


## Effet « status » posé à un endroit (flaque de lave, soin), soumis au même rythme que les statuts.
func status_at(echo_id: StringName, pos: Vector2, radius: float = 20.0, duration: float = 1.2) -> Node2D:
	if ctx.time < float(_status_ready.get(echo_id, 0.0)):
		return null
	_status_ready[echo_id] = ctx.time + STATUS_INTERVAL
	return play(echo_id, &"status", pos, Vector2.RIGHT, {"radius": radius, "visual_duration": duration,
		"travel_distance": 0.0})


func clear() -> void:
	if layer:
		for effect: Node in layer.get_children():
			effect.queue_free()


func _on_status_applied(target: Combatant, status_id: StringName, added: int, source_id: StringName) -> void:
	if added <= 0 or _status_of.get(source_id, &"") != status_id or not (target is Enemy):
		return
	status_at(source_id, (target as Enemy).global_position, clampf((target as Enemy).radius, 12.0, 24.0))
