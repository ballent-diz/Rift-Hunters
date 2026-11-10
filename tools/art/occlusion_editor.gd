extends Node2D
## Éditeur de masquage (outil de développement) : silhouettes des éléments de décor peints qui passent devant les
## personnages. Mode d'emploi : docs/maps/MASQUAGE_PAR_LE_DECOR.md.
## Lancer : godot --path . res://tools/art/occlusion_editor.tscn -- --arena=three_rifts
## (--save : sans fenêtre, recharge, enregistre et recalcule depth.png, puis ferme)
## (dans Godot : ouvrir la scène puis F6 ; sans argument, l'arène three_rifts).
##
## Outils : B pinceau (clic gauche = peindre, clic droit = gommer, [ et ] = taille) ; P polygone (clic gauche = point,
## clic droit ou Entrée = fermer et remplir, Maj en fermant = découper un trou, Retour arrière = dernier point,
## Échap = abandon) ; F ligne de pied (glisser de gauche à droite pour une ligne inclinée, simple clic = ligne
## horizontale) ; V aperçu (un personnage suit la souris : 1 Chasseur, 2 Écho, 3 Corrompu ; clic = en poser un,
## Retour arrière = les retirer).
## Éléments : N nouveau (pied sous la souris), G choisir sous la souris (répéter pour passer au suivant), K catégorie,
## H masquer / afficher (Maj+H : tout afficher), Suppr supprimer. Vue : ZQSD / WASD / flèches, clic milieu glissé,
## molette ou + et -, R zoom réel du jeu. Calques : C collisions, M masques, L lignes de pied.
## Ctrl+Z annuler, Ctrl+Y ou Ctrl+Maj+Z rétablir, Ctrl+S enregistrer.

const PAN_SPEED := 900.0
const UNDO_LIMIT := 80
const SELECTED_COLOR := Color(0.2, 0.95, 1.0, 0.5)
const CATEGORY_COLORS: Dictionary = {
	"": Color(1.0, 0.85, 0.2), "rock": Color(0.75, 0.75, 0.8), "tree": Color(0.3, 1.0, 0.4),
	"wall": Color(1.0, 0.5, 0.3), "building": Color(1.0, 0.35, 0.6), "ruin": Color(0.85, 0.6, 1.0),
	"pillar": Color(0.4, 0.6, 1.0), "statue": Color(1.0, 1.0, 1.0), "debris": Color(0.9, 0.7, 0.45),
}
const PREVIEW_NAMES: Array[String] = ["Chasseur", "Écho", "Corrompu"]

var arena: ArenaData
var doc: OcclusionDocument
var map: OcclusionMap
var selected: OcclusionDocument.Element
var tool: String = "brush"
var brush_radius: float = 6.0
var _env: EnvironmentSet
var _rect := Rect2()
var _depth_image: Image
var _textures: Dictionary = {}
var _blocked_tex: ImageTexture
var _camera := Camera2D.new()
var _label := Label.new()
var _list := ItemList.new()
var _poly := PackedVector2Array()
var _stroke: int = 0
var _edit_before: OcclusionDocument.Element
var _edit_id: String = ""
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _panning: bool = false
var _foot_from := Vector2.INF
var _dirty: bool = false
var _show_collisions: bool = true
var _show_masks: bool = true
var _show_lines: bool = true
var _pick_index: int = 0
var _preview_kind: int = 0
var _preview: EntityVisual
var _preview_pins: Array[EntityVisual] = []
var _last_mouse := Vector2.ZERO
var _status: String = ""


