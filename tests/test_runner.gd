extends Node
## Lanceur de tests : exécute tests/unit/test_*.gd. Code de sortie 1 si un test échoue.
## Usage : godot --headless --path . res://tests/run_tests.tscn [-- --filter=nom]

func _ready() -> void:
	var filter: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var total: int = 0
	var failed: int = 0
	var dir := DirAccess.open("res://tests/unit")
	var files: PackedStringArray = dir.get_files() if dir else PackedStringArray()
	files.sort()
	for file: String in files:
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		if filter != "" and not file.contains(filter):
			continue
		var script: GDScript = load("res://tests/unit/" + file)
		var suite: TestCase = script.new()
		suite.host = self
		for method: Dictionary in suite.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			suite.current_test = "%s::%s" % [file.get_basename(), method_name]
			var before: int = suite.failures.size()
			suite.before_each()
			await suite.call(method_name)
			suite.after_each()
			# Laisse le moteur libérer les scènes créées par le test (queue_free) avant le suivant.
			await get_tree().process_frame
			await get_tree().process_frame
			if suite.failures.size() > before:
				failed += 1
				print("  ✗ ", suite.current_test)
			else:
				print("  ✓ ", suite.current_test)
		for failure: String in suite.failures:
			printerr("    ÉCHEC ", failure)
	print("\nTests : %d, réussis : %d, échoués : %d" % [total, total - failed, failed])
	get_tree().quit(1 if failed > 0 else 0)
