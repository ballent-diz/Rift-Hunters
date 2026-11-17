class_name DraftCombos
extends RefCounted
## Combos de la v2 (docs/design/GAMEPLAY_COMBOS_2P5D.md, § 5 ; docs/design/GAMEPLAY_V2_ARCHITECTURE.md, lots 4 et 6).
## Un combo est *possible* dès que tous ses sorts sont équipés et ne se *déclenche* que sur un vrai événement :
## - Exécution prismatique : une Rupture qui frappe des ennemis touchés par la Lance prismatique depuis moins de
##   `combo_window` s déclenche sur chacun une détonation secondaire, qui achève les ennemis affaiblis (hors boss) ;
## - Déluge prismatique : une Lance prismatique qui traverse un Cristal réfracteur se brise en une gerbe d'éclats plus
##   nombreux et plus forts, plafonnée par cristal ;
## - Lame gravitationnelle : une Taille fendante qui atteint un puits de Singularité actif libère une onde de choc
##   sur les ennemis du puits et les expose (une fois par puits) ;
## - lot 6 (marque et Rupture) : Chasse dimensionnelle, Rupture du traqueur, Convergence prismatique ;
## - lot 6 (fenêtres) : Contre-faille, Rebond spectral, Égide vengeresse ;
## - lot 6 (terrain) : Prison de faille, Rempart fracassant, Tempête immobile.
## Un sort en réserve n'est jamais ingrédient : l'équipement est contrôlé à l'instant du déclenchement, y compris pour
## les objets laissés dans le monde (cristal, puits, mur, ombre). Aucun combo ne tire de projectile ni ne relance un
## sort : ses coups passent directement par `DraftEnemies.hit`, donc aucun combo n'en déclenche un autre (pas de
## réaction récursive). Réglages dans draft3d/tuning.tres (groupe « Combos »).

const EXECUTION := &"prismatic_execution"
const DELUGE := &"prismatic_deluge"
const GRAVITY_BLADE := &"gravity_blade"
const HUNT := &"dimensional_hunt"
const TRACKER := &"tracker_rupture"
const CONVERGENCE := &"prismatic_convergence"
const COUNTER := &"rift_counter"
const SPECTRAL := &"spectral_rebound"
const AEGIS := &"vengeful_aegis"
const PRISON := &"rift_prison"
const RAMPART := &"shattering_rampart"
const STORM := &"still_storm"
## Sorts requis par combo (tous équipés).
const RECIPES: Dictionary = {
	EXECUTION: [&"prismatic_lance", &"rupture"],
	DELUGE: [&"refracting_crystal", &"prismatic_lance"],
	GRAVITY_BLADE: [&"singularity", &"cleaving_slash"],
	HUNT: [&"hunter_mark", &"void_rend"],
	TRACKER: [&"hunter_mark", &"rupture"],
	CONVERGENCE: [&"prismatic_lance", &"refracting_crystal", &"rupture"],
	COUNTER: [&"parry", &"cleaving_slash"],
	SPECTRAL: [&"rift_step", &"void_rend"],
	AEGIS: [&"parry", &"aegis"],
	PRISON: [&"singularity", &"rift_wall"],
	RAMPART: [&"rift_leap", &"rift_wall"],
	STORM: [&"stasis_wave", &"shard_rain"],
}
const NAME_KEYS: Dictionary = {
	EXECUTION: "COMBO3D_PRISMATIC_EXECUTION_NAME",
	DELUGE: "COMBO3D_PRISMATIC_DELUGE_NAME",
	GRAVITY_BLADE: "COMBO3D_GRAVITY_BLADE_NAME",
	HUNT: "COMBO3D_DIMENSIONAL_HUNT_NAME",
	TRACKER: "COMBO3D_TRACKER_RUPTURE_NAME",
	CONVERGENCE: "COMBO3D_PRISMATIC_CONVERGENCE_NAME",
	COUNTER: "COMBO3D_RIFT_COUNTER_NAME",
	SPECTRAL: "COMBO3D_SPECTRAL_REBOUND_NAME",
	AEGIS: "COMBO3D_VENGEFUL_AEGIS_NAME",
	PRISON: "COMBO3D_RIFT_PRISON_NAME",
	RAMPART: "COMBO3D_SHATTERING_RAMPART_NAME",
	STORM: "COMBO3D_STILL_STORM_NAME",
}

