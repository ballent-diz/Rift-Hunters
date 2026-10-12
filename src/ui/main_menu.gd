extends Control
## Écran titre : entrer au Refuge, langue, quitter. Affiche les alertes de sauvegarde.

func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Settings.changed.connect(_build)
	_build()
	Audio.play_context("menu")


func _build() -> void:
	UiKit.clear(self)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = UiKit.center_box(self, 16)
	box.add_child(UiKit.label("RIFT HUNTERS", 72, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label(tr("MENU_TAGLINE"), 22, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var warning: String = Profile.status_message()
	if warning != "":
		var label: Label = UiKit.label(warning, 16, UiKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 700
		box.add_child(label)
	var play: Button = UiKit.button(tr("MENU_PLAY"), func() -> void:
		Audio.play_sfx(&"ui_click")
		Router.goto_refuge(), 360)
	play.custom_minimum_size.y = 60
	play.add_theme_font_size_override("font_size", 26)
	box.add_child(play)
	box.add_child(UiKit.button(tr("OPTIONS_LANGUAGE") % tr("LANGUAGE_NAME"), func() -> void:
		Settings.set_locale("en" if Settings.locale == "fr" else "fr"), 360))
	box.add_child(UiKit.button(tr("MENU_QUIT"), func() -> void: get_tree().quit(), 360))
	box.add_child(UiKit.label("v" + str(ProjectSettings.get_setting("application/config/version")), 13, UiKit.MUTED,
		HORIZONTAL_ALIGNMENT_CENTER))
	play.grab_focus.call_deferred()
