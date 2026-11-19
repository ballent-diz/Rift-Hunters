class_name DraftCombatFx
extends RefCounted
## Couches de matière du combat 3D. Les appelants fournissent l'emprise et la durée. Aucun calcul de cible,
## de collision ou de dégâts. Les zones amies et les peintures restent sous les annonces des ennemis.

const GROUP := &"draft_combat_fx"
const SHADER := preload("res://draft3d/render/combat_fx.gdshader")
const DISC := 0
const LANE := 1
const WAVE := 2
const VEIL := 3
const GLINT := 4
const RIM := 5
const ORB := 6
const BEAM := 7

const HOLD := 0
const WINDUP := 1
const IMPACT := 2
const RETRACT := 3

const PLAYER := -2
const WARNING := 0
const CONTACT := -1

# Une teinte d'ombre, une teinte de lumière et une matière par famille.
const PALETTES := {
	&"void": [Color("#7137b5"), Color("#ecd1ff"), 0],
	&"riftborn": [Color("#9b2a81"), Color("#ffc3ef"), 0],
	&"reflets": [Color("#457eab"), Color("#c2f3ff"), 1],
	&"givres": [Color("#466f9c"), Color("#c5efff"), 1],
	&"silence": [Color("#526789"), Color("#dbedff"), 1],
	&"calcines": [Color("#a74731"), Color("#ffcb85"), 2],
	&"magma": [Color("#bc492d"), Color("#ffe1a2"), 2],
	&"enlises": [Color("#47774d"), Color("#d5ed9f"), 4],
	&"mist": [Color("#526e84"), Color("#c0d8dd"), 3],
	&"highlands": [Color("#5d689d"), Color("#dbd5ff"), 3],
	&"fallen": [Color("#946146"), Color("#ffe0ad"), 5],
	&"steel": [Color("#4e7a8a"), Color("#e2f5ed"), 5],
}
# Teintes des compléments aux planches de mutations, combos et passifs.
const ACCENTS := {
	&"mutation_mark_execute": &"fallen", &"mutation_mark_hunt": &"fallen", &"mutation_rend_pierce": &"void",
	&"mutation_step_trap": &"riftborn", &"mutation_stasis_shards": &"givres", &"mutation_rain_storm": &"reflets",
	&"mutation_rain_focus": &"reflets", &"mutation_veil_recoil": &"calcines",
	&"combo_prismatic_execution": &"reflets", &"combo_prismatic_deluge": &"reflets",
	&"combo_gravity_blade": &"void", &"combo_dimensional_hunt": &"riftborn", &"combo_tracker_rupture": &"magma",
	&"combo_prismatic_convergence": &"reflets", &"combo_counter_rift": &"steel", &"combo_spectral_rebound": &"void",
	&"combo_avenging_aegis": &"steel", &"combo_rift_prison": &"enlises",
	&"combo_shattering_bastion": &"highlands", &"combo_still_storm": &"givres",
	&"passive_dash_blade": &"steel", &"passive_void_wake": &"void", &"passive_counter_cut": &"fallen",
}

static func material(extent: Vector2, shape: int, family: StringName, beat: int, priority: int,
		opacity: float = 1.0, cone: float = -1.0) -> ShaderMaterial:
	var palette: Array = PALETTES.get(family, PALETTES[&"void"])
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.render_priority = priority
	result.set_shader_parameter("shape", shape)
	result.set_shader_parameter("extent", extent)
	result.set_shader_parameter("pigment", palette[0])
	# Le bord rose pâle identifie l'annonce ennemie, quelle que soit la matière de son intérieur.
	var edge: Color = palette[1]
	result.set_shader_parameter("highlight", edge.lerp(Color("#ffb4da"), 0.55) if beat == WINDUP else edge)
	result.set_shader_parameter("motif", palette[2])
	result.set_shader_parameter("beat", beat)
	result.set_shader_parameter("opacity", opacity)
	result.set_shader_parameter("cone_cos", cone)
	return result


static func ground(parent: Node, at: Vector3, extent: Vector2, family: StringName, shape: int = DISC,
		beat: int = HOLD, priority: int = PLAYER, opacity: float = 1.0, direction: Vector3 = Vector3.FORWARD,
		cone: float = -1.0) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = extent
	var node: MeshInstance3D = _mesh(parent, plane, at + Vector3.UP * 0.09,
		material(extent, shape, family, beat, priority, opacity, cone))
	node.global_basis = Basis(Vector3.UP, atan2(-direction.x, -direction.z))
	return node


static func burst(parent: Node, at: Vector3, radius: float, family: StringName, seconds: float = 0.36,
		direction: Vector3 = Vector3.FORWARD, cone: float = -1.0, beat: int = IMPACT) -> MeshInstance3D:
	return fade(ground(parent, at, Vector2.ONE * radius * 2.0, family, DISC, beat, PLAYER, 0.9, direction, cone), seconds)


static func streak(parent: Node, start: Vector3, direction: Vector3, length: float, width: float,
		family: StringName, seconds: float = 0.3) -> MeshInstance3D:
	return fade(ground(parent, start + direction * length * 0.5, Vector2(width, length), family,
		LANE, IMPACT, PLAYER, 0.86, direction), seconds)


static func veil(parent: Node, at: Vector3, size: Vector2, along: Vector3, family: StringName,
		opacity: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var node: MeshInstance3D = _mesh(parent, quad, at + Vector3.UP * size.y * 0.5,
		material(size, VEIL, family, HOLD, PLAYER, opacity))
	node.rotation.y = atan2(-along.z, along.x)
	# En vue rasante, le pied et la crête affichent encore l'épaisseur du voile.
	var start: Vector3 = node.global_position
	var heading: Vector3 = along.normalized()
	ground(node, at, Vector2(0.46, size.x), family, LANE, HOLD, PLAYER, 0.88, heading)
	ground(node, start + Vector3.UP * (size.y * 0.33), Vector2(0.26, size.x), family, LANE, HOLD, PLAYER, 0.65, heading)
	return node


## Éclats autour d'un sprite (le centre reste libre). L'effet est enfant de son point d'ancrage et suit son tri.
static func glint(anchor: Node3D, offset: Vector3, size: Vector2, family: StringName,
		seconds: float, opacity: float = 1.0) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var node: MeshInstance3D = _mesh(anchor, quad, anchor.global_position + offset,
		material(size, GLINT, family, IMPACT if seconds > 0.0 else HOLD, CONTACT, opacity))
	return fade(node, seconds) if seconds > 0.0 else node


## Garde la couleur d'état choisie par la mécanique (sûr, armé, scellé, etc.).
static func tint(node: MeshInstance3D, color: Color) -> void:
	var look := node.material_override as ShaderMaterial
	look.set_shader_parameter("pigment", color.darkened(0.25))
	look.set_shader_parameter("highlight", color.lerp(Color("#fff0db"), 0.48))
	look.set_shader_parameter("opacity", color.a)


static func update(node: MeshInstance3D, amount: float) -> void:
	(node.material_override as ShaderMaterial).set_shader_parameter("progress", amount)


static func fade(node: MeshInstance3D, seconds: float) -> MeshInstance3D:
	var anim: Tween = node.create_tween()
	anim.tween_method(func(amount: float) -> void: update(node, amount), 0.0, 1.0, maxf(seconds, 0.01))
	anim.tween_callback(node.queue_free)
	return node


static func _mesh(parent: Node, mesh: Mesh, at: Vector3, look: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = look
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group(GROUP)
	parent.add_child(node)
	if node.is_inside_tree():
		node.global_position = at
	return node
