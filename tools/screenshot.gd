extends Node
## Captures d'écran d'une partie jouée par le bot (nécessite un affichage, ex. xvfb-run).
## Usage : xvfb-run -a godot --path . --fixed-fps 60 res://tools/screenshot.tscn -- --out=/chemin --times=20,150
##         [--starter=mossback] [--boss-at=60] [--menu] [--seed=1] [--locale=fr]

var _run: RunController
var _times: Array[float] = [20.0]
var _out: String = "user://screenshots"
var _index: int = 0


func _ready() -> void:
	var setup: RunSetup = Profile.make_run_setup(&"mossback")
	setup.autopilot = true
	setup.run_seed = 1
	var boss_at: float = -1.0
	var menu: String = ""
	var tab: int = 0
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		match parts[0]:
			"out":
				_out = parts[1]
			"times":
				_times.clear()
				for t: String in parts[1].split(","):
					_times.append(float(t))
			"starter":
				setup.starter_id = StringName(parts[1])
			"seed":
				setup.run_seed = int(parts[1])
			"boss-at":
				boss_at = float(parts[1])
			"menu":
				menu = parts[1] if parts.size() > 1 else "main"
			"locale":
				Settings.set_locale(parts[1])
			"tab":
				tab = int(parts[1])
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
				"levelup": _run.level_up_panel.open()
				"chest": _run.chest_panel.open()
				"results":
					_run.results_panel.show_result({"victory": true, "time": 900, "level": 30, "kills": 1200},
						{"shards": 240, "essence": 80})
					get_tree().paused = true
		else:
			var scene: PackedScene = load(Router.REFUGE if menu == "refuge" else Router.MAIN_MENU)
			var screen: Control = scene.instantiate()
			add_child(screen)
			if screen is Refuge:
				screen.tabs.current_tab = clampi(tab, 0, screen.tabs.get_tab_count() - 1)
			elif menu == "credits":
				screen._show_credits()
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		_save("menu_" + menu)
		get_tree().quit()
		return
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	add_child(_run)
	if boss_at >= 0.0:
		_run.ctx.arena = _run.ctx.arena.duplicate()
		_run.ctx.arena.boss_time = boss_at
	_run.ctx.player.god_mode = true


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
