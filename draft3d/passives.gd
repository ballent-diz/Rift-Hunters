class_name DraftPassives
extends RefCounted
## Passifs techniques de l'expédition (docs/design/GAMEPLAY_COMBOS_2P5D.md, § 6) : ils changent une action, pas une
## statistique. Sans plafond ; une fois chacun. Réglages dans draft3d/tuning.tres (groupe « Passifs »).
## - dash_blade (Ruée tranchante) : la Ruée blesse les ennemis traversés ;
## - void_wake (Sillage du vide) : la Ruée laisse une traînée qui ralentit ;
## - counter_cut (Contre-taille) : esquiver un coup pendant la Ruée renforce le sort suivant ;
## - anchor (Ancre) : un ennemi ralenti ou immobilisé qui meurt s'effondre en petite Singularité.

const ALL: Array[StringName] = [&"dash_blade", &"void_wake", &"counter_cut", &"anchor"]

var run: DraftRun
var tuning: DraftTuning
var owned: Dictionary = {}
## Contre-taille : temps restant pour profiter du sort renforcé.
var empowered_left: float = 0.0
## Sillage du vide : points de la traînée {at, left}.
var trail: Array[Dictionary] = []
var _dash_hit: Array[DraftEnemies.Foe] = []
var _was_dashing: bool = false
var _trail_clock: float = 0.0
var _anchor_ready: float = 0.0


func _init(p_run: DraftRun) -> void:
	run = p_run
	tuning = run.tuning
	run.hunter.dodged.connect(_on_dodged)


func has(id: StringName) -> bool:
	return owned.has(id)


func add(id: StringName) -> void:
	if ALL.has(id):
		owned[id] = true


func step(delta: float) -> void:
	tuning = run.tuning
	empowered_left = maxf(empowered_left - delta, 0.0)
	_anchor_ready = maxf(_anchor_ready - delta, 0.0)
	var hunter: DraftHunter = run.hunter
	var dashing: bool = hunter.is_dashing()
	if dashing and not _was_dashing:
		_dash_hit.clear()
	if dashing and has(&"dash_blade"):
		_dash_blade(hunter.global_position)
	if dashing and has(&"void_wake"):
		_trail_clock -= delta
		if _trail_clock <= 0.0:
			_trail_clock = 0.08
			trail.append({"at": hunter.global_position, "left": tuning.void_wake_duration,
				"visual": run.fx_or(&"passive_void_wake", tuning.void_wake_radius * 2.0, &"shadow_hands",
					DraftPixelFx.DEFAULT_FAMILY, hunter.global_position + Vector3.UP * 0.2, 0.5)})
	_was_dashing = dashing
	_step_trail(delta)


func _dash_blade(here: Vector3) -> void:
	for foe: DraftEnemies.Foe in run.enemies.near(here, tuning.dash_blade_radius):
		if _dash_hit.has(foe) or absf(foe.pos.y - here.y) > DraftEnemies.MELEE_REACH_UP:
			continue
		_dash_hit.append(foe)
		run.fx_or(&"passive_dash_blade", 1.4, &"hit", DraftPixelFx.DEFAULT_FAMILY, foe.pos + Vector3.UP * 0.6)
		run.enemies.hit(foe, tuning.dash_blade_damage * run.hunter.stats.get_value(StatKeys.DAMAGE))


func _step_trail(delta: float) -> void:
	for i: int in range(trail.size() - 1, -1, -1):
		var point: Dictionary = trail[i]
		point["left"] = float(point["left"]) - delta
		var at: Vector3 = point["at"]
		for foe: DraftEnemies.Foe in run.enemies.near(at, tuning.void_wake_radius):
			if absf(foe.pos.y - at.y) <= DraftEnemies.MELEE_REACH_UP:
				foe.slow(tuning.void_wake_slow, 0.3)
		if float(point["left"]) <= 0.0:
			trail.remove_at(i)


func _on_dodged() -> void:
	if has(&"counter_cut"):
		empowered_left = tuning.counter_cut_window
		run.fx_or(&"passive_counter_cut", 2.2, &"ring_burst", DraftPixelFx.DEFAULT_FAMILY, run.hunter.chest(), 1.2)


## Puissance du prochain sort (Contre-taille), ×1 sans esquive récente.
func power() -> float:
	return tuning.counter_cut_power if empowered_left > 0.0 else 1.0


## Un sort est parti : la Contre-taille est consommée.
func consume() -> void:
	empowered_left = 0.0


## Ancre : la mort d'un ennemi ralenti ou immobilisé crée une petite Singularité (délai minimal entre deux).
func on_kill(foe: DraftEnemies.Foe) -> void:
	if not has(&"anchor") or foe.slow_left <= 0.0 or _anchor_ready > 0.0 or foe.boss != null:
		return
	_anchor_ready = tuning.anchor_cooldown
	run.spells.world.add_well(foe.pos, tuning.anchor_radius, tuning.anchor_duration, 3.0,
		tuning.anchor_damage * run.hunter.stats.get_value(StatKeys.DAMAGE))
