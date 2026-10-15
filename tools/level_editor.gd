extends Node2D
## Éditeur de niveau (outil de développement, première version) : ouvrir tools/level_editor.tscn dans Godot et
## lancer la scène (F6). Affiche la carte dessinée d'une arène, le décor infranchissable (rouge), les régions
## séparées par les barrières (couleurs), les barrières, les points d'ancrage des zones, le centre de l'arène du
## boss et le départ. Tout se modifie à la souris ; S enregistre dans data/arenas/<id>.tres et le manifeste.
##
## Souris : glisser un point / une barrière (clic gauche) ; coin bas-droit d'une barrière = redimensionner ;
## clic droit glissé = nouvelle barrière pour la zone choisie ; molette = zoom ; clic milieu glissé = déplacer la vue.
## Clavier : 1-9 = zone choisie ; Suppr = supprimer la barrière survolée ; R = recalculer les régions ;
## S = enregistrer. Lancement : godot --path . res://tools/level_editor.tscn -- --arena=three_rifts

const MANIFEST := "res://assets/asset_manifest.json"
const HANDLE := 14.0
const REGION_COLORS: Array[Color] = [Color(0.2, 0.6, 1.0), Color(0.3, 1.0, 0.4), Color(1.0, 0.8, 0.2),
	Color(0.9, 0.4, 1.0), Color(0.3, 1.0, 1.0)]

var arena: ArenaData
var arena_path: String = ""
var start := Vector2.ZERO
var zone_selected: int = 0
var _env: EnvironmentSet
var _blocked_tex: ImageTexture
var _region_tex: ImageTexture
var _region_rect := Rect2()
var _camera := Camera2D.new()
var _label := Label.new()
## Élément saisi : {"kind": "anchor"|"finale"|"start"|"wall"|"resize"|"new", "zone": int, "wall": int}.
var _drag: Dictionary = {}
var _drag_offset := Vector2.ZERO
var _new_from := Vector2.ZERO
var _panning: bool = false
var _dirty: bool = false