func _ready() -> void:
	var arena_id: String = "three_rifts"
	var capture: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--arena="):
			arena_id = arg.get_slice("=", 1)
		elif arg.begins_with("--capture="):
			capture = arg.get_slice("=", 1)
		elif arg == "--save":
			capture = "--save"
	arena = GameDB.arena(StringName(arena_id))
	if arena == null:
		push_error("Éditeur de masquage : arène inconnue « %s »" % arena_id)
		return
	_env = Assets.environment(arena.environment_id)
	if _env == null or not _env.is_map():
		push_error("Éditeur de masquage : l'arène « %s » n'a pas de carte peinte" % arena_id)
		return
	_rect = Rect2(-arena.size * 0.5, arena.size)
	var tile: Vector2i = Vector2i(_env.map_texture.get_size())
	var map_size := Vector2i(tile.x * maxi(_env.map_tiles.size(), 1), tile.y)
	var directory: String = OcclusionDocument.default_directory(arena.environment_id)
	doc = OcclusionDocument.open(directory, map_size)
	if doc == null:
		var painted: Vector2 = arena.size / arena.decor_scale
		doc = OcclusionDocument.create(arena.environment_id, directory, map_size, painted)
	_depth_image = doc.depth_image(Rect2i(Vector2i.ZERO, doc.grid))
	map = OcclusionMap.from_data(doc.runtime_data(Rect2i(Vector2i.ZERO, doc.grid)), _depth_image, _rect)
	for e: OcclusionDocument.Element in doc.elements:
		_refresh_texture(e)
	if not doc.elements.is_empty():
		selected = doc.elements[0]
	add_child(_camera)
	_camera.zoom = Vector2.ONE * 0.3
	_build_ui()
	if capture != "--save":
		_build_blocked_overlay()
	_refresh_list()
	if capture == "--save":
		# Sans fenêtre : recalcule depth.png après tools/art/occlusion_trace.py, puis ferme.
		_save()
		get_tree().quit.call_deferred(0 if not _dirty else 1)
	elif capture != "":
		_capture.call_deferred(capture)


