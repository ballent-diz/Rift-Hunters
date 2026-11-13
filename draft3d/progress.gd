class_name DraftProgress
extends RefCounted
## Campagne de la base 3D : un chapitre s'ouvre quand le précédent est vaincu. Sauvegarde à part
## (user://draft3d_progress.json) : le profil de la campagne 2D n'est jamais écrit.

const PATH := "user://draft3d_progress.json"

## Chemin de sauvegarde ; vide : rien n'est lu ni écrit (essais automatiques, bot).
static var path: String = PATH


static func cleared() -> Array[int]:
	var result: Array[int] = []
	if path == "" or not FileAccess.file_exists(path):
		return result
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		for value: Variant in (data as Dictionary).get("cleared", []):
			result.append(int(value))
	return result


static func is_unlocked(order: int, done: Array[int]) -> bool:
	return order <= 1 or done.has(order - 1)


static func record_victory(order: int) -> void:
	if path == "":
		return
	var done: Array[int] = cleared()
	if done.has(order):
		return
	done.append(order)
	done.sort()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 1, "cleared": done}))
