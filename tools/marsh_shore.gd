extends Node3D
## Carte des rives du Marais des Marées (DraftLevelMarsh.SHORE_MAP) : à régénérer après un changement de plan.
## godot --headless --path . res://tools/marsh_shore.tscn


func _ready() -> void:
	var level := DraftLevelMarsh.new()
	add_child(level)
	level.build()
	var image: Image = level.shore_image()
	var path: String = ProjectSettings.globalize_path(DraftLevelMarsh.SHORE_MAP)
	var code: int = image.save_png(path)
	print("RIVES|%s|%d × %d|code %d" % [DraftLevelMarsh.SHORE_MAP, image.get_width(), image.get_height(), code])
	get_tree().quit(code)
