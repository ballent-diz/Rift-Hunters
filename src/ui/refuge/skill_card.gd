class_name SkillCard
extends PanelContainer
## Fiche compacte d'une compétence (arbre du Chasseur, arbres des Échos) : en-tête icône + nom, effet lisible
## sans défiler (chiffres clés en couleur), précisions discrètes, actions toujours visibles en bas.
## Aucune règle de jeu : l'appelant fournit les textes et les boutons.

const WIDTH := 320.0
const NUMBER_COLOR := "f3c886"

var _box: VBoxContainer
var _actions: VBoxContainer


func _init() -> void:
	custom_minimum_size.x = WIDTH
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.05, 0.04, 0.1, 0.97), MenuSkin.COPPER))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)


## Contenu : title, accent, icon (Texture2D ou null), kind, state, state_color, body, facts, notes (PackedStringArray).
func show_entry(entry: Dictionary) -> void:
	UiKit.clear(_box)
	var accent: Color = entry.get("accent", UiKit.TEXT)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_box.add_child(header)
	var icon: Texture2D = entry.get("icon")
	if icon:
		var image := TextureRect.new()
		image.texture = icon
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(56, 56)
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		header.add_child(image)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	var title: Label = UiKit.title(str(entry.get("title", "")), 19, accent)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(title)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	heading.add_child(tags)
	tags.add_child(UiKit.caption(str(entry.get("kind", "")), 11, MenuSkin.PAPER.darkened(0.25)))
	var state: String = str(entry.get("state", ""))
	if state != "":
		tags.add_child(UiKit.caption("· " + state, 11, entry.get("state_color", UiKit.ACCENT)))
	_box.add_child(_rule(accent))
	var body := RichTextLabel.new()
	body.name = "SkillBody"
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("normal_font", UiKit.font(&"body"))
	body.add_theme_font_override("bold_font", UiKit.font(&"strong"))
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_font_size_override("bold_font_size", 15)
	body.add_theme_color_override("default_color", MenuSkin.PAPER)
	body.text = highlight(str(entry.get("body", "")))
	# Effet, chiffres et conditions se lisent d'un bloc ; le défilement ne sert qu'aux textes exceptionnellement longs.
	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var facts: String = str(entry.get("facts", ""))
	if facts != "":
		var facts_label: Label = UiKit.label(facts, 13, UiKit.MUTED)
		facts_label.add_theme_font_override("font", UiKit.font(&"numbers"))
		facts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(facts_label)
	var steps: Array = entry.get("steps", [])
	if not steps.is_empty():
		var steps_box := VBoxContainer.new()
		steps_box.name = "SkillSteps"
		steps_box.add_theme_constant_override("separation", 6)
		steps_box.add_child(UiKit.caption(str(entry.get("steps_title", "")), 10, MenuSkin.PAPER.darkened(0.25)))
		for step: Dictionary in steps:
			steps_box.add_child(_step_row(step))
		content.add_child(steps_box)
	for note: String in entry.get("notes", PackedStringArray()):
		content.add_child(UiKit.wrapped(note, 13, UiKit.GOLD))
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	_box.add_child(_actions)


## Message seul (rien de sélectionné).
func show_hint(text: String) -> void:
	UiKit.clear(_box)
	var hint: Label = UiKit.wrapped(text, 15, UiKit.MUTED)
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)


## Bouton d'action en pied de fiche ; primary = l'action conseillée, mise en avant.
func add_action(button_name: String, text: String, callback: Callable, enabled: bool, primary: bool = false) -> Button:
	var b: Button = UiKit.button(text, callback, 0)
	b.name = button_name
	b.disabled = not enabled
	b.custom_minimum_size.y = 40 if primary else 34
	b.add_theme_font_size_override("font_size", 16 if primary else 14)
	if primary:
		b.add_theme_stylebox_override("normal", MenuSkin.frame(Color(0.26, 0.1, 0.12), MenuSkin.LANTERN))
		b.set_meta(MenuSkin.KEEP_STYLE, true)
	_actions.add_child(b)
	return b


## Raison pour laquelle l'action conseillée est impossible (ligne discrète au-dessus des boutons).
func add_reason(text: String) -> void:
	if text != "":
		_actions.add_child(UiKit.wrapped(text, 13, UiKit.MUTED))


