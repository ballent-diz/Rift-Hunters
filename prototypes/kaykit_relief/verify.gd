extends Node
## Exercices sur les vrais CharacterBody3D, collisions et NavigationServer de l'essai.

var checks: Array[Dictionary] = []
var arena: Node3D
var output := ""

func record(id: String, passed: bool, details: Variant) -> void:
	checks.append({"id": id, "passed": passed, "details": details})
	print("CHECK ", id, " ", "PASS" if passed else "FAIL", " ", details)

func wait_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame

func move_actor(actor: CharacterBody3D, direction: Vector3, frames: int) -> void:
	actor.automating = true
	actor.auto_direction = direction
	await wait_frames(frames)
	actor.auto_direction = Vector3.ZERO
	await wait_frames(3)

func place(actor: CharacterBody3D, at: Vector3) -> void:
	actor.position = at
	actor.velocity = Vector3.ZERO
	actor.auto_direction = Vector3.ZERO
	await wait_frames(20)

func capture(id: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output.path_join(id + ".png"))
	print("CAPTURE ", id, " ", error)

func run(level: Node3D) -> void:
	arena = level
	output = ProjectSettings.globalize_path("res://captures")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	while not arena.navigation_ready:
		await get_tree().physics_frame
	await wait_frames(45)
	for actor: Node in get_tree().get_nodes_in_group("actors"):
		if actor.role != "hunter":
			actor.active = false
	var hunter: CharacterBody3D = arena.hunter
	hunter.automating = true
	var map: RID = arena.navigation.get_navigation_map()
	var path := NavigationServer3D.map_get_path(map, Vector3(0, 0, 5), Vector3(0, 2, -10), true)
	record("navigation_terrace", path.size() >= 2, {"points": path.size()})
	await place(hunter, Vector3(0, 0.2, 11))
	await move_actor(hunter, Vector3.FORWARD, 60)
	record("archway_passable", hunter.position.z < 7.0, str(hunter.position))
	await place(hunter, Vector3(0, 0.2, 3))
	await move_actor(hunter, Vector3.FORWARD, 145)
	record("stairs_ascent", hunter.position.y > 1.8 and hunter.position.z < -7, str(hunter.position))
	arena.echo.position = Vector3(-1.7, 2.05, -8.3)
	arena.camera.position = Vector3(0, 22, 17)
	arena.camera.look_at(Vector3(0, 1.5, -7))
	arena.camera.size = 16
	await capture("02_escalier_terrasse")
	await move_actor(hunter, Vector3.BACK, 145)
	record("stairs_descent", hunter.position.y < 0.2 and hunter.position.z > 2, str(hunter.position))
	await place(hunter, Vector3(6, 0.2, 5))
	await move_actor(hunter, Vector3.FORWARD, 70)
	record("pillar_blocks_movement", hunter.position.z > 2.4 and hunter.position.z < 4.5, str(hunter.position))
	await move_actor(hunter, Vector3.RIGHT, 30)
	await move_actor(hunter, Vector3.FORWARD, 62)
	record("pillar_can_be_bypassed", hunter.position.z < 0 and hunter.position.x > 8, str(hunter.position))
	await place(hunter, Vector3(6, 0.2, 5))
	var before: int = arena.blocked_shots
	arena.shoot(Vector3.FORWARD)
	await wait_frames(35)
	record("projectile_stops_on_cover", arena.blocked_shots > before, arena.blocked_shots)
	var opening := PhysicsRayQueryParameters3D.create(Vector3(0, 0.8, 10), Vector3(0, 0.8, 4), 1)
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(opening)
	record("projectile_passes_archway", hit.is_empty(), str(hit.get("position", "clear")))
	await place(hunter, Vector3(-10, 0.2, 5))
	var target: CharacterBody3D = get_tree().get_nodes_in_group("enemies")[0]
	target.position = Vector3(-10, 0.01, 1)
	var hits_before: int = arena.enemy_hits
	arena.shoot(Vector3.FORWARD)
	await wait_frames(25)
	record("projectile_hits_enemy", arena.enemy_hits > hits_before, arena.enemy_hits)
	await place(hunter, Vector3(8, 0.2, -3.5))
	await move_actor(hunter, Vector3.FORWARD, 55)
	record("terrace_front_is_solid", hunter.position.z > -6 and hunter.position.y < 0.2, str(hunter.position))
	# L'Écho doit trouver puis DESCENDRE l'escalier par la navigation 3D.
	await place(hunter, Vector3(0, 0.2, 4))
	arena.echo.position = Vector3(0, 2.1, -10)
	arena.echo.velocity = Vector3.ZERO
	arena.echo.active = true
	arena.echo.nav.target_position = hunter.position + Vector3(-1.4, 0, 1.5)
	await wait_frames(280)
	record("echo_uses_stairs", arena.echo.position.y < 0.2 and arena.echo.position.z > 2, str(arena.echo.position))
	arena.echo.active = false
	await place(hunter, Vector3(-5.8, 0.2, 0.4))
	arena.echo.position = Vector3(-8, 0.05, 1)
	arena.camera.position = Vector3(-5, 15, 17)
	arena.camera.look_at(Vector3(-5, 0.8, 1))
	arena.camera.size = 13
	await capture("03_abris_profondeur")
	await place(hunter, Vector3(0, 0.2, 11))
	arena.echo.position = Vector3(-1.8, 0.1, 10)
	arena.set_overview()
	await capture("01_vue_ensemble")
	arena.toggle_collision_preview()
	await capture("04_collisions")
	arena.toggle_collision_preview()
	TranslationServer.set_locale("en")
	await capture("05_english")
	TranslationServer.set_locale("fr")
	# Petite séquence réelle de déplacement pour le GIF : portail puis escalier.
	arena.camera.position = Vector3(0, 24, 23)
	arena.camera.look_at(Vector3(0, 1, -2))
	arena.camera.size = 22
	arena.echo.position = Vector3(-1.4, 0.2, 10)
	arena.echo.active = true
	hunter.auto_direction = Vector3.FORWARD
	for i: int in 48:
		await wait_frames(5)
		await capture("motion_%03d" % i)
	hunter.auto_direction = Vector3.ZERO
	var success := checks.all(func(check: Dictionary) -> bool: return check.passed)
	var report := {"success": success, "checks": checks, "engine": Engine.get_version_info().string,
		"scope": "Prototype indépendant : contrôleur/combat simplifiés, sans migration de la campagne."}
	var file := FileAccess.open(output.path_join("verification.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VERIFICATION_SUCCESS=", success)
	# Libérer les maillages de visualisation avant l'arrêt du pilote GLES3 de Godot 4.3.
	var tree := get_tree()
	reparent(tree.root)
	arena.queue_free()
	arena = null
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.quit(0 if success else 1)