var run: DraftRun
## Ennemis touchés par la Lance : Foe → temps restant de la fenêtre.
var lance_hits: Dictionary = {}
## Ennemis touchés par un éclat d'une Lance réfractée (Convergence) : Foe → temps restant de la fenêtre.
var prism_hits: Dictionary = {}
## Ennemis figés ou ralentis par l'Onde de stase (Tempête immobile) : Foe → temps restant.
var stasis_hits: Dictionary = {}
## Fenêtres ouvertes par une Parade réussie (Contre-faille) et par un Pas de faille (Rebond spectral, avec le point
## de départ du Pas, où reste l'ombre).
var counter_left: float = 0.0
var spectral_left: float = 0.0
var spectral_from := Vector3.ZERO
## Égide vengeresse : la prochaine riposte du bouclier en cours est renforcée.
var aegis_empowered: bool = false
## Nombre de déclenchements par combo (statistiques de partie, essais).
var counts: Dictionary = {}
## Dernière annonce de chaque combo (s), pour ne pas répéter la bannière.
var _announced: Dictionary = {}


func _init(p_run: DraftRun) -> void:
	run = p_run


## Les deux sorts du combo sont équipés (jamais en réserve).
func possible(combo: StringName) -> bool:
	for id: StringName in RECIPES[combo]:
		if not run.spells.has_spell(id):
			return false
	return true


func step(delta: float) -> void:
	for table: Dictionary in [lance_hits, prism_hits, stasis_hits]:
		_tick(table, delta)
	counter_left = maxf(counter_left - delta, 0.0)
	spectral_left = maxf(spectral_left - delta, 0.0)
	if aegis_empowered and run.hunter.shield <= 0.0:
		aegis_empowered = false


static func _tick(table: Dictionary, delta: float) -> void:
	for foe: Variant in table.keys():
		var left: float = float(table[foe]) - delta
		if left <= 0.0 or not (foe as DraftEnemies.Foe).alive:
			table.erase(foe)
		else:
			table[foe] = left


# --- Exécution prismatique --------------------------------------------------------------------------------------

## Un trait du Chasseur vient de toucher `foe` : Lance (Exécution) et Lance réfractée ou ses éclats (Convergence).
func on_bolt_hit(shot: Dictionary, foe: DraftEnemies.Foe) -> void:
	if shot.get("lance", false):
		on_lance_hit(foe)
	if shot.get("prism", false) or (shot.get("lance", false) and shot.get("refracted", false)):
		on_prism_hit(foe)


## Un trait de Lance prismatique vient de toucher `foe`.
func on_lance_hit(foe: DraftEnemies.Foe) -> void:
	lance_hits[foe] = run.tuning.combo_window


## Après la détonation d'une Rupture (rebonds de Réaction compris) : Exécution prismatique, Rupture du traqueur et
## Convergence prismatique, chacune au plus une fois par Rupture. Renvoie le nombre de cibles de l'Exécution.
func on_rupture(struck: Array[DraftEnemies.Foe], damage: float) -> int:
	var executed: int = _execution(struck, damage)
	_tracker(struck, damage)
	_convergence(struck, damage)
	return executed


## Détonation secondaire sur les cibles de la Lance. Renvoie le nombre de cibles.
func _execution(struck: Array[DraftEnemies.Foe], damage: float) -> int:
	if lance_hits.is_empty() or not possible(EXECUTION):
		return 0
	var tuning: DraftTuning = run.tuning
	var targets: Array[DraftEnemies.Foe] = []
	for foe: DraftEnemies.Foe in struck:
		if foe.alive and lance_hits.has(foe) and targets.size() < tuning.combo_execution_max:
			targets.append(foe)
	if targets.is_empty():
		return 0
	for foe: DraftEnemies.Foe in targets:
		lance_hits.erase(foe)
		run.fx_or(&"combo_prismatic_execution", 2.0, &"ring_burst", &"reflets", foe.pos + Vector3.UP * 0.6, 1.3)
		var blow: float = damage * tuning.combo_execution_mult
		if foe.boss == null and foe.hp - blow <= foe.max_hp * tuning.combo_execution_threshold:
			blow = foe.hp + foe.max_hp
		run.enemies.hit(foe, blow)
	_announce(EXECUTION)
	return targets.size()


