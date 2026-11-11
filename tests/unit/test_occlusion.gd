extends TestCase
## Masquage des personnages par le décor peint (docs/maps/MASQUAGE_PAR_LE_DECOR.md) : données de l'éditeur, cuisson
## de la profondeur, règle de masquage, branchement sur les visuels.

const DOC := preload("res://tools/art/occlusion_document.gd")


## Carte fictive de 1000 × 500 pixels pour 1000 × 500 unités : cellules de 2 pixels.
func _doc() -> OcclusionDocument:
	return DOC.create(&"environment.test", "user://occlusion_test", Vector2i(1000, 500), Vector2(1000, 500))


func _square(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


func test_grid_follows_map_resolution() -> void:
	var doc: OcclusionDocument = _doc()
	check_eq(doc.cell, 2, "2 unités visées = 2 pixels par cellule")
	check_eq(doc.grid, Vector2i(500, 250), "grille")
	var rect := Rect2(-400, -200, 800, 400)
	check(doc.cell_to_world(Vector2(250, 125), rect).is_equal_approx(Vector2.ZERO), "centre de la carte = centre de l'arène")
	check(doc.world_to_cell(Vector2(400, 200), rect).is_equal_approx(Vector2(500, 250)), "coin bas-droit")


func test_polygon_keeps_holes_and_brush_erases() -> void:
	var doc: OcclusionDocument = _doc()
	var e: OcclusionDocument.Element = doc.add_element("ruin", Vector2(30, 60))
	doc.fill_polygon(e, _square(10, 10, 50, 50), true)
	doc.fill_polygon(e, _square(20, 20, 40, 40), false)
	check(e.covers(Vector2i(15, 15)), "mur plein")
	check(not e.covers(Vector2i(30, 30)), "ouverture préservée")
	check(not e.covers(Vector2i(60, 30)), "hors du polygone")
	doc.paint_circle(e, Vector2(15, 45), 3.0, false)
	check(not e.covers(Vector2i(15, 45)), "gomme")
	doc.paint_circle(e, Vector2(80, 80), 3.0, true)
	check(e.covers(Vector2i(80, 80)), "pinceau hors du cadre : le masque s'agrandit")
	check(e.covers(Vector2i(12, 12)), "l'agrandissement garde le masque")
	check_eq(e.id, "ruin_01", "identifiant stable par catégorie")
	check_eq(doc.add_element("ruin", Vector2.ZERO).id, "ruin_02", "identifiant suivant")


func test_front_element_wins_on_overlap() -> void:
	var doc: OcclusionDocument = _doc()
	var back: OcclusionDocument.Element = doc.add_element("tree", Vector2(20, 60))
	doc.fill_polygon(back, _square(0, 0, 40, 60), true)
	var front: OcclusionDocument.Element = doc.add_element("pillar", Vector2(30, 90))
	doc.fill_polygon(front, _square(30, 20, 50, 90), true)
	doc.bake()
	var k: float = float(doc.cell) / doc.map_size.y
	check_eq(doc.code_at(Vector2i(10, 10)), OcclusionMap.encode(60 * k), "arbre seul")
	check_eq(doc.code_at(Vector2i(35, 30)), OcclusionMap.encode(90 * k), "chevauchement : le plus proche l'emporte")
	check_eq(doc.code_at(Vector2i(100, 100)), 0, "sol nu")


func test_sloped_foot_line() -> void:
	var doc: OcclusionDocument = _doc()
	var e: OcclusionDocument.Element = doc.add_element("wall", Vector2(10, 40))
	e.depth_b = Vector2(30, 60)
	check_near(e.depth_at(20.0), 50.0, 0.001, "milieu")
	check_near(e.depth_at(0.0), 40.0, 0.001, "constante à gauche")
	check_near(e.depth_at(99.0), 60.0, 0.001, "constante à droite")


## Même règle que le shader, carte réduite par decor_scale (0,8) : le rectangle de l'arène porte l'échelle.
func test_hidden_only_behind_the_foot_line() -> void:
	var doc: OcclusionDocument = _doc()
	var e: OcclusionDocument.Element = doc.add_element("rock", Vector2(0, 100))
	doc.fill_polygon(e, _square(100, 50, 200, 100), true)
	doc.bake()
	var region: Rect2i = doc.used_rect()
	var image: Image = doc.depth_image(region)
	var rect := Rect2(Vector2(-1000, -500) * 0.5 * 0.8, Vector2(1000, 500) * 0.8)
	var map: OcclusionMap = OcclusionMap.from_data(doc.runtime_data(region), image, rect)
	check(map != null, "données lues")
	var line_y: float = doc.cell_to_world(Vector2(0, 100), rect).y
	var on_rock: Vector2 = doc.cell_to_world(Vector2(150, 70), rect)
	check(map.hides(image, Vector2(on_rock.x, line_y - 5.0), on_rock), "pied derrière : caché")
	check(not map.hides(image, Vector2(on_rock.x, line_y + 5.0), on_rock), "pied devant : normal")
	var beside: Vector2 = doc.cell_to_world(Vector2(250, 70), rect)
	check(not map.hides(image, Vector2(beside.x, line_y - 5.0), beside), "hors silhouette : normal")
	check(map.depth_rect.size.x > 0.0 and map.texture != null, "texture prête")


func test_save_and_reopen() -> void:
	var doc: OcclusionDocument = _doc()
	var e: OcclusionDocument.Element = doc.add_element("statue", Vector2(40, 80))
	e.depth_b = Vector2(60, 90)
	doc.fill_polygon(e, _square(30, 20, 70, 80), true)
	doc.fill_polygon(e, _square(45, 40, 55, 60), false)
	check_eq(doc.save(false), OK, "enregistrement")
	var again: OcclusionDocument = DOC.open("user://occlusion_test", Vector2i(1000, 500))
	check(again != null and again.elements.size() == 1, "repris")
	if again != null and again.elements.size() == 1:
		var r: OcclusionDocument.Element = again.elements[0]
		check_eq(r.id, "statue_01", "identifiant")
		check(r.covers(Vector2i(35, 30)) and not r.covers(Vector2i(50, 50)), "masque et trou repris")
		check(r.depth_b.is_equal_approx(Vector2(60, 90)), "ligne de pied reprise")
		check_eq(again.code_at(Vector2i(35, 30)), doc.code_at(Vector2i(35, 30)), "même profondeur")
	check(DOC.open("user://occlusion_test", Vector2i(999, 500)) == null, "carte changée : données ignorées")


func test_demo_sector_hides_behind_the_column() -> void:
	var arena: ArenaData = GameDB.arena(&"firefly_woods")
	var ground := ArenaGround.new()
	ground.setup(arena, 1)
	var map: OcclusionMap = ground.occlusion_map()
	check(map != null, "le Bois des Lucioles a des données de masquage")
	if map != null:
		var path: String = str(Assets.entry(arena.environment_id).get("occlusion", ""))
		var image: Image = OcclusionMap.load_depth_image(path.get_base_dir().path_join("depth.png"))
		var env: EnvironmentSet = ground.environment
		var map_size := Vector2(env.map_texture.get_width() * env.map_tiles.size(), env.map_texture.get_height())
		var rect: Rect2 = ground.arena_rect()
		var to_world := func(px: Vector2) -> Vector2: return rect.position + px / map_size * rect.size
		var column_top: Vector2 = to_world.call(Vector2(1380, 4100))
		check(map.hides(image, to_world.call(Vector2(1380, 4130)), column_top), "derrière la colonne : caché")
		check(not map.hides(image, to_world.call(Vector2(1380, 4440)), column_top), "devant la colonne : normal")
		var fence_gap: Vector2 = to_world.call(Vector2(1600, 4250))
		check(not map.hides(image, to_world.call(Vector2(1600, 4260)), fence_gap), "ouverture de la clôture")
	ground.free()


## Hautes Terres d'Orage (première carte détourée) : le Chasseur au nord d'un menhir est caché, au sud il est devant.
func test_storm_highlands_menhir() -> void:
	var ground := ArenaGround.new()
	ground.setup(GameDB.arena(&"storm_highlands"), 1)
	var map: OcclusionMap = ground.occlusion_map()
	check(map != null, "les Hautes Terres ont des données de masquage")
	if map != null:
		var path: String = str(Assets.entry(&"environment.storm_highlands").get("occlusion", ""))
		var image: Image = OcclusionMap.load_depth_image(path.get_base_dir().path_join("depth.png"))
		var rect: Rect2 = ground.arena_rect()
		var to_world := func(px: Vector2) -> Vector2: return rect.position + px / Vector2(11286, 11286) * rect.size
		var stone: Vector2 = to_world.call(Vector2(5130, 1100))
		check(map.hides(image, to_world.call(Vector2(5130, 1150)), stone), "derrière le menhir : caché")
		check(not map.hides(image, to_world.call(Vector2(5130, 1800)), stone), "devant le menhir : normal")
		check(not map.hides(image, to_world.call(Vector2(5700, 1150)), to_world.call(Vector2(5700, 1100))),
			"herbe dégagée : normal")
	ground.free()


## Entrée du Glacier (carte 16, décor réduit à 0,9) : derrière un rocher-abri le Chasseur est caché par son sommet.
func test_glacier_entry_cover_rock() -> void:
	var ground := ArenaGround.new()
	ground.setup(GameDB.arena(&"glacier_entry"), 1)
	var map: OcclusionMap = ground.occlusion_map()
	check(map != null, "l'Entrée du Glacier a des données de masquage")
	if map != null:
		var path: String = str(Assets.entry(&"environment.glacier_entry").get("occlusion", ""))
		var image: Image = OcclusionMap.load_depth_image(path.get_base_dir().path_join("depth.png"))
		var rect: Rect2 = ground.arena_rect()
		var to_world := func(px: Vector2) -> Vector2: return rect.position + px / Vector2(11286, 7524) * rect.size
		var cap: Vector2 = to_world.call(Vector2(5668, 1520))
		check(map.hides(image, to_world.call(Vector2(5668, 1590)), cap), "derrière le rocher : caché par le sommet")
		check(not map.hides(image, to_world.call(Vector2(5668, 2050)), cap), "devant le rocher : normal")
		check(not map.hides(image, to_world.call(Vector2(6400, 1590)), to_world.call(Vector2(6400, 1520))),
			"neige dégagée : normal")
	ground.free()


func test_maps_without_data_are_untouched() -> void:
	var ground := ArenaGround.new()
	ground.setup(GameDB.arena(&"brazier_pass"), 1)
	check(ground.occlusion_map() == null, "pas de données : pas de masquage")
	ground.free()


func test_only_body_and_shadow_get_the_shared_material() -> void:
	var doc: OcclusionDocument = _doc()
	var region := Rect2i(0, 0, 4, 4)
	var map: OcclusionMap = OcclusionMap.from_data(doc.runtime_data(region), doc.depth_image(region), Rect2(0, 0, 100, 100))
	var visual := EntityVisual.new()
	host.add_child(visual)
	visual.occlusion = map
	visual.setup(GameDB.balance.player_visual)
	var body: CanvasItem = null
	for child: Node in visual.get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			body = child
	check(body != null and body.material == map.material(&"body"), "corps : matériau partagé")
	var other := EntityVisual.new()
	host.add_child(other)
	other.occlusion = map
	other.setup(GameDB.enemy(&"ash_hound").visual)
	var other_body: CanvasItem = null
	for child: Node in other.get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			other_body = child
	check(other_body != null and other_body.material == body.material, "même matériau pour une autre entité")
	if body is AnimatedSprite2D:
		visual.set_lift(30.0)
		check((body as Node2D).position == Vector2.ZERO, "saut : l'origine du sprite reste au pied")
		check((body as AnimatedSprite2D).offset.y < -Assets.anchor(GameDB.balance.player_visual.visual_id).y,
			"saut : le sprite monte")
	visual.set_occlusion(null)
	check(body != null and body.material == null, "masquage retiré")
	visual.free()
	other.free()
