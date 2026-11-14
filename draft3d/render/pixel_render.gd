class_name DraftPixelRender
extends Node
## Rendu pixel 3D (docs/art/RENDU_PIXEL_3D.md) : la 3D elle-même dessinée en pixel art, sans toucher aux modules,
## aux collisions ni au jeu.
## - La scène 3D est dessinée dans une vue basse résolution (SubViewport) où un texel couvre `TEXEL` mètres, la
##   taille d'un pixel d'art des sprites (échelle 0,65 du manifeste) : décor et sprites ont la même densité.
## - La caméra est calée sur la grille de texels (aucun scintillement du décor) ; l'image agrandie est décalée de la
##   fraction de texel restante (défilement fluide) avec un échantillonnage net à toute échelle.
## - Décor en aplats (toon.gdshader), puis contours, tramage et palette du chapitre (pixel_post.gdshader) ; sprites,
##   effets, cristaux et interface sont dessinés après, intacts. Le moteur de compatibilité n'offrant pas la
##   profondeur aux shaders, une vue jumelle dessine la profondeur du décor seul (copies des maillages, statiques).
## Réglage : F4 en partie, `--pixel=0` au lancement ; le choix est gardé d'une partie à l'autre.

## Mètres par texel : un pixel d'art d'un sprite d'échelle 0,65 (Chasseur, monstres de la campagne).
const TEXEL := DraftSpriteView.PIXEL * 0.65
## Texels ajoutés autour de la vue pour le décalage sub-pixel.
const MARGIN := 1
## Soleil du rendu pixel : lumière haut-gauche de la bible graphique, un peu de face pour éclairer les façades.
const SUN_ROTATION := Vector3(-52, -60, 0)
const PALETTE_PATH := "res://draft3d/render/palettes/chapter_%d.tres"

## Choix gardé d'une partie à l'autre (R rejoue avec le même rendu).
static var preferred: bool = true
## Essai de pixels plus gros (`--pixel-scale=2`) : un texel couvre plusieurs pixels d'art, les sprites perdent du
## détail. 1 : même densité que les sprites (réglage retenu).
static var texel_scale: int = 1

var enabled: bool = false
var palette: DraftPixelPalette
var camera: Camera3D
var viewport: SubViewport
var screen: TextureRect
## Mètres par texel de l'image courante (TEXEL, sauf vue trop large pour l'écran) et texels visibles.
var texel_size: float = TEXEL
var view_texels := Vector2i(16, 16)
## Fraction de texel retirée par le calage de la caméra (x vers la droite, y vers le bas).
var remainder := Vector2.ZERO

var _host: Node3D
var _level: Node
var _sun: DirectionalLight3D
var _sun_rotation := Vector3.ZERO
var _environment: Environment
var _tonemap: Environment.ToneMapper = Environment.TONE_MAPPER_FILMIC
var _layer: CanvasLayer
var _post: MeshInstance3D
var _post_material: ShaderMaterial
var _depth_view: SubViewport
var _depth_camera: Camera3D
var _depth_root: Node3D
var _display: ShaderMaterial
var _toon_shader: Shader = preload("res://draft3d/render/toon.gdshader")
var _toon_cache: Dictionary = {}
## Matériaux d'origine des maillages du décor : [MeshInstance3D, material_override, [matériaux par surface]].
var _originals: Array = []


## `host` : nœud qui porte le monde 3D (la partie) ; `p_camera` : sa caméra orthographique.
func setup(host: Node3D, p_camera: Camera3D, chapter: int) -> void:
	_host = host
	camera = p_camera
	palette = load_palette(chapter)
	_build_depth_view()
	viewport = SubViewport.new()
	viewport.name = "PixelView"
	viewport.world_3d = host.get_world_3d()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.audio_listener_enable_3d = true
	add_child(viewport)
	_layer = CanvasLayer.new()
	_layer.layer = -1
	add_child(_layer)
	screen = TextureRect.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	screen.texture = viewport.get_texture()
	_display = ShaderMaterial.new()
	_display.shader = preload("res://draft3d/render/pixel_display.gdshader")
	screen.material = _display
	screen.visible = false
	_layer.add_child(screen)
	_post = MeshInstance3D.new()
	_post.name = "PixelPost"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_post.mesh = quad
	_post.extra_cull_margin = 16384.0
	_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_post_material = ShaderMaterial.new()
	_post_material.shader = preload("res://draft3d/render/pixel_post.gdshader")
	# Première chose dessinée après le décor opaque : sprites, effets et cristaux passent ensuite, intacts.
	_post_material.render_priority = Material.RENDER_PRIORITY_MIN
	_post_material.set_shader_parameter("depth_tex", _depth_view.get_texture())
	# Profondeur codée de near à far (pixel_depth.gdshader).
	_post_material.set_shader_parameter("depth_range", camera.far - camera.near)
	_post.material_override = _post_material
	_post.position = Vector3(0, 0, -1)
	_post.visible = false
	camera.add_child(_post)
	apply_palette()


