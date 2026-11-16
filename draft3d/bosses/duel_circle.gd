class_name DraftDuelCircle
extends DraftBossMechanic
## Cercle du duel, mécanique phare du Chevalier calciné (chapitre 2, docs/design/MONSTRES.md), reprise de
## `AshGuardians.duel_circle` pour le monde 3D : il plante son épée et trace un cercle de feu autour de lui et du
## Chasseur. Dedans, ses coups portent × 1,5 ; dehors, le Chasseur brûle. Le volet « Échos repoussés » de la v1 n'a
## pas d'objet (Chasseur seul).

const FIRE := Color(1.0, 0.45, 0.1)
const BURN_EVERY := 0.5

## Cercle en cours : {"center", "radius", "until", "mult", "burn"} (vide : aucun).
var circle: Dictionary = {}
var burns: int = 0
var _clock: float = 0.0
var _burn_at: float = 0.0
var _node: MeshInstance3D


func handles(kind: StringName) -> bool:
	return kind == &"duel_circle"


func perform(pattern: BossPatternData) -> float:
	_clear()
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var hunter: Vector3 = brain.enemies.hunter.global_position
	var radius: float = maxf(float(params.get("radius", 350.0)) * DraftHunter.UNIT, foe.pos.distance_to(hunter) * 0.5 + 3.0)
	var center: Vector3 = brain.enemies.level.closest(foe.pos.lerp(hunter, 0.5))
	circle = {"center": center, "radius": radius, "from": _clock + pattern.telegraph,
		"until": _clock + pattern.telegraph + float(params.get("duration", 8.0)) + (1.0 if brain.phase >= 1 else 0.0),
		"mult": float(params.get("damage_mult", 1.5)), "burn": brain.damage(float(params.get("burn", 6.0)))}
	_node = _ring(center, radius)
	brain.play_clip([StringName(str(params.get("anim", "attack"))), &"attack"], pattern.telegraph)
	brain.fx(&"fire_ring", foe.pos + Vector3.UP * 0.5, 2.0)
	intro("BOSS_DUEL_INTRO_3D")
	return pattern.telegraph + 0.3


func active() -> bool:
	return not circle.is_empty() and _clock >= float(circle["from"])


func inside(at: Vector3) -> bool:
	var offset: Vector3 = at - (circle["center"] as Vector3)
	return Vector2(offset.x, offset.z).length() <= float(circle["radius"])


func damage_mult() -> float:
	return float(circle["mult"]) if active() and inside(brain.enemies.hunter.global_position) else 1.0


func step(delta: float) -> void:
	_clock += delta
	if circle.is_empty():
		return
	var material: StandardMaterial3D = _node.material_override
	material.albedo_color = Color(FIRE, 0.85 if active() else 0.35)
	if _clock >= float(circle["until"]):
		_clear()
		return
	var hunter: DraftHunter = brain.enemies.hunter
	if active() and not inside(hunter.global_position) and _clock >= _burn_at and hunter.alive:
		_burn_at = _clock + BURN_EVERY
		burns += 1
		hunter.take_damage(float(circle["burn"]))
		brain.fx(&"flame_pillar", hunter.chest(), 0.8)


func _ring(center: Vector3, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.25
	mesh.outer_radius = radius
	mesh.rings = 64
	mesh.ring_segments = 4
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(FIRE, 0.35)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain.enemies.add_child(node)
	node.global_position = center + Vector3.UP * 0.1
	node.scale = Vector3(1, 0.3, 1)
	return node


func _clear() -> void:
	if _node != null:
		_node.queue_free()
		_node = null
	circle = {}


func finish() -> void:
	_clear()
