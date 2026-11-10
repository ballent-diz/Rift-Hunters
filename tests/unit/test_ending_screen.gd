extends TestCase
## Scène de fin (EndingScreen) : l'Œil se referme, un monde par chapitre, le Chasseur, le Cauchemar s'il vient de
## s'ouvrir, puis « Fin » avec Générique et Continuer ; Continuer rend la main aux résultats.


func test_cards_follow_the_journey() -> void:
	var ending := EndingScreen.new()
	ending.setup(true)
	var chapters: int = Campaign.chapters_of(Campaign.MAIN).size()
	check_eq(chapters, 5, "cinq chapitres")
	check_eq(ending.cards.size(), chapters + 3, "Œil, un monde par chapitre, Chasseur, Cauchemar")
	for card: Array in ending.cards:
		check(not String(card[0]).begins_with("ENDING_"), "texte traduit : %s" % card[0])
	ending.setup(false)
	check_eq(ending.cards.size(), chapters + 2, "sans Cauchemar s'il était déjà ouvert")
	ending.free()


func test_skip_then_continue_hands_back_to_results() -> void:
	var ending := EndingScreen.new()
	ending.setup(false)
	host.add_child(ending)
	var done: Array[bool] = [false]
	ending.finished.connect(func() -> void: done[0] = true)
	ending._process(EndingScreen.EYE_TIME)
	check_eq(ending.card_index, 0, "première carte après l'Œil")
	ending._finish_cards()
	check(ending._done and ending.card_index == ending.cards.size(), "cartes passées")
	check_eq(ending._buttons.get_child_count(), 2, "Générique et Continuer")
	ending._close()
	check(done[0], "les résultats reprennent la main")


func test_final_map_is_the_rift_eye() -> void:
	check_eq(Campaign.final_map().arena_id, &"rift_eye", "la scène de fin suit la victoire sur l'Œil de la Faille")
