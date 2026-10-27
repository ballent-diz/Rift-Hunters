extends Node2D
## Présentation autonome : le combat fournit les points, dimensions et événements confirmés.
## Aucune collision, cible, apparition, altération ou résolution de dégâts ici.
signal visual_finished

const Stroke = preload("res://assets/vfx/echoes/painted_stroke.gd")
const Shapes = preload("res://assets/vfx/hunter/effects_common.gd")
const Paint = preload("res://assets/vfx/enemies/chapter3/painted_ribbon.gd")
const INK := Color("102833")
const WARNING := Color("f19983")
const WHITE := Color("ecfff7")
const ROOT := Color("565d39")
const BRUSH_SOURCE = preload("res://assets/vfx/hunter/cleaving_slash/textures/blade-ribbon.png")

static var _shared_brush: Texture2D

@export var effect_kind: StringName = &"splash"
@export_enum("organic", "crystal", "ice") var surface: String = "organic"
@export var color := Color("40c6bd")
@export var accent := Color("c9f2ed")
@export var radius: float = 80.0
@export var width: float = 24.0
@export var travel_distance: float = 240.0
@export var visual_duration: float = 0.8
@export var half_angle_degrees: float = 40.0
@export var target_shape: StringName = &"area"
@export_range(0, 32) var particle_budget: int = 16
@export var loop_visual: bool = false
@export var destroy_on_finish: bool = true
var secondary_offsets := PackedVector2Array()
var path_points := PackedVector2Array()
var facet_strengths := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
var strength: float = 1.0
var stage: float = 0.0
var _elapsed: float = 0.0
var _playing: bool = false
var _releasing: bool = false
var _release_age: float = 0.0
var _finished: bool = false
var _visible_time: bool = false
var _facet_vertices := PackedVector2Array()
var _facet_colors := PackedColorArray()
var _facet_indices := PackedInt32Array()


