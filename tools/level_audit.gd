extends Node3D
## Contrôle de composition des cartes 3D (DraftLevelAudit, règles : docs/maps/CARTES_3D.md).
## godot --headless --path . res://tools/level_audit.tscn -- [--chapters=1,2,3,4,5,6.0,6.1,6] [--out=<dossier>]
##   (6.0 et 6.1 : étages de la tour du chapitre 6, 6 : son sommet)
##   [--bot-seconds=90 --seed=1]   (parcours du bot tracé sur la carte : la partie complète est lancée)
## Écrit `<dossier>/navigation_<chapitre>.png` (carte de navigation) et une ligne par incohérence ; code de sortie 1
## si une carte en a.


func _ready() -> void:
	var options: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var out: String = str(options.get("out", ""))
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	var bot_seconds: float = float(options.get("bot-seconds", "0"))
	var failed: bool = false
	# 6.0, 6.1 : étages de la tour du chapitre 6 ; 6 seul : son sommet.
	for value: String in str(options.get("chapters", "1,2,3,4,5,6.0,6.1,6")).split(",", false):
		var chapter: int = int(value.get_slice(".", 0))
		var tower_floor: int = int(value.get_slice(".", 1)) if value.contains(".") else -1
		var trail := PackedVector3Array()
		var run: DraftRun = null
		var level: DraftLevel
		if bot_seconds > 0.0:
			DraftRun.chosen_chapter = chapter
			run = (load("res://draft3d/main.tscn") as PackedScene).instantiate()
			add_child(run)
			while run.state != DraftRun.State.PLAYING:
				await get_tree().physics_frame
			level = run.level
			var until: float = run.time + bot_seconds
			while run.time < until and run.state not in [DraftRun.State.WON, DraftRun.State.LOST]:
				trail.append(run.hunter.global_position)
				await get_tree().create_timer(0.25, true, false, true).timeout
		else:
			level = DraftLevel.create(chapter) if tower_floor < 0 else DraftTower.floor_level(tower_floor)
			add_child(level)
			level.build()
			await level.bake()
		var audit: DraftLevelAudit = DraftLevelAudit.check(level)
		print("AUDIT|chapitre %s|%s|%d escaliers|%d incohérence(s)" % [
			value, level.get_script().get_global_name(), audit.stairs.size(), audit.issues.size()])
		for line: String in audit.lines():
			print("AUDIT|chapitre %s|%s" % [value, line])
		failed = failed or not audit.issues.is_empty()
		if out != "":
			audit.draw_map(trail).save_png(out.path_join("navigation_%s.png" % value.replace(".", "_")))
		if run != null:
			run.queue_free()
		else:
			level.queue_free()
		for frame: int in 4:
			await get_tree().physics_frame
	get_tree().quit(1 if failed else 0)
