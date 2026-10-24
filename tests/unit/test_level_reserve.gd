extends TestCase
## Choix de niveau en réserve : pas de pause en plein combat ; ouverture aux temps forts, à la demande
## ou quand la réserve est pleine.

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host, &"mossback")
	run.ctx.setup.autopilot = false
	run.set_physics_process(false)


func after_each() -> void:
	host.get_tree().paused = false
	RunFixture.dispose(run)


func _level_up(count: int) -> void:
	for i: int in count:
		run.ctx.player.gain_xp(float(run.ctx.balance.xp_to_next(run.ctx.player.level)) / run.ctx.player.stats.get_value(
			StatKeys.XP_GAIN))


func test_level_up_is_stored_without_pause() -> void:
	_level_up(1)
	check_eq(run.ctx.player.pending_levels, 1, "un choix en réserve")
	run._open_modals()
	check(not run.level_up_panel.visible and not host.get_tree().paused, "le combat continue")


func test_milestone_opens_all_stored_choices() -> void:
	enable_features([&"chests", &"relics"])
	_level_up(2)
	run.ctx.events.chest_collected.emit()
	run._open_modals()
	check(run.level_up_panel.visible, "temps fort : les choix s'ouvrent")
	run.level_up_panel._choose(0)
	check_eq(run.ctx.player.pending_levels, 1, "un choix pris")
	run._open_modals()
	check(run.level_up_panel.visible, "le choix suivant enchaîne")
	run.level_up_panel._choose(0)
	run._open_modals()
	check(run.chest_panel.visible, "puis le coffre")
	check(not run.release_choices, "réserve vidée")


func test_open_choices_action_and_cap() -> void:
	_level_up(1)
	var press := InputEventAction.new()
	press.action = &"open_choices"
	press.pressed = true
	run._unhandled_input(press)
	run._open_modals()
	check(run.level_up_panel.visible, "touche : les choix s'ouvrent")
	run.level_up_panel._choose(0)
	check(not run.level_up_panel.visible, "réserve vide")
	_level_up(run.ctx.balance.level_reserve_cap)
	run._open_modals()
	check(run.level_up_panel.visible, "réserve pleine : elle s'ouvre d'elle-même")
	for i: int in run.ctx.balance.level_reserve_cap:
		run.level_up_panel._choose(0)
		run._open_modals()
	check_eq(run.ctx.player.pending_levels, 0, "réserve pleine vidée en une seule pause")
	check(not run.level_up_panel.visible and not run.release_choices, "le combat reprend")