func _ready() -> void:
	z_index = 100 if effect_kind == &"indicator" else 1
	if effect_kind != &"indicator" and _shared_brush == null:
		# Même matière peinte que le Chasseur, neutralisée pour garder la palette du monstre.
		# Une seule préparation partagée, jamais de traitement d'image par frame ou par particule.
		var image: Image = BRUSH_SOURCE.get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(256, 96, Image.INTERPOLATE_LANCZOS)
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel: Color = image.get_pixel(x, y)
				var opacity: float = pixel.a * sqrt(pixel.get_luminance())
				image.set_pixel(x, y, Color(1, 1, 1, opacity if opacity >= 0.035 else 0.0))
		# Le ruban source a de larges marges transparentes : les retirer évite les filaments.
		image = image.get_region(image.get_used_rect())
		image.resize(256, 96, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		_shared_brush = ImageTexture.create_from_image(image)


func duration() -> float:
	return maxf(visual_duration, 0.05)


func play(direction: Vector2 = Vector2.RIGHT) -> void:
	rotation = direction.angle() if direction.length_squared() > 0.0001 else 0.0
	_elapsed = 0.0
	_release_age = 0.0
	_releasing = false
	_finished = false
	_visible_time = true
	_playing = true
	queue_redraw()


func play_from(seconds: float, direction: Vector2 = Vector2.RIGHT) -> void:
	play(direction)
	_elapsed = clampf(seconds, 0.0, duration())
	queue_redraw()


func seek_visual(seconds: float) -> void:
	_elapsed = clampf(seconds, 0.0, duration())
	_playing = false
	_releasing = false
	_finished = false
	_visible_time = true
	queue_redraw()


## Points LOCAUX déjà tronqués/réfléchis par le combat ; aucune recherche d'obstacle ici.
func set_path_local(points: PackedVector2Array) -> void:
	path_points = points.slice(0, 64)
	queue_redraw()


func set_secondary_offsets(points: PackedVector2Array) -> void:
	secondary_offsets = points.slice(0, 8)
	queue_redraw()


## Intensité d'armure et stade de durcissement fournis par les données de jeu.
func set_visual_state(value: float, hardening: float = 0.0) -> void:
	strength = clampf(value, 0.0, 1.0)
	stage = clampf(hardening, 0.0, 1.0)
	queue_redraw()


func set_facet_strengths(values: PackedFloat32Array) -> void:
	for i: int in 4:
		facet_strengths[i] = clampf(values[i], 0.0, 1.0) if i < values.size() else 0.0
	queue_redraw()


func release() -> void:
	if _finished or _releasing:
		return
	_releasing = true
	_release_age = 0.0
	_playing = true


func _process(delta: float) -> void:
	if not _playing or _finished:
		return
	_elapsed += maxf(delta, 0.0)
	if _releasing:
		_release_age += maxf(delta, 0.0)
		if _release_age >= 0.22:
			_finish()
	elif _elapsed >= duration() and not loop_visual:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_playing = false
	_visible_time = false
	visual_finished.emit()
	if destroy_on_finish:
		queue_free()


func _draw() -> void:
	if not _visible_time or _finished:
		return
	_facet_vertices.clear()
	_facet_colors.clear()
	_facet_indices.clear()
	var p: float = fposmod(_elapsed, duration()) / duration() if loop_visual else \
		clampf(_elapsed / duration(), 0.0, 1.0)
	var fade: float = 1.0 if loop_visual else 1.0 - smoothstep(0.65, 1.0, p)
	if _releasing:
		fade *= 1.0 - clampf(_release_age / 0.22, 0.0, 1.0)
	match effect_kind:
		&"indicator": _indicator(p, fade)
		&"projectile": _projectile(p, fade)
		&"splash", &"frost": _splash(p, fade)
		&"roots", &"leash": _roots(p, fade)
		&"spores", &"heal": _spores(p, fade)
		&"mark": _mark(p, fade)
		&"shield", &"facets": _shield(p, fade)
		&"blink", &"clones": _blink(p, fade)
		&"mirror": _mirror(p, fade)
		&"beam": _beam(p, fade)
		&"shards", &"burst": _burst(p, fade)
		&"rage", &"weakness": _pulse(p, fade)
		&"swallow": _swallow(p, fade)
		&"mud_wall": _mud_wall(p, fade)
		&"whirlpool": _whirlpool(p, fade)
		&"tide": _tide(p, fade)
		&"claw": _claw(p, fade)
	if not _facet_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
			_facet_indices, _facet_vertices, _facet_colors)


func _stroke(points: PackedVector2Array, size: float, ink: Color,
		light: Color, fade: float) -> void:
	var brush: Texture2D = _shared_brush if size >= 4.0 and effect_kind != &"indicator" else null
	if brush != null:
		Paint.stroke(self, points, maxf(size, 0.1), ink, light, fade, brush)
	else:
		Stroke.stroke(self, points, maxf(size, 0.1), ink, light, fade)


## Tous les éclats d'une scène partagent une commande, sans nœud par fragment.
func _facet(center: Vector2, angle: float, length: float, size: float,
		ink: Color, light: Color, opacity: float = 1.0) -> void:
	if length < 0.1 or size < 0.1 or opacity < 0.003:
		return
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	var nose: Vector2 = center + along * length * 0.55
	var tail: Vector2 = center - along * length * 0.45
	var left: Vector2 = center + across * size * 0.5
	var right: Vector2 = center - across * size * 0.5
	var offset: int = _facet_vertices.size()
	_facet_vertices.append_array(PackedVector2Array([tail, left, nose, tail, right, nose]))
	for i: int in 3:
		_facet_colors.append(Color(ink, opacity))
	for i: int in 3:
		_facet_colors.append(Color(light, opacity))
	for i: int in 6:
		_facet_indices.append(offset + i)
	# Arête claire incluse dans le même maillage, plutôt qu'une ligne de plus par éclat.
	var ridge: Vector2 = across * 0.48
	offset = _facet_vertices.size()
	_facet_vertices.append_array(PackedVector2Array([tail - ridge, nose - ridge,
		nose + ridge, tail + ridge]))
	for i: int in 4:
		_facet_colors.append(Color(light.lerp(WHITE, 0.5), opacity))
	_facet_indices.append_array(PackedInt32Array([offset, offset + 1, offset + 2,
		offset, offset + 2, offset + 3]))


