class_name TestArena
extends RefCounted
## Outils (captures, bot) : variante d'une arène existante pour essayer une brique de carte avant sa vraie carte.
## null si rien n'est modifié (la partie charge alors l'arène normale).


## Briques d'essai, activées par les options du même nom (--night, --altar...).
const FEATURES: Array[String] = ["night", "altar", "shallows", "rivers"]


static func build(arena_id: StringName, boss_id: StringName, features: Array[String]) -> ArenaData:
	if boss_id == &"" and features.is_empty():
		return null
	var arena: ArenaData = GameDB.arena(arena_id)
	arena = arena.duplicate()
	if features.has("night"):
		_add_test_night(arena)
	if boss_id != &"":
		arena.boss_id = boss_id
	if features.has("altar"):
		# Défense d'autel d'essai (Plaine fracturée conseillée) : sceau au centre, gardien du Bois à la fin.
		arena.altar_waves = 5
		arena.altar_point = Vector2.ZERO
		if boss_id == &"":
			arena.boss_id = &"root_sentinel"
	if features.has("shallows"):
		# Gués d'essai : trois bandes d'eau peu profonde autour du centre de la carte.
		var bands: Array[Rect2] = [Rect2(-700, -420, 1400, 160), Rect2(-700, 260, 1400, 160), Rect2(-160, -160, 320, 320)]
		arena.slow_zones = bands
	if features.has("rivers"):
		_add_test_rivers(arena)
	return arena


## Carte 5 d'essai (Plaine fracturée conseillée) : deux lits de crue qui se croisent et un courant en bas.
static func _add_test_rivers(arena: ArenaData) -> void:
	var half: Vector2 = arena.size * 0.5
	var lanes: Array[Rect2] = [Rect2(-half.x, -300, arena.size.x, 150), Rect2(150, -half.y, 150, arena.size.y)]
	var lane_dirs: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN]
	arena.flood_lanes = lanes
	arena.flood_dirs = lane_dirs
	arena.flood_first = 15.0
	var currents: Array[Rect2] = [Rect2(-half.x, 330, arena.size.x, 130)]
	var current_dirs: Array[Vector2] = [Vector2.LEFT]
	arena.currents = currents
	arena.current_dirs = current_dirs


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
