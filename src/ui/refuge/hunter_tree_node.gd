class_name HunterTreeNode
extends Button
## Nœud graphique d'un arbre de compétences (Chasseur ou Écho) : icône dans son cadre, nom dessous, état lisible
## d'un coup d'œil (cadenas, contour, lueur), infobulle compacte au survol. La sélection ne dépense rien : les actions
## sont dans la fiche (SkillCard).

const CAPTION_HEIGHT := 30.0

var data: SkillNodeData
## upcoming, locked, learnable, learned ou active.
var current: String = "locked"
var picked := false
var ink: Color = HunterTreeSkin.PAPER
var portrait: Texture2D
var border: Texture2D
var rank := 0
var max_rank := 1
## Dessin de repli sans illustration : might, focus, spell, signature (Échos) ; sinon le symbole de la voie.
var symbol: StringName = &""
## Hauteur réservée à la légende (2 lignes ; 16 pour une ligne).
var caption_height := CAPTION_HEIGHT
var caption: Label
## Étiquette sur le bas du cadre (coût en Éclats d'un nœud à apprendre) ; vide : rien.
var tag: String = ""
var tag_color: Color = HunterTreeSkin.CYAN

var _tip: Array[String] = ["", "", "", ""]


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Le bouton ne porte pas de texte ; sa légende est un Label indépendant.
	add_theme_font_size_override("font_size", 1)
	for key: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(key, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	caption = UiKit.label("", 12, HunterTreeSkin.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_constant_override("line_spacing", -2)
	add_child(caption)
	for sig: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		sig.connect(queue_redraw)
	resized.connect(layout_caption)


## Nœud de l'arbre du Chasseur : état et icône lus depuis HunterTree.
func setup(p: ProfileData, node: SkillNodeData, selected: StringName) -> void:
	var state: String = HunterTreeSkin.state(p, node)
	var shown_rank: int = HunterTree.active_rank(p, node) if state == "active" else HunterTree.learned_rank(p, node)
	configure(node, state, shown_rank, node.id == selected, HunterTreeSkin.icon(node), tr(node.name_key))
	set_tip(tr(node.name_key), tr(HunterTreeSkin.KIND_KEYS[node.kind]), HunterTreeSkin.state_text(p, node),
		tr(node.desc_key))
	# Coût visible sur le nœud : ce qu'on peut apprendre tout de suite, ou ce qui ne manque que d'Éclats.
	var status: HunterTree.Status = HunterTree.status(p, node)
	if status in [HunterTree.Status.LEARNABLE, HunterTree.Status.TOO_EXPENSIVE]:
		tag = "◆ %d" % HunterTree.next_cost(p, node)
		tag_color = HunterTreeSkin.CYAN if status == HunterTree.Status.LEARNABLE else HunterTreeSkin.SHORT


func configure(node: SkillNodeData, state: String, p_rank: int, p_picked: bool, p_portrait: Texture2D,
		caption_text: String, accent: Color = Color.TRANSPARENT) -> void:
	data = node
	name = str(node.id)
	current = state
	picked = p_picked
	rank = p_rank
	max_rank = node.max_rank()
	portrait = p_portrait
	ink = accent if accent.a > 0.0 else HunterTreeSkin.accent(node.branch)
	border = HunterTreeSkin.frame(node, state)
	caption.text = caption_text
	var lit: bool = state in ["active", "learned"]
	caption.add_theme_color_override("font_color", ink if lit else (MenuSkin.PAPER if state == "learnable"
		else HunterTreeSkin.MUTED))
	caption.add_theme_font_override("font", UiKit.font(&"strong" if lit else &"body"))
	queue_redraw()


func set_tip(title_text: String, kind: String, state: String, body: String) -> void:
	_tip = [title_text, kind, state, body]
	tooltip_text = title_text


func _make_custom_tooltip(_for_text: String) -> Object:
	return SkillCard.tooltip(_tip[0], _tip[1], _tip[2], _tip[3], ink)


## Carré de l'icône : en haut, centré, la légende dessous.
func emblem_rect() -> Rect2:
	var edge: float = maxf(minf(size.x - 8, size.y - caption_height), 16)
	return Rect2(Vector2((size.x - edge) * 0.5, 0), Vector2.ONE * edge)


## Appelé par le plateau après chaque placement (un nœud de taille fixe ne reçoit pas toujours « resized »).
func layout_caption() -> void:
	var rect: Rect2 = emblem_rect()
	caption.max_lines_visible = 1 if caption_height < CAPTION_HEIGHT else 2
	caption.position = Vector2(-6, rect.end.y + 3)
	caption.size = Vector2(size.x + 12, caption_height)
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = emblem_rect()
	var faded: bool = current in ["locked", "upcoming"]
	var hovered: bool = is_hovered() or has_focus()
	# Halo : doré pour ce qui est actif dans le build, cyan pour ce qu'on peut apprendre tout de suite.
	if current in ["active", "learnable"]:
		var glow: Color = HunterTreeSkin.GOLD if current == "active" else HunterTreeSkin.CYAN
		draw_rect(rect.grow(3), Color(glow, 0.45), false, 1.5)
		draw_rect(rect.grow(6), Color(glow, 0.15), false, 3.0)
	if picked or hovered:
		draw_rect(rect.grow(4), Color(0.13, 0.16, 0.23, 0.95))
		draw_rect(rect.grow(4), HunterTreeSkin.CYAN if picked else Color(ink, 0.8), false, 2.0 if picked else 1.0)
	draw_texture_rect(border, rect, false, Color(1, 1, 1, 0.55 if faded else 1.0))
	if portrait:
		draw_texture_rect(portrait, rect.grow(-rect.size.x * 0.12), false, Color(1, 1, 1, 0.4 if faded else 1.0))
	else:
		_draw_symbol(rect, ink.darkened(0.45) if faded else ink)
	if data.kind == SkillNodeData.Kind.VARIANT:
		_badge(Vector2(rect.get_center().x, rect.position.y + 1), HunterTreeSkin.variant_letter(data), HunterTreeSkin.PAPER)
	_draw_state(rect)


func _badge(center: Vector2, text: String, color: Color) -> void:
	var font: Font = UiKit.font(&"numbers")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8
	var box := Rect2(center - Vector2(width * 0.5, 7), Vector2(width, 14))
	draw_rect(box, HunterTreeSkin.NIGHT)
	draw_rect(box, Color(color, 0.5), false, 1.0)
	draw_string(font, box.position + Vector2(4, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


func _draw_state(rect: Rect2) -> void:
	var point: Vector2 = rect.end - Vector2(4, 4)
	# Avec une étiquette de coût, le repère d'état du coin la gênerait : le cadre porte déjà l'état.
	match "" if tag != "" else current:
		"locked":
			draw_circle(point, 7, HunterTreeSkin.NIGHT)
			draw_rect(Rect2(point - Vector2(3.5, -0.5), Vector2(7, 5)), HunterTreeSkin.MUTED)
			draw_arc(point - Vector2(0, 0.5), 2.5, PI, TAU, 8, HunterTreeSkin.MUTED, 1.5, true)
		"learnable":
			draw_circle(point, 7, HunterTreeSkin.NIGHT)
			draw_line(point - Vector2(4, 0), point + Vector2(4, 0), HunterTreeSkin.CYAN, 2)
			draw_line(point - Vector2(0, 4), point + Vector2(0, 4), HunterTreeSkin.CYAN, 2)
		"active":
			draw_circle(point, 6, HunterTreeSkin.NIGHT)
			draw_circle(point, 4, HunterTreeSkin.GOLD)
		"upcoming":
			draw_circle(point, 7, HunterTreeSkin.NIGHT)
			for x: int in [-3, 0, 3]:
				draw_circle(point + Vector2(x, 0), 1, HunterTreeSkin.MUTED)
	if max_rank > 1 and rank > 0:
		_badge(Vector2(rect.position.x + 12, rect.position.y + 6), "%d/%d" % [rank, max_rank],
			HunterTreeSkin.GOLD if current == "active" else HunterTreeSkin.PAPER)
	if tag != "":
		_badge(Vector2(rect.get_center().x, rect.end.y - 3), tag, tag_color)


func _draw_symbol(rect: Rect2, color: Color) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = rect.size.x * 0.21
	match symbol:
		&"might":
			draw_line(center + Vector2(-radius, radius), center + Vector2(radius, -radius), color, 3, true)
			draw_line(center + Vector2(-radius * 0.9, radius * 0.1), center + Vector2(-radius * 0.1, radius * 0.9), color, 3, true)
			return
		&"focus":
			draw_arc(center, radius, -2.2, 2.6, 24, color, 2.5, true)
			draw_line(center, center + Vector2(0, -radius * 0.7), color, 2, true)
			draw_line(center, center + Vector2(radius * 0.5, 0), color, 2, true)
			return
		&"spell":
			for i: int in 4:
				var direction: Vector2 = Vector2.RIGHT.rotated(i * PI / 4.0) * radius
				draw_line(center - direction, center + direction, color, 2, true)
			draw_circle(center, radius * 0.3, color)
			return
		&"signature":
			_crown(center, radius, color)
			return
	if data.kind == SkillNodeData.Kind.KEYSTONE:
		_crown(center, radius, color)
	elif data.kind in [SkillNodeData.Kind.TRANSFORM, SkillNodeData.Kind.VARIANT]:
		draw_arc(center, radius, 0.2, 4.7, 16, color, 1.5, true)
		draw_arc(center, radius * 0.55, 3.3, 7.9, 16, color, 1.5, true)
	else:
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), color, 2, true)
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), color, 2, true)


func _crown(center: Vector2, radius: float, color: Color) -> void:
	var crown := PackedVector2Array([center + Vector2(-radius, -3), center + Vector2(-radius * 0.6, radius),
		center + Vector2(radius * 0.6, radius), center + Vector2(radius, -3), center + Vector2(radius * 0.4, 1),
		center + Vector2(0, -radius), center + Vector2(-radius * 0.4, 1), center + Vector2(-radius, -3)])
	draw_polyline(crown, color, 2, true)
