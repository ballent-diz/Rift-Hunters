extends Node
func _ready() -> void:
	call_deferred("_measure")
func _measure() -> void:
	for id: StringName in [&"three_rifts",&"storm_highlands"]:
		var arena: ArenaData = get_tree().root.get_node("GameDB").arena(id)
		var ground := ArenaGround.new()
		ground.setup(arena,7)
		var flow := FlowField.new()
		flow.setup(ground.obstacle_field(),ground.arena_rect(),arena.navigation_cell_size)
		var start: int = Time.get_ticks_usec()
		flow.update(ground.player_start())
		print(id, " navigation : ", (Time.get_ticks_usec()-start)/1000.0, " ms, grille ",flow.size)
		ground.free()
	get_tree().quit()
