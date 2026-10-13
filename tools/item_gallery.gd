extends Control
## Planche de contrôle des illustrations, séparée des écrans jouables.
## godot --path . res://tools/item_gallery.tscn -- --kind=upgrade|relic|offer --out=<dossier> --locale=fr


func _ready() -> void:
	var kind: String = "upgrade"
	var out: String = "user://item_gallery"
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"kind": kind = parts[1]
			"out": out = parts[1]
			"locale": Settings.set_locale(parts[1])
	theme = MenuSkin.theme()
	MenuSkin.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var heading: String = tr("BESTIARY_RELICS") if kind == "relic" else tr("OFFER_TAG_UPGRADE")
	box.add_child(UiKit.label(heading, 24, MenuSkin.PAPER, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for key: String in ItemArt.entries():
		if not key.begins_with(kind + "."):
			continue
		var id := StringName(key.get_slice(".", 1))
		var accent: Color = UiKit.ACCENT
		var title: String = ""
		if kind == "upgrade":
			var upgrade: UpgradeData = GameDB.upgrade(id)
			title = tr(upgrade.name_key)
			accent = upgrade.color
		elif kind == "relic":
			var relic: RelicData = GameDB.relic(id)
			title = tr(relic.name_key)
			accent = relic.color
		else:
			title = tr("OFFER_HEAL_TITLE") if id == &"heal" else tr("OFFER_SHARDS_TITLE")
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", MenuSkin.frame())
		grid.add_child(panel)
		var tile := VBoxContainer.new()
		panel.add_child(tile)
		tile.add_child(ItemArt.portrait(kind, id, accent, 80))
		var label: Label = UiKit.label(title, 14, MenuSkin.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tile.add_child(label)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join(kind + "s.png")
	image.save_png(path)
	print("Capture : ", path)
	get_tree().quit()
