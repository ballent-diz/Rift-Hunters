class_name DraftAbyssEchoes
extends DraftBossMechanic
## Échos des mondes, mécanique phare de l'Abyssarque (chapitre 5, docs/design/MONSTRES.md), reprise de
## `BossController._pattern_abyss_echoes` pour le monde 3D : à chaque fois, le Dévoreur final rappelle un des mondes
## traversés (Ruines, cendres, marais, glacier, Cité, dans l'ordre) : des Corrompus de ce monde surgissent autour de
## lui, annoncés, et une onde part de son œil. Ses six formes (feuilles, entrées, techniques) passent par le socle.

const RIFT := Color(0.9, 0.35, 1.0, 0.45)

var world: int = 0
var summoned: int = 0
## Apparitions annoncées : {"pos", "id", "at", "disc"}.
var pending: Array[Dictionary] = []
var _clock: float = 0.0


func handles(kind: StringName) -> bool:
	return kind == &"abyss_echoes"


func perform(pattern: BossPatternData) -> float:
	var params: Dictionary = pattern.params
	var worlds: Array = params.get("worlds", [])
	var foe: DraftEnemies.Foe = brain.foe
	if not worlds.is_empty():
		var ids: Array = worlds[world % worlds.size()]
		world += 1
		var count: int = int(params.get("count", 4)) + mini(int(brain.phase * 0.5), 2)
		var spread: float = clampf(float(params.get("spread", 320.0)) * DraftHunter.UNIT, 4.0, 11.0)
		var offset: float = brain.enemies.rng.randf() * TAU
		for i: int in count:
			var at: Vector3 = brain.enemies.level.closest(foe.pos + Vector3(cos(offset + TAU * i / count), 0,
				sin(offset + TAU * i / count)) * spread)
			pending.append({"pos": at, "id": StringName(str(ids[i % ids.size()])), "at": _clock + pattern.telegraph,
				"disc": make_disc(at, 0.9, RIFT)})
	brain.enemies.hazards.ring(foe.pos, clampf(float(params.get("speed", 280.0)) * DraftHunter.UNIT, 6.0, 10.0),
		clampf(float(params.get("max_radius", 900.0)) * DraftHunter.UNIT, 14.0, 28.0), pattern.telegraph,
		brain.damage(pattern.damage), brain.fx_at(&"ring_burst", 2.5))
	brain.play_clip([StringName(str(params.get("anim", "attack"))), &"summon", &"attack"], pattern.telegraph)
	return pattern.telegraph + 0.5


func step(delta: float) -> void:
	_clock += delta
	for i: int in range(pending.size() - 1, -1, -1):
		var entry: Dictionary = pending[i]
		if _clock < float(entry["at"]):
			continue
		(entry["disc"] as Node).queue_free()
		pending.remove_at(i)
		var data: EnemyData = GameDB.enemy(entry["id"])
		if not DraftRoster.usable(data):
			continue
		brain.enemies.spawn(data, entry["pos"])
		summoned += 1
		brain.fx(&"summon_rise", (entry["pos"] as Vector3) + Vector3.UP * 0.5, 1.2)


func finish() -> void:
	for entry: Dictionary in pending:
		(entry["disc"] as Node).queue_free()
	pending.clear()
