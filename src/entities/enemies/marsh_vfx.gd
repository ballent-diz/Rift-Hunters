class_name MarshVfx
extends RefCounted
## Effets peints des Enlisés et Reflets du chapitre 3 (assets/vfx/enemies/chapter3/, docs/art/MARAIS_SORTS_GODOT.md),
## posés sur les techniques déjà résolues par EnemyManager et MarshTechniques. Présentation seulement : les dégâts,
## statuts et déplacements restent dans les techniques. Sans scène pour un monstre, rien n'est créé.

## Frappes au contact, par monstre (première scène trouvée).
const MELEE := ["bite", "slash", "snap", "impact"]
const BLINKS := ["reflection_jump", "evasive_blink", "chain_blink"]

var ctx: RunContext
var m: EnemyManager
## Rayons balayants en cours, par ennemi (identifiant d'instance → effet).
var _beams: Dictionary = {}


func _init(p_ctx: RunContext, manager: EnemyManager) -> void:
	ctx = p_ctx
	m = manager


func _painted() -> PaintedVfx:
	return ctx.painted if ctx and ctx.painted and is_instance_valid(ctx.painted) else null


## Appelé après chaque technique réussie : effets pixelfx de la compétence (tous chapitres), puis coups et boucles
## peints dont la géométrie se lit dans la technique.
func technique(enemy: Enemy, technique_data: EnemyTechniqueData, player_pos: Vector2) -> void:
	if ctx.pixel_fx: ctx.pixel_fx.technique(enemy, technique_data.kind, technique_data.params)
	var painted: PaintedVfx = _painted()
	if painted == null or enemy.data == null:
		return
	var owner: StringName = enemy.data.id
	var params: Dictionary = technique_data.params
	var wait: float = technique_data.telegraph
	var dir: Vector2 = (player_pos - enemy.position).normalized()
	match technique_data.kind:
		&"mud_leap":
			var key: String = painted.enemy_key(owner, ["mud_landing"])
			var radius: float = float(params.get("radius", 70.0)) + 30.0
			m._later(enemy, wait + float(params.get("flight", 0.45)), func() -> void:
				painted.play(key, enemy.position, Vector2.RIGHT, {"radius": radius}))
		&"burrow":
			var key: String = painted.enemy_key(owner, ["burrow", "plunge"])
			var radius: float = float(params.get("radius", 80.0))
			painted.play(key, enemy.position, dir)
			m._later(enemy, wait + float(params.get("travel", 1.2)) + float(params.get("emerge", 0.55)), func() -> void:
				painted.play(key, enemy.position, Vector2.RIGHT, {"radius": radius}))
		&"charge":
			var key: String = painted.enemy_key(owner, ["belly_charge"])
			var travel: float = float(params.get("speed", 560.0)) * float(params.get("duration", 0.6))
			m._later(enemy, wait, func() -> void:
				painted.play(key, enemy.position, dir, {"travel_distance": travel, "width": enemy.radius * 1.6}))
		&"rage":
			painted.hold(painted.enemy_key(owner, ["rage"]), enemy.position, INF, enemy, {"radius": enemy.radius * 1.2})
		&"web":
			var key: String = painted.enemy_key(owner, ["binding_roots"])
			m._later(enemy, wait, func() -> void: painted.play(key, enemy.position, dir))
		&"burn_slam":
			var key: String = painted.enemy_key(owner, ["spore_carpet"])
			var target: Vector2 = enemy.position + (player_pos - enemy.position).limit_length(technique_data.max_range)
			var radius: float = float(params.get("burn_radius", params.get("radius", 110.0)))
			var lasts: float = float(params.get("burn_time", 6.0))
			m._later(enemy, wait, func() -> void: painted.hold(key, target, ctx.time + lasts, null, {"radius": radius}))
		&"ally_shield":
			_shields(painted, enemy, owner, float(params.get("radius", 220.0)))
		&"heal_aura":
			var radius: float = float(params.get("radius", 240.0))
			var fx: Node2D = painted.hold(painted.enemy_key(owner, ["heal_aura"]), enemy.position, ctx.time + 1.2, enemy,
				{"radius": radius})
			if fx:
				var offsets := PackedVector2Array()
				for other: Enemy in m.query_radius(enemy.position, radius):
					if other != enemy and offsets.size() < 8:
						offsets.append(other.position - enemy.position)
				fx.call("set_secondary_offsets", offsets)
		&"reflect":
			painted.hold(painted.enemy_key(owner, ["reflecting_mirror"]), enemy.position, enemy.reflect_until, enemy,
				{"radius": enemy.radius + 14.0}, enemy.reflect_dir)
		&"shard_fan":
			var key: String = painted.enemy_key(owner, ["shard_fan"])
			var half: float = float(params.get("spread", 50.0)) * 0.5
			m._later(enemy, wait, func() -> void:
				painted.play(key, enemy.position, dir, {"half_angle_degrees": half}))


