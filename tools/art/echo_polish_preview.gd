extends "res://tools/art/origin_echo_preview.gd"
## Même partie et mêmes mesures pour les seize Échos, sorties séparées des livraisons historiques.


func _ready() -> void:
	output_path = "res://docs/previews/echos-animations/"
	await super._ready()


func _specifications() -> Array:
	var result: Array = super._specifications()
	var extra: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/echoes/catalog.json"))
	for spec: Dictionary in extra:
		result.append({"id": spec.id, "name": spec.name, "status": spec.status,
			"spells": [[spec.base], [spec.alt]]})
	return result


func _configure_targets(effect: Node2D, name: String, id: String) -> void:
	super._configure_targets(effect, name, id)
	var offsets := PackedVector2Array()
	if name in ["wandering_flame", "conductive_dome"]:
		for i: int in 3:
			offsets.append(effect.to_local(_run.ctx.enemies.list[i].global_position))
	elif name in ["healing_grove", "protective_thorns"]:
		offsets.append(effect.to_local(_run.ctx.player.global_position))
	if not offsets.is_empty():
		effect.call("set_secondary_offsets", offsets)
