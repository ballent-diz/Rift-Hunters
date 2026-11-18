class_name DraftPixelFx
extends Sprite3D
## Effets PixelFX de la campagne (assets/vfx/pixelfx/<effet>/<famille>.png + .json) joués dans le monde 3D.
## Même catalogue que le jeu 2D (techniques.json : effet de tir et d'impact par famille de monstres) ; les feuilles
## sont lues telles quelles, dans la palette de la famille. Un effet absent pour une famille n'affiche rien.

const ROOT := "res://assets/vfx/pixelfx/%s/%s"
const CATALOG := "res://assets/vfx/pixelfx/techniques.json"
const DEFAULT_FAMILY := &"violet"
## Mètres par pixel d'effet.
const PIXEL := 0.03
## Priorité de rendu des effets dédiés (combos, passifs) : dessinés avant les zones annoncées des ennemis
## (priorité 0), qui restent lisibles par-dessus (docs/design/FICHES_VFX_GAMEPLAY_V2.md).
const UNDER_TELEGRAPHS := -1
## Zone qui tombe du ciel (pluie du boss) : un effet par famille.
const RAIN := {&"violet": &"star_fall", &"highlands": &"lightning_strike", &"calcines": &"flame_pillar",
	&"magma": &"meteor", &"enlises": &"geyser", &"reflets": &"ice_shatter", &"givres": &"icicle_fall",
	&"silence": &"ice_spikes", &"fallen": &"dark_explosion", &"riftborn": &"dark_explosion"}

## Effets dédiés : hauteur minimale (m) sous le point d'ancrage que l'image peut atteindre avant d'être avancée vers
## la caméra. Les fiches ancrent les effets au sol à 0,3 m : le bas de l'image ne passe plus sous le sol.
const GROUND_CLEARANCE := 0.3
## Effets dédiés : avance minimale (m) vers la caméra, pour passer devant le sprite de la cible qu'ils recouvrent.
const IN_FRONT := 1.0
## Effets dédiés ancrés sur un ennemi ou sur le Chasseur : en rendu pixel, les personnages sont en transparence
## mélangée à la priorité 0 et recouvriraient un effet dessiné avant eux (priorité -1). Ces effets, petits et brefs,
## partagent donc la priorité des personnages et sont triés par profondeur (avancés de IN_FRONT devant leur cible).
## Les effets au sol (Orage, Ombre piégée, zones des combos) restent sous les zones annoncées des ennemis.
const OVER_TARGET: Array[StringName] = [&"mutation_mark_execute", &"mutation_mark_hunt", &"mutation_rend_pierce",
	&"mutation_stasis_shards", &"mutation_rain_focus", &"mutation_veil_recoil", &"combo_prismatic_execution",
	&"combo_dimensional_hunt", &"combo_prismatic_convergence", &"combo_still_storm", &"passive_dash_blade",
	&"passive_counter_cut"]

static var _sheets: Dictionary = {}
static var _catalog: Dictionary = {}

var loop: bool = false
## Effet dédié joué (vide pour un effet générique).
var dedicated_effect: StringName = &""
## Point d'ancrage demandé (sans le décalage vers la caméra) : c'est lui que l'on compare à la cible.
var anchor: Vector3 = Vector3.ZERO
var _sheet: Dictionary = {}
var _clock: float = 0.0
var _toward_camera: Vector3 = Vector3.ZERO


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return _catalog


static func enemy_family(data: EnemyData) -> StringName:
	return data.family if data != null and data.family != &"" else DEFAULT_FAMILY


static func boss_family(data: BossData) -> StringName:
	return StringName(str((catalog().get("boss_families", {}) as Dictionary).get(String(data.id), DEFAULT_FAMILY)))


## Effet de vol (`flights`) ou d'impact (`shots`) des tirs d'une famille.
static func shot_effect(table: String, family: StringName) -> StringName:
	return StringName(str((catalog().get(table, {}) as Dictionary).get(String(family), "mana_burst")))