# --- Déluge prismatique -----------------------------------------------------------------------------------------

## Réfraction d'un trait par `crystal` : réglages du Déluge si le trait est une Lance et que le combo est possible,
## sinon réfraction ordinaire. Renvoie {split, angle, damage}.
func refraction(shot: Dictionary, crystal: Dictionary) -> Dictionary:
	var tuning: DraftTuning = run.tuning
	var plain := {"split": tuning.crystal_split, "angle": tuning.crystal_angle, "damage": tuning.crystal_damage}
	if not shot.get("lance", false) or not possible(DELUGE):
		return plain
	var left: int = int(crystal.get("deluge_left", tuning.combo_deluge_cap))
	if left <= 0:
		return plain
	var split: int = mini(tuning.combo_deluge_split, left)
	crystal["deluge_left"] = left - split
	run.fx_or(&"combo_prismatic_deluge", 3.0, &"ice_shatter", &"givres", (crystal["at"] as Vector3) + Vector3.UP * 0.8,
		2.0)
	_announce(DELUGE)
	return {"split": split, "angle": tuning.combo_deluge_angle, "damage": tuning.combo_deluge_damage}


# --- Lame gravitationnelle --------------------------------------------------------------------------------------

## Une Taille fendante part de `here` vers `dir` (`reach` m, demi-angle `half` en cosinus, -1 : tout autour).
## Chaque puits atteint (pas encore utilisé) libère une onde. Renvoie le nombre d'ondes.
## La Contre-faille (Parade réussie peu avant) se joue d'abord, sur la même Taille.
func on_slash(here: Vector3, dir: Vector3, reach: float, half: float, damage: float) -> int:
	_counter(here, reach, damage)
	if run.spells.world.wells.is_empty() or not possible(GRAVITY_BLADE):
		return 0
	var tuning: DraftTuning = run.tuning
	var waves: int = 0
	for well: Dictionary in run.spells.world.wells:
		var at: Vector3 = well["at"]
		var radius: float = well["radius"]
		if well.get("combo", false) or absf(at.y - here.y) > DraftEnemies.MELEE_REACH_UP:
			continue
		var offset: Vector3 = DraftSpells._flat(at - here)
		var inside: bool = offset.length() <= radius
		if not inside and (offset.length() > reach + radius or offset.normalized().dot(dir) < half):
			continue
		well["combo"] = true
		waves += 1
		var area: float = radius * tuning.combo_gravity_area
		run.fx_or(&"combo_gravity_blade", area * 2.0, &"dark_explosion", DraftPixelFx.DEFAULT_FAMILY,
			at + Vector3.UP * 0.6, area)
		for foe: DraftEnemies.Foe in run.spells._level(run.enemies.near(at, radius * tuning.combo_gravity_area), at):
			foe.expose(tuning.combo_gravity_expose, tuning.combo_gravity_expose_time)
			run.enemies.hit(foe, damage * tuning.combo_gravity_mult, DraftSpells._flat(foe.pos - at).normalized() * 4.0)
	if waves > 0:
		_announce(GRAVITY_BLADE)
	return waves


# --- Marque et Rupture (lot 6) ------------------------------------------------------------------------------------

## Ennemi marqué par la Marque du traqueur (null sans marque).
func _marked() -> DraftEnemies.Foe:
	var foe: DraftEnemies.Foe = run.spells.rift.marked if run.spells.rift != null else null
	return foe if foe != null and foe.alive else null


