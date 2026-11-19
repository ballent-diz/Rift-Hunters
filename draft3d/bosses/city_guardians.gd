class_name DraftCityGuardians
extends DraftBossMechanic
## Mécaniques phares des gardiens du chapitre 5 (docs/design/MONSTRES.md), reprises de `BossController` et
## `CityTechniques` pour le monde 3D. Une instance par gardien ; elle ne joue que la technique de sa signature.
## - Cri de guerre (Commandant déchu) : onde du cri autour de lui, Corrompus proches ralliés (plus rapides, plus forts),
##   miliciens appelés, puis il charge.
## - Tempête de runes (Golem du sanctuaire) : sceaux autour du Chasseur, qui frappent puis ralentissent quelques
##   secondes ; il se couvre d'une armure de dalles le temps de la tempête (les portes runiques de la v1 n'existent pas).
## - Réveil du Panthéon (Gardienne du Panthéon) : des statues s'éveillent près du Chasseur (pas de socles en 3D) et
##   une onde de pierre part d'elle.
## - Chaîne d'âmes (Grand Héraldiste) : des Déchus accourent, il lie à lui les Corrompus proches (dégâts subis × 0,4) et
##   un sceau se trace sous le Chasseur. Frapper l'Héraldiste, ou attendre que les liens se rompent.

const SEAL := Color(0.75, 0.3, 0.95, 0.35)
const LINK := Color(0.8, 0.45, 1.0)
const SLAB_MULT := 0.35

var kind: StringName
## Sceaux qui ralentissent : {"pos", "radius", "until", "disc"}.
var seals: Array[Dictionary] = []
## Ralliés : {"foe", "until", "speed", "damage"}.
var rallied: Array[Dictionary] = []
var linked: Array[DraftEnemies.Foe] = []
var woken: int = 0
var _clock: float = 0.0
var _armor_until: float = 0.0
var _links: Array[MeshInstance3D] = []
var _link_until: float = 0.0
var _charge_at: float = -1.0
var _charge_damage: float = 0.0


func _init(p_kind: StringName = &"") -> void:
	kind = p_kind


func handles(p_kind: StringName) -> bool:
	return p_kind == kind


func perform(pattern: BossPatternData) -> float:
	match kind:
		&"war_cry":
			return _war_cry(pattern)
		&"rune_barrage":
			return _rune_barrage(pattern)
		&"pantheon_wake":
			return _pantheon_wake(pattern)
		&"soul_chain":
			return _soul_chain(pattern)
	return 0.0


func damage_mult() -> float:
	return SLAB_MULT if _clock < _armor_until else 1.0


func step(delta: float) -> void:
	_clock += delta
	_step_seals()
	_step_rally()
	_step_links()
	if _charge_at >= 0.0 and _clock >= _charge_at:
		_charge_at = -1.0
		var aim: Vector3 = brain.enemies.hunter.global_position - brain.foe.pos
		aim.y = 0.0
		var charge := BossPatternData.new()
		charge.kind = &"charge"
		charge.telegraph = 0.6
		charge.damage = _charge_damage
		brain.charge(charge, aim.normalized() if aim.length() > 0.01 else Vector3.RIGHT)


func _spawn_around(id: StringName, count: int, distance: float) -> void:
	var data: EnemyData = GameDB.enemy(id)
	if not DraftRoster.usable(data):
		return
	var foe: DraftEnemies.Foe = brain.foe
	for i: int in count:
		var angle: float = TAU * i / maxi(count, 1) + brain.enemies.rng.randf()
		var at: Vector3 = brain.enemies.level.closest(foe.pos + Vector3(cos(angle), 0, sin(angle)) * distance)
		brain.enemies.spawn(data, at)
		brain.fx(&"summon_rise", at + Vector3.UP * 0.5, 1.0)


func _seal(at: Vector3, radius: float, delay: float, damage: float, duration: float) -> void:
	brain.enemies.hazards.circle(at, radius, delay, damage, brain.fx_at(&"rune_circle", radius))
	seals.append({"pos": at, "radius": radius, "from": _clock + delay, "until": _clock + delay + duration,
		"disc": make_disc(at, radius, Color(SEAL, 0.0))})


func _step_seals() -> void:
	var hunter: DraftHunter = brain.enemies.hunter
	for i: int in range(seals.size() - 1, -1, -1):
		var seal: Dictionary = seals[i]
		if _clock >= float(seal["until"]):
			(seal["disc"] as Node).queue_free()
			seals.remove_at(i)
			continue
		if _clock < float(seal["from"]):
			continue
		DraftCombatFx.tint(seal["disc"], SEAL)
		var offset: Vector3 = hunter.global_position - (seal["pos"] as Vector3)
		if Vector2(offset.x, offset.z).length() < float(seal["radius"]) and absf(offset.y) < 1.2:
			hunter.hinder(0.6, 0.3)


# --- Cri de guerre -------------------------------------------------------------------------------------------------

