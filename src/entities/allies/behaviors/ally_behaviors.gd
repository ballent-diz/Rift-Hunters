class_name AllyBehaviors
extends RefCounted
## Registre des comportements : behavior_id (données) → classe de code.

static func create(behavior_id: StringName) -> AllyBehavior:
	match behavior_id:
		&"striker":
			return StrikerBehavior.new()
		&"slam":
			return SlamBehavior.new()
		&"orb":
			return OrbBehavior.new()
	push_error("Comportement d'Écho inconnu : %s" % behavior_id)
	return AllyBehavior.new()