## Chasse dimensionnelle : la Fente du vide traverse la cible marquée, une frappe secondaire la suit.
## Rebond spectral : une Fente lancée peu après un Pas de faille repart aussi de l'ombre laissée au départ du Pas.
## `struck` : ennemis frappés par la Fente ; `dir`, `length`, `width` : sa ligne ; `pierce` : Fente perçante.
func on_rend(struck: Array[DraftEnemies.Foe], damage: float, dir: Vector3, length: float, width: float,
		pierce: bool) -> void:
	var tuning: DraftTuning = run.tuning
	var target: DraftEnemies.Foe = _marked()
	if target != null and struck.has(target) and possible(HUNT):
		run.fx_or(&"combo_dimensional_hunt", 2.0, &"claw_swipe", DraftPixelFx.DEFAULT_FAMILY,
			target.pos + Vector3.UP * 0.7, 1.4)
		run.enemies.hit(target, damage * tuning.combo_hunt_mult, dir * 2.0)
		_announce(HUNT)
	if spectral_left > 0.0 and possible(SPECTRAL):
		spectral_left = 0.0
		var from: Vector3 = spectral_from
		if not DraftPixelFx.has_sheet(&"combo_spectral_rebound"):
			run.fx(&"blink_out", DraftPixelFx.DEFAULT_FAMILY, from + Vector3.UP * 0.6)
		run.fx_or(&"combo_spectral_rebound", 3.0, &"heavy_cleave", DraftPixelFx.DEFAULT_FAMILY,
			from + dir * length * 0.5 + Vector3.UP * 0.7, length * 0.4)
		for foe: DraftEnemies.Foe in _line(from, dir, length, width, pierce):
			run.enemies.hit(foe, damage * tuning.combo_spectral_mult, dir * 2.0)
		_announce(SPECTRAL)


## Un Pas de faille part de `from` : la fenêtre du Rebond spectral s'ouvre.
func on_blink(from: Vector3) -> void:
	spectral_left = run.tuning.combo_window
	spectral_from = from


## Ennemis de la ligne `from` → `dir` × `length` (demi-largeur `width`), du plus proche au plus loin ; le premier
## seulement sans `pierce`.
func _line(from: Vector3, dir: Vector3, length: float, width: float, pierce: bool) -> Array[DraftEnemies.Foe]:
	var result: Array[DraftEnemies.Foe] = []
	for foe: DraftEnemies.Foe in run.spells._level(run.enemies.near(from, length + 1.0), from):
		var offset: Vector3 = DraftSpells._flat(foe.pos - from)
		var along: float = offset.dot(dir)
		if along >= -0.3 and along <= length + 0.6 and (offset - dir * along).length() <= width + foe.radius:
			result.append(foe)
	result.sort_custom(func(a: DraftEnemies.Foe, b: DraftEnemies.Foe) -> bool:
		return DraftSpells._flat(a.pos - from).dot(dir) < DraftSpells._flat(b.pos - from).dot(dir))
	if not pierce and result.size() > 1:
		result.resize(1)
	return result


## Rupture du traqueur : la Rupture atteint la cible marquée, une explosion concentrée éclate sur elle.
func _tracker(struck: Array[DraftEnemies.Foe], damage: float) -> void:
	var target: DraftEnemies.Foe = _marked()
	if target == null or not struck.has(target) or not possible(TRACKER):
		return
	var tuning: DraftTuning = run.tuning
	var at: Vector3 = target.pos
	run.fx_or(&"combo_tracker_rupture", 2.4, &"small_explosion", &"fallen",
		at + Vector3.UP * 0.6, tuning.combo_tracker_radius)
	for foe: DraftEnemies.Foe in run.spells._level(run.enemies.near(at, tuning.combo_tracker_radius), at):
		run.enemies.hit(foe, damage * (tuning.combo_tracker_mult if foe == target else tuning.combo_tracker_splash))
	_announce(TRACKER)


## Un trait issu d'une Lance réfractée (la Lance après le Cristal ou ses éclats) vient de toucher `foe`.
func on_prism_hit(foe: DraftEnemies.Foe) -> void:
	prism_hits[foe] = run.tuning.combo_window


