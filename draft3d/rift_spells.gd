class_name DraftRiftSpells
extends RefCounted
## Sorts actifs propres à la version 3D (docs/design/SORTS_ACTIFS_V2.md, section 5, validés le 15 novembre 2026) :
## Marque du traqueur, Fente du vide, Pas de faille, Onde de stase, Pluie d'éclats, Voile de cendre. Données
## `SpellData` dans `draft3d/spells/data/` ; `DraftSpells` les lance et garde recharges, variantes et rangs.
## Ce fichier porte leurs effets et leur état (marque, charges, seconde fente, ombres, voiles).

const KINDS: Array[StringName] = [&"mark", &"rend", &"blink", &"stasis", &"shard_rain", &"veil"]
const DATA: Array[String] = ["res://draft3d/spells/data/hunter_mark.tres", "res://draft3d/spells/data/void_rend.tres",
	"res://draft3d/spells/data/rift_step.tres", "res://draft3d/spells/data/stasis_wave.tres",
	"res://draft3d/spells/data/shard_rain.tres", "res://draft3d/spells/data/ash_veil.tres"]

static var _registry: Dictionary = {}

var spells: DraftSpells
var run: DraftRun
## Marque du traqueur : ennemi marqué et temps restant.
var marked: DraftEnemies.Foe
var mark_left: float = 0.0
## Charges (Deux charges du Pas de faille) : identifiant du sort → charges disponibles.
var charges: Dictionary = {}
## Double fente : fenêtre de la seconde fente gratuite.
var rend_window: float = 0.0
## Ombres du Pas de faille {at, left, radius, damage, slow, duration} et Voiles de cendre {at, radius, left, follow,
## heal, slow, visual}.
var shades: Array[Dictionary] = []
var veils: Array[Dictionary] = []
var shots_blocked: int = 0
var _mark_spell: SpellData
var _mark_visual: Node3D
var _rend_slot: int = -1

func _init(p_spells: DraftSpells) -> void:
	spells = p_spells
	run = p_spells.run


## Sorts propres à la v2, par identifiant.
static func registry() -> Dictionary:
	if _registry.is_empty():
		for path: String in DATA:
			var data: SpellData = load(path)
			if data != null:
				_registry[data.id] = data
	return _registry


func cast(data: SpellData, aim: Vector3) -> bool:
	match data.spell_kind:
		&"mark":
			return _mark(data, aim)
		&"rend":
			return _rend(data, aim)
		&"blink":
			return _blink(data, aim)
		&"stasis":
			return _stasis(data, aim)
		&"shard_rain":
			return _rain(data, aim)
		&"veil":
			return _veil(data)
	return false


## Charges disponibles du sort (Deux charges), ou 0 sans cette variante.
func max_charges(data: SpellData) -> int:
	return int(spells.param(data, "charges", 1.0)) if spells.has_variant(data, &"charges") else 1


func has_charge(data: SpellData) -> bool:
	return max_charges(data) > 1 and int(charges.get(data.id, max_charges(data))) > 0


## Après un lancement : vrai si ce fichier gère lui-même la recharge (charges, seconde fente).
func after_cast(slot: int, data: SpellData) -> bool:
	if max_charges(data) > 1:
		var left: int = int(charges.get(data.id, max_charges(data))) - 1
		charges[data.id] = left
		if spells.cooldowns[slot] <= 0.0:
			spells.cooldowns[slot] = spells.cooldown_of(data)
		return true
	if spells.has_variant(data, &"double"):
		if _rend_slot < 0:
			_rend_slot = slot
			rend_window = spells.param(data, "window", 2.0)
			spells.cooldowns[slot] = 0.0
			return true
		_rend_slot = -1
		rend_window = 0.0
	return false


func step(delta: float) -> void:
	for i: int in spells.slots.size():
		var data: SpellData = spells.slots[i]
		if data != null and max_charges(data) > 1 and spells.cooldowns[i] <= 0.0 \
				and int(charges.get(data.id, max_charges(data))) < max_charges(data):
			charges[data.id] = int(charges.get(data.id, 0)) + 1
			if int(charges[data.id]) < max_charges(data):
				spells.cooldowns[i] = spells.cooldown_of(data)
	if rend_window > 0.0:
		rend_window -= delta
		if rend_window <= 0.0 and _rend_slot >= 0:
			spells.cooldowns[_rend_slot] = spells.cooldown_of(spells.slots[_rend_slot])
			_rend_slot = -1
	_step_mark(delta)
	_step_shades(delta)
	_step_veils(delta)


## Une case change de sort (échange d'arsenal) : la seconde fente en attente sur cette case se termine (recharge
## complète), pour qu'aucun échange ne serve à remettre une recharge à zéro.
func settle_slot(slot: int) -> void:
	if _rend_slot == slot:
		spells.cooldowns[slot] = spells.cooldown_of(spells.slots[slot])
		_rend_slot = -1
		rend_window = 0.0


