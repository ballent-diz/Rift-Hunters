class_name DecorLayout
extends RefCounted
## Placement du décor d'une arène : pur et déterministe (même graine = même décor), testable sans nœud.
## Plaques et détails sont posés à plat ; objets et forêt de bordure « debout » (point d'appui = pied).

const FLAT := 0
const STANDING := 1
## Espacement minimal entre deux objets (grille de rejet, unités du monde).
const PROP_SPACING := 28.0
## Passage minimal laissé entre deux obstacles (on ne s'enferme jamais).
const PATH_GAP := 140.0
## Zone de départ sans obstacle (en plus de clear_radius).
const START_MARGIN := 140.0


## Retourne [{decal: int, position: Vector2 (point d'appui), pass: FLAT|STANDING, outside: bool,
## colliders: Array[Vector3] (cercles en coordonnées du monde, obstacles et eau)}],
## trié dans l'ordre d'affichage (à plat d'abord, puis debout du haut vers le bas de l'écran).
static func generate(env: EnvironmentSet, arena: Rect2, seed_value: int, density_mult: float = 1.0) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.0025
	var out: Array[Dictionary] = []
	var inner: Rect2 = arena.grow(-12.0)
	var area: float = inner.get_area() / 1000000.0
	var occupied: Dictionary = {}
	var blockers: Array[Vector3] = []
	for layer: StringName in [&"water", &"obstacle"]:
		_place_obstacles(env, layer, arena.grow(-60.0), rng, density_mult, area, blockers, out)
	for layer: StringName in [&"patch", &"detail", &"prop"]:
		var pool: Array[int] = env.decals_in(layer)
		if pool.is_empty():
			continue
		var count: int = roundi(float(env.density.get(String(layer), 0.0)) * area * maxf(density_mult, 0.0))
		for i: int in count:
			var pos: Vector2 = _pick_position(rng, noise, inner, layer != &"patch")
			if _near_blocker(pos, blockers, 14.0):
				continue
			if layer == &"prop":
				if pos.length() < env.clear_radius:
					continue
				var cell := Vector2i(floori(pos.x / PROP_SPACING), floori(pos.y / PROP_SPACING))
				if occupied.has(cell):
					continue
				occupied[cell] = true
			out.append({"decal": _pick(rng, env, pool), "position": pos.round(),
				"pass": STANDING if layer == &"prop" else FLAT, "outside": false, "colliders": _none()})
	_border(env, arena, rng, out)
	out.sort_custom(_before)
	return out


## Obstacles et eau : espacés d'au moins PATH_GAP (toujours un passage), hors de la zone de départ.
static func _place_obstacles(env: EnvironmentSet, layer: StringName, rect: Rect2, rng: RandomNumberGenerator,
		density_mult: float, area: float, blockers: Array[Vector3], out: Array[Dictionary]) -> void:
	var pool: Array[int] = env.decals_in(layer)
	if pool.is_empty():
		return
	var count: int = roundi(float(env.density.get(String(layer), 0.0)) * area * maxf(density_mult, 0.0))
	for i: int in count:
		for attempt: int in 10:
			var index: int = _pick(rng, env, pool)
			var decal: Dictionary = env.decals[index]
			var pos := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)).round()
			var circles: Array[Vector3] = []
			var ok: bool = true
			for c: Vector3 in decal["collision"]:
				var world := Vector3(pos.x + c.x, pos.y + c.y, c.z)
				var center := Vector2(world.x, world.y)
				if center.length() < env.clear_radius + START_MARGIN + world.z or not rect.has_point(center) \
						or _near_blocker(center, blockers, world.z + PATH_GAP):
					ok = false
					break
				circles.append(world)
			if not ok:
				continue
			blockers.append_array(circles)
			out.append({"decal": index, "position": pos, "pass": FLAT if layer == &"water" else STANDING,
				"outside": false, "colliders": circles})
			break


static func _none() -> Array[Vector3]:
	return []


static func _near_blocker(pos: Vector2, blockers: Array[Vector3], margin: float) -> bool:
	for c: Vector3 in blockers:
		if Vector2(pos.x - c.x, pos.y - c.y).length() < c.z + margin:
			return true
	return false


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["pass"] != b["pass"]:
		return a["pass"] < b["pass"]
	return (a["position"] as Vector2).y < (b["position"] as Vector2).y


## Les détails et objets se regroupent en bosquets (bruit basse fréquence) et laissent des clairières.
static func _pick_position(rng: RandomNumberGenerator, noise: FastNoiseLite, rect: Rect2, clustered: bool) -> Vector2:
	var pos := Vector2.ZERO
	for attempt: int in 12:
		pos = Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if not clustered:
			return pos
		var n: float = (noise.get_noise_2dv(pos) + 1.0) * 0.5
		if rng.randf() < 0.15 + 0.85 * n * n:
			return pos
	return pos


static func _pick(rng: RandomNumberGenerator, env: EnvironmentSet, pool: Array[int]) -> int:
	var total: float = 0.0
	for index: int in pool:
		total += float(env.decals[index]["weight"])
	var roll: float = rng.randf() * total
	for index: int in pool:
		roll -= float(env.decals[index]["weight"])
		if roll <= 0.0:
			return index
	return pool[pool.size() - 1]


## Forêt dense hors de l'arène, rangées décalées ; chaque élément reste entièrement à l'extérieur.
static func _border(env: EnvironmentSet, arena: Rect2, rng: RandomNumberGenerator, out: Array[Dictionary]) -> void:
	var pool: Array[int] = env.decals_in(&"border")
	if pool.is_empty() or env.border_width <= 0.0:
		return
	var rows: int = maxi(1, ceili(env.border_width / (env.border_spacing * 1.05)))
	var reach: float = env.border_width
	for side: int in 4:
		var horizontal: bool = side < 2
		var from: float = (arena.position.x if horizontal else arena.position.y) - reach
		var to: float = (arena.end.x if horizontal else arena.end.y) + reach
		var t: float = from
		while t < to:
			for row: int in rows:
				var index: int = _pick(rng, env, pool)
				var decal: Dictionary = env.decals[index]
				var size: Vector2 = (decal["region"] as Rect2).size * env.pixel_scale
				var anchor: Vector2 = (decal["anchor"] as Vector2) * env.pixel_scale
				var depth: float = 3.0 + row * env.border_spacing * 1.05 + rng.randf_range(0.0, 8.0)
				var along: float = t + row * env.border_spacing * 0.37 + rng.randf_range(-6.0, 6.0)
				var pos := Vector2.ZERO
				match side:
					0:  # nord : l'arbre pousse vers le haut, hors de l'arène
						pos = Vector2(along, arena.position.y - depth)
					1:  # sud : le pied est assez bas pour que la cime reste dehors
						pos = Vector2(along, arena.end.y + anchor.y + depth)
					2:  # ouest
						pos = Vector2(arena.position.x - depth - size.x * 0.5, along)
					_:  # est
						pos = Vector2(arena.end.x + depth + size.x * 0.5, along)
				out.append({"decal": index, "position": pos.round(), "pass": STANDING, "outside": true,
					"colliders": _none()})
			t += env.border_spacing * rng.randf_range(0.8, 1.25)