## Convergence prismatique : la Rupture atteint une cible de la Lance réfractée ; un arc saute d'ennemi en ennemi,
## `combo_convergence_jumps` fois au plus, sans jamais revenir sur un ennemi déjà touché.
func _convergence(struck: Array[DraftEnemies.Foe], damage: float) -> void:
	if prism_hits.is_empty() or not possible(CONVERGENCE):
		return
	var start: DraftEnemies.Foe = null
	for foe: DraftEnemies.Foe in struck:
		if foe.alive and prism_hits.has(foe):
			start = foe
			break
	if start == null:
		return
	for foe: DraftEnemies.Foe in struck:
		prism_hits.erase(foe)
	var tuning: DraftTuning = run.tuning
	var chained: Array[DraftEnemies.Foe] = [start]
	var from: DraftEnemies.Foe = start
	for jump: int in tuning.combo_convergence_jumps:
		var next: DraftEnemies.Foe = null
		for foe: DraftEnemies.Foe in run.spells._level(run.enemies.near(from.pos, tuning.combo_convergence_reach), from.pos):
			if not chained.has(foe):
				next = foe
				break
		if next == null:
			break
		chained.append(next)
		from = next
	for foe: DraftEnemies.Foe in chained:
		run.fx_or(&"combo_prismatic_convergence", 2.4, &"zap_hit", &"highlands", foe.pos + Vector3.UP * 0.7, 1.2)
		run.enemies.hit(foe, damage * tuning.combo_convergence_mult)
	_announce(CONVERGENCE)


# --- Fenêtres (lot 6) ---------------------------------------------------------------------------------------------

## Parade réussie : ouvre la Contre-faille ; si l'Égide protège le Chasseur, sa prochaine riposte est renforcée.
func on_parried() -> void:
	counter_left = run.tuning.combo_window
	if run.hunter.shield > 0.0 and possible(AEGIS):
		aegis_empowered = true


## Contre-faille : la Taille qui suit une Parade réussie déclenche une contre-attaque élargie tout autour.
func _counter(here: Vector3, reach: float, damage: float) -> void:
	if counter_left <= 0.0 or not possible(COUNTER):
		return
	counter_left = 0.0
	var tuning: DraftTuning = run.tuning
	var radius: float = reach * tuning.combo_counter_area
	run.fx_or(&"combo_counter_rift", radius * 2.0, &"ring_burst", DraftPixelFx.DEFAULT_FAMILY,
		here + Vector3.UP * 0.5, radius)
	for foe: DraftEnemies.Foe in run.spells._level(run.enemies.near(here, radius), here):
		run.enemies.hit(foe, damage * tuning.combo_counter_mult, DraftSpells._flat(foe.pos - here).normalized() * 4.0)
		if foe.alive and foe.boss == null:
			foe.slow(0.0, tuning.parry_stun)
	_announce(COUNTER)


## Égide vengeresse : multiplicateur de la riposte quand le bouclier cède (1 sans combo) ; consomme le renfort.
func riposte_power() -> float:
	if not aegis_empowered or not possible(AEGIS):
		aegis_empowered = false
		return 1.0
	aegis_empowered = false
	_announce(AEGIS)
	return 1.0 + run.tuning.combo_aegis_bonus


# --- Terrain (lot 6) ----------------------------------------------------------------------------------------------

## Prison de faille : les ennemis attirés par le puits `well` près d'un Mur de faille sont entravés (une fois par
## ennemi et par puits, `combo_prison_cap` au plus par puits ; jamais les boss, que le puits n'attire pas).
func on_well(well: Dictionary) -> void:
	var walls: Array[Dictionary] = run.spells.world.walls
	if walls.is_empty() or not possible(PRISON):
		return
	var tuning: DraftTuning = run.tuning
	var held: Array = well.get("prisoned", [])
	if held.size() >= tuning.combo_prison_cap:
		return
	var at: Vector3 = well["at"]
	for foe: DraftEnemies.Foe in run.enemies.near(at, float(well["radius"]) * 1.6):
		if foe.boss != null or held.has(foe) or absf(foe.pos.y - at.y) > DraftEnemies.MELEE_REACH_UP:
			continue
		if _wall_distance(foe.pos, walls) > tuning.combo_prison_reach + foe.radius:
			continue
		held.append(foe)
		foe.slow(0.0, tuning.combo_prison_root)
		run.fx(&"root_snare", &"enlises", foe.pos + Vector3.UP * 0.3, 1.0)
		if held.size() >= tuning.combo_prison_cap:
			break
	if not held.is_empty() and not well.get("prison", false):
		well["prison"] = true
		if DraftPixelFx.has_sheet(&"combo_rift_prison"):
			run.fx_or(&"combo_rift_prison", float(well["radius"]) * 2.0, &"root_snare", &"enlises",
				at + Vector3.UP * 0.6)
		_announce(PRISON)
	well["prisoned"] = held


