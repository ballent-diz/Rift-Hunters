extends Control
## Menu principal (prototype) : choix de l'Écho de départ et lancement d'une partie.

func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Settings.changed.connect(_build)
	_build()


func _build() -> void:
	UiKit.clear(self)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = UiKit.center_box(self, 14)
	box.add_child(UiKit.label("RIFT HUNTERS", 64, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label(tr("MENU_TAGLINE"), 20, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label(tr("MENU_CHOOSE_STARTER"), 22, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		var monster: MonsterData = GameDB.monster(id)
		row.add_child(UiKit.card(tr("ROLE_%d" % monster.role), tr(monster.name_key), tr(monster.desc_key),
			monster.visual.primary.lightened(0.3), _start.bind(id)))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	buttons.add_child(UiKit.button(tr("OPTIONS_LANGUAGE") % tr("LANGUAGE_NAME"), func() -> void:
		Settings.set_locale("en" if Settings.locale == "fr" else "fr"), 260))
	buttons.add_child(UiKit.button(tr("MENU_QUIT"), func() -> void: get_tree().quit(), 200))


func _start(starter: StringName) -> void:
	Router.start_run(Profile.make_run_setup(starter))