## Capture de l'éditeur (documentation, vérification) : vue sur l'élément choisi, puis fermeture.
func _capture(path: String) -> void:
	if selected != null:
		_camera.position = doc.region_to_world(selected.rect, _rect).get_center()
		_camera.zoom = Vector2.ONE * 0.9
	_set_tool("preview")
	_preview.position = _camera.position + Vector2(-20, -40)
	for i: int in 3:
		await get_tree().process_frame
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Capture : ", path)
	get_tree().quit()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	_label.position = Vector2(12, 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(_label)
	_list.anchor_left = 1.0
	_list.anchor_right = 1.0
	_list.anchor_bottom = 1.0
	_list.offset_left = -230
	_list.offset_top = 150
	_list.offset_right = -8
	_list.offset_bottom = -8
	_list.focus_mode = Control.FOCUS_NONE
	_list.item_selected.connect(func(index: int) -> void:
		selected = doc.elements[index]
		queue_redraw())
	ui.add_child(_list)


## Collisions existantes en hachures (lecture seule ; jamais modifiées par cet outil).
func _build_blocked_overlay() -> void:
	var field: Image = _env.field_image
	var img := Image.create(field.get_width(), field.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in field.get_height():
		for x: int in field.get_width():
			if field.get_pixel(x, y).r * 255.0 < 128.0:
				img.set_pixel(x, y, Color(0.9, 0.1, 0.2, 0.42 if (x + y) / 6 % 2 == 0 else 0.22))
	_blocked_tex = ImageTexture.create_from_image(img)


func _refresh_texture(e: OcclusionDocument.Element) -> void:
	if e.mask == null:
		_textures.erase(e.id)
		return
	var tex: ImageTexture = _textures.get(e.id)
	if tex != null and Vector2i(tex.get_size()) == e.mask.get_size():
		tex.update(e.mask)
	else:
		_textures[e.id] = ImageTexture.create_from_image(e.mask)


func _refresh_list() -> void:
	_list.clear()
	for e: OcclusionDocument.Element in doc.elements:
		var label: String = e.id + ("  [%s]" % e.category if e.category != "" else "") + ("  (masqué)" if e.hidden else "")
		_list.add_item(label)
		if e == selected:
			_list.select(_list.item_count - 1)
	queue_redraw()


## Rafraîchit la profondeur (et l'aperçu en jeu) sur une région de la grille.
func _rebake(region: Rect2i) -> void:
	region = region.grow(1).intersection(Rect2i(Vector2i.ZERO, doc.grid))
	if not region.has_area():
		return
	doc.bake(region)
	_depth_image.blit_rect(doc.depth_image(region), Rect2i(Vector2i.ZERO, region.size), region.position)
	map.set_image(_depth_image)


# --- Annuler / rétablir --------------------------------------------------------------------------------------------

func _begin_edit(e: OcclusionDocument.Element) -> void:
	_edit_id = e.id if e != null else ""
	_edit_before = e.copy() if e != null else null


func _end_edit(e: OcclusionDocument.Element) -> void:
	var after: OcclusionDocument.Element = e.copy() if e != null else null
	var id: String = e.id if e != null else _edit_id
	_undo.append({"id": id, "before": _edit_before, "after": after})
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()
	_edit_before = null
	_dirty = true
	_rebake(_region_of(_undo.back()))
	if e != null:
		_refresh_texture(e)
	_refresh_list()


func _region_of(step: Dictionary) -> Rect2i:
	var out := Rect2i()
	for key: String in ["before", "after"]:
		var e: OcclusionDocument.Element = step[key]
		if e != null and e.rect.has_area():
			out = e.rect if not out.has_area() else out.merge(e.rect)
	return out


func _apply_step(step: Dictionary, forward: bool) -> void:
	var state: OcclusionDocument.Element = step["after" if forward else "before"]
	var index: int = -1
	for i: int in doc.elements.size():
		if doc.elements[i].id == step["id"]:
			index = i
	if state == null:
		if index >= 0:
			doc.elements.remove_at(index)
		_textures.erase(step["id"])
		selected = null if selected != null and selected.id == step["id"] else selected
	else:
		var copy: OcclusionDocument.Element = state.copy()
		if index >= 0:
			doc.elements[index] = copy
		else:
			doc.elements.append(copy)
		_refresh_texture(copy)
		selected = copy
	_dirty = true
	_rebake(_region_of(step))
	_refresh_list()


func undo() -> void:
	if _undo.is_empty():
		return
	var step: Dictionary = _undo.pop_back()
	_apply_step(step, false)
	_redo.append(step)


func redo() -> void:
	if _redo.is_empty():
		return
	var step: Dictionary = _redo.pop_back()
	_apply_step(step, true)
	_undo.append(step)


# --- Boucle --------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if doc == null:
		return
	var move := Vector2.ZERO
	if not Input.is_key_pressed(KEY_CTRL):
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
			move.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			move.x += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
			move.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			move.y += 1.0
	if move != Vector2.ZERO:
		_camera.position += move.normalized() * PAN_SPEED * delta / _camera.zoom.x
		queue_redraw()
	var mouse: Vector2 = get_global_mouse_position()
	if _preview != null:
		var moving: bool = mouse.distance_to(_last_mouse) > 0.5
		if moving:
			_preview.set_facing_left(mouse.x < _preview.position.x, true)
		_preview.position = mouse
		_preview.tick(delta, moving, mouse.distance_to(_last_mouse) / maxf(delta, 0.001))
		for pin: EntityVisual in _preview_pins:
			pin.tick(delta, false)
	_last_mouse = mouse
	_update_label()


func _zoom_by(factor: float) -> void:
	_camera.zoom = (_camera.zoom * factor).clamp(Vector2.ONE * 0.05, Vector2.ONE * 6.0)
	queue_redraw()


func _cell(world: Vector2) -> Vector2:
	return doc.world_to_cell(world, _rect)


func _world(cell: Vector2) -> Vector2:
	return doc.cell_to_world(cell, _rect)


# --- Dessin --------------------------------------------------------------------------------------------------------

func _draw() -> void:
	if doc == null:
		return
	if _env.map_tiles.is_empty():
		draw_texture_rect(_env.map_texture, _rect, false)
	else:
		var tile := Vector2(_rect.size.x / _env.map_tiles.size(), _rect.size.y)
		for i: int in _env.map_tiles.size():
			draw_texture_rect(_env.map_tiles[i], Rect2(_rect.position + Vector2(i * tile.x, 0), tile), false)
	# Aperçu : rendu du jeu, sans calques d'édition (lignes de pied seulement).
	var editing: bool = tool != "preview"
	if _show_collisions and _blocked_tex and editing:
		draw_texture_rect(_blocked_tex, _rect, false)
	var px: float = 1.0 / _camera.zoom.x
	if _show_masks and editing:
		for e: OcclusionDocument.Element in doc.elements:
			if e.hidden or not _textures.has(e.id):
				continue
			var color: Color = SELECTED_COLOR if e == selected else Color(CATEGORY_COLORS.get(e.category, Color.WHITE), 0.3)
			draw_texture_rect(_textures[e.id], doc.region_to_world(e.rect, _rect), false, color)
	if _show_lines:
		for e: OcclusionDocument.Element in doc.elements:
			if not e.hidden or e == selected:
				_draw_foot_line(e, px)
	if selected != null and selected.rect.has_area():
		draw_rect(doc.region_to_world(selected.rect, _rect), Color(SELECTED_COLOR, 0.9), false, 1.5 * px)
	if _poly.size() > 0:
		var points := PackedVector2Array()
		for p: Vector2 in _poly:
			points.append(_world(p))
		points.append(get_global_mouse_position())
		draw_polyline(points, Color.YELLOW, 2.0 * px)
		for p: Vector2 in points:
			draw_circle(p, 3.0 * px, Color.YELLOW)
	if _foot_from != Vector2.INF:
		draw_line(_world(_foot_from), get_global_mouse_position(), Color.ORANGE, 3.0 * px)
	if tool == "brush":
		var radius: float = (_world(Vector2(brush_radius, 0)) - _world(Vector2.ZERO)).x
		draw_arc(get_global_mouse_position(), radius, 0.0, TAU, 40, Color.WHITE, 1.5 * px)


## Ligne de pied : tracée sur la largeur de l'élément (au-dessus : derrière, en dessous : devant).
func _draw_foot_line(e: OcclusionDocument.Element, px: float) -> void:
	var x0: float = minf(e.depth_a.x, e.depth_b.x)
	var x1: float = maxf(e.depth_a.x, e.depth_b.x)
	if e.rect.has_area():
		x0 = minf(x0, e.rect.position.x)
		x1 = maxf(x1, e.rect.end.x)
	var points := PackedVector2Array()
	for x: float in [x0, minf(e.depth_a.x, e.depth_b.x), maxf(e.depth_a.x, e.depth_b.x), x1]:
		points.append(_world(Vector2(x, e.depth_at(x))))
	var color: Color = Color.ORANGE if e == selected else Color(1.0, 0.6, 0.1, 0.6)
	draw_polyline(points, color, (3.0 if e == selected else 1.5) * px)
	draw_circle(_world(e.depth_a), 4.0 * px, color)
	draw_circle(_world(e.depth_b), 4.0 * px, color)


func _update_label() -> void:
	if doc == null:
		return
	var mouse: Vector2 = get_global_mouse_position()
	var c: Vector2i = Vector2i(_cell(mouse).floor())
	var tool_text: String = {"brush": "pinceau (rayon %d)" % roundi(brush_radius), "polygon": "polygone",
		"foot": "ligne de pied", "preview": "aperçu : %s" % PREVIEW_NAMES[_preview_kind]}.get(tool, tool)
	var sel: String = "aucun (N : nouveau)" if selected == null else "%s%s" % [selected.id,
		" [%s]" % selected.category if selected.category != "" else ""]
	_label.text = ("Masquage — %s%s — %d éléments — outil : %s — élément : %s\nsouris : monde %s · cellule %s · " +
		"carte %s px · zoom %.2f%s\n%s\nB pinceau · P polygone (Maj = trou) · F ligne de pied · V aperçu (1-3) · N nouveau · " +
		"G choisir · K catégorie · H masquer · Suppr\nZQSD vue · R zoom réel · C collisions · M masques · L lignes · " +
		"Ctrl+Z / Ctrl+Y · Ctrl+S enregistrer") % [arena.id, " (modifié)" if _dirty else "", doc.elements.size(),
		tool_text, sel, Vector2i(mouse), c, Vector2i(Vector2(c) * doc.cell), _camera.zoom.x,
		"  (zoom réel)" if is_equal_approx(_camera.zoom.x, GameDB.balance.camera_zoom) else "", _status]


# --- Entrées -------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if doc == null:
		return
	var mouse: Vector2 = get_global_mouse_position()
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton, mouse)
	elif event is InputEventMagnifyGesture:
		_zoom_by((event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		_camera.position += (event as InputEventPanGesture).delta * 20.0 / _camera.zoom.x
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if _panning:
			_camera.position -= m.relative / _camera.zoom
		elif _stroke != 0 and selected != null:
			_paint_segment(_cell(mouse - m.relative), _cell(mouse), _stroke > 0)
	elif event is InputEventKey and event.pressed:
		_on_key(event as InputEventKey, mouse)
	queue_redraw()


func _on_mouse_button(b: InputEventMouseButton, mouse: Vector2) -> void:
	if b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed:
		_zoom_by(1.15)
	elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed:
		_zoom_by(1.0 / 1.15)
	elif b.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = b.pressed
	elif b.button_index != MOUSE_BUTTON_LEFT and b.button_index != MOUSE_BUTTON_RIGHT:
		return
	elif tool == "brush":
		if b.pressed and selected != null and _stroke == 0:
			_stroke = 1 if b.button_index == MOUSE_BUTTON_LEFT else -1
			_begin_edit(selected)
			_paint_segment(_cell(mouse), _cell(mouse), _stroke > 0)
		elif not b.pressed and _stroke != 0:
			_stroke = 0
			_end_edit(selected)
		elif b.pressed and selected == null:
			_status = "Aucun élément choisi : N pour en créer un."
	elif tool == "polygon" and b.pressed:
		if b.button_index == MOUSE_BUTTON_LEFT:
			_poly.append(_cell(mouse))
		else:
			_close_polygon(b.shift_pressed)
	elif tool == "foot" and selected != null and b.button_index == MOUSE_BUTTON_LEFT:
		if b.pressed:
			_foot_from = _cell(mouse)
		elif _foot_from != Vector2.INF:
			_set_foot(_foot_from, _cell(mouse))
			_foot_from = Vector2.INF
	elif tool == "preview" and b.pressed:
		if b.button_index == MOUSE_BUTTON_LEFT:
			var pin: EntityVisual = _make_visual(_preview_kind)
			pin.position = mouse
			pin.set_facing_left(_preview.position.x > mouse.x)
			_preview_pins.append(pin)


func _paint_segment(from: Vector2, to: Vector2, add: bool) -> void:
	var steps: int = maxi(1, ceili(from.distance_to(to) / maxf(brush_radius * 0.5, 0.5)))
	var touched := Rect2i()
	for i: int in steps + 1:
		var r: Rect2i = doc.paint_circle(selected, from.lerp(to, float(i) / steps), brush_radius, add)
		touched = r if not touched.has_area() else touched.merge(r)
	_refresh_texture(selected)


func _close_polygon(cut: bool) -> void:
	if selected == null or _poly.size() < 3:
		_status = "Polygone : au moins 3 points et un élément choisi."
		_poly.clear()
		return
	_begin_edit(selected)
	doc.fill_polygon(selected, _poly, not cut)
	_poly.clear()
	_end_edit(selected)


func _set_foot(a: Vector2, b: Vector2) -> void:
	_begin_edit(selected)
	if a.distance_to(b) < 2.0:
		selected.depth_a = a
		selected.depth_b = a
	else:
		selected.depth_a = a
		selected.depth_b = b
	_end_edit(selected)


func _on_key(k: InputEventKey, mouse: Vector2) -> void:
	_status = ""
	if k.ctrl_pressed:
		match k.keycode:
			KEY_S:
				_save()
			KEY_Z:
				if k.shift_pressed:
					redo()
				else:
					undo()
			KEY_Y:
				redo()
		return
	match k.keycode:
		KEY_B:
			_set_tool("brush")
		KEY_P:
			_set_tool("polygon")
		KEY_F:
			_set_tool("foot")
		KEY_V:
			_set_tool("brush" if tool == "preview" else "preview")
		KEY_1, KEY_2, KEY_3:
			if tool == "preview":
				_preview_kind = k.keycode - KEY_1
				_set_tool("preview")
		KEY_BRACKETLEFT:
			brush_radius = maxf(brush_radius / 1.25, 0.5)
		KEY_BRACKETRIGHT:
			brush_radius = minf(brush_radius * 1.25, 120.0)
		KEY_ENTER, KEY_KP_ENTER:
			_close_polygon(k.shift_pressed)
		KEY_ESCAPE:
			_poly.clear()
			_foot_from = Vector2.INF
		KEY_BACKSPACE:
			if not _poly.is_empty():
				_poly.remove_at(_poly.size() - 1)
			else:
				for pin: EntityVisual in _preview_pins:
					pin.queue_free()
				_preview_pins.clear()
		KEY_N:
			_new_element(mouse)
		KEY_G:
			_pick(mouse)
		KEY_K:
			if selected != null:
				_begin_edit(selected)
				var i: int = OcclusionDocument.CATEGORIES.find(selected.category)
				selected.category = OcclusionDocument.CATEGORIES[(i + 1) % OcclusionDocument.CATEGORIES.size()]
				_end_edit(selected)
		KEY_H:
			if k.shift_pressed:
				for e: OcclusionDocument.Element in doc.elements:
					e.hidden = false
			elif selected != null:
				selected.hidden = not selected.hidden
			_dirty = true
			_refresh_list()
		KEY_DELETE:
			if selected != null:
				_begin_edit(selected)
				doc.elements.erase(selected)
				_textures.erase(selected.id)
				selected = null
				_end_edit(null)
		KEY_C:
			_show_collisions = not _show_collisions
		KEY_M:
			_show_masks = not _show_masks
		KEY_L:
			_show_lines = not _show_lines
		KEY_R:
			_camera.position = mouse
			_camera.zoom = Vector2.ONE * GameDB.balance.camera_zoom
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			_zoom_by(1.25)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_by(0.8)


func _set_tool(name: String) -> void:
	tool = name
	_poly.clear()
	if _preview != null:
		_preview.queue_free()
		_preview = null
	if name == "preview":
		_preview = _make_visual(_preview_kind)
		_preview.position = get_global_mouse_position()


func _new_element(mouse: Vector2) -> void:
	var category: String = selected.category if selected != null else ""
	var e: OcclusionDocument.Element = doc.add_element(category, _cell(mouse))
	_textures.erase(e.id)
	_edit_id = e.id
	_edit_before = null
	selected = e
	_end_edit(e)
	if tool == "preview" or tool == "foot":
		_set_tool("polygon")
	_status = "Nouvel élément %s : tracer sa silhouette (P ou B), puis régler sa ligne de pied (F)." % e.id


## Choisit l'élément sous la souris ; appuyer de nouveau passe au suivant quand plusieurs se chevauchent.
func _pick(mouse: Vector2) -> void:
	var hits: Array[OcclusionDocument.Element] = doc.elements_at(Vector2i(_cell(mouse).floor()))
	if hits.is_empty():
		_status = "Aucun élément sous la souris."
		return
	_pick_index = (_pick_index + 1) % hits.size() if hits.has(selected) else 0
	selected = hits[_pick_index]
	_refresh_list()


func _make_visual(kind: int) -> EntityVisual:
	var visual := EntityVisual.new()
	visual.z_index = 2
	add_child(visual)
	var data: VisualData = GameDB.balance.player_visual
	if kind == 1:
		data = GameDB.monster(&"ashblade").visual
	elif kind == 2:
		data = GameDB.enemy(&"ash_hound").visual
	visual.occlusion = map
	visual.setup(data)
	return visual


func _save() -> void:
	var err: Error = doc.save()
	_dirty = err != OK
	for e: OcclusionDocument.Element in doc.elements:
		_refresh_texture(e)
	_status = "Enregistrement %s (%s). Relancer l'import de Godot pour la texture du jeu." % [
		"réussi" if err == OK else "ÉCHOUÉ : %s" % error_string(err), doc.directory]
	print("Éditeur de masquage : ", _status)
	_refresh_list()