## Rempart fracassant : le Bond de faille atterrit près d'un Mur actif ; chaque mur proche libère une onde de choc
## (une fois par mur). `damage` : dégâts de l'onde d'atterrissage du Bond.
func on_landed(landing: Vector3, damage: float) -> int:
	var walls: Array[Dictionary] = run.spells.world.walls
	if walls.is_empty() or not possible(RAMPART):
		return 0
	var tuning: DraftTuning = run.tuning
	var waves: int = 0
	for wall: Dictionary in walls:
		if wall.get("rampart", false) or _wall_distance(landing, [wall] as Array[Dictionary]) > tuning.combo_rampart_reach:
			continue
		wall["rampart"] = true
		waves += 1
		var a: Vector3 = wall["a"]
		var b: Vector3 = wall["b"]
		var center: Vector3 = (a + b) * 0.5
		run.fx_or(&"combo_shattering_bastion", a.distance_to(b) * 1.2, &"quake", &"highlands",
			center + Vector3.UP * 0.4, a.distance_to(b) * 0.6)
		for foe: DraftEnemies.Foe in run.enemies.near(center, a.distance_to(b) * 0.5 + tuning.combo_rampart_area):
			var closest: Vector3 = Geometry3D.get_closest_point_to_segment(foe.pos, a, b)
			var away: Vector3 = DraftSpells._flat(foe.pos - closest)
			if away.length() > tuning.combo_rampart_area + foe.radius or absf(foe.pos.y - a.y) > DraftEnemies.MELEE_REACH_UP:
				continue
			run.enemies.hit(foe, damage * tuning.combo_rampart_mult, away.normalized() * 5.0)
	if waves > 0:
		_announce(RAMPART)
	return waves


## Distance au sol de `at` au Mur le plus proche (du même niveau), INF sans mur.
static func _wall_distance(at: Vector3, walls: Array[Dictionary]) -> float:
	var best: float = INF
	for wall: Dictionary in walls:
		var a: Vector3 = wall["a"]
		if absf(at.y - a.y) > DraftEnemies.MELEE_REACH_UP:
			continue
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(at, a, wall["b"])
		best = minf(best, DraftSpells._flat(at - closest).length())
	return best


## L'Onde de stase vient de figer (ou de ralentir, pour un boss) `foe` pendant `seconds`.
func on_stasis(foe: DraftEnemies.Foe, seconds: float) -> void:
	stasis_hits[foe] = seconds


## Tempête immobile : à chaque coup de la Pluie d'éclats, des éclats supplémentaires tombent sur les ennemis pris
## par l'Onde de stase dans la zone (`combo_storm_cap` au plus par coup).
func on_rain_tick(at: Vector3, radius: float, damage: float) -> int:
	if stasis_hits.is_empty() or not possible(STORM):
		return 0
	var tuning: DraftTuning = run.tuning
	var extra: int = 0
	for foe: DraftEnemies.Foe in run.spells._level(run.enemies.near(at, radius), at):
		if extra >= tuning.combo_storm_cap:
			break
		if not stasis_hits.has(foe):
			continue
		extra += 1
		run.fx_or(&"combo_still_storm", 2.0, &"ice_shatter_small", &"givres", foe.pos + Vector3.UP * 0.8, 0.9)
		run.enemies.hit(foe, damage * tuning.combo_storm_mult)
	if extra > 0:
		_announce(STORM)
	return extra


func _announce(combo: StringName) -> void:
	counts[combo] = int(counts.get(combo, 0)) + 1
	# Les combos à répétition (Tempête immobile à chaque coup) n'annoncent qu'une fois par `combo_banner_gap` s.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_announced.get(combo, -INF)) < run.tuning.combo_banner_gap:
		return
	_announced[combo] = now
	Audio.play_sfx(&"technique")
	if run.hud != null:
		run.hud.banner(tr(NAME_KEYS[combo]), 1.6)