func _war_cry(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var radius: float = float(params.get("radius", 650.0)) * DraftHunter.UNIT
	var duration: float = float(params.get("duration", 5.0))
	brain.enemies.hazards.circle(foe.pos, float(params.get("blast", 200.0)) * DraftHunter.UNIT, pattern.telegraph,
		brain.damage(pattern.damage), brain.fx_at(&"rage", 2.5))
	for other: DraftEnemies.Foe in brain.enemies.near(foe.pos, radius):
		if other.brain != null:
			continue
		rallied.append({"foe": other, "until": _clock + pattern.telegraph + duration, "speed": other.speed,
			"damage": other.damage})
		other.speed *= float(params.get("speed_mult", 1.3))
		other.damage *= float(params.get("damage_mult", 1.3))
		other.view.set_tint(Color(1.4, 0.8, 0.8))
	_spawn_around(StringName(str(params.get("spawn", "fallen_militia"))), int(params.get("count", 3)), 4.5)
	_charge_at = _clock + pattern.telegraph + 0.2
	_charge_damage = pattern.damage
	brain.play_clip([StringName(str(params.get("anim", "rallying_cry"))), &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.1


func _step_rally() -> void:
	for i: int in range(rallied.size() - 1, -1, -1):
		var entry: Dictionary = rallied[i]
		var other: DraftEnemies.Foe = entry["foe"]
		if _clock < float(entry["until"]) and other.alive:
			continue
		other.speed = entry["speed"]
		other.damage = entry["damage"]
		if other.alive:
			other.view.set_tint(Color.WHITE)
		rallied.remove_at(i)


# --- Tempête de runes ----------------------------------------------------------------------------------------------

func _rune_barrage(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var target: Vector3 = brain.enemies.hunter.global_position
	var count: int = int(params.get("count", 3)) + (1 if brain.phase >= 1 else 0)
	var spread: float = float(params.get("spread", 170.0)) * DraftHunter.UNIT
	var radius: float = float(params.get("radius", 110.0)) * DraftHunter.UNIT
	var offset: float = brain.enemies.rng.randf() * TAU
	for i: int in count:
		var angle: float = offset + TAU * i / maxf(count - 1, 1)
		var at: Vector3 = target if i == 0 else target + Vector3(cos(angle), 0, sin(angle)) * spread
		_seal(brain.enemies.level.closest(at), radius, pattern.telegraph + 0.1 * i, brain.damage(pattern.damage),
			float(params.get("duration", 4.0)))
	_armor_until = _clock + pattern.telegraph + float(params.get("duration", 4.0))
	brain.foe.view.set_tint(Color(0.85, 0.85, 1.1))
	brain.play_clip([StringName(str(params.get("anim", "slab_armor"))), &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.4


# --- Réveil du Panthéon --------------------------------------------------------------------------------------------

func _pantheon_wake(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var data: EnemyData = GameDB.enemy(&"awakened_statue")
	if DraftRoster.usable(data):
		var hunter: Vector3 = brain.enemies.hunter.global_position
		for i: int in int(params.get("statues", 2)):
			var angle: float = brain.enemies.rng.randf() * TAU
			var at: Vector3 = brain.enemies.level.closest(hunter + Vector3(cos(angle), 0, sin(angle)) * 6.0)
			brain.enemies.spawn(data, at)
			woken += 1
			brain.fx(&"dirt_explosion", at + Vector3.UP * 0.6, 1.6)
	brain.enemies.hazards.ring(foe.pos, clampf(float(params.get("speed", 260.0)) * DraftHunter.UNIT, 6.0, 9.0),
		clampf(float(params.get("max_radius", 650.0)) * DraftHunter.UNIT, 12.0, 22.0), pattern.telegraph,
		brain.damage(pattern.damage), brain.fx_at(&"quake", 2.2))
	brain.play_clip([StringName(str(params.get("anim", "awaken_statues"))), &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.5


# --- Chaîne d'âmes -------------------------------------------------------------------------------------------------

func _soul_chain(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	_spawn_around(StringName(str(params.get("spawn", "fallen_militia"))), int(params.get("count", 3)), 4.5)
	_seal(brain.enemies.level.closest(brain.enemies.hunter.global_position),
		float(params.get("seal_radius", 120.0)) * DraftHunter.UNIT, pattern.telegraph, brain.damage(pattern.damage), 4.0)
	_clear_links()
	var duration: float = float(params.get("duration", 6.0))
	for other: DraftEnemies.Foe in brain.enemies.near(foe.pos, float(params.get("radius", 500.0)) * DraftHunter.UNIT):
		if other.brain != null or linked.size() >= int(params.get("links", 6)):
			continue
		other.linked_mult = float(params.get("mult", 0.4))
		other.linked_left = pattern.telegraph + duration
		linked.append(other)
		_links.append(_link_node())
	_link_until = _clock + pattern.telegraph + duration
	brain.play_clip([StringName(str(params.get("anim", "soul_link"))), &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.4


func _step_links() -> void:
	if linked.is_empty():
		return
	if _clock >= _link_until:
		_clear_links()
		return
	var foe: DraftEnemies.Foe = brain.foe
	for i: int in linked.size():
		var other: DraftEnemies.Foe = linked[i]
		_links[i].visible = other.alive
		if not other.alive:
			continue
		var a: Vector3 = foe.pos + Vector3.UP
		var b: Vector3 = other.pos + Vector3.UP * 0.6
		_links[i].global_position = (a + b) * 0.5
		(_links[i].mesh as BoxMesh).size = Vector3(0.08, 0.08, maxf(a.distance_to(b), 0.1))
		if a.distance_to(b) > 0.1:
			_links[i].look_at(b, Vector3.UP)


func _link_node() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 1.0)
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = LINK
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain.enemies.add_child(node)
	return node


func _clear_links() -> void:
	for other: DraftEnemies.Foe in linked:
		other.linked_left = 0.0
	linked.clear()
	for node: MeshInstance3D in _links:
		node.queue_free()
	_links.clear()


func finish() -> void:
	for seal: Dictionary in seals:
		(seal["disc"] as Node).queue_free()
	seals.clear()
	_armor_until = 0.0
	_charge_at = -1.0
	for entry: Dictionary in rallied:
		var other: DraftEnemies.Foe = entry["foe"]
		other.speed = entry["speed"]
		other.damage = entry["damage"]
	rallied.clear()
	_clear_links()
