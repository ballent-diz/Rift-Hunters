class_name KeyGuide
extends RefCounted
## Aide-mémoire des touches (lot 5 des menus) : chaque action avec sa touche actuelle (réglages et mode de contrôle)
## et son bouton de manette, dessiné en pastille aux couleurs habituelles (A vert, B rouge, X bleu, Y jaune).

## Lignes de l'aide-mémoire : [clé de traduction, actions clavier, entrée manette].
const ROWS: Array = [
	["ACTION_MOVE", [&"move_up", &"move_left", &"move_down", &"move_right"], "LS"],
	["ACTION_DASH", [&"dash"], &"dash"],
	["ACTION_SPELL_1", [&"spell_1"], "RT"],
	["ACTION_SPELL_2", [&"spell_2"], "LT"],
	["ACTION_SPELL_3", [&"spell_3"], &"spell_3"],
	["ACTION_SPELL_4", [&"spell_4"], &"spell_4"],
	["ACTION_TECHNIQUE_1", [&"technique_1"], &"technique_1"],
	["ACTION_TECHNIQUE_2", [&"technique_2"], &"technique_2"],
	["ACTION_TECHNIQUE_3", [&"technique_3"], &"technique_3"],
	["ACTION_OPEN_CHOICES", [&"open_choices"], &"open_choices"],
	["ACTION_TOGGLE_MAP", [&"toggle_map"], &"toggle_map"],
	["ACTION_PAUSE", [&"pause"], &"pause"],
]
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_START: "Start", JOY_BUTTON_DPAD_UP: "✚ ↑", JOY_BUTTON_DPAD_RIGHT: "✚ →",
	JOY_BUTTON_DPAD_DOWN: "✚ ↓", JOY_BUTTON_DPAD_LEFT: "✚ ←",
}
const PAD_COLORS := {
	"A": Color(0.4, 0.85, 0.4), "B": Color(0.95, 0.4, 0.4), "X": Color(0.4, 0.6, 1.0), "Y": Color(1.0, 0.85, 0.3),
}


## Libellé manette d'une action ("" : aucune).
static func pad_label(entry: Variant) -> String:
	if entry is String:
		return entry
	var buttons: Array = InputSetup.JOY_BUTTONS.get(entry, [])
	return str(PAD_NAMES.get(buttons[0], "")) if not buttons.is_empty() else ""


## Libellé clavier d'une ligne (déplacement : les quatre touches ; clic gauche en plus du Sort 1 en mode souris).
static func keys_label(actions: Array) -> String:
	var labels: PackedStringArray = []
	for action: StringName in actions:
		labels.append(InputSetup.key_label(action))
	var text: String = " ".join(labels) if actions.size() > 1 else labels[0]
	if actions == [&"spell_1"] and Settings.uses_mouse():
		text += " / " + TranslationServer.translate("KEY_GUIDE_CLICK")
	return text


static func build(font_size: int = 15) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "KeyGuide"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for header: String in ["KEY_GUIDE_ACTION", "KEY_GUIDE_KEYBOARD", "KEY_GUIDE_PAD"]:
		grid.add_child(UiKit.caption(TranslationServer.translate(header), 11, UiKit.MUTED))
	for row: Array in ROWS:
		grid.add_child(UiKit.label(TranslationServer.translate(row[0]), font_size, MenuSkin.PAPER))
		grid.add_child(_chip(keys_label(row[1]), MenuSkin.PAPER, font_size))
		var pad: String = pad_label(row[2])
		grid.add_child(_chip(pad, PAD_COLORS.get(pad, Color(0.8, 0.75, 0.9)), font_size) if pad != ""
			else UiKit.label("—", font_size, UiKit.MUTED))
	return grid


static func _chip(text: String, color: Color, font_size: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var frame: StyleBoxFlat = MenuSkin.frame(Color(color, 0.14), Color(color, 0.7))
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(6)
	frame.content_margin_left = 8
	frame.content_margin_right = 8
	frame.content_margin_top = 1
	frame.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", frame)
	chip.add_child(UiKit.label(text, font_size, color))
	return chip
