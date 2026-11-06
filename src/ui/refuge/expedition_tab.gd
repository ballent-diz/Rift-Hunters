extends RefugeTab
## Préparation de l'expédition (lots B1-B2, M2) : à gauche, l'équipe d'Échos, le choix Campagne / Survie, puis les
## chapitres de cette piste et leurs cartes ; à droite, le résumé de la carte choisie (objectifs, difficulté, pactes)
## et le départ, toujours visibles.

const TILE_SIZE := Vector2(248, 178)


func title_key() -> String:
	return "TAB_EXPEDITION"


func refresh() -> void:
	var p: ProfileData = profile()
	UiKit.clear(self)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	var scroll := ScrollContainer.new()
	scroll.name = "ExpeditionScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	# Le mode de jeu d'abord : il décide des cartes proposées.
	var track := StringName(p.preference("expedition_mode", String(Campaign.MAIN)))
	box.add_child(_mode_switch(track))
	_add_starters(box, p)
	box.add_child(UiKit.title(tr("EXPEDITION_MAPS"), 20, MenuSkin.PAPER))
	var arena: ArenaData = _current_arena(p, track)
	for chapter: ChapterData in Campaign.chapters_of(track):
		box.add_child(_chapter_panel(p, chapter, arena))
	if track == Campaign.SURVIVAL and _has_loose_arenas():
		box.add_child(_survival_panel(p, arena))
	root.add_child(_summary(p, arena))


## Campagne principale (jalons) ou épreuves de survie (montées de niveau) : docs/design/MODES.md.
func _mode_switch(track: StringName) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for mode: StringName in [Campaign.MAIN, Campaign.SURVIVAL]:
		var key: String = "EXPEDITION_MODE_CAMPAIGN" if mode == Campaign.MAIN else "EXPEDITION_MODE_SURVIVAL"
		var b: Button = HunterTreeSkin.button(tr(key), _set_pref.bind("expedition_mode", String(mode)), mode == track)
		b.name = "Mode_" + String(mode)
		b.custom_minimum_size = Vector2(180, 38)
		row.add_child(b)
	var hint: String = "EXPEDITION_MODE_CAMPAIGN_HINT" if track == Campaign.MAIN else "EXPEDITION_MODE_SURVIVAL_HINT"
	box.add_child(UiKit.wrapped(tr(hint), 13, UiKit.MUTED))
	return box


## Arènes hors de tout chapitre (essais) : affichées avec les épreuves de survie.
func _has_loose_arenas() -> bool:
	for arena: ArenaData in Profile.unlocked_arenas():
		if not Campaign.is_campaign_map(arena.id):
			return true
	return false


# --- Équipe d'Échos

## Équipe choisie au refuge (décision du 24 octobre 2026) : jusqu'à 3 Échos parmi ceux débloqués, le premier mène.
func _add_starters(box: VBoxContainer, p: ProfileData) -> void:
	var team: Array[StringName] = Profile.team()
	box.add_child(UiKit.title(tr("EXPEDITION_TEAM") % [team.size(), GameDB.balance.max_team_slots], 20, MenuSkin.PAPER))
	box.add_child(UiKit.wrapped(tr("EXPEDITION_TEAM_HINT"), 13, UiKit.MUTED))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	box.add_child(row)
	var owned: Array[StringName] = []
	var later: Array[StringName] = []
	for id: StringName in GameDB.sorted_ids(GameDB.monsters):
		(owned if p.is_monster_unlocked(GameDB.monster(id)) else later).append(id)
	later.sort_custom(func(a: StringName, b: StringName) -> bool: return _map_number(a) < _map_number(b))
	for id: StringName in owned:
		row.add_child(_starter_tile(p, GameDB.monster(id), team.has(id)))
	if not later.is_empty():
		# Échos à gagner : une rangée de pastilles discrètes, l'équipe disponible reste au premier plan.
		var hidden := HFlowContainer.new()
		hidden.name = "EchoesToFind"
		hidden.add_theme_constant_override("h_separation", 6)
		hidden.add_theme_constant_override("v_separation", 6)
		hidden.add_child(UiKit.caption(tr("EXPEDITION_ECHOES_TO_FIND") % later.size(), 11, UiKit.MUTED))
		for id: StringName in later:
			hidden.add_child(_starter_tile(p, GameDB.monster(id), false))
		box.add_child(hidden)
	for id: StringName in team:
		var monster: MonsterData = GameDB.monster(id)
		# Sort actif de l'Écho, en une ligne (retour de test).
		if monster.technique:
			box.add_child(UiKit.wrapped(_spell_line(monster), 12, UiKit.MUTED))
		var options := HBoxContainer.new()
		options.add_theme_constant_override("separation", 10)
		var entry: Dictionary = p.mastery_entry(id)
		if Mastery.variant_unlocked(p, monster):
			var on: bool = bool(entry.get("use_variant", false))
			var variant: Button = UiKit.button(tr(monster.variant.name_key) + (" ✓" if on else ""), _toggle.bind(id,
				"use_variant"), 0)
			variant.tooltip_text = tr(monster.variant.desc_key)
			options.add_child(variant)
		if not Mastery.palette(p, monster).is_empty():
			var palette_on: bool = bool(entry.get("use_palette", false))
			options.add_child(UiKit.button(tr("EXPEDITION_PALETTE") + (" ✓" if palette_on else ""), _toggle.bind(id,
				"use_palette"), 0))
		if options.get_child_count() > 0:
			options.add_child(UiKit.label(tr(monster.name_key), 13, MenuSkin.PAPER))
			options.move_child(options.get_child(options.get_child_count() - 1), 0)
			box.add_child(options)


