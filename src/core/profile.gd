extends Node
## Progression du joueur (version prototype : pas encore de sauvegarde, tout est débloqué).

func make_run_setup(starter_id: StringName, previous: RunSetup = null) -> RunSetup:
	var setup := RunSetup.new()
	if previous:
		setup.arena_id = previous.arena_id
		setup.difficulty_id = previous.difficulty_id
	setup.starter_id = starter_id if starter_id != &"" else &"mossback"
	setup.unlocked_monsters = GameDB.sorted_ids(GameDB.monsters)
	return setup


func apply_run_result(result: Dictionary) -> Dictionary:
	return RunRewards.compute(result, GameDB.balance)