static func sheet(effect: StringName, family: StringName) -> Dictionary:
	var key: String = "%s/%s" % [effect, family]
	if _sheets.has(key):
		return _sheets[key]
	var result: Dictionary = {}
	var base: String = ROOT % [effect, family]
	if ResourceLoader.exists(base + ".png") and FileAccess.file_exists(base + ".json"):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		if data is Dictionary:
			var rects: Array[Rect2] = []
			var frames: Variant = data["frames"]
			for frame: Variant in (frames if frames is Array else (frames as Dictionary).values()):
				var r: Dictionary = frame["frame"]
				rects.append(Rect2(r["x"], r["y"], r["w"], r["h"]))
			var meta: Dictionary = data["meta"]["pixelfx"]
			result = {"texture": load(base + ".png"), "rects": rects, "fps": float(meta["fps"])}
	_sheets[key] = result
	return result


## Effet livré (feuille de la famille par défaut) : effets dédiés de la v2 (docs/design/FICHES_VFX_GAMEPLAY_V2.md).
static func has_sheet(effect: StringName) -> bool:
	return not sheet(effect, DEFAULT_FAMILY).is_empty()


## Échelle à passer à `play` pour que la première image mesure `width` m de large.
static func size_for(effect: StringName, width: float) -> float:
	var rects: Array[Rect2] = sheet(effect, DEFAULT_FAMILY).get("rects", [] as Array[Rect2])
	return width / (rects[0].size.x * PIXEL) if not rects.is_empty() and rects[0].size.x > 0.0 else 1.0


## Effet dédié `effect` s'il est livré, `width` m de large, dessiné sous les zones annoncées des ennemis ; sinon null
## (l'appelant garde son repli, ou rien quand l'effet n'a pas d'équivalent : docs/design/FICHES_VFX_MUTATIONS_V2.md).
static func dedicated(parent: Node, effect: StringName, width: float, at: Vector3, looping: bool = false) -> DraftPixelFx:
	if not has_sheet(effect):
		return null
	var node: DraftPixelFx = play(parent, effect, DEFAULT_FAMILY, at, size_for(effect, width), looping)
	node.dedicated_effect = effect
	node.render_priority = priority_for(effect)
	var camera: Camera3D = parent.get("camera") as Camera3D if "camera" in parent else null
	node._clear_ground(camera if camera != null else node.get_viewport().get_camera_3d())
	node.place(at)
	return node


## Priorité de rendu d'un effet dédié (voir OVER_TARGET).
static func priority_for(effect: StringName) -> int:
	return 0 if OVER_TARGET.has(effect) else UNDER_TELEGRAPHS


## Place l'effet sur `at` (à rappeler pour un effet qui suit sa cible ou sa zone).
func place(at: Vector3) -> void:
	anchor = at
	position = at + _toward_camera


## Image face caméra : devant le sprite de sa cible, et assez avancée pour que sa moitié basse, qui descend sous
## l'ancrage, ne soit pas coupée par le sol (Orage, Ombre piégée). La caméra étant orthographique, avancer l'effet vers
## elle ne change ni sa place ni sa taille à l'écran.
func _clear_ground(camera: Camera3D) -> void:
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	var up: Vector3 = camera.global_basis.y
	var back: Vector3 = camera.global_basis.z
	var below: float = region_rect.size.y * pixel_size * 0.5 * up.y - GROUND_CLEARANCE
	var push: float = IN_FRONT
	if below > 0.0 and back.y > 0.05:
		push = maxf(push, below / back.y)
	_toward_camera = back * push


## Joue l'effet à `at` (null si la feuille n'existe pas pour cette famille, après repli sur la famille par défaut).
static func play(parent: Node, effect: StringName, family: StringName, at: Vector3, size: float = 1.0,
		looping: bool = false) -> DraftPixelFx:
	var data: Dictionary = sheet(effect, family)
	if data.is_empty():
		data = sheet(effect, DEFAULT_FAMILY)
	if data.is_empty():
		return null
	var node := DraftPixelFx.new()
	node._sheet = data
	node.loop = looping
	node.texture = data["texture"]
	node.region_enabled = true
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.shaded = false
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.pixel_size = PIXEL * size
	node.position = at
	node.region_rect = (data["rects"] as Array[Rect2])[0]
	parent.add_child(node)
	return node


func _process(delta: float) -> void:
	_clock += delta
	var rects: Array[Rect2] = _sheet["rects"]
	var frame: int = int(_clock * float(_sheet["fps"]))
	if frame >= rects.size() and not loop:
		queue_free()
		return
	region_rect = rects[frame % rects.size()]
