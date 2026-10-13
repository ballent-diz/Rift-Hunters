class_name ItemArt
extends RefCounted
## Illustrations de menu : le catalogue ne contient aucune règle ni valeur de gameplay.

const CATALOG_PATH := "res://assets/ui/items/catalog.json"

static var _entries: Dictionary = {}
static var _textures: Dictionary = {}


static func entries() -> Dictionary:
	if _entries.is_empty():
		var catalog: Resource = load(CATALOG_PATH)
		if catalog is JSON:
			_entries = (catalog as JSON).data.get("entries", {})
	return _entries


static func texture(kind: String, id: StringName) -> Texture2D:
	var key: String = kind + "." + String(id)
	if _textures.has(key):
		return _textures[key]
	var entry: Dictionary = entries().get(key, {})
	var path: String = entry.get("image", "")
	var image: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	if image:
		_textures[key] = image
	return image


static func portrait(kind: String, id: StringName, accent: Color, height: float = 144) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ItemPortrait"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame: StyleBoxFlat = MenuSkin.frame(Color(0.025, 0.02, 0.07, 0.8), accent.darkened(0.45))
	frame.set_border_width_all(1)
	frame.content_margin_top = 8
	frame.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", frame)
	var art := TextureRect.new()
	art.name = "Illustration"
	art.texture = texture(kind, id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0, height)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(art)
	return panel


static func add_to_card(card: Button, kind: String, id: StringName, accent: Color) -> void:
	if texture(kind, id) == null:
		return
	var box: VBoxContainer = card.get_child(0)
	var art: PanelContainer = portrait(kind, id, accent)
	box.add_child(art)
	box.move_child(art, 1)
	card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, 360)
