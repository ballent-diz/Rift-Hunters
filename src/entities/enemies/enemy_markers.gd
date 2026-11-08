class_name EnemyMarkers
extends RefCounted
## Marqueurs au-dessus des Corrompus visibles : affixes des élites (une fois débloqués) et statuts (Fracture, Marques,
## Brûlure, Entrave…). Dessin seulement, appelé par la couche de surimpression d'EnemyManager.


static func draw_statuses(canvas: CanvasItem, list: Array[Enemy], view: Rect2, show_affixes: bool) -> void:
	if show_affixes:
		var font: Font = ThemeDB.fallback_font
		for enemy: Enemy in list:
			if enemy.alive and enemy.is_elite and view.has_point(enemy.position):
				var names: PackedStringArray = []
				for affix: EliteAffixData in enemy.affixes:
					names.append(TranslationServer.translate(affix.name_key))
				var top: Vector2 = enemy.position + Vector2(-60, -enemy.radius - 18.0)
				canvas.draw_string_outline(font, top, " · ".join(names), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 3, Color.BLACK)
				canvas.draw_string(font, top, " · ".join(names), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1.0, 0.8, 0.4))
	for enemy: Enemy in list:
		if not enemy.alive or enemy.statuses.is_empty() or not view.has_point(enemy.position):
			continue
		var top: Vector2 = enemy.position + Vector2(0, -enemy.radius - 7.0)
		var x: float = -8.0
		if enemy.statuses.has(&"fracture"):
			canvas.draw_line(top + Vector2(x - 3, -3), top + Vector2(x + 3, 3), Color(1.0, 0.55, 0.15), 2.0)
			canvas.draw_line(top + Vector2(x + 3, -3), top + Vector2(x - 1, 2), Color(1.0, 0.55, 0.15), 2.0)
			x += 8.0
		var marks: int = enemy.statuses.get_stacks(&"mark")
		for m: int in mini(marks, 8):
			canvas.draw_circle(top + Vector2(x + m * 5.0, 0), 2.2, Color(0.55, 0.95, 1.0))
		if marks > 0:
			x += mini(marks, 8) * 5.0 + 3.0
		if enemy.statuses.has(&"burn"):
			canvas.draw_circle(top + Vector2(x, 0), 3.0, Color(1.0, 0.4, 0.1))
			x += 7.0
		if enemy.statuses.has(&"slow"):
			canvas.draw_circle(top + Vector2(x, 0), 3.0, Color(0.6, 0.7, 1.0))
			x += 7.0
		if enemy.statuses.has(&"root"):
			canvas.draw_rect(Rect2(top + Vector2(x - 3, -3), Vector2(6, 6)), Color(0.45, 0.85, 0.35))
			x += 8.0
		if enemy.statuses.has(&"static"):
			canvas.draw_line(top + Vector2(x - 3, -3), top + Vector2(x + 3, 3), Color(1.0, 0.95, 0.4), 2.0)
			x += 8.0
		if enemy.statuses.has(&"warded"):
			canvas.draw_arc(top + Vector2(x, 0), 4.0, 0.0, TAU, 12, Color(0.55, 0.75, 1.0), 2.0)
