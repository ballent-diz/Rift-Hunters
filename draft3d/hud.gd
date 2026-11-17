class_name DraftHud
extends CanvasLayer
## Interface du premier jet : PV, EXP, niveau, chrono, boss, améliorations prises, choix de niveau, fin de partie.
## Lit l'état de la partie, n'applique aucune règle. Reste active pendant la pause du choix d'amélioration.

signal chosen(index: int)
signal restart_requested
signal chapter_chosen(order: int)
signal chapter_change_requested
signal pause_requested
signal menu_requested
## Raccourci de test « Aller au boss » (DraftRun.test_shortcuts).
signal boss_test_requested

const INK := Color("f0e8d7")
const DIM := Color("b9bccb")

## Bouton de test « Aller au boss » dans la pause (versions de développement seulement).
var test_shortcuts: bool = false
var _hp_bar: ProgressBar
var _hp_text: Label
var _xp_bar: ProgressBar
var _level: Label
var _clock: Label
var _kills: Label
var _dash: ProgressBar
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _build: Label
var _hint: Label
var _spell_bar: DraftSpellBar
var _arsenal: DraftArsenalPanel
var _choice: DraftChoicePanel
var _spell_pips: DraftSpellPips
var _banner: Label
var _banner_left: float = 0.0
var _offer_root: Control
var _end_root: Control
var _chapter_root: Control
var _pause_root: Control
var _options: DraftOptions
var _cards: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_xp_bar = _bar(root, Color("7fd6ff"), Color(0.05, 0.07, 0.12, 0.85))
	_xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_xp_bar.offset_bottom = 14
	_level = _label(root, 20, INK)
	_level.position = Vector2(16, 20)
	_hp_bar = _bar(root, Color("e0524f"), Color(0.12, 0.05, 0.06, 0.85))
	_hp_bar.position = Vector2(16, 52)
	_hp_bar.size = Vector2(260, 20)
	_hp_text = _label(root, 14, INK)
	_hp_text.position = Vector2(24, 52)
	_dash = _bar(root, Color("c9b3ff"), Color(0.07, 0.06, 0.12, 0.85))
	_dash.position = Vector2(16, 78)
	_dash.size = Vector2(120, 8)
	_clock = _label(root, 26, INK)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock.offset_top = 20
	_clock.offset_left = -60
	_clock.offset_right = 60
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kills = _label(root, 16, DIM)
	_kills.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_kills.offset_left = -220
	_kills.offset_right = -16
	_kills.offset_top = 22
	_kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_left = -260
	_boss_box.offset_right = 260
	_boss_box.offset_top = 58
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = _label(_boss_box, 16, Color("d9b8ff"))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar = _bar(_boss_box, Color("a45cff"), Color(0.08, 0.04, 0.12, 0.85))
	_boss_bar.custom_minimum_size = Vector2(520, 14)
	_build = _label(root, 14, DIM)
	_build.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_build.offset_left = 16
	_build.offset_top = -210
	_build.offset_bottom = -14
	_build.offset_right = 360
	_build.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_spell_pips = DraftSpellPips.new()
	_spell_pips.name = "SpellPips"
	root.add_child(_spell_pips)
	_spell_bar = DraftSpellBar.new()
	_spell_bar.name = "SpellBar"
	root.add_child(_spell_bar)
	_spell_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_spell_bar.offset_left = -_spell_bar.custom_minimum_size.x * 0.5
	_spell_bar.offset_right = _spell_bar.custom_minimum_size.x * 0.5
	_spell_bar.offset_top = -(DraftSpellBar.SLOT + 40.0)
	_spell_bar.offset_bottom = -18.0
	_hint = _label(root, 15, DIM)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -420
	_hint.offset_right = 420
	_hint.offset_top = -(DraftSpellBar.SLOT + 74.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = tr("DRAFT_CONTROLS") % _spell_keys()
	_banner = _label(root, 30, Color("ffd9a0"))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = -190
	_banner.offset_bottom = -140
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false


func refresh(run: Node, delta: float) -> void:
	var hunter: DraftHunter = run.get("hunter")
	_hp_bar.max_value = hunter.max_hp()
	_hp_bar.value = hunter.hp
	_hp_text.text = "%d / %d" % [int(ceil(hunter.hp)), int(hunter.max_hp())]
	_xp_bar.max_value = hunter.xp_needed()
	_xp_bar.value = hunter.xp
	_level.text = tr("DRAFT_LEVEL") % hunter.level
	_dash.max_value = hunter.dash_cooldown()
	_dash.value = hunter.dash_cooldown() - hunter.dash_cooldown_left
	var time: float = run.get("time")
	_clock.text = "%d:%02d" % [int(time) / 60, int(time) % 60]
	_kills.text = tr("DRAFT_KILLS") % int(run.get("kills"))
	_hint.visible = time < 12.0
	var enemies: DraftEnemies = run.get("enemies")
	_boss_box.visible = enemies.boss != null and enemies.boss.alive
	if _boss_box.visible:
		_boss_name.text = tr(enemies.boss.boss.name_key)
		_boss_bar.max_value = enemies.boss.max_hp
		_boss_bar.value = enemies.boss.hp
	_spell_bar.spells = run.get("spells")
	_spell_pips.run = run as DraftRun
	_banner_left -= delta
	_banner.visible = _banner_left > 0.0


## Améliorations prises, avec leur rang : la montée en puissance reste lisible pendant le combat.
func show_build(upgrades: DraftUpgrades) -> void:
	var lines: PackedStringArray = []
	for data: UpgradeData in upgrades.all_cards():
		var stacks: int = upgrades.stacks_of(data.id)
		if stacks > 0:
			lines.append("%s  %s" % [tr(data.name_key), "◆".repeat(stacks) + "◇".repeat(data.max_stacks - stacks)])
	_build.text = "\n".join(lines)


func banner(text: String, seconds: float = 3.0) -> void:
	_banner.text = text
	_banner_left = seconds


func show_offers(level: int, offers: Array[UpgradeData], upgrades: DraftUpgrades) -> void:
	_offer_root = _overlay()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 18)
	_offer_root.add_child(column)
	var title := _label(column, 34, Color("ffd9a0"))
	title.text = tr("DRAFT_LEVEL_UP") % level
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(column, 16, DIM)
	subtitle.text = tr("DRAFT_CHOOSE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	_cards.clear()
	for i: int in offers.size():
		var data: UpgradeData = offers[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(300, 190)
		card.focus_mode = Control.FOCUS_NONE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.11, 0.96)
		style.border_color = data.color
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(16)
		card.add_theme_stylebox_override("normal", style)
		var hover: StyleBoxFlat = style.duplicate()
		hover.bg_color = Color(0.12, 0.13, 0.2, 0.98)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)
		var key := _label(box, 14, DIM)
		key.text = "[%d]" % (i + 1)
		# Rareté (cartes de la v2) : couleur du cadre et nom de la rareté.
		var rarity: int = DraftCard.rarity_of(data)
		if data is DraftCard:
			key.text += "  %s" % tr("REWARD3D_RARITY_%d" % rarity)
			key.add_theme_color_override("font_color", DraftCard.RARITY_COLORS[rarity])
			style.border_color = DraftCard.RARITY_COLORS[rarity]
			hover.border_color = DraftCard.RARITY_COLORS[rarity]
		var title_row := HBoxContainer.new()
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(title_row)
		var name_label := _label(title_row, 22, data.color.lightened(0.3))
		name_label.text = tr(data.name_key)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Illustration : icône du sort (cartes de sort, celle de la barre) ou illustration de la v1 des cartes de
		# statistique (assets/ui/items/upgrades/, catalogue ItemArt).
		var icon: Texture2D = DraftSpellBar.icon_for(spell_of(data))
		var art: Texture2D = icon if icon != null else ItemArt.texture("upgrade", data.id)
		if art != null:
			var frame := PanelContainer.new()
			var frame_style := StyleBoxFlat.new()
			frame_style.bg_color = Color(0.025, 0.02, 0.07, 0.8)
			frame_style.border_color = data.color.darkened(0.45)
			frame_style.set_border_width_all(1)
			frame_style.set_corner_radius_all(4)
			frame_style.set_content_margin_all(6)
			frame.add_theme_stylebox_override("panel", frame_style)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(frame)
			var picture := TextureRect.new()
			picture.name = "SpellIcon" if icon != null else "UpgradeArt"
			picture.texture = art
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.custom_minimum_size = Vector2(0, 120)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(picture)
			card.custom_minimum_size.y = 340
		var desc := _label(box, 15, INK)
		desc.text = tr(data.desc_key)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var rank := _label(box, 13, DIM)
		var stacks: int = upgrades.stacks_of(data.id)
		rank.text = tr("DRAFT_NEW") if stacks == 0 else tr("DRAFT_RANK") % [stacks + 1, data.max_stacks]
		card.pressed.connect(func() -> void: chosen.emit(i))
		row.add_child(card)
		_cards.append(card)


