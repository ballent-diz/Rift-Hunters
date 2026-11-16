class_name DraftUnlocks
extends RefCounted
## Déblocages permanents de la version 3D (docs/design/DEBLOCAGE_V2.md, direction C) : une monnaie gagnée en partie
## (Fragments de faille), des sorts et des mutations débloqués à l'écran « Déblocages » (draft3d/unlock_screen.gd) et
## les 2 sorts de départ choisis parmi les sorts débloqués. Le contenu débloqué est le seul tiré au choix de niveau.
## Sauvegarde à part : user://draft3d_unlocks.json (le profil 2D n'est jamais écrit). Coûts et gains : draft3d/tuning.tres.

signal changed

const PATH := "user://draft3d_unlocks.json"
const FORMAT := 1

## Chemin de sauvegarde ; vide : rien n'est lu ni écrit (essais automatiques, bot).
static var path: String = PATH
static var _instance: DraftUnlocks

var fragments: int = 0
var unlocked: Dictionary = {}
var starting: Array[StringName] = []
var gain: int = -1
var tuning: DraftTuning
var _entries: Array[Dictionary] = []


## État partagé (chargé une fois) : l'écran, le menu et la partie lisent le même objet.
static func load() -> DraftUnlocks:
	if _instance == null:
		_instance = DraftUnlocks.new()
		_instance._read()
	return _instance


## Oublie l'état en mémoire (essais : un nouvel état est relu au prochain `load`).
static func reset() -> void:
	_instance = null


func _init() -> void:
	tuning = ResourceLoader.load("res://draft3d/tuning.tres")
	var spells: Array[Dictionary] = []
	var variants: Array[Dictionary] = []
	for path_card: String in DraftUpgrades.SPELL_CARDS:
		var card: UpgradeData = ResourceLoader.load(path_card)
		var effect := card.effects[0] as DraftSpellEffect if not card.effects.is_empty() else null
		if effect == null:
			continue
		match effect.kind:
			DraftSpellEffect.Kind.LEARN:
				var spell: SpellData = DraftSpells.spell(effect.spell_id)
				var free: bool = tuning.free_spells.has(effect.spell_id)
				spells.append({"id": effect.spell_id, "kind": "spell", "spell_id": effect.spell_id,
					"name_key": spell.name_key, "desc_key": spell.desc_key, "cost": 0 if free else tuning.spell_unlock_cost})
			DraftSpellEffect.Kind.VARIANT:
				variants.append({"id": card.id, "kind": "variant", "spell_id": effect.spell_id,
					"name_key": card.name_key, "desc_key": card.desc_key, "cost": tuning.mutation_unlock_cost})
	spells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return [int(a["cost"]), str(a["id"])] < [int(b["cost"]), str(b["id"])])
	for spell: Dictionary in spells:
		_entries.append(spell)
		for variant: Dictionary in variants:
			if variant["spell_id"] == spell["id"]:
				_entries.append(variant)
	for id: StringName in tuning.free_spells:
		unlocked[id] = true
	starting = tuning.free_spells.duplicate()


func currency() -> int:
	return fragments


## Ce qui se débloque, sorts puis leurs mutations : {id, kind, spell_id, name_key, desc_key, cost, unlocked, available}.
func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		var view: Dictionary = entry.duplicate()
		view["unlocked"] = unlocked.has(entry["id"])
		view["available"] = entry["kind"] == "spell" or unlocked.has(entry["spell_id"])
		result.append(view)
	return result


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


## Dépense et débloque ; faux si trop cher, déjà fait, inconnu ou condition manquante (sort non débloqué).
func unlock(id: StringName) -> bool:
	for entry: Dictionary in entries():
		if entry["id"] == id and not entry["unlocked"] and entry["available"] and int(entry["cost"]) <= fragments:
			fragments -= int(entry["cost"])
			unlocked[id] = true
			_write()
			changed.emit()
			return true
	return false


func starting_spells() -> Array[StringName]:
	return starting.duplicate()


## Deux sorts différents, débloqués.
func set_starting_spells(ids: Array[StringName]) -> bool:
	if ids.size() != 2 or ids[0] == ids[1] or not unlocked.has(ids[0]) or not unlocked.has(ids[1]):
		return false
	starting = ids.duplicate()
	_write()
	changed.emit()
	return true


## Fragments gagnés à la dernière partie (écran de fin) ; -1 avant toute partie.
func last_gain() -> int:
	return gain


## Fragments d'une partie : éliminations, temps tenu, gardien et Dévoreur vaincus (réglages dans tuning.tres).
func run_gain(kills: int, seconds: float, guardians: int, devourers: int) -> int:
	return int(floor(kills * tuning.fragments_per_kill + seconds / 60.0 * tuning.fragments_per_minute
		+ guardians * tuning.fragments_per_guardian + devourers * tuning.fragments_per_devourer))


## Fin de partie : le gain est crédité et enregistré, défaite comme victoire.
func record_run(amount: int) -> void:
	gain = maxi(amount, 0)
	fragments += gain
	_write()
	changed.emit()


func _read() -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	fragments = maxi(int((data as Dictionary).get("fragments", 0)), 0)
	for id: Variant in (data as Dictionary).get("unlocked", []):
		unlocked[StringName(str(id))] = true
	var saved: Array[StringName] = []
	for id: Variant in (data as Dictionary).get("starting", []):
		saved.append(StringName(str(id)))
	if saved.size() == 2 and saved[0] != saved[1] and unlocked.has(saved[0]) and unlocked.has(saved[1]):
		starting = saved
	gain = int((data as Dictionary).get("last_gain", -1))


func _write() -> void:
	if path == "":
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	var ids: Array[String] = []
	for id: StringName in unlocked:
		ids.append(String(id))
	file.store_string(JSON.stringify({"version": FORMAT, "fragments": fragments, "unlocked": ids,
		"starting": starting.map(func(id: StringName) -> String: return String(id)), "last_gain": gain}))
