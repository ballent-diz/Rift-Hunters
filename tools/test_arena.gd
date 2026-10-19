class_name TestArena
extends RefCounted
## Outils (captures, bot) : variante d'une arène existante pour essayer une brique de carte avant sa vraie carte.
## null si rien n'est modifié (la partie charge alors l'arène normale).


static func build(arena_id: StringName, night: bool, boss_id: StringName, altar: bool = false,
		shallows: bool = false) -> ArenaData:
	if not night and boss_id == &"" and not altar and not shallows:
		return null
	var arena: ArenaData = GameDB.arena(arena_id)
	arena = arena.duplicate()
	if night:
		_add_test_night(arena)
	if boss_id != &"":
		arena.boss_id = boss_id
	if altar:
		# Défense d'autel d'essai (Plaine fracturée conseillée) : sceau au centre, gardien du Bois à la fin.
		arena.altar_waves = 5
		arena.altar_point = Vector2.ZERO
		if boss_id == &"":
			arena.boss_id = &"root_sentinel"
	if shallows:
		# Gués d'essai : trois bandes d'eau peu profonde autour du centre de la carte.
		var bands: Array[Rect2] = [Rect2(-700, -420, 1400, 160), Rect2(-700, 260, 1400, 160), Rect2(-160, -160, 320, 320)]
		arena.slow_zones = bands
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