## Sort visé par une carte de sort (nouveau sort, variante, rang), null pour une carte de statistique.
static func spell_of(data: UpgradeData) -> SpellData:
	for effect: GameplayEffect in data.effects:
		var spell := effect as DraftSpellEffect
		if spell != null:
			return DraftSpells.spell(spell.spell_id)
	return null


func hide_offers() -> void:
	if _offer_root != null:
		_offer_root.queue_free()
		_offer_root = null
	_cards.clear()


func offers_open() -> bool:
	return _offer_root != null


## `gain` : Fragments de faille gagnés pendant la partie (-1 : système de déblocage absent, rien n'est affiché).
func show_end(victory: bool, summary: String, gain: int = -1) -> void:
	_end_root = _overlay()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 16)
	_end_root.add_child(column)
	var title := _label(column, 48, Color("ffd9a0") if victory else Color("ff8a8a"))
	title.text = tr("DRAFT_VICTORY") if victory else tr("DRAFT_DEFEAT")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stats := _label(column, 18, INK)
	stats.text = summary
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if gain >= 0:
		var reward := _label(column, 22, Color("ffd9a0"))
		reward.name = "Gain"
		reward.text = tr("UNLOCK3D_GAIN") % gain
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var list: Array[Button] = [
		_menu_button(column, "Restart", tr("DRAFT_RESTART"), func() -> void: restart_requested.emit()),
		_menu_button(column, "Chapter", tr("DRAFT_CHANGE_CHAPTER"), func() -> void: chapter_change_requested.emit()),
		_menu_button(column, "Menu", tr("MENU3D_BACK_TO_MENU"), func() -> void: menu_requested.emit())]
	DraftMenu._chain_focus(list)
	list[0].grab_focus.call_deferred()


