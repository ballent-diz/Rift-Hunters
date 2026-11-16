class_name DraftMarshWater
extends Node
## Matériaux de l'eau et de la vase mouillée du Marais des Marées (carte 8), et leur suivi de la marée : la hauteur de
## l'eau passe au shader chaque image ; une levée basse reste détrempée WET_TIME secondes après le retrait de l'eau.
## Textures peintes : draft3d/marsh/README.md.

const FOLDER := "res://draft3d/marsh/"
const RIPPLE_FRAMES := 8
const FOAM_FRAMES := 6
## Durée du séchage d'une levée basse après le retrait de l'eau (s).
const WET_TIME := 10.0

var water_material: ShaderMaterial
var wet_material: ShaderMaterial
var wetness: float = 0.0
var _water: Node3D
var _low_top: float = 0.0
var _dry_for: float = WET_TIME


## `water` : la surface (sa hauteur suit la marée) ; `low_top` : dessus des levées basses.
func setup(water: MeshInstance3D, low_top: float, shore_map: String, shore_rect: Rect2, shore_range: float) -> void:
	name = "MarshWater"
	_water = water
	_low_top = low_top
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://draft3d/marsh/marsh_water.gdshader")
	# Après la passe de palette (RENDER_PRIORITY_MIN), avant les sprites : l'eau ne se dessine pas sur les monstres.
	water_material.render_priority = Material.RENDER_PRIORITY_MIN + 2
	water_material.set_shader_parameter("surface_tex", load(FOLDER + "eau_surface.png"))
	water_material.set_shader_parameter("ripple_tex", frames("eau_rides_%d.png", RIPPLE_FRAMES))
	water_material.set_shader_parameter("ripple_frames", RIPPLE_FRAMES)
	water_material.set_shader_parameter("foam_tex", frames("ecume_%d.png", FOAM_FRAMES))
	water_material.set_shader_parameter("foam_frames", FOAM_FRAMES)
	water_material.set_shader_parameter("shore_tex", load(shore_map))
	water_material.set_shader_parameter("shore_rect", Vector4(shore_rect.position.x, shore_rect.position.y,
		shore_rect.size.x, shore_rect.size.y))
	water_material.set_shader_parameter("shore_range", shore_range)
	water_material.set_shader_parameter("low_top", low_top)
	water.material_override = water_material
	wet_material = ShaderMaterial.new()
	wet_material.shader = preload("res://draft3d/marsh/marsh_wet.gdshader")
	wet_material.render_priority = Material.RENDER_PRIORITY_MIN + 1
	wet_material.set_shader_parameter("mud_tex", load(FOLDER + "vase_mouillee.png"))
	_follow(0.0)


## Images d'une animation (`pattern` % 1..count) réunies en un tableau de textures (une couche par image).
static func frames(pattern: String, count: int) -> Texture2DArray:
	var images: Array[Image] = []
	for index: int in count:
		var image: Image = (load(FOLDER + pattern % (index + 1)) as Texture2D).get_image()
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
	var array := Texture2DArray.new()
	array.create_from_images(images)
	return array


## Vase mouillée posée sur la dalle d'une levée basse.
func wet(slab: MeshInstance3D) -> void:
	slab.material_overlay = wet_material


func _process(delta: float) -> void:
	_follow(delta)


func _follow(delta: float) -> void:
	var level: float = _water.position.y
	water_material.set_shader_parameter("water_level", level)
	_dry_for = 0.0 if level > _low_top else minf(_dry_for + delta, WET_TIME)
	var value: float = 1.0 - _dry_for / WET_TIME
	if not is_equal_approx(value, wetness) or delta == 0.0:
		wetness = value
		wet_material.set_shader_parameter("wetness", wetness)
