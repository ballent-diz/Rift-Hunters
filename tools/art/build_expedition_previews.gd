extends SceneTree
## Vignettes de menu issues des décors jouables : aucune nouvelle peinture ni modification des cartes.
## Usage : godot --headless --path . --script res://tools/art/build_expedition_previews.gd

const TARGET := Vector2i(768, 256)
## Carte → [entrée de décor, hauteur du bandeau (0..1, centre), carte entière recomposée depuis ses tuiles].
## Les trois premières gardent leur cadrage d'origine (première tuile seulement).
const MAPS := {
	"three_rifts": ["environment.cascade_ruins", 0.0, false],
	"storm_highlands": ["environment.storm_highlands", 0.64, false],
	"fractured_plain": ["environment.fractured_plain_map", 0.4, false],
	"firefly_woods": ["environment.firefly_woods", 0.45, true],
	"mist_ford": ["environment.mist_ford", 0.5, true],
	"cascade_source": ["environment.cascade_source", 0.72, true],
	"scorched_verge": ["environment.scorched_verge", 0.5, true],
}


func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_manifest.json"))
	for id: String in MAPS:
		var entry: Dictionary = data["entries"][MAPS[id][0]]
		var image: Image = _load_map(entry, MAPS[id][2])
		if image == null:
			push_error("Décor absent : " + MAPS[id][0])
			quit(1)
			return
		var width: int = image.get_width()
		var height: int = mini(image.get_height(), width / 3)
		var focus: float = MAPS[id][1]
		var top: int = clampi(int(image.get_height() * focus - height * 0.5), 0, image.get_height() - height) \
			if MAPS[id][2] else (0 if focus == 0.0 else int((image.get_height() - height) * focus))
		var crop: Image = image.get_region(Rect2i(0, top, width, height))
		crop.resize(TARGET.x, TARGET.y, Image.INTERPOLATE_LANCZOS)
		var out: String = "res://assets/ui/expedition/" + id + ".png"
		crop.save_png(out)
		entry["menu_preview"] = out
		entry["menu_preview_generated_by"] = "tools/art/build_expedition_previews.gd"
	var file := FileAccess.open("res://assets/asset_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	print("%d vignettes d’expédition enregistrées : %s" % [MAPS.size(), TARGET])
	quit()


## Première tuile, ou carte entière (tuiles côte à côte, réduites avant l'assemblage).
func _load_map(entry: Dictionary, whole: bool) -> Image:
	if not whole or not entry.has("map_tiles"):
		return Image.load_from_file(entry["map"])
	var tiles: Array = entry["map_tiles"]
	var parts: Array[Image] = []
	for path: String in tiles:
		var tile := Image.load_from_file(path)
		if tile == null:
			return null
		tile.resize(tile.get_width() / 4, tile.get_height() / 4, Image.INTERPOLATE_LANCZOS)
		parts.append(tile)
	var full := Image.create(parts[0].get_width() * parts.size(), parts[0].get_height(), false, parts[0].get_format())
	for i: int in parts.size():
		full.blit_rect(parts[i], Rect2i(Vector2i.ZERO, parts[i].get_size()), Vector2i(parts[0].get_width() * i, 0))
	return full