## Visée du bot, ou Vector3.INF quand le sort ne servirait à rien maintenant.
func auto_aim(data: SpellData) -> Vector3:
	var here: Vector3 = run.hunter.global_position
	match data.spell_kind:
		&"mark":
			var foe: DraftEnemies.Foe = run.target()
			return foe.pos if foe != null and (marked == null or not marked.alive) else Vector3.INF
		&"rend":
			var foes: Array[DraftEnemies.Foe] = spells._level(run.enemies.near(here, spells.reach_of(data)), here)
			return foes[0].pos if not foes.is_empty() else Vector3.INF
		&"blink":
			var close: Array[DraftEnemies.Foe] = spells._level(run.enemies.near(here, 2.2), here)
			if close.size() < 3:
				return Vector3.INF
			var away := Vector3.ZERO
			for foe: DraftEnemies.Foe in close:
				away += DraftSpells._flat(here - foe.pos).normalized()
			return here + (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * spells.reach_of(data)
		&"stasis":
			var near: Array[DraftEnemies.Foe] = spells._level(run.enemies.near(here, spells.reach_of(data)), here)
			return near[0].pos if near.size() >= 3 else Vector3.INF
		&"shard_rain":
			var foe: DraftEnemies.Foe = run.target()
			return foe.pos if foe != null and run.enemies.near(foe.pos, 3.0).size() >= 3 else Vector3.INF
		&"veil":
			var threats: int = run.enemies.near(here, 3.0).size()
			for shot: Dictionary in run.hostile:
				if (shot["at"] as Vector3).distance_to(here) < 6.0:
					threats += 2
			return here if threats >= 4 else Vector3.INF
	return Vector3.INF


# --- Marque du traqueur -------------------------------------------------------------------------------------------

## Marque l'ennemi visible le plus proche du point visé (boss et plus résistants d'abord) : il subit plus de dégâts
## et le Trait le vise en priorité.
func _mark(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = spells._landing(aim, spells.reach_of(data))
	var best: DraftEnemies.Foe = null
	var here: Vector3 = run.hunter.global_position
	for foe: DraftEnemies.Foe in spells._level(run.enemies.near(at, spells.area_of(data)), here):
		if best == null or _priority(foe) > _priority(best):
			best = foe
	if best == null:
		var fallback: DraftEnemies.Foe = run.target()
		if fallback == null:
			return false
		best = fallback
	_mark_spell = data
	_apply_mark(best, spells.duration_of(data))
	return true


static func _priority(foe: DraftEnemies.Foe) -> float:
	return foe.max_hp + (1000000.0 if foe.boss != null else 0.0)


func mark_bonus(data: SpellData) -> float:
	return float(data.params.get("bonus", 0.0)) + spells.bonus(data, &"effect")


func _apply_mark(foe: DraftEnemies.Foe, seconds: float) -> void:
	marked = foe
	mark_left = seconds
	foe.expose(mark_bonus(_mark_spell), seconds)
	if _mark_visual == null or not is_instance_valid(_mark_visual):
		_mark_visual = run.fx(&"hex_sigil", &"fallen", foe.pos + Vector3.UP * 1.6, 0.8, true)


func _step_mark(delta: float) -> void:
	if marked == null:
		return
	mark_left -= delta
	var data: SpellData = _mark_spell
	if marked.alive and spells.has_variant(data, &"execute") \
			and marked.hp <= marked.max_hp * spells.param(data, "threshold", 0.2):
		var target: DraftEnemies.Foe = marked
		run.fx(&"dark_explosion", DraftPixelFx.DEFAULT_FAMILY, target.pos + Vector3.UP * 0.6, 1.4)
		var finish: float = target.hp / maxf(CombatSystem.defense_multiplier(target.defense), 0.05) + 1.0
		var blow: float = finish if target.boss == null else spells.damage_of(data) * spells.param(data, "boss", 3.0)
		_clear_mark()
		run.enemies.hit(target, blow)
		return
	if not marked.alive and mark_left > 0.0 and spells.has_variant(data, &"hunt"):
		var from: Vector3 = marked.pos
		var next: Array[DraftEnemies.Foe] = spells._level(run.enemies.near(from, spells.param(data, "reach", 8.0)), from)
		if not next.is_empty():
			_apply_mark(next[0], mark_left)
			return
	if not marked.alive or mark_left <= 0.0:
		_clear_mark()
		return
	_mark_visual.position = marked.view.render_position() + Vector3.UP * 1.6


func _clear_mark() -> void:
	marked = null
	mark_left = 0.0
	if _mark_visual != null and is_instance_valid(_mark_visual):
		_mark_visual.queue_free()
	_mark_visual = null


# --- Fente du vide ------------------------------------------------------------------------------------------------

## Fente vers la visée (arrêtée par le décor), invulnérable : frappe le premier ennemi traversé (Fente perçante :
## tous ceux de la ligne).
func _rend(data: SpellData, aim: Vector3) -> bool:
	var hunter: DraftHunter = run.hunter
	var here: Vector3 = hunter.global_position
	var landing: Vector3 = spells._landing(aim, spells.reach_of(data))
	var dir: Vector3 = DraftSpells._flat(landing - here)
	var length: float = dir.length()
	dir = dir.normalized() if length > 0.05 else hunter.facing.normalized()
	length = maxf(length, 1.0)
	var pierce: bool = spells.has_variant(data, &"pierce")
	var struck: Array[DraftEnemies.Foe] = []
	for foe: DraftEnemies.Foe in spells._level(run.enemies.near(here, length + 1.0), here):
		var offset: Vector3 = DraftSpells._flat(foe.pos - here)
		var along: float = offset.dot(dir)
		if along >= -0.3 and along <= length + 0.6 and (offset - dir * along).length() <= spells.area_of(data) + foe.radius:
			struck.append(foe)
	struck.sort_custom(func(a: DraftEnemies.Foe, b: DraftEnemies.Foe) -> bool:
		return DraftSpells._flat(a.pos - here).dot(dir) < DraftSpells._flat(b.pos - here).dot(dir))
	if not pierce and struck.size() > 1:
		struck.resize(1)
	run.fx(&"blink_out", DraftPixelFx.DEFAULT_FAMILY, here + Vector3.UP * 0.6)
	run.fx(&"heavy_cleave", DraftPixelFx.DEFAULT_FAMILY, here + dir * length * 0.5 + Vector3.UP * 0.7, length * 0.4)
	for foe: DraftEnemies.Foe in struck:
		run.fx(&"hit", DraftPixelFx.DEFAULT_FAMILY, foe.pos + Vector3.UP * 0.6, 1.2)
		run.enemies.hit(foe, spells.damage_of(data), dir * data.knockback * DraftHunter.UNIT)
	run.combos.on_rend(struck, spells.damage_of(data), dir, length, spells.area_of(data), pierce)
	hunter.leap_to(landing + Vector3.UP * 0.05, float(data.params.get("duration", 0.18)), 0.0)
	return true


# --- Pas de faille ------------------------------------------------------------------------------------------------

## Téléportation immédiate vers la visée (arrêtée par le décor) ; l'ombre laissée au départ éclate peu après.
func _blink(data: SpellData, aim: Vector3) -> bool:
	var hunter: DraftHunter = run.hunter
	var start: Vector3 = hunter.global_position
	var landing: Vector3 = spells._landing(aim, spells.reach_of(data))
	run.combos.on_blink(start)
	run.fx(&"blink_out", DraftPixelFx.DEFAULT_FAMILY, start + Vector3.UP * 0.6)
	hunter.global_position = landing + Vector3.UP * 0.05
	hunter.reset_motion()
	hunter.invulnerable = maxf(hunter.invulnerable, 0.2)
	run.fx(&"blink_in", DraftPixelFx.DEFAULT_FAMILY, landing + Vector3.UP * 0.6)
	var trap: bool = spells.has_variant(data, &"trap")
	shades.append({"at": start, "left": float(data.params.get("delay", 1.0)), "radius": spells.area_of(data),
		"damage": spells.damage_of(data), "slow": spells.param(data, "slow", 1.0) if trap else 1.0,
		"duration": spells.param(data, "duration", 0.0) if trap else 0.0,
		"visual": run.fx(&"shadow_hands", DraftPixelFx.DEFAULT_FAMILY, start + Vector3.UP * 0.4, 1.0, true)})
	return true


func _step_shades(delta: float) -> void:
	for i: int in range(shades.size() - 1, -1, -1):
		var shade: Dictionary = shades[i]
		shade["left"] = float(shade["left"]) - delta
		if float(shade["left"]) > 0.0:
			continue
		var at: Vector3 = shade["at"]
		run.fx(&"dark_explosion", DraftPixelFx.DEFAULT_FAMILY, at + Vector3.UP * 0.6, float(shade["radius"]))
		for foe: DraftEnemies.Foe in spells._level(run.enemies.near(at, float(shade["radius"])), at):
			run.enemies.hit(foe, float(shade["damage"]))
			if foe.alive and float(shade["duration"]) > 0.0:
				foe.slow(float(shade["slow"]), float(shade["duration"]))
		DraftSpellWorld._free(shade)
		shades.remove_at(i)


# --- Onde de stase ------------------------------------------------------------------------------------------------

## Cône devant le Chasseur (Onde circulaire : tout autour, portée réduite) : fige les ennemis, ralentit les boss.
## Éclats de stase : les ennemis figés subissent plus de dégâts le temps de la stase.
func _stasis(data: SpellData, aim: Vector3) -> bool:
	var here: Vector3 = run.hunter.global_position
	var dir: Vector3 = spells._direction(aim)
	var reach: float = spells.reach_of(data)
	var half: float = cos(deg_to_rad(clampf(data.width, 0.0, 180.0)))
	if spells.has_variant(data, &"circle"):
		reach *= spells.param(data, "reach", 1.0)
		half = -1.0
	var seconds: float = spells.duration_of(data)
	var shards: bool = spells.has_variant(data, &"shards")
	run.fx(&"frost_nova", &"givres", here + (Vector3.ZERO if half < 0.0 else dir * reach * 0.5) + Vector3.UP * 0.5,
		reach * 0.6)
	for foe: DraftEnemies.Foe in spells._level(run.enemies.near(here, reach), here):
		var offset: Vector3 = DraftSpells._flat(foe.pos - here)
		if offset.length() > foe.radius + 0.4 and offset.normalized().dot(dir) < half:
			continue
		run.enemies.hit(foe, spells.damage_of(data))
		if not foe.alive:
			continue
		foe.slow(float(data.params.get("boss_slow", 0.5)) if foe.boss != null else 0.0, seconds)
		run.combos.on_stasis(foe, seconds)
		if shards:
			foe.expose(spells.param(data, "bonus", 0.0), seconds)
	return true


# --- Pluie d'éclats -----------------------------------------------------------------------------------------------

## Zone au point visé où tombent des éclats à intervalle régulier. Orage : la zone suit le Chasseur.
## Concentration : zone plus petite, dégâts plus forts.
func _rain(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = spells._landing(aim, spells.reach_of(data))
	var radius: float = spells.area_of(data)
	var damage: float = spells.damage_of(data)
	var follow: bool = spells.has_variant(data, &"storm")
	if spells.has_variant(data, &"focus"):
		radius *= spells.param(data, "area", 1.0)
		damage *= spells.param(data, "damage", 1.0)
	spells.add_zone({"at": run.hunter.global_position if follow else at, "radius": radius,
		"left": spells.duration_of(data), "tick": float(data.params.get("tick", 0.4)), "clock": 0.0, "damage": damage,
		"follow": follow, "rain": true, "visual": null})
	return true


# --- Voile de cendre ----------------------------------------------------------------------------------------------

## Nuage autour du Chasseur : détruit les tirs ennemis qui y entrent et ralentit les ennemis dedans.
## Voile mobile : il suit le Chasseur. Contrecoup : chaque tir détruit rend des PV.
func _veil(data: SpellData) -> bool:
	var here: Vector3 = run.hunter.global_position
	var radius: float = spells.area_of(data)
	veils.append({"at": here, "radius": radius, "left": spells.duration_of(data),
		"follow": spells.has_variant(data, &"mobile"),
		"heal": spells.param(data, "heal", 0.0) if spells.has_variant(data, &"recoil") else 0.0,
		"slow": float(data.params.get("slow", 0.6)),
		"visual": run.fx(&"smoke_bomb", &"calcines", here + Vector3.UP * 0.6, radius * 0.9, true)})
	return true


func _step_veils(delta: float) -> void:
	for i: int in range(veils.size() - 1, -1, -1):
		var veil: Dictionary = veils[i]
		veil["left"] = float(veil["left"]) - delta
		if veil["follow"]:
			veil["at"] = run.hunter.global_position
			var visual: Variant = veil["visual"]
			if visual is Node3D and is_instance_valid(visual):
				(visual as Node3D).position = run.hunter.global_position + Vector3.UP * 0.6
		var at: Vector3 = veil["at"]
		var radius: float = veil["radius"]
		for foe: DraftEnemies.Foe in run.enemies.near(at, radius):
			if absf(foe.pos.y - at.y) <= DraftEnemies.MELEE_REACH_UP:
				foe.slow(float(veil["slow"]), 0.25)
		for s: int in range(run.hostile.size() - 1, -1, -1):
			var shot: Dictionary = run.hostile[s]
			if DraftSpells._flat((shot["at"] as Vector3) - at).length() <= radius:
				run.fx(&"smoke_puff", &"calcines", shot["at"], 0.6)
				(shot["visual"] as Node).queue_free()
				run.hostile.remove_at(s)
				shots_blocked += 1
				run.hunter.heal(float(veil["heal"]))
		if float(veil["left"]) <= 0.0:
			DraftSpellWorld._free(veil)
			veils.remove_at(i)
