extends Node
## Persistance réelle entre deux lancements du jeu (fermeture puis redémarrage du processus).
## Usage : godot --headless --path . res://tests/smoke/persistence.tscn -- --phase=write   puis   -- --phase=read

const PATH := "user://test_persistence/profile.json"
## Profil de la v2 (DraftSave), séparé du profil v1.
const V2_PATH := "user://test_persistence/draft3d_profile.json"


func _ready() -> void:
	var phase: String = "write"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	DraftSave.path = V2_PATH
	DraftSave.legacy_unlocks_path = ""
	DraftSave.legacy_progress_path = ""
	if phase == "write":
		for suffix: String in ["", ".bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(V2_PATH + suffix))
		var unlocks: DraftUnlocks = DraftUnlocks.load()
		DraftSave.record_stats(true, 77, 120.0, 5, 0, 0)
		unlocks.record_run(300)
		unlocks.unlock(&"rift_leap")
		DraftProgress.record_victory(1)
		Profile.load_profile(PATH)
		Profile.profile.add_currency("shards", 500)
		HunterTree.learn(Profile.profile, GameDB.skill_node(&"combat_training"))
		Profile.profile.unlock("monster:glimmerwing")
		Profile.profile.mastery_entry(&"mossback")["xp"] = 42
		var ok: bool = Profile.save() == OK
		print("Écriture : ", "OK" if ok else "ÉCHEC")
		get_tree().quit(0 if ok else 1)
		return
	Profile.load_profile(PATH)
	var p: ProfileData = Profile.profile
	var v2: DraftUnlocks = DraftUnlocks.load()
	var checks := {
		"v2 état": DraftSave.load_state == DraftSave.LoadState.OK,
		"v2 Fragments": v2.currency() > 0 and v2.currency() < 300 and v2.last_gain() == 300,
		"v2 déblocage": v2.is_unlocked(&"rift_leap"),
		"v2 chapitres": DraftProgress.cleared() == ([1] as Array[int]),
		"v2 statistiques": int(DraftSave.stat("kills")) == 77,
		"état": Profile.load_state == Profile.LoadState.OK,
		"Éclats": p.shards() == 500 - GameDB.skill_node(&"combat_training").costs[0],
		"arbre": p.tree_rank(&"combat_training") == 1,
		"déblocage": p.has_unlock("monsters", &"glimmerwing"),
		"maîtrise": int(p.mastery_entry(&"mossback")["xp"]) == 42,
	}
	var failed: int = 0
	for key: String in checks:
		print("  %s %s" % ["✓" if checks[key] else "✗", key])
		if not checks[key]:
			failed += 1
	print("Relecture après redémarrage : ", "OK" if failed == 0 else "ÉCHEC")
	get_tree().quit(1 if failed > 0 else 0)
