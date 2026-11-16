class_name DraftBossMechanic
extends RefCounted
## Mécanique phare d'un boss de la base 3D (docs/design/BOSS_V2.md) : état qui dure au-delà d'une attaque, greffé
## sur `DraftBossBrain`. Une mécanique peut prendre en charge certaines techniques des données (`handles`) ; les
## autres restent jouées par le cerveau commun. Elle est retirée à la mort du boss (`finish`).

var brain: DraftBossBrain


func setup(p_brain: DraftBossBrain) -> void:
	brain = p_brain


## Vrai si la mécanique joue elle-même cette technique des données.
func handles(_kind: StringName) -> bool:
	return false


## Joue la technique ; renvoie la durée pendant laquelle le boss reste occupé.
func perform(_pattern: BossPatternData) -> float:
	return 0.0


func step(_delta: float) -> void:
	pass


func on_phase(_index: int) -> void:
	pass


## Multiplicateur des coups reçus par le boss (carapace, voile, cœur exposé...).
func damage_mult() -> float:
	return 1.0


## Vrai tant que la mécanique retient le boss (ni déplacement ni attaque du cerveau commun).
func holds_boss() -> bool:
	return false


## Explication de la mécanique, une fois par partie (bandeau).
func intro(key: String) -> void:
	brain.banner_once(key)


## Boule lumineuse (orbe, étoile, lanterne) ajoutée au monde, sans ombre.
func make_orb(color: Color, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain.enemies.add_child(node)
	return node


func finish() -> void:
	pass
