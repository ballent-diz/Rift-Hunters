class_name PixelFx
extends Node2D
## Effets génériques des Corrompus aux couleurs de leur famille (impact quand ils sont touchés, disparition quand ils
## meurent) : feuilles générées avec pixelfx (MIT, tools/art/build_pixelfx.py), une par effet et par famille dans
## assets/vfx/pixelfx/<effet>/<famille>.png (+ .json : cadres, pivot, cadence). Présentation seulement : un effet
## refusé (plafond atteint) ne change rien au jeu. Tout est dessiné par ce seul nœud (pas de nœud par effet).
## Compétences (docs/design/VFX_COMPETENCES.md) : le catalogue assets/vfx/pixelfx/techniques.json associe à chaque
## compétence d'un Corrompu ou d'un boss ses effets, à l'élément de sa famille : annonce sur le lanceur (cast), impact
## quand sa zone frappe, état en boucle qui le suit, tir qui touche.

const ROOT := "res://assets/vfx/pixelfx/%s/%s"
const DEFAULT_FAMILY := &"violet"
## Effets affichés en même temps au plus, et nouveaux impacts par image au plus (les hordes frappées en masse).
const MAX_ACTIVE := 48
const MAX_HITS_PER_FRAME := 5
## Délai minimal entre deux impacts sur un même Corrompu.
const HIT_INTERVAL := 0.15
## Vitesse de lecture : la disparition (1,6 s dans pixelfx) est raccourcie pour ne pas encombrer l'écran.
const SPEED := {&"hit": 1.0, &"death": 1.6, &"ring_burst": 2.0, &"ring_dust": 1.5}
## Anneaux des boss (sorts en cercle) : poussière le long du front, au plus une bouffée par RING_DUST_STEP unités de
## circonférence, et RING_DUST_MAX par passage ; la charge et l'onde de choc sont agrandies (pixels nets).
const RING_DUST_STEP := 260.0
const RING_DUST_MAX := 3
const RING_SCALE := 2.0
const CATALOG := "res://assets/vfx/pixelfx/techniques.json"
## Effets des compétences des boss, agrandis comme leur corps.
const BOSS_SCALE := 1.6
## États en boucle (rage, aura…) au plus, pour ne jamais saturer l'écran.
const MAX_STATES := 12

static var _catalog: Dictionary = {}

var ctx: RunContext
## Feuille chargée par « effet/famille » : {"texture", "rects", "pivot", "fps"} (vide si absente).
var _sheets: Dictionary = {}
var _projectile_art: Dictionary = {}
## Effets en cours : {"sheet", "pos", "t", "speed", "flip"}.
var _active: Array[Dictionary] = []
var _last_hit: Dictionary = {}
var _hits_this_frame: int = 0
## Dernière compétence de chaque lanceur (identifiant de source des zones) : [compétence, famille, boss].
var _last_kind: Dictionary = {}


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "PixelFx"
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func family_of(enemy: Enemy) -> StringName:
	if enemy.boss_data:
		return StringName(str((catalog().get("boss_families", {}) as Dictionary).get(String(enemy.boss_data.id),
			DEFAULT_FAMILY)))
	return enemy.data.family if enemy.data and enemy.data.family != &"" else DEFAULT_FAMILY


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG)) if FileAccess.file_exists(CATALOG) \
			else null
		_catalog = data if data is Dictionary else {"effects": {}}
	return _catalog


## Effets d'une compétence : {moment: effet ou [effets], time, param} ; vide si rien n'est prévu. Un boss prend
## d'abord ses effets propres, puis les motifs communs s'il a une famille d'effets.
static func entry_of(source: String, boss: bool, kind: StringName) -> Dictionary:
	var c: Dictionary = catalog()
	if boss:
		var own: Dictionary = (c.get("bosses", {}) as Dictionary).get(source, {})
		if own.has(String(kind)):
			return own[String(kind)]
		if (c.get("boss_families", {}) as Dictionary).has(source):
			return (c.get("boss_common", {}) as Dictionary).get(String(kind), {})
		return {}
	return ((c.get("enemies", {}) as Dictionary).get(source, {}) as Dictionary).get(String(kind), {})


static func source_of(enemy: Enemy) -> String:
	return String(enemy.boss_data.id) if enemy.boss_data else (String(enemy.data.id) if enemy.data else "")


## Compétence lancée : effet d'annonce sur le lanceur et état éventuel ; la compétence est retenue pour ses impacts.
func technique(enemy: Enemy, kind: StringName, params: Dictionary = {}) -> void:
	var boss: bool = enemy.boss_data != null
	var source: String = source_of(enemy)
	var entry: Dictionary = entry_of(source, boss, kind)
	if entry.is_empty():
		return
	var family: StringName = family_of(enemy)
	_last_kind[source] = [kind, family, boss]
	var at: Vector2 = ctx.player.global_position if entry.get("at", "") == "target" and ctx.player else enemy.position
	_play_all(entry.get("cast"), family, at, boss)
	if entry.has("state"):
		var time: float = float(entry.get("time", params.get(str(entry.get("param", "duration")), 3.0)))
		for effect: Variant in (entry["state"] if entry["state"] is Array else [entry["state"]]):
			state(enemy, StringName(str(effect)), time)


