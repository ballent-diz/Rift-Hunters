extends Node2D
## Contrôle graphique hors partie : lit uniquement le manifeste, sans données de gameplay C7.

const IDS: Array[String] = [
	"ashblade", "glimmerwing", "gloommaw", "mirrorling", "mossback", "thornweave", "voltwisp",
	"cinderwing", "magmander", "hollowflame", "moonspore", "gravishell", "grovestag",
	"sunclaw", "glowmoth", "stormshell",
]
const NAMES: Array[String] = [
	"Cendrelame", "Lucivelle", "Gueule-d’ombre", "Mirelle", "Mousseroc", "Ronceline", "Fulgurine",
	"Pyraile", "Scoriade", "Spectrâtre", "Sporelune", "Gravelune", "Sylvécaille",
	"Solgriffe", "Lueurine", "Égidor",
]
const OUT := "res://docs/previews/c8/"

var _world: Node2D


func _ready() -> void:
	get_window().size = Vector2i(2880, 720)
	get_window().content_scale_size = Vector2i(2880, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	_world = Node2D.new()
	_world.scale = Vector2.ONE * (4.0 / 3.0)
	add_child(_world)
	_label("LOT C8 · 16 ÉCHOS · ÉCHELLE DU JEU (ZOOM 4/3)", Vector2(40, 50), 28)
	_label("Comparaison graphique hors partie · Chasseur à gauche · aucune teinte de maîtrise", Vector2(40, 100), 18)
	_add_sprite("player.hunter", Vector2(100, 420))
	_label("Chasseur", Vector2(60, 445), 15)
	for i: int in IDS.size():
		var x: float = 260.0 + i * 164.0
		_add_sprite("monster." + IDS[i], Vector2(x, 420))
		_label(NAMES[i], Vector2(x - 60, 445), 15)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "roster_16.png")
	for child: Node in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	_world = Node2D.new()
	_world.scale = Vector2.ONE * (4.0 / 3.0)
	add_child(_world)
	var ground := ArenaGround.new()
	_world.add_child(ground)
	ground.setup(load("res://data/arenas/three_rifts.tres") as ArenaData, 1)
	ground.position = Vector2(1250, 360)
	_label("C8 · CONTRÔLE SUR LE SOL DES RUINES DES CASCADES", Vector2(25, 22), 20)
	_add_sprite("player.hunter", Vector2(70, 120))
	for i: int in IDS.size():
		var pos := Vector2(180 + (i % 4) * 285, 205 + (i / 4) * 145)
		_add_sprite("monster." + IDS[i], pos)
		_label(NAMES[i], pos + Vector2(-50, 15), 15)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "cascade_roster.png")
	print("C8 : captures du roster et du sol enregistrées.")
	get_tree().quit()


func _add_sprite(id: String, screen_position: Vector2) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.get_sprite_frames(StringName(id))
	sprite.centered = false
	sprite.offset = -Assets.anchor(StringName(id))
	sprite.scale = Vector2.ONE * Assets.pixel_scale(StringName(id))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = screen_position / (4.0 / 3.0)
	sprite.play(&"idle")
	_world.add_child(sprite)


func _label(text: String, pos: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", load("res://assets/fonts/inter/Inter-Variable.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
