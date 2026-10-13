extends Node
## Persistance réelle entre deux lancements du jeu (fermeture puis redémarrage du processus).
## Usage : godot --headless --path . res://tests/smoke/persistence.tscn -- --phase=write   puis   -- --phase=read

const PATH := "user://test_persistence/profile.json"


func _ready() -> void:
	var phase: String = "write"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	if phase == "write":
		for suffix: String in ["", ".bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
		Profile.load_profile(PATH)
		Profile.profile.add_currency("shards", 500)
		SkillTree.buy(Profile.profile, GameDB.skill_node(&"combat_training"))
		Profile.profile.unlock("monster:glimmerwing")
		Profile.profile.mastery_entry(&"mossback")["xp"] = 42
		var ok: bool = Profile.save() == OK
		print("Écriture : ", "OK" if ok else "ÉCHEC")
		get_tree().quit(0 if ok else 1)
		return
	Profile.load_profile(PATH)
	var p: ProfileData = Profile.profile
	var checks := {
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