func _starter_tile(p: ProfileData, monster: MonsterData, selected: bool) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(100, 116)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var unlocked: bool = p.is_monster_unlocked(monster)
	_tile_style(tile, monster.visual.primary.lightened(0.3) if unlocked else MenuSkin.COPPER.darkened(0.4), selected)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_right = -8
	box.offset_top = 6
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	if unlocked:
		var portrait := EchoPortrait.new()
		portrait.setup(monster, EchoPortrait.profile_palette(monster))
		portrait.custom_minimum_size = Vector2(0, 64)
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(portrait)
		var name_label: Label = UiKit.label(tr(monster.name_key), 13, UiKit.GOLD if selected else MenuSkin.PAPER,
			HORIZONTAL_ALIGNMENT_CENTER)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(name_label)
		var role: Label = UiKit.caption(tr("ROLE_%d" % monster.role), 10, UiKit.MUTED)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(role)
		tile.tooltip_text = tr(monster.desc_key) + "\n" + tr("EXPEDITION_MASTERY") % Mastery.level(p, monster)
		if monster.technique:
			tile.tooltip_text += "\n" + _spell_line(monster)
		tile.pressed.connect(_select_starter.bind(monster.id))
	else:
		tile.custom_minimum_size = Vector2(46, 46)
		box.offset_left = 2
		box.offset_right = -2
		box.offset_top = 2
		box.offset_bottom = -2
		var number: int = _map_number(monster.id)
		var short: String = tr("EXPEDITION_ECHO_MAP_SHORT") % number if number < 99 else "?"
		var mystery: Label = UiKit.title(short, 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		mystery.size_flags_vertical = Control.SIZE_EXPAND_FILL
		mystery.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(mystery)
		var where: String = tr("EXPEDITION_ECHO_AT_MAP") % number if number < 99 else tr("EXPEDITION_ECHO_LATER")
		tile.tooltip_text = where + "\n" + EchoCollection.source_text(monster)
	for child: Node in box.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile


## « Écho — sort actif : description ».
func _spell_line(monster: MonsterData) -> String:
	return tr("EXPEDITION_ECHO_SPELL") % [tr(monster.name_key), tr(monster.technique.name_key),
		tr(monster.technique.desc_key)]


## Numéro de la carte de campagne qui donne cet Écho (99 : pas encore de carte).
func _map_number(monster_id: StringName) -> int:
	var monster: MonsterData = GameDB.monster(monster_id)
	var number: int = 0
	for chapter: ChapterData in Campaign.chapters_of(Campaign.MAIN):
		for map: CampaignMapData in chapter.maps:
			number += 1
			if monster and map.arena_id == monster.discovery_arena:
				return number
	return 99


# --- Cartes

## Carte choisie dans la piste affichée ; sinon la dernière débloquée de cette piste (retenue pour le départ).
func _current_arena(p: ProfileData, track: StringName) -> ArenaData:
	var arena: ArenaData = GameDB.arena(StringName(p.preference("arena", "three_rifts")))
	var loose: bool = arena != null and not Campaign.is_campaign_map(arena.id)
	var in_track: bool = arena != null and (Campaign.track_of(arena.id) == track if not loose else track == Campaign.SURVIVAL)
	if arena == null or not p.is_arena_unlocked(arena) or not in_track:
		arena = Profile.unlocked_arenas()[0]
		for map: CampaignMapData in Campaign.maps_in_order(track):
			var candidate: ArenaData = GameDB.arena(map.arena_id)
			if candidate and p.is_arena_unlocked(candidate):
				arena = candidate
		p.set_preference("arena", String(arena.id))
	return arena


func _chapter_panel(p: ProfileData, chapter: ChapterData, current: ArenaData) -> PanelContainer:
	var panel := PanelContainer.new()
	var frame: StyleBoxFlat = MenuSkin.frame(Color(0.06, 0.045, 0.1, 0.9), Color(chapter.color, 0.45))
	frame.border_width_left = 4
	frame.border_color = Color(chapter.color, 0.6)
	panel.add_theme_stylebox_override("panel", frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var banner := PanelContainer.new()
	var banner_frame := MenuSkin.frame(Color(chapter.color, 0.10), Color(chapter.color, 0.45))
	banner_frame.set_border_width_all(1)
	banner_frame.border_width_left = 5
	banner.add_theme_stylebox_override("panel", banner_frame)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 2)
	banner.add_child(heading)
	heading.add_child(UiKit.caption(_chapter_caption(chapter), 11, chapter.color))
	heading.add_child(UiKit.title(tr(chapter.name_key), 20, MenuSkin.PAPER))
	box.add_child(banner)
	box.add_child(UiKit.wrapped(tr(chapter.desc_key), 13, UiKit.MUTED))
	box.add_child(_chapter_path(p, chapter, current))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	box.add_child(row)
	var maps: Array[CampaignMapData] = Campaign.maps_in_order(chapter.track)
	for map: CampaignMapData in chapter.maps:
		var arena: ArenaData = GameDB.arena(map.arena_id)
		if arena == null:
			continue
		var index: int = maps.find(map)
		var previous: ArenaData = GameDB.arena(maps[index - 1].arena_id) if index > 0 else null
		row.add_child(_map_tile(p, arena, map, chapter.color, arena == current, previous))
	return panel


## Chemin du chapitre : une étape par carte, reliées dans l'ordre ; pleine si gagnée, cerclée d'or si ouverte, grise si
## fermée ; un anneau sur la carte choisie et, dessous, les étoiles obtenues.
func _chapter_path(p: ProfileData, chapter: ChapterData, current: ArenaData) -> Control:
	var steps: Array[Dictionary] = []
	var stars: int = 0
	var total: int = 0
	for map: CampaignMapData in chapter.maps:
		var arena: ArenaData = GameDB.arena(map.arena_id)
		if arena == null:
			continue
		var done: int = 0
		for objective: MapObjectiveData in map.objectives:
			done += 1 if Campaign.objective_done(p, arena.id, Campaign.NORMAL, objective.id) else 0
		stars += done
		total += map.objectives.size()
		steps.append({"won": Campaign.wins(p, arena.id) > 0, "open": p.is_arena_unlocked(arena),
			"current": arena == current, "stars": "%d/%d" % [done, map.objectives.size()]})
	var row := HBoxContainer.new()
	row.name = "ChapterPath"
	row.add_theme_constant_override("separation", 14)
	var path := Control.new()
	path.custom_minimum_size = Vector2(maxf(steps.size() * 92.0, 92.0), 50)
	path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path.draw.connect(func() -> void:
		var font: Font = path.get_theme_default_font()
		for i: int in steps.size():
			var center := Vector2(26 + i * 92, 18)
			if i > 0:
				var lit: bool = bool(steps[i - 1]["won"])
				path.draw_line(center - Vector2(78, 0), center - Vector2(14, 0),
					Color(chapter.color, 0.9) if lit else Color(UiKit.MUTED, 0.35), 3.0 if lit else 2.0, true)
			var step: Dictionary = steps[i]
			if step["won"]:
				path.draw_circle(center, 11, chapter.color)
			elif step["open"]:
				path.draw_circle(center, 11, Color(0.08, 0.06, 0.12))
				path.draw_arc(center, 11, 0, TAU, 32, UiKit.GOLD, 2.0, true)
			else:
				path.draw_circle(center, 11, Color(0.18, 0.18, 0.22))
			if step["current"]:
				path.draw_arc(center, 16, 0, TAU, 32, MenuSkin.PAPER, 1.5, true)
			var number: String = str(i + 1)
			path.draw_string(font, center + Vector2(-4 * number.length(), 5), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.05, 0.04, 0.08) if step["won"] else MenuSkin.PAPER)
			if step["open"]:
				path.draw_string(font, center + Vector2(-14, 32), "★ " + str(step["stars"]), HORIZONTAL_ALIGNMENT_LEFT,
					-1, 11, UiKit.GOLD if step["won"] else UiKit.MUTED))
	row.add_child(path)
	var summary: Label = UiKit.caption(tr("EXPEDITION_CHAPTER_STARS") % [stars, total], 12, UiKit.GOLD)
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(summary)
	return row


