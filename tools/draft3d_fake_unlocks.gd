extends RefCounted
## Double de `DraftUnlocks` (docs/design/DEBLOCAGE_V2.md) pour les essais et les captures de l'écran de déblocage,
## en attendant la classe de la session « Gameplay ». Même API, contenu lu dans draft3d/spells/ : sorts (cartes
## « learn_ ») et variantes, coûts indicatifs du document. N'écrit rien sur le disque.

signal changed

const SPELL_COST := 150
const VARIANT_COST := 80
const FREE_SPELLS: Array[StringName] = [&"cleaving_slash", &"prismatic_lance"]

var fragments: int = 420
var gain: int = 87
var unlocked: Dictionary = {}
var starting: Array[StringName] = FREE_SPELLS.duplicate()
var _entries: Array[Dictionary] = []


func _init() -> void:
	var variants: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://draft3d/spells"):
		if not file.ends_with(".tres"):
			continue
		var data: UpgradeData = load("res://draft3d/spells/" + file.trim_suffix(".remap"))
		var effect: Resource = data.effects[0] if not data.effects.is_empty() else null
		if effect == null:
			continue
		var spell_id: StringName = effect.get("spell_id")
		var kind: int = int(effect.get("kind"))
		if kind == 0:
			var spell: SpellData = DraftSpells.spell(spell_id)
			_entries.append({"id": spell_id, "kind": "spell", "spell_id": spell_id,
				"name_key": spell.name_key if spell != null else data.name_key,
				"desc_key": spell.desc_key if spell != null else data.desc_key,
				"cost": 0 if FREE_SPELLS.has(spell_id) else SPELL_COST})
			if FREE_SPELLS.has(spell_id):
				unlocked[spell_id] = true
		elif kind == 1 and variants.get(spell_id, 0) < 2:
			variants[spell_id] = variants.get(spell_id, 0) + 1
			_entries.append({"id": data.id, "kind": "variant", "spell_id": spell_id, "name_key": data.name_key,
				"desc_key": data.desc_key, "cost": VARIANT_COST})
	unlocked[&"lance_fan"] = true


func currency() -> int:
	return fragments


## Sorts d'abord (offerts en tête), chaque sort suivi de ses variantes.
func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var spells: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if entry["kind"] == "spell":
			spells.append(entry)
	spells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return [int(a["cost"]), str(a["id"])] < [int(b["cost"]), str(b["id"])])
	for spell: Dictionary in spells:
		result.append(_view(spell))
		for entry: Dictionary in _entries:
			if entry["kind"] == "variant" and entry["spell_id"] == spell["id"]:
				result.append(_view(entry))
	return result


func unlock(id: StringName) -> bool:
	for entry: Dictionary in entries():
		if entry["id"] == id and not entry["unlocked"] and entry["available"] and int(entry["cost"]) <= fragments:
			fragments -= int(entry["cost"])
			unlocked[id] = true
			changed.emit()
			return true
	return false


func starting_spells() -> Array[StringName]:
	return starting.duplicate()


func set_starting_spells(ids: Array[StringName]) -> bool:
	if ids.size() != 2 or ids[0] == ids[1] or not unlocked.has(ids[0]) or not unlocked.has(ids[1]):
		return false
	starting = ids.duplicate()
	changed.emit()
	return true


func last_gain() -> int:
	return gain


func _view(entry: Dictionary) -> Dictionary:
	var view: Dictionary = entry.duplicate()
	view["unlocked"] = unlocked.has(entry["id"])
	view["available"] = entry["kind"] == "spell" or unlocked.has(entry["spell_id"])
	return view
