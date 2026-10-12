extends Node
## Charge tous les scripts du projet (avec les autoloads) pour détecter les erreurs de compilation.
## Usage : godot --headless --path . res://tools/check_scripts.tscn

func _ready() -> void:
	var failures: int = 0
	var count: int = 0
	for path: String in _list("res://src") + _list("res://tests") + _list("res://tools"):
		count += 1
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			printerr("ÉCHEC : ", path)
			failures += 1
	print("Scripts vérifiés : %d, échecs : %d" % [count, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _list(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for sub: String in dir.get_directories():
		result.append_array(_list(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			result.append(dir_path.path_join(file))
	return result
