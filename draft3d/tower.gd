class_name DraftTower
extends RefCounted
## Tour du chapitre 6 (docs/maps/CARTES_3D.md) : trois étages en anneau (DraftLevelRing, `floor_index` 0 à 2) joués
## à la suite dans la même partie. Fin d'un étage à la durée : `floor_time` secondes après l'arrivée, la herse de la
## rampe se lève (à l'étage du gardien, il faut aussi l'avoir vaincu) ; atteindre le palier fait monter d'un étage.
## Le gardien n'apparaît qu'au deuxième étage, le Dévoreur qu'au sommet. Le Chasseur garde tout (niveau,
## améliorations, sorts) ; ennemis, attaques et projectiles de l'étage quitté disparaissent, ses cristaux sont acquis.

const CHAPTER := 6
const GUARDIAN_FLOOR := 1
## Rayon autour du palier de sortie qui déclenche la montée (m).
const EXIT_REACH := 3.0

var run: DraftRun
var floor_index: int = 0
var opened: bool = false
## Moment (temps de partie) de l'arrivée à l'étage en cours.
var arrived_at: float = 0.0
var climbing: bool = false


static func applies(chapter: int) -> bool:
	return chapter == CHAPTER


static func floor_level(index: int) -> DraftLevelRing:
	var level := DraftLevelRing.new()
	level.floor_index = index
	return level


func _init(host: DraftRun) -> void:
	run = host


func first_level() -> DraftLevel:
	return floor_level(0)


func summit() -> bool:
	return floor_index == DraftLevelRing.TOP_FLOOR


func floor_key() -> String:
	return "DRAFT_TOWER_FLOOR_%d" % (floor_index + 1)


## Le gardien du chapitre n'apparaît qu'à son étage, un moment après l'arrivée.
func guardian_due() -> bool:
	return floor_index == GUARDIAN_FLOOR and run.time >= arrived_at + run.tuning.tower_guardian_delay


## Le Dévoreur n'apparaît qu'au sommet, à l'heure prévue, mais jamais dès l'arrivée.
func boss_due() -> bool:
	return summit() and run.time >= maxf(run.boss_time, arrived_at + run.tuning.tower_boss_delay)


## Appelée à chaque pas de la partie : ouverture de la rampe, puis montée quand le Chasseur atteint le palier.
func step() -> void:
	if summit() or climbing:
		return
	if not opened and _floor_done():
		opened = true
		(run.level as DraftLevelRing).open_ramp()
		run.hud.banner(run.tr("DRAFT_TOWER_RAMP_OPEN"), 3.0)
		Audio.play_sfx(&"elite_spawn")
	if opened and run.hunter.global_position.distance_to(run.level.exit_point) < EXIT_REACH:
		climb()


func _floor_done() -> bool:
	if run.time < arrived_at + run.tuning.tower_floor_time:
		return false
	if floor_index == GUARDIAN_FLOOR and not run.roster.guardians.is_empty():
		return run.guardian_defeated()
	return true


func climb() -> void:
	climbing = true
	floor_index += 1
	opened = false
	var next: DraftLevelRing = floor_level(floor_index)
	await run.change_level(next)
	arrived_at = run.time
	run.hud.banner(run.tr(floor_key()), 3.0)
	climbing = false


## But du bot : le palier de sortie dès que la rampe est ouverte.
func bot_goal() -> Vector3:
	return run.level.exit_point if opened else Vector3.INF
