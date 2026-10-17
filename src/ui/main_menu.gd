extends Control
## Habillage du menu uniquement ; les actions et services existants sont conservés.

const DESIGN_SIZE := Vector2(1752, 897)
const MENU_ART := preload("res://assets/ui/main_menu/refuge.png")
const INK := Color(1.0, 0.91, 0.8)

var _canvas: Control


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit_canvas)
	Settings.changed.connect(_build)
	_build()
	Audio.play_context("menu")


func _build() -> void:
	UiKit.clear(self)
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.02, 0.055)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_canvas = Control.new()
	_canvas.name = "MenuCanvas"
	_canvas.size = DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	var art := TextureRect.new()
	art.texture = MENU_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = DESIGN_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(art)
	var play: Button = UiKit.button(tr("MENU_PLAY"), func() -> void:
		Audio.play_sfx(&"ui_click")
		Router.goto_refuge(), 360)
	var settings: Button = UiKit.button(tr("MENU_LANGUAGE") % tr("LANGUAGE_NAME"), func() -> void:
		Settings.set_locale("en" if Settings.locale == "fr" else "fr"), 360)
	settings.tooltip_text = tr("OPTIONS_LANGUAGE") % tr("LANGUAGE_NAME")
	var credits: Button = UiKit.button(tr("MENU_CREDITS"), _show_credits, 360)
	var quit: Button = UiKit.button(tr("MENU_QUIT"), func() -> void: get_tree().quit(), 360)
	var buttons: Array[Button] = [play, settings, credits, quit]
	var rows: Array[Rect2] = [Rect2(298, 400, 475, 74), Rect2(298, 490, 475, 70),
		Rect2(298, 577, 475, 70), Rect2(298, 662, 475, 70)]
	for index: int in buttons.size():
		_skin_button(buttons[index], rows[index])
		buttons[index].name = ["Play", "Language", "Credits", "Quit"][index]
	for index: int in buttons.size():
		var previous: NodePath = buttons[index].get_path_to(buttons[posmod(index - 1, buttons.size())])
		var next: NodePath = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_neighbor_top = previous
		buttons[index].focus_previous = previous
		buttons[index].focus_neighbor_bottom = next
		buttons[index].focus_next = next
	var version: Label = UiKit.label("v" + str(ProjectSettings.get_setting("application/config/version")),
		19, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	version.position = Vector2(500, 747)
	version.size = Vector2(80, 32)
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(version)
	_add_warning()
	_fit_canvas()
	play.grab_focus.call_deferred()


## Une seule transformation pour l'image, le texte et les zones cliquables : aucun recadrage.
func _fit_canvas() -> void:
	if not is_instance_valid(_canvas):
		return
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - DESIGN_SIZE * factor) * 0.5


func _skin_button(button: Button, rect: Rect2) -> void:
	_canvas.add_child(button)
	button.position = rect.position
	button.custom_minimum_size = Vector2.ZERO
	button.size = rect.size
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 29)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK.darkened(0.15))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 0.55, 0.45, 0.1) if state == "hover" else Color(0, 0, 0, 0)
		if state == "pressed":
			style.bg_color = Color(0.03, 0.01, 0.08, 0.35)
		style.content_margin_left = 120
		style.content_margin_right = 54
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(1, 0.8, 0.55, 0.85)
	focus.set_border_width_all(2)
	focus.shadow_color = Color(1, 0.23, 0.35, 0.35)
	focus.shadow_size = 8
	button.add_theme_stylebox_override("focus", focus)


func _add_warning() -> void:
	var warning: String = Profile.status_message()
	if warning == "":
		return
	var panel := PanelContainer.new()
	panel.position = Vector2(890, 735)
	panel.size = Vector2(780, 125)
	panel.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.DANGER, Color(0.04, 0.025, 0.08, 0.96)))
	_canvas.add_child(panel)
	var label: Label = UiKit.label(warning, 22, INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)


## Crédits et licences (la licence de Godot doit accompagner toute distribution).
func _show_credits() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = MenuSkin.theme()
	panel.add_theme_stylebox_override("panel", MenuSkin.frame())
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiKit.title(tr("MENU_CREDITS"), 32, UiKit.ACCENT))
	var text := RichTextLabel.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 15)
	text.text = tr("CREDITS_BODY") + "\n\n" + Engine.get_license_text()
	box.add_child(text)
	var back: Button = UiKit.button(tr("CREDITS_BACK"), func() -> void: panel.queue_free(), 260)
	box.add_child(back)
	back.grab_focus.call_deferred()
