extends Node
## Captures de contrôle des combos de la v2 (draft3d/combos.gd) : chaque combo est mis en scène dans une vraie partie
## (ennemis immobiles devant le Chasseur, sorts équipés, vrais lancers) puis photographié juste après son
## déclenchement. Les effets joués sont ceux du jeu (effets dédiés s'ils sont livrés, sinon les replis).
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 res://tools/combo_showcase.tscn \
##     -- --bot --passive --out=docs/previews/combos [--only=rift_counter]

const STAGES: Array[StringName] = [&"prismatic_execution", &"prismatic_deluge", &"gravity_blade", &"dimensional_hunt",
	&"tracker_rupture", &"prismatic_convergence", &"rift_counter", &"spectral_rebound", &"vengeful_aegis",
	&"rift_prison", &"shattering_rampart", &"still_storm"]

var run: DraftRun
var _out: String = "user://combos"
var _report: Array[String] = []


func _ready() -> void:
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	for stage: StringName in STAGES:
		if only == "" or only == String(stage):
			await _stage(stage)
	print("\n".join(_report))
	get_tree().quit()


func _stage(combo: StringName) -> void:
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
	for i: int in run.spells.slots.size():
		run.spells.stash(i)
	for id: StringName in DraftCombos.RECIPES[combo]:
		run.spells.learn(id)
		if not run.spells.has_spell(id):
			run.spells.equip(id, run.spells.slots.find(null))
	await _frames(3)
	await call("_play_" + String(combo))
	await _frames(4)
	var count: int = int(run.combos.counts.get(combo, 0))
	_report.append("%-22s déclenchements : %d" % [combo, count])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("%s.png" % combo))
	run.queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame


func _settle() -> void:
	for frame: int in 90:
		if not run.hunter.is_leaping():
			break
		await get_tree().physics_frame


func _here() -> Vector3:
	return run.hunter.global_position


func _foe(offset: Vector3) -> DraftEnemies.Foe:
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), _here() + offset)
	foe.speed = 0.0
	foe.max_hp = 100000.0
	foe.hp = foe.max_hp
	return foe


func _cast(id: StringName, aim: Vector3) -> void:
	var slot: int = run.spells.slot_of(id)
	if slot >= 0:
		run.spells.cooldowns[slot] = 0.0
		run.spells.cast(slot, aim)


func _group(center: Vector3, count: int = 4) -> DraftEnemies.Foe:
	var first: DraftEnemies.Foe = _foe(center)
	for i: int in count - 1:
		_foe(center + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.2)
	return first


func _play_prismatic_execution() -> void:
	var foe: DraftEnemies.Foe = _group(Vector3(4, 0, 0))
	await _frames(2)
	_cast(&"prismatic_lance", foe.pos)
	await _frames(20)
	_cast(&"rupture", foe.pos)


func _play_prismatic_deluge() -> void:
	_group(Vector3(9, 0, 0), 5)
	_cast(&"refracting_crystal", _here() + Vector3(4, 0, 0))
	await _frames(3)
	_cast(&"prismatic_lance", _here() + Vector3(12, 0, 0))
	await _frames(14)


func _play_gravity_blade() -> void:
	var foe: DraftEnemies.Foe = _group(Vector3(2.5, 0, 0))
	await _frames(2)
	_cast(&"singularity", foe.pos)
	await _frames(20)
	_cast(&"cleaving_slash", _here() + Vector3(4, 0, 0))


func _play_dimensional_hunt() -> void:
	var foe: DraftEnemies.Foe = _foe(Vector3(3, 0, 0))
	_foe(Vector3(3.5, 0, 2.2))
	_foe(Vector3(3.5, 0, -2.2))
	await _frames(2)
	_cast(&"hunter_mark", foe.pos)
	await _frames(10)
	_cast(&"void_rend", _here() + Vector3(6, 0, 0))


func _play_tracker_rupture() -> void:
	var foe: DraftEnemies.Foe = _group(Vector3(4, 0, 0))
	await _frames(2)
	_cast(&"hunter_mark", foe.pos)
	await _frames(10)
	_cast(&"rupture", foe.pos)


func _play_prismatic_convergence() -> void:
	var foe: DraftEnemies.Foe = _foe(Vector3(8, 0, 0))
	for i: int in 5:
		_foe(Vector3(8 + 2.5 * (i + 1), 0, 2.0 * (1 if i % 2 == 0 else -1)))
	_cast(&"refracting_crystal", _here() + Vector3(4, 0, 0))
	await _frames(3)
	_cast(&"prismatic_lance", _here() + Vector3(12, 0, 0))
	await _frames(25)
	_cast(&"rupture", foe.pos)


func _play_rift_counter() -> void:
	_group(Vector3(2, 0, 0), 3)
	_group(Vector3(-2, 0, 0), 3)
	await _frames(2)
	_cast(&"parry", _here())
	run.hunter.parried.emit()
	await _frames(6)
	_cast(&"cleaving_slash", _here() + Vector3(4, 0, 0))


func _play_spectral_rebound() -> void:
	_group(Vector3(2.5, 0, 0), 3)
	await _frames(2)
	_cast(&"rift_step", _here() + Vector3(0, 0, 5))
	await _frames(4)
	_cast(&"void_rend", _here() + Vector3(5, 0, 0))


func _play_vengeful_aegis() -> void:
	_group(Vector3(1.6, 0, 0), 5)
	await _frames(2)
	_cast(&"aegis", _here())
	_cast(&"parry", _here())
	run.hunter.parried.emit()
	await _frames(6)
	run.hunter.shield_broken.emit()


func _play_rift_prison() -> void:
	_cast(&"rift_wall", _here() + Vector3(4, 0, 0))
	_group(Vector3(6.5, 0, 0), 5)
	await _frames(2)
	_cast(&"singularity", _here() + Vector3(5.5, 0, 0))
	await _frames(25)


func _play_shattering_rampart() -> void:
	_cast(&"rift_wall", _here() + Vector3(6, 0, 0))
	_group(Vector3(7.8, 0, 0), 4)
	await _frames(2)
	_cast(&"rift_leap", _here() + Vector3(4.5, 0, 0))
	await _settle()


func _play_still_storm() -> void:
	var foe: DraftEnemies.Foe = _group(Vector3(3, 0, 0), 5)
	await _frames(2)
	_cast(&"stasis_wave", foe.pos)
	_cast(&"shard_rain", foe.pos)
	await _frames(30)