## Met en couleur les valeurs chiffrées (dégâts, %, secondes) ; le texte traduit est échappé du BBCode.
static func highlight(text: String) -> String:
	var escaped: String = text.replace("[", "[lb]")
	var regex := RegEx.create_from_string("[+−-]?\\d+(?:[.,]\\d+)?(?:[ \\x{00A0}\\x{202F}]?%| ?s\\b| PV| HP)?")
	var result: String = ""
	var last: int = 0
	for found: RegExMatch in regex.search_all(escaped):
		result += escaped.substr(last, found.get_start() - last)
		result += "[color=#%s][b]%s[/b][/color]" % [NUMBER_COLOR, found.get_string()]
		last = found.get_end()
	return result + escaped.substr(last)


## Infobulle compacte au survol d'un nœud (même mise en forme, sans actions).
static func tooltip(title_text: String, kind: String, state: String, body_text: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.05, 0.04, 0.1, 0.98), accent.darkened(0.2)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(UiKit.title(title_text, 16, accent))
	box.add_child(UiKit.caption(kind + ("  · " + state if state != "" else ""), 11, UiKit.MUTED))
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size.x = 280
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("normal_font", UiKit.font(&"body"))
	body.add_theme_font_override("bold_font", UiKit.font(&"strong"))
	body.add_theme_font_size_override("normal_font_size", 14)
	body.add_theme_font_size_override("bold_font_size", 14)
	body.add_theme_color_override("default_color", MenuSkin.PAPER)
	body.text = highlight(body_text)
	box.add_child(body)
	return panel


## Étape du parcours d'une compétence : pastille d'état, intitulé, précision (coût, condition manquante).
## step : state (done, next, blocked, todo, info), number, title, detail.
func _step_row(step: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var state: String = str(step.get("state", "todo"))
	var badge := StepBadge.new()
	badge.state = state
	badge.number = int(step.get("number", 0))
	row.add_child(badge)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var title: Label = UiKit.label(str(step.get("title", "")), 14, StepBadge.color_of(state).lightened(0.15))
	title.add_theme_font_override("font", UiKit.font(&"strong"))
	text.add_child(title)
	var detail: String = str(step.get("detail", ""))
	if detail != "":
		text.add_child(UiKit.wrapped(detail, 12, MenuSkin.PAPER.darkened(0.2) if state == "next" else UiKit.MUTED))
	return row


## Pastille d'une étape : coche (fait), numéro cerclé (à faire maintenant), cadenas (bloqué), numéro terne (plus tard).
class StepBadge:
	extends Control

	var state: String = "todo"
	var number: int = 0

	static func color_of(p_state: String) -> Color:
		match p_state:
			"done": return HunterTreeSkin.GOLD
			"next": return HunterTreeSkin.CYAN
			"blocked": return HunterTreeSkin.SHORT
		return HunterTreeSkin.MUTED

	func _init() -> void:
		custom_minimum_size = Vector2(22, 22)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := Vector2(11, 11)
		var color: Color = color_of(state)
		match state:
			"done":
				draw_circle(center, 10, Color(color, 0.9))
				draw_polyline(PackedVector2Array([center + Vector2(-5, 0), center + Vector2(-1, 4), center + Vector2(5, -4)]),
					HunterTreeSkin.NIGHT, 2.5, true)
				return
			"blocked":
				draw_circle(center, 10, Color(0.22, 0.07, 0.1))
				draw_arc(center, 10, 0, TAU, 28, Color(color, 0.8), 1.5, true)
				draw_rect(Rect2(center + Vector2(-4, -1), Vector2(8, 6)), color)
				draw_arc(center + Vector2(0, -1), 2.8, PI, TAU, 10, color, 1.5, true)
				return
		draw_circle(center, 10, Color(color, 0.16 if state == "next" else 0.06))
		draw_arc(center, 10, 0, TAU, 28, color, 2.0 if state == "next" else 1.0, true)
		if number > 0:
			var font: Font = UiKit.font(&"numbers")
			var text: String = str(number)
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(font, center + Vector2(-width * 0.5, 4.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _rule(accent: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(accent, 0.35)
	line.custom_minimum_size.y = 1
	return line
