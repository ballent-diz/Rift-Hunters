extends TestCase
func test_map_routes_clearance_and_scale() -> void:
	var arena: ArenaData = GameDB.arena(&"storm_highlands")
	check(arena != null and arena.unlocked_by_default,"niveau disponible au refuge")
	check_eq(arena.size.x*arena.size.y,GameDB.arena(&"three_rifts").size.x*GameDB.arena(&"three_rifts").size.y*3,"surface triplée")
	var ground := ArenaGround.new()
	ground.setup(arena,7)
	var field: ObstacleField = ground.obstacle_field()
	check(field.distance(ground.player_start()) >= 36,"départ dégagé")
	var flow := FlowField.new()
	flow.setup(field,ground.arena_rect(),arena.navigation_cell_size)
	flow.update(ground.player_start())
	for uv: Vector2 in [Vector2(.3,.25),Vector2(.49,.47),Vector2(.4,.62),Vector2(.52,.80),Vector2(.87,.74)]:
		var point: Vector2 = uv*arena.size-arena.size*.5
		check(field.distance(point)>=16,"passage dégagé " + str(uv))
		check(flow.cost_at(point)<FlowField.UNREACHED,"passage accessible " + str(uv))
	for center: Vector2 in [Vector2(.49,.47),Vector2(.52,.80),Vector2(.87,.74)]:
		for i: int in 24:
			var point: Vector2 = center*arena.size-arena.size*.5+Vector2.from_angle(TAU*i/24)*70
			check(not field.blocks(point,14),"espace pour tourner " + str(center))
	check(field.blocks(Vector2(.86,.18)*arena.size-arena.size*.5,12),"eau du lac bloquée")
	ground.free()

func test_new_bestiaire_spawn_and_boss() -> void:
	var setup := RunSetup.new()
	setup.arena_id = &"storm_highlands"
	setup.starter_id = &"mossback"
	setup.autopilot = true
	var run: RunController = load("res://scenes/run.tscn").instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	check(run.ctx.finale != null and run.ctx.finale.walled(),"place centrale murée (mode failles : test_rift_mode)")
	for id: StringName in [&"heath_runner",&"slate_scarab",&"silver_harpy",&"ash_newt"]:
		var enemy: Enemy = run.ctx.enemies.spawn(GameDB.enemy(id),run.ctx.player.position+Vector2(120,0))
		check(enemy != null and enemy.visual != null,"ennemi animé " + String(id))
	for id: StringName in run.ctx.arena.elite_enemy_ids:
		var elite: Enemy = run.spawner.spawn_elite(id)
		check(elite != null and elite.is_elite,"élite distinct " + String(id))
	run.ctx.time=run.ctx.arena.boss_time
	run.spawner.step(.1)
	check(run.ctx.boss == null,"pas de boss chronométré : il attend la fermeture des failles")
	check_eq(run.ctx.arena.boss_id,&"astravorn","boss propre à la zone")
	RunFixture.dispose(run)