## Spore-marque, marque de prisme (appelé par MarshTechniques au moment où la marque est posée) : suit le Chasseur
## tant qu'il est marqué ; explose si la marque arrive à son terme, s'efface sans explosion si la Ruée l'a retirée.
func mark(enemy: Enemy) -> void:
	var painted: PaintedVfx = _painted()
	if painted == null or enemy.data == null:
		return
	var blast: String = painted.enemy_key(enemy.data.id, ["mark_explosion", "prism_explosion"])
	var player: Player = ctx.player
	var explode := func(_fx: Variant) -> void:
		if player.alive and not player.is_dashing():
			painted.play(blast, player.global_position, Vector2.RIGHT, {"radius": player.mark_radius})
	painted.hold(painted.enemy_key(enemy.data.id, ["spore_mark", "prism_mark"]), player.global_position, INF, player,
		{}, Vector2.RIGHT, player.is_marked, explode)


## Bouclier d'écorce : une bulle par Corrompu réellement protégé ; elle vole en éclats si la Gardienne tombe.
func _shields(painted: PaintedVfx, enemy: Enemy, owner: StringName, radius: float) -> void:
	var key: String = painted.enemy_key(owner, ["bark_shield"])
	var broken: String = painted.enemy_key(owner, ["armor_break"])
	var source: Variant = enemy
	for other: Enemy in m.query_radius(enemy.position, radius):
		if other.shield_source != enemy or other.shield_until <= ctx.time:
			continue
		painted.hold(key, other.position, other.shield_until, other, {"radius": other.radius + 8.0}, Vector2.RIGHT,
			func() -> bool: return is_instance_valid(source) and (source as Enemy).alive,
			func(fx: Variant) -> void:
				if not is_instance_valid(source) or not (source as Enemy).alive:
					painted.play(broken, (fx as Node2D).global_position))


## Saut de reflet, clignement : départ et arrivée réels (appelé par MarshTechniques au moment du saut).
func blink(enemy: Enemy, from: Vector2, to: Vector2) -> void:
	var painted: PaintedVfx = _painted()
	if painted == null or enemy.data == null:
		return
	var key: String = painted.enemy_key(enemy.data.id, BLINKS)
	painted.play(key, from, to - from)
	painted.play(key, to, to - from)


## Reflets : positions des copies, déjà validées par la technique.
func clones(enemy: Enemy, positions: Array[Vector2]) -> void:
	var painted: PaintedVfx = _painted()
	if painted == null or enemy.data == null:
		return
	var offsets := PackedVector2Array()
	for pos: Vector2 in positions:
		offsets.append(pos - enemy.position)
	var fx: Node2D = painted.play(painted.enemy_key(enemy.data.id, ["clones"]), enemy.position)
	if fx:
		fx.call("set_secondary_offsets", offsets)


## Rayon qui balaie : un seul effet par Colosse, recalé sur chaque tronçon réel (déjà coupé par le décor).
func sweep(enemy: Enemy, dir: Vector2, length: float, width: float, until: float) -> void:
	var painted: PaintedVfx = _painted()
	if painted == null or enemy.data == null:
		return
	var id: int = enemy.get_instance_id()
	var fx: Node2D = _beams[id] if _beams.has(id) and is_instance_valid(_beams[id]) else null
	if fx == null:
		fx = painted.hold(painted.enemy_key(enemy.data.id, ["sweep_beam"]), enemy.position, until, enemy, {"width": width})
		if fx == null:
			return
		_beams[id] = fx
	fx.call("set_path_local", PackedVector2Array([Vector2.ZERO, dir * length]))


## Cœur à nu du Colosse après son rayon.
func exposed(enemy: Enemy, seconds: float) -> void:
	var painted: PaintedVfx = _painted()
	if painted and enemy.data:
		painted.hold(painted.enemy_key(enemy.data.id, ["exposed_core"]), enemy.position, ctx.time + seconds, enemy,
			{"radius": enemy.radius})


## Coup au contact visible : la rangée d'attaque de la feuille, et la frappe peinte du monstre vers le Chasseur.
func melee(enemy: Enemy, player_pos: Vector2) -> void:
	enemy.visual.play_action(&"attack")
	var painted: PaintedVfx = _painted()
	if painted and enemy.data:
		var dir: Vector2 = player_pos - enemy.position
		painted.play(painted.enemy_key(enemy.data.id, MELEE), enemy.position + dir * 0.5, dir)


## Chasseresse furtive qui redevient visible.
func reveal(enemy: Enemy) -> void:
	var painted: PaintedVfx = _painted()
	if painted and enemy.data:
		painted.play(painted.enemy_key(enemy.data.id, ["reveal"]), enemy.position)


## Corps peint d'un tir ennemi (« projectile » ou « needle » du tireur), qui suivra le tir réel ; null sinon.
static func projectile(painted: PaintedVfx, source_id: StringName, pos: Vector2, dir: Vector2) -> Node2D:
	if painted == null or not is_instance_valid(painted):
		return null
	return painted.play(painted.enemy_key(source_id, ["projectile", "needle"]), pos, dir)
