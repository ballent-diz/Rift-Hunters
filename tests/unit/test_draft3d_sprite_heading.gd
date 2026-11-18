extends TestCase
## Veilleur des Seuils en dos et en face (docs/art/VEILLEUR_DOS_FACE.md) : choix du clip selon la direction à l'écran,
## hystérésis sur les diagonales, confirmation dans le temps, profil gardé pour les actions et repli sans rangées.

const STEP := 1.0 / 60.0

var _viewport: SubViewport


func before_each() -> void:
	_viewport = SubViewport.new()
	host.add_child(_viewport)
	var camera := Camera3D.new()
	_viewport.add_child(camera)
	camera.make_current()


func after_each() -> void:
	_viewport.queue_free()


func _view(visual_id: StringName) -> DraftSpriteView:
	var view := DraftSpriteView.new()
	_viewport.add_child(view)
	view.directional = true
	view.setup(visual_id)
	view.snap_to(Vector3.ZERO)
	return view


## Avance à 5 m/s dans la direction donnée à l'écran (x : droite, y : haut) pendant `seconds`.
func _walk(view: DraftSpriteView, screen: Vector2, seconds: float) -> void:
	var step := Vector3(screen.x, 0.0, -screen.y).normalized() * 5.0 * STEP
	var pos: Vector3 = view._current
	for i: int in int(seconds / STEP):
		pos += step
		view.push_position(pos, STEP)


func _stand(view: DraftSpriteView, seconds: float) -> void:
	for i: int in int(seconds / STEP):
		view.push_position(view._current, STEP)


func test_next_heading_thresholds_and_hysteresis() -> void:
	var side := DraftSpriteView.SIDE
	check_eq(DraftSpriteView.next_heading(side, Vector2(0, 1)), DraftSpriteView.BACK, "monte : dos")
	check_eq(DraftSpriteView.next_heading(side, Vector2(0, -1)), DraftSpriteView.FRONT, "descend : face")
	check_eq(DraftSpriteView.next_heading(side, Vector2(1, 0)), side, "droite : profil")
	var diagonal := Vector2(1, 1)
	check_eq(DraftSpriteView.next_heading(side, diagonal), side, "diagonale depuis le profil : profil gardé")
	check_eq(DraftSpriteView.next_heading(DraftSpriteView.BACK, diagonal), DraftSpriteView.BACK,
		"diagonale depuis le dos : dos gardé")
	check_eq(DraftSpriteView.next_heading(DraftSpriteView.FRONT, Vector2(1, -1)), DraftSpriteView.FRONT,
		"diagonale descendante depuis la face : face gardée")
	check_eq(DraftSpriteView.next_heading(DraftSpriteView.BACK, Vector2(1, 0.3)), side, "presque horizontal : profil")
	check_eq(DraftSpriteView.next_heading(DraftSpriteView.BACK, Vector2(0, -1)), DraftSpriteView.FRONT,
		"demi-tour : dos vers face")
	check_eq(DraftSpriteView.next_heading(DraftSpriteView.FRONT, Vector2(0.1, 0.1)), DraftSpriteView.FRONT,
		"micro-correction ignorée")


func test_warden_picks_back_front_and_idle() -> void:
	var view := _view(&"player.threshold_warden")
	for id: StringName in [&"idle_back", &"move_back", &"idle_front", &"move_front"]:
		check(view.has_clip(id), "clip %s livré" % id)
	_walk(view, Vector2(0, 1), 0.4)
	check_eq(view.animation, &"move_back", "marche vers le haut de l'écran")
	check(not view.sprite.flip_h, "dos jamais retourné")
	_stand(view, 0.3)
	check_eq(view.animation, &"idle_back", "arrêt après la montée : repos de dos")
	_walk(view, Vector2(0, -1), 0.4)
	check_eq(view.animation, &"move_front", "marche vers le bas")
	_stand(view, 0.3)
	check_eq(view.animation, &"idle_front", "arrêt après la descente : repos de face")
	_walk(view, Vector2(-1, 0), 0.4)
	check_eq(view.animation, &"move", "marche à gauche : profil")
	check(view.sprite.flip_h, "profil gauche retourné")
	_stand(view, 0.3)
	check_eq(view.animation, &"idle", "repos de profil")


func test_diagonal_wobble_does_not_flicker() -> void:
	var view := _view(&"player.threshold_warden")
	_walk(view, Vector2(0, 1), 0.4)
	var changes: int = 0
	var last: StringName = view.animation
	for i: int in 20:
		_walk(view, Vector2(1.0, 1.2 if i % 2 == 0 else 0.9), 0.05)
		if view.animation != last:
			changes += 1
			last = view.animation
	check_eq(changes, 0, "diagonale hésitante : aucune bascule")
	_walk(view, Vector2(0, -1), 0.05)
	check_eq(view.animation, &"move_back", "inversion trop brève : non confirmée")


func test_actions_stay_in_profile() -> void:
	var view := _view(&"player.threshold_warden")
	_walk(view, Vector2(-1, 0), 0.4)
	_walk(view, Vector2(0, 1), 0.4)
	check(not view.sprite.flip_h, "dos non retourné")
	view.play_action(&"attack", 0.2)
	check_eq(view.animation, &"attack", "attaque en profil")
	check(view.sprite.flip_h, "attaque retournée selon le dernier profil")
	_walk(view, Vector2(0, 1), 0.4)
	check_eq(view.animation, &"move_back", "retour au dos après l'attaque")
	view.play_action(&"dash", 0.15)
	check_eq(view.animation, &"dash", "Ruée en profil")


func test_fallback_without_directional_rows() -> void:
	var view := _view(&"boss.abyssarch")
	check(not view.has_clip(&"move_back"), "apparence sans rangée dos")
	_walk(view, Vector2(0, 1), 0.4)
	check_eq(view.heading, DraftSpriteView.BACK, "orientation suivie")
	check_eq(view.animation, &"move", "repli sur le profil")
	_stand(view, 0.3)
	check_eq(view.animation, &"idle", "repos de profil")
	var foe := DraftSpriteView.new()
	_viewport.add_child(foe)
	foe.setup(&"player.threshold_warden")
	foe.snap_to(Vector3.ZERO)
	_walk(foe, Vector2(0, 1), 0.4)
	check_eq(foe.animation, &"move", "sans `directional` : comportement inchangé")
