class_name DraftProgress
extends RefCounted
## Campagne de la base 3D : un chapitre s'ouvre quand le précédent est vaincu. Chapitres atteints et vaincus gardés
## dans le profil v2 (`DraftSave`, user://draft3d_profile.json) : le profil de la campagne 2D n'est jamais écrit.


static func cleared() -> Array[int]:
	var result: Array[int] = []
	result.assign(DraftSave.data()["chapters"]["cleared"])
	return result


static func reached() -> Array[int]:
	var result: Array[int] = []
	result.assign(DraftSave.data()["chapters"]["reached"])
	return result


static func is_unlocked(order: int, done: Array[int]) -> bool:
	return order <= 1 or done.has(order - 1)


## Début d'un chapitre : il compte comme atteint.
static func record_start(order: int) -> void:
	if not DraftSave.read_only and DraftSave.mark_reached(order):
		DraftSave.save()


## Victoire : le chapitre est vaincu et le suivant atteint (ouvert).
static func record_victory(order: int) -> void:
	if DraftSave.read_only:
		return
	var done: Array = DraftSave.data()["chapters"]["cleared"]
	var changed: bool = DraftSave.mark_reached(order)
	changed = DraftSave.mark_reached(order + 1) or changed
	if not done.has(order):
		done.append(order)
		done.sort()
		changed = true
	if changed:
		DraftSave.save()
