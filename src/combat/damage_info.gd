class_name DamageInfo
extends RefCounted
## Description d'un coup. Les effets lisent source_kind / source_id / tags pour réagir.

enum SourceKind { PLAYER, ALLY, ENEMY, ENVIRONMENT }

const TAG_BOLT := &"bolt"
const TAG_ATTACK := &"attack"
const TAG_TECHNIQUE := &"technique"
const TAG_SPELL := &"spell"
const TAG_DETONATION := &"detonation"
const TAG_DOT := &"dot"
const TAG_EXPLOSION := &"explosion"
const TAG_PROC := &"proc"

var amount: float = 0.0
var source_kind: SourceKind = SourceKind.PLAYER
## &"player", identifiant d'Écho, d'ennemi ou de boss.
var source_id: StringName = &""
var tags: Array[StringName] = []
var knockback: float = 0.0
var direction: Vector2 = Vector2.ZERO
## Coup créé par un effet : ne déclenche pas d'autres effets « au toucher » (évite les boucles).
var is_proc: bool = false
var statuses: Array[StatusApplication] = []


static func make(p_amount: float, kind: SourceKind, id: StringName, p_tags: Array[StringName] = []) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.source_kind = kind
	info.source_id = id
	info.tags = p_tags
	return info


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


func is_friendly() -> bool:
	return source_kind == SourceKind.PLAYER or source_kind == SourceKind.ALLY


func duplicate_info() -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.source_kind = source_kind
	info.source_id = source_id
	info.tags = tags.duplicate()
	info.knockback = knockback
	info.direction = direction
	info.is_proc = is_proc
	info.statuses = statuses
	return info
