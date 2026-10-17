extends SceneTree
## Vignettes de menu issues des décors jouables : aucune nouvelle peinture ni modification des cartes.

const TARGET := Vector2i(768, 256)
const MAPS := {
	"three_rifts": "environment.cascade_ruins",
	"storm_highlands": "environment.storm_highlands",
	"fractured_plain": "environment.fractured_plain_map",
}


func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_manifest.json"))
	for id: String in MAPS:
		var entry: Dictionary = data["entries"][MAPS[id]]
		var source: String = entry["map"]
		var image := Image.load_from_file(source)
		if image == null:
			push_error("Décor absent : " + source)
			quit(1)
			return
		var width: int = image.get_width()
		var height: int = mini(image.get_height(), width / 3)
		var focus: float = 0.64 if id == "storm_highlands" else 0.4
		var top: int = 0 if id == "three_rifts" else int((image.get_height() - height) * focus)
		var crop: Image = image.get_region(Rect2i(0, top, width, height))
		crop.resize(TARGET.x, TARGET.y, Image.INTERPOLATE_LANCZOS)
		var out: String = "res://assets/ui/expedition/" + id + ".png"
		crop.save_png(out)
		entry["menu_preview"] = out
		entry["menu_preview_generated_by"] = "tools/art/build_expedition_previews.gd"
	var file := FileAccess.open("res://assets/asset_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	print("Trois vignettes d’expédition enregistrées : ", TARGET)
	quit()
