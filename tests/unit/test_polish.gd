extends TestCase
## Phase 5 : retours de jeu, accessibilité, manette, succès, options.


func test_gamepad_actions_exist() -> void:
	for action: StringName in [&"dash", &"technique_1", &"technique_2", &"technique_3", &"focus_order", &"pause", &"move_left"]:
		var has_joy: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_joy = has_joy or event is InputEventJoypadButton or event is InputEventJoypadMotion
		check(has_joy, "%s : commande manette" % action)


func test_objective_unlocks_platform_achievement() -> void:
	var profile := ProfileData.new()
	PlatformServices.unlocked_this_session.clear()
	var result := {"victory": false, "time": 200.0, "difficulty_level": 0, "team": [], "evolutions": [], "relics": [],
		"synergies": [], "stats": {"counters": {"time_survived": 200.0}}}
	MetaProgression.apply_run_result(profile, result)
	check(PlatformServices.unlocked_this_session.has("first_steps"), "succès plateforme déclenché par l'objectif")
	check(bool(profile.data["flags"].get("tutorial_done", false)), "conseils de première partie marqués comme vus")


func test_tutorial_only_on_first_run() -> void:
	var original: ProfileData = Profile.profile
	Profile.profile = ProfileData.new()
	check(Profile.make_run_setup(&"mossback").show_tutorial, "conseils lors de la première partie")
	Profile.profile.data["flags"]["tutorial_done"] = true
	check(not Profile.make_run_setup(&"mossback").show_tutorial, "plus de conseils ensuite")
	Profile.profile = original


func test_settings_roundtrip() -> void:
	var path: String = "user://test_settings_%d.json" % Time.get_ticks_usec()
	var original_path: String = Settings.path
	var flags: Array = [Settings.reduce_flashes, Settings.show_fps, Settings.vsync, Settings.music_volume]
	Settings.path = path
	Settings.reduce_flashes = true
	Settings.show_fps = true
	Settings.vsync = false
	Settings.music_volume = 0.35
	Settings.save_settings()
	Settings.reduce_flashes = false
	Settings.show_fps = false
	Settings.vsync = true
	Settings.load_settings()
	check(Settings.reduce_flashes and Settings.show_fps and not Settings.vsync, "options relues")
	check_near(Settings.music_volume, 0.35, 0.001, "volume musique relu")
	Settings.path = original_path
	Settings.reduce_flashes = flags[0]
	Settings.show_fps = flags[1]
	Settings.vsync = flags[2]
	Settings.music_volume = flags[3]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_hitstop_pauses_simulation_only_for_humans() -> void:
	var run: RunController = RunFixture.create(host, &"mossback")
	run.hitstop(0.5)
	check_near(run._hitstop, 0.0, 0.001, "pas de gel pour le bot (simulations fiables)")
	run.ctx.setup.autopilot = false
	run.hitstop(0.5)
	check_near(run._hitstop, 0.5, 0.001, "gel actif pour un joueur")
	RunFixture.dispose(run)


func test_debris_are_capped() -> void:
	var run: RunController = RunFixture.create(host, &"mossback")
	for i: int in 300:
		run.ctx.fx.debris(Vector2.ZERO, Color.WHITE, 10)
	check(run.ctx.fx._particles.size() <= FxRenderer.MAX_PARTICLES, "particules plafonnées")
	RunFixture.dispose(run)


func test_audio_missing_files_are_silent() -> void:
	Audio.play_sfx(&"enemy_hit")
	Audio.play_sfx(&"inexistant")
	Audio.play_context("run")
	check(Audio.current_track_id == "" or ResourceLoader.exists(str(Audio.music_tracks[Audio.current_track_id]["path"])),
		"aucune piste fantôme quand les fichiers sont absents")


func test_music_folders_are_scanned() -> void:
	var dir: String = "res://assets/audio/music/run"
	var found: Dictionary = Audio.scan_music_folders()
	for id: String in found:
		var track: Dictionary = found[id]
		check(ResourceLoader.exists(track["path"]) or FileAccess.file_exists(track["path"]), "piste détectée : %s" % id)
	check(DirAccess.dir_exists_absolute(dir), "dossier des musiques de partie présent")


func test_music_playlist_and_fallbacks() -> void:
	var run_ids: Array[String] = Audio.tracks_for("run")
	check(run_ids.size() >= 2, "plusieurs musiques de partie (%d)" % run_ids.size())
	check(not Audio.tracks_for("boss").is_empty(), "musiques de boss présentes")
	check(not Audio.tracks_for("victory").is_empty(), "jingle de victoire présent")
	if Audio.tracks_for("menu").is_empty():
		check_eq(Audio.resolve_context("menu"), "run", "menu sans musique : repli sur les musiques de partie")
	check_eq(Audio.resolve_context("boss_phase2"), "boss_phase2", "la phase 2 utilise le dossier des boss")
	if run_ids.size() >= 2:
		for i: int in 20:
			check(Audio.next_track_id("run", run_ids[0]) != run_ids[0], "le morceau suivant change")


func test_measured_tempo_is_applied() -> void:
	var with_bpm: int = 0
	for id: String in Audio.tracks_for("run"):
		var bpm: float = float(Audio.music_tracks[id].get("bpm", 0.0))
		if bpm > 0.0:
			with_bpm += 1
			check(bpm >= 100.0 and bpm <= 220.0, "tempo plausible pour %s : %.1f" % [id, bpm])
	check(with_bpm > 0, "tempo mesuré appliqué aux musiques de partie")


func test_player_sprite_and_death_animation() -> void:
	var run: RunController = RunFixture.create(host, &"ashblade")
	var player: Player = run.ctx.player
	check(player.visual.has_sheet(), "le joueur utilise sa feuille de sprites (samouraï)")
	player.receive_damage(99999.0)
	check(not player.alive, "joueur vaincu")
	for i: int in 30:
		run._physics_process(1.0 / 60.0)
	check(not run.ctx.finished, "l'écran de défaite attend la fin de l'animation de chute")
	for i: int in 90:
		run._physics_process(1.0 / 60.0)
	check(run.ctx.finished, "écran de défaite après le délai (%.1f s)" % RunController.DEFEAT_DELAY)
	RunFixture.dispose(run)
