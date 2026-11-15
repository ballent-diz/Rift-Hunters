class_name DraftSpellVfx
extends RefCounted
## Animations peintes des sorts de la v1 (lot C5 de Codex, `assets/vfx/hunter/`, manifeste `vfx.hunter.*`) jouées
## dans le monde 3D. Ces scènes 2D sont dessinées vue de dessus : chacune est rendue dans une petite vue transparente
## (SubViewport) affichée à plat sur le sol, à l'échelle du monde (1 unité v1 = `DraftHunter.UNIT` m), orientée
## dans la direction du sort. Présentation seulement : aucun dégât ni règle ici. Sans scène, l'appelant garde son
## effet PixelFX.

## Taille fendante : le coup est instantané, l'animation commence à la phase de coupe (comme en v1).
const SLASH_CUT_PHASE := 0.10
## Résolution de la vue (pixels de vue par unité v1) et côté maximal de la vue.
const RESOLUTION := 0.6
const MAX_VIEW := 1400
## Marge autour du dessin (unités v1).
const MARGIN := 90.0
## Noms des variantes côté animation quand ils diffèrent de ceux des cartes de la v2 ; les variantes propres à la v2
## sans dessin jouent la version de base.
const VARIANT_NAMES := {
	&"blaze": &"inferno", &"double": &"double_prism", &"burning": &"burning_wall", &"second_wind": &"sharing",
	&"long_guard": &"base",
}

static var _scenes: Dictionary = {}

var run: DraftRun
## Effets en cours {node, view, plane, follow}.
var playing: Array[Dictionary] = []


func _init(p_run: DraftRun) -> void:
	run = p_run


static func scene(effect_id: String) -> PackedScene:
	if not _scenes.has(effect_id):
		var path: String = str(Assets.entry(StringName("vfx.hunter." + effect_id)).get("scene", ""))
		_scenes[effect_id] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _scenes[effect_id]


static func variant_name(variant: StringName) -> StringName:
	return &"base" if variant == &"" else VARIANT_NAMES.get(variant, variant)


## Crée l'animation `effect_id` posée au sol en `at`, sur un carré de `extent` unités v1 autour de son origine.
## `setup` reçoit le nœud 2D (propriétés à régler) ; `start` le démarre (play, play_from, play_between…).
## `follow` : l'animation suit le Chasseur (Égide, Parade). Renvoie le nœud 2D, ou null sans scène.
func spawn(effect_id: String, at: Vector3, extent: float, start: Callable, setup: Callable = Callable(),
		follow: bool = false, lift: float = 0.06) -> Node2D:
	var packed: PackedScene = scene(effect_id)
	if packed == null or run == null or not run.is_inside_tree():
		return null
	var half: float = extent + MARGIN
	var pixels: int = mini(ceili(half * 2.0 * RESOLUTION), MAX_VIEW)
	var scale: float = float(pixels) / (half * 2.0)
	var view := SubViewport.new()
	view.transparent_bg = true
	view.disable_3d = true
	view.size = Vector2i(pixels, pixels)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	view.canvas_transform = Transform2D(0.0, Vector2(scale, scale), 0.0, Vector2(pixels, pixels) * 0.5)
	run.add_child(view)
	var node: Node2D = packed.instantiate()
	if node.get("destroy_on_finish") != null:
		node.set("destroy_on_finish", false)
	if setup.is_valid():
		setup.call(node)
	view.add_child(node)
	start.call(node)
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * half * 2.0 * DraftHunter.UNIT
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = view.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material = material
	var plane := MeshInstance3D.new()
	plane.mesh = quad
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	run.add_child(plane)
	plane.global_position = at + Vector3.UP * lift
	var item := {"node": node, "view": view, "plane": plane, "follow": follow, "lift": lift}
	playing.append(item)
	if node.has_signal("visual_finished"):
		node.connect("visual_finished", func() -> void: _finish(item))
	return node


## Direction 3D (sol) → direction de la scène 2D (x vers +x, y vers +z).
static func flat(direction: Vector3) -> Vector2:
	var result := Vector2(direction.x, direction.z)
	return result.normalized() if result.length_squared() > 0.0001 else Vector2.RIGHT


func step() -> void:
	for i: int in range(playing.size() - 1, -1, -1):
		var item: Dictionary = playing[i]
		if not is_instance_valid(item["node"]):
			_finish(item)
			continue
		if item["follow"] and run.hunter != null:
			(item["plane"] as Node3D).global_position = run.hunter.view.render_position() + Vector3.UP * float(item["lift"])


## Arrête l'animation (fin du sort persistant : mur, cristal, puits).
func stop(node: Node2D) -> void:
	for item: Dictionary in playing.duplicate():
		if item["node"] == node:
			_finish(item)


func _finish(item: Dictionary) -> void:
	playing.erase(item)
	for key: String in ["view", "plane"]:
		var target: Variant = item[key]
		if target is Node and is_instance_valid(target):
			(target as Node).queue_free()
