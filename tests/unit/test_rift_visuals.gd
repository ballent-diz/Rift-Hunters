extends TestCase


func test_touching_stair_rectangles_form_one_continuous_wall() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 30, 20), Rect2(25, 15, 30, 20), Rect2(50, 30, 30, 20)]
	var groups: Array[PackedInt32Array] = RiftWallVisual.connected_groups(rects)
	check_eq(groups.size(), 1, "chaîne diagonale réunie en un seul masque, sans contours intérieurs")
	check_eq(groups[0].size(), 3, "tous les rectangles conservés")


func test_separate_passages_keep_separate_surfaces() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 20, 80), Rect2(20, 0, 20, 80), Rect2(100, 0, 20, 80)]
	var groups: Array[PackedInt32Array] = RiftWallVisual.connected_groups(rects)
	check_eq(groups.size(), 2, "un contact de bord est uni ; un vrai passage vide reste séparé")
	var count: int = 0
	for group: PackedInt32Array in groups:
		count += group.size()
	check_eq(count, rects.size(), "aucune barrière perdue ni ajoutée")


func test_stair_curtain_is_one_smooth_path_without_rectangle_edges() -> void:
	var rects: Array[Rect2] = [Rect2(0, 0, 56, 56), Rect2(35, -20, 56, 56), Rect2(70, -40, 56, 56)]
	var path: PackedVector2Array = RiftWallVisual.curtain_path(rects)
	check(path.size() > rects.size(), "courbe subdivisée pour une ondulation réelle du maillage")
	var max_step: float = 0.0
	for i: int in path.size() - 1:
		max_step = maxf(max_step, path[i].distance_to(path[i + 1]))
	check(max_step < 15.0, "ruban continu, sans saut aux raccords des rectangles")
