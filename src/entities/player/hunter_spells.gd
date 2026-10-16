class_name HunterSpells
extends Node2D
## Sorts du Chasseur (lot C1, docs/design/ARBRE_DU_CHASSEUR.md) : 4 emplacements (A, E, R, F par défaut), visée au
## curseur. Par défaut la touche lance immédiatement ; avec l'option « aperçu », maintenir la touche affiche la zone
## au sol et la relâcher lance. Dessine aussi le réticule de visée et l'aperçu (indicateur au sol).
## spell_kind (données) → fonction de code, comme les Techniques des Échos. Les sorts du lot C2b et leurs objets
## persistants (cristaux, murs, portails…) vivent dans HunterSpellWorld (`world`).

const SLOTS := 4
const RETICLE_COLOR := Color(0.85, 0.95, 1.0, 0.55)
## Variantes (arbre du Chasseur v2) : Tourbillon (cercle, portée ×0,85), Estoc (ligne), Éventail (3 lances),
## Surcharge (maintenir pour charger).
const WHIRLWIND_REACH := 0.85
const THRUST_RANGE := 320.0
const THRUST_HALF_WIDTH := 22.0
const FAN_ANGLE := 15.0
const FAN_DAMAGE := 0.8
const OVERCHARGE_TIME := 1.2
const OVERCHARGE_MAX := 2.5

var ctx: RunContext
## Sort équipé par emplacement (null : emplacement vide).
var slots: Array[SpellData] = []
## Recharge restante par emplacement (secondes).
var cooldowns := PackedFloat32Array()
## Variante active par emplacement (&"" : sort de base).
var variants: Array[StringName] = []
## Emplacement en aperçu (touche maintenue, option « aperçu »), -1 sinon.
var preview_slot: int = -1
## Emplacement en charge (Surcharge), -1 sinon, et durée de charge.
var charge_slot: int = -1
var charge_time: float = 0.0
var world: HunterSpellWorld


func setup(p_ctx: RunContext, spell_ids: Array[StringName], spell_variants: Dictionary = {}) -> void:
	ctx = p_ctx
	z_index = 1
	slots.clear()
	variants.clear()
	for i: int in SLOTS:
		var spell: SpellData = GameDB.spells.get(spell_ids[i]) if i < spell_ids.size() else null
		slots.append(spell)
		variants.append(StringName(str(spell_variants.get(spell.id, ""))) if spell else &"")
	cooldowns.resize(SLOTS)
	cooldowns.fill(0.0)
	world = HunterSpellWorld.new()
	world.setup(ctx, self)
	add_child(world)


func step(delta: float) -> void:
	var player: Player = ctx.player
	var brain: PlayerBrain = player.brain
	for i: int in SLOTS:
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	world.step(delta)
	if not player.alive:
		preview_slot = -1
		return
	if charge_slot >= 0:
		charge_time += delta
		if brain.spell_released(charge_slot) or not brain.spell_held(charge_slot):
			var slot: int = charge_slot
			charge_slot = -1
			cast(slot, brain.aim_point(), charge_power())
	for i: int in SLOTS:
		if slots[i] == null:
			continue
		if variants[i] == &"overcharge" and brain.can_hold():
			if brain.spell_pressed(i) and cooldowns[i] <= 0.0 and charge_slot < 0:
				charge_slot = i
				charge_time = 0.0
		elif brain.preview_casting():
			if brain.spell_pressed(i):
				preview_slot = i
			elif preview_slot == i and brain.spell_released(i):
				preview_slot = -1
				cast(i, brain.aim_point())
		elif brain.spell_pressed(i):
			cast(i, brain.aim_point())
	queue_redraw()


## Puissance de la Surcharge en cours (×1 à ×2,5).
func charge_power() -> float:
	return lerpf(1.0, OVERCHARGE_MAX, clampf(charge_time / OVERCHARGE_TIME, 0.0, 1.0))


