extends Node
## Navigation entre les scènes principales.

const MAIN_MENU := "res://scenes/main.tscn"
const REFUGE := "res://scenes/refuge.tscn"
const RUN := "res://scenes/run.tscn"

var pending_setup: RunSetup
var last_result: Dictionary = {}


func start_run(setup: RunSetup) -> void:
	pending_setup = setup
	_change(RUN)


func goto_refuge() -> void:
	_change(REFUGE)


func goto_main_menu() -> void:
	_change(MAIN_MENU)


func _change(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)
