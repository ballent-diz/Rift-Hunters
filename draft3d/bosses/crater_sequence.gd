class_name DraftCraterSequence
extends DraftBossMechanic
## Séquence des cratères, mécanique phare de Pyrevorn (chapitre 2, docs/design/MONSTRES.md), reprise de
## `BossSignatures.crater_sequence` pour le monde 3D : une grille de 3 × 3 cases se pose autour du Chasseur ; des cases
## s'allument une à une puis entrent en éruption dans le même ordre, à peine annoncées (un éclair juste avant). Il faut
## retenir lesquelles et quand. Le boss se concentre pendant l'allumage.
## Gardiens de palier (CARTES.md, carte 10) : à son passage en seconde phase, Pyrevorn appelle le Titan de caldeira
## et le Wyrmeau de flammes, élites en version boss.

const EMBER := Color(1.0, 0.45, 0.12)
const SHOW_ALPHA := 0.75
## Éclair qui précède chaque éruption (s), le seul rappel une fois les cases éteintes.
const FLASH := 0.2
## Flaque de lave laissée par chaque éruption : part de la case, durée (s).
const LAVA_RATIO := 0.3
const LAVA_TIME := 3.5
## Escorte de seconde phase : élite, PV (multiple de ses PV d'origine), taille.
const ESCORTS := [[&"caldera_titan", 4.0, 1.6], [&"flame_wyrmling", 4.0, 1.7]]

## Cases de la grille (centres) et étapes : {"cell", "lit_at", "erupt_at", "done"}.
var cells: Array[Vector3] = []
var steps: Array[Dictionary] = []
var cell_size: float = 7.8
var eruptions: int = 0
var escorts: Array[DraftEnemies.Foe] = []
var _clock: float = 0.0
var _damage: float = 0.0
var _tiles: Array[MeshInstance3D] = []


func handles(kind: StringName) -> bool:
	return kind == &"crater_sequence"


func perform(pattern: BossPatternData) -> float:
	_clear()
	var params: Dictionary = pattern.params
	var grid: int = int(params.get("grid", 3))
	cell_size = float(params.get("cell", 260.0)) * DraftHunter.UNIT
	var count: int = mini(int(params.get("steps", 4)), grid * grid)
	var show_gap: float = float(params.get("show_gap", 0.55))
	var erupt_gap: float = float(params.get("erupt_gap", 0.9))
	var center: Vector3 = brain.enemies.level.closest(brain.enemies.hunter.global_position)
	var half: float = (grid - 1) * cell_size * 0.5
	for y: int in grid:
		for x: int in grid:
			var at: Vector3 = brain.enemies.level.closest(center + Vector3(x * cell_size - half, 0, y * cell_size - half))
			cells.append(at)
			_tiles.append(_tile(at))
	var order: Array[int] = []
	for i: int in cells.size():
		order.append(i)
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = brain.enemies.rng.randi() % (i + 1)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	var lights_end: float = _clock + pattern.telegraph + count * show_gap
	for k: int in count:
		steps.append({"cell": order[k], "lit_at": _clock + pattern.telegraph + k * show_gap, "lit_for": show_gap * 0.8,
			"erupt_at": lights_end + float(params.get("pause", 0.6)) + k * erupt_gap, "done": false})
	_damage = brain.damage(pattern.damage)
	brain.play_clip([StringName(str(params.get("anim", "crater_rain"))), &"attack"], lights_end - _clock)
	intro("BOSS_CRATER_INTRO")
	return lights_end - _clock + 0.2


func active() -> bool:
	return not steps.is_empty()


func on_phase(index: int) -> void:
	if index != 1:
		return
	var foe: DraftEnemies.Foe = brain.foe
	for k: int in ESCORTS.size():
		var data: EnemyData = GameDB.enemy(ESCORTS[k][0])
		if not DraftRoster.usable(data):
			continue
		var angle: float = TAU * k / ESCORTS.size() + brain.enemies.rng.randf()
		var at: Vector3 = brain.enemies.level.closest(foe.pos + Vector3(cos(angle), 0, sin(angle)) * 5.0)
		var escort: DraftEnemies.Foe = brain.enemies.spawn(data, at, float(ESCORTS[k][2]))
		escort.max_hp *= float(ESCORTS[k][1])
		escort.hp = escort.max_hp
		escort.damage *= 1.3
		escorts.append(escort)
		brain.fx(&"summon_rise", at + Vector3.UP * 0.6, 2.0)


func step(delta: float) -> void:
	_clock += delta
	if steps.is_empty():
		return
	var lit: Dictionary = {}
	var flashing: Dictionary = {}
	var all_done: bool = true
	for entry: Dictionary in steps:
		var index: int = entry["cell"]
		if _clock >= float(entry["lit_at"]) and _clock < float(entry["lit_at"]) + float(entry["lit_for"]):
			lit[index] = true
		if entry["done"]:
			continue
		all_done = false
		if _clock >= float(entry["erupt_at"]) - FLASH:
			flashing[index] = true
		if _clock >= float(entry["erupt_at"]):
			entry["done"] = true
			_erupt(cells[index])
	for i: int in _tiles.size():
		var material: StandardMaterial3D = _tiles[i].material_override
		var alpha: float = 0.12
		if lit.has(i):
			alpha = SHOW_ALPHA
		elif flashing.has(i):
			alpha = 0.45
		material.albedo_color = Color(EMBER, alpha)
	if all_done and _clock > float(steps.back()["erupt_at"]) + 0.4:
		_clear()


func _erupt(at: Vector3) -> void:
	eruptions += 1
	var hunter: DraftHunter = brain.enemies.hunter
	var offset: Vector3 = hunter.global_position - at
	var half: float = cell_size * 0.5 - DraftHunter.RADIUS * 0.3
	if absf(offset.x) <= half and absf(offset.z) <= half and absf(offset.y) <= DraftHazards.REACH_UP:
		if hunter.take_damage(_damage) > 0.0:
			brain.enemies.run.call("on_hunter_hit", brain.foe)
	brain.fx(&"flame_pillar", at + Vector3.UP * 0.8, cell_size * 0.35)
	Audio.play_sfx(&"detonation")
	# Le cratère laisse une flaque de lave quelques secondes (ralentit et brûle) : la grille se referme peu à peu.
	brain.enemies.hazards.zone(at, cell_size * LAVA_RATIO, LAVA_TIME, _damage * 0.2, 0.75)


func _tile(at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell_size * 0.94, 0.04, cell_size * 0.94)
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(EMBER, 0.12)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain.enemies.add_child(node)
	node.global_position = at + Vector3.UP * 0.07
	return node


func _clear() -> void:
	for tile: MeshInstance3D in _tiles:
		tile.queue_free()
	_tiles.clear()
	cells.clear()
	steps.clear()


func finish() -> void:
	_clear()