func _map_tile(p: ProfileData, arena: ArenaData, map: CampaignMapData, accent: Color, selected: bool,
		previous: ArenaData) -> Button:
	var tile := Button.new()
	tile.name = "Map_" + String(arena.id)
	tile.custom_minimum_size = TILE_SIZE
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var unlocked: bool = p.is_arena_unlocked(arena)
	_tile_style(tile, accent if unlocked else MenuSkin.COPPER.darkened(0.4), selected)
	var image: TextureRect = _map_preview(arena, 80)
	image.modulate = Color.WHITE if unlocked else Color(0.42, 0.42, 0.46, 1)
	tile.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	image.offset_left = 4
	image.offset_right = -4
	image.offset_top = 4
	image.offset_bottom = 84
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_top = 94
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	var name_label: Label = UiKit.title(tr(arena.name_key), 16, UiKit.GOLD if selected else (MenuSkin.PAPER if unlocked
		else UiKit.MUTED))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)
	if map and unlocked:
		var done: int = 0
		for objective: MapObjectiveData in map.objectives:
			done += 1 if Campaign.objective_done(p, arena.id, Campaign.NORMAL, objective.id) else 0
		box.add_child(_stars(done, map.objectives.size()))
		var won: bool = Campaign.wins(p, arena.id) > 0
		box.add_child(UiKit.caption(tr("EXPEDITION_MAP_CLEARED") if won else tr("EXPEDITION_MAP_NEW"), 10,
			accent if won else UiKit.GOLD))
	elif unlocked:
		box.add_child(UiKit.caption(tr("EXPEDITION_SURVIVAL_TAG"), 10, accent))
	else:
		var hint: String = tr("EXPEDITION_MAP_LOCKED_BY") % tr(previous.name_key) if previous else tr("EXPEDITION_LOCKED")
		var locked: Label = UiKit.wrapped(hint, 12, UiKit.MUTED)
		box.add_child(locked)
	for child: Node in box.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.disabled = not unlocked
	tile.tooltip_text = tr(arena.desc_key) if unlocked else tr("EXPEDITION_MAP_LOCKED")
	tile.pressed.connect(_set_pref.bind("arena", String(arena.id)))
	return tile


