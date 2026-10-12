extends TestCase
## Pipeline d'assets : manifeste, validateur, placeholders.


func test_manifest_loaded() -> void:
	check(not Assets.manifest.is_empty(), "manifeste chargé")


func test_every_visual_id_is_declared() -> void:
	for id: StringName in GameDB.monsters:
		var m: MonsterData = GameDB.monsters[id]
		check(Assets.manifest.has(String(m.visual.visual_id)), "%s absent du manifeste" % m.visual.visual_id)
	for id: StringName in GameDB.enemies:
		var e: EnemyData = GameDB.enemies[id]
		check(Assets.manifest.has(String(e.visual.visual_id)), "%s absent du manifeste" % e.visual.visual_id)
	for id: StringName in GameDB.bosses:
		var b: BossData = GameDB.bosses[id]
		check(Assets.manifest.has(String(b.visual.visual_id)), "%s absent du manifeste" % b.visual.visual_id)


func test_manifest_has_no_errors() -> void:
	for entry: Dictionary in AssetValidator.validate_manifest(Assets.manifest):
		check(entry["status"] != "ERROR", "%s : %s" % [entry["id"], "; ".join(entry["messages"])])


func test_validator_detects_bad_sheet() -> void:
	var opaque := Image.create(100, 64, false, Image.FORMAT_RGB8)
	var messages: PackedStringArray = AssetValidator.check_image(opaque, [64, 64], {"idle": {"row": 1, "frames": 3}}, [10, 90])
	var text: String = " ".join(messages)
	check(text.contains("multiples"), "dimensions non multiples détectées")
	check(text.contains("transparence"), "fond opaque détecté")
	check(text.contains("hors de la feuille"), "ligne d'animation hors feuille détectée")
	check(text.contains("ancre"), "ancre hors cellule détectée")


func test_validator_accepts_good_sheet() -> void:
	var sheet := Image.create(128, 64, false, Image.FORMAT_RGBA8)
	sheet.fill_rect(Rect2i(20, 20, 20, 20), Color.RED)
	var messages: PackedStringArray = AssetValidator.check_image(sheet, [64, 64], {"idle": {"row": 0, "frames": 2}}, [32, 56])
	check(messages.is_empty(), "feuille valide acceptée : %s" % "; ".join(messages))


func test_placeholder_generation() -> void:
	var visual: VisualData = GameDB.monster(&"ashblade").visual
	var result: Array = Assets.placeholder(visual)
	var texture: Texture2D = result[0]
	var image: Image = texture.get_image()
	var center: Color = image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	check(center.a > 0.5, "placeholder opaque au centre")
	check(image.get_pixel(0, 0).a < 0.05, "placeholder transparent au coin")


func test_missing_sheet_falls_back_to_placeholder() -> void:
	check(Assets.get_sprite_frames(&"monster.ashblade") == null, "feuille absente → pas de SpriteFrames")
	var visual := EntityVisual.new()
	visual.setup(GameDB.monster(&"ashblade").visual)
	check(visual.get_child_count() == 1 and visual.get_child(0) is Sprite2D, "EntityVisual utilise le placeholder")
	visual.free()
