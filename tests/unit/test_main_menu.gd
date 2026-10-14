extends TestCase
## Le nouvel habillage doit conserver les contrôles et leurs zones cliquables.

var _menu: Control
var _locale: String


func before_each() -> void:
	_locale = Settings.locale
	_menu = load("res://scenes/main.tscn").instantiate()
	host.add_child(_menu)


func after_each() -> void:
	_menu.free()
	Settings.set_locale(_locale)


func test_art_and_hit_targets_stay_inside_each_resolution() -> void:
	await host.get_tree().process_frame
	_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for resolution: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1024, 768),
			Vector2(2560, 1080), Vector2(720, 1280)]:
		_menu.size = resolution
		_menu._fit_canvas()
		var canvas: Control = _menu.get_node("MenuCanvas")
		var bounds := Rect2(canvas.position, canvas.size * canvas.scale)
		check(Rect2(Vector2.ZERO, resolution).encloses(bounds), "décor visible : %s" % resolution)
		for button_name: String in ["Play", "Language", "Credits", "Quit"]:
			var button: Button = canvas.get_node(button_name)
			var target := Rect2(canvas.position + button.position * canvas.scale, button.size * canvas.scale)
			check(bounds.encloses(target), "bouton visible : %s / %s" % [button_name, resolution])


func test_language_action_rebuilds_translated_controls() -> void:
	await host.get_tree().process_frame
	Settings.set_locale("fr")
	await host.get_tree().process_frame
	var settings: Button = _menu.get_node("MenuCanvas/Language")
	check_eq(settings.text, "Langue : Français")
	settings.pressed.emit()
	await host.get_tree().process_frame
	check_eq(Settings.locale, "en")
	check_eq(_menu.get_node("MenuCanvas/Language").text, "Language: English")
	check_eq(_menu.get_node("MenuCanvas/Play").text, "Enter the Refuge")
	check_eq(_menu.get_node("MenuCanvas/Quit").text, "Quit")


func test_keyboard_cycle_and_credits_action() -> void:
	await host.get_tree().process_frame
	var canvas: Control = _menu.get_node("MenuCanvas")
	var play: Button = canvas.get_node("Play")
	var quit: Button = canvas.get_node("Quit")
	check_eq(play.get_node(play.focus_previous), quit, "navigation circulaire vers le dernier bouton")
	check_eq(quit.get_node(quit.focus_next), play, "navigation circulaire vers le premier bouton")
	var credits: Button = canvas.get_node("Credits")
	credits.pressed.emit()
	await host.get_tree().process_frame
	var panel: PanelContainer = _menu.get_child(_menu.get_child_count() - 1)
	check(panel is PanelContainer, "crédits ouverts par le bouton existant")
	var box: VBoxContainer = panel.get_child(0)
	var back: Button = box.get_child(box.get_child_count() - 1)
	back.pressed.emit()
	check(panel.is_queued_for_deletion(), "retour des crédits")