func _survival_panel(p: ProfileData, current: ArenaData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.05, 0.04, 0.08, 0.85), MenuSkin.COPPER.darkened(0.3)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UiKit.caption(tr("EXPEDITION_SURVIVAL"), 11, UiKit.MUTED))
	box.add_child(UiKit.wrapped(tr("EXPEDITION_SURVIVAL_NOTE"), 13, UiKit.MUTED))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	box.add_child(row)
	for arena: ArenaData in Profile.unlocked_arenas():
		if not Campaign.is_campaign_map(arena.id):
			row.add_child(_map_tile(p, arena, null, MenuSkin.LANTERN, arena == current, null))
	return panel


## Trois étoiles dessinées (objectifs Normal obtenus) : lisibles à toute taille, sans dépendre d'une police.
func _stars(done: int, total: int) -> Control:
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(16 * total, 16)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.draw.connect(func() -> void:
		for i: int in total:
			var center := Vector2(8 + i * 18, 8)
			var points := PackedVector2Array()
			for k: int in 10:
				var radius: float = 7.0 if k % 2 == 0 else 3.0
				points.append(center + Vector2.UP.rotated(k * PI / 5.0) * radius)
			if i < done:
				stars.draw_colored_polygon(points, UiKit.GOLD)
			else:
				points.append(points[0])
				stars.draw_polyline(points, Color(UiKit.MUTED, 0.7), 1.2, true))
	return stars