## Accent de contact immédiat ; les dégâts ne dépendent jamais de cette horloge visuelle.
func _contact(center: Vector2, size: float, p: float, fade: float) -> void:
	var flash: float = 1.0 - smoothstep(0.0, 0.20, p)
	Shapes.star(self, center, size * (0.5 + flash * 0.5), Color(accent, fade * flash), -0.25)


func _debris(center: Vector2, p: float, fade: float, reach: float, count: int) -> void:
	var release: float = 1.0 - pow(1.0 - p, 2.2)
	for i: int in mini(count, particle_budget):
		var axis := Vector2.from_angle(i * 2.39996 + 0.3)
		var fraction: float = 0.28 + float(i % 7) * 0.095
		var pos: Vector2 = center + axis * reach * fraction * release
		pos.y += reach * p * p * 0.10
		var size: float = (4.0 + float(i % 4) * 2.1) * (1.0 - p * 0.75)
		_facet(pos, axis.angle() + p * 1.4, size, size * 0.38,
			color.darkened(0.25), accent, fade * (1.0 - p * 0.45))


func _line() -> PackedVector2Array:
	if path_points.size() >= 2:
		return path_points
	return PackedVector2Array([Vector2.ZERO, Vector2(maxf(travel_distance, 0.0), 0.0)])


func _projectile(p: float, fade: float) -> void:
	var size: float = maxf(width, 1.0)
	var points := PackedVector2Array()
	for i: int in 8:
		var t: float = i / 7.0
		points.append(Vector2(-size * 2.4 * (1.0 - t), sin(t * TAU + p * TAU) * size * 0.09))
	_stroke(points, size * 0.9, INK, color, fade * 0.8)
	if surface == "organic":
		var body := PackedVector2Array()
		for i: int in 12:
			var a: float = i * TAU / 12.0
			var lobe: float = 0.86 + sin(a * 3.0 + p * TAU) * 0.10
			body.append(Vector2(cos(a), sin(a) * 0.75) * size * 0.65 * lobe)
		draw_colored_polygon(body, Color(color.darkened(0.3), fade))
		_facet(Vector2(size * 0.14, -size * 0.14), -0.2,
			size * 0.85, size * 0.45, color, accent, fade)
		for i: int in mini(particle_budget, 3):
			var age: float = fposmod(p + i * 0.33, 1.0)
			var pos := Vector2(-size * (0.8 + age * 1.7), sin(i * 2.4) * size * age * 0.5)
			_facet(pos, -0.2, size * 0.3 * (1.0 - age), size * 0.15,
				color, accent, fade * (1.0 - age))
	else:
		_facet(Vector2.ZERO, 0.0, size * 2.0, size * 0.7, color, accent, fade)
		_facet(Vector2(-size * 0.25, size * 0.25), -0.15,
			size * 1.2, size * 0.25, INK, color, fade * 0.8)
		_stroke(PackedVector2Array([Vector2(-size * 1.1, 0), Vector2(size * 0.8, 0)]),
			1.3, accent, WHITE, fade * 0.9)
	Shapes.star(self, Vector2(size * 0.35, -size * 0.12), size * 0.20, Color(accent, fade))


