class_name DraftCombos
extends RefCounted
## Combos MVP (docs/design/GAMEPLAY_COMBOS_2P5D.md, § 5 ; docs/design/GAMEPLAY_V2_ARCHITECTURE.md, lot 4).
## Un combo est *possible* dès que ses deux sorts sont équipés et ne se *déclenche* que sur un vrai événement :
## - Exécution prismatique : une Rupture qui frappe des ennemis touchés par la Lance prismatique depuis moins de
##   `combo_window` s déclenche sur chacun une détonation secondaire, qui achève les ennemis affaiblis (hors boss) ;
## - Déluge prismatique : une Lance prismatique qui traverse un Cristal réfracteur se brise en une gerbe d'éclats plus
##   nombreux et plus forts, plafonnée par cristal ;
## - Lame gravitationnelle : une Taille fendante qui atteint un puits de Singularité actif libère une onde de choc
##   sur les ennemis du puits et les expose (une fois par puits).
## Un sort en réserve n'est jamais ingrédient : l'équipement est contrôlé à l'instant du déclenchement, y compris pour
## les objets laissés dans le monde (cristal, puits). Réglages dans draft3d/tuning.tres (groupe « Combos »).

const EXECUTION := &"prismatic_execution"
const DELUGE := &"prismatic_deluge"
const GRAVITY_BLADE := &"gravity_blade"
## Sorts requis par combo (équipés tous les deux).
const RECIPES: Dictionary = {
	EXECUTION: [&"prismatic_lance", &"rupture"],
	DELUGE: [&"refracting_crystal", &"prismatic_lance"],
	GRAVITY_BLADE: [&"singularity", &"cleaving_slash"],
}
const NAME_KEYS: Dictionary = {
	EXECUTION: "COMBO3D_PRISMATIC_EXECUTION_NAME",
	DELUGE: "COMBO3D_PRISMATIC_DELUGE_NAME",
	GRAVITY_BLADE: "COMBO3D_GRAVITY_BLADE_NAME",
}

var run: DraftRun
## Ennemis touchés par la Lance : Foe → temps restant de la fenêtre.
var lance_hits: Dictionary = {}
## Nombre de déclenchements par combo (statistiques de partie, essais).
var counts: Dictionary = {}


func _init(p_run: DraftRun) -> void:
	run = p_run


## Les deux sorts du combo sont équipés (jamais en réserve).
func possible(combo: StringName) -> bool:
	for id: StringName in RECIPES[combo]:
		if not run.spells.has_spell(id):
			return false
	return true


func step(delta: float) -> void:
	for foe: Variant in lance_hits.keys():
		var left: float = float(lance_hits[foe]) - delta
		if left <= 0.0 or not (foe as DraftEnemies.Foe).alive:
			lance_hits.erase(foe)
		else:
			lance_hits[foe] = left


# --- Exécution prismatique --------------------------------------------------------------------------------------

## Un trait de Lance prismatique vient de toucher `foe`.
func on_lance_hit(foe: DraftEnemies.Foe) -> void:
	lance_hits[foe] = run.tuning.combo_window


## Après la détonation d'une Rupture : détonation secondaire sur les cibles de la Lance. Renvoie le nombre de cibles.
func on_rupture(struck: Array[DraftEnemies.Foe], damage: float) -> int:
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
		run.fx(&"ring_burst", &"reflets", foe.pos + Vector3.UP * 0.6, 1.3)
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
	run.fx(&"ice_shatter", &"reflets", (crystal["at"] as Vector3) + Vector3.UP * 0.8, 2.0)
	_announce(DELUGE)
	return {"split": split, "angle": tuning.combo_deluge_angle, "damage": tuning.combo_deluge_damage}


# --- Lame gravitationnelle --------------------------------------------------------------------------------------

## Une Taille fendante part de `here` vers `dir` (`reach` m, demi-angle `half` en cosinus, -1 : tout autour).
## Chaque puits atteint (pas encore utilisé) libère une onde. Renvoie le nombre d'ondes.
func on_slash(here: Vector3, dir: Vector3, reach: float, half: float, damage: float) -> int:
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
		run.fx(&"dark_explosion", DraftPixelFx.DEFAULT_FAMILY, at + Vector3.UP * 0.6, radius * tuning.combo_gravity_area)
		for foe: DraftEnemies.Foe in run.spells._level(run.enemies.near(at, radius * tuning.combo_gravity_area), at):
			foe.expose(tuning.combo_gravity_expose, tuning.combo_gravity_expose_time)
			run.enemies.hit(foe, damage * tuning.combo_gravity_mult, DraftSpells._flat(foe.pos - at).normalized() * 4.0)
	if waves > 0:
		_announce(GRAVITY_BLADE)
	return waves


func _announce(combo: StringName) -> void:
	counts[combo] = int(counts.get(combo, 0)) + 1
	Audio.play_sfx(&"technique")
	if run.hud != null:
		run.hud.banner(tr(NAME_KEYS[combo]), 1.6)
