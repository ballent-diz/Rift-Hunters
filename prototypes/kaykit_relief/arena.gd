extends Node3D

const ACTOR := preload("res://actor.gd")
const EFFECT := preload("res://pixel_effect.gd")
const SPAWN := Vector3(0, 0.2, 11)
var catalog: Dictionary
var hunter: CharacterBody3D
var echo: CharacterBody3D
var camera: Camera3D
var navigation: NavigationRegion3D
var navigation_ready := false
var follow_camera := false
var blocked_shots := 0
var enemy_hits := 0
var debug_collisions := false
var debug_root: Node3D
var projectiles: Array[Dictionary] = []
var status: Label
var clock := 0.0
var capture_mode := false

func _ready() -> void:
	TranslationServer.set_locale("fr")
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog.json"))
	build_lighting()
	build_environment()
	build_navigation()
	if OS.get_cmdline_user_args().has("--save-level"):
		save_level()
		get_tree().quit()
		return
	hunter = add_actor("hunter", SPAWN)
	echo = add_actor("echo", Vector3(-1.8, 0.2, 10))
	echo.follow_target = hunter
	spawn_enemies()
	build_camera()
	build_hud()
	call_deferred("finish_navigation")
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--verify":
			capture_mode = true
			call_deferred("run_verification")

func build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101222")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b2b9d8")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -35, 0)
	sun.light_color = Color("ffe4bc")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 145, 0)
	fill.light_color = Color("7b7cb5")
	fill.light_energy = 0.16
	add_child(fill)

func module(id: String, at: Vector3, scale_value := Vector3.ONE, yaw := 0.0) -> Node3D:
	var packed := load("res://modules/%s.tscn" % id) as PackedScene
	var instance := packed.instantiate() as Node3D
	navigation.add_child(instance)
	instance.position = at
	instance.scale = scale_value
	instance.rotation.y = deg_to_rad(yaw)
	return instance

func build_environment() -> void:
	if ResourceLoader.exists("res://level.tscn"):
		navigation = load("res://level.tscn").instantiate() as NavigationRegion3D
		add_child(navigation)
	else:
		assemble_environment()
	debug_root = Node3D.new()
	debug_root.name = "CollisionPreview"
	add_child(debug_root)

func assemble_environment() -> void:
	navigation = NavigationRegion3D.new()
	navigation.name = "Level"
	add_child(navigation)
	for x: int in range(-16, 17, 4):
		for z: int in range(-12, 13, 4):
			module("floor_tile_large", Vector3(x, 0, z))
	# Terrasse pleine : sa face avant est réellement bloquante, accès par l'escalier central.
	box_solid("Terrace", Vector3(0, 0.95, -10), Vector3(20, 2.1, 8), Color("555567"))
	for x: int in range(-8, 9, 4):
		for z: int in [-12, -8]:
			module("floor_tile_large", Vector3(x, 2, z))
	module("stairs_wide", Vector3(0, 0, -6), Vector3(1, 0.5, 1.5))
	for x: int in range(-16, 17, 4):
		module("wall_cracked" if x % 8 == 0 else "wall", Vector3(x, 2 if absi(x) < 11 else 0, -14))
	for z: int in range(-12, 13, 4):
		module("wall_broken" if z % 8 == 0 else "wall", Vector3(-18, 0, z), Vector3.ONE, 90)
		module("wall_broken" if z % 8 == 0 else "wall", Vector3(18, 0, z), Vector3.ONE, 90)
	for x: int in [-16, -12, -8, 8, 12, 16]:
		module("wall_broken", Vector3(x, 0, 14), Vector3.ONE, 180)
	# Une limite visible basse clôt les bords restants ; pas de mur invisible au portail sud.
	module("barrier", Vector3(-4, 0, 14))
	module("barrier", Vector3(0, 0, 14))
	module("barrier", Vector3(4, 0, 14))
	module("wall_doorway", Vector3(0, 0, 7.3))
	module("wall_broken", Vector3(-4, 0, 7.3))
	module("wall_broken", Vector3(4, 0, 7.3))
	for p: Vector3 in [Vector3(-6, 0, 2), Vector3(6, 0, 2), Vector3(-6, 0, -2.5), Vector3(6, 0, -2.5)]:
		module("pillar_decorated", p, Vector3.ONE * 0.7)
	for x: int in [-7, 7]:
		module("pillar_decorated", Vector3(x, 2, -10))
		module("banner_red", Vector3(x, 4.3, -9.15), Vector3.ONE * 0.65)
		add_torch(Vector3(x, 2, -8))
	for p: Vector3 in [Vector3(-12, 0, 6), Vector3(12, 0, 6), Vector3(-13, 0, -4), Vector3(13, 0, -4)]:
		module("crates_stacked", p, Vector3.ONE * 0.85)
		module("barrel_large", p + Vector3(1.5, 0, 0.7), Vector3.ONE * 0.85)
	module("chest", Vector3(0, 2, -12), Vector3.ONE * 0.8)
	for p: Vector3 in [Vector3(-3, 0, 7), Vector3(3, 0, 7), Vector3(-10, 0, -5), Vector3(10, 0, -5)]:
		add_torch(p)

