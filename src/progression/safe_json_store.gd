class_name SafeJsonStore
extends RefCounted
## Fichier JSON sûr : écriture atomique (tmp → vérification → bascule), copie .bak,
## mise en quarantaine des fichiers corrompus (jamais supprimés), restauration depuis .bak.

enum LoadStatus { OK, MISSING, RESTORED_FROM_BACKUP, CORRUPTED_NO_BACKUP }

var path: String
var last_status: LoadStatus = LoadStatus.MISSING
## Chemin de la copie mise en quarantaine lors du dernier chargement (vide sinon).
var quarantined_path: String = ""


func _init(p_path: String) -> void:
	path = p_path


func backup_path() -> String:
	return path + ".bak"


func temp_path() -> String:
	return path + ".tmp"


## validator(data: Dictionary) -> String : message d'erreur, vide si les données sont valides.
func load_data(validator: Callable = Callable()) -> Dictionary:
	quarantined_path = ""
	if FileAccess.file_exists(path):
		var main: Dictionary = _read_valid(path, validator)
		if not main.is_empty():
			last_status = LoadStatus.OK
			return main
		quarantined_path = _quarantine(path)
	if FileAccess.file_exists(backup_path()):
		var backup: Dictionary = _read_valid(backup_path(), validator)
		if not backup.is_empty():
			last_status = LoadStatus.RESTORED_FROM_BACKUP
			return backup
	if quarantined_path != "":
		last_status = LoadStatus.CORRUPTED_NO_BACKUP
	else:
		last_status = LoadStatus.MISSING
	return {}


func save_data(data: Dictionary) -> Error:
	_ensure_dir()
	var text: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(temp_path(), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()
	# Vérifie que ce qui a été écrit se relit à l'identique avant de remplacer quoi que ce soit.
	var check: Variant = JSON.parse_string(FileAccess.get_file_as_string(temp_path()))
	if not (check is Dictionary):
		DirAccess.remove_absolute(temp_path())
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		var copy_error: Error = DirAccess.copy_absolute(path, backup_path())
		if copy_error != OK:
			push_warning("Copie de sauvegarde impossible (%s)" % error_string(copy_error))
	return DirAccess.rename_absolute(temp_path(), path)


func _read_valid(file_path: String, validator: Callable) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(file_path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed
	if validator.is_valid():
		var error: String = validator.call(data)
		if error != "":
			push_warning("Sauvegarde invalide (%s) : %s" % [file_path, error])
			return {}
	return data


func _quarantine(file_path: String) -> String:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var target: String = "%s.corrupted-%s" % [file_path, stamp]
	var error: Error = DirAccess.copy_absolute(file_path, target)
	if error != OK:
		push_error("Impossible de mettre en quarantaine %s" % file_path)
		return ""
	push_warning("Sauvegarde corrompue conservée dans " + target)
	return target


func _ensure_dir() -> void:
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
