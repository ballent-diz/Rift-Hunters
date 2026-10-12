class_name GameplayEffect
extends Resource
## Effet composable (reliques, synergies, mutations, arbre, maîtrise, évolutions).
## Une ressource est partagée : tout état de partie vit dans les closures créées par install().

## owner_id : identifiant de l'Écho propriétaire (passive, évolution, maîtrise), sinon &"".
func install(_ctx: RunContext, _owner_id: StringName) -> void:
	pass


## Filtre de source : &"any" (tout allié), &"player", &"allies", &"owner", ou un identifiant d'Écho.
static func matches_source(filter: StringName, owner_id: StringName, info: DamageInfo) -> bool:
	match filter:
		&"", &"any":
			return info.is_friendly()
		&"player":
			return info.source_kind == DamageInfo.SourceKind.PLAYER
		&"allies":
			return info.source_kind == DamageInfo.SourceKind.ALLY
		&"owner":
			return info.source_kind == DamageInfo.SourceKind.ALLY and info.source_id == owner_id
		_:
			return info.source_id == filter


static func matches_source_id(filter: StringName, owner_id: StringName, source_id: StringName) -> bool:
	match filter:
		&"", &"any":
			return true
		&"owner":
			return source_id == owner_id
		_:
			return source_id == filter
