extends Node
## Captures d'écran d'une partie jouée par le bot (nécessite un affichage, ex. xvfb-run).
## Usage : xvfb-run -a godot --path . --fixed-fps 60 res://tools/screenshot.tscn -- --out=/chemin --times=20,150
##         [--starter=mossback] [--boss-at=60] [--menu] [--seed=1] [--locale=fr]
##         [--night] [--boss=root_sentinel] [--altar] [--shallows] [--rivers] [--map] (grande carte ouverte)
##         [--at=-2,-120] (Chasseur immobile placé à ce point, pour cadrer un endroit précis)

var _run: RunController
var _times: Array[float] = [20.0]
var _out: String = "user://screenshots"
var _index: int = 0


func _ready() -> void:
	var setup: RunSetup = Profile.make_run_setup(&"mossback")
	setup.autopilot = true
	setup.run_seed = 1
	var boss_at: float = -1.0
	var features: Array[String] = []
	var boss_id: StringName = &""
	var menu: String = ""
	var tab: int = 0
	var item_ids: PackedStringArray = []
	var selection: String = ""
	var at := Vector2.INF
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		if parts[0] in TestArena.FEATURES:
			features.append(parts[0])
		match parts[0]:
			"out":
				_out = parts[1]
			"times":
				_times.clear()
				for t: String in parts[1].split(","):
					_times.append(float(t))
			"arena":
				setup.arena_id = StringName(parts[1])
			"starter":
				setup.starter_id = StringName(parts[1])
			"seed":
				setup.run_seed = int(parts[1])
			"boss-at":
				boss_at = float(parts[1])
			"boss":
				boss_id = StringName(parts[1])
			"menu":
				menu = parts[1] if parts.size() > 1 else "main"
			"locale":
				Settings.set_locale(parts[1])
			"tab":
				tab = int(parts[1])
			"item-ids":
				item_ids = parts[1].split(",", false)
			"selection":
				selection = parts[1]
			"at":
				var xy: PackedStringArray = parts[1].split(",")
				at = Vector2(float(xy[0]), float(xy[1]))
				setup.autopilot = false
	DirAccess.make_dir_recursive_absolute(_out)
	if menu != "":
		if menu in ["pause", "levelup", "chest", "results"]:
			setup.autopilot = false
			_run = load(Router.RUN).instantiate()
			_run.skip_profile = true
			_run.start(setup)
			add_child(_run)
			await get_tree().create_timer(0.2).timeout
			_run.level_up_panel.visible = false
			_run.chest_panel.visible = false
			match menu:
				"pause": _run.pause_panel.open()
				"levelup":
					_run.level_up_panel.open()
					if not item_ids.is_empty():
						await get_tree().process_frame
						_run.level_up_panel._offers.clear()
						for id: String in item_ids:
							var upgrade: UpgradeData = GameDB.upgrade(StringName(id))
							var offer := UpgradeOffer.new()
							offer.upgrade = upgrade
							offer.key = "up:" + id
							offer.kind = UpgradeOffer.Kind.MUTATION if upgrade.kind == UpgradeData.Kind.MUTATION \
								else UpgradeOffer.Kind.STAT
							_run.level_up_panel._offers.append(offer)
						_run.level_up_panel._refresh()
				"chest":
					_run.chest_panel.open()
					if not item_ids.is_empty():
						await get_tree().process_frame
						_run.chest_panel._relics.clear()
						for id: String in item_ids:
							_run.chest_panel._relics.append(GameDB.relic(StringName(id)))
						_run.chest_panel._refresh_cards()
				"results":
					_run.results_panel.show_result({"victory": true, "time": 900, "level": 30, "kills": 1200},
						{"shards": 240, "essence": 80})
					get_tree().paused = true
		else:
			var scene: PackedScene = load(Router.REFUGE if menu == "refuge" else Router.MAIN_MENU)
			var screen: Control = scene.instantiate()
			add_child(screen)
			if screen is Refuge:
				if selection.begins_with("relic:"):
					Profile.profile.discover("relics", selection.get_slice(":", 1))
				screen.tabs.current_tab = clampi(tab, 0, screen.tabs.get_tab_count() - 1)
				if selection != "" and tab == 3:
					(screen.tabs.get_child(3) as RefugeTab)._show(selection)
				if selection.begins_with("echo:") and tab == 2:
					# Onglet Échos : l'Écho et le nœud affichés (ex. echo:sunclaw:sunclaw_spell_alt).
					var echoes: RefugeTab = screen.tabs.get_child(2)
					echoes.set("_monster", StringName(selection.get_slice(":", 1)))
					echoes.set("_selected", StringName(selection.get_slice(":", 2)))
					echoes.refresh()
			elif menu == "credits":
				screen._show_credits()
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		_save("menu_" + menu)
		get_tree().quit()
		return
	setup.arena_override = TestArena.build(setup.arena_id, boss_id, features)
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	add_child(_run)
	if boss_at >= 0.0:
		_run.ctx.arena = _run.ctx.arena.duplicate()
		_run.ctx.arena.boss_time = boss_at
	_run.ctx.player.god_mode = true
	if at != Vector2.INF:
		_run.ctx.player.global_position = at
	if OS.get_cmdline_user_args().has("--map"):
		_run.hud.minimap.toggle()


func _physics_process(_delta: float) -> void:
	if _run == null or _index >= _times.size():
		return
	if _run.ctx.time >= _times[_index]:
		_index += 1
		_capture.call_deferred(_index)


func _capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	_save("run_%02d_%ds" % [index, int(_run.ctx.time)])
	if index >= _times.size():
		get_tree().quit()


func _save(file_name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(file_name + ".png")
	image.save_png(path)
	print("Capture : ", path, " ", image.get_size())
