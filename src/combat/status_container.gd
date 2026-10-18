class_name StatusContainer
extends RefCounted
## Statuts actifs d'un combattant. Les agrégats sont recalculés à chaque changement.

## Bonus d'amplification de Fracture (arbre/reliques), injecté par StatusSystem.
var fracture_amp_bonus: float = 0.0
var _entries: Dictionary = {}  # StringName -> Dictionary {data, stacks, time, source_id, tick}
var _defense_add: float = 0.0
var _damage_taken_mult: float = 1.0
var _speed_mult: float = 1.0
var _miss_chance: float = 0.0


func apply(data: StatusData, stacks: int, duration: float, max_stacks: int, source_id: StringName) -> int:
	var entry: Dictionary = _entries.get(data.id, {})
	var before: int = 0
	if entry.is_empty():
		entry = {"data": data, "stacks": 0, "time": 0.0, "source_id": source_id, "tick": 0.0}
		_entries[data.id] = entry
	else:
		before = int(entry["stacks"])
	entry["stacks"] = mini(before + stacks, max_stacks)
	entry["time"] = maxf(float(entry["time"]), duration)
	entry["source_id"] = source_id
	_recompute()
	return int(entry["stacks"]) - before


func remove(id: StringName) -> int:
	if not _entries.has(id):
		return 0
	var stacks: int = int(_entries[id]["stacks"])
	_entries.erase(id)
	_recompute()
	return stacks


func get_stacks(id: StringName) -> int:
	var entry: Dictionary = _entries.get(id, {})
	return int(entry.get("stacks", 0))


func has(id: StringName) -> bool:
	return _entries.has(id)


func is_empty() -> bool:
	return _entries.is_empty()


func ids() -> Array:
	return _entries.keys()


func clear() -> void:
	_entries.clear()
	_recompute()


## Avance le temps. Retourne les dégâts sur la durée à appliquer : [[montant, source_id, status_id], ...].
func tick(delta: float, dps_mult: Dictionary) -> Array:
	if _entries.is_empty():
		return []
	var result: Array = []
	var expired: Array = []
	for id: StringName in _entries:
		var entry: Dictionary = _entries[id]
		entry["time"] = float(entry["time"]) - delta
		var data: StatusData = entry["data"]
		if data.dps_per_stack > 0.0:
			entry["tick"] = float(entry["tick"]) + delta
			if float(entry["tick"]) >= 0.5:
				entry["tick"] = float(entry["tick"]) - 0.5
				var mult: float = float(dps_mult.get(id, 1.0))
				result.append([data.dps_per_stack * int(entry["stacks"]) * 0.5 * mult, entry["source_id"], id])
		if float(entry["time"]) <= 0.0:
			expired.append(id)
	if not expired.is_empty():
		for id: StringName in expired:
			_entries.erase(id)
		_recompute()
	return result


func defense_add() -> float:
	return _defense_add


func damage_taken_mult() -> float:
	return _damage_taken_mult


func speed_mult() -> float:
	return _speed_mult


## Chance de rater une attaque (Aveuglement ; les chances se cumulent sans dépasser 90 %).
func miss_chance() -> float:
	return _miss_chance


func _recompute() -> void:
	_defense_add = 0.0
	_damage_taken_mult = 1.0
	_speed_mult = 1.0
	var hit_chance: float = 1.0
	for id: StringName in _entries:
		var data: StatusData = _entries[id]["data"]
		_defense_add += data.defense_add
		var taken: float = data.damage_taken_mult
		if id == &"fracture":
			taken += fracture_amp_bonus
		_damage_taken_mult *= taken
		_speed_mult *= data.speed_mult
		hit_chance *= 1.0 - data.miss_chance
	_miss_chance = minf(1.0 - hit_chance, 0.9)
