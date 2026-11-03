class_name CreditsScreen
extends Control
## Générique (menu principal) : il défile tout seul sur un fond de failles. Titre et Chasseur, galeries animées des
## Échos et des Dévoreurs (leurs vrais sprites de jeu), cartes des ressources, remerciements. Les licences complètes
## s'ouvrent à part (celle de Godot accompagne toute distribution). La molette ou un glissement reprend la main.

signal closed

## Vitesse du défilement (pixels par seconde) et reprise après une action de l'utilisateur.
const SPEED := 48.0
const RESUME_AFTER := 4.0
const DEVOURERS: Array[StringName] = [&"nebulorax", &"astravorn", &"source_devourer", &"pyrevorn", &"glauquemire",
	&"nivorath"]
const MOTES := 80
const RIFT := Color(0.72, 0.45, 1.0)
const WIDTH := 1180.0

var back_button: Button
var _scroll: ScrollContainer
var _offset: float = 0.0
var _resume_at: float = 0.0
var _time: float = 0.0
## Particules de faille : x, y (0..1), phase.
var _motes: Array[Vector3] = []
var _licenses: Control


func _ready() -> void:
	name = "CreditsScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuSkin.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in MOTES:
		_motes.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_bottom = -96.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.gui_input.connect(_on_scroll_input)
	add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_theme_constant_override("separation", 64)
	center.add_child(column)
	column.add_child(_spacer(520))
	_header(column)
	_creation(column)
	_gallery(column, tr("CREDITS_ECHOES"), tr("CREDITS_ECHOES_SUB") % GameDB.monsters.size(), _echo_visuals(), 8)
	_gallery(column, tr("CREDITS_DEVOURERS"), tr("CREDITS_DEVOURERS_SUB"), _devourer_visuals(), 6)
	_resources(column)
	_thanks(column)
	# Le défilement s'arrête avec les remerciements au milieu de l'écran.
	column.add_child(_spacer(250))
	_bottom_bar()


func _process(delta: float) -> void:
	_time += delta
	if _time >= _resume_at and _licenses == null:
		var end: float = maxf(_scroll.get_v_scroll_bar().max_value - _scroll.size.y, 0.0)
		_offset = minf(_offset + SPEED * delta, end)
		_scroll.scroll_vertical = int(_offset)
	queue_redraw()


## L'utilisateur fait défiler : on lui laisse la main quelques secondes.
func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenDrag or event is InputEventPanGesture:
		_resume_at = _time + RESUME_AFTER
		_offset = float(_scroll.scroll_vertical)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


## Fond : nuit de faille, lueur centrale et particules qui montent.
func _draw() -> void:
	var area: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, area), Color(0.035, 0.03, 0.075))
	for i: int in 6:
		var radius: float = area.y * (0.9 - i * 0.13)
		draw_circle(area * Vector2(0.5, 0.42), radius, Color(RIFT, 0.025 + i * 0.012))
	for mote: Vector3 in _motes:
		var y: float = fposmod(mote.y - _time * (0.015 + 0.02 * fposmod(mote.z, 1.0)), 1.0)
		var x: float = mote.x + 0.012 * sin(_time * 0.8 + mote.z)
		var glow: float = 0.35 + 0.35 * sin(_time * 2.0 + mote.z)
		var color: Color = UiKit.ACCENT if fmod(mote.z, 2.0) < 1.0 else RIFT
		draw_circle(Vector2(x, y) * area, 1.5 + 2.0 * glow, Color(color, 0.25 + 0.4 * glow))


# --- Contenu ---------------------------------------------------------------------------------------------------

func _header(column: VBoxContainer) -> void:
	var title: Label = UiKit.title("RIFT HUNTERS", 84, MenuSkin.PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(RIFT, 0.55))
	column.add_child(title)
	var tagline: Label = UiKit.label(tr("CREDITS_TAGLINE"), 24, UiKit.ACCENT)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	var hunter := VisualData.new()
	hunter.visual_id = &"player.hunter"
	hunter.shape = VisualData.Shape.HUNTER
	hunter.size = 40.0
	column.add_child(_portrait(hunter, tr("CREDITS_HUNTER"), Vector2(260, 260), MenuSkin.LANTERN))


func _creation(column: VBoxContainer) -> void:
	var card: PanelContainer = _card(MenuSkin.LANTERN)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(760, 0)
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_centered(UiKit.title(tr("CREDITS_CREATION"), 30, MenuSkin.LANTERN)))
	box.add_child(_centered(UiKit.label(tr("CREDITS_TEAM"), 34, MenuSkin.PAPER)))
	var roles: Label = _centered(UiKit.label(tr("CREDITS_CREATION_ROLES"), 18, UiKit.MUTED))
	roles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(roles)
	column.add_child(card)


func _gallery(column: VBoxContainer, heading: String, subtitle: String, entries: Array, columns: int) -> void:
	column.add_child(_section_title(heading, subtitle))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	var cell: float = floorf((WIDTH - 14.0 * (columns - 1)) / columns)
	for entry: Array in entries:
		grid.add_child(_portrait(entry[0], entry[1], Vector2(cell, cell * 0.95), entry[2]))
	column.add_child(grid)


