class_name DraftSpellPips
extends Control
## Recharges des sorts sous le Chasseur (demande du propriétaire, 15 novembre 2026) : une petite case par sort appris,
## qui se remplit de bas en haut pendant la recharge et s'allume quand le sort est prêt, pour suivre la disponibilité
## des sorts sans quitter l'action des yeux. Suit la position affichée du Chasseur (caméra lisse ou rendu pixel).

const SIZE := 18.0
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
	for i: int in DraftSpells.SLOTS:
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
		draw_rect(rect, Color(0.04, 0.05, 0.09, 0.7))
		var filled: float = 1.0 if ready else spells.ready_ratio(i)
		var fill := Rect2(rect.position + Vector2(0, SIZE * (1.0 - filled)), Vector2(SIZE, SIZE * filled))
		draw_rect(fill, Color(data.color, 0.85 if ready else 0.35))
		draw_rect(rect, data.color.lightened(0.3) if ready else Color(0.5, 0.52, 0.6, 0.8), false, 1.5 if ready else 1.0)
		if not ready and spells.cooldowns[i] >= 1.0:
			var text: String = str(ceili(spells.cooldowns[i]))
			draw_string_outline(font, rect.position + Vector2(0, SIZE - 4), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 11, 3,
				Color(0, 0, 0, 0.9))
			draw_string(font, rect.position + Vector2(0, SIZE - 4), text, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 11, Color.WHITE)
		x += SIZE + GAP
