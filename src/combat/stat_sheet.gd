class_name StatSheet
extends RefCounted
## Statistiques modifiables. Valeur = (base + plat) × (1 + pourcentages), pourcentages bornés à −90 %.

signal changed(key: StringName)

var _base: Dictionary = {}
var _flat: Dictionary = {}
var _pct: Dictionary = {}


func set_base(key: StringName, value: float) -> void:
	_base[key] = value
	changed.emit(key)


func add_modifier(key: StringName, flat: float = 0.0, pct: float = 0.0) -> void:
	if flat != 0.0:
		_flat[key] = float(_flat.get(key, 0.0)) + flat
	if pct != 0.0:
		_pct[key] = float(_pct.get(key, 0.0)) + pct
	changed.emit(key)


func remove_modifier(key: StringName, flat: float = 0.0, pct: float = 0.0) -> void:
	add_modifier(key, -flat, -pct)


func get_value(key: StringName) -> float:
	var pct: float = maxf(float(_pct.get(key, 0.0)), -0.9)
	return (float(_base.get(key, 0.0)) + float(_flat.get(key, 0.0))) * (1.0 + pct)


func get_int(key: StringName) -> int:
	return int(round(get_value(key)))


func has_base(key: StringName) -> bool:
	return _base.has(key)
