class_name ArenaGround
extends Node2D
## Sol et décor de l'arène. Avec un décor dans le manifeste : sol périodique en pixel art, éléments posés par
## DecorLayout, forêt de bordure, assombrissement hors limites et particules d'ambiance. Sinon : sol de
## remplacement dessiné en code. Tout est dessiné une seule fois, en blocs que le moteur n'affiche que s'ils
## sont à l'écran.

const CHUNK := 512.0
## Sol dessiné au-delà de la bordure (ce que la caméra peut montrer près d'un bord).
const OUTSIDE_MARGIN := 700.0
const OUTSIDE_MODULATE := Color(0.7, 0.78, 0.76)

var arena: ArenaData
var seed_value: int = 0
var environment: EnvironmentSet
var placements: Array[Dictionary] = []
var _ambient: CPUParticles2D


func setup(p_arena: ArenaData, p_seed: int) -> void:
	arena = p_arena
	seed_value = p_seed
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	environment = Assets.environment(arena.environment_id)
	if environment != null:
		if environment.smooth:
			texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if not environment.is_map():
			placements = DecorLayout.generate(environment, arena_rect(), seed_value, arena.decor_density)
			_build_chunks()
		_build_ambient()
	queue_redraw()


## Champ d'obstacles infranchissables du décor (vide sans décor).
func obstacle_field() -> ObstacleField:
	var field := ObstacleField.new()
	if environment != null and environment.is_map():
		field.set_distance_field(environment.field_image, arena_rect(), environment.field_step)
	for item: Dictionary in placements:
		for c: Vector3 in item.get("colliders", []):
			field.add(Vector2(c.x, c.y), c.z)
	return field


## Point de départ du joueur : dégagé sur une map dessinée, sinon le centre de l'arène.
func player_start() -> Vector2:
	return environment.start if environment != null and environment.is_map() else Vector2.ZERO


func uses_placeholder() -> bool:
	return environment == null


func arena_rect() -> Rect2:
	var half: Vector2 = arena.size * 0.5
	return Rect2(-half, arena.size)


func _process(_delta: float) -> void:
	if _ambient == null:
		return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		_ambient.global_position = camera.get_screen_center_position()