func _splash(p: float, fade: float) -> void:
	var strike: float = 1.0 - pow(1.0 - clampf(p / 0.48, 0.0, 1.0), 2.6)
	var reach: float = maxf(radius, 0.0) * (0.14 + 0.86 * strike)
	var puddle := PackedVector2Array()
	for i: int in 18:
		var angle: float = i * TAU / 18.0
		var lobe: float = 0.82 + sin(i * 2.4) * 0.18
		puddle.append(Vector2(cos(angle), sin(angle) * 0.6) * reach * lobe * 0.62)
	# Plusieurs impacts ne doivent pas effacer le sol ni les silhouettes.
	draw_colored_polygon(puddle, Color(INK, fade * 0.20))
	var rim := puddle.duplicate()
	rim.append(rim[0])
	_stroke(rim, 7.0 * (1.0 - p * 0.4), color.darkened(0.5), color, fade * 0.75)
	for arm: int in 5:
		var direction := Vector2.from_angle(arm * TAU / 5.0 + 0.2)
		var points := PackedVector2Array()
		var side: float = -1.0 if arm % 2 == 0 else 1.0
		for i: int in 9:
			var t: float = i / 8.0
			var point: Vector2 = direction * reach * (0.08 + t * 0.70)
			point += direction.orthogonal() * sin(t * PI) * reach * 0.15 * side
			point.y -= sin(p * PI) * radius * 0.15 * t
			points.append(point)
		_stroke(points, (15.0 + arm % 3 * 3.0) * (1.0 - p * 0.65), INK, color, fade)
		_stroke(points, 1.4, color, accent, fade * 0.45)
	var count: int = clampi(particle_budget, 0, 32)
	for i: int in count:
		var axis := Vector2.from_angle(i * 2.39996)
		var fraction: float = 0.35 + float(i % 5) * 0.13
		var pos: Vector2 = axis * reach * fraction
		pos.y -= sin(p * PI) * radius * (0.12 + float(i % 3) * 0.06)
		_facet(pos, axis.angle() + p, 8.0 + float(i % 4) * 4.0,
			5.0 + float(i % 3) * 2.0, INK, color, fade)
	for i: int in 3:
		var arc: float = i * TAU / 3.0
		draw_arc(Vector2.ZERO, maxf(reach * 0.7, 0.1), arc, arc + 0.9, 9,
			Color(accent, fade * 0.65), 2.0, false)
	_contact(Vector2.ZERO, minf(radius * 0.23, 28.0), p, fade)


func _roots(p: float, fade: float) -> void:
	var base: PackedVector2Array = _line()
	if effect_kind == &"leash":
		# Lien mécanique : âme continue lisible, puis les brins peints qui la suivent.
		Stroke.stroke(self, base, maxf(width * 0.72, 3.0), ROOT.darkened(0.5), ROOT, fade)
		for strand: int in 2:
			var woven := PackedVector2Array()
			for segment: int in base.size() - 1:
				var delta: Vector2 = base[segment + 1] - base[segment]
				for i: int in 12:
					var t: float = i / 11.0
					woven.append(base[segment].lerp(base[segment + 1], t)
						+ delta.normalized().orthogonal() * sin(t * TAU * 2.0 + p * TAU + strand * PI) * width * 0.2)
			_stroke(woven, width * 0.65, ROOT.darkened(0.5), ROOT, fade)
			_stroke(woven, maxf(width * 0.10, 1.0), ROOT, accent, fade * 0.45)
		return
	for root: int in 5:
		var direction := Vector2.from_angle(lerpf(-0.7, 0.7, root / 4.0))
		var growth: float = clampf(_elapsed / maxf(duration() * 0.4, 0.01), 0.0, 1.0)
		var reach: float = radius * (1.0 - pow(1.0 - growth, 2.0))
		var points := PackedVector2Array([Vector2.ZERO, direction * reach * 0.32 + Vector2(0, -12),
			direction * reach * 0.7 + Vector2(0, -22), direction * reach])
		_stroke(points, 12.0 - root, ROOT.darkened(0.5), ROOT, fade)
		_stroke(points, 2.0, color, accent, fade * 0.7)
		for branch: int in 2:
			var base_point: Vector2 = points[branch + 1]
			var side: float = -1.0 if (root + branch) % 2 == 0 else 1.0
			var tip: Vector2 = base_point + direction.orthogonal() * side * radius * 0.12 * growth
			_stroke(PackedVector2Array([base_point, tip - direction * 6.0, tip]),
				4.0, ROOT.darkened(0.4), color, fade * 0.8)