static func load_palette(chapter: int) -> DraftPixelPalette:
	var path: String = PALETTE_PATH % chapter
	if ResourceLoader.exists(path):
		return load(path) as DraftPixelPalette
	return DraftPixelPalette.new()


## La carte est construite : son décor et son soleil passent au rendu pixel si le réglage est actif.
func attach_level(level: Node, sun: DirectionalLight3D) -> void:
	_level = level
	_sun = sun
	_sun_rotation = sun.rotation_degrees
	_environment = _host.get_world_3d().environment
	if _environment != null:
		_tonemap = _environment.tonemap_mode
	set_enabled(preferred)


func toggle() -> bool:
	preferred = not enabled
	set_enabled(preferred)
	return enabled


func set_enabled(on: bool) -> void:
	DraftSpriteView.blend_alpha = on
	for node: Node in get_tree().get_nodes_in_group(DraftSpriteView.GROUP):
		(node as DraftSpriteView).refresh_alpha()
	if on == enabled and (not on or _originals.size() > 0):
		return
	enabled = on
	var global: Transform3D = camera.global_transform
	camera.get_parent().remove_child(camera)
	if on:
		viewport.add_child(camera)
	else:
		_host.add_child(camera)
	camera.global_transform = global
	camera.current = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_depth_view.render_target_update_mode = viewport.render_target_update_mode
	screen.visible = on
	_post.visible = on
	if _sun != null:
		_sun.rotation_degrees = SUN_ROTATION if on else _sun_rotation
	# Tonemap linéaire : la passe de palette fixe les couleurs finales du décor (un filmic les délaverait une seconde
	# fois) et les sprites s'affichent avec les couleurs exactes de leurs feuilles.
	if _environment != null:
		_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR if on else _tonemap
	if _level != null:
		if on:
			_swap_materials()
			_copy_depth_meshes()
		else:
			_restore_materials()
			for child: Node in _depth_root.get_children():
				child.queue_free()


## Place la caméra (vue de `view_size` mètres de haut centrée sur `focus` + `offset`) ; appelée à chaque image.
func place(focus: Vector3, view_size: float, offset: Vector3) -> void:
	if not enabled:
		camera.size = view_size
		camera.position = focus + offset
		return
	var window := Vector2(get_window().size)
	if DisplayServer.get_name() == "headless" or window.y < 200.0:
		window = Vector2(1920, 1080)
	var rows: int = clampi(roundi(view_size / (TEXEL * texel_scale)), 16, int(window.y))
	var cols: int = maxi(roundi(float(rows) * window.x / window.y), 16)
	view_texels = Vector2i(cols, rows)
	texel_size = view_size / float(rows)
	var size := Vector2i(cols + MARGIN * 2, rows + MARGIN * 2)
	if viewport.size != size:
		viewport.size = size
		_depth_view.size = size
	camera.size = texel_size * float(size.y)
	var target: Vector3 = focus + offset
	var basis: Basis = camera.global_basis
	var across: float = target.dot(basis.x) / texel_size
	var up: float = target.dot(basis.y) / texel_size
	target += basis.x * (roundf(across) - across) * texel_size + basis.y * (roundf(up) - up) * texel_size
	camera.global_position = target
	_depth_camera.global_transform = camera.global_transform
	_depth_camera.size = camera.size
	remainder = Vector2(across - roundf(across), roundf(up) - up)
	_display.set_shader_parameter("texture_texels", Vector2(size))
	_display.set_shader_parameter("view_texels", Vector2(view_texels))
	_display.set_shader_parameter("origin", Vector2(MARGIN, MARGIN) + remainder)


## Envoie la palette (et ses réglages) aux shaders : à rappeler après une retouche de la ressource.
func apply_palette() -> void:
	var lab := PackedVector3Array()
	for color: Color in palette.colors:
		if lab.size() < 64:
			lab.append(oklab(color))
	var count: int = lab.size()
	lab.resize(64)
	_post_material.set_shader_parameter("palette_lab", lab)
	_post_material.set_shader_parameter("palette_size", count)
	_post_material.set_shader_parameter("outline_color", palette.outline)
	_post_material.set_shader_parameter("rim_color", palette.rim)
	_post_material.set_shader_parameter("rim_strength", palette.rim_strength)
	_post_material.set_shader_parameter("lit_outline", palette.lit_outline)
	_post_material.set_shader_parameter("crease_dark", palette.crease_dark)
	_post_material.set_shader_parameter("crease_depth", palette.crease_depth)
	_post_material.set_shader_parameter("edge_light", palette.edge_light)
	_post_material.set_shader_parameter("dither", palette.palette_dither)
	_post_material.set_shader_parameter("exposure", palette.exposure)
	for material: ShaderMaterial in _toon_cache.values():
		_tune_toon(material)


