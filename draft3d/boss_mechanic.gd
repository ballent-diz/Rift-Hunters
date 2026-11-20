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


## Faux si la technique ne doit pas être choisie à cette distance du Chasseur (aspiration de trop loin...).
func allows(_kind: StringName, _distance: float) -> bool:
	return true


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


## Enchaînement propre au boss : technique à jouer de préférence après `last` (&"" : aucune préférence).
func next_kind(_last: StringName) -> StringName:
	return &""


## Appelée juste après que le boss a joué une technique (suite imposée : charge après un écrasement...).
func after(_kind: StringName) -> void:
	pass


## Coup reçu par le boss (dégâts réellement infligés).
func on_hit(_dealt: float) -> void:
	pass


## Vrai tant que le boss est hors d'atteinte du contact (plongé sous l'eau, dans un miroir).
func hides_boss() -> bool:
	return false


## Vrai tant que la mécanique retient le boss (ni déplacement ni attaque du cerveau commun).
func holds_boss() -> bool:
	return false


## Boule lumineuse (orbe, étoile, lanterne) ajoutée au monde, sans ombre.
## Obstacle solide (mur de vase, miroir) : bloque le Chasseur, les tirs, les ondes et la vue (couche 1 du décor).
func make_block(at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	body.add_child(node)
	brain.enemies.add_child(body)
	body.global_position = at + Vector3.UP * size.y * 0.5
	return body


## Disque plat au sol (flaque, zone), sans ombre.
func make_disc(at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = DraftCombatFx.ground(brain.enemies, at, Vector2.ONE * radius * 2.0,
		brain.combat_family(), DraftCombatFx.DISC, DraftCombatFx.HOLD, DraftCombatFx.WARNING)
	DraftCombatFx.tint(node, color)
	return node


func make_orb(color: Color, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = DraftCombatFx.material(Vector2.ONE * radius * 2.0, DraftCombatFx.ORB,
		brain.combat_family(), DraftCombatFx.HOLD, DraftCombatFx.CONTACT)
	DraftCombatFx.tint(node, color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brain.enemies.add_child(node)
	return node


func finish() -> void:
	pass
