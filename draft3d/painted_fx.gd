class_name DraftPaintedFx
extends Node3D
## Effet peint d'un boss (scènes 2D de `BossData.vfx_dir` : Dévoreur des Sources, Glauquemire) affiché dans le monde
## 3D : la scène est dessinée dans un `SubViewport` transparent, posé à plat sur le sol (le dessin v1 est vu de
## dessus ; un pixel de la v1 vaut `DraftHunter.UNIT` mètre). Présentation seulement : aucune règle de jeu.
## Le nœud se retire seul à la fin de l'animation, ou à `release_at` pour une boucle tenue.

## Effets peints simultanés au plus (chaque effet a son rendu intermédiaire).
const MAX_ACTIVE := 6
## Taille maximale du rendu intermédiaire (pixels) ; au-delà, le dessin est réduit.
const MAX_SIZE := 1024
const HEIGHT := 0.09

static var _scenes: Dictionary = {}

var effect: Node2D
var _left: float = 0.0
var _released: bool = false


## Scène peinte `name` du dossier `dir` ; nulle si elle n'existe pas.
static func scene(dir: String, name: String) -> PackedScene:
	if dir == "" or name == "":
		return null
	var path: String = dir.path_join(name + ".tscn")
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]


static func active(host: Node) -> int:
	return host.get_tree().get_nodes_in_group(&"draft_painted_fx").size()


## Joue l'effet peint `name` à `at`, orienté vers `direction` (à plat). `contact` >= 0 : démarre à cette fraction de
## l'animation (frappe déjà résolue). `hold` > 0 : boucle tenue autant de secondes. Nul si la scène manque ou si le
## plafond est atteint (l'appelant garde alors son effet PixelFX).
static func play(host: Node, dir: String, name: String, at: Vector3, direction: Vector3 = Vector3.RIGHT,
		props: Dictionary = {}, contact: float = -1.0, hold: float = 0.0) -> DraftPaintedFx:
	var packed: PackedScene = scene(dir, name)
	if packed == null or active(host) >= MAX_ACTIVE:
		return null
	var node := DraftPaintedFx.new()
	host.add_child(node)
	node._setup(packed.instantiate(), props, at, direction, contact, hold)
	return node


func _setup(p_effect: Node2D, props: Dictionary, at: Vector3, direction: Vector3, contact: float, hold: float) -> void:
	add_to_group(&"draft_painted_fx")
	effect = p_effect
	for key: String in props:
		effect.set(key, props[key])
	var reach: float = 40.0
	for key: String in ["radius", "travel_distance", "width"]:
		var value: Variant = effect.get(key)
		if value is float or value is int:
			reach += float(value)
	var size: int = mini(int(ceil(reach * 2.0)), MAX_SIZE)
	var shrink: float = minf(1.0, float(MAX_SIZE) / (reach * 2.0))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size, size)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	effect.position = Vector2(size, size) * 0.5
	effect.scale = Vector2.ONE * shrink
	viewport.add_child(effect)
	var quad := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * size / shrink * DraftHunter.UNIT
	quad.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = viewport.get_texture()
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	global_position = at + Vector3.UP * HEIGHT
	# Le plan du dessin v1 (x, y) se pose sur le sol (x, z).
	var aim := Vector2(direction.x, direction.z)
	aim = aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT
	var length: float = float(effect.call("duration")) if effect.has_method("duration") else 1.0
	if contact >= 0.0 and effect.has_method("play_from"):
		effect.call("play_from", length * contact, aim)
		length *= 1.0 - contact
	elif effect.has_method("play"):
		effect.call("play", aim)
	_left = hold if hold > 0.0 else length + 0.3


## Fin d'une boucle tenue (ou retrait anticipé) : l'effet se dissipe s'il sait le faire.
func release() -> void:
	if _released:
		return
	_released = true
	if is_instance_valid(effect) and effect.has_method("release"):
		effect.call("release")
		_left = 0.6
	else:
		_left = 0.0


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		if not _released and is_instance_valid(effect) and bool(effect.get("loop_visual")):
			release()
			return
		queue_free()
	elif not is_instance_valid(effect):
		queue_free()