func _spores(p: float, fade: float) -> void:
	for spiral: int in 3:
		var strand := PackedVector2Array()
		for k: int in 14:
			var t: float = k / 13.0
			var angle: float = spiral * TAU / 3.0 + t * 2.2 + p * TAU
			strand.append(Vector2.from_angle(angle) * radius * (0.12 + t * 0.45) - Vector2(0, t * 12.0))
		_stroke(strand, 5.0, INK, color, fade * 0.45)
	var count: int = clampi(particle_budget, 0, 24)
	for i: int in count:
		var t: float = fposmod(p + i * 0.618034, 1.0)
		var point := Vector2.from_angle(i * 2.39996) * radius * (0.25 + float(i % 5) * 0.14)
		point.y -= t * 32.0
		var alpha: float = sin(t * PI) * fade
		var size: float = 2.5 + float(i % 3) * 1.7
		draw_circle(point, size + 1.5, Color(INK, alpha))
		draw_circle(point, size, Color(color, alpha))
		if effect_kind == &"heal":
			_facet(point, -PI * 0.25, size * 2.5, size, color, accent, alpha)
			_facet(point, PI * 0.25, size * 2.5, size, color, accent, alpha)
		else:
			Shapes.star(self, point + Vector2(-1, -1), size * 0.65, Color(accent, alpha))


func _mark(p: float, fade: float) -> void:
	var pulse: float = 0.85 + sin(p * TAU * 3.0) * 0.15
	for i: int in 4:
		var axis := Vector2.from_angle(i * PI * 0.5)
		var center: Vector2 = axis * radius * 0.52
		_facet(center, axis.angle(), radius * 0.22 * pulse,
			radius * 0.1, INK, color, fade)
	Shapes.star(self, Vector2.ZERO, radius * 0.2 * pulse, Color(WARNING, fade))


func _shield(p: float, fade: float) -> void:
	var sectors: int = 4 if effect_kind == &"facets" else 6
	for i: int in sectors:
		var angle: float = i * TAU / sectors
		var integrity: float = facet_strengths[i] if effect_kind == &"facets" else strength
		if integrity <= 0.0:
			continue
		var points := PackedVector2Array()
		for k: int in 7:
			var a: float = angle - 0.4 + k * 0.8 / 6.0
			points.append(Vector2.from_angle(a) * radius)
		_stroke(points, 8.0 * integrity, INK, color, fade * integrity)
		_facet(Vector2.from_angle(angle) * radius, angle + PI * 0.5,
			18.0, 6.0, color, accent, fade * integrity)
		var glint: float = fposmod(p * 1.3 + i / float(sectors), 1.0)
		var highlight: Vector2 = Vector2.from_angle(angle - 0.28 + glint * 0.56) * radius
		_facet(highlight, angle + PI * 0.5, 9.0, 2.5,
			color, accent, fade * integrity * sin(glint * PI))
	if effect_kind == &"shield":
		for point: Vector2 in secondary_offsets:
			_stroke(PackedVector2Array([Vector2.ZERO, point]), 3.0, ROOT, color, fade * 0.45)


func _blink(p: float, fade: float) -> void:
	var origins := secondary_offsets if not secondary_offsets.is_empty() else \
		PackedVector2Array([Vector2.ZERO])
	for center: Vector2 in origins:
		# Le plafond est partagé entre les positions confirmées, pas multiplié par les clones.
		var count: int = mini(20, clampi(particle_budget, 0, 32) / maxi(origins.size(), 1))
		for i: int in count:
			var angle: float = i * 2.39996
			var spread: float = radius * sin(p * PI) * (0.2 + float(i % 5) * 0.15)
			var pos: Vector2 = center + Vector2(cos(angle) * spread * 0.5, sin(angle) * spread)
			_facet(pos, angle, 8.0 + i % 4 * 3.0, 3.0, color, accent, fade)
		Shapes.star(self, center, radius * 0.6 * sin(p * PI), Color(accent, fade))
		for side: int in 2:
			var sign_x: float = -1.0 if side == 0 else 1.0
			var bend: float = radius * sin(p * PI) * 0.4
			var stroke := PackedVector2Array([center + Vector2(-bend * sign_x, -radius * 0.5),
				center + Vector2(bend * sign_x, -radius * 0.1), center + Vector2(0, radius * 0.45)])
			_stroke(stroke, 5.0 * sin(p * PI), INK, color, fade * 0.6)


