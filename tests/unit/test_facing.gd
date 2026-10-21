extends TestCase
## Anti-scintillement des sprites (EntityVisual) : pas de retournement gauche-droite à chaque image.


func _visual() -> EntityVisual:
	var visual := EntityVisual.new()
	host.add_child(visual)
	visual.setup(GameDB.monster(&"ashblade").visual)
	return visual


func test_small_horizontal_speed_keeps_the_side() -> void:
	var visual: EntityVisual = _visual()
	visual.face_velocity(-40.0)
	check(visual._facing_left, "va nettement à gauche : regarde à gauche")
	for i: int in 30:
		visual.tick(1.0 / 60.0, true)
		visual.face_velocity(3.0 if i % 2 == 0 else -3.0)
	check(visual._facing_left, "déplacement presque vertical : garde son côté")
	visual.queue_free()


func test_flips_are_held_a_moment() -> void:
	var visual: EntityVisual = _visual()
	visual.face_velocity(-40.0)
	var flips: int = 0
	var last: bool = visual._facing_left
	for i: int in 30:
		visual.tick(1.0 / 60.0, true)
		visual.face_velocity(40.0 if i % 2 == 0 else -40.0)
		if visual._facing_left != last:
			flips += 1
			last = visual._facing_left
	check(flips <= 3, "zigzag rapide : au plus un retournement tous les ~0,2 s (obtenu %d en 0,5 s)" % flips)
	visual.set_facing_left(not visual._facing_left, true)
	check_eq(visual._facing_left, not last, "retournement forcé (attaque, Chasseur) immédiat")
	visual.queue_free()
