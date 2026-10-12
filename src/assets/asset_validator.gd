class_name AssetValidator
extends RefCounted
## Valide le manifeste d'assets : fichiers, dimensions, transparence, ancre, animations requises.
## Statuts : OK, PLACEHOLDER (prévu mais absent, non bloquant), ERROR (bloquant).

## Retourne [{id, status, messages}].
static func validate_manifest(entries: Dictionary) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for id: String in entries:
		report.append(validate_entry(id, entries[id]))
	return report


static func validate_entry(id: String, e: Dictionary) -> Dictionary:
	var messages: PackedStringArray = []
	var category: String = id.get_slice(".", 0)
	if category == "environment":
		return validate_environment(id, e)
	var cell: Array = e.get("cell", [])
	if cell.size() != 2 or int(cell[0]) <= 0 or int(cell[1]) <= 0:
		messages.append("cellule invalide")
	var animations: Dictionary = e.get("animations", {})
	var required: Array = AssetRegistryRules.required_animations(category)
	if id.count(".") == 1:
		for anim: String in required:
			if not animations.has(anim):
				messages.append("animation requise manquante : " + anim)
	var sheet_path: String = str(e.get("sheet", ""))
	var exists: bool = sheet_path != "" and ResourceLoader.exists(sheet_path)
	if not exists:
		var status: String = "ERROR" if str(e.get("status", "planned")) == "final" or not messages.is_empty() else "PLACEHOLDER"
		if status == "ERROR" and messages.is_empty():
			messages.append("statut final mais feuille absente : " + sheet_path)
		return {"id": id, "status": status, "messages": messages}
	var texture: Texture2D = load(sheet_path)
	var image: Image = texture.get_image() if texture else null
	if image == null:
		messages.append("image illisible")
		return {"id": id, "status": "ERROR", "messages": messages}
	messages.append_array(check_image(image, cell, animations, e.get("anchor", [])))
	return {"id": id, "status": "ERROR" if not messages.is_empty() else "OK", "messages": messages}


## Vérifications d'image pures (testables avec une image générée).
static func check_image(image: Image, cell: Array, animations: Dictionary, anchor: Array) -> PackedStringArray:
	var messages: PackedStringArray = []
	if cell.size() != 2:
		return messages
	var cw: int = int(cell[0])
	var ch: int = int(cell[1])
	if image.get_width() % cw != 0 or image.get_height() % ch != 0:
		messages.append("dimensions %dx%d non multiples de la cellule %dx%d" % [image.get_width(), image.get_height(), cw, ch])
	if not image.detect_alpha():
		messages.append("pas de transparence (fond opaque)")
	else:
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1)]:
			if image.get_pixelv(corner).a > 0.05:
				messages.append("coin %s non transparent" % corner)
				break
	var columns: int = image.get_width() / maxi(cw, 1)
	var rows: int = image.get_height() / maxi(ch, 1)
	for anim_name: String in animations:
		var anim: Dictionary = animations[anim_name]
		if int(anim.get("row", 0)) >= rows:
			messages.append("animation %s : ligne %d hors de la feuille" % [anim_name, int(anim.get("row", 0))])
		if int(anim.get("frames", 1)) > columns:
			messages.append("animation %s : %d frames > %d colonnes" % [anim_name, int(anim.get("frames", 1)), columns])
	if anchor.size() == 2 and (int(anchor[0]) < 0 or int(anchor[0]) > cw or int(anchor[1]) < 0 or int(anchor[1]) > ch):
		messages.append("ancre hors de la cellule")
	return messages


## Décor d'arène : sol et atlas présents, chaque élément dans l'atlas, couches connues.
static func validate_environment(id: String, e: Dictionary) -> Dictionary:
	var messages: PackedStringArray = []
	var present: bool = ResourceLoader.exists(str(e.get("ground", ""))) and ResourceLoader.exists(str(e.get("atlas", "")))
	if not present:
		var missing_status: String = "ERROR" if str(e.get("status", "planned")) == "final" else "PLACEHOLDER"
		if missing_status == "ERROR":
			messages.append("statut final mais sol ou atlas absent")
		return {"id": id, "status": missing_status, "messages": messages}
	var atlas: Texture2D = load(str(e["atlas"]))
	var bounds := Rect2(Vector2.ZERO, atlas.get_size())
	var decals: Array = e.get("decals", [])
	if decals.is_empty():
		messages.append("aucun élément de décor")
	for raw: Variant in decals:
		var d: Dictionary = raw
		var r: Array = d.get("rect", [])
		if r.size() != 4 or not bounds.encloses(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))):
			messages.append("élément %s hors de l'atlas" % str(d.get("name", "?")))
		if not EnvironmentSet.LAYERS.has(StringName(str(d.get("layer", "")))):
			messages.append("élément %s : couche inconnue %s" % [str(d.get("name", "?")), str(d.get("layer", ""))])
	return {"id": id, "status": "ERROR" if not messages.is_empty() else "OK", "messages": messages}