func end_open() -> bool:
	return _end_root != null


## Choix du chapitre au lancement : son bestiaire, ses gardiens et son Dévoreur.
func show_chapters(chapters: Array[ChapterData], done: Array[int], all_open: bool = false) -> void:
	var overlay: Control = _overlay()
	_chapter_root = overlay
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 12)
	overlay.add_child(column)
	var title := _label(column, 34, Color("ffd9a0"))
	title.text = tr("DRAFT_CHOOSE_CHAPTER")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detail := _label(column, 15, DIM)
	detail.custom_minimum_size = Vector2(560, 48)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var list: Array[Button] = []
	for i: int in chapters.size():
		var open: bool = all_open or DraftProgress.is_unlocked(i + 1, done)
		var text: String = "%d. %s%s" % [i + 1, tr(DraftRoster.name_key(chapters[i])), "  ✓" if done.has(i + 1) else ""]
		if not open:
			text += "  —  " + tr("DRAFT_CHAPTER_LOCKED")
		var button: Button = _menu_button(column, "Chapter%d" % (i + 1), text, func() -> void:
			_chapter_root = null
			overlay.queue_free()
			chapter_chosen.emit(i + 1))
		button.disabled = not open
		button.custom_minimum_size = Vector2(560, 46)
		button.add_theme_color_override("font_color", chapters[i].color.lightened(0.4))
		button.add_theme_color_override("font_focus_color", chapters[i].color.lightened(0.6))
		button.add_theme_color_override("font_hover_color", chapters[i].color.lightened(0.6))
		var desc: String = tr(DraftRoster.desc_key(chapters[i]))
		button.focus_entered.connect(func() -> void: detail.text = desc)
		button.mouse_entered.connect(func() -> void: detail.text = desc)
		if open:
			list.append(button)
	column.move_child(detail, -1)
	list.append(_menu_button(column, "Back", tr("MENU3D_BACK"), func() -> void: menu_requested.emit()))
	DraftMenu._chain_focus(list)
	list[0].grab_focus.call_deferred()


func chapters_open() -> bool:
	return _chapter_root != null


