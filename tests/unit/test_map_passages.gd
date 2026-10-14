extends TestCase
## Régressions observées en jeu : escaliers et place de basalte, avec gabarit d'une élite.
func test_visible_stairs_and_basalt_are_reachable() -> void:
	_check_routes(&"storm_highlands", [
		[Vector2(.403,.737),Vector2(.407,.755),Vector2(.415,.785),Vector2(.45,.8)],
		[Vector2(.567,.725),Vector2(.563,.747),Vector2(.56,.77),Vector2(.55,.796)],
		[Vector2(.376,.865),Vector2(.382,.846),Vector2(.386,.827),Vector2(.428,.809)],
		[Vector2(.81,.493),Vector2(.851,.465),Vector2(.888,.437)],
		[Vector2(.18,.575),Vector2(.20,.54),Vector2(.28,.505)],
		[Vector2(.22,.70),Vector2(.28,.743),Vector2(.35,.74)],
	])
	_check_routes(&"three_rifts", [
		[Vector2(.046,.101),Vector2(.052,.137),Vector2(.062,.177),Vector2(.08,.215)],
		[Vector2(.781,.325),Vector2(.795,.38),Vector2(.812,.425),Vector2(.84,.48)],
		[Vector2(.77,.76),Vector2(.792,.723),Vector2(.805,.68),Vector2(.819,.64),Vector2(.848,.595)],
	])

func _check_routes(id: StringName, routes: Array) -> void:
	var arena: ArenaData = GameDB.arena(id)
	var ground := ArenaGround.new()
	ground.setup(arena,7)
	var field: ObstacleField = ground.obstacle_field()
	var flow := FlowField.new()
	flow.setup(field,ground.arena_rect(),arena.navigation_cell_size)
	flow.update(ground.player_start())
	for route: Array in routes:
		for segment: int in route.size()-1:
			var a: Vector2 = route[segment]*arena.size-arena.size*.5
			var b: Vector2 = route[segment+1]*arena.size-arena.size*.5
			for index: int in 40:
				var point: Vector2 = a.lerp(b,index/39.0)
				check(field.push_out(point,24).distance_to(point)<.1,"passage libre " + String(id) + " " + str(route))
				var cell: Vector2i = flow._nearest_walkable(flow.cell_of(point))
				check(flow.cost_at(flow.cell_center(cell))<FlowField.UNREACHED,"passage relié au départ " + String(id) + " " + str(route))
	ground.free()

func test_basalt_has_turning_room_and_lava_stays_blocked() -> void:
	var arena: ArenaData = GameDB.arena(&"storm_highlands")
	var ground := ArenaGround.new()
	ground.setup(arena,7)
	var field: ObstacleField = ground.obstacle_field()
	var center: Vector2 = Vector2(.18,.65)*arena.size-arena.size*.5
	for index: int in 40:
		var point: Vector2 = center+Vector2.from_angle(TAU*index/40)*160
		check(not field.blocks(point,24),"tourner sur le basalte avec une élite")
	check(field.blocks(Vector2(.035,.67)*arena.size-arena.size*.5,14),"lave périphérique infranchissable")
	ground.free()
