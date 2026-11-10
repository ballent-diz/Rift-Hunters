class_name OcclusionMap
extends RefCounted
## Masquage des personnages par le décor peint (docs/maps/MASQUAGE_PAR_LE_DECOR.md). Charge la texture de profondeur
## préparée par l'éditeur de masquage (tools/art/occlusion_editor.tscn) et fournit les matériaux partagés posés sur
## les visuels des entités (corps et ombre). Sans données pour la carte : aucun objet, rendu inchangé.
##
## Repères : la carte (toutes ses tuiles côte à côte) couvre exactement le rectangle de l'arène en jeu (déjà réduit
## par ArenaData.decor_scale). Une cellule de la grille de masquage = `cell` pixels de la carte.
## monde = arène.position + (cellule × cell / pixels de la carte) × arène.size.

const SHADER := preload("res://assets/shaders/occluded_entity.gdshader")
const FORMAT_VERSION := 1
## Profondeur codée sur 16 bits (0 = aucun élément).
const DEPTH_MAX := 65535.0

var texture: Texture2D
## Rectangle du monde couvert par la texture de profondeur.
var depth_rect := Rect2()
## Y du haut de la carte et hauteur de la carte (décodage des profondeurs).
var depth_range := Vector2(0.0, 1.0)
var _materials: Dictionary = {}


## Données de masquage de la carte d'un décor (clé « occlusion » de son entrée de manifeste), placées sur `rect`
## (rectangle de l'arène en jeu). null si la carte n'en a pas.
static func load_for(environment_id: StringName, rect: Rect2) -> OcclusionMap:
	var path: String = str(Assets.entry(environment_id).get("occlusion", ""))
	if path == "" or not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return null
	var depth_path: String = path.get_base_dir().path_join(str((data as Dictionary).get("depth", "depth.png")))
	var image: Image = load_depth_image(depth_path)
	if image == null:
		return null
	return from_data(data, image, rect)


## Image de profondeur : ressource importée, sinon fichier brut (outils, avant le premier import).
static func load_depth_image(path: String) -> Image:
	var image: Image = null
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex != null:
			image = tex.get_image()
	elif FileAccess.file_exists(path):
		image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	return image


static func from_data(data: Dictionary, image: Image, rect: Rect2) -> OcclusionMap:
	if int(data.get("version", 0)) != FORMAT_VERSION:
		return null
	var map_size: Vector2 = _vec(data.get("map_size", [0, 0]))
	var cell: float = float(data.get("cell", 1))
	var crop: Array = data.get("depth_rect", [])
	if map_size.x <= 0.0 or map_size.y <= 0.0 or crop.size() != 4 or image == null:
		return null
	var occlusion := OcclusionMap.new()
	var per_cell: Vector2 = rect.size * cell / map_size
	occlusion.depth_rect = Rect2(rect.position + Vector2(float(crop[0]), float(crop[1])) * per_cell,
		Vector2(float(crop[2]), float(crop[3])) * per_cell)
	occlusion.depth_range = Vector2(rect.position.y, rect.size.y)
	occlusion.set_image(image)
	return occlusion


static func _vec(raw: Variant) -> Vector2:
	var list: Array = raw if raw is Array else [0, 0]
	return Vector2(float(list[0]), float(list[1])) if list.size() >= 2 else Vector2.ZERO


## Remplace la texture (éditeur : aperçu immédiat après chaque retouche).
func set_image(image: Image) -> void:
	var rg: Image = image.duplicate()
	if rg.get_format() != Image.FORMAT_RG8:
		rg.convert(Image.FORMAT_RG8)
	if texture is ImageTexture and Vector2i(texture.get_size()) == rg.get_size():
		(texture as ImageTexture).update(rg)
	else:
		texture = ImageTexture.create_from_image(rg)
	for mat: ShaderMaterial in _materials.values():
		_apply(mat)


## Matériau partagé : &"body" (corps), &"matte" (corps sur fond vert à détourer) ou &"shadow" (ombre au sol).
func material(kind: StringName) -> ShaderMaterial:
	if not _materials.has(kind):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("is_shadow", kind == &"shadow")
		mat.set_shader_parameter("green_matte", kind == &"matte")
		_apply(mat)
		_materials[kind] = mat
	return _materials[kind]


func _apply(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("depth_map", texture)
	mat.set_shader_parameter("depth_rect", Vector4(depth_rect.position.x, depth_rect.position.y,
		depth_rect.size.x, depth_rect.size.y))
	mat.set_shader_parameter("depth_range", depth_range)


## Code de profondeur (16 bits) d'une valeur 0..1 de la hauteur de la carte ; 0 réservé à « aucun élément ».
static func encode(fraction: float) -> int:
	return clampi(roundi(fraction * DEPTH_MAX), 1, int(DEPTH_MAX))


## Même règle que le shader, côté processeur (tests, outils) : le point `world` d'une entité dont le pied est en
## `foot` est-il caché ? `image` : texture de profondeur (RG8 ou RGB8).
func hides(image: Image, foot: Vector2, world: Vector2) -> bool:
	var uv: Vector2 = (world - depth_rect.position) / depth_rect.size
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return false
	var c: Color = image.get_pixelv(Vector2i(uv * Vector2(image.get_size())))
	var code: int = c.r8 * 256 + c.g8
	return code > 0 and foot.y < depth_range.x + code / DEPTH_MAX * depth_range.y
