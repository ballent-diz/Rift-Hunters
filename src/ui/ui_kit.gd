class_name UiKit
extends RefCounted
## Fabrique d'éléments d'interface cohérents (thème sombre, lisible, adapté à toutes résolutions).

const BG := Color(0.05, 0.06, 0.1, 0.92)
const PANEL := Color(0.1, 0.11, 0.18, 0.97)
const BORDER := Color(0.35, 0.4, 0.6)
const TEXT := Color(0.92, 0.94, 1.0)
const MUTED := Color(0.62, 0.66, 0.8)
const ACCENT := Color(0.55, 0.9, 1.0)
const GOLD := Color(1.0, 0.85, 0.4)
const DANGER := Color(1.0, 0.4, 0.6)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = ThemeDB.fallback_font
	_theme.default_font_size = 18
	_theme.set_stylebox("normal", "Button", _box(Color(0.14, 0.16, 0.26), BORDER, 2))
	_theme.set_stylebox("hover", "Button", _box(Color(0.2, 0.23, 0.36), ACCENT, 2))
	_theme.set_stylebox("pressed", "Button", _box(Color(0.1, 0.12, 0.2), ACCENT, 2))
	_theme.set_stylebox("disabled", "Button", _box(Color(0.1, 0.1, 0.14), Color(0.25, 0.25, 0.3), 2))
	_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 2))
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 2))
	_theme.set_stylebox("panel", "Panel", _box(PANEL, BORDER, 2))
	_theme.set_stylebox("tab_selected", "TabContainer", _box(Color(0.2, 0.23, 0.36), ACCENT, 2))
	_theme.set_stylebox("tab_unselected", "TabContainer", _box(Color(0.1, 0.11, 0.18), BORDER, 1))
	_theme.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.16, 0.18, 0.28), ACCENT, 1))
	_theme.set_stylebox("panel", "TabContainer", _box(Color(0.07, 0.08, 0.13, 0.96), BORDER, 2))
	return _theme


static func _box(bg: Color, border: Color, width: int, radius: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func panel_box(border: Color = BORDER, bg: Color = PANEL) -> StyleBoxFlat:
	return _box(bg, border, 2, 8)


static func label(text: String, size: int = 18, color: Color = TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func wrapped(text: String, size: int = 16, color: Color = MUTED) -> Label:
	var l: Label = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


static func button(text: String, callback: Callable, min_width: float = 200.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44)
	b.pressed.connect(func() -> void: Audio.play_sfx(&"ui_click"))
	b.pressed.connect(callback)
	return b


## Fond assombri plein écran qui bloque la souris.
static func dimmer(alpha: float = 0.72) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


static func center_box(parent: Control, separation: int = 16) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return box


static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Carte de choix (amélioration, relique) : bandeau de couleur, catégorie, titre, description.
static func card(category: String, title: String, description: String, accent: Color, callback: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 230)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal: StyleBoxFlat = _box(Color(0.11, 0.12, 0.2), accent.darkened(0.3), 2, 10)
	normal.border_width_top = 6
	b.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = _box(Color(0.17, 0.19, 0.3), accent, 3, 10)
	hover.border_width_top = 8
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(callback)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_right = -14
	box.offset_top = 16
	box.offset_bottom = -12
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	b.add_child(box)
	var cat: Label = label(category.to_upper(), 13, accent)
	box.add_child(cat)
	var t: Label = label(title, 21, TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(t)
	var d: Label = wrapped(description, 15, MUTED)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(d)
	for child: Control in [cat, t, d]:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b
