extends TestCase
## Chaque texte visible doit exister en français ET en anglais.

var _table: Dictionary = {}


func before_each() -> void:
	if _table.is_empty():
		_table = load_table()


static func load_table() -> Dictionary:
	var table: Dictionary = {}
	var file := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < 3 or line[0] == "":
			continue
		table[line[0]] = {header[1]: line[1], header[2]: line[2]}
	return table


func test_all_rows_have_both_languages() -> void:
	for key: String in _table:
		var row: Dictionary = _table[key]
		check(str(row.get("fr", "")).strip_edges() != "", "%s : français manquant" % key)
		check(str(row.get("en", "")).strip_edges() != "", "%s : anglais manquant" % key)


func test_placeholders_match_between_languages() -> void:
	var regex := RegEx.create_from_string("%[0-9.]*[sd f]")
	for key: String in _table:
		var row: Dictionary = _table[key]
		check_eq(regex.search_all(row["fr"]).size(), regex.search_all(row["en"]).size(), "%s : nombre de %%" % key)


func test_data_keys_are_translated() -> void:
	var missing: PackedStringArray = []
	for collection: Dictionary in [GameDB.monsters, GameDB.enemies, GameDB.affixes, GameDB.bosses, GameDB.statuses,
			GameDB.upgrades, GameDB.relics, GameDB.synergies, GameDB.arenas, GameDB.difficulties, GameDB.skill_branches,
			GameDB.skill_nodes, GameDB.objectives, GameDB.research]:
		for id: StringName in collection:
			_collect_missing(collection[id], missing, {})
	check(missing.is_empty(), "clés de données sans traduction : %s" % ", ".join(missing))


func test_code_keys_are_translated() -> void:
	var regex := RegEx.create_from_string("tr\\(\"([A-Z0-9_]+)\"\\)")
	var missing: PackedStringArray = []
	for path: String in _scripts("res://src"):
		for result: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			var key: String = result.get_string(1)
			if not _table.has(key) and not missing.has(key):
				missing.append(key)
	check(missing.is_empty(), "clés du code sans traduction : %s" % ", ".join(missing))


func test_translation_server_has_both_locales() -> void:
	TranslationServer.set_locale("en")
	var en: String = tr("MENU_QUIT")
	TranslationServer.set_locale("fr")
	var fr: String = tr("MENU_QUIT")
	TranslationServer.set_locale(Settings.locale)
	check(en == "Quit" and fr == "Quitter", "traductions importées (%s / %s)" % [fr, en])


func _collect_missing(res: Resource, missing: PackedStringArray, seen: Dictionary) -> void:
	if res == null or seen.has(res.get_instance_id()):
		return
	seen[res.get_instance_id()] = true
	for prop: Dictionary in res.get_property_list():
		var prop_name: String = prop["name"]
		var value: Variant = res.get(prop_name)
		if prop_name.ends_with("_key") and value is String and value != "":
			if not _table.has(value) and not missing.has(value):
				missing.append(value)
		elif value is Resource:
			_collect_missing(value, missing, seen)
		elif value is Array:
			for item: Variant in value:
				if item is Resource:
					_collect_missing(item, missing, seen)


func _scripts(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	for sub: String in dir.get_directories():
		result.append_array(_scripts(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			result.append(dir_path.path_join(file))
	return result
