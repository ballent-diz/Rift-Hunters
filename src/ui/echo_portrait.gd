class_name EchoPortrait
extends Control
## Aperçu du même EntityVisual que les alliés en partie, jamais une illustration réinventée.

var visual: EntityVisual
var visual_data: VisualData


func setup(monster: MonsterData, palette: Array = [], evolution: EvolutionData = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(120, 112)
	visual_data = evolution.visual if evolution and evolution.visual else monster.visual
	visual = EntityVisual.new()
	add_child(visual)
	# Même remplacement que Ally._refresh_visual() lorsqu'une évolution n'a pas de feuille dédiée.
	if evolution and evolution.visual and not Assets.has_sheet(visual_data.visual_id) \
			and Assets.has_sheet(monster.visual.visual_id):
		visual_data = monster.visual
		visual.setup(visual_data, evolution.visual.primary)
	elif palette.size() == 2 and evolution == null:
		visual.setup(visual_data, palette[0], palette[1])
	else:
		visual.setup(visual_data)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	if visual == null:
		return
	var cell: Array = Assets.entry(visual_data.visual_id).get("cell", [64, 64])
	var pixels := Vector2(float(cell[0]), float(cell[1]))
	var unit: float = Assets.pixel_scale(visual_data.visual_id)
	var zoom: float = maxf(0.1, minf((size.x - 12) / (pixels.x * unit), (size.y - 12) / (pixels.y * unit)))
	visual.scale = Vector2.ONE * zoom
	visual.position = size * 0.5 + (Assets.anchor(visual_data.visual_id) - pixels * 0.5) * unit * zoom


static func profile_palette(monster: MonsterData) -> Array:
	return Mastery.palette(Profile.profile, monster) if bool(Profile.profile.mastery_entry(monster.id).get("use_palette", false)) \
		else []


static func add_to_card(card: Button, monster: MonsterData, palette: Array = [], evolution: EvolutionData = null) -> void:
	var box: VBoxContainer = card.get_child(0)
	var portrait := EchoPortrait.new()
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.setup(monster, palette, evolution)
	box.add_child(portrait)
	box.move_child(portrait, 1)
	card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, 320)
