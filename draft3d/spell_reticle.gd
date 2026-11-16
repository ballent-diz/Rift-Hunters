class_name DraftSpellReticle
extends MeshInstance3D
## Anneau de visée au sol des sorts du Chasseur : point visé, ou zone du sort en aperçu (option « aperçu ») et pendant
## la charge de la Surcharge. Lecture seule de `DraftSpells`.

const RETICLE_COLOR := Color(0.85, 0.95, 1.0, 0.55)

var _material: StandardMaterial3D


func _init() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.88
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 4
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_material.albedo_color = RETICLE_COLOR
	ring.material = _material
	name = "SpellReticle"
	mesh = ring
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func show_for(spells: DraftSpells) -> void:
	var here: Vector3 = spells.run.hunter.global_position
	var aim: Vector3 = spells.aim_point()
	var radius: float = 0.35
	var at: Vector3 = aim
	var color: Color = RETICLE_COLOR
	var shown: int = spells.preview_slot if spells.preview_slot >= 0 else spells.charge_slot
	if shown >= 0 and spells.slots[shown] != null:
		var data: SpellData = spells.slots[shown]
		color = Color(data.color, 0.7)
		match data.spell_kind:
			&"slash":
				at = here
				radius = spells.reach_of(data)
			&"rupture", &"leap", &"singularity", &"crystal":
				at = here + DraftSpells._flat(aim - here).limit_length(spells.reach_of(data))
				radius = spells.area_of(data)
			&"wall":
				at = here + DraftSpells._flat(aim - here).limit_length(spells.reach_of(data))
				radius = spells.area_of(data) * 0.5
			&"parry", &"aegis", &"veil":
				at = here
				radius = spells.area_of(data)
			&"stasis":
				at = here
				radius = spells.reach_of(data)
			&"mark", &"shard_rain", &"blink", &"rend":
				at = here + DraftSpells._flat(aim - here).limit_length(spells.reach_of(data))
				radius = spells.area_of(data)
			_:
				radius = spells.area_of(data) * 2.0
	visible = spells.slots.any(func(s: SpellData) -> bool: return s != null)
	position = Vector3(at.x, here.y + 0.06, at.z)
	scale = Vector3(radius, 0.3, radius)
	_material.albedo_color = color
