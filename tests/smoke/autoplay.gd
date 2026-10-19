extends Node
## Smoke test : une partie complète jouée par le bot, sans intervention.
## Vérifie que la boucle tient de bout en bout (vagues, niveaux, coffres, boss, fin de partie).
## Usage : godot --headless --fixed-fps 60 --path . res://tests/smoke/autoplay.tscn -- [--starter=mossback]
##         [--difficulty=normal] [--seed=1] [--god] [--max-minutes=12] [--boss-at=60]
##         [--night] (nuit d'essai, brique B2) [--boss=root_sentinel] (autre boss ou gardien) [--altar] (défense d'autel d'essai)
##         [--shallows] (gués d'essai) [--rivers] (crues et courant d'essai, carte 5)

var _run: RunController
var _frames: int = 0
var _max_frames: int = 60 * 60 * 12
var _report_every: int = 60 * 30


func _ready() -> void:
	var setup: RunSetup = Profile.make_run_setup(&"mossback")
	setup.autopilot = true
	setup.run_seed = 1
	# Simulation d'équilibrage : tout le contenu est disponible, indépendamment du profil local.
	setup.unlocked_monsters = GameDB.sorted_ids(GameDB.monsters)
	setup.unlocked_relics = GameDB.sorted_ids(GameDB.relics)
	setup.unlocked_upgrades = GameDB.sorted_ids(GameDB.upgrades)
	setup.meta_effects = []
	setup.modifier_ids = []
	setup.arena_id = &"fractured_plain"
	setup.difficulty_id = &"normal"
	var god: bool = false
	var boss_at: float = -1.0
	var features: Array[String] = []
	var boss_id: StringName = &""
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=")
		if parts[0] in TestArena.FEATURES:
			features.append(parts[0])
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
			"arena":
				setup.arena_id = StringName(parts[1])
			"boss":
				boss_id = StringName(parts[1])
			"meta":
				setup.meta_effects = _meta_profile(parts[1])
			"modifiers":
				for id: String in parts[1].split(",", false):
					setup.modifier_ids.append(StringName(id))
	setup.arena_override = TestArena.build(setup.arena_id, boss_id, features)
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


## Profils de progression typiques pour l'équilibrage : « veteran » ≈ 10 parties, « expert » ≈ 30 parties.
func _meta_profile(kind: String) -> Array[GameplayEffect]:
	var ranks := {
		"combat_training": 3, "combat_phantom_step": 1, "echoes_bonds": 3, "echoes_veteran": 1, "echoes_third_seal": 1,
		"explore_prospector": 2, "explore_magnet": 1, "research_rift_study": 1, "spec_deep_breach": 1,
	}
	if kind == "expert":
		ranks.merge({"combat_shattering_dash": 1, "combat_last_breath": 1, "echoes_sharpened": 2, "research_unstable": 1,
			"research_banish": 1, "research_fourth_option": 1, "spec_prismatic_resonance": 1, "explore_sealed_chests": 1,
			"research_rift_study": 2})
	var profile := ProfileData.new()
	var nodes: Dictionary = HunterTree.active_build(profile)["nodes"]
	for id: String in ranks:
		profile.set_tree_rank(StringName(id), int(ranks[id]))
		# Profil d'équilibrage : passifs appris et actifs, sans limite de points.
		nodes[id] = int(ranks[id])
	return HunterTree.effects_for(profile)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames % _report_every == 0 and _run.ctx:
		var ctx: RunContext = _run.ctx
		print("  t=%ds niv=%d ennemis=%d éliminations=%d PV=%d équipe=%s boss=%s" % [int(ctx.time), ctx.player.level,
			ctx.enemies.count(), int(ctx.stats.get_value(&"kills")), int(ctx.player.hp), ctx.allies.team_ids(),
			("%d%%" % int(100.0 * ctx.boss.hp / ctx.boss.max_hp)) if ctx.boss else "-"])
		if ctx.rifts:
			print("    failles %d/%d · finale %d · position %s" % [ctx.rifts.closed, ctx.rifts.total(),
				ctx.finale.state if ctx.finale else -1, ctx.player.global_position.round()])
		if ctx.zones:
			print("    zone %d phase %d vague %d · finale %d · position %s" % [ctx.zones.zone_index, ctx.zones.phase,
				ctx.zones.wave_index, ctx.finale.state if ctx.finale else -1, ctx.player.global_position.round()])
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
	print("Sorts lancés : ", int(_run.ctx.stats.get_value(&"spells_cast")))
	var boss_ratio: float = (_run.ctx.boss.hp / _run.ctx.boss.max_hp) if _run.ctx.boss else 1.0
	var boss_time: float = float(result["time"]) - _run.ctx.arena.boss_time if _run.ctx.boss else 0.0
	print("RESULT|%s|%s|%s|%d|%d|%d|%d|%d|%.2f|%d" % [_run.ctx.setup.starter_id, _run.ctx.arena.id, _run.ctx.setup.difficulty_id,
		1 if result["victory"] else 0, int(result["time"]), result["level"], result["kills"], int(boss_time), boss_ratio,
		int(counters.get("damage_taken", 0))])
	print("Récompenses : ", _run.rewards)
	get_tree().quit(0)
