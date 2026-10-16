class_name HunterSpells
extends Node2D
## Sorts du Chasseur (lot C1, docs/design/ARBRE_DU_CHASSEUR.md) : 4 emplacements (A, E, R, F par défaut), visée au
## curseur. Par défaut la touche lance immédiatement ; avec l'option « aperçu », maintenir la touche affiche la zone
## au sol et la relâcher lance. Dessine aussi le réticule de visée et l'aperçu (indicateur au sol).
## spell_kind (données) → fonction de code, comme les Techniques des Échos.

const SLOTS := 4
const RETICLE_COLOR := Color(0.85, 0.95, 1.0, 0.55)

var ctx: RunContext
## Sort équipé par emplacement (null : emplacement vide).
var slots: Array[SpellData] = []
## Recharge restante par emplacement (secondes).
var cooldowns := PackedFloat32Array()
## Emplacement en aperçu (touche maintenue, option « aperçu »), -1 sinon.
var preview_slot: int = -1


func setup(p_ctx: RunContext, spell_ids: Array[StringName]) -> void:
	ctx = p_ctx
	z_index = 1
	slots.clear()
	for i: int in SLOTS:
		var spell: SpellData = GameDB.spells.get(spell_ids[i]) if i < spell_ids.size() else null
		slots.append(spell)
	cooldowns.resize(SLOTS)
	cooldowns.fill(0.0)


func step(delta: float) -> void:
	var player: Player = ctx.player
	var brain: PlayerBrain = player.brain
	for i: int in SLOTS:
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	if not player.alive:
		preview_slot = -1
		return
	for i: int in SLOTS:
		if slots[i] == null:
			continue
		if brain.preview_casting():
			if brain.spell_pressed(i):
				preview_slot = i
			elif preview_slot == i and brain.spell_released(i):
				preview_slot = -1
				cast(i, brain.aim_point())
		elif brain.spell_pressed(i):
			cast(i, brain.aim_point())
	queue_redraw()


## Lance le sort de l'emplacement vers `aim` (point du monde). Faux si vide ou en recharge.
func cast(slot: int, aim: Vector2) -> bool:
	var spell: SpellData = slots[slot] if slot < slots.size() else null
	if spell == null or cooldowns[slot] > 0.0:
		return false
	var origin: Vector2 = ctx.player.global_position
	var dir: Vector2 = aim_direction(aim)
	match spell.spell_kind:
		&"slash":
			_slash(spell, origin, dir)
		&"lance":
			_lance(spell, origin, dir)
		_:
			push_error("Sort inconnu : %s" % spell.spell_kind)
			return false
	cooldowns[slot] = spell.cooldown * maxf(ctx.player.stats.get_value(StatKeys.SPELL_COOLDOWN), 0.1)
	ctx.player.facing = dir
	ctx.stats.add(&"spells_cast")
	ctx.stats.add(StringName(String(spell.id) + "_casts"))
	ctx.events.spell_cast.emit(spell.id)
	return true


func ready_ratio(slot: int) -> float:
	var spell: SpellData = slots[slot]
	if spell == null:
		return 0.0
	var total: float = spell.cooldown * maxf(ctx.player.stats.get_value(StatKeys.SPELL_COOLDOWN), 0.1)
	return 1.0 - cooldowns[slot] / maxf(total, 0.01)


## Direction de lancement : vers le point visé, ou vers l'avant si le curseur est sur le Chasseur.
func aim_direction(aim: Vector2) -> Vector2:
	var offset: Vector2 = aim - ctx.player.global_position
	return offset.normalized() if offset.length() > 4.0 else ctx.player.facing


func _make_info(spell: SpellData, dir: Vector2) -> DamageInfo:
	var stats: StatSheet = ctx.player.stats
	var amount: float = spell.damage * stats.get_value(StatKeys.DAMAGE) * stats.get_value(StatKeys.SPELL_DAMAGE)
	var tags: Array[StringName] = [DamageInfo.TAG_SPELL]
	var info := DamageInfo.make(amount, DamageInfo.SourceKind.PLAYER, &"player", tags)
	info.knockback = spell.knockback
	info.direction = dir
	info.statuses = spell.statuses
	return info


## Taille fendante : arc de lame devant le Chasseur (portée `spell_range`, demi-angle `width` en degrés).
func _slash(spell: SpellData, origin: Vector2, dir: Vector2) -> void:
	var half: float = deg_to_rad(spell.width)
	var hits: int = 0
	for enemy: Enemy in ctx.enemies.query_radius(origin, spell.spell_range):
		var offset: Vector2 = enemy.global_position - origin
		var dist: float = maxf(offset.length(), 0.01)
		# Tolérance du rayon de l'ennemi : un ennemi à cheval sur le bord de l'arc est touché.
		var tolerance: float = asin(clampf(enemy.radius / dist, 0.0, 1.0))
		if absf(dir.angle_to(offset)) > half + tolerance:
			continue
		ctx.combat.deal_damage(enemy, _make_info(spell, offset / dist))
		hits += 1
	ctx.stats.set_max(&"slash_max_hits", float(hits))
	ctx.fx.sector(origin, dir, spell.spell_range, half, spell.color, 0.22)
	ctx.player.visual.play_action(&"attack")
	Audio.play_sfx(&"bolt_fire")


## Lance prismatique : trait lourd qui traverse tout jusqu'à sa portée et pose des Marques.
func _lance(spell: SpellData, origin: Vector2, dir: Vector2) -> void:
	var speed: float = maxf(spell.speed, 1.0)
	ctx.projectiles.spawn_friendly(origin, dir, speed, _make_info(spell, dir), {
		"pierce": 999,
		"radius": spell.width,
		"life": spell.spell_range / speed,
		"color": spell.color,
	})
	ctx.fx.line(origin, origin + dir * 60.0, spell.color, 6.0, 0.15)
	ctx.player.visual.play_action(&"attack")
	Audio.play_sfx(&"bolt_fire")


func _draw() -> void:
	if ctx == null or ctx.setup.autopilot or not ctx.player.alive:
		return
	var origin: Vector2 = ctx.player.global_position
	var aim: Vector2 = ctx.player.brain.aim_point()
	if preview_slot >= 0 and slots[preview_slot] != null:
		draw_shape(slots[preview_slot], origin, aim_direction(aim))
	# Réticule : le point visé, au sol.
	draw_arc(aim, 10.0, 0.0, TAU, 20, RETICLE_COLOR, 1.5)
	draw_line(aim + Vector2(-5, 0), aim + Vector2(5, 0), RETICLE_COLOR, 1.5)
	draw_line(aim + Vector2(0, -5), aim + Vector2(0, 5), RETICLE_COLOR, 1.5)


## Indicateur au sol : forme et portée du sort.
func draw_shape(spell: SpellData, origin: Vector2, dir: Vector2) -> void:
	var fill := Color(spell.color, 0.16)
	var edge := Color(spell.color, 0.7)
	match spell.spell_kind:
		&"slash":
			var points: PackedVector2Array = FxRenderer.sector_points(origin, dir, spell.spell_range,
				deg_to_rad(spell.width))
			draw_colored_polygon(points, fill)
			points.append(points[0])
			draw_polyline(points, edge, 2.0)
		&"lance":
			var side: Vector2 = dir.orthogonal() * spell.width
			var end: Vector2 = origin + dir * spell.spell_range
			var rect := PackedVector2Array([origin + side, end + side, end - side, origin - side])
			draw_colored_polygon(rect, fill)
			rect.append(rect[0])
			draw_polyline(rect, edge, 2.0)