## Pause (Échap, P ou Start) : reprendre, options, recommencer, menu principal, quitter.
func show_pause() -> void:
	if _pause_root != null:
		return
	_pause_root = _overlay()
	_pause_root.name = "Pause"
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	_pause_root.add_child(column)
	var title := _label(column, 44, Color("ffd9a0"))
	title.text = tr("PAUSE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var list: Array[Button] = [
		_menu_button(column, "Resume", tr("PAUSE_RESUME"), func() -> void: pause_requested.emit()),
		_menu_button(column, "Arsenal", tr("ARSENAL3D_TITLE"), func() -> void:
			var panel: DraftArsenalPanel = show_arsenal(_spell_bar.spells)
			panel.closed.connect(func() -> void:
				hide_arsenal()
				(_pause_root.find_child("Arsenal", true, false) as Control).grab_focus.call_deferred())),
		_menu_button(column, "Options", tr("MENU_OPTIONS"), open_options),
		_menu_button(column, "Restart", tr("MENU3D_RESTART"), func() -> void: restart_requested.emit()),
		_menu_button(column, "Menu", tr("MENU3D_BACK_TO_MENU"), func() -> void: menu_requested.emit()),
		_menu_button(column, "Quit", tr("MENU_QUIT"), func() -> void: get_tree().quit())]
	if test_shortcuts:
		var test: Button = _menu_button(column, "BossTest", tr("PAUSE3D_BOSS_TEST"), func() -> void:
			boss_test_requested.emit())
		column.move_child(test, 2)
		list.insert(1, test)
	DraftMenu._chain_focus(list)
	list[0].grab_focus.call_deferred()


func hide_pause() -> void:
	close_options()
	if _pause_root != null:
		_pause_root.queue_free()
		_pause_root = null


func pause_open() -> bool:
	return _pause_root != null


func open_options() -> void:
	if _options != null:
		return
	_options = DraftOptions.new()
	add_child(_options)
	_options.closed.connect(close_options)
	_options.language_changed.connect(func() -> void:
		_hint.text = tr("DRAFT_CONTROLS") % _spell_keys()
		close_options()
		hide_pause()
		show_pause()
		open_options())


func close_options() -> void:
	if _options == null:
		return
	_options.queue_free()
	_options = null
	_hint.text = tr("DRAFT_CONTROLS") % _spell_keys()
	if _pause_root != null:
		var button: Button = _pause_root.find_child("Options", true, false)
		button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _options != null or _arsenal != null or _choice != null:
		return
	var back: bool = event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")
	if back and chapters_open():
		menu_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if back and not offers_open() and not end_open():
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if offers_open():
		var index: int = [KEY_1, KEY_2, KEY_3].find(key.physical_keycode)
		if index < 0:
			index = [KEY_KP_1, KEY_KP_2, KEY_KP_3].find(key.physical_keycode)
		if index >= 0 and index < _cards.size():
			chosen.emit(index)
	elif key.physical_keycode == KEY_R and not pause_open() and not chapters_open():
		restart_requested.emit()


## Arsenal (docs/design/GAMEPLAY_V2_ARCHITECTURE.md) : remplacement d'une case (`replace_id`) ou gestion depuis la pause.
func show_arsenal(spells: DraftSpells, replace_id: StringName = &"") -> DraftArsenalPanel:
	hide_arsenal()
	_arsenal = DraftArsenalPanel.new()
	_arsenal.name = "Arsenal"
	add_child(_arsenal)
	if replace_id != &"":
		_arsenal.replace_for(spells, replace_id)
	else:
		_arsenal.manage(spells)
	return _arsenal


func show_choice(title: String, hint: String, options: Array[String], cancel: String) -> DraftChoicePanel:
	hide_choice()
	_choice = DraftChoicePanel.new().setup(title, hint, options, cancel)
	_choice.name = "Choice"
	add_child(_choice)
	return _choice


func hide_choice() -> void:
	if _choice != null:
		_choice.queue_free()
		_choice = null


func hide_arsenal() -> void:
	if _arsenal != null:
		_arsenal.queue_free()
		_arsenal = null


func arsenal_open() -> bool:
	return _arsenal != null


func _menu_button(parent: Node, id: String, text: String, callback: Callable) -> Button:
	var button: Button = UiKit.button(text, callback, 320)
	button.name = id
	button.theme = UiKit.theme()
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_entered.connect(button.grab_focus)
	parent.add_child(button)
	return button


func _overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.05, 0.62)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	return overlay


## Touches des quatre sorts (actions reconfigurables), pour l'aide de début de partie.
static func _spell_keys() -> String:
	var keys: PackedStringArray = []
	for action: StringName in DraftSpells.ACTIONS.slice(0, DraftSpells.SLOTS):
		keys.append(InputSetup.key_label(action))
	return " ".join(keys)


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _bar(parent: Node, fill: Color, back: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	var behind := StyleBoxFlat.new()
	behind.bg_color = back
	bar.add_theme_stylebox_override("fill", front)
	bar.add_theme_stylebox_override("background", behind)
	parent.add_child(bar)
	return bar