func _chapter_caption(chapter: ChapterData) -> String:
	if chapter.track == Campaign.SURVIVAL:
		return tr("EXPEDITION_MODE_SURVIVAL")
	return tr("EXPEDITION_CHAPTER_NUMBER") % chapter.order


func _tile_style(tile: Button, accent: Color, selected: bool) -> void:
	var normal: StyleBoxFlat = MenuSkin.frame(Color(0.2, 0.06, 0.12) if selected else Color(0.07, 0.055, 0.12),
		MenuSkin.LANTERN if selected else Color(accent, 0.55))
	if selected:
		normal.set_border_width_all(3)
	var hover: StyleBoxFlat = MenuSkin.frame(Color(0.16, 0.07, 0.17), accent)
	var disabled: StyleBoxFlat = MenuSkin.frame(Color(0.045, 0.04, 0.07, 0.9), Color(accent, 0.35))
	tile.add_theme_stylebox_override("normal", normal)
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("pressed", normal)
	tile.add_theme_stylebox_override("focus", hover)
	tile.add_theme_stylebox_override("disabled", disabled)
	tile.set_meta(MenuSkin.KEEP_STYLE, true)


# --- Résumé et départ

func _summary(p: ProfileData, arena: ArenaData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ExpeditionSummary"
	panel.custom_minimum_size.x = 340
	panel.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.05, 0.04, 0.1, 0.97), MenuSkin.COPPER))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	box.add_child(_map_preview(arena, 104))
	var chapter: ChapterData = Campaign.chapter_of(arena.id)
	box.add_child(UiKit.caption(_chapter_caption(chapter) + " · " + tr(chapter.name_key) if chapter
		else tr("EXPEDITION_SURVIVAL_TAG"), 11, chapter.color if chapter else MenuSkin.LANTERN))
	var title: Label = UiKit.title(tr(arena.name_key), 22, MenuSkin.PAPER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	box.add_child(UiKit.wrapped(tr(arena.desc_key), 14, UiKit.MUTED))
	var difficulty: DifficultyData = _add_difficulties(box, p)
	var mode: StringName = Campaign.mode_of(difficulty.id)
	var map: CampaignMapData = Campaign.map_data(arena.id)
	if map:
		box.add_child(UiKit.caption(tr("EXPEDITION_OBJECTIVES") % tr(difficulty.name_key), 11, UiKit.MUTED))
		for objective: MapObjectiveData in Campaign.objectives_of(map, mode):
			var ok: bool = Campaign.objective_done(p, arena.id, mode, objective.id)
			box.add_child(UiKit.wrapped(("★  " if ok else "☆  ") + Campaign.objective_text(objective), 13,
				UiKit.GOLD if ok else MenuSkin.PAPER))
	_add_modifiers(box, difficulty)
	var packed: PackedStringArray = []
	for raw: Variant in p.data["shop"]["packed"]:
		var item: ShopItemData = GameDB.shop_items.get(StringName(str(raw)))
		if item:
			packed.append(tr(item.name_key))
	if not packed.is_empty():
		box.add_child(UiKit.wrapped(tr("EXPEDITION_PACKED") % ", ".join(packed), 13, UiKit.GOLD))
	var names: PackedStringArray = []
	for id: StringName in Profile.team():
		names.append(tr(GameDB.monster(id).name_key))
	if not names.is_empty():
		outer.add_child(UiKit.label(tr("EXPEDITION_WITH") % ", ".join(names), 13, UiKit.MUTED))
	var go: Button = UiKit.button(tr("EXPEDITION_DEPART"), _depart, 0)
	go.name = "DepartButton"
	go.custom_minimum_size.y = 56
	go.add_theme_font_override("font", UiKit.font(&"title"))
	go.add_theme_font_size_override("font_size", 22)
	go.add_theme_stylebox_override("normal", MenuSkin.frame(Color(0.3, 0.08, 0.12), MenuSkin.LANTERN))
	go.add_theme_stylebox_override("hover", MenuSkin.frame(Color(0.42, 0.12, 0.16), MenuSkin.PAPER))
	go.set_meta(MenuSkin.KEEP_STYLE, true)
	outer.add_child(go)
	# Salle d'entraînement : essayer l'équipe et le build contre des mannequins, sans rien gagner ni perdre.
	var training: Button = UiKit.button(tr("TRAINING_OPEN"), _train, 0)
	training.name = "TrainingButton"
	training.tooltip_text = tr("TRAINING_OPEN_HINT")
	outer.add_child(training)
	return panel


## Normal, puis Cauchemar une fois la campagne finie. Retourne la difficulté retenue.
func _add_difficulties(box: VBoxContainer, p: ProfileData) -> DifficultyData:
	var current: DifficultyData = GameDB.difficulty(StringName(p.preference("difficulty", "normal")))
	if current == null or not p.is_difficulty_unlocked(current):
		current = GameDB.difficulty(Campaign.NORMAL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for difficulty: DifficultyData in GameDB.difficulties_by_level():
		var unlocked: bool = p.is_difficulty_unlocked(difficulty)
		var b: Button = HunterTreeSkin.button(tr(difficulty.name_key), _set_pref.bind("difficulty", String(difficulty.id)),
			difficulty == current)
		b.name = "Difficulty_" + String(difficulty.id)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 36
		b.disabled = not unlocked
		b.tooltip_text = tr(difficulty.desc_key) if unlocked else tr("EXPEDITION_NIGHTMARE_LOCKED")
		row.add_child(b)
	box.add_child(UiKit.wrapped(tr(current.desc_key), 13, UiKit.MUTED))
	return current


## Pactes de risque : modificateurs cumulables, réservés au Cauchemar.
func _add_modifiers(box: VBoxContainer, difficulty: DifficultyData) -> void:
	if GameDB.modifiers.is_empty() or difficulty.level < 1:
		return
	box.add_child(UiKit.caption(tr("EXPEDITION_MODIFIERS"), 11, UiKit.MUTED))
	var chosen: PackedStringArray = profile().preference("modifiers", "").split(",", false)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	box.add_child(flow)
	var bonus: float = 0.0
	for id: StringName in GameDB.sorted_ids(GameDB.modifiers):
		var modifier: RunModifierData = GameDB.modifier(id)
		var allowed: bool = difficulty.level >= modifier.min_difficulty
		var on: bool = chosen.has(String(id)) and allowed
		if on:
			bonus += modifier.reward_bonus
		var text: String = "%s +%d %%" % [tr(modifier.name_key), int(round(modifier.reward_bonus * 100.0))]
		var button: Button = HunterTreeSkin.button(text, _toggle_modifier.bind(String(id)), on)
		button.tooltip_text = tr(modifier.desc_key)
		button.disabled = not allowed
		flow.add_child(button)
	box.add_child(UiKit.label(tr("EXPEDITION_MODIFIERS_BONUS") % int(round(bonus * 100.0)), 13, UiKit.GOLD))


func _toggle_modifier(id: String) -> void:
	var chosen: PackedStringArray = profile().preference("modifiers", "").split(",", false)
	if chosen.has(id):
		chosen.remove_at(chosen.find(id))
	else:
		chosen.append(id)
	_set_pref("modifiers", ",".join(chosen))


## Ajoute l'Écho à l'équipe (s'il reste une place) ou l'en retire (il en reste toujours un).
func _select_starter(id: StringName) -> void:
	var team: Array[StringName] = Profile.team()
	if team.has(id):
		if team.size() > 1:
			team.erase(id)
	elif team.size() < GameDB.balance.max_team_slots:
		team.append(id)
	Profile.set_team(team)
	refuge.commit()


func _set_pref(key: String, value: String) -> void:
	profile().set_preference(key, value)
	refuge.commit()


func _toggle(id: StringName, key: String) -> void:
	var entry: Dictionary = profile().mastery_entry(id)
	entry[key] = not bool(entry.get(key, false))
	refuge.commit()


func _train() -> void:
	Audio.play_sfx(&"ui_click")
	Router.start_run(Profile.make_training_setup())


func _depart() -> void:
	Audio.play_sfx(&"ui_click")
	Router.start_run(Profile.make_run_setup(&""))

## Aperçu léger du décor réel, référencé dans le manifeste ; aucune texture de niveau chargée ici.
func _map_preview(arena: ArenaData, height: float) -> TextureRect:
	var image := TextureRect.new()
	image.name = "MapPreview_" + String(arena.id)
	var entry: Dictionary = Assets.entry(arena.environment_id)
	var path: String = str(entry.get("menu_preview", ""))
	if path != "" and ResourceLoader.exists(path):
		image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.custom_minimum_size.y = height
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image
