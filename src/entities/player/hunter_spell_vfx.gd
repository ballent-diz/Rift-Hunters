class_name HunterSpellVfx
extends RefCounted
## Raccordement des animations de sorts de Codex (lot C5, assets/vfx/hunter/, docs/art/AUTRES_SORTS_C5.md) aux
## sorts du Chasseur. Les animations ne font que de la présentation : le gameplay reste dans HunterSpells et
## HunterSpellWorld. Si une scène manque (manifeste incomplet), l'appelant garde son dessin provisoire.

## Noms des variantes côté animation quand ils diffèrent de ceux de l'arbre.
const VARIANT_NAMES := {
	&"blaze": &"inferno", &"double": &"double_prism", &"burning": &"burning_wall", &"quarry": &"feast",
	&"share": &"sharing",
}
## Identifiant d'animation (manifeste « vfx.hunter.<id> ») pour chaque type de sort.
const EFFECT_IDS := {
	&"slash": "cleaving_slash", &"lance": "prismatic_lance", &"leap": "rift_leap", &"parry": "parry",
	&"rupture": "rupture", &"crystal": "refractor_crystal", &"singularity": "singularity", &"wall": "rift_wall",
	&"rifts": "twin_rifts", &"pack_call": "pack_call", &"aegis": "rift_aegis", &"swap": "swap",
}
## Taille fendante : le coup est instantané, l'animation commence directement à la phase de coupe.
const SLASH_CUT_PHASE := 0.10
## Impacts de Taille fendante affichés au plus par coup.
const MAX_IMPACTS := 2

var layer: Node2D
var _scenes: Dictionary = {}


func setup(parent: Node) -> void:
	layer = Node2D.new()
	layer.name = "SpellVfx"
	layer.z_index = 6
	parent.add_child(layer)


static func variant_name(variant: StringName) -> StringName:
	if variant == &"":
		return &"base"
	return VARIANT_NAMES.get(variant, variant)


func has_effect(spell_kind: StringName) -> bool:
	return _scene(EFFECT_IDS.get(spell_kind, "")) != null


## Crée l'animation d'un sort à `pos` (globale) sans la démarrer ; null si elle n'existe pas.
func spawn(spell_kind: StringName, pos: Vector2) -> Node2D:
	return _spawn_id(EFFECT_IDS.get(spell_kind, ""), pos)


func _spawn_id(effect_id: String, pos: Vector2) -> Node2D:
	var scene: PackedScene = _scene(effect_id)
	if scene == null or layer == null or not is_instance_valid(layer):
		return null
	var effect: Node2D = scene.instantiate()
	layer.add_child(effect)
	effect.global_position = pos
	return effect


## Impact de Taille fendante sur un contact confirmé.
func slash_impact(pos: Vector2, direction: Vector2) -> void:
	var effect: Node2D = _spawn_id("cleaving_slash.impact", pos)
	if effect:
		effect.call("play", direction)


func _scene(effect_id: String) -> PackedScene:
	if effect_id == "":
		return null
	if not _scenes.has(effect_id):
		var path: String = str(Assets.entry(StringName("vfx.hunter." + effect_id)).get("scene", ""))
		_scenes[effect_id] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _scenes[effect_id]
