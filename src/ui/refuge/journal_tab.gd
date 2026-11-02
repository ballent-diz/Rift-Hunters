extends RefugeTab
## Journal des mécaniques (MechanicJournal) : chaque mécanique de carte, de Corrompu, de gardien ou de Dévoreur déjà
## rencontrée, avec son explication ; celles qui restent à découvrir apparaissent masquées.

const GROUP_COLORS := {&"maps": Color(0.55, 0.9, 0.6), &"enemies": Color(1.0, 0.6, 0.45), &"bosses": Color(0.75, 0.55, 1.0)}


func title_key() -> String:
	return "TAB_JOURNAL"


## Nouvelle mécanique notée depuis la dernière lecture du Journal.
func needs_attention() -> bool:
	return MechanicJournal.seen(profile()).size() > int(profile().data.get("journal_read", 0))


func refresh() -> void:
	var box: VBoxContainer = scroll_box(10)
	var p: ProfileData = profile()
	p.data["journal_read"] = MechanicJournal.seen(p).size()
	box.add_child(UiKit.wrapped(tr("JOURNAL_INTRO") % [MechanicJournal.seen(p).size(), MechanicJournal.ENTRIES.size()],
		15, UiKit.MUTED))
	for group: StringName in MechanicJournal.GROUPS:
		var color: Color = GROUP_COLORS[group]
		box.add_child(UiKit.title(tr("JOURNAL_GROUP_" + String(group).to_upper()), 22, color))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		box.add_child(grid)
		for key: String in MechanicJournal.keys_of(group):
			grid.add_child(_entry(key, MechanicJournal.has_seen(p, key), color))


func _entry(key: String, known: bool, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(540, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.07, 0.055, 0.12, 0.9),
		Color(color, 0.8) if known else Color(0.3, 0.3, 0.38)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	box.add_child(UiKit.label(tr(MechanicJournal.title_key(key)) if known else "???", 19,
		MenuSkin.PAPER if known else UiKit.MUTED))
	box.add_child(UiKit.wrapped(MechanicJournal.body(key) if known else tr("JOURNAL_UNKNOWN"), 15, UiKit.MUTED))
	return card
