class_name DraftSaumor
extends DraftBossMechanic
## Saumor, Dévoreur des Salines (chapitre 8, docs/art/SAUMOR.md) : « Appel de la vanne ». Calé sur ses bras, il ouvre
## ses vantaux et aspire le Chasseur vers son siphon, puis les referme d'un coup sur tout ce qui s'y trouve.
## - Deux abris de sel sortent du sol à côté du Chasseur ; tout obstacle solide (abri, décor) entre le siphon et lui
##   coupe l'aspiration. Le courant d'aspiration est visible tant qu'il porte, et disparaît derrière un abri.
## - Vantaux ouverts, le siphon est à découvert : les coups portent davantage.
## - Enchaînement : après l'aspiration, l'écrasement des épaules (vantaux) ou la pulsation du siphon (siphon à nu).
## Aucun texte n'explique la mécanique : le joueur la lit au courant et aux abris.

const SALT := Color(0.66, 0.62, 0.53)
const SHELTER := Vector3(1.7, 2.4, 1.7)
## Écart des abris de part et d'autre du Chasseur, et avance vers le boss (m).
const SHELTER_SIDE := 3.2
const SHELTER_AHEAD := 1.4
## Siphon à découvert pendant l'aspiration : coups × OPEN_MULT.
const OPEN_MULT := 1.3
const STREAM_WIDTH := 1.2
## Au-delà de cette distance (m), il ne lance pas l'appel : il se rapproche d'abord.
const REACH := 12.0

## Aspirations jouées, temps passé aspiré, temps passé à l'abri pendant une aspiration (essais).
var pulls: int = 0
var pulled_time: float = 0.0
var sheltered_time: float = 0.0
## Abris dressés : {"body", "pos", "until"}.
var shelters: Array[Dictionary] = []
var _clock: float = 0.0
var _open_at: float = -1.0
var _close_at: float = -1.0
var _pull: float = 0.0
var _stream: MeshInstance3D


func handles(kind: StringName) -> bool:
	return kind == &"gate_pull"


func allows(kind: StringName, distance: float) -> bool:
	return kind != &"gate_pull" or distance <= REACH


func next_kind(last: StringName) -> StringName:
	if last == &"gate_pull":
		return &"core_burst" if brain.phase >= 1 else &"slam"
	return &""


func perform(pattern: BossPatternData) -> float:
	pulls += 1
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var hunter: DraftHunter = brain.enemies.hunter
	var duration: float = float(params.get("duration", 3.2))
	_pull = float(params.get("pull", 120.0)) * DraftHunter.UNIT
	_open_at = _clock + pattern.telegraph
	_close_at = _open_at + duration
	var toward: Vector3 = foe.pos - hunter.global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.LEFT
	var side := Vector3(-toward.z, 0, toward.x)
	var count: int = int(params.get("shelters", 2))
	for k: int in count:
		var lateral: float = (1.0 if k % 2 == 0 else -1.0) * SHELTER_SIDE * (1.0 + 0.5 * floorf(k / 2.0))
		var at: Vector3 = brain.enemies.level.closest(hunter.global_position + side * lateral + toward * SHELTER_AHEAD)
		if at.distance_to(foe.pos) < foe.radius + 2.0:
			continue
		shelters.append({"body": make_block(at, SHELTER, SALT), "pos": at, "until": _close_at + 2.5})
		brain.fx(&"geyser", at + Vector3.UP * 0.5, 1.4)
	# Les vantaux se referment : tout ce qui est près du siphon est broyé.
	var reach: float = foe.radius + float(params.get("mouth_radius", 110.0)) * DraftHunter.UNIT
	brain.enemies.hazards.circle(foe.pos, reach, pattern.telegraph + duration, brain.damage(pattern.damage),
		brain.fx_at(&"splash", reach * 1.4))
	brain.play_clip([StringName(str(params.get("anim", "gate_pull"))), &"attack"], pattern.telegraph + duration)
	return pattern.telegraph + duration + 0.3


## Le siphon a-t-il une vue dégagée sur le Chasseur (aucun abri, aucun décor entre eux) ?
func exposed() -> bool:
	var foe: DraftEnemies.Foe = brain.foe
	var hunter: DraftHunter = brain.enemies.hunter
	if absf(hunter.global_position.y - foe.pos.y) > DraftHazards.REACH_UP:
		return false
	var space: PhysicsDirectSpaceState3D = brain.enemies.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(foe.pos + Vector3.UP * 0.9, hunter.chest(), 1)
	return space.intersect_ray(query).is_empty()


func pulling() -> bool:
	return _open_at >= 0.0 and _clock >= _open_at and _clock < _close_at


func holds_boss() -> bool:
	return _open_at >= 0.0 and _clock < _close_at


func damage_mult() -> float:
	return OPEN_MULT if pulling() else 1.0


func step(delta: float) -> void:
	_clock += delta
	for i: int in range(shelters.size() - 1, -1, -1):
		if _clock >= float(shelters[i]["until"]):
			brain.fx(&"splash", (shelters[i]["pos"] as Vector3) + Vector3.UP, 1.4)
			(shelters[i]["body"] as Node).queue_free()
			shelters.remove_at(i)
	if _open_at >= 0.0 and _clock >= _close_at:
		_open_at = -1.0
		_hide_stream()
	if not pulling() or not brain.foe.alive:
		_hide_stream()
		return
	var hunter: DraftHunter = brain.enemies.hunter
	if not hunter.alive:
		return
	if not exposed():
		sheltered_time += delta
		_hide_stream()
		return
	_show_stream()
	if hunter.is_dashing():
		return
	var toward: Vector3 = brain.foe.pos - hunter.global_position
	toward.y = 0.0
	if toward.length() < brain.foe.radius + 0.6:
		return
	pulled_time += delta
	hunter.move_and_collide(toward.normalized() * _pull * delta)


## Courant d'aspiration entre le siphon et le Chasseur, au sol.
func _show_stream() -> void:
	var from: Vector3 = brain.foe.pos
	var to: Vector3 = brain.enemies.hunter.global_position
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var length: float = maxf(flat.length(), 0.5)
	if _stream == null:
		_stream = DraftCombatFx.ground(brain.enemies, from, Vector2(STREAM_WIDTH, length), brain.combat_family(),
			DraftCombatFx.LANE, DraftCombatFx.HOLD, DraftCombatFx.WARNING, 0.75, flat / length)
	var plane := _stream.mesh as PlaneMesh
	plane.size = Vector2(STREAM_WIDTH, length)
	(_stream.material_override as ShaderMaterial).set_shader_parameter("extent", plane.size)
	_stream.global_position = (from + to) * 0.5 + Vector3.UP * 0.09
	_stream.global_basis = Basis(Vector3.UP, atan2(-flat.x, -flat.z))
	_stream.visible = true


func _hide_stream() -> void:
	if _stream != null:
		_stream.visible = false


func finish() -> void:
	_open_at = -1.0
	if _stream != null:
		_stream.queue_free()
		_stream = null
	for shelter: Dictionary in shelters:
		(shelter["body"] as Node).queue_free()
	shelters.clear()