func save_level() -> void:
	for child: Node in navigation.get_children():
		child.owner = navigation
		if child.scene_file_path.is_empty():
			for descendant: Node in child.find_children("*", "", true, false):
				descendant.owner = navigation
	var scene := PackedScene.new()
	assert(scene.pack(navigation) == OK)
	assert(ResourceSaver.save(scene, "res://level.tscn") == OK)
	print("EDITABLE_LEVEL_SAVED")

func box_solid(id: String, at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = id
	navigation.add_child(body)
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	body.add_child(mesh)

func add_torch(at: Vector3) -> void:
	module("torch_lit", at, Vector3.ONE * 0.8)
	var light := OmniLight3D.new()
	light.position = at + Vector3.UP * 1.6
	light.light_color = Color("ffac66")
	light.light_energy = 1.6
	light.omni_range = 5
	light.shadow_enabled = false
	navigation.add_child(light)

func build_navigation() -> void:
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.2)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.1)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.6
	mesh.agent_max_climb = 0.3
	mesh.agent_max_slope = 48
	mesh.cell_size = 0.2
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	navigation.navigation_mesh = mesh

func finish_navigation() -> void:
	navigation.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation_ready = true
	print("NAVIGATION_READY polygons=", navigation.navigation_mesh.get_polygon_count())

func add_actor(role: String, at: Vector3) -> CharacterBody3D:
	var actor := CharacterBody3D.new()
	actor.set_script(ACTOR)
	actor.role = role
	actor.art = catalog.actors[role]
	actor.position = at
	actor.name = role.capitalize()
	add_child(actor)
	return actor

func spawn_enemies() -> void:
	for p: Vector3 in [Vector3(-9, 0.1, 4), Vector3(9, 0.1, 4), Vector3(-10, 0.1, -3),
		Vector3(10, 0.1, -3), Vector3(-3, 2.1, -11), Vector3(3, 2.1, -11)]:
		var enemy := add_actor("enemy", p)
		enemy.follow_target = hunter

func build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.5
	camera.far = 150
	add_child(camera)
	set_overview()
	camera.current = true

func set_overview() -> void:
	follow_camera = false
	camera.position = Vector3(0, 32, 29)
	camera.look_at(Vector3(0, 0.5, -1.5))
	camera.size = 25.5

