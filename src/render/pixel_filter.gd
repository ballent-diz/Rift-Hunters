class_name PixelFilter
extends RefCounted
## Filtre pixel du décor dessiné (cartes de type map d'ArenaGround) : grille de pixels ancrée au monde,
## regroupement local des couleurs, contraste et quantification luminance/chrominance. Ne touche ni aux
## images sources, ni aux collisions, personnages, effets ou UI. Les sols procéduraux ne sont pas filtrés.

const SHADER: Shader = preload("res://assets/shaders/pixel_filter.gdshader")
const OFF := "off"
const FINE := "fine"
## Préréglage interne (non proposé dans les options) : essai plus marqué que « fin ».
const BOLD := "bold"
const GRAPHIC := "graphic"
## Ordre du réglage dans les options (cycle du bouton).
const CHOICES: Array[String] = [OFF, FINE, GRAPHIC]
const PRESETS: Array[String] = [OFF, FINE, BOLD, GRAPHIC]


static func is_valid(preset: String) -> bool:
	return PRESETS.has(preset)


static func next_choice(preset: String) -> String:
	return CHOICES[(CHOICES.find(preset) + 1) % CHOICES.size()]


## Le décor peut-il être filtré : une carte dessinée valide (jamais un sol procédural).
static func supports(ground: ArenaGround) -> bool:
	return ground != null and ground.environment != null and ground.environment.is_map() \
			and ground.arena != null


## Matériau du préréglage pour ce sol (null pour « off » ou un décor non filtrable). La densité de texture
## vient de la taille du monde (decor_scale compris) et la grille part du coin de l'arène, comme les tuiles.
static func build_material(ground: ArenaGround, preset: String) -> ShaderMaterial:
	if preset == OFF or not is_valid(preset) or not supports(ground):
		return null
	var env: EnvironmentSet = ground.environment
	var rect: Rect2 = ground.arena_rect()
	var tile_width: float = rect.size.x / maxi(1, env.map_tiles.size())
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("texture_density", float(env.map_texture.get_width()) / tile_width)
	mat.set_shader_parameter("grid_origin", rect.position)
	var bold: bool = preset != FINE
	mat.set_shader_parameter("pixel_world_pitch", 1.5 if bold else 0.75)
	mat.set_shader_parameter("color_steps", 11.0 if bold else 22.0)
	mat.set_shader_parameter("chroma_steps", 12.0 if bold else 24.0)
	mat.set_shader_parameter("grouping", 1.0 if bold else 0.4)
	mat.set_shader_parameter("grouping_range", 18.0 if bold else 85.0)
	mat.set_shader_parameter("contrast", 1.025)
	mat.set_shader_parameter("sharpening", 0.1 if bold else 0.2)
	mat.set_shader_parameter("palette_strength", 1.0 if bold else 0.7)
	if preset == GRAPHIC:
		mat.set_shader_parameter("grouping_radius", 2.0)
		mat.set_shader_parameter("grouping_range", 8.0)
		mat.set_shader_parameter("color_steps", 10.0)
		mat.set_shader_parameter("chroma_steps", 10.0)
		mat.set_shader_parameter("sharpening", 0.0)
	return mat