## Lance le sort de l'emplacement vers `aim` (point du monde), avec un multiplicateur de dégâts `power`.
## Faux si vide ou en recharge.
func cast(slot: int, aim: Vector2, power: float = 1.0) -> bool:
	var spell: SpellData = slots[slot] if slot < slots.size() else null
	if spell == null or ctx.player.is_leaping():
		return false
	var origin: Vector2 = ctx.player.global_position
	var dir: Vector2 = aim_direction(aim)
	var variant: StringName = variants[slot]
	# Second appui gratuit : Retour du Bond, sortie des Failles jumelles.
	if world.free_recast(spell):
		return world.cast(slot, spell, variant, origin, dir, aim, power)
	if cooldowns[slot] > 0.0:
		return false
	power *= world.consume_power(spell)
	match spell.spell_kind:
		&"slash":
			if variant == &"thrust":
				_thrust(spell, origin, dir)
			else:
				_slash(spell, origin, dir, variant == &"whirlwind")
		&"lance":
			if variant == &"fan":
				for angle: float in [-FAN_ANGLE, 0.0, FAN_ANGLE]:
					_lance(spell, origin, dir.rotated(deg_to_rad(angle)), FAN_DAMAGE)
			else:
				_lance(spell, origin, dir, power)
		_:
			if not world.cast(slot, spell, variant, origin, dir, aim, power):
				return false
	cooldowns[slot] = spell.cooldown * maxf(ctx.player.stats.get_value(StatKeys.SPELL_COOLDOWN), 0.1)
	ctx.player.facing = dir
	ctx.stats.add(&"spells_cast")
	ctx.stats.add(StringName(String(spell.id) + "_casts"))
	ctx.events.spell_cast.emit(spell.id)
	return true


## Relais vers les sorts persistants (appelés par les combats et les projectiles).
func on_parry() -> void:
	world.on_parry()


func blocks_projectile(pos: Vector2) -> bool:
	return not world.walls.is_empty() and world.blocks_projectile(pos)


func affect_projectile(p: Projectile) -> void:
	if not world.crystals.is_empty() or not world.portals.is_empty():
		world.affect_projectile(p)


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


func _make_info(spell: SpellData, dir: Vector2, power: float = 1.0) -> DamageInfo:
	var stats: StatSheet = ctx.player.stats
	var amount: float = spell.damage * power * stats.get_value(StatKeys.DAMAGE) * stats.get_value(StatKeys.SPELL_DAMAGE)
	var tags: Array[StringName] = [DamageInfo.TAG_SPELL]
	var info := DamageInfo.make(amount, DamageInfo.SourceKind.PLAYER, &"player", tags)
	info.knockback = spell.knockback
	info.direction = dir
	info.statuses = spell.statuses
	return info


## Taille fendante : arc de lame devant le Chasseur (portée `spell_range`, demi-angle `width` en degrés) ;
## Tourbillon : cercle complet.
func _slash(spell: SpellData, origin: Vector2, dir: Vector2, whirlwind: bool = false) -> void:
	var half: float = PI if whirlwind else deg_to_rad(spell.width)
	var reach: float = spell.spell_range * (WHIRLWIND_REACH if whirlwind else 1.0)
	var hits: int = 0
	for enemy: Enemy in ctx.enemies.query_radius(origin, reach):
		var offset: Vector2 = enemy.global_position - origin
		var dist: float = maxf(offset.length(), 0.01)
		# Tolérance du rayon de l'ennemi : un ennemi à cheval sur le bord de l'arc est touché.
		var tolerance: float = asin(clampf(enemy.radius / dist, 0.0, 1.0))
		if absf(dir.angle_to(offset)) > half + tolerance:
			continue
		ctx.combat.deal_damage(enemy, _make_info(spell, offset / dist))
		hits += 1
	ctx.stats.set_max(&"slash_max_hits", float(hits))
	ctx.fx.sector(origin, dir, reach, minf(half, PI - 0.01), spell.color, 0.22)
	ctx.player.visual.play_action(&"attack")
	Audio.play_sfx(&"bolt_fire")


## Estoc : ligne longue et étroite devant le Chasseur, qui perce tout.
func _thrust(spell: SpellData, origin: Vector2, dir: Vector2) -> void:
	var hits: int = 0
	for enemy: Enemy in ctx.enemies.query_radius(origin + dir * THRUST_RANGE * 0.5, THRUST_RANGE * 0.5 + 40.0):
		var offset: Vector2 = enemy.global_position - origin
		var along: float = offset.dot(dir)
		if along < -enemy.radius or along > THRUST_RANGE + enemy.radius:
			continue
		if absf(offset.dot(dir.orthogonal())) > THRUST_HALF_WIDTH + enemy.radius:
			continue
		ctx.combat.deal_damage(enemy, _make_info(spell, dir))
		hits += 1
	ctx.stats.set_max(&"slash_max_hits", float(hits))
	ctx.fx.line(origin, origin + dir * THRUST_RANGE, spell.color, THRUST_HALF_WIDTH * 2.0, 0.2)
	ctx.player.visual.play_action(&"attack")
	Audio.play_sfx(&"bolt_fire")


