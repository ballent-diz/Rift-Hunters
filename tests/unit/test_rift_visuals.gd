extends TestCase


func test_touching_stair_rectangles_form_one_continuous_wall() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 30, 20), Rect2(25, 15, 30, 20), Rect2(50, 30, 30, 20)]
	var groups: Array[PackedInt32Array] = RiftWallVisual.connected_groups(rects)
	check_eq(groups.size(), 1, "chaîne diagonale réunie en une seule barrière")
	check_eq(groups[0].size(), 3, "tous les rectangles conservés")


func test_separate_passages_keep_separate_surfaces() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 20, 80), Rect2(20, 0, 20, 80), Rect2(100, 0, 20, 80)]
	var groups: Array[PackedInt32Array] = RiftWallVisual.connected_groups(rects)
	check_eq(groups.size(), 2, "un contact de bord est uni ; un vrai passage vide reste séparé")
	var count: int = 0
	for group: PackedInt32Array in groups:
		count += group.size()
	check_eq(count, rects.size(), "aucune barrière perdue ni ajoutée")


func _kinds(placed: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for piece: Dictionary in placed["pieces"]:
		counts[piece["kind"]] = int(counts.get(piece["kind"], 0)) + 1
	return counts


func _length(placed: Dictionary) -> float:
	var total: float = 0.0
	for piece: Dictionary in placed["pieces"]:
		total += float(piece["length"]) * (2.0 if piece["kind"] == &"corner" else 1.0)
	return total


func test_horizontal_strip_is_tiled_with_face_modules_and_cut_last() -> void:
	var rects: Array[Rect2] = [Rect2(100, 300, 300, 60)]
	var path: PackedVector2Array = RiftWallVisual.ground_path(rects)
	check_eq(path, PackedVector2Array([Vector2(100, 330), Vector2(400, 330)]), "ligne médiane, de gauche à droite")
	var placed: Dictionary = RiftWallVisual.layout(path)
	check_eq(_kinds(placed), {&"face": 3}, "trois modules de face")
	check(is_equal_approx(_length(placed), 300.0), "longueur exacte, dernier module coupé")
	var lengths: Array[float] = []
	for piece: Dictionary in placed["pieces"]:
		lengths.append(float(piece["length"]))
	check_eq(lengths, [128.0, 128.0, 44.0] as Array[float], "modules de 128 unités, raccords sur la grille")
	check_eq((placed["seals"] as PackedVector2Array).size(), 2, "une borne à chaque extrémité")


func test_vertical_strip_uses_bias_from_top_to_bottom() -> void:
	var rects: Array[Rect2] = [Rect2(-870, 360, 60, 180)]
	var placed: Dictionary = RiftWallVisual.layout(RiftWallVisual.ground_path(rects))
	check_eq(_kinds(placed), {&"bias": 2}, "barrière verticale à l'écran : modules de biais")
	check_eq((placed["pieces"][0] as Dictionary)["origin"], Vector2(-840, 360), "pose depuis le haut")
	check(is_equal_approx(_length(placed), 180.0), "longueur conservée")


func test_east_south_turn_uses_corner_module_and_one_seal_on_the_fold() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 300, 40), Rect2(260, 0, 40, 330)]
	var path: PackedVector2Array = RiftWallVisual.ground_path(rects)
	for i: int in path.size() - 1:
		check(path[i].x == path[i + 1].x or path[i].y == path[i + 1].y, "segments horizontaux ou verticaux")
	var placed: Dictionary = RiftWallVisual.layout(path)
	check_eq(int(_kinds(placed).get(&"corner", 0)), 1, "pli est→sud : module d'angle dédié")
	check_eq((placed["seals"] as PackedVector2Array).size(), 3, "bornes aux deux extrémités et sur le pli")
	check(is_equal_approx(_length(placed), path[0].distance_to(path[1]) + path[1].distance_to(path[2])),
		"l'angle remplace exactement les deux demi-longueurs voisines")


func test_diagonal_spell_wall_becomes_stairs_without_seals_on_each_step() -> void:
	var rects: Array[Rect2] = []
	for i: int in 6:
		rects.append(Rect2(Vector2(i * 18, i * 18), Vector2(26, 26)))
	check_eq(RiftWallVisual.connected_groups(rects).size(), 1, "une seule barrière")
	var path: PackedVector2Array = RiftWallVisual.ground_path(rects)
	var placed: Dictionary = RiftWallVisual.layout(path)
	check_eq((placed["seals"] as PackedVector2Array).size(), 2, "bornes aux extrémités seulement")
	check(int(_kinds(placed).get(&"face", 0)) > 0 and int(_kinds(placed).get(&"bias", 0)) > 0, "marches face et biais")


func test_barrier_set_follows_campaign_chapter() -> void:
	check_eq(RiftWallVisual.chapter_for(&"glacier_entry"), 4, "Entrée du Glacier : chapitre 4")
	check_eq(RiftWallVisual.chapter_for(&"no_such_arena"), 1, "hors campagne : chapitre 1")
	for chapter: int in range(1, 6):
		var barrier: Dictionary = RiftWallVisual.barrier_set(chapter)
		check_eq(int(barrier.get("chapter", 0)), chapter, "jeu peint complet pour le chapitre %d" % chapter)
		check(barrier.has(&"corner") and barrier.has(&"seal_b"), "modules d'angle et bornes chargés")


func test_painted_wall_redraws_only_when_pose_changes() -> void:
	var barrier: Dictionary = RiftWallVisual.barrier_set(1)
	var wall := RiftWallVisual.new()
	var rects: Array[Rect2] = [Rect2(0, 0, 400, 50)]
	wall.setup(rects, [0] as Array[int], barrier, RiftWallVisual.Phase.CLOSED, 0.0)
	check_eq(wall.piece_count(), 4, "quatre modules pour 400 unités")
	check(RiftWallVisual.clip_duration(barrier, &"appear") > 0.8, "durée d'apparition lue du clip (10 im à 12 im/s)")
	check(is_equal_approx(RiftWallVisual.clip_duration(barrier, &"dissolve"), 1.0), "dissolution : 12 im à 12 im/s")
	wall.free()
