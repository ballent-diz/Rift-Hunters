class_name EnvironmentSet
extends RefCounted
## Décor d'une arène lu dans le manifeste d'assets (entrée « environment.<id> ») :
## sol périodique, atlas d'éléments (plaques, détails, objets, bordure), densités et ambiance.

const LAYERS: Array[StringName] = [&"patch", &"water", &"detail", &"prop", &"obstacle", &"border"]

var id: StringName = &""
var pixel_scale: float = 1.0
var ground: Texture2D
var atlas: Texture2D
## Éléments : {name, layer, weight, region (Rect2 dans l'atlas), anchor (point d'appui en pixels),
## collision (Array[Vector3] : cercles x, y, rayon en unités du monde, relatifs au point d'appui)}.
var decals: Array[Dictionary] = []
## Nombre d'éléments par couche pour 1000 x 1000 unités du monde.
var density: Dictionary = {}
var border_width: float = 0.0
var border_spacing: float = 30.0
var clear_radius: float = 150.0
var outside_tint: Color = Color(0, 0, 0, 0)
var ambient_color: Color = Color(1, 1, 1, 0.6)
var ambient_amount: int = 0
## Arène dessinée d'un seul tenant (« kind » = map) : image du sol entier et carte de distance des zones
## infranchissables (niveau de gris : 128 = bord, au-dessus praticable, 1 niveau = field_step unités, voir build_map.py).
var map_texture: Texture2D
var field_image: Image
var field_step: float = 1.0
var arena_size: float = 0.0
## Départ du joueur (point dégagé de la map, unités du monde).
var start := Vector2.ZERO
## Image agrandie (peinture lissée) : filtrage linéaire au lieu des pixels nets.
var smooth: bool = false


func is_map() -> bool:
	return map_texture != null


## Construit le décor depuis une entrée du manifeste. null si un fichier manque (le jeu garde le sol de remplacement).
static func from_entry(p_id: StringName, e: Dictionary) -> EnvironmentSet:
	if e.is_empty() or str(e.get("status", "planned")) == "planned":
		return null
	if str(e.get("kind", "")) == "map":
		return _from_map_entry(p_id, e)
	for key: String in ["ground", "atlas"]:
		if not ResourceLoader.exists(str(e.get(key, ""))):
			return null
	var env := EnvironmentSet.new()
	env.id = p_id
	env.pixel_scale = float(e.get("scale", 1.0))
	env.ground = load(str(e["ground"]))
	env.atlas = load(str(e["atlas"]))
	for raw: Variant in e.get("decals", []):
		var d: Dictionary = raw
		var rect: Array = d.get("rect", [0, 0, 0, 0])
		var anchor: Array = d.get("anchor", [int(rect[2]) / 2, int(rect[3]) / 2])
		var collision: Array[Vector3] = []
		for c: Variant in d.get("collision", []):
			var circle: Array = c
			collision.append(Vector3(float(circle[0]), float(circle[1]), float(circle[2])) * env.pixel_scale)
		env.decals.append({
			"collision": collision,
			"name": StringName(str(d.get("name", ""))),
			"layer": StringName(str(d.get("layer", "detail"))),
			"weight": float(d.get("weight", 1.0)),
			"region": Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])),
			"anchor": Vector2(float(anchor[0]), float(anchor[1])),
		})
	env.density = e.get("density", {})
	var border: Dictionary = e.get("border", {})
	env.border_width = float(border.get("width", 0.0))
	env.border_spacing = maxf(float(border.get("spacing", 30.0)), 8.0)
	env.clear_radius = float(e.get("clear_radius", 150.0))
	env.outside_tint = Color.from_string(str(e.get("outside_tint", "#00000000")), Color(0, 0, 0, 0))
	var ambient: Dictionary = e.get("ambient", {})
	env.ambient_color = Color.from_string(str(ambient.get("color", "#ffffff")), Color.WHITE)
	env.ambient_amount = int(ambient.get("amount", 0))
	return env


static func _from_map_entry(p_id: StringName, e: Dictionary) -> EnvironmentSet:
	if not ResourceLoader.exists(str(e.get("map", ""))) or not ResourceLoader.exists(str(e.get("field", ""))):
		return null
	var env := EnvironmentSet.new()
	env.id = p_id
	env.pixel_scale = float(e.get("scale", 1.0))
	env.map_texture = load(str(e["map"]))
	env.field_image = (load(str(e["field"])) as Texture2D).get_image()
	if env.field_image.is_compressed():
		env.field_image.decompress()
	env.field_step = float(e.get("field_step", 1.0))
	env.smooth = str(e.get("filter", "nearest")) == "linear"
	var start: Array = e.get("start", [0, 0])
	env.start = Vector2(float(start[0]), float(start[1]))
	env.arena_size = float(e.get("arena_size", 0.0))
	env.outside_tint = Color.from_string(str(e.get("outside_tint", "#00000000")), Color(0, 0, 0, 0))
	var ambient: Dictionary = e.get("ambient", {})
	env.ambient_color = Color.from_string(str(ambient.get("color", "#ffffff")), Color.WHITE)
	env.ambient_amount = int(ambient.get("amount", 0))
	return env


## Indices des éléments d'une couche.
func decals_in(layer: StringName) -> Array[int]:
	var out: Array[int] = []
	for i: int in decals.size():
		if decals[i]["layer"] == layer:
			out.append(i)
	return out
