class_name EndingScreen
extends Control
## Scène de fin du jeu (victoire sur la dernière carte de la campagne, Campaign.final_map) : l'Œil de l'Abyssarque se
## referme sur un fond de Faille qui s'apaise, puis le voyage défile, un monde par chapitre à sa couleur, avant le mot
## de la fin. Une touche ou un clic passe à la carte suivante ; « Générique » ouvre CreditsScreen. `finished` rend la
## main à l'écran des résultats.

signal finished

## Durée d'une carte de texte (fondu compris) et des fondus.
const CARD_TIME := 4.2
const FADE := 0.8
const EYE_TIME := 3.6
const MOTES := 70
const RIFT := Color(0.72, 0.45, 1.0)
const NIGHT := Color(0.03, 0.02, 0.06)
const EYE_VISUAL := &"boss.abyssarch.death"

## Cartes : [texte, couleur] ; la dernière est le mot de la fin.
var cards: Array[Array] = []
var card_index: int = -1
var _card_time: float = 0.0
var _time: float = 0.0
var _calm: float = 0.0
var _motes: Array[Vector3] = []
var _title: Label
var _line: Label
var _eye: AnimatedSprite2D
var _buttons: HBoxContainer
var _done: bool = false


## `nightmare_new` : le Cauchemar vient de s'ouvrir avec cette victoire (dernière carte).
func setup(nightmare_new: bool) -> void:
	cards.clear()
	cards.append([tr("ENDING_EYE"), RIFT])
	var chapters: Array[ChapterData] = Campaign.chapters_of(Campaign.MAIN)
	for i: int in chapters.size():
		cards.append([tr("ENDING_CHAPTER_%d" % mini(i + 1, 5)), chapters[i].color])
	cards.append([tr("ENDING_HUNTER"), UiKit.GOLD])
	if nightmare_new:
		cards.append([tr("ENDING_NIGHTMARE"), UiKit.DANGER])


func _ready() -> void:
	name = "EndingScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuSkin.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if cards.is_empty():
		setup(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 25
	for i: int in MOTES:
		_motes.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))
	var frames: SpriteFrames = Assets.get_sprite_frames(EYE_VISUAL)
	if frames and frames.has_animation(&"eye_close"):
		_eye = AnimatedSprite2D.new()
		_eye.sprite_frames = frames
		_eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_eye.centered = false
		_eye.offset = -Assets.anchor(EYE_VISUAL)
		_eye.speed_scale = 0.6
		_eye.play(&"eye_close")
		add_child(_eye)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	column.offset_top = -300.0
	column.offset_bottom = -110.0
	column.offset_left = -560.0
	column.offset_right = 560.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	_title = UiKit.title(tr("ENDING_TITLE"), 64, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.modulate.a = 0.0
	column.add_child(_title)
	_line = UiKit.label("", 26, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.modulate.a = 0.0
	column.add_child(_line)
	_buttons = HBoxContainer.new()
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_buttons.offset_top = -84.0
	_buttons.offset_bottom = -32.0
	_buttons.offset_left = -300.0
	_buttons.offset_right = 300.0
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	add_child(_buttons)
	_buttons.add_child(UiKit.button(tr("ENDING_SKIP"), _finish_cards, 220))


func _process(delta: float) -> void:
	_time += delta
	if _eye:
		_eye.position = size * Vector2(0.5, 0.12)
		_eye.scale = Vector2.ONE * size.y / 900.0
		_eye.modulate.a = clampf(1.0 - (_time - EYE_TIME) / FADE, 0.0, 1.0)
	_calm = clampf(_time / (EYE_TIME + CARD_TIME * cards.size()), 0.0, 1.0)
	if not _done and _time >= EYE_TIME * 0.5:
		_card_time += delta
		if card_index < 0 or _card_time >= CARD_TIME:
			_next_card()
	if card_index >= 0 and not _done:
		var t: float = _card_time
		_line.modulate.a = clampf(minf(t / FADE, (CARD_TIME - t) / FADE), 0.0, 1.0)
	queue_redraw()


func _next_card() -> void:
	card_index += 1
	_card_time = 0.0
	if card_index >= cards.size():
		_finish_cards()
		return
	_line.text = String(cards[card_index][0])
	_line.add_theme_color_override("font_color", (cards[card_index][1] as Color).lightened(0.35))


## Fin des cartes : le titre reste, avec « Générique » et « Continuer ».
func _finish_cards() -> void:
	if _done:
		return
	_done = true
	card_index = cards.size()
	_line.text = tr("ENDING_THANKS")
	_line.remove_theme_color_override("font_color")
	_line.modulate.a = 1.0
	create_tween().tween_property(_title, "modulate:a", 1.0, FADE)
	UiKit.clear(_buttons)
	_buttons.add_child(UiKit.button(tr("ENDING_CREDITS"), _show_credits, 220))
	var go: Button = UiKit.button(tr("ENDING_CONTINUE"), _close, 220)
	_buttons.add_child(go)
	go.grab_focus.call_deferred()


func _show_credits() -> void:
	var credits := CreditsScreen.new()
	credits.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(credits)


func _close() -> void:
	finished.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_card_time = CARD_TIME
		accept_event()


## Fond : nuit de la Faille dont les filaments violets s'apaisent au fil du voyage.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NIGHT)
	var glow: float = 1.0 - _calm * 0.7
	for mote: Vector3 in _motes:
		var y: float = fmod(mote.y - _time * 0.015 * (0.5 + mote.x), 1.0)
		if y < 0.0:
			y += 1.0
		var pos := Vector2(mote.x * size.x + sin(_time * 0.4 + mote.z) * 12.0, y * size.y)
		var pulse: float = 0.5 + 0.5 * sin(_time * 1.5 + mote.z)
		draw_circle(pos, 1.5 + 2.0 * pulse, Color(RIFT, (0.15 + 0.35 * pulse) * glow))
	var center: Vector2 = size * Vector2(0.5, 0.38)
	for k: int in 4:
		var r: float = 120.0 + 70.0 * k + 10.0 * sin(_time * 0.8 + k)
		draw_arc(center, r, _time * 0.2 * (k + 1), _time * 0.2 * (k + 1) + PI * 1.3, 48, Color(RIFT, 0.12 * glow), 3.0)
