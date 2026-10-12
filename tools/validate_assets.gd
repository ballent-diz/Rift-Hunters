extends Node
## Rapport de validation des assets. Usage : godot --headless --path . res://tools/validate_assets.tscn
## Code de sortie 1 si un asset présent est invalide (les placeholders ne bloquent pas).

func _ready() -> void:
	var report: Array[Dictionary] = AssetValidator.validate_manifest(Assets.manifest)
	var errors: int = 0
	var placeholders: int = 0
	for entry: Dictionary in report:
		match entry["status"]:
			"ERROR":
				errors += 1
			"PLACEHOLDER":
				placeholders += 1
		var detail: String = "" if (entry["messages"] as PackedStringArray).is_empty() else " — " + "; ".join(entry["messages"])
		print("%-12s %s%s" % [entry["status"], entry["id"], detail])
	print("\nAssets : %d, valides : %d, placeholders : %d, erreurs : %d" % [report.size(),
		report.size() - errors - placeholders, placeholders, errors])
	get_tree().quit(1 if errors > 0 else 0)
