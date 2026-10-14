class_name ResultsPanel
extends Control
## Écran de fin de partie : résultat, statistiques, dégâts par source, récompenses et déblocages.

signal replay_requested
signal refuge_requested

var _box: VBoxContainer


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UiKit.dimmer(0.85))
	_box = MenuSkin.modal_box(self, 10)


func show_result(result: Dictionary, rewards: Dictionary) -> void:
	visible = true
	UiKit.clear(_box)
	var victory: bool = result.get("victory", false)
	_box.add_child(UiKit.label(tr("RESULT_VICTORY") if victory else tr("RESULT_DEFEAT"), 44,
		UiKit.GOLD if victory else UiKit.DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	var time: float = result.get("time", 0.0)
	var summary: String = tr("RESULT_SUMMARY") % [int(time) / 60, int(time) % 60, int(result.get("level", 1)),
		int(result.get("kills", 0))]
	_box.add_child(UiKit.label(summary, 20, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(columns)
	columns.add_child(_damage_column(result))
	columns.add_child(_rewards_column(result, rewards))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	var refuge: Button = UiKit.button(tr("RESULT_REFUGE"), func() -> void: refuge_requested.emit(), 240)
	buttons.add_child(refuge)
	refuge.grab_focus.call_deferred()
	buttons.add_child(UiKit.button(tr("RESULT_REPLAY"), func() -> void: replay_requested.emit(), 240))
	_box.add_child(buttons)


func _damage_column(result: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_child(UiKit.label(tr("RESULT_DAMAGE_TITLE"), 20, UiKit.ACCENT))
	var damage: Dictionary = result.get("stats", {}).get("damage_by_source", {})
	var entries: Array = []
	for source: Variant in damage:
		if not String(source).begins_with("taken_"):
			entries.append([String(source), float(damage[source])])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	for entry: Array in entries.slice(0, 6):
		col.add_child(UiKit.label("%s : %d" % [_source_name(entry[0]), int(entry[1])], 16, UiKit.TEXT))
	var counters: Dictionary = result.get("stats", {}).get("counters", {})
	col.add_child(UiKit.label(tr("RESULT_ELITES") % int(counters.get("elites_killed", 0)), 16, UiKit.MUTED))
	col.add_child(UiKit.label(tr("RESULT_DAMAGE_TAKEN") % int(counters.get("damage_taken", 0)), 16, UiKit.MUTED))
	return col


func _rewards_column(_result: Dictionary, rewards: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_child(UiKit.label(tr("RESULT_REWARDS_TITLE"), 20, UiKit.GOLD))
	col.add_child(UiKit.label(tr("RESULT_SHARDS") % int(rewards.get("shards", 0)), 16, UiKit.TEXT))
	col.add_child(UiKit.label(tr("RESULT_ESSENCE") % int(rewards.get("essence", 0)), 16, UiKit.TEXT))
	for line: String in rewards.get("lines", []):
		var label: Label = UiKit.wrapped(line, 15, UiKit.ACCENT)
		label.custom_minimum_size.x = 360
		col.add_child(label)
	return col


func _source_name(source: String) -> String:
	if source == "player":
		return tr("SOURCE_PLAYER")
	var monster: MonsterData = GameDB.monster(StringName(source))
	return tr(monster.name_key) if monster else source
