extends TestCase
## Rendu pixel 3D (draft3d/render/, docs/art/RENDU_PIXEL_3D.md) : vue basse résolution à la densité des sprites,
## caméra calée sur la grille de texels, décor en aplats, palette du chapitre, bascule sans toucher au jeu.

var run: DraftRun


func after_each() -> void:
	if run != null:
		run.queue_free()
		run = null
	DraftPixelRender.preferred = true


func _start(pixel: bool) -> void:
	DraftPixelRender.preferred = pixel
	DraftRun.chosen_chapter = 1
	run = (load("res://draft3d/main.tscn") as PackedScene).instantiate()
	host.add_child(run)
	for frame: int in 600:
		if run.state == DraftRun.State.PLAYING:
			break
		await host.get_tree().physics_frame
	run.boss_time = INF
	DraftRun.chosen_chapter = 0


func test_palettes_are_complete() -> void:
	for chapter: int in range(1, 6):
		var palette: DraftPixelPalette = DraftPixelPalette.new()
		check(ResourceLoader.exists(DraftPixelRender.PALETTE_PATH % chapter), "palette du chapitre %d" % chapter)
		palette = DraftPixelRender.load_palette(chapter)
		check(palette.colors.size() >= 12 and palette.colors.size() <= 64, "chapitre %d : 12 à 64 couleurs" % chapter)
		check(palette.bands >= 3 and palette.bands <= 4, "chapitre %d : 3 ou 4 paliers" % chapter)


func test_texel_matches_sprite_pixels() -> void:
	check_near(DraftPixelRender.TEXEL, DraftSpriteView.PIXEL * 0.65, 0.00001, "un texel = un pixel d'art à l'échelle 0,65")


func test_pixel_view_is_snapped() -> void:
	await _start(true)
	var pixel: DraftPixelRender = run.pixel
	check(pixel.enabled, "rendu pixel actif par défaut")
	check(pixel.camera.get_viewport() == pixel.viewport, "la caméra dessine la vue basse résolution")
	check(pixel.viewport.world_3d == run.get_world_3d(), "même monde 3D (physique, navigation)")
	check(pixel.toon_meshes() > 50, "décor en aplats (%d maillages)" % pixel.toon_meshes())
	check(DraftSpriteView.blend_alpha, "sprites dessinés après la palette")
	for step: int in 12:
		pixel.place(Vector3(0.137 * step, 0.0, 28.0 - 0.071 * step), 20.0, DraftRun.CAMERA_OFFSET)
		var basis: Basis = pixel.camera.global_basis
		var across: float = pixel.camera.global_position.dot(basis.x) / pixel.texel_size
		var up: float = pixel.camera.global_position.dot(basis.y) / pixel.texel_size
		check_near(across, roundf(across), 0.002, "caméra sur la grille (horizontal)")
		check_near(up, roundf(up), 0.002, "caméra sur la grille (vertical)")
		check(absf(pixel.remainder.x) <= 0.5001 and absf(pixel.remainder.y) <= 0.5001, "reste sub-pixel ≤ ½ texel")
	check_near(pixel.texel_size, DraftPixelRender.TEXEL, 0.0001, "vue de 20 m : texel du sprite")
	check_eq(pixel.viewport.size.y, pixel.view_texels.y + DraftPixelRender.MARGIN * 2, "marge d'un texel")


func test_toggle_restores_smooth_render() -> void:
	await _start(true)
	var pixel: DraftPixelRender = run.pixel
	var count: int = pixel.toon_meshes()
	check(not pixel.toggle(), "F4 : retour au rendu lisse")
	check(pixel.camera.get_viewport() == run.get_viewport(), "caméra rendue à la fenêtre")
	check_eq(pixel.toon_meshes(), 0, "matériaux d'origine rendus")
	check(not DraftSpriteView.blend_alpha, "sprites en découpe nette comme avant")
	for node: Node in run.level.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface: int in (mesh.mesh.get_surface_count() if mesh.mesh != null else 0):
			check(not (mesh.get_active_material(surface) is ShaderMaterial), "aucun aplat ne reste sur le décor")
	check(pixel.toggle(), "F4 : rendu pixel de nouveau")
	check_eq(pixel.toon_meshes(), count, "mêmes maillages en aplats")


func test_smooth_render_option() -> void:
	await _start(false)
	check(not run.pixel.enabled, "--pixel=0 : rendu d'origine")
	check_eq(run.pixel.toon_meshes(), 0, "aucun matériau changé")
	check(not run.pixel.screen.visible, "aucune image agrandie")


func test_oklab_reference() -> void:
	var white: Vector3 = DraftPixelRender.oklab(Color.WHITE)
	check_near(white.x, 1.0, 0.001, "blanc : L = 1")
	check_near(white.y, 0.0, 0.001, "blanc : a = 0")
	var black: Vector3 = DraftPixelRender.oklab(Color.BLACK)
	check_near(black.x, 0.0, 0.001, "noir : L = 0")
