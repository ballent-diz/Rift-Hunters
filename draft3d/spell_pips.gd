class_name DraftSpellPips
extends Control
## Recharges des sorts sous le Chasseur (demande du propriétaire, 15 novembre 2026) : une petite case par sort appris,
## avec l'icône du sort (celle de la barre), voilée pendant la recharge (le voile se retire de bas en haut) et cerclée
## de sa couleur quand il est prêt, pour suivre la disponibilité des sorts sans quitter l'action des yeux.
## Suit la position affichée du Chasseur (caméra lisse ou rendu pixel).

const SIZE := 26.0
const GAP := 4.0
## Distance sous les pieds du Chasseur (pixels d'écran).
const BELOW := 14.0

var run: DraftRun


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null or run.spells == null or run.hunter == null or not run.hunter.alive or run.camera == null:
		return
	var spells: DraftSpells = run.spells
	var shown: Array[int] = []
	for i: int in spells.slots.size():
		if spells.slots[i] != null:
			shown.append(i)
	if shown.is_empty():
		return
	var feet: Vector2 = run.screen_point(run.hunter.view.render_position())
	var width: float = shown.size() * (SIZE + GAP) - GAP
	var x: float = feet.x - width * 0.5
	var font: Font = get_theme_default_font()
	for i: int in shown:
		var data: SpellData = spells.slots[i]
		var rect := Rect2(x, feet.y + BELOW, SIZE, SIZE)
		var ready: bool = spells.ready(i)
		draw_rect(rect, Color(0.04, 0.05, 0.09, 0.75))
		var icon: Texture2D = DraftSpellBar.icon_for(data)
		if icon != null:
			draw_texture_rect(icon, rect.grow(-1.5), false, Color(1, 1, 1, 1.0 if ready else 0.5))
		else:
			draw_rect(rect.grow(-3.0), Color(data.color, 0.85 if ready else 0.35))
		if not ready:
			# Voile qui se retire de bas en haut pendant la recharge.
			var veil: float = 1.0 - spells.ready_ratio(i)
			draw_rect(Rect2(rect.position, Vector2(SIZE, SIZE * veil)), Color(0, 0, 0, 0.55))
		draw_rect(rect, data.color.lightened(0.3) if ready else Color(0.5, 0.52, 0.6, 0.8), false, 1.5 if ready else 1.0)
		if not ready and spells.cooldowns[i] >= 1.0:
			var text: String = str(ceili(spells.cooldowns[i]))
			draw_string_outline(font, rect.position + Vector2(0, SIZE - 7), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 13, 3,
				Color(0, 0, 0, 0.9))
			draw_string(font, rect.position + Vector2(0, SIZE - 7), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 13, Color.WHITE)
		x += SIZE + GAP