## Couleur sRVB → OKLab (même calcul que pixel_post.gdshader).
static func oklab(color: Color) -> Vector3:
	var c := Vector3(color.srgb_to_linear().r, color.srgb_to_linear().g, color.srgb_to_linear().b)
	var l: float = pow(0.4122214708 * c.x + 0.5363325363 * c.y + 0.0514459929 * c.z, 1.0 / 3.0)
	var m: float = pow(0.2119034982 * c.x + 0.6806995451 * c.y + 0.1073969566 * c.z, 1.0 / 3.0)
	var s: float = pow(0.0883024619 * c.x + 0.2817188376 * c.y + 0.6299787005 * c.z, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


## Nombre de maillages du décor passés en aplats (vérifications).
func toon_meshes() -> int:
	return _originals.size()


## Vue jumelle : même cadrage, même taille, monde à part ne contenant que les copies du décor.
func _build_depth_view() -> void:
	_depth_view = SubViewport.new()
	_depth_view.name = "PixelDepth"
	_depth_view.own_world_3d = true
	_depth_view.world_3d = World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.WHITE
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_depth_view.world_3d.environment = environment
	_depth_view.msaa_3d = Viewport.MSAA_DISABLED
	_depth_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_depth_view)
	_depth_camera = Camera3D.new()
	_depth_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_depth_camera.far = camera.far
	_depth_camera.near = camera.near
	_depth_view.add_child(_depth_camera)
	_depth_camera.current = true
	_depth_root = Node3D.new()
	_depth_view.add_child(_depth_root)


## Copies statiques des maillages du décor (mêmes transformations) avec le matériau de profondeur.
func _copy_depth_meshes() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://draft3d/render/pixel_depth.gdshader")
	for node: Node in _level.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		if source.mesh == null or not source.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.material_override = material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_depth_root.add_child(copy)
		copy.global_transform = source.global_transform


## Nombre de copies dans la vue de profondeur (vérifications).
func depth_meshes() -> int:
	return _depth_root.get_child_count()


func _swap_materials() -> void:
	_originals.clear()
	for node: Node in _level.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var surfaces: Array = []
		var changed: bool = false
		var toon: Array[Material] = []
		for surface: int in mesh.mesh.get_surface_count():
			surfaces.append(mesh.get_surface_override_material(surface))
			var source: Material = mesh.get_active_material(surface)
			var replacement: Material = _toon_for(source)
			toon.append(replacement if replacement != null else source)
			changed = changed or replacement != null
		if not changed:
			continue
		_originals.append([mesh, mesh.material_override, surfaces])
		mesh.material_override = null
		for surface: int in toon.size():
			mesh.set_surface_override_material(surface, toon[surface])


func _restore_materials() -> void:
	for saved: Array in _originals:
		var mesh: MeshInstance3D = saved[0]
		if not is_instance_valid(mesh):
			continue
		var surfaces: Array = saved[2]
		for surface: int in surfaces.size():
			mesh.set_surface_override_material(surface, surfaces[surface])
		mesh.material_override = saved[1]
	_originals.clear()


## Équivalent en aplats d'un matériau standard opaque et éclairé ; null s'il doit rester tel quel (eau, lueurs).
func _toon_for(source: Material) -> Material:
	var standard := source as BaseMaterial3D
	if standard == null or standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or standard.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return null
	if _toon_cache.has(standard):
		return _toon_cache[standard]
	var toon := ShaderMaterial.new()
	toon.shader = _toon_shader
	toon.set_shader_parameter("albedo_color", standard.albedo_color)
	var texture: Texture2D = standard.albedo_texture
	if texture != null and palette.textures.has(texture.resource_path):
		texture = palette.textures[texture.resource_path]
	toon.set_shader_parameter("use_texture", texture != null)
	toon.set_shader_parameter("albedo_texture", texture)
	toon.set_shader_parameter("uv_scale", standard.uv1_scale)
	toon.set_shader_parameter("uv_offset", standard.uv1_offset)
	toon.set_shader_parameter("use_vertex_color", standard.vertex_color_use_as_albedo)
	if standard.emission_enabled:
		toon.set_shader_parameter("emission_color", standard.emission)
		toon.set_shader_parameter("emission_energy", standard.emission_energy_multiplier)
	_tune_toon(toon)
	_toon_cache[standard] = toon
	return toon


func _tune_toon(toon: ShaderMaterial) -> void:
	toon.set_shader_parameter("bands", palette.bands)
	toon.set_shader_parameter("dither", palette.band_dither)
	toon.set_shader_parameter("shadow_tint", palette.shadow_tint)
	toon.set_shader_parameter("light_tint", palette.light_tint)
