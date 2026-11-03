extends TestCase
## Lot 2 des menus : astuces de la première expédition déclenchées par les actions du joueur, conseil après une
## défaite selon ce qui a le plus blessé le Chasseur.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func test_tips_follow_what_the_player_does() -> void:
	run = RunFixture.create(host, &"ashblade")
	var tips := TutorialTips.new()
	tips.setup(run.ctx)
	tips.step(0.1)
	check(tips.text != "" and tips.time > 0.0, "première astuce : se déplacer")
	check(not tips._done.has("TIP_DASH"), "pas d'astuce de Ruée avant le premier coup reçu")
	run.ctx.events.player_hurt.emit(5.0)
	check(tips._done.has("TIP_DASH"), "premier coup reçu : l'astuce de la Ruée attend son tour")
	run.ctx.events.elite_spawned.emit(null)
	run.ctx.events.elite_spawned.emit(null)
	check_eq(tips._queue.count("TIP_ELITE"), 1, "chaque astuce une seule fois")
	tips.time = 0.0
	tips._gap = 0.0
	tips.step(0.1)
	check_eq(tips.text, tr("TIP_DASH"), "les astuces passent une à une, dans l'ordre")


func test_defeat_advice_names_the_main_threat() -> void:
	var result := {"stats": {"damage_by_source": {"taken_bloat_toad": 120.0, "taken_mire_leech": 30.0, "player": 900.0}}}
	check_eq(DefeatAdvice.main_threat(result), "bloat_toad", "la menace principale")
	var lines: Array[String] = DefeatAdvice.advice(result)
	check_eq(lines[0], tr(GameDB.enemy(&"bloat_toad").name_key), "son nom")
	check_eq(lines[1], tr(GameDB.enemy(&"bloat_toad").desc_key), "et comment la contrer (sa fiche)")
	var boss := {"stats": {"damage_by_source": {"taken_spore_matriarch": 300.0}}}
	check_eq(DefeatAdvice.advice(boss)[1], MechanicJournal.body("BOSS_SPORE_VEIL_INTRO"), "un gardien : sa mécanique phare")
	var cold := {"stats": {"damage_by_source": {"taken_cold": 80.0}}}
	check_eq(DefeatAdvice.advice(cold)[1], tr("COLD_INTRO"), "un danger de carte : comment l'éviter")
	check(DefeatAdvice.advice({}).is_empty(), "rien à dire sans dégâts subis")


func test_spare_shards_are_pointed_out() -> void:
	var profile := ProfileData.new()
	check_eq(DefeatAdvice.build_hint(profile), "", "sans Éclats, pas de rappel")
	profile.add_currency("shards", 500)
	check(DefeatAdvice.build_hint(profile).contains("500"), "des Éclats qui attendent dans l'arbre")


func test_results_screen_shows_the_advice_on_defeat() -> void:
	var panel := ResultsPanel.new()
	host.add_child(panel)
	panel.setup()
	var result := {"victory": false, "milestones": true, "time": 200.0,
		"stats": {"damage_by_source": {"taken_bloat_toad": 120.0}, "counters": {}}}
	panel.show_result(result, {})
	check(panel.find_child("DefeatAdvice", true, false) != null, "défaite : le conseil s'affiche")
	result["victory"] = true
	panel.show_result(result, {})
	check(panel.find_child("DefeatAdvice", true, false) == null, "victoire : pas de conseil")
	panel.queue_free()