func _draw() -> void:
	if environment == null:
		_draw_placeholder()
		return
	var rect: Rect2 = arena_rect()
	if environment.is_map():
		# Arène dessinée : la map couvre exactement l'arène (la caméra ne montre rien au-delà).
		draw_rect(rect.grow(OUTSIDE_MARGIN), Color(0.03, 0.06, 0.04))
		if environment.map_tiles.is_empty():
			draw_texture_rect(environment.map_texture, rect, false)
		else:
			var tile_size := Vector2(rect.size.x / environment.map_tiles.size(), rect.size.y)
			for i: int in environment.map_tiles.size():
				var tile_rect := Rect2(rect.position + Vector2(i * tile_size.x, 0), tile_size)
				draw_texture_rect(environment.map_tiles[i], tile_rect, false)
		return
	var area: Rect2 = rect.grow(environment.border_width + OUTSIDE_MARGIN)
	var s: float = environment.pixel_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_texture_rect(environment.ground, Rect2(area.position / s, area.size / s), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Hors limites : sol assombri (bande adoucie contre la lisière, puis teinte pleine).
	var tint: Color = environment.outside_tint
	_draw_frame(rect.grow(24.0), area, tint)
	_draw_frame(rect, rect.grow(24.0), Color(tint, tint.a * 0.5))


func _draw_frame(inner: Rect2, outer: Rect2, color: Color) -> void:
	draw_rect(Rect2(outer.position, Vector2(outer.size.x, inner.position.y - outer.position.y)), color)
	draw_rect(Rect2(Vector2(outer.position.x, inner.end.y), Vector2(outer.size.x, outer.end.y - inner.end.y)), color)
	draw_rect(Rect2(Vector2(outer.position.x, inner.position.y), Vector2(inner.position.x - outer.position.x, inner.size.y)), color)
	draw_rect(Rect2(Vector2(inner.end.x, inner.position.y), Vector2(outer.end.x - inner.end.x, inner.size.y)), color)


## Regroupe les éléments par bloc de CHUNK unités : d'abord tout ce qui est à plat, puis ce qui est debout
## (blocs ajoutés du haut vers le bas pour que les objets du bas recouvrent ceux du haut).
func _build_chunks() -> void:
	for pass_index: int in [DecorLayout.FLAT, DecorLayout.STANDING]:
		var chunks: Dictionary = {}
		for item: Dictionary in placements:
			if item["pass"] != pass_index:
				continue
			var pos: Vector2 = item["position"]
			var key := Vector2i(floori(pos.x / CHUNK), floori(pos.y / CHUNK))
			if not chunks.has(key):
				var list: Array[Dictionary] = []
				chunks[key] = list
			(chunks[key] as Array[Dictionary]).append(item)
		var keys: Array = chunks.keys()
		keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		for key: Vector2i in keys:
			var chunk := DecorChunk.new()
			chunk.env = environment
			chunk.items = chunks[key]
			add_child(chunk)


func _build_ambient() -> void:
	if environment.ambient_amount <= 0:
		return
	_ambient = CPUParticles2D.new()
	_ambient.z_index = 2
	_ambient.amount = environment.ambient_amount
	_ambient.lifetime = 7.0
	_ambient.preprocess = 7.0
	_ambient.local_coords = false
	_ambient.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ambient.emission_rect_extents = Vector2(620.0, 380.0)
	_ambient.direction = Vector2(0.35, -1.0)
	_ambient.spread = 35.0
	_ambient.gravity = Vector2.ZERO
	_ambient.initial_velocity_min = 5.0
	_ambient.initial_velocity_max = 13.0
	_ambient.scale_amount_min = 1.0
	_ambient.scale_amount_max = 2.0
	var ramp := Gradient.new()
	var base: Color = environment.ambient_color
	ramp.set_color(0, Color(base, 0.0))
	ramp.set_color(1, Color(base, 0.0))
	ramp.add_point(0.25, Color(base, base.a * 0.7))
	ramp.add_point(0.75, Color(base, base.a * 0.7))
	_ambient.color_ramp = ramp
	add_child(_ambient)


## Sol de remplacement (arène sans décor) : dalles sombres, fissures de faille et bordure.
func _draw_placeholder() -> void:
	var rect: Rect2 = arena_rect()
	var half: Vector2 = arena.size * 0.5
	draw_rect(rect.grow(600.0), Color(0.03, 0.03, 0.06))
	draw_rect(rect, arena.ground_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tile: float = 160.0
	var x: float = -half.x
	while x < half.x:
		var y: float = -half.y
		while y < half.y:
			if rng.randf() < 0.35:
				draw_rect(Rect2(x + 4, y + 4, tile - 8, tile - 8), Color(arena.ground_detail_color, rng.randf_range(0.15, 0.35)))
			y += tile
		x += tile
	for i: int in 90:
		var start := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		var points := PackedVector2Array([start])
		var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
		for s: int in rng.randi_range(3, 7):
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			points.append(points[points.size() - 1] + dir * rng.randf_range(18.0, 46.0))
		draw_polyline(points, Color(0.45, 0.25, 0.75, rng.randf_range(0.15, 0.35)), 2.0)
	for i: int in 40:
		var pos := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		draw_circle(pos, rng.randf_range(2.0, 5.0), Color(0.6, 0.4, 1.0, 0.25))
	draw_rect(rect, Color(0.55, 0.3, 0.9, 0.9), false, 6.0)


## Bloc d'éléments de décor, dessiné une seule fois.
class DecorChunk:
	extends Node2D

	var env: EnvironmentSet
	var items: Array[Dictionary] = []

	func _draw() -> void:
		var s: float = env.pixel_scale
		for item: Dictionary in items:
			var decal: Dictionary = env.decals[int(item["decal"])]
			var region: Rect2 = decal["region"]
			var top_left: Vector2 = (item["position"] as Vector2) - (decal["anchor"] as Vector2) * s
			var tint: Color = OUTSIDE_MODULATE if item["outside"] else Color.WHITE
			draw_texture_rect_region(env.atlas, Rect2(top_left, region.size * s), region, tint)