## Moment propre à une compétence (arrivée d'une téléportation…), sur `pos`.
func moment(enemy: Enemy, kind: StringName, moment_name: String, pos: Vector2) -> void:
	var boss: bool = enemy.boss_data != null
	_play_all(entry_of(source_of(enemy), boss, kind).get(moment_name), family_of(enemy), pos, boss)


## Zone d'un lanceur qui frappe : effet d'impact de sa dernière compétence.
func impact(source: StringName, pos: Vector2) -> void:
	var last: Array = _last_kind.get(String(source), [])
	if not last.is_empty():
		_play_all(entry_of(String(source), last[2], last[0]).get("impact"), last[1], pos, last[2])


## Tir qui touche : attribution propre au lanceur, puis impact discret dans la palette de sa famille.
func shot(source: StringName, pos: Vector2) -> void:
	var entry: Dictionary = entry_of(String(source), false, &"shot")
	var data: EnemyData = GameDB.enemies.get(source)
	if not entry.is_empty() and data:
		_play_all(entry.get("shot"), data.family, pos, false)
		return
	var family: String = String(data.family) if data else str(catalog()["boss_families"].get(String(source), ""))
	_play_all((catalog().get("shots", {}) as Dictionary).get(family), StringName(family), pos, false)


## Corps des tirs sans scène peinte : feuille partagée, sans nœud ni animation indépendante du projectile.
func projectile_art(source: StringName) -> Dictionary:
	if _projectile_art.has(source):
		return _projectile_art[source]
	var data: EnemyData = GameDB.enemies.get(source)
	var family: String = String(data.family) if data else str(catalog()["boss_families"].get(String(source), ""))
	var own: Dictionary = entry_of(String(source), false, &"shot")
	var effect := StringName(own.get("flight", catalog().get("flights", {}).get(family, "")))
	var sheet: Dictionary = _sheet(effect, StringName(family)) if effect != &"" else {}
	var art: Dictionary = {}
	if not sheet.is_empty():
		var spec: Dictionary = catalog()["effects"][String(effect)]
		var offset: Array = spec.get("flight_origin", [0, 0])
		art = {"sheet": sheet, "radius": float(spec.get("flight_radius", 16.0)),
			"offset": Vector2(offset[0], offset[1]), "directional": bool(spec.get("flight_directional", false))}
	_projectile_art[source] = art
	return art


func draw_projectile(canvas: Node2D, p: Projectile) -> void:
	var art: Dictionary = p.pixel_art
	var sheet: Dictionary = art["sheet"]
	var rects: Array = sheet["rects"]
	var frame: int = int(p.visual_time * float(sheet["fps"])) % rects.size()
	var size: float = clampf(p.radius / float(art["radius"]), 0.2, 2.0)
	canvas.draw_set_transform(p.position, p.velocity.angle() if art["directional"] else 0.0, Vector2.ONE * size)
	canvas.draw_texture_rect_region(sheet["texture"], Rect2(-(sheet["pivot"] as Vector2)
		- (art["offset"] as Vector2), (rects[frame] as Rect2).size), rects[frame])
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rayon déclenché après son annonce, orienté et limité à la portée réellement libre.
func beam(source: StringName, kind: StringName, origin: Vector2, direction: Vector2, length: float,
		width: float, duration: float) -> bool:
	var entry: Dictionary = entry_of(String(source), true, kind)
	var effect := StringName(entry.get("beam", ""))
	var family := StringName(catalog()["boss_families"].get(String(source), ""))
	var sheet: Dictionary = _sheet(effect, family) if effect != &"" else {}
	if sheet.is_empty() or _active.size() >= MAX_ACTIVE or length <= 0.0:
		return false
	var spec: Dictionary = catalog()["effects"][String(effect)]
	var pivot: Array = spec.get("beam_origin", [0.0, 0.0])
	_active.append({"sheet": sheet, "pos": origin, "t": 0.0, "speed": 1.0, "flip": false,
		"rotation": direction.angle(), "stretch": Vector2(length / float(spec["beam_length"]),
			width / float(spec["beam_width"])), "offset": Vector2(pivot[0], pivot[1]), "life": duration})
	return true


## Apparition d'un Corrompu : état permanent éventuel (aura d'un gardien…).
func spawned(enemy: Enemy) -> void:
	var entry: Dictionary = entry_of(source_of(enemy), false, &"spawn")
	if entry.has("state"):
		state(enemy, StringName(str(entry["state"])), float(entry.get("time", -1.0)))