func _resources(column: VBoxContainer) -> void:
	column.add_child(_section_title(tr("CREDITS_RESOURCES"), ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(WIDTH, 0)
	row.add_child(_resource(tr("CREDITS_ENGINE_TITLE"), "Godot Engine", UiKit.font(&"title"), tr("CREDITS_ENGINE_BODY"),
		tr("CREDITS_ENGINE_LICENSE"), UiKit.ACCENT))
	row.add_child(_resource(tr("CREDITS_FONTS_TITLE"), "Cinzel · Inter", UiKit.font(&"title"), tr("CREDITS_FONTS_BODY"),
		tr("CREDITS_FONTS_LICENSE"), MenuSkin.LANTERN))
	row.add_child(_resource(tr("CREDITS_TILES_TITLE"), "Ninja Adventure", UiKit.font(&"title"), tr("CREDITS_TILES_BODY"),
		tr("CREDITS_TILES_LICENSE"), Color(0.55, 0.9, 0.55)))
	column.add_child(row)


func _thanks(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	var pick: Array = _echo_visuals()
	if pick.size() >= 2:
		row.add_child(_portrait(pick[0][0], "", Vector2(180, 180), Color(0, 0, 0, 0)))
	var thanks: Label = UiKit.title(tr("CREDITS_THANKS"), 48, MenuSkin.PAPER)
	thanks.add_theme_constant_override("outline_size", 8)
	thanks.add_theme_color_override("font_outline_color", Color(RIFT, 0.5))
	thanks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(thanks)
	if pick.size() >= 2:
		row.add_child(_portrait(pick[pick.size() - 1][0], "", Vector2(180, 180), Color(0, 0, 0, 0)))
	column.add_child(row)


func _echo_visuals() -> Array:
	var list: Array = []
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var monster: MonsterData = GameDB.monsters[id]
		list.append([monster.visual, tr(monster.name_key), monster.visual.accent])
	return list


func _devourer_visuals() -> Array:
	var list: Array = []
	for id: StringName in DEVOURERS:
		var boss: BossData = GameDB.boss(id)
		if boss:
			list.append([boss.visual, tr(boss.name_key), boss.visual.accent])
	return list


# --- Briques ---------------------------------------------------------------------------------------------------

func _portrait(data: VisualData, caption: String, area: Vector2, accent: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.055, 0.12, 0.85) if accent.a > 0.0 else Color(0, 0, 0, 0)
	style.border_color = Color(accent, 0.75)
	style.set_border_width_all(2 if accent.a > 0.0 else 0)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", style)
	var portrait := EchoPortrait.new()
	portrait.custom_minimum_size = area - Vector2(4, 4)
	frame.add_child(portrait)
	portrait.setup_visual(data)
	box.add_child(frame)
	if caption != "":
		var label: Label = _centered(UiKit.label(caption, 16, MenuSkin.PAPER))
		box.add_child(label)
	return box


func _card(accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.07, 0.055, 0.12, 0.9), accent))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	return card


func _resource(heading: String, name_text: String, name_font: Font, body: String, license: String,
		accent: Color) -> PanelContainer:
	var card: PanelContainer = _card(accent)
	card.custom_minimum_size = Vector2(370, 0)
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_centered(UiKit.caption(heading.to_upper(), 14, accent)))
	var title: Label = _centered(UiKit.label(name_text, 30, MenuSkin.PAPER))
	title.add_theme_font_override("font", name_font)
	box.add_child(title)
	box.add_child(_centered(UiKit.wrapped(body, 16, UiKit.MUTED)))
	box.add_child(_centered(UiKit.caption(license, 13, Color(accent, 0.9))))
	return card


func _section_title(heading: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_centered(UiKit.title(heading, 40, MenuSkin.LANTERN)))
	var line := ColorRect.new()
	line.color = Color(MenuSkin.LANTERN, 0.55)
	line.custom_minimum_size = Vector2(220, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(line)
	if subtitle != "":
		box.add_child(_centered(UiKit.label(subtitle, 18, UiKit.MUTED)))
	return box


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_top = -80.0
	bar.offset_bottom = -24.0
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.add_theme_constant_override("separation", 24)
	add_child(bar)
	bar.add_child(UiKit.button(tr("CREDITS_LICENSES"), _show_licenses, 240))
	back_button = UiKit.button(tr("CREDITS_BACK"), _close, 240)
	bar.add_child(back_button)
	back_button.grab_focus.call_deferred()


## Licences complètes : moteur (obligatoire), polices, décors.
func _show_licenses() -> void:
	if _licenses:
		return
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", MenuSkin.frame())
	add_child(panel)
	_licenses = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiKit.title(tr("CREDITS_LICENSES"), 32, UiKit.ACCENT))
	var text := RichTextLabel.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 15)
	text.text = tr("CREDITS_LICENSES_BODY") + "\n\n" + Engine.get_license_text()
	box.add_child(text)
	var back: Button = UiKit.button(tr("CREDITS_BACK"), func() -> void:
		panel.queue_free()
		_licenses = null
		back_button.grab_focus(), 260)
	box.add_child(back)
	back.grab_focus.call_deferred()


func _close() -> void:
	closed.emit()
	queue_free()
