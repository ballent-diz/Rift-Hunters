extends TestCase
## Passages des cartes dessinées (collisions peintes à la main par le propriétaire, docs/maps/DE_L_IMAGE_AU_NIVEAU.md) :
## chaque lieu clé est atteignable depuis le départ avec le gabarit d'une élite, et les obstacles peints le restent.

const ELITE_RADIUS := 24.0
const STEP := 16.0


## Parcours en largeur sur une grille de STEP unités, avec la marge `radius` aux obstacles.
static func reachable(field: ObstacleField, rect: Rect2, from: Vector2, targets: Array[Vector2], radius: float) -> Array[bool]:
	var size := Vector2i(ceili(rect.size.x / STEP), ceili(rect.size.y / STEP))
	var seen := PackedByteArray()
	seen.resize(size.x * size.y)
	var cell := func(p: Vector2) -> Vector2i: return Vector2i(((p - rect.position) / STEP).floor())
	var start: Vector2i = cell.call(from)
	var queue: Array[Vector2i] = [start]
	seen[start.y * size.x + start.x] = 1
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = c + n
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y or seen[next.y * size.x + next.x]:
				continue
			if field.blocks(rect.position + (Vector2(next) + Vector2(0.5, 0.5)) * STEP, radius):
				continue
			seen[next.y * size.x + next.x] = 1
			queue.append(next)
	var result: Array[bool] = []
	for target: Vector2 in targets:
		var t: Vector2i = cell.call(target)
		result.append(seen[t.y * size.x + t.x] == 1)
	return result


func _check(id: StringName, places: Dictionary) -> void:
	var arena: ArenaData = GameDB.arena(id)
	var ground := ArenaGround.new()
	ground.setup(arena, 7)
	var field: ObstacleField = ground.obstacle_field()
	var targets: Array[Vector2] = []
	targets.assign(places.values())
	var ok: Array[bool] = reachable(field, ground.arena_rect(), ground.player_start(), targets, ELITE_RADIUS)
	var names: Array = places.keys()
	for i: int in ok.size():
		check(ok[i], "%s : %s atteignable par une élite" % [id, names[i]])
	ground.free()


func test_storm_highlands_landmarks_are_reachable() -> void:
	_check(&"storm_highlands", {"place centrale": Vector2(-11, -323), "cour du bas": Vector2(167, 1505),
		"sanctuaire": Vector2(1710, -225), "champ de basalte": Vector2(-1605, 752), "menhirs": Vector2(-11, -1928)})


func test_three_rifts_landmarks_are_reachable() -> void:
	_check(&"three_rifts", {"zone 1": Vector2(-1648, -136), "zone 2": Vector2(154, -144), "arène": Vector2(1960, 31),
		"pont": Vector2(1030, 16), "escalier nord de l'arène": Vector2(1452, -196),
		"bout du pont": Vector2(1332, 16), "escalier sud de l'arène": Vector2(1512, 324)})


func test_painted_obstacles_stay_blocked() -> void:
	var storm: ArenaData = GameDB.arena(&"storm_highlands")
	var ground := ArenaGround.new()
	ground.setup(storm, 7)
	check(ground.obstacle_field().blocks(Vector2(.035, .67) * storm.size - storm.size * .5, 14), "lave périphérique infranchissable")
	var center: Vector2 = Vector2(.18, .65) * storm.size - storm.size * .5
	for index: int in 40:
		var point: Vector2 = center + Vector2.from_angle(TAU * index / 40) * 160
		check(not ground.obstacle_field().blocks(point, ELITE_RADIUS), "tourner sur le basalte avec une élite")
	ground.free()
