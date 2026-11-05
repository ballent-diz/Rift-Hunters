extends RefCounted
## Adaptateur generique : conserver l'instance pour pouvoir restaurer le materiau initial.
## Usage dans une branche d'essai : var filter = load(path).new(); filter.apply(ground, "fine")

var saved: Dictionary = {}

func apply(ground: Node2D, preset: String = "fine") -> void:
	if preset == "original":
		restore(ground)
		return
	if not saved.has(ground):
		saved[ground] = [ground.material, ground.texture_filter]
	var shader = Shader.new()
	shader.code = FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("rift_pixel.gdshader"))
	var mat = ShaderMaterial.new()
	mat.shader = shader
	var env = ground.environment
	var count = maxi(1, env.map_tiles.size())
	mat.set_shader_parameter("texture_density", float(env.map_texture.get_width()) / (ground.arena_rect().size.x / count))
	mat.set_shader_parameter("grid_origin", ground.arena_rect().position)
	var bold = preset in ["affirme","graphique"]
	mat.set_shader_parameter("pixel_world_pitch", 1.5 if bold else 0.75)
	mat.set_shader_parameter("color_steps", 11.0 if bold else 22.0)
	mat.set_shader_parameter("chroma_steps", 12.0 if bold else 24.0)
	mat.set_shader_parameter("grouping", 1.0 if bold else 0.4)
	mat.set_shader_parameter("grouping_range", 18.0 if bold else 85.0)
	mat.set_shader_parameter("contrast", 1.025 if bold else 1.025)
	mat.set_shader_parameter("sharpening", 0.1 if bold else 0.2)
	mat.set_shader_parameter("palette_strength", 1.0 if bold else 0.7)
	if preset == "graphique":
		mat.set_shader_parameter("grouping_radius",2.0)
		mat.set_shader_parameter("grouping_range",8.0)
		mat.set_shader_parameter("color_steps",10.0)
		mat.set_shader_parameter("chroma_steps",10.0)
		mat.set_shader_parameter("sharpening",0.0)
	ground.material = mat
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func restore(ground: Node2D) -> void:
	if not saved.has(ground):
		return
	ground.material = saved[ground][0]
	ground.texture_filter = saved[ground][1]
	saved.erase(ground)
