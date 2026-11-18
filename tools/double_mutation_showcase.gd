extends Node
## Captures comparatives des doubles mutations des sorts historiques (docs/design/DOUBLES_MUTATIONS_VFX.md) : pour
## chaque sort, vraie partie, sort équipé avec ses mutations dans l'ordre demandé, vrai lancer, image au pic de l'effet.
## Ordres : `a` (mutation peinte seule), `b` (autre mutation seule), `ab`, `ba` (les deux, dans cet ordre).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 \
##     res://tools/double_mutation_showcase.tscn -- --bot --passive --out=docs/previews/doubles_mutations \
##     [--only=rupture] [--orders=a,ba]

## Sort → [carte de la mutation peinte en priorité, carte de l'autre mutation].
const PAIRS := {
	&"rupture": ["rupture_blaze", "rupture_reaction"],
	&"rift_leap": ["leap_impact", "leap_return"],
	&"parry": ["parry_mirror", "parry_long_guard"],
	&"singularity": ["singularity_collapse", "singularity_horizon"],
	&"rift_wall": ["wall_burning", "wall_chains"],
	&"aegis": ["aegis_second_wind", "aegis_riposte"],
	&"refracting_crystal": ["crystal_focus", "crystal_double"],
}
## Images de physique entre le lancer et la capture (pic lisible de l'effet).
const DELAY := {&"rupture": 30, &"rift_leap": 30, &"parry": 6, &"singularity": 40, &"rift_wall": 40, &"aegis": 12,
	&"refracting_crystal": 20}

var run: DraftRun
var _out: String = "user://doubles_mutations"
var _report: Array[String] = []


func _ready() -> void:
	var only: String = ""
	var orders: PackedStringArray = ["a", "b", "ab", "ba"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--orders="):
			orders = arg.trim_prefix("--orders=").split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	for id: StringName in PAIRS:
		if only == "" or only == String(id):
			for order: String in orders:
				await _stage(id, order)
	print("\n".join(_report))
	get_tree().quit()


func _effect(card: String) -> DraftSpellEffect:
	return (load("res://draft3d/spells/%s.tres" % card) as UpgradeData).effects[0] as DraftSpellEffect


func _stage(id: StringName, order: String) -> void:
	run = (load("res://draft3d/main.tscn") as PackedScene).instantiate()
	add_child(run)
	for frame: int in 900:
		if run.state == DraftRun.State.PLAYING:
			break
		await get_tree().physics_frame
	run._bot = false
	run.spells.auto_cast = false
	run.hunter.automating = false
	run.boss_time = INF
	run.tuning = run.tuning.duplicate()
	run.tuning.waves.assign([{"at": 0.0, "rate": 0.0, "cap": 0, "mix": {"skitterling": 1.0}}])
	run.tuning.swarm_every = INF
	run._swarm_at = INF
	run.hunter.attack_timer = 100000.0
	run.hunter.god_mode = true
	run.enemies.clear_all()
	run.spells.learn(id)
	if run.spells.slot_of(id) < 0:
		run.spells.equip(id, 2)
	for letter: String in order:
		run.spells.add_mutation(_effect(PAIRS[id][0 if letter == "a" else 1]))
	run.view_size = 12.0
	var here: Vector3 = run.hunter.global_position
	for offset: Vector3 in [Vector3(3, 0, 0.6), Vector3(3, 0, -0.6), Vector3(5, 0, 1.5)]:
		var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), here + offset)
		foe.speed = 0.0
		foe.max_hp = 100000.0
		foe.hp = foe.max_hp
	await _frames(3)
	var slot: int = run.spells.slot_of(id)
	run.spells.cooldowns[slot] = 0.0
	run.spells.cast(slot, here + Vector3(3, 0, 0))
	if id == &"parry":
		run.hunter.parried.emit()
	if id == &"refracting_crystal":
		run.spells.cooldowns[1] = 0.0
		run.spells.cast(1, here + Vector3(6, 0, 0))
	await _frames(int(DELAY[id]))
	var painted: String = "-"
	if not run.spells.vfx.playing.is_empty():
		painted = str((run.spells.vfx.playing.back()["node"] as Node2D).get("variant"))
	_report.append("%-20s %-3s mutations %-28s peinte : %s" % [id, order, str(run.spells.mutations(id)), painted])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [id, order]))
	run.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame
