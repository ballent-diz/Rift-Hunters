extends Node
## Navigation entre les scènes principales.

const MAIN_MENU := "res://scenes/main.tscn"
const REFUGE := "res://scenes/refuge.tscn"
const RUN := "res://scenes/run.tscn"

const FADE_TIME := 0.18

var pending_setup: RunSetup
var last_result: Dictionary = {}
var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.02, 0.05, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func start_run(setup: RunSetup) -> void:
	pending_setup = setup
	_change(RUN)


func goto_refuge() -> void:
	_change(REFUGE)


func goto_main_menu() -> void:
	_change(MAIN_MENU)


func _change(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tween.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
