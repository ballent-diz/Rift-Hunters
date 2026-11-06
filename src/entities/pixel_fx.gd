class_name PixelFx
extends Node2D
## Effets génériques des Corrompus aux couleurs de leur famille (impact quand ils sont touchés, disparition quand ils
## meurent) : feuilles générées avec pixelfx (MIT, tools/art/build_pixelfx.py), une par effet et par famille dans
## assets/vfx/pixelfx/<effet>/<famille>.png (+ .json : cadres, pivot, cadence). Présentation seulement : un effet
## refusé (plafond atteint) ne change rien au jeu. Tout est dessiné par ce seul nœud (pas de nœud par effet).

const ROOT := "res://assets/vfx/pixelfx/%s/%s"
const DEFAULT_FAMILY := &"violet"
## Effets affichés en même temps au plus, et nouveaux impacts par image au plus (les hordes frappées en masse).
const MAX_ACTIVE := 48
const MAX_HITS_PER_FRAME := 5
## Délai minimal entre deux impacts sur un même Corrompu.
const HIT_INTERVAL := 0.15
## Vitesse de lecture : la disparition (1,6 s dans pixelfx) est raccourcie pour ne pas encombrer l'écran.
const SPEED := {&"hit": 1.0, &"death": 1.6}

var ctx: RunContext
## Feuille chargée par « effet/famille » : {"texture", "rects", "pivot", "fps"} (vide si absente).
var _sheets: Dictionary = {}
## Effets en cours : {"sheet", "pos", "t", "speed", "flip"}.
var _active: Array[Dictionary] = []
var _last_hit: Dictionary = {}
var _hits_this_frame: int = 0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "PixelFx"
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func family_of(enemy: Enemy) -> StringName:
	return enemy.data.family if enemy.data and enemy.data.family != &"" else DEFAULT_FAMILY


## Impact sur un Corrompu touché, tourné dans le sens du coup (depuis le Chasseur).
func hit(enemy: Enemy) -> void:
	if _hits_this_frame >= MAX_HITS_PER_FRAME:
		return
	var id: int = enemy.get_instance_id()
	if ctx.time - float(_last_hit.get(id, -1.0)) < HIT_INTERVAL:
		return
	_last_hit[id] = ctx.time
	_hits_this_frame += 1
	var flip: bool = ctx.player != null and enemy.position.x < ctx.player.global_position.x
	play(&"hit", family_of(enemy), enemy.position, flip)


## Disparition d'un Corrompu ; les élites et les boss gardent en plus leurs débris (et sans feuille, ou plafond
## atteint, les débris seuls, comme avant).
func death(enemy: Enemy) -> void:
	_last_hit.erase(enemy.get_instance_id())
	var shown: bool = not enemy.is_boss and play(&"death", family_of(enemy), enemy.position)
	if not shown or enemy.is_elite or enemy.is_boss:
		var tint: Color = enemy.data.visual.primary.lightened(0.3) if enemy.data else Color(0.8, 0.5, 1.0)
		ctx.fx.debris(enemy.position, tint, 14 if (enemy.is_elite or enemy.is_boss) else 4)


func play(effect: StringName, family: StringName, pos: Vector2, flip: bool = false) -> bool:
	if _active.size() >= MAX_ACTIVE:
		return false
	var sheet: Dictionary = _sheet(effect, family)
	if sheet.is_empty():
		return false
	_active.append({"sheet": sheet, "pos": pos, "t": 0.0, "speed": float(SPEED.get(effect, 1.0)), "flip": flip})
	return true


func active_count() -> int:
	return _active.size()


func _sheet(effect: StringName, family: StringName) -> Dictionary:
	var key: String = "%s/%s" % [effect, family]
	if _sheets.has(key):
		return _sheets[key]
	var sheet: Dictionary = {}
	var base: String = ROOT % [effect, family]
	if ResourceLoader.exists(base + ".png") and FileAccess.file_exists(base + ".json"):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		if data is Dictionary:
			var rects: Array[Rect2] = []
			var frames: Variant = data["frames"]
			for frame: Variant in (frames if frames is Array else (frames as Dictionary).values()):
				var r: Dictionary = frame["frame"]
				rects.append(Rect2(r["x"], r["y"], r["w"], r["h"]))
			var meta: Dictionary = data["meta"]["pixelfx"]
			sheet = {"texture": load(base + ".png"), "rects": rects, "fps": float(meta["fps"]),
				"pivot": Vector2(meta["pivot"][0], meta["pivot"][1])}
	_sheets[key] = sheet
	return sheet


func step(delta: float) -> void:
	_hits_this_frame = 0
	var i: int = _active.size() - 1
	while i >= 0:
		var fx: Dictionary = _active[i]
		fx["t"] = float(fx["t"]) + delta * float(fx["speed"])
		var sheet: Dictionary = fx["sheet"]
		if int(float(fx["t"]) * float(sheet["fps"])) >= (sheet["rects"] as Array).size():
			_active[i] = _active[_active.size() - 1]
			_active.pop_back()
		i -= 1
	if _last_hit.size() > 512:
		_last_hit.clear()
	queue_redraw()


func _draw() -> void:
	for fx: Dictionary in _active:
		var sheet: Dictionary = fx["sheet"]
		var rects: Array = sheet["rects"]
		var frame: int = mini(int(float(fx["t"]) * float(sheet["fps"])), rects.size() - 1)
		var rect: Rect2 = rects[frame]
		var pivot: Vector2 = sheet["pivot"]
		var pos: Vector2 = fx["pos"]
		if bool(fx["flip"]):
			draw_set_transform(pos, 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect_region(sheet["texture"], Rect2(-pivot, rect.size), rect)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect_region(sheet["texture"], Rect2(pos - pivot, rect.size), rect)