func _mirror(p: float, fade: float) -> void:
	var points := PackedVector2Array([Vector2(0, -radius), Vector2(width * 0.55, 0),
		Vector2(0, radius), Vector2(-width * 0.55, 0)])
	draw_colored_polygon(points, Color(INK, fade * 0.85))
	_facet(Vector2.ZERO, PI * 0.5, radius * 1.8, width,
		color.darkened(0.3), accent, fade * 0.8)
	points.append(points[0])
	_stroke(points, 4.0, INK, color, fade)
	for side: int in 4:
		var corner: Vector2 = points[side]
		_facet(corner, corner.angle(), 10.0, 5.0, INK, accent, fade)
	var sweep_y: float = lerpf(-radius * 0.6, radius * 0.6, p)
	var shine := PackedVector2Array([Vector2(-width * 0.25, sweep_y),
		Vector2(width * 0.25, sweep_y - 7.0)])
	_stroke(shine, 3.0, color, WHITE, fade * 0.8)
	Shapes.star(self, Vector2(0, sin(p * TAU) * radius * 0.5), width * 0.23, Color(WHITE, fade))


func _beam(p: float, fade: float) -> void:
	var points: PackedVector2Array = _line()
	var pulse: float = 0.94 + sin(p * TAU * 4.0) * 0.06
	# Le contour et le cœur restent continus jusqu'aux extrémités du trajet confirmé.
	Stroke.stroke(self, points, width + 5.0, INK, color.darkened(0.4), fade)
	_stroke(points, width * pulse, color, accent, fade * 0.9)
	Stroke.stroke(self, points, width * 0.22, accent, WHITE, fade)
	for point: Vector2 in points:
		Shapes.star(self, point, width * 0.65, Color(accent, fade))
	# Reflets qui parcourent le trajet confirmé, sans créer de nouveau segment dangereux.
	var total: float = 0.0
	for i: int in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	if total > 0.1:
		for glint: int in mini(particle_budget, 3):
			var distance: float = fposmod(p * 1.7 + glint / 3.0, 1.0) * total
			for segment: int in points.size() - 1:
				var length: float = points[segment].distance_to(points[segment + 1])
				if distance <= length and length > 0.001:
					var center: Vector2 = points[segment].lerp(points[segment + 1], distance / length)
					Shapes.star(self, center, minf(width * 0.42, 10.0), Color(WHITE, fade * 0.7))
					break
				distance -= length


func _burst(p: float, fade: float) -> void:
	_debris(Vector2.ZERO, p, fade, radius, 24)
	_contact(Vector2.ZERO, minf(radius * 0.25, 25.0), p, fade)
	if effect_kind == &"shards":
		var advance: float = 1.0 - pow(1.0 - p, 2.0)
		for i: int in 3:
			var half: float = deg_to_rad(half_angle_degrees)
			var angle: float = lerpf(-half, half, i / 2.0)
			var axis := Vector2.from_angle(angle)
			var head: Vector2 = axis * travel_distance * advance
			_stroke(PackedVector2Array([head - axis * width * 2.2, head]),
				width * 0.6, INK, color, fade * 0.7)
			_facet(head, angle, width * 1.7, width * 0.55, color, accent, fade)


func _swallow(p: float, fade: float) -> void:
	# Engloutissement : convergence vers la gueule, distincte d'une colonne de rage.
	for arm: int in 4:
		var angle: float = arm * TAU / 4.0 + 0.2
		var points := PackedVector2Array()
		for i: int in 15:
			var t: float = i / 14.0
			var a: float = angle + t * 0.8 - p * 0.5
			points.append(Vector2.from_angle(a) * radius * (1.0 - t * 0.93))
		_stroke(points, width * 0.65, INK, color, fade * 0.7)
	for i: int in mini(particle_budget, 16):
		var age: float = fposmod(p + i * 0.618034, 1.0)
		var angle: float = i * 2.39996 - age * 0.5
		var point: Vector2 = Vector2.from_angle(angle) * radius * (1.0 - age) * 0.85
		_facet(point, angle + PI, 10.0 * (1.0 - age * 0.7), 3.0,
			color, accent, fade * sin(age * PI))
	Shapes.star(self, Vector2.ZERO, width * (0.8 + sin(p * TAU) * 0.15), Color(accent, fade * 0.8))


