extends SceneTree
## Contrôle de rendu des assets livrés, sans partie ni déclencheur de gameplay.
## godot --path . --resolution 800x600 --script res://tools/art/preview_v2_delivery.gd

const EFFECTS := {
	"combo_prismatic_execution": 2.0, "combo_prismatic_deluge": 3.0, "combo_gravity_blade": 6.0,
	"combo_counter_rift": 3.0, "combo_dimensional_hunt": 2.0, "combo_tracker_rupture": 2.4,
	"combo_spectral_rebound": 3.0, "combo_shattering_bastion": 6.0, "combo_avenging_aegis": 4.0,
	"combo_still_storm": 4.0, "combo_rift_prison": 6.0, "combo_prismatic_convergence": 4.0,
	"passive_dash_blade": 1.5, "passive_void_wake": 1.5, "passive_counter_cut": 2.2,
}
const OUT := "res://docs/previews/couverture-vfx/rendu"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	root.size = Vector2i(800, 600)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("11131c")
	stage.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	stage.add_child(camera)
	camera.position = Vector3(0, 9, 9)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.current = true
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("252735")
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	for x: int in range(-7, 8):
		for z: int in range(-7, 8):
			if (x + z) % 2 != 0:
				continue
			var tile := MeshInstance3D.new()
			var tile_mesh := PlaneMesh.new()
			tile_mesh.size = Vector2.ONE
			tile.mesh = tile_mesh
			tile.position = Vector3(x, 0.001, z)
			var tile_mat := material.duplicate() as StandardMaterial3D
			tile_mat.albedo_color = Color("2d3040")
			tile.material_override = tile_mat
			stage.add_child(tile)
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 18)
	root.add_child(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for id: String in EFFECTS:
		var effect := StringName(id)
		var data: Dictionary = DraftPixelFx.sheet(effect, DraftPixelFx.DEFAULT_FAMILY)
		var node: DraftPixelFx = DraftPixelFx.play(stage, effect, DraftPixelFx.DEFAULT_FAMILY,
			Vector3(0, 1.5, 0), DraftPixelFx.size_for(effect, EFFECTS[id]), true)
		if node == null:
			push_error("Asset absent : " + id)
			quit(1)
			return
		node.set_process(false)
		node.render_priority = DraftPixelFx.UNDER_TELEGRAPHS
		var rects: Array[Rect2] = data["rects"]
		var peak: int = maxi(1, int(rects.size() * 0.45))
		node._clock = peak / float(data["fps"])
		node._process(0.0)
		label.text = "%s | image %d | largeur %.1f m" % [id, peak, EFFECTS[id]]
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var error: Error = image.save_png(OUT.path_join(id + ".png"))
		print("CAPTURE ", id, " ", error)
		node.queue_free()
		await process_frame
	quit()
