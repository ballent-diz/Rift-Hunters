class_name PaintedVfx
extends Node2D
## Effets peints autonomes (scènes « effect_scene » du manifeste : vfx.enemy.*, vfx.boss.*, docs/art/MARAIS_SORTS_GODOT.md)
## posés sur les événements déjà résolus par le combat. Présentation seulement : aucune règle de jeu ici. Si une scène
## manque, rien n'est créé et l'appelant garde son dessin provisoire.
## Trois usages : `play` (coup unique), `hold` (boucle qui suit un porteur jusqu'à une échéance ou une condition) et
## `sync` + `prune` (boucle recalée chaque image sur un état du combat, dissipée quand l'état disparaît).

## Plafond d'effets décoratifs simultanés, dont ceux des boss (les avertissements du combat ne passent pas par ici).
const MAX_EFFECTS := 24
const MAX_BOSS := 8

var ctx: RunContext
var _scenes: Dictionary = {}
## Boucles tenues : {"fx", "until", "follow", "has_follow", "keep", "on_end"}.
var _held: Array[Dictionary] = []
## Boucles synchronisées (étiquette → effet) et étiquettes vues depuis leur dernier élagage.
var _synced: Dictionary = {}
var _seen: Dictionary = {}


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "PaintedVfx"
	z_index = 2


func scene(key: String) -> PackedScene:
	if key == "":
		return null
	if not _scenes.has(key):
		var path: String = str(Assets.entry(StringName(key)).get("scene", ""))
		_scenes[key] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _scenes[key]


## Première scène existante parmi `names` pour ce monstre (« vfx.enemy.<id>.<nom> ») ; "" sinon.
func enemy_key(owner: StringName, names: Array) -> String:
	for anim: String in names:
		var key: String = "vfx.enemy.%s.%s" % [owner, anim]
		if scene(key) != null:
			return key
	return ""


## Coup unique à `pos` (globale), orienté vers `dir`. contact >= 0 : démarre à cette fraction de l'animation.
## required : jamais refusé par le plafond (boucles d'état, voir `sync`).
func play(key: String, pos: Vector2, dir: Vector2 = Vector2.RIGHT, props: Dictionary = {}, contact: float = -1.0,
		required: bool = false) -> Node2D:
	var packed: PackedScene = scene(key)
	if packed == null or (not required and not _room(key.begins_with("vfx.boss."))):
		return null
	var fx: Node2D = packed.instantiate()
	for prop: String in props:
		fx.set(prop, props[prop])
	fx.set_meta(&"boss", key.begins_with("vfx.boss."))
	add_child(fx)
	fx.global_position = pos
	if contact >= 0.0:
		fx.call("play_from", float(fx.call("duration")) * contact, dir)
	else:
		fx.call("play", dir)
	return fx


## Boucle tenue jusqu'à `until` (temps de partie), qui suit `follow` (nœud) s'il est fourni ; dissipée plus tôt si le
## porteur meurt ou si `keep` renvoie faux. `on_end(fx)` est appelé à la dissipation.
func hold(key: String, pos: Vector2, until: float, follow: Variant = null, props: Dictionary = {},
		dir: Vector2 = Vector2.RIGHT, keep: Callable = Callable(), on_end: Callable = Callable()) -> Node2D:
	var fx: Node2D = play(key, pos, dir, props)
	if fx:
		_held.append({"fx": fx, "until": until, "follow": follow, "has_follow": follow != null, "keep": keep,
			"on_end": on_end})
	return fx


## Boucle liée à l'étiquette `tag` : créée au premier appel, replacée et reconfigurée (props) aux suivants. Ces boucles
## montrent un état du combat (miroirs, marée, carapace), déjà borné par la mécanique : le plafond ne les refuse pas.
func sync(tag: String, key: String, pos: Vector2, props: Dictionary = {}) -> Node2D:
	_seen[tag] = true
	var fx: Node2D = null
	if _synced.has(tag) and is_instance_valid(_synced[tag]):
		fx = _synced[tag]
		for prop: String in props:
			fx.set(prop, props[prop])
	else:
		fx = play(key, pos, Vector2.RIGHT, props, -1.0, true)
		if fx == null:
			_synced.erase(tag)
			return null
		_synced[tag] = fx
	fx.global_position = pos
	return fx


## Dissipe les boucles d'étiquette commençant par `prefix` qui n'ont pas été synchronisées depuis le dernier élagage.
func prune(prefix: String) -> void:
	for tag: String in _synced.keys():
		if tag.begins_with(prefix) and not _seen.has(tag):
			_release(_synced[tag])
			_synced.erase(tag)
	for tag: String in _seen.keys():
		if tag.begins_with(prefix):
			_seen.erase(tag)


## Fin de partie, changement de boss : tout se dissipe.
func clear() -> void:
	for tag: String in _synced:
		_release(_synced[tag])
	_synced.clear()
	_seen.clear()
	for entry: Dictionary in _held:
		_release(entry["fx"])
	_held.clear()


func count() -> int:
	return get_child_count()


func _room(boss: bool) -> bool:
	var total: int = 0
	var bosses: int = 0
	for child: Node in get_children():
		if child.is_queued_for_deletion():
			continue
		total += 1
		if child.get_meta(&"boss", false):
			bosses += 1
	return total < MAX_EFFECTS and (not boss or bosses < MAX_BOSS)


func _process(_delta: float) -> void:
	if ctx == null:
		return
	var i: int = _held.size() - 1
	while i >= 0:
		var entry: Dictionary = _held[i]
		# Lus sans type : un porteur ou un effet libéré entre-temps.
		var fx: Variant = entry["fx"]
		var follow: Variant = entry["follow"]
		if not is_instance_valid(fx):
			_held.remove_at(i)
			i -= 1
			continue
		var lost: bool = bool(entry["has_follow"]) and (not is_instance_valid(follow)
			or (follow.has_method("is_alive") and not follow.call("is_alive")))
		var keep: Callable = entry["keep"]
		if not lost and ctx.time < float(entry["until"]) and (not keep.is_valid() or bool(keep.call())):
			if bool(entry["has_follow"]):
				(fx as Node2D).global_position = (follow as Node2D).global_position
		else:
			_held.remove_at(i)
			var on_end: Callable = entry["on_end"]
			if on_end.is_valid():
				on_end.call(fx)
			_release(fx)
		i -= 1


static func _release(fx: Variant) -> void:
	if is_instance_valid(fx):
		(fx as Node).call("release")
