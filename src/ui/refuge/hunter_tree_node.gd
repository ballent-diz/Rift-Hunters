class_name HunterTreeNode
extends Button
## Nœud graphique. La sélection ne dépense rien ; toutes les actions restent dans le panneau de détail.

var data: SkillNodeData
var current: String
var picked := false
var large := false
var expanded := false
var caption_above := false
var ink: Color
var portrait: Texture2D
var border: Texture2D
var rank := 0
var caption: Label


func setup(p: ProfileData, node: SkillNodeData, selected: StringName) -> void:
	data = node
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Le bouton ne porte pas de texte ; sa légende est un Label indépendant.
	add_theme_font_size_override("font_size", 1)
	name = str(node.id)
	current = HunterTreeSkin.state(p, node)
	picked = node.id == selected
	ink = HunterTreeSkin.accent(node.branch)
	portrait = HunterTreeSkin.icon(node)
	border = HunterTreeSkin.frame(node, current)
	rank = HunterTree.active_rank(p, node) if current == "active" else HunterTree.learned_rank(p, node)
	tooltip_text = "%s · %s\n%s" % [tr(node.name_key), HunterTreeSkin.state_text(p, node), tr(node.desc_key)]
	for key: String in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(key, StyleBoxEmpty.new())
	caption = HunterTreeSkin.trimmed(tr(node.name_key), 11, ink if current in ["active", "learned"] else HunterTreeSkin.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect: Rect2 = emblem_rect()
	var side: float = rect.size.y
	var faded: bool = current in ["locked", "upcoming"]
	if picked or is_hovered() or has_focus():
		draw_rect(rect.grow(4), Color(0.13, 0.16, 0.23, 0.95))
		draw_rect(rect.grow(4), HunterTreeSkin.CYAN if picked else ink, false, 1.5)
	draw_texture_rect(border, rect, false, Color(1, 1, 1, 0.65 if faded else 1.0))
	if portrait:
		draw_texture_rect(portrait, rect.grow(-7), false, Color(1, 1, 1, 0.5 if faded else 1.0))
	else:
		_draw_symbol(rect, ink.darkened(0.45) if faded else ink)
	if portrait and data.kind == SkillNodeData.Kind.VARIANT:
		var badge := Rect2(Vector2(rect.get_center().x - 6, rect.position.y), Vector2(12, 12))
		draw_rect(badge, HunterTreeSkin.NIGHT)
		draw_string(ThemeDB.fallback_font, badge.position + Vector2(2, 10), HunterTreeSkin.variant_letter(data),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HunterTreeSkin.PAPER)
	_draw_state(rect)
	if caption.visible:
		var width: float = minf(size.x, 120 if expanded else 116)
		caption.position = Vector2((size.x - width) * 0.5, 0 if caption_above else side)
		caption.size = Vector2(width, 36 if expanded else 15)
		draw_rect(Rect2(caption.position, caption.size), HunterTreeSkin.NIGHT)


func _draw_symbol(rect: Rect2, color: Color) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = rect.size.x * 0.21
	if data.kind == SkillNodeData.Kind.VARIANT:
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), HunterTreeSkin.variant_letter(data),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	elif data.kind == SkillNodeData.Kind.KEYSTONE:
		var crown := PackedVector2Array([center + Vector2(-radius, -3), center + Vector2(-radius * 0.6, radius),
			center + Vector2(radius * 0.6, radius), center + Vector2(radius, -3), center,
			center + Vector2(0, -radius), center + Vector2(-radius, -3)])
		draw_polyline(crown, color, 1.5, true)
	elif data.kind == SkillNodeData.Kind.TRANSFORM:
		draw_arc(center, radius, 0.2, 4.7, 16, color, 1.5, true)
		draw_arc(center, radius * 0.55, 3.3, 7.9, 16, color, 1.5, true)
	elif data.branch == &"blade":
		draw_line(center + Vector2(-radius, radius), center + Vector2(radius, -radius), color, 2, true)
		draw_line(center + Vector2(-radius, 1), center + Vector2(-1, radius), color, 2, true)
	elif data.branch == &"prism":
		draw_polyline(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
			center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)]), color, 1.5, true)
	elif data.branch == &"abyss":
		draw_arc(center, radius, -0.5, 5, 24, color, 2, true)
		draw_circle(center, 2, color)
	elif data.branch == &"bond":
		for offset: Vector2 in [Vector2(-5, -3), Vector2(5, -3), Vector2(0, 5)]:
			draw_circle(center + offset, 2.5, color)
		draw_arc(center, radius + 1, 0, TAU, 20, color, 1, true)
	else:
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), color, 2, true)
		draw_line(center - Vector2(0, radius), center + Vector2(0, radius), color, 2, true)


func _draw_state(rect: Rect2) -> void:
	var point: Vector2 = rect.end - Vector2(3, 3)
	draw_circle(point, 5, HunterTreeSkin.NIGHT)
	match current:
		"locked":
			draw_rect(Rect2(point - Vector2(3, 0), Vector2(6, 4)), HunterTreeSkin.MUTED)
			draw_arc(point - Vector2(0, 1), 2, PI, TAU, 8, HunterTreeSkin.MUTED, 1, true)
		"learnable":
			draw_line(point - Vector2(3, 0), point + Vector2(3, 0), HunterTreeSkin.CYAN, 1.5)
			draw_line(point - Vector2(0, 3), point + Vector2(0, 3), HunterTreeSkin.CYAN, 1.5)
		"learned":
			draw_polyline(PackedVector2Array([point + Vector2(-3, 0), point + Vector2(-1, 2),
				point + Vector2(3, -2)]), HunterTreeSkin.PAPER, 1.5, true)
		"active":
			draw_circle(point, 3, HunterTreeSkin.GOLD)
		"upcoming":
			for x: int in [-3, 0, 3]:
				draw_circle(point + Vector2(x, 0), 0.8, HunterTreeSkin.MUTED)
	if rank > 0:
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, 11), str(rank),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HunterTreeSkin.PAPER)


func emblem_rect() -> Rect2:
	var edge: float = minf(144 if large else (80 if expanded else 40),
		size.y - (0 if large else (36 if expanded else 15)))
	return Rect2(Vector2((size.x - edge) * 0.5, 36 if caption_above else 0), Vector2.ONE * edge)
