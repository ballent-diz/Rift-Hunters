class_name BuildState
extends RefCounted
## État du build pendant une partie.

var upgrade_stacks: Dictionary = {}  # id -> int
var exclusive_taken: Dictionary = {}  # groupe -> id
var relics: Array[StringName] = []
var banished: Array[StringName] = []
var rerolls_used: int = 0
var banishes_used: int = 0
var evolutions: Dictionary = {}  # monster_id -> evolution_id
var active_synergies: Array[StringName] = []
## Échos capturés pendant la partie (débloqués définitivement en fin de partie).
var captures: Array[StringName] = []


func stacks_of(id: StringName) -> int:
	return int(upgrade_stacks.get(id, 0))


func add_upgrade(upgrade: UpgradeData) -> void:
	upgrade_stacks[upgrade.id] = stacks_of(upgrade.id) + 1
	if upgrade.exclusive_group != &"":
		exclusive_taken[upgrade.exclusive_group] = upgrade.id


func is_blocked_by_exclusive(upgrade: UpgradeData) -> bool:
	if upgrade.exclusive_group == &"":
		return false
	var taken: StringName = exclusive_taken.get(upgrade.exclusive_group, &"")
	return taken != &"" and taken != upgrade.id
