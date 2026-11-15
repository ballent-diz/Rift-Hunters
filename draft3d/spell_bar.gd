class_name DraftSpellBar
extends Control
## Barre des sorts actifs (bas de l'écran) : quatre cases avec icône de l'arbre du Chasseur, touche de l'action
## (reconfigurable), recharge qui se vide de haut en bas avec les secondes restantes, nom du sort. Une case libre
## reste visible avec sa touche : un sort appris en partie viendra s'y placer. Lecture seule de `DraftSpells`.

const SLOT := 64.0
const GAP := 34.0

var spells: DraftSpells
var _icons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2(DraftSpells.SLOTS * (SLOT + GAP) - GAP, SLOT + 22.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if spells == null:
		return
	var font: Font = get_theme_default_font()
	for i: int in DraftSpells.SLOTS:
		var rect := Rect2(i * (SLOT + GAP), 0.0, SLOT, SLOT)
		var data: SpellData = spells.slots[i]
		var key: String = InputSetup.key_label(DraftSpells.ACTIONS[i])
		draw_rect(rect, Color(0.06, 0.07, 0.11, 0.82 if data != null else 0.45))
		if data == null:
			draw_rect(rect, Color(1, 1, 1, 0.18), false, 1.0)
			_text(font, rect.position + Vector2(6, 18), key, 14, Color(1, 1, 1, 0.35))
			continue
		var ready: bool = spells.cooldowns[i] <= 0.0
		var icon: Texture2D = _icon(data)
		if icon != null:
			draw_texture_rect(icon, rect.grow(-4.0), false, Color(1, 1, 1, 1.0 if ready else 0.45))
		else:
			draw_circle(rect.get_center(), SLOT * 0.3, Color(data.color, 0.4 if ready else 0.15))
		if not ready:
			var left: float = 1.0 - spells.ready_ratio(i)
			draw_rect(Rect2(rect.position, Vector2(SLOT, SLOT * left)), Color(0, 0, 0, 0.55))
			_text(font, rect.position + Vector2(0, 40), "%.1f" % spells.cooldowns[i], 17, Color.WHITE, SLOT)
		var border: Color = data.color if ready else Color(0.55, 0.57, 0.66)
		if spells.preview_slot == i:
			border = Color.WHITE
		draw_rect(rect, border, false, 2.0)
		_text(font, rect.position + Vector2(5, 17), key, 14, Color("ffd9a0") if ready else Color(0.6, 0.6, 0.65))
		_text(font, rect.position + Vector2(-GAP * 0.5, SLOT + 15), tr(data.name_key), 11,
			Color.WHITE if ready else Color(0.65, 0.66, 0.72), SLOT + GAP)


func _text(font: Font, at: Vector2, value: String, font_size: int, color: Color, width: float = -1.0) -> void:
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
	draw_string_outline(font, at, value, align, width, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, value, align, width, font_size, color)


func _icon(data: SpellData) -> Texture2D:
	if not _icons.has(data.id):
		var node: SkillNodeData = HunterTree.spell_node(data.id)
		_icons[data.id] = HunterTreeSkin.icon(node) if node != null else null
	return _icons[data.id]
