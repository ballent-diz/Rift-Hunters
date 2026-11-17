class_name DraftProgress
extends RefCounted
## Campagne de la base 3D : un chapitre s'ouvre quand le précédent est vaincu. Enregistré dans le profil v2
## (DraftSave, section `chapters`) ; le profil de la campagne 2D n'est jamais écrit.


static func cleared() -> Array[int]:
	var result: Array[int] = []
	for value: Variant in DraftSave.load().section("chapters").get("cleared", []):
		result.append(int(value))
	return result


static func is_unlocked(order: int, done: Array[int]) -> bool:
	return order <= 1 or done.has(order - 1)


static func record_victory(order: int) -> void:
	var done: Array[int] = cleared()
	if done.has(order):
		return
	done.append(order)
	done.sort()
	var profile: DraftSave = DraftSave.load()
	profile.section("chapters")["cleared"] = done
	profile.save()