## Effet en boucle qui suit `enemy` pendant `time` secondes (négatif : jusqu'à sa mort).
func state(enemy: Enemy, effect: StringName, time: float) -> void:
	var states: int = 0
	for fx: Dictionary in _active:
		if fx.has("follow"):
			states += 1
	var sheet: Dictionary = _sheet(effect, family_of(enemy))
	if states >= MAX_STATES or sheet.is_empty() or _active.size() >= MAX_ACTIVE:
		return
	_active.append({"sheet": sheet, "pos": enemy.position, "t": 0.0, "speed": 1.0, "flip": false,
		"scale": _scale_of(effect, enemy.boss_data != null), "follow": enemy,
		"until": INF if time < 0.0 else ctx.time + time})


func _play_all(value: Variant, family: StringName, pos: Vector2, boss: bool) -> void:
	if value == null:
		return
	for effect: Variant in (value if value is Array else [value]):
		var id := StringName(str(effect))
		var spec: Dictionary = (catalog().get("effects", {}) as Dictionary).get(String(id), {})
		play(id, family, pos, ctx.player != null and pos.x > ctx.player.global_position.x, _scale_of(id, boss),
			float(spec.get("speed", 0.0)))


func _scale_of(effect: StringName, boss: bool) -> float:
	var spec: Dictionary = (catalog().get("effects", {}) as Dictionary).get(String(effect), {})
	return float(spec.get("scale", 1.0)) * (BOSS_SCALE if boss else 1.0)


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


func play(effect: StringName, family: StringName, pos: Vector2, flip: bool = false, scale: float = 1.0,
		speed: float = 0.0) -> bool:
	if _active.size() >= MAX_ACTIVE:
		return false
	var sheet: Dictionary = _sheet(effect, family)
	if sheet.is_empty():
		return false
	_active.append({"sheet": sheet, "pos": pos, "t": 0.0, "speed": speed if speed > 0.0 else float(SPEED.get(effect, 1.0)),
		"flip": flip, "scale": scale})
	return true


## Charge d'un sort en cercle : l'implosion se resserre sur le boss pendant toute l'annonce (`duration`).
func ring_charge(pos: Vector2, family: StringName, duration: float) -> void:
	var sheet: Dictionary = _sheet(&"ring_charge", family)
	if sheet.is_empty() or duration <= 0.05:
		return
	var length: float = (sheet["rects"] as Array).size() / float(sheet["fps"])
	play(&"ring_charge", family, pos, false, RING_SCALE, length / duration)


## Départ de l'anneau : onde de choc au centre.
func ring_burst(pos: Vector2, family: StringName) -> void:
	play(&"ring_burst", family, pos, false, RING_SCALE)


## Poussière soulevée par le front de l'anneau (rayon `radius`), hors des brèches (`safe` : angle -> vrai si brèche).
func ring_dust(center: Vector2, radius: float, family: StringName, safe: Callable) -> void:
	var count: int = mini(RING_DUST_MAX, maxi(1, int(TAU * radius / RING_DUST_STEP)))
	for i: int in count:
		var angle: float = ctx.rng.randf() * TAU if ctx else randf() * TAU
		if not safe.call(angle):
			play(&"ring_dust", family, center + Vector2.RIGHT.rotated(angle) * radius, angle > PI * 0.5 and angle < PI * 1.5)


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
		var length: float = (sheet["rects"] as Array).size() / float(sheet["fps"])
		var done: bool = float(fx["t"]) >= length
		if fx.has("life"):
			fx["life"] = float(fx["life"]) - delta
			done = float(fx["life"]) <= 0.0
			fx["t"] = fposmod(float(fx["t"]), length)
		if fx.has("follow"):
			# État en boucle : suit son porteur, s'arrête à sa mort ou à la fin de la durée.
			var owner: Variant = fx["follow"]
			done = not is_instance_valid(owner) or not (owner as Enemy).alive or ctx.time >= float(fx["until"])
			if not done:
				fx["pos"] = (owner as Enemy).position
				fx["t"] = fposmod(float(fx["t"]), length)
		if done:
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
		var scale: float = fx.get("scale", 1.0)
		if fx.has("stretch"):
			draw_set_transform(pos, float(fx["rotation"]), fx["stretch"])
			draw_texture_rect_region(sheet["texture"], Rect2(-pivot - (fx["offset"] as Vector2), rect.size), rect)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif bool(fx["flip"]) or scale != 1.0:
			draw_set_transform(pos, 0.0, Vector2(-scale if bool(fx["flip"]) else scale, scale))
			draw_texture_rect_region(sheet["texture"], Rect2(-pivot, rect.size), rect)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect_region(sheet["texture"], Rect2(pos - pivot, rect.size), rect)
