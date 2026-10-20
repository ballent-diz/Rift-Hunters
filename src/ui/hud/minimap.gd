class_name Minimap
extends Control
## Mini-carte (coin haut droit du HUD) et grande carte (touche « toggle_map ») : fond de la carte (manifeste,
## clé « minimap » ; sinon dessiné d'après les collisions), Chasseur, Échos, objectif du mode, barrières fermées,
## élites, boss et coffres. Les Corrompus ordinaires n'y figurent pas ; de nuit, une élite n'apparaît que si elle
## est visible (éclairée ou Révélée). Redessinée à cadence réduite (REFRESH) : coût négligeable.

## Côté de la mini-carte selon Settings.minimap_size (0 = masquée).
const SIZES: Array[float] = [0.0, 160.0, 210.0, 260.0]
## Largeur de monde couverte par la mini-carte (les petites arènes sont montrées en entier).
const VIEW_SPAN := 2600.0
const REFRESH := 1.0 / 15.0
const MARGIN := 16.0
const TOP := 84.0
const FRAME := Color(0.85, 0.78, 0.55, 0.9)
const BACK := Color(0.03, 0.04, 0.07, 0.85)
const PLAYER := Color(1.0, 0.95, 0.6)
const ECHO := Color(0.45, 0.95, 1.0)
const OBJECTIVE := Color(1.0, 0.82, 0.3)
const HOSTILE := Color(1.0, 0.3, 0.4)
const WALL := Color(0.75, 0.5, 1.0)
const CHEST := Color(1.0, 0.75, 0.25)

var ctx: RunContext
## Grande carte ouverte (le jeu continue derrière).
var expanded: bool = false
var texture: Texture2D
var _timer: float = 0.0
var _font: Font


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = ThemeDB.fallback_font
	texture = _load_texture()


func _load_texture() -> Texture2D:
	var path: String = str(Assets.entry(ctx.arena.environment_id).get("minimap", ""))
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return _texture_from_collisions()


## Sans image préparée : praticable clair, décor sombre, d'après les collisions de l'arène.
func _texture_from_collisions() -> Texture2D:
	var rect: Rect2 = ctx.arena_rect()
	var cells := Vector2i(256, maxi(1, roundi(256.0 * rect.size.y / rect.size.x)))
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	for y: int in cells.y:
		for x: int in cells.x:
			var pos: Vector2 = rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * rect.size / Vector2(cells)
			var free: bool = not ctx.obstacles.blocks(pos, 4.0, false)
			image.set_pixel(x, y, Color(0.32, 0.36, 0.3) if free else Color(0.08, 0.09, 0.14))
	return ImageTexture.create_from_image(image)


func toggle() -> void:
	expanded = not expanded
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if ctx and event.is_action_pressed(&"toggle_map") and not get_tree().paused:
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		queue_redraw()


## Cadre de la mini-carte à l'écran (vide si masquée).
func frame_rect() -> Rect2:
	var side: float = SIZES[clampi(Settings.minimap_size, 0, SIZES.size() - 1)]
	if side <= 0.0:
		return Rect2()
	var rect: Rect2 = ctx.arena_rect()
	var width: float = side * clampf(rect.size.x / rect.size.y, 1.0, 1.3)
	# Arène basse (Ruines) : le cadre s'arrête au bas de la carte, sans bande vide.
	var scale: float = width / minf(VIEW_SPAN, rect.size.x)
	var height: float = minf(side, rect.size.y * scale)
	return Rect2(size.x - MARGIN - width, TOP, width, height)


## Partie du monde montrée par la mini-carte : centrée sur le Chasseur, sans sortir de l'arène.
func view_rect(frame: Rect2) -> Rect2:
	var arena: Rect2 = ctx.arena_rect()
	var span := Vector2(VIEW_SPAN, VIEW_SPAN * frame.size.y / frame.size.x)
	if span.x >= arena.size.x and span.y >= arena.size.y:
		return arena
	span = span.min(arena.size)
	var center: Vector2 = ctx.player.global_position
	var low: Vector2 = arena.position + span * 0.5
	var high: Vector2 = arena.end - span * 0.5
	return Rect2(center.clamp(low, high) - span * 0.5, span)


func _draw() -> void:
	if ctx == null or ctx.player == null:
		return
	if expanded:
		_draw_expanded()
		return
	var frame: Rect2 = frame_rect()
	if frame.size.x <= 0.0:
		return
	var view: Rect2 = view_rect(frame)
	# Arène plus petite que la vue (dans une direction) : centrée dans le cadre.
	var scale: float = minf(frame.size.x / view.size.x, frame.size.y / view.size.y)
	var area := Rect2(frame.get_center() - view.size * scale * 0.5, view.size * scale)
	draw_rect(frame.grow(3.0), BACK)
	_draw_map(area, view)
	_draw_markers(area, view, 1.0)
	draw_rect(frame.grow(3.0), FRAME, false, 2.0)


