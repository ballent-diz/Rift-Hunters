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
		for button_name: String in ["Play", "Options", "Credits", "Quit"]:
			var button: Button = canvas.get_node(button_name)
			var target := Rect2(canvas.position + button.position * canvas.scale, button.size * canvas.scale)
			check(bounds.encloses(target), "bouton visible : %s / %s" % [button_name, resolution])


func test_language_action_rebuilds_translated_controls() -> void:
	await host.get_tree().process_frame
	Settings.set_locale("fr")
	await host.get_tree().process_frame
	var options: Button = _menu.get_node("MenuCanvas/Options")
	check_eq(options.text, "Options")
	options.pressed.emit()
	await host.get_tree().process_frame
	var window: Control = _menu.get_node("OptionsWindow")
	var language: Button = null
	for button: Node in window.find_children("*", "Button", true, false):
		if (button as Button).text == "Langue : Français":
			language = button
	check(language != null, "la langue se règle dans la fenêtre d'options")
	language.pressed.emit()
	await host.get_tree().process_frame
	check_eq(Settings.locale, "en")
	var play: String = _menu.get_node("MenuCanvas/Play").text
	check(play == "Enter the Refuge" or play == "Continue", "menu retraduit : %s" % play)
	check_eq(_menu.get_node("MenuCanvas/Quit").text, "Quit")
	check(_menu.find_child("CloseOptions", true, false) != null, "fenêtre d'options toujours ouverte")
	check_eq((_menu.find_child("CloseOptions", true, false) as Button).text, "Close", "fenêtre retraduite")


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
	var screen: Variant = _menu.get_child(_menu.get_child_count() - 1)
	check(screen is CreditsScreen, "générique ouvert par le bouton existant")
	var credits_screen: CreditsScreen = screen
	await host.get_tree().process_frame
	var scroll: ScrollContainer = credits_screen.get_child(0)
	var before: int = scroll.scroll_vertical
	for i: int in 30:
		await host.get_tree().process_frame
	check(scroll.scroll_vertical > before, "le générique défile tout seul")
	credits_screen._show_licenses()
	check(credits_screen._licenses != null, "les licences s'ouvrent à part")
	credits_screen.back_button.pressed.emit()
	check(credits_screen.is_queued_for_deletion(), "retour du générique")
