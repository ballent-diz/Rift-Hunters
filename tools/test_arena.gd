class_name TestArena
extends RefCounted
## Outils (captures, bot) : variante d'une arène existante pour essayer une brique de carte avant sa vraie carte.
## null si rien n'est modifié (la partie charge alors l'arène normale).


static func build(arena_id: StringName, night: bool, boss_id: StringName) -> ArenaData:
	if not night and boss_id == &"":
		return null
	var arena: ArenaData = GameDB.arena(arena_id)
	arena = arena.duplicate()
	if night:
		_add_test_night(arena)
	if boss_id != &"":
		arena.boss_id = boss_id
	return arena


## Nuit d'essai : clairières de lucioles aux points clés de la carte (zones, failles, arène finale).
static func _add_test_night(arena: ArenaData) -> void:
	arena.night = 0.85
	var glades: Array[Vector2] = []
	for zone: LevelZoneData in arena.zones:
		glades.append(zone.anchor)
	glades.append_array(arena.rift_points)
	if arena.has_finale():
		glades.append(arena.finale_center)
	if glades.is_empty():
		for i: int in 6:
			glades.append(Vector2.from_angle(TAU * i / 6.0) * 900.0)
	arena.firefly_glades = glades