## Grande carte : l'arène entière au centre de l'écran, avec le nom des zones.
func _draw_expanded() -> void:
	var arena: Rect2 = ctx.arena_rect()
	var room: Vector2 = size * Vector2(0.86, 0.78)
	var scale: float = minf(room.x / arena.size.x, room.y / arena.size.y)
	var area := Rect2(size * 0.5 - arena.size * scale * 0.5 + Vector2(0, 14), arena.size * scale)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.03, 0.72))
	draw_rect(area.grow(4.0), BACK)
	_draw_map(area, arena)
	if ctx.zones:
		for zone: LevelZoneData in ctx.arena.zones:
			_label(_to_screen(zone.anchor, area, arena) + Vector2(0, -14), tr(zone.name_key), 15, Color.WHITE)
	_draw_markers(area, arena, 1.6)
	draw_rect(area.grow(4.0), FRAME, false, 2.0)
	_label(Vector2(size.x * 0.5, area.position.y - 22.0), tr(ctx.arena.name_key), 26, UiKit.ACCENT)
	_label(Vector2(size.x * 0.5, area.end.y + 30.0), tr("MAP_CLOSE_HINT") % InputSetup.key_label(&"toggle_map"), 15,
		UiKit.MUTED)


func _draw_map(area: Rect2, view: Rect2) -> void:
	if texture == null:
		return
	var arena: Rect2 = ctx.arena_rect()
	var px: Vector2 = Vector2(texture.get_size()) / arena.size
	var source := Rect2((view.position - arena.position) * px, view.size * px)
	draw_texture_rect_region(texture, area, source)


func _to_screen(pos: Vector2, area: Rect2, view: Rect2) -> Vector2:
	return area.position + (pos - view.position) / view.size * area.size


func _draw_markers(area: Rect2, view: Rect2, big: float) -> void:
	# Barrières fermées (zones, finale, failles).
	for i: int in ctx.obstacles.walls.size():
		if ctx.obstacles.wall_enabled[i]:
			var wall: Rect2 = ctx.obstacles.walls[i]
			var a: Vector2 = _to_screen(wall.position, area, view)
			var b: Vector2 = _to_screen(wall.end, area, view)
			var r := Rect2(a, (b - a).max(Vector2(2.0, 2.0)))
			if area.intersects(r):
				draw_rect(r.intersection(area), WALL)
	for item: Dictionary in ctx.pickups.items:
		if item["kind"] == PickupManager.Kind.CHEST:
			_dot(_to_screen(item["pos"], area, view), 3.5 * big, CHEST, area, false)
	for enemy: Enemy in ctx.enemies.list:
		if not enemy.alive or not (enemy.is_elite or enemy.is_boss):
			continue
		if ctx.night and not ctx.night.can_target(enemy):
			continue
		_dot(_to_screen(enemy.global_position, area, view), (6.0 if enemy.is_boss else 3.5) * big, HOSTILE, area,
			enemy.is_boss)
	for objective: Vector2 in objectives():
		_diamond(_to_screen(objective, area, view), 6.0 * big, area)
	for ally: Ally in ctx.allies.team:
		_dot(_to_screen(ally.global_position, area, view), 2.5 * big, ECHO, area, false)
	_draw_player(_to_screen(ctx.player.global_position, area, view), 7.0 * big)


## Repères d'objectif du mode en cours : zone suivante, failles ouvertes, autel, arène de la finale.
func objectives() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if ctx.zones:
		var goal: Vector2 = ctx.zones.objective()
		if goal != Vector2.INF:
			out.append(goal)
	if ctx.rifts:
		for rift: Enemy in ctx.rifts.open_rifts():
			out.append(rift.global_position)
	if ctx.altar and not ctx.altar.destroyed:
		out.append(ctx.altar.position)
	if ctx.finale and ctx.finale.state == ArenaFinale.State.TRAVEL and not out.has(ctx.arena.finale_center):
		out.append(ctx.arena.finale_center)
	return out


## Point ; hors du cadre, il est ramené au bord (sauf `pinned` = faux : alors masqué).
func _dot(p: Vector2, radius: float, color: Color, area: Rect2, pinned: bool) -> void:
	if not area.has_point(p):
		if not pinned:
			return
		p = p.clamp(area.position + Vector2(radius, radius), area.end - Vector2(radius, radius))
	draw_circle(p, radius + 1.5, Color(0, 0, 0, 0.8))
	draw_circle(p, radius, color)


## Objectif : losange doré, ramené au bord du cadre s'il est hors de vue.
func _diamond(p: Vector2, radius: float, area: Rect2) -> void:
	p = p.clamp(area.position + Vector2(radius, radius), area.end - Vector2(radius, radius))
	var points := PackedVector2Array([p + Vector2(0, -radius), p + Vector2(radius, 0), p + Vector2(0, radius),
		p + Vector2(-radius, 0)])
	draw_colored_polygon(points, OBJECTIVE)
	points.append(points[0])
	draw_polyline(points, Color(0, 0, 0, 0.8), 1.5)


## Chasseur : flèche dans le sens du regard.
func _draw_player(p: Vector2, length: float) -> void:
	var dir: Vector2 = ctx.player.facing.normalized() if ctx.player.facing.length() > 0.1 else Vector2.UP
	var side: Vector2 = dir.orthogonal() * length * 0.6
	var points := PackedVector2Array([p + dir * length, p - dir * length * 0.6 + side, p - dir * length * 0.6 - side])
	draw_colored_polygon(points, PLAYER)
	points.append(points[0])
	draw_polyline(points, Color(0, 0, 0, 0.9), 1.5)


func _label(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(center.x - width * 0.5, center.y)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0.02, 0.02, 0.05))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