func _pulse(p: float, fade: float) -> void:
	var pulse: float = 0.7 + sin(p * TAU * 2.0) * 0.3
	if effect_kind == &"weakness":
		# Noyau exposé : quatre fentes brèves et un cœur lisible, pas une aura de rage.
		for i: int in 4:
			var axis := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
			var tip: Vector2 = axis * radius * (0.2 + pulse * 0.16)
			_stroke(PackedVector2Array([axis * radius * 0.72, tip + axis.orthogonal() * 5.0, tip]),
				maxf(width * 0.35, 2.0), INK, color, fade * 0.7)
		Shapes.star(self, Vector2.ZERO, minf(radius * 0.2, 18.0) * pulse, Color(accent, fade))
		return
	for i: int in 3:
		var points := PackedVector2Array()
		for k: int in 8:
			var y: float = k / 7.0
			points.append(Vector2((i - 1) * radius * 0.3 + sin(y * TAU + p * TAU) * 6.0,
				-radius * y))
		_stroke(points, width * (1.0 + pulse), INK, color, fade * 0.85)
		_stroke(points, width * 0.24, color, accent, fade * 0.8)
	for i: int in mini(particle_budget, 12):
		var t: float = fposmod(p + i * 0.618, 1.0)
		var point := Vector2(sin(i * 2.4) * radius * 0.45, -t * radius)
		_facet(point, -PI * 0.5, 6.0 + i % 3 * 2.0, 3.0, color, accent, fade * sin(t * PI))
	Shapes.star(self, Vector2(0, -radius * 0.3), width * pulse, Color(accent, fade))


func _mud_wall(p: float, fade: float) -> void:
	var height: float = radius * stage
	var body: Color = ROOT.lerp(color, 0.18)
	var silhouette := PackedVector2Array([Vector2(-width * 0.5, 6)])
	var ridge := PackedVector2Array()
	for i: int in 15:
		var x: float = lerpf(-width * 0.5, width * 0.5, i / 14.0)
		var jagged: float = 0.62 + 0.28 * absf(sin(i * 1.73 + 0.4))
		var top := Vector2(x, -height * jagged)
		silhouette.append(top)
		ridge.append(top)
	silhouette.append(Vector2(width * 0.5, 6))
	draw_colored_polygon(silhouette, Color(body.darkened(0.25), fade * 0.9))
	_stroke(ridge, 7.0, body, color, fade * 0.85)
	for i: int in 6:
		var x: float = lerpf(-width * 0.43, width * 0.43, i / 5.0)
		var top: float = height * (0.55 + float(i % 3) * 0.12)
		_facet(Vector2(x, -top * 0.5), -PI * 0.5 + sin(i * 2.4) * 0.12,
			top * 0.85, maxf(width * 0.12, 3.0), body.darkened(0.4),
			body.lerp(color, 0.4).lightened(0.12), fade * 0.8)
		_stroke(PackedVector2Array([Vector2(x, -top * 0.8),
			Vector2(x - 3, -top * 0.45), Vector2(x + 4, -top * 0.08)]),
			maxf(width * 0.07, 3.0), body.darkened(0.15), body.lightened(0.2), fade * 0.7)
		_stroke(PackedVector2Array([Vector2(x + 4, -top * 0.85),
			Vector2(x - 3, -top * 0.42), Vector2(x + 2, -top * 0.15)]),
			1.4, body, accent, fade * 0.45)
	if stage < 0.8:
		for i: int in mini(particle_budget, 8):
			var point := Vector2(cos(i * 2.39996) * width * 0.4, sin(i * 2.39996 + p * TAU) * 6.0)
			draw_circle(point, 5.0, Color(color.darkened(0.6), fade * 0.7))


