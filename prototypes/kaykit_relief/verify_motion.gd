extends Node
## Mesure le mouvement réel, l'orientation et le rendu entre pas physiques (lancer à --fixed-fps 120).

var arena: Node3D
var checks: Array[Dictionary] = []
var output := ""

func record(id: String, passed: bool, details: Variant) -> void:
	checks.append({"id": id, "passed": passed, "details": details})
	print("MOTION_CHECK ", id, " ", "PASS" if passed else "FAIL", " ", details)

func wait_physics(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

func place(actor: CharacterBody3D, at: Vector3) -> void:
	actor.auto_direction = Vector3.ZERO
	actor.position = at
	actor.reset_motion()
	await wait_physics(12)

func run(level: Node3D) -> void:
	arena = level
	output = ProjectSettings.globalize_path("res://captures")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	while not arena.navigation_ready:
		await get_tree().physics_frame
	for actor: Node in get_tree().get_nodes_in_group("actors"):
		actor.active = actor.role == "hunter"
	var hunter: CharacterBody3D = arena.hunter
	hunter.automating = true
	await place(hunter, Vector3(0, 0.1, 4))
	var flips := 0
	var flipped: bool = hunter.sprite.flip_h
	for i: int in 60:
		hunter.auto_direction = Vector3(0.025 if i % 2 == 0 else -0.025, 0, -1).normalized()
		await wait_physics(1)
		if flipped != hunter.sprite.flip_h:
			flips += 1
			flipped = hunter.sprite.flip_h
	record("orientation_ignores_horizontal_noise", flips == 0, {"flips_in_one_second": flips})
	await place(hunter, Vector3(0, 0.1, 4))
	hunter.auto_direction = Vector3.LEFT
	await wait_physics(20)
	record("sustained_turn_left", hunter.sprite.flip_h, {"facing_left": hunter.sprite.flip_h})
	hunter.auto_direction = Vector3.RIGHT
	await wait_physics(25)
	record("sustained_turn_right", not hunter.sprite.flip_h, {"facing_left": hunter.sprite.flip_h})
	hunter.auto_direction = Vector3.ZERO
	var release := hunter.global_position
	await wait_physics(12)
	var drift := Vector2(hunter.position.x - release.x, hunter.position.z - release.z).length()
	record("responsive_stop", drift < 0.2 and hunter.velocity.length() < 0.02, {"drift_m": drift})
	await place(hunter, Vector3(0, 0.1, 4))
	hunter.auto_direction = Vector3.RIGHT
	await wait_physics(15)
	var cardinal := Vector2(hunter.velocity.x, hunter.velocity.z).length()
	await place(hunter, Vector3(0, 0.1, 4))
	hunter.auto_direction = Vector3(1, 0, -1).normalized()
	await wait_physics(15)
	var diagonal := Vector2(hunter.velocity.x, hunter.velocity.z).length()
	record("diagonal_keeps_speed", absf(cardinal - diagonal) < 0.03, {"cardinal": cardinal, "diagonal": diagonal})
	# Observer l'image entre les pas physiques, pas seulement calculer une formule d'interpolation.
	await place(hunter, Vector3(0, 0.1, 4))
	hunter.auto_direction = Vector3.FORWARD
	await wait_physics(12)
	var body := hunter.global_position
	var visual: Vector3 = hunter.sprite.global_position
	var intermediate_updates := 0
	for i: int in 120:
		await get_tree().process_frame
		var next_body := hunter.global_position
		var next_visual: Vector3 = hunter.sprite.global_position
		if body.distance_squared_to(next_body) < 0.0000001 and visual.distance_squared_to(next_visual) > 0.0000001:
			intermediate_updates += 1
		body = next_body
		visual = next_visual
	record("render_moves_between_physics_steps", intermediate_updates > 15, {"intermediate_updates": intermediate_updates})
	await place(hunter, Vector3(6, 0.1, 5))
	hunter.auto_direction = Vector3.FORWARD
	await wait_physics(80)
	record("no_walking_in_place_against_cover", hunter.animation_name == "idle", hunter.animation_name)
	await place(hunter, Vector3(-10, 0.1, -0.5))
	var echo: CharacterBody3D = arena.echo
	await place(echo, Vector3(-11.4, 0.1, 5))
	echo.active = true
	await wait_physics(180)
	var previous := echo.global_position
	var settling_distance := 0.0
	var echo_flips := 0
	flipped = echo.sprite.flip_h
	for i: int in 180:
		# Un Chasseur presque immobile ne doit pas faire repartir l'Écho à chaque petite correction.
		hunter.position.x = -10.0 + (0.025 if i % 2 == 0 else -0.025)
		await wait_physics(1)
		settling_distance += previous.distance_to(echo.global_position)
		previous = echo.global_position
		if flipped != echo.sprite.flip_h:
			echo_flips += 1
			flipped = echo.sprite.flip_h
	record("echo_stays_settled_near_target", settling_distance < 0.15 and echo_flips == 0,
		{"distance_during_three_seconds_m": settling_distance, "orientation_changes": echo_flips})
	echo.active = false
	var success := checks.all(func(check: Dictionary) -> bool: return check.passed)
	var report := {"success": success, "checks": checks, "physics_hz": Engine.physics_ticks_per_second,
		"render_test_fps": 120, "engine": Engine.get_version_info().string}
	var file := FileAccess.open(output.path_join("motion_verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if OS.get_cmdline_user_args().has("--capture-motion"):
		await capture_demo()
	print("MOTION_SUCCESS=", success)
	get_tree().quit(0 if success else 1)

func capture_demo() -> void:
	var hunter: CharacterBody3D = arena.hunter
	await place(hunter, Vector3(0, 0.1, 10.5))
	await place(arena.echo, Vector3(-1.4, 0.1, 10.5))
	arena.echo.active = true
	if not arena.follow_camera:
		arena.toggle_follow()
	arena.camera.size = 17
	var waypoints: Array[Vector3] = [Vector3(0, 0, -9), Vector3(-4, 0, -9), Vector3(0, 0, -9)]
	var waypoint := 0
	for i: int in 720:
		var difference := waypoints[waypoint] - hunter.global_position
		difference.y = 0
		if difference.length() < 0.15 and waypoint < waypoints.size() - 1:
			waypoint += 1
		hunter.auto_direction = difference.normalized() if difference.length() >= 0.15 else Vector3.ZERO
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if i % 2 == 0:
			var image := get_viewport().get_texture().get_image()
			image.save_png(output.path_join("smooth_%04d.png" % (i / 2)))
			if i % 120 == 0:
				print("MOTION_CAPTURE ", i / 2)