## Lance prismatique : trait lourd qui traverse tout jusqu'à sa portée et pose des Marques.
func _lance(spell: SpellData, origin: Vector2, dir: Vector2, power: float = 1.0) -> void:
	var speed: float = maxf(spell.speed, 1.0)
	ctx.projectiles.spawn_friendly(origin, dir, speed, _make_info(spell, dir, power), {
		"pierce": 999,
		"radius": spell.width * (1.0 + 0.4 * (power - 1.0)),
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
	var shown: int = charge_slot if charge_slot >= 0 else preview_slot
	if shown >= 0 and slots[shown] != null:
		draw_shape(slots[shown], origin, aim_direction(aim), variants[shown])
	if charge_slot >= 0:
		var ratio: float = clampf(charge_time / OVERCHARGE_TIME, 0.0, 1.0)
		draw_arc(origin, 26.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32, Color(slots[charge_slot].color, 0.9), 3.0)
	# Réticule : le point visé, au sol.
	draw_arc(aim, 10.0, 0.0, TAU, 20, RETICLE_COLOR, 1.5)
	draw_line(aim + Vector2(-5, 0), aim + Vector2(5, 0), RETICLE_COLOR, 1.5)
	draw_line(aim + Vector2(0, -5), aim + Vector2(0, 5), RETICLE_COLOR, 1.5)


## Indicateur au sol : forme et portée du sort (selon sa variante).
func draw_shape(spell: SpellData, origin: Vector2, dir: Vector2, variant: StringName = &"") -> void:
	var fill := Color(spell.color, 0.16)
	var edge := Color(spell.color, 0.7)
	match spell.spell_kind:
		&"slash" when variant == &"whirlwind":
			draw_circle(origin, spell.spell_range * WHIRLWIND_REACH, fill)
			draw_arc(origin, spell.spell_range * WHIRLWIND_REACH, 0.0, TAU, 40, edge, 2.0)
		&"slash" when variant == &"thrust":
			_draw_line_shape(origin, dir, THRUST_RANGE, THRUST_HALF_WIDTH, fill, edge)
		&"lance" when variant == &"fan":
			for angle: float in [-FAN_ANGLE, 0.0, FAN_ANGLE]:
				_draw_line_shape(origin, dir.rotated(deg_to_rad(angle)), spell.spell_range, spell.width, fill, edge)
		&"slash":
			var points: PackedVector2Array = FxRenderer.sector_points(origin, dir, spell.spell_range,
				deg_to_rad(spell.width))
			draw_colored_polygon(points, fill)
			points.append(points[0])
			draw_polyline(points, edge, 2.0)
		&"lance":
			_draw_line_shape(origin, dir, spell.spell_range, spell.width, fill, edge)
		&"leap":
			var target: Vector2 = origin + dir * minf(spell.spell_range, ctx.player.brain.aim_point().distance_to(origin))
			draw_line(origin, target, edge, 2.0)
			_draw_circle_shape(target, spell.width * (2.0 if variant == &"impact" else 1.0), fill, edge)
		&"parry", &"aegis":
			_draw_circle_shape(origin, maxf(spell.width, 60.0) if spell.spell_kind == &"parry" else 60.0, fill, edge)
		&"wall":
			var center: Vector2 = _aim_point(origin, spell.spell_range)
			var axis: Vector2 = dir.orthogonal() * spell.width * 0.5
			draw_line(center - axis, center + axis, edge, 6.0)
		&"swap":
			draw_line(origin, _aim_point(origin, spell.spell_range), edge, 2.0)
		&"singularity":
			_draw_circle_shape(_aim_point(origin, spell.spell_range),
				spell.width * (1.4 if variant == &"horizon" else 1.0), fill, edge)
		&"crystal", &"rifts":
			_draw_circle_shape(_aim_point(origin, spell.spell_range), maxf(spell.width, 26.0), fill, edge)
		_:
			_draw_circle_shape(_aim_point(origin, spell.spell_range), spell.width, fill, edge)


func _aim_point(origin: Vector2, max_range: float) -> Vector2:
	return origin + (ctx.player.brain.aim_point() - origin).limit_length(max_range)


func _draw_circle_shape(center: Vector2, radius: float, fill: Color, edge: Color) -> void:
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 40, edge, 2.0)


func _draw_line_shape(origin: Vector2, dir: Vector2, length: float, half_width: float, fill: Color, edge: Color) -> void:
	var side: Vector2 = dir.orthogonal() * half_width
	var end: Vector2 = origin + dir * length
	var rect := PackedVector2Array([origin + side, end + side, end - side, origin - side])
	draw_colored_polygon(rect, fill)
	rect.append(rect[0])
	draw_polyline(rect, edge, 2.0)