func _whirlpool(p: float, fade: float) -> void:
	for arm: int in 4:
		var points := PackedVector2Array()
		for i: int in 25:
			var t: float = i / 24.0
			var angle: float = arm * TAU / 4.0 + t * TAU * 0.8 - p * TAU
			points.append(Vector2.from_angle(angle) * radius * (0.12 + 0.88 * t))
		_stroke(points, maxf(width * 0.7, 2.0), INK, color, fade * 0.7)
		_stroke(points, 2.0, color, accent, fade * 0.8)
	for i: int in mini(particle_budget, 20):
		var t: float = fposmod(p + i * 0.618034, 1.0)
		var angle: float = i * 2.39996 - p * TAU * 2.0
		var point: Vector2 = Vector2.from_angle(angle) * radius * (1.0 - t * 0.86)
		_facet(point, angle + PI * 0.5, 13.0 + i % 4 * 3.0,
			4.0 + i % 3, color, accent, fade * sin(t * PI))
		if i % 4 == 0:
			var wake: Vector2 = Vector2.from_angle(angle + PI * 0.5) * 9.0
			draw_line(point - wake, point, Color(accent, fade * sin(t * PI) * 0.65), 1.5, false)


func _tide(p: float, fade: float) -> void:
	for part: int in 12:
		var start: float = part * TAU / 12.0
		var points := PackedVector2Array()
		for i: int in 9:
			var a: float = start + i / 8.0 * TAU / 12.0 * 0.92
			var ripple: float = sin(a * 18.0 - p * TAU) * 3.0
			points.append(Vector2.from_angle(a) * (radius + ripple))
		_stroke(points, width, INK, color, fade * 0.65)
		_stroke(points, 2.0, color, accent, fade * 0.85)
		if part % 2 == 0:
			var crest: Vector2 = points[4]
			_facet(crest, start + PI * 0.5, 9.0, 3.0,
				color, accent, fade * (0.45 + sin(p * TAU + part) * 0.2))


func _claw(p: float, fade: float) -> void:
	var sweep: float = 1.0 - pow(1.0 - clampf(p / 0.55, 0.0, 1.0), 2.5)
	var half: float = deg_to_rad(half_angle_degrees)
	var head: float = lerpf(-half, half, sweep)
	var tail: float = maxf(-half, head - 1.15)
	for finger: int in 3:
		var points := PackedVector2Array()
		for i: int in 14:
			var angle: float = lerpf(tail, head, i / 13.0)
			points.append(Vector2.from_angle(angle) * radius * (0.95 - finger * 0.13))
		_stroke(points, maxf(width * (1.35 - finger * 0.25), 1.0), INK, color, fade)
		_stroke(points, 1.8, color, accent, fade * 0.85)
		Shapes.star(self, points[-1], minf(width * 0.65, 8.0), Color(accent, fade * (1.0 - p)))
	_contact(Vector2.from_angle(-half) * radius * 0.8, minf(width, 13.0), p, fade)


## Télégraphe distinct : dimension exacte du danger, contour corail, remplissage très faible.
func _indicator(p: float, fade: float) -> void:
	var ink := Color(WARNING, fade * (0.75 + sin(p * TAU * 3.0) * 0.2))
	if target_shape == &"line":
		var points: PackedVector2Array = _line()
		_stroke(points, width + 4.0, INK, INK, fade)
		_stroke(points, width, WARNING, WARNING, fade * 0.08)
		for i: int in points.size() - 1:
			var normal: Vector2 = (points[i + 1] - points[i]).normalized().orthogonal() * width * 0.5
			draw_line(points[i] + normal, points[i + 1] + normal, ink, 2.0, false)
			draw_line(points[i] - normal, points[i + 1] - normal, ink, 2.0, false)
	elif target_shape == &"sector":
		var half: float = deg_to_rad(half_angle_degrees)
		draw_arc(Vector2.ZERO, maxf(radius, 0.1), -half, half, 32, ink, 3.0, false)
		draw_line(Vector2.ZERO, Vector2.from_angle(-half) * radius, ink, 2.0, false)
		draw_line(Vector2.ZERO, Vector2.from_angle(half) * radius, ink, 2.0, false)
	else:
		draw_arc(Vector2.ZERO, maxf(radius, 0.1), 0.0, TAU, 48, Color(INK, fade), 5.0, false)
		draw_arc(Vector2.ZERO, maxf(radius, 0.1), 0.0, TAU, 48, ink, 2.0, false)