func _ready() -> void:
	var arena_id: String = "three_rifts"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--arena="):
			arena_id = arg.get_slice("=", 1)
	arena_path = "res://data/arenas/%s.tres" % arena_id
	arena = load(arena_path).duplicate(true)
	_env = Assets.environment(arena.environment_id)
	if _env:
		start = _env.start
		_build_blocked_overlay()
	add_child(_camera)
	_camera.zoom = Vector2.ONE * 0.25
	var ui := CanvasLayer.new()
	add_child(ui)
	_label.position = Vector2(12, 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(_label)
	_rebuild_regions()


func _rect() -> Rect2:
	return Rect2(-arena.size * 0.5, arena.size)


## Décor infranchissable d'après la carte de distance (valeur < 128 = bloqué).
func _build_blocked_overlay() -> void:
	var field: Image = _env.field_image
	var img := Image.create(field.get_width(), field.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in field.get_height():
		for x: int in field.get_width():
			if field.get_pixel(x, y).r * 255.0 < 128.0:
				img.set_pixel(x, y, Color(1.0, 0.1, 0.1, 0.4))
	_blocked_tex = ImageTexture.create_from_image(img)


## Régions connexes barrières fermées (même calcul que le jeu) : une fuite entre deux zones saute aux yeux.
func _rebuild_regions() -> void:
	if _env == null:
		return
	var obstacles := ObstacleField.new()
	obstacles.set_distance_field(_env.field_image, _rect(), _env.field_step)
	for zone: LevelZoneData in arena.zones:
		for wall: Rect2 in zone.exit_walls:
			obstacles.add_wall(wall)
	var flow := FlowField.new()
	flow.setup(obstacles, _rect(), arena.navigation_cell_size)
	var seeds: Array[Vector2] = []
	for zone: LevelZoneData in arena.zones:
		seeds.append(zone.anchor)
	seeds.append(arena.finale_center)
	var labels: PackedInt32Array = flow.label_regions(seeds)
	var img := Image.create(flow.size.x, flow.size.y, false, Image.FORMAT_RGBA8)
	for i: int in labels.size():
		if labels[i] >= 0:
			var c: Color = REGION_COLORS[labels[i] % REGION_COLORS.size()]
			img.set_pixel(i % flow.size.x, i / flow.size.x, Color(c, 0.22))
	_region_tex = ImageTexture.create_from_image(img)
	_region_rect = Rect2(flow.origin, Vector2(flow.size) * flow.cell_size)
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = _rect()
	if _env and _env.is_map():
		if _env.map_tiles.is_empty():
			draw_texture_rect(_env.map_texture, rect, false)
		else:
			var tile := Vector2(rect.size.x / _env.map_tiles.size(), rect.size.y)
			for i: int in _env.map_tiles.size():
				draw_texture_rect(_env.map_tiles[i], Rect2(rect.position + Vector2(i * tile.x, 0), tile), false)
	if _blocked_tex:
		draw_texture_rect(_blocked_tex, rect, false)
	if _region_tex:
		draw_texture_rect(_region_tex, _region_rect, false)
	draw_rect(rect, Color.WHITE, false, 4.0)
	var s: float = 1.0 / _camera.zoom.x
	for z: int in arena.zones.size():
		var zone: LevelZoneData = arena.zones[z]
		var color: Color = REGION_COLORS[z % REGION_COLORS.size()]
		var width: float = (4.0 if z == zone_selected else 2.0) * s
		for wall: Rect2 in zone.exit_walls:
			draw_rect(wall, Color(0.75, 0.3, 1.0, 0.45))
			draw_rect(wall, color, false, width)
			draw_rect(Rect2(wall.end - Vector2.ONE * HANDLE * s, Vector2.ONE * HANDLE * s), color)
		draw_circle(zone.anchor, HANDLE * s, color)
		draw_string(ThemeDB.fallback_font, zone.anchor + Vector2(HANDLE, -HANDLE) * s, "Zone %d" % (z + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * s), color)
	draw_circle(arena.finale_center, HANDLE * s, Color.ORANGE_RED)
	if arena.finale_radii.x > 0:
		draw_arc(arena.finale_center, arena.finale_radii.x, 0, TAU, 64, Color.ORANGE_RED, 2.0 * s)
	draw_circle(start, HANDLE * s, Color.WHITE)
	if _drag.get("kind", "") == "new":
		draw_rect(Rect2(_new_from, get_global_mouse_position() - _new_from).abs(), Color.YELLOW, false, 2.0 * s)
	_label.text = "Arène %s%s — zone choisie : %d/%d — souris : %s\n%s" % [arena.id, " (modifié)" if _dirty else "",
		zone_selected + 1, arena.zones.size(), Vector2i(get_global_mouse_position()),
		"Glisser : points et barrières · coin = taille · clic droit glissé : nouvelle barrière · 1-9 : zone · " +
		"Suppr : effacer · R : régions · S : enregistrer"]


## Élément sous la souris (le plus prioritaire d'abord : poignées, puis barrières).
func _pick(pos: Vector2) -> Dictionary:
	var r: float = HANDLE * 1.5 / _camera.zoom.x
	if pos.distance_to(start) < r:
		return {"kind": "start"}
	if pos.distance_to(arena.finale_center) < r:
		return {"kind": "finale"}
	for z: int in arena.zones.size():
		if pos.distance_to(arena.zones[z].anchor) < r:
			return {"kind": "anchor", "zone": z}
	for z: int in arena.zones.size():
		var walls: Array[Rect2] = arena.zones[z].exit_walls
		for w: int in walls.size():
			if pos.distance_to(walls[w].end) < r:
				return {"kind": "resize", "zone": z, "wall": w}
			if walls[w].has_point(pos):
				return {"kind": "wall", "zone": z, "wall": w}
	return {}


func _unhandled_input(event: InputEvent) -> void:
	var mouse: Vector2 = get_global_mouse_position()
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var factor: float = 1.15 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			_camera.zoom = (_camera.zoom * factor).clamp(Vector2.ONE * 0.08, Vector2.ONE * 3.0)
		elif b.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = b.pressed
		elif b.button_index == MOUSE_BUTTON_LEFT and b.pressed:
			_drag = _pick(mouse)
			_drag_offset = _position_of(_drag) - mouse
		elif b.button_index == MOUSE_BUTTON_RIGHT and b.pressed and zone_selected < arena.zones.size():
			_drag = {"kind": "new"}
			_new_from = mouse.round()
		elif not b.pressed and not _drag.is_empty():
			if _drag["kind"] == "new":
				var wall := Rect2(_new_from, mouse.round() - _new_from).abs()
				if wall.size.x >= 8 and wall.size.y >= 8:
					arena.zones[zone_selected].exit_walls.append(wall)
			_drag = {}
			_dirty = true
			_rebuild_regions()
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if _panning:
			_camera.position -= m.relative / _camera.zoom
		elif not _drag.is_empty():
			_move(_drag, (mouse + _drag_offset).round())
	elif event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode >= KEY_1 and k.keycode <= KEY_9 and k.keycode - KEY_1 < arena.zones.size():
			zone_selected = k.keycode - KEY_1
		elif k.keycode == KEY_DELETE:
			var hit: Dictionary = _pick(mouse)
			if hit.get("kind", "") in ["wall", "resize"]:
				arena.zones[hit["zone"]].exit_walls.remove_at(hit["wall"])
				_dirty = true
				_rebuild_regions()
		elif k.keycode == KEY_R:
			_rebuild_regions()
		elif k.keycode == KEY_S:
			save()
	queue_redraw()


func _position_of(item: Dictionary) -> Vector2:
	match item.get("kind", ""):
		"start":
			return start
		"finale":
			return arena.finale_center
		"anchor":
			return arena.zones[item["zone"]].anchor
		"wall":
			return arena.zones[item["zone"]].exit_walls[item["wall"]].position
		"resize":
			return arena.zones[item["zone"]].exit_walls[item["wall"]].end
	return get_global_mouse_position()


func _move(item: Dictionary, pos: Vector2) -> void:
	match item.get("kind", ""):
		"start":
			start = pos
		"finale":
			arena.finale_center = pos
		"anchor":
			arena.zones[item["zone"]].anchor = pos
		"wall":
			arena.zones[item["zone"]].exit_walls[item["wall"]].position = pos
		"resize":
			var wall: Rect2 = arena.zones[item["zone"]].exit_walls[item["wall"]]
			wall.size = (pos - wall.position).max(Vector2.ONE * 8.0)
			arena.zones[item["zone"]].exit_walls[item["wall"]] = wall


## Enregistre l'arène (.tres) et le point de départ (manifeste d'assets).
func save() -> void:
	var err: Error = ResourceSaver.save(arena, arena_path)
	if err == OK and _env:
		var text: String = FileAccess.get_file_as_string(MANIFEST)
		var manifest: Dictionary = JSON.parse_string(text)
		var entries: Dictionary = manifest.get("entries", {})
		if entries.has(str(arena.environment_id)):
			entries[str(arena.environment_id)]["start"] = [start.x, start.y]
			var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
			file.store_string(JSON.stringify(manifest, "\t", false) + "\n")
	_dirty = err != OK
	print("Éditeur de niveau : enregistrement %s (%s)" % ["réussi" if err == OK else "ÉCHOUÉ", arena_path])
