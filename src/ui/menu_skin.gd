class_name MenuSkin
extends RefCounted
## Thème local aux menus : aucun changement du HUD ou du thème partagé UiKit.

const BACKDROP := preload("res://assets/ui/menus/refuge-backdrop.png")
const PAPER := Color(1.0, 0.91, 0.8)
const COPPER := Color(0.6, 0.38, 0.42)
const LANTERN := Color(1.0, 0.55, 0.36)
const NIGHT := Color(0.055, 0.045, 0.105, 0.96)
## Métadonnée d'un bouton dont le style propre doit être conservé par finish() (action principale…).
const KEEP_STYLE := &"menu_skin_keep_style"

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = UiKit.theme().duplicate(true)
	_theme.set_stylebox("normal", "Button", frame(NIGHT, COPPER))
	_theme.set_stylebox("hover", "Button", frame(Color(0.25, 0.07, 0.16), LANTERN))
	_theme.set_stylebox("pressed", "Button", frame(Color(0.12, 0.025, 0.08), LANTERN))
	_theme.set_stylebox("disabled", "Button", frame(Color(0.05, 0.04, 0.08), COPPER.darkened(0.5)))
	_theme.set_stylebox("focus", "Button", frame(Color(0, 0, 0, 0), PAPER))
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		_theme.set_color(state, "Button", PAPER)
	for type: String in ["PanelContainer", "Panel", "TabContainer"]:
		_theme.set_stylebox("panel", type, frame(NIGHT, COPPER))
	_theme.set_stylebox("tab_selected", "TabContainer", frame(Color(0.25, 0.065, 0.15), LANTERN))
	_theme.set_stylebox("tab_unselected", "TabContainer", frame(Color(0.06, 0.045, 0.105), COPPER))
	_theme.set_stylebox("tab_hovered", "TabContainer", frame(Color(0.16, 0.08, 0.2), PAPER))
	_theme.set_color("font_selected_color", "TabContainer", PAPER)
	_theme.set_color("font_unselected_color", "TabContainer", Color(0.72, 0.66, 0.78))
	_theme.set_stylebox("scroll", "VScrollBar", frame(Color(0.04, 0.03, 0.08), COPPER.darkened(0.5)))
	_theme.set_stylebox("grabber", "VScrollBar", frame(Color(0.24, 0.12, 0.22), COPPER))
	_theme.set_stylebox("grabber_highlight", "VScrollBar", frame(Color(0.4, 0.15, 0.23), LANTERN))
	_theme.set_stylebox("grabber_pressed", "VScrollBar", frame(Color(0.3, 0.08, 0.15), LANTERN))
	for state: String in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var scrollbar: StyleBox = _theme.get_stylebox(state, "VScrollBar")
		for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			scrollbar.set_content_margin(side, 3)
	return _theme


static func frame(fill: Color = NIGHT, border: Color = COPPER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.border_width_bottom = 3
	style.set_corner_radius_all(0)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func background(parent: Control) -> void:
	var art := TextureRect.new()
	art.texture = BACKDROP
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.055, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)


## Panneau centré et défilant : les actions restent accessibles dans une petite fenêtre.
static func modal_box(parent: Control, separation: int, preferred: Vector2 = Vector2(1100, 620)) -> VBoxContainer:
	parent.theme = theme()
	var panel := PanelContainer.new()
	panel.name = "ModalFrame"
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.name = "ModalScroll"
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	scroll.add_child(box)
	var fit: Callable = func() -> void:
		var available: Vector2 = (parent.size - Vector2(48, 48)).max(Vector2(100, 100))
		var content_height: float = maxf(160, box.get_combined_minimum_size().y + 32)
		panel.size = Vector2(minf(preferred.x, available.x), minf(minf(preferred.y, content_height), available.y))
		panel.position = (parent.size - panel.size) * 0.5
	parent.resized.connect(fit)
	parent.visibility_changed.connect(func() -> void: fit.call_deferred())
	box.minimum_size_changed.connect(func() -> void: fit.call_deferred())
	fit.call_deferred()
	return box


## Harmonise seulement les cadres personnalisés ; les couleurs de rareté/état restent distinctes.
static func finish(node: Node) -> void:
	if node is Button and not node.has_meta(KEEP_STYLE):
		var button: Button = node
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state: String in ["normal", "hover", "focus"]:
			if button.has_theme_stylebox_override(state):
				var previous: StyleBox = button.get_theme_stylebox(state)
				if previous is StyleBoxFlat:
					var style: StyleBoxFlat = previous.duplicate()
					style.set_corner_radius_all(0)
					style.bg_color = NIGHT if state == "normal" else Color(0.18, 0.065, 0.16)
					button.add_theme_stylebox_override(state, style)
	for child: Node in node.get_children():
		finish(child)


## Le refresh peut remplacer les cartes avant le prochain frame.
static func focus_first(cards: Container) -> void:
	var focus: Callable = func() -> void:
		if is_instance_valid(cards) and cards.is_inside_tree() and cards.get_child_count() > 0:
			(cards.get_child(0) as Control).grab_focus()
	focus.call_deferred()