func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(hunter):
		if follow_camera:
			camera.position = camera.position.lerp(hunter.position + Vector3(0, 18, 17), 1 - exp(-5 * delta))
		status.text = tr("lab_status") % [maxf(0, hunter.position.y), blocked_shots, enemy_hits]
	update_projectiles(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(11, camera.size - 1.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(36, camera.size + 1.2)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R: get_tree().reload_current_scene()
			KEY_C: toggle_follow()
			KEY_V: toggle_collision_preview()
			KEY_F2:
				TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("fr") else "fr")
			KEY_ESCAPE: get_tree().quit()

func toggle_follow() -> void:
	if follow_camera:
		set_overview()
	else:
		follow_camera = true
		camera.size = 16

func shoot(direction_override := Vector3.ZERO) -> void:
	var origin := hunter.position + Vector3.UP * 0.8
	var direction := direction_override
	if direction == Vector3.ZERO:
		var mouse := get_viewport().get_mouse_position()
		var ray_origin := camera.project_ray_origin(mouse)
		var ray_direction := camera.project_ray_normal(mouse)
		var plane := Plane(Vector3.UP, origin.y)
		var target: Variant = plane.intersects_ray(ray_origin, ray_direction)
		if target == null:
			return
		direction = origin.direction_to(target)
		direction.y = 0
		direction = direction.normalized()
	var visual := spawn_fx("fireball", origin)
	visual.loop = true
	visual.flip_h = direction.x < 0
	projectiles.append({"at": origin, "direction": direction, "life": 1.4, "visual": visual})

func update_projectiles(delta: float) -> void:
	for i: int in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var next: Vector3 = shot.at + shot.direction * 18.0 * delta
		var query := PhysicsRayQueryParameters3D.create(shot.at, next, 1 | 2)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		shot.life -= delta
		if not hit.is_empty():
			spawn_fx("hit", hit.position)
			if hit.collider.collision_layer & 2:
				hit.collider.hit()
			else:
				blocked_shots += 1
		if not hit.is_empty() or shot.life <= 0:
			if is_instance_valid(shot.visual):
				shot.visual.queue_free()
			projectiles.remove_at(i)
		else:
			shot.at = next
			shot.visual.position = next

func spawn_fx(id: String, at: Vector3) -> Sprite3D:
	var effect := Sprite3D.new()
	effect.set_script(EFFECT)
	effect.art = catalog.effects[id]
	effect.position = at
	add_child(effect)
	return effect

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := PanelContainer.new()
	top.position = Vector2(28, 24)
	top.add_theme_stylebox_override("panel", panel_style())
	layer.add_child(top)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	top.add_child(column)
	var eyebrow := label("lab_subtitle", 12, Color("b9aed6"))
	column.add_child(eyebrow)
	column.add_child(label("lab_title", 26, Color("f0e8d7")))
	column.add_child(label("lab_note", 14, Color("c7c8d1")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var overview := Button.new()
	overview.text = "lab_photo"
	overview.pressed.connect(set_overview)
	row.add_child(overview)
	var follow := Button.new()
	follow.text = "lab_follow"
	follow.pressed.connect(toggle_follow)
	row.add_child(follow)
	var reset := Button.new()
	reset.text = "lab_reset"
	reset.pressed.connect(func() -> void: get_tree().reload_current_scene())
	row.add_child(reset)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_top = -118
	bottom.offset_bottom = -22
	bottom.add_theme_stylebox_override("panel", panel_style())
	layer.add_child(bottom)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	bottom.add_child(text)
	text.add_child(label("lab_controls", 15, Color("eee8dc")))
	text.add_child(label("lab_controls_more", 13, Color("bfc1cf")))
	status = label("", 13, Color("c3aadf"))
	text.add_child(status)
	var scope := label("lab_scope", 12, Color("bfc1cf"))
	scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scope.position = Vector2(870, 27)
	scope.size.x = 700
	layer.add_child(scope)

func label(key: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = key
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.07, 0.9)
	style.border_color = Color("685572")
	style.border_width_left = 2
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func toggle_collision_preview() -> void:
	debug_collisions = not debug_collisions
	if debug_root.get_child_count() == 0:
		for node: Node in navigation.find_children("*", "CollisionShape3D", true, false):
			var collision := node as CollisionShape3D
			var mesh := MeshInstance3D.new()
			mesh.mesh = collision.shape.get_debug_mesh()
			debug_root.add_child(mesh)
			mesh.global_transform = collision.global_transform
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.no_depth_test = true
			material.albedo_color = Color("66f1c5")
			mesh.material_override = material
	debug_root.visible = debug_collisions

func run_verification() -> void:
	var verifier = load("res://verify.gd").new()
	add_child(verifier)
	verifier.run(self)
