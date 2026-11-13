class_name DraftSpells
extends RefCounted
## Sorts du Chasseur dans la base 3D. Données d'origine (`SpellData` : dégâts, recharge, portée, largeur), sorts
## équipés lus dans l'arbre du profil (HunterTree.loadout, lecture seule) ou, à défaut, sorts de départ de
## l'équilibrage. Ils partent seuls quand ils sont prêts et utiles : les commandes restent le déplacement et la Ruée.
## Sorts raccordés : Taille (`slash`), Lance (`lance`), Rupture (`rupture`), Bond de Faille (`leap`).
## Les autres sorts équipés sont ignorés pour l'instant (liste dans `skipped`).

const SUPPORTED: Array[StringName] = [&"slash", &"lance", &"rupture", &"leap"]

var run: DraftRun
var spells: Array[SpellData] = []
var cooldowns: Array[float] = []
var skipped: Array[StringName] = []
var casts: int = 0


func setup(p_run: DraftRun, ids: Array[StringName]) -> void:
	run = p_run
	for id: StringName in ids:
		var data: SpellData = GameDB.spells.get(id)
		if data == null:
			continue
		if SUPPORTED.has(data.spell_kind):
			spells.append(data)
			cooldowns.append(2.0 + spells.size())
		else:
			skipped.append(id)


func cooldown_of(data: SpellData) -> float:
	return data.cooldown * maxf(run.hunter.stats.get_value(StatKeys.SPELL_COOLDOWN), 0.2)


func damage_of(data: SpellData) -> float:
	return data.damage * run.hunter.stats.get_value(StatKeys.SPELL_DAMAGE) * run.hunter.stats.get_value(StatKeys.DAMAGE)


func step(delta: float) -> void:
	if not run.hunter.alive:
		return
	for i: int in spells.size():
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
		if cooldowns[i] <= 0.0 and _cast(spells[i]):
			cooldowns[i] = cooldown_of(spells[i])
			casts += 1
			Audio.play_sfx(&"technique")


func _cast(data: SpellData) -> bool:
	match data.spell_kind:
		&"slash":
			return _slash(data)
		&"lance":
			return _lance(data)
		&"rupture":
			return _rupture(data)
		&"leap":
			return _leap(data)
	return false


## Taille : tout ce qui est devant, dans la portée, de plain-pied et visible.
func _slash(data: SpellData) -> bool:
	var here: Vector3 = run.hunter.global_position
	var reach: float = data.spell_range * DraftHunter.UNIT
	var foes: Array[DraftEnemies.Foe] = _level(run.enemies.near(here, reach), here)
	if foes.is_empty():
		return false
	var aim: Vector3 = _flat(foes[0].pos - here).normalized()
	run.fx(&"heavy_cleave", DraftPixelFx.DEFAULT_FAMILY, here + aim * reach * 0.5 + Vector3.UP * 0.7, 2.2)
	for foe: DraftEnemies.Foe in foes:
		if _flat(foe.pos - here).normalized().dot(aim) > -0.2:
			run.enemies.hit(foe, damage_of(data), aim * data.knockback * DraftHunter.UNIT * 3.0)
	return true


## Lance : un trait lourd qui traverse tout, dans l'axe de la cible visible la plus proche.
func _lance(data: SpellData) -> bool:
	var foe: DraftEnemies.Foe = run.target()
	if foe == null:
		return false
	var origin: Vector3 = run.hunter.chest()
	run.fire_bolt(origin, origin.direction_to(foe.pos + Vector3.UP * 0.5), damage_of(data),
		minf(data.spell_range * DraftHunter.UNIT, 22.0), 99, 0)
	return true


## Rupture : détonation de zone sur la cible visible.
func _rupture(data: SpellData) -> bool:
	var foe: DraftEnemies.Foe = run.target()
	if foe == null:
		return false
	var radius: float = data.width * DraftHunter.UNIT * 0.5
	run.fx(&"dark_explosion", DraftPixelFx.DEFAULT_FAMILY, foe.pos + Vector3.UP * 0.6, radius)
	for other: DraftEnemies.Foe in _level(run.enemies.near(foe.pos, radius), foe.pos):
		run.enemies.hit(other, damage_of(data) * 2.0)
	return true


## Bond de Faille : quand le Chasseur est serré de près, il se dégage et frappe là où il retombe.
func _leap(data: SpellData) -> bool:
	var hunter: DraftHunter = run.hunter
	var here: Vector3 = hunter.global_position
	var close: Array[DraftEnemies.Foe] = _level(run.enemies.near(here, 2.2), here)
	if close.size() < 3:
		return false
	var away := Vector3.ZERO
	for foe: DraftEnemies.Foe in close:
		away += _flat(here - foe.pos).normalized()
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	run.fx(&"blink_out", DraftPixelFx.DEFAULT_FAMILY, here + Vector3.UP * 0.6)
	hunter.global_position = run.level.closest(here + away * minf(data.spell_range * DraftHunter.UNIT, 7.0)) + Vector3.UP * 0.1
	hunter.reset_motion()
	hunter.invulnerable = maxf(hunter.invulnerable, 0.4)
	var landing: Vector3 = hunter.global_position
	run.fx(&"ring_burst", DraftPixelFx.DEFAULT_FAMILY, landing + Vector3.UP * 0.4, 2.0)
	for foe: DraftEnemies.Foe in _level(run.enemies.near(landing, data.width * DraftHunter.UNIT), landing):
		run.enemies.hit(foe, damage_of(data), _flat(foe.pos - landing).normalized() * 4.0)
	return true


## Ennemis du même niveau et visibles depuis `from` (aucun décor entre les deux), les plus proches d'abord.
func _level(foes: Array[DraftEnemies.Foe], from: Vector3) -> Array[DraftEnemies.Foe]:
	var result: Array[DraftEnemies.Foe] = []
	for foe: DraftEnemies.Foe in foes:
		if absf(foe.pos.y - from.y) <= DraftEnemies.MELEE_REACH_UP \
				and run.sight_clear(from + Vector3.UP * 0.8, foe.pos + Vector3.UP * 0.5):
			result.append(foe)
	result.sort_custom(func(a: DraftEnemies.Foe, b: DraftEnemies.Foe) -> bool:
		return a.pos.distance_squared_to(from) < b.pos.distance_squared_to(from))
	return result


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
