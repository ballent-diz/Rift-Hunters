extends Node
## Smoke test : une partie complète jouée par le bot, sans intervention.
## Vérifie que la boucle tient de bout en bout (vagues, niveaux, coffres, boss, fin de partie).
## Usage : godot --headless --fixed-fps 60 --path . res://tests/smoke/autoplay.tscn -- [--starter=mossback]
##         [--difficulty=tension_0] [--seed=1] [--god] [--max-minutes=12] [--boss-at=60]

var _run: RunController
var _frames: int = 0
var _max_frames: int = 60 * 60 * 12
var _report_every: int = 60 * 30


func _ready() -> void:
	var setup: RunSetup = Profile.make_run_setup(&"mossback")
	setup.autopilot = true
	setup.run_seed = 1
	var god: bool = false
	var boss_at: float = -1.0
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		match parts[0]:
			"starter":
				setup.starter_id = StringName(parts[1])
			"difficulty":
				setup.difficulty_id = StringName(parts[1])
			"seed":
				setup.run_seed = int(parts[1])
			"god":
				god = true
			"max-minutes":
				_max_frames = int(float(parts[1]) * 3600.0)
			"boss-at":
				boss_at = float(parts[1])
	_run = load("res://scenes/run.tscn").instantiate()
	_run.skip_profile = true
	_run.start(setup)
	add_child(_run)
	if boss_at >= 0.0:
		_run.ctx.arena = _run.ctx.arena.duplicate()
		_run.ctx.arena.boss_time = boss_at
	_run.ctx.player.god_mode = god
	_run.finished.connect(_on_finished)
	print("Smoke test : départ ", setup.starter_id, " / ", setup.difficulty_id, " / graine ", setup.run_seed)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames % _report_every == 0 and _run.ctx:
		var ctx: RunContext = _run.ctx
		print("  t=%ds niv=%d ennemis=%d éliminations=%d PV=%d équipe=%s boss=%s" % [int(ctx.time), ctx.player.level,
			ctx.enemies.count(), int(ctx.stats.get_value(&"kills")), int(ctx.player.hp), ctx.allies.team_ids(),
			("%d%%" % int(100.0 * ctx.boss.hp / ctx.boss.max_hp)) if ctx.boss else "-"])
	if _frames > _max_frames:
		printerr("ÉCHEC : la partie n'est pas terminée après le délai maximal")
		get_tree().quit(2)


func _on_finished(result: Dictionary) -> void:
	var counters: Dictionary = result["stats"]["counters"]
	var line: String = "Fin de partie : %s en %ds, niveau %d, %d éliminations, élites %d, coffres %d, évolutions %s, reliques %s"
	print((line + ", synergies %s") % [
		"VICTOIRE" if result["victory"] else "DÉFAITE", int(result["time"]), result["level"], result["kills"],
		int(counters.get("elites_killed", 0)), int(counters.get("chests_opened", 0)), result["evolutions"],
		result["relics"], result["synergies"]])
	print("Dégâts par source : ", result["stats"]["damage_by_source"])
	print("Récompenses : ", _run.rewards)
	get_tree().quit(0)
