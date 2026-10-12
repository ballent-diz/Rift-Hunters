class_name RunStats
extends RefCounted
## Compteurs d'une partie (fin de partie, objectifs, maîtrise). Clés libres en StringName.

var counters: Dictionary = {}
var damage_by_source: Dictionary = {}
var kills_by_source: Dictionary = {}


func add(key: StringName, amount: float = 1.0) -> void:
	counters[key] = float(counters.get(key, 0.0)) + amount


func set_max(key: StringName, value: float) -> void:
	if value > float(counters.get(key, -INF)):
		counters[key] = value


func set_value(key: StringName, value: float) -> void:
	counters[key] = value


func get_value(key: StringName) -> float:
	return float(counters.get(key, 0.0))


func record_damage(source_id: StringName, amount: float) -> void:
	damage_by_source[source_id] = float(damage_by_source.get(source_id, 0.0)) + amount


func record_kill(source_id: StringName) -> void:
	kills_by_source[source_id] = int(kills_by_source.get(source_id, 0)) + 1
	add(&"kills")


func to_dict() -> Dictionary:
	return {
		"counters": counters.duplicate(),
		"damage_by_source": damage_by_source.duplicate(),
		"kills_by_source": kills_by_source.duplicate(),
	}
