class_name DraftBossBrain
extends RefCounted
## Cerveau d'un boss de la base 3D, piloté par ses données d'origine (docs/design/BOSS_V2.md, lot 0) :
## - phases et seuils de `BossData.phases` (2, 3 ou 6), vitesse, défense et rythme propres à chaque phase ;
## - techniques pondérées de `BossPatternData` (recharge, annonce, dégâts, animation `params.anim`), regroupées en
##   gestes 3D (`GESTURES`) ; une mécanique phare (`DraftBossMechanic`) peut en prendre en charge ;
## - déplacements : poursuite, tournoiement autour du Chasseur, recul après un gros coup, rapprochements annoncés
##   (charge arrêtée par le décor, bond, saut de faille), enchaînements plus longs à chaque phase ;
## - transitions (onde, clip, changement de feuille, idle de phase), intro, réaction aux gros coups, mort.
## Un boss n'est jamais totalement invulnérable : les coups sont réduits (transition, en l'air), jamais annulés.

const UNIT := DraftHunter.UNIT
## Geste 3D joué pour chaque technique des données. Les mécaniques phares encore à importer (lots 1 à 10) jouent
## en attendant le geste commun le plus proche.
const GESTURES := {
	&"claw": &"claw", &"sweep": &"sweep", &"slam": &"slam", &"bark_guard": &"slam", &"swallow": &"slam",
	&"shadow_wave": &"wave", &"tide_wave": &"wave", &"star_crown": &"wave", &"absorb": &"wave",
	&"quake": &"quake", &"whirlpool": &"quake",
	&"rock_rain": &"rain", &"slag_rain": &"rain", &"crater_sequence": &"rain", &"mud_wall": &"rain",
	&"rune_barrage": &"rain", &"source_orb": &"rain", &"spore_veil": &"rain",
	&"summon": &"summon", &"leech_feed": &"summon", &"war_cry": &"summon", &"pantheon_wake": &"summon",
	&"abyss_echoes": &"summon",
	&"void_beam": &"beam", &"prism_beam": &"beam", &"soul_chain": &"beam",
	&"eye_beam": &"sweep_beam", &"breath": &"breath",
	&"charge": &"charge", &"pyre_ram": &"charge", &"storm_hunt": &"charge",
	&"blink": &"blink", &"portal_hop": &"blink", &"mist_veil": &"blink",
	&"skyfall": &"leap", &"frozen_dive": &"leap", &"maw_dive": &"leap",
	&"ice_spikes": &"spikes", &"root_leash": &"spikes", &"root_snare": &"spikes", &"floe_quake": &"spikes",
	&"avalanche": &"spikes", &"silk_threads": &"spikes",
	&"shatter_floor": &"burst", &"deep_freeze": &"burst", &"duel_circle": &"burst", &"spell_capture": &"burst",
}
## Gestes portés au corps à corps : choisis seulement à portée et de plain-pied.
const MELEE := [&"claw", &"sweep", &"slam"]
## Gros gestes après lesquels le boss recule un instant.
const HEAVY := [&"slam", &"wave", &"quake", &"burst", &"leap"]
## Animations candidates par geste, après `params.anim` et l'animation d'origine du type.
const GESTURE_CLIPS := {
	&"claw": [&"claws", &"claw", &"attack"], &"sweep": [&"root_sweep", &"attack"],
	&"slam": [&"heavy_slam", &"phase2_slam", &"attack"], &"wave": [&"shadow_wave", &"roar", &"attack"],
	&"quake": [&"heavy_slam", &"roar", &"attack"], &"rain": [&"crater_rain", &"phase2_attack", &"attack"],
	&"summon": [&"summon", &"brood_call", &"roar", &"attack"], &"beam": [&"ray_sweep", &"phase2_attack", &"attack"],
	&"sweep_beam": [&"ray_sweep", &"rift_eye", &"phase2_attack", &"attack"],
	&"breath": [&"rift_breath", &"magma_breath", &"blizzard_breath", &"phase2_breath", &"attack"],
	&"charge": [&"charge", &"slide", &"belly_charge", &"attack"], &"blink": [&"blink", &"attack"],
	&"leap": [&"skyfall", &"pounce", &"frozen_dive", &"dive", &"attack"],
	&"spikes": [&"ice_spikes", &"root_lash", &"roots", &"attack"], &"burst": [&"shatter_floor", &"roar", &"attack"],
}
const CHARGE_SPEED := 15.0
const LEAP_TIME := 1.1
const LEAP_HEIGHT := 4.0
const STUN_TIME := 1.6
const STUN_DAMAGE_MULT := 1.5
const TRANSITION_DAMAGE_MULT := 0.2
const AIRBORNE_DAMAGE_MULT := 0.25
## Au-delà de cette distance, le boss se rapproche par une charge, un bond ou un saut de faille.
const FAR := 11.0

var enemies: DraftEnemies
var foe: DraftEnemies.Foe
var data: BossData
var phase: int = 0
var mechanics: Array[DraftBossMechanic] = []
## Lu par DraftEnemies : direction voulue, multiplicateur de vitesse, orientation libre.
var wish := Vector3.ZERO
var speed_mult: float = 1.0
var turns: bool = true
## Compteurs (essais, mesures).
var patterns_played: int = 0
var gestures_played: Dictionary = {}

var _clock: float = 0.0
var _ready_at: Dictionary = {}
var _next_at: float = 2.0
var _busy: float = 0.0
var _combo_left: int = 0
var _transition: float = 0.0
var _stunned: float = 0.0
var _mode: StringName = &"chase"
var _mode_left: float = 0.0
var _orbit: float = 1.0
var _closer_at: float = 4.0
var _hurt_window: float = 0.0
var _hurt_lost: float = 0.0
var _hurt_ready_at: float = 0.0
## Déplacement propre en cours : {} ou {"kind": &"charge"|&"leap", ...}.
var _move: Dictionary = {}
var _dead: bool = false


func setup(p_enemies: DraftEnemies, p_foe: DraftEnemies.Foe) -> void:
	enemies = p_enemies
	foe = p_foe
	data = foe.boss
	_orbit = 1.0 if enemies.rng.randf() < 0.5 else -1.0
	if not data.phases.is_empty():
		_apply_phase_stats()
	var intro: StringName = data.intro_animation if data.intro_animation != &"" else &"roar"
	if foe.view.has_clip(intro):
		_busy = minf(foe.view.clip_length(intro), 2.2)
		foe.view.play_action(intro, _busy)
		_next_at = _busy + 0.8


func phase_data() -> BossPhaseData:
	return data.phases[phase] if phase < data.phases.size() else null


## Le boss est-il en train de se déplacer seul (charge, bond) ? DraftEnemies ne le fait alors pas marcher.
func moves_itself() -> bool:
	return not _move.is_empty()


func busy() -> bool:
	return _busy > 0.0 or _transition > 0.0 or _stunned > 0.0 or moves_itself()


func stunned() -> bool:
	return _stunned > 0.0


func airborne() -> bool:
	return _move.get("kind", &"") == &"leap"


## Multiplicateur des coups reçus : transition et bond réduisent, étourdi augmente, mécaniques en plus.
func damage_mult() -> float:
	var mult: float = 1.0
	if _transition > 0.0:
		mult *= TRANSITION_DAMAGE_MULT
	if airborne():
		mult *= AIRBORNE_DAMAGE_MULT
	if _stunned > 0.0:
		mult *= STUN_DAMAGE_MULT
	for mechanic: DraftBossMechanic in mechanics:
		mult *= mechanic.damage_mult()
	return mult


func on_damage(amount: float) -> void:
	_hurt_lost += amount


## Étourdi (contre un mur, mécanique renvoyée) : ni déplacement ni attaque, coups × 1,5.
func stun(seconds: float) -> void:
	_stunned = maxf(_stunned, seconds)
	_move = {}
	foe.view.hop = 0.0
	foe.view.play_action(_first_clip([&"hurt", &"idle"]), seconds)
	foe.view.set_tint(Color(1.3, 1.3, 0.7))
	_fx(&"thunderclap", foe.pos + Vector3.UP * (foe.radius + 1.0), 1.4)


func add_mechanic(mechanic: DraftBossMechanic) -> void:
	mechanic.setup(self)
	mechanics.append(mechanic)


# --- Boucle --------------------------------------------------------------------------------------------------------

func step(to_hunter: Vector3, distance: float, climb: float, delta: float) -> void:
	_clock += delta
	wish = Vector3.ZERO
	speed_mult = 1.0
	turns = true
	for mechanic: DraftBossMechanic in mechanics:
		mechanic.step(delta)
	_check_phase()
	_check_hurt(delta)
	if _stunned > 0.0:
		_stunned -= delta
		turns = false
		if _stunned <= 0.0:
			foe.view.set_tint(Color.WHITE)
		return
	if _transition > 0.0:
		_transition -= delta
		turns = false
		return
	if not _move.is_empty():
		_step_move(delta)
		turns = false
		return
	for mechanic: DraftBossMechanic in mechanics:
		if mechanic.holds_boss():
			turns = false
			return
	if _busy > 0.0:
		_busy -= delta
		turns = false
		return
	var hunter: DraftHunter = enemies.hunter
	if hunter.alive and _clock >= _next_at:
		if distance > FAR and _clock >= _closer_at and _close_in(to_hunter, distance, climb):
			return
		var pattern: BossPatternData = _choose(distance, climb)
		if pattern != null:
			_perform(pattern, to_hunter, distance)
			return
	_walk(to_hunter, distance, climb, delta)


## Marche entre deux techniques : poursuite de loin, tournoiement à mi-distance, recul après un gros coup.
func _walk(to_hunter: Vector3, distance: float, climb: float, delta: float) -> void:
	var p: BossPhaseData = phase_data()
	var base: float = p.move_speed_mult if p != null else 1.0
	_mode_left -= delta
	if _mode_left <= 0.0:
		var roll: float = enemies.rng.randf()
		if distance > 8.0 or climb > 0.8:
			_mode = &"chase"
			_mode_left = 1.0
		elif roll < 0.55:
			_mode = &"circle"
			_mode_left = enemies.rng.randf_range(1.0, 2.2)
			if enemies.rng.randf() < 0.35:
				_orbit = -_orbit
		else:
			_mode = &"chase"
			_mode_left = enemies.rng.randf_range(0.8, 1.6)
	var aim: Vector3 = to_hunter / maxf(distance, 0.001)
	match _mode:
		&"back_off":
			wish = -aim
			speed_mult = base * 0.9
			turns = false
		&"circle":
			# Tourne autour du Chasseur en gardant 4 à 6 m ; un tour bloqué par le décor change de sens.
			var keep: float = clampf((distance - (foe.radius + 4.0)) * 0.5, -1.0, 1.0)
			wish = (Vector3(-aim.z, 0, aim.x) * _orbit + aim * keep).normalized()
			speed_mult = base * 0.85
			var ahead: Vector3 = foe.pos + wish * 1.2
			if enemies.level.closest(ahead).distance_to(ahead) > 0.6:
				_orbit = -_orbit
		_:
			if distance < foe.radius + 1.2 and climb < DraftEnemies.MELEE_REACH_UP:
				return
			wish = enemies.chase(foe, enemies.hunter.global_position, to_hunter, distance, climb, delta)
			speed_mult = base


# --- Phases --------------------------------------------------------------------------------------------------------

func _check_phase() -> void:
	var next: int = phase + 1
	if next >= data.phases.size() or foe.hp <= 0.0:
		return
	if foe.hp / foe.max_hp > data.phases[next].hp_threshold:
		return
	phase = next
	var p: BossPhaseData = phase_data()
	_apply_phase_stats()
	_move = {}
	foe.view.hop = 0.0
	_combo_left = 0
	_transition = maxf(p.transition_time, 1.0)
	_next_at = _clock + _transition + 0.6
	if p.visual_id != &"":
		foe.view.swap_visual(p.visual_id)
	var idle := StringName("phase%d_idle" % (phase + 1))
	if foe.view.has_clip(idle):
		foe.view.idle_clip = idle
	foe.view.play_action(_first_clip([p.transition_animation, &"transform", &"roar", &"attack"]), _transition)
	# Onde de transition : repousse le Chasseur qui colle le boss ; une Ruée la traverse.
	enemies.hazards.ring(foe.pos, 9.0, 14.0, _transition * 0.5, _damage(10.0), _fx_at(&"ring_burst", 2.5))
	_fx(&"ring_charge", foe.pos + Vector3.UP * 0.3, 2.4)
	Audio.play_sfx(&"boss_roar")
	for mechanic: DraftBossMechanic in mechanics:
		mechanic.on_phase(phase)
	enemies.run.call("boss_phase_changed", foe, phase)


func _apply_phase_stats() -> void:
	var p: BossPhaseData = phase_data()
	if p.defense_override >= 0.0:
		foe.defense = p.defense_override


## Réaction aux gros coups (part des PV perdue en une seconde, `hurt_ratio`), jamais au milieu d'une attaque.
func _check_hurt(delta: float) -> void:
	_hurt_window += delta
	if _hurt_window < 1.0:
		return
	var lost: float = _hurt_lost / foe.max_hp
	_hurt_window = 0.0
	_hurt_lost = 0.0
	if data.hurt_ratio > 0.0 and lost >= data.hurt_ratio and not busy() and _clock >= _hurt_ready_at \
			and foe.view.has_clip(&"hurt"):
		_hurt_ready_at = _clock + 6.0
		foe.view.play_action(&"hurt")
		_busy = 0.4


# --- Choix et techniques -------------------------------------------------------------------------------------------

func _choose(distance: float, climb: float) -> BossPatternData:
	var p: BossPhaseData = phase_data()
	if p == null:
		return null
	var options: Array[BossPatternData] = []
	var total: float = 0.0
	for pattern: BossPatternData in p.patterns:
		if _clock < float(_ready_at.get(pattern, 0.0)):
			continue
		var gesture: StringName = gesture_of(pattern)
		if MELEE.has(gesture) and (distance > foe.radius + (5.0 if gesture == &"slam" else 3.5) \
				or climb > DraftEnemies.MELEE_REACH_UP):
			continue
		options.append(pattern)
		total += pattern.weight
	if options.is_empty():
		return null
	var roll: float = enemies.rng.randf() * total
	for pattern: BossPatternData in options:
		roll -= pattern.weight
		if roll <= 0.0:
			return pattern
	return options.back()


static func gesture_of(pattern: BossPatternData) -> StringName:
	return GESTURES.get(pattern.kind, &"wave")


func _perform(pattern: BossPatternData, to_hunter: Vector3, distance: float) -> void:
	var p: BossPhaseData = phase_data()
	_ready_at[pattern] = _clock + pattern.cooldown
	patterns_played += 1
	var aim: Vector3 = to_hunter / maxf(distance, 0.001)
	foe.view.face_left(aim.x < 0.0)
	Audio.play_sfx(&"boss_telegraph")
	var handled: bool = false
	for mechanic: DraftBossMechanic in mechanics:
		if mechanic.handles(pattern.kind):
			_busy = mechanic.perform(pattern)
			handled = true
			break
	var gesture: StringName = gesture_of(pattern)
	if not handled:
		gestures_played[gesture] = int(gestures_played.get(gesture, 0)) + 1
		var clip: StringName = _pattern_clip(pattern, gesture)
		_busy = call("_gesture_" + String(gesture), pattern, aim)
		foe.view.play_action(clip, maxf(_busy, 0.5))
	# Enchaînements : plus fréquents et plus longs à chaque phase.
	if _combo_left > 0:
		_combo_left -= 1
	elif enemies.rng.randf() < minf(0.25 + 0.2 * phase, 0.7):
		_combo_left = 1 + mini(phase, 2)
	var interval: float = p.pattern_interval if p != null else 1.8
	_next_at = _clock + _busy + (0.3 if _combo_left > 0 else interval * enemies.boss_pace)
	if HEAVY.has(gesture) and _combo_left == 0:
		_mode = &"back_off"
		_mode_left = 0.7


## Rapprochement annoncé quand le Chasseur est loin : charge si la voie est libre, sinon bond ou saut de faille.
func _close_in(to_hunter: Vector3, distance: float, climb: float) -> bool:
	_closer_at = _clock + maxf(7.0 - phase * 1.5, 3.5)
	var aim: Vector3 = to_hunter / maxf(distance, 0.001)
	var probe := BossPatternData.new()
	probe.damage = data.damage
	probe.telegraph = 0.75
	var target: Vector3 = enemies.hunter.global_position
	if climb < 0.6 and bool(enemies.run.call("sight_clear", foe.pos + Vector3.UP * 0.8, target + Vector3.UP * 0.8)):
		probe.kind = &"charge"
		_busy = _gesture_charge(probe, aim)
	elif enemies.rng.randf() < 0.7:
		probe.kind = &"skyfall"
		_busy = _gesture_leap(probe, aim)
	else:
		probe.kind = &"blink"
		_busy = _gesture_blink(probe, aim)
	gestures_played[GESTURES[probe.kind]] = int(gestures_played.get(GESTURES[probe.kind], 0)) + 1
	_next_at = _clock + _busy + 0.5
	return true


func _gesture_claw(pattern: BossPatternData, aim: Vector3) -> float:
	var reach: float = clampf(float(pattern.params.get("radius", 120.0)) * UNIT, 1.6, 4.0)
	enemies.hazards.circle(foe.pos + aim * (foe.radius + reach * 0.7), foe.radius * 0.5 + reach, pattern.telegraph,
		_damage(pattern.damage), _fx_at(&"claw_swipe", reach))
	return pattern.telegraph + 0.35


func _gesture_sweep(pattern: BossPatternData, aim: Vector3) -> float:
	# Balayage en arc devant lui : trois zones de gauche à droite, à peine décalées.
	for i: int in 3:
		var direction: Vector3 = aim.rotated(Vector3.UP, deg_to_rad(-45.0 + 45.0 * i))
		enemies.hazards.circle(foe.pos + direction * (foe.radius + 1.8), 1.9, pattern.telegraph + 0.1 * i,
			_damage(pattern.damage), _fx_at(&"claw_swipe", 1.8))
	return pattern.telegraph + 0.5


func _gesture_slam(pattern: BossPatternData, _aim: Vector3) -> float:
	var reach: float = foe.radius + clampf(float(pattern.params.get("radius", 90.0)) * UNIT, 2.0, 4.0)
	enemies.hazards.circle(foe.pos, reach, pattern.telegraph, _damage(pattern.damage), _fx_at(&"quake", reach))
	if phase >= 1:
		# Double écrasement : une seconde frappe plus large, juste après.
		enemies.hazards.circle(foe.pos, reach + 2.5, pattern.telegraph + 0.55, _damage(pattern.damage * 0.8),
			_fx_at(&"dirt_explosion", reach + 2.0))
	return pattern.telegraph + (1.0 if phase >= 1 else 0.6)


func _gesture_wave(pattern: BossPatternData, _aim: Vector3) -> float:
	_fx(&"ring_charge", foe.pos + Vector3.UP * 0.3, 2.0)
	var waves: int = maxi(int(pattern.params.get("waves", 1)), 1 + mini(phase, 1))
	for i: int in waves:
		enemies.hazards.ring(foe.pos, 8.5, 22.0, pattern.telegraph + 0.9 * i, _damage(pattern.damage),
			_fx_at(&"ring_burst", 2.5) if i == 0 else Callable())
	return pattern.telegraph + 0.6


func _gesture_quake(pattern: BossPatternData, _aim: Vector3) -> float:
	# Séisme : trois anneaux serrés, à franchir d'une Ruée ou derrière un abri.
	for i: int in 3:
		enemies.hazards.ring(foe.pos, 7.0, 16.0, pattern.telegraph + 0.7 * i, _damage(pattern.damage * 0.8),
			_fx_at(&"quake", 2.2) if i == 0 else Callable())
	return pattern.telegraph + 1.2


func _gesture_rain(pattern: BossPatternData, _aim: Vector3) -> float:
	var count: int = 3 + 2 * mini(phase, 2)
	var center: Vector3 = enemies.hunter.global_position
	var effect: StringName = DraftPixelFx.RAIN.get(family(), &"dark_explosion")
	for n: int in count:
		var offset := Vector3.ZERO if n == 0 else Vector3(enemies.rng.randf_range(-4.5, 4.5), 0,
			enemies.rng.randf_range(-4.5, 4.5))
		enemies.hazards.circle(enemies.level.closest(center + offset), 1.9, pattern.telegraph + 0.12 * n,
			_damage(pattern.damage), _fx_at(effect, 1.5))
	return pattern.telegraph * 0.6 + 0.3


func _gesture_summon(pattern: BossPatternData, _aim: Vector3) -> float:
	var amount: int = clampi(int(pattern.params.get("count", 4)), 2, 6) + mini(phase, 2)
	var worlds: Array = pattern.params.get("worlds", [])
	if worlds.is_empty():
		enemies.run.call("boss_summon", foe, amount)
	else:
		# Échos des mondes (Abyssarque) : monstres d'un chapitre après l'autre.
		var world: Array = worlds[patterns_played % worlds.size()]
		var ids: Array[StringName] = []
		for id: Variant in world:
			ids.append(StringName(str(id)))
		enemies.run.call("boss_summon_ids", foe, ids, amount)
	return 1.0


func _gesture_beam(pattern: BossPatternData, aim: Vector3) -> float:
	enemies.hazards.line(foe.pos, aim, 24.0, 2.2, pattern.telegraph + 0.3, _damage(pattern.damage))
	return pattern.telegraph + 0.7


func _gesture_sweep_beam(pattern: BossPatternData, aim: Vector3) -> float:
	# Rayon qui balaie : cinq traits annoncés l'un après l'autre, d'un côté à l'autre.
	var side: float = 1.0 if enemies.rng.randf() < 0.5 else -1.0
	for i: int in 5:
		var direction: Vector3 = aim.rotated(Vector3.UP, side * deg_to_rad(-50.0 + 25.0 * i))
		enemies.hazards.line(foe.pos, direction, 22.0, 1.8, pattern.telegraph + 0.18 * i, _damage(pattern.damage * 0.8))
	return pattern.telegraph + 1.1


func _gesture_breath(pattern: BossPatternData, aim: Vector3) -> float:
	for i: int in 3:
		var direction: Vector3 = aim.rotated(Vector3.UP, deg_to_rad(-22.0 + 22.0 * i))
		enemies.hazards.line(foe.pos, direction, 12.0, 2.4, pattern.telegraph + 0.05 * i, _damage(pattern.damage))
	_fx(&"fire_breath", foe.pos + aim * (foe.radius + 2.0) + Vector3.UP, 2.0)
	return pattern.telegraph + 0.6


func _gesture_spikes(pattern: BossPatternData, aim: Vector3) -> float:
	# Ligne de pics qui court vers le Chasseur, zone après zone.
	var effect: StringName = &"ice_spikes" if family() in [&"givres", &"silence"] else &"earth_spike"
	for i: int in 8:
		var at: Vector3 = foe.pos + aim * (foe.radius + 1.0 + 1.7 * i)
		enemies.hazards.circle(enemies.level.closest(at), 1.15, pattern.telegraph + 0.08 * i, _damage(pattern.damage),
			_fx_at(effect, 1.1))
	return pattern.telegraph + 0.4


func _gesture_burst(pattern: BossPatternData, _aim: Vector3) -> float:
	# Sol qui éclate autour de lui : une couronne, puis une seconde plus loin à partir de la phase 2.
	var rings: int = 1 + mini(phase, 1)
	for r: int in rings:
		var count: int = 8 + 4 * r
		var spin: float = enemies.rng.randf() * TAU
		for k: int in count:
			var direction := Vector3.RIGHT.rotated(Vector3.UP, spin + TAU * k / count)
			var at: Vector3 = foe.pos + direction * (foe.radius + 3.0 + 3.5 * r)
			enemies.hazards.circle(enemies.level.closest(at), 1.6, pattern.telegraph + 0.45 * r,
				_damage(pattern.damage), _fx_at(&"ice_shatter_small", 1.2))
	return pattern.telegraph + 0.5 * rings


func _gesture_charge(pattern: BossPatternData, aim: Vector3) -> float:
	var length: float = clampf(foe.pos.distance_to(enemies.hunter.global_position) + 6.0, 10.0, 22.0)
	enemies.hazards.line(foe.pos, aim, length, foe.radius * 2.0 + 0.6, pattern.telegraph, 0.0)
	foe.view.set_tint(Color(1.5, 1.05, 0.7))
	_move = {"kind": &"charge", "dir": aim, "wait": pattern.telegraph, "left": length / CHARGE_SPEED,
		"damage": _damage(pattern.damage), "hit": false}
	return 0.0


func _gesture_leap(pattern: BossPatternData, _aim: Vector3) -> float:
	var land: Vector3 = enemies.level.closest(enemies.hunter.global_position)
	var reach: float = foe.radius + 2.2
	enemies.hazards.circle(land, reach, pattern.telegraph + LEAP_TIME, _damage(pattern.damage),
		_fx_at(&"quake", reach))
	_move = {"kind": &"leap", "from": foe.pos, "to": land, "wait": pattern.telegraph, "t": 0.0}
	return 0.0


func _gesture_blink(pattern: BossPatternData, aim: Vector3) -> float:
	# Saut de faille : disparaît, réapparaît sur un flanc du Chasseur et frappe aussitôt.
	_fx(&"blink_out", foe.pos + Vector3.UP * 0.8, 1.6)
	var side: Vector3 = Vector3(-aim.z, 0, aim.x) * (1.0 if enemies.rng.randf() < 0.5 else -1.0)
	var at: Vector3 = enemies.level.closest(enemies.hunter.global_position + side * (foe.radius + 2.6))
	foe.pos = at
	foe.vel = Vector3.ZERO
	foe.path = PackedVector3Array()
	foe.view.snap_to(at)
	_fx(&"blink_in", at + Vector3.UP * 0.8, 1.6)
	var to_hunter: Vector3 = enemies.hunter.global_position - at
	to_hunter.y = 0.0
	var claw := BossPatternData.new()
	claw.damage = pattern.damage
	claw.telegraph = maxf(pattern.telegraph * 0.8, 0.55)
	return _gesture_claw(claw, to_hunter.normalized() if to_hunter.length() > 0.01 else aim) + 0.2


# --- Déplacements propres (charge, bond) ---------------------------------------------------------------------------

func _step_move(delta: float) -> void:
	_move["wait"] = float(_move["wait"]) - delta
	if float(_move["wait"]) > 0.0:
		return
	if _move["kind"] == &"charge":
		_step_charge(delta)
	else:
		_step_leap(delta)


func _step_charge(delta: float) -> void:
	var direction: Vector3 = _move["dir"]
	var next: Vector3 = foe.pos + direction * CHARGE_SPEED * delta
	var landed: Vector3 = enemies.level.closest(next + Vector3.UP * 0.2)
	foe.vel = direction * CHARGE_SPEED
	# Contre le décor ou un mur de faille : il s'assomme (coups × 1,5) ; se placer devant un obstacle paie.
	# Avance réelle sur la navigation : moins de la moitié du pas voulu, c'est le décor qui l'arrête.
	var progress: float = (landed - foe.pos).dot(direction)
	if progress < CHARGE_SPEED * delta * 0.5 or bool(enemies.run.call("barrier_blocks", foe.pos, next)):
		_move = {}
		foe.vel = Vector3.ZERO
		foe.view.set_tint(Color.WHITE)
		_fx(&"dirt_explosion", foe.pos + direction * foe.radius + Vector3.UP * 0.6, 1.8)
		stun(STUN_TIME)
		return
	foe.pos = landed
	var hunter: DraftHunter = enemies.hunter
	var offset: Vector3 = hunter.global_position - foe.pos
	if not bool(_move["hit"]) and Vector2(offset.x, offset.z).length() < foe.radius + DraftHunter.RADIUS + 0.4 \
			and absf(offset.y) < DraftEnemies.MELEE_REACH_UP and hunter.alive:
		_move["hit"] = true
		if hunter.take_damage(float(_move["damage"])) > 0.0:
			enemies.run.call("on_hunter_hit", foe)
	_move["left"] = float(_move["left"]) - delta
	if float(_move["left"]) <= 0.0:
		_move = {}
		foe.vel = Vector3.ZERO
		foe.view.set_tint(Color.WHITE)
		_busy = 0.45


func _step_leap(delta: float) -> void:
	_move["t"] = float(_move["t"]) + delta / LEAP_TIME
	var t: float = minf(float(_move["t"]), 1.0)
	var from: Vector3 = _move["from"]
	var to: Vector3 = _move["to"]
	foe.pos = from.lerp(to, t)
	foe.vel = Vector3.ZERO
	foe.view.hop = sin(t * PI) * LEAP_HEIGHT
	if t >= 1.0:
		foe.view.hop = 0.0
		foe.pos = enemies.level.closest(to + Vector3.UP * 0.2)
		_move = {}
		_busy = 0.6
		_mode = &"back_off"
		_mode_left = 0.5


# --- Mort ----------------------------------------------------------------------------------------------------------

## Mort : mécaniques retirées, feuille de mort dédiée s'il y en a une, clip joué en entier. Renvoie sa durée.
func die() -> float:
	if _dead:
		return 0.0
	_dead = true
	_move = {}
	foe.view.hop = 0.0
	foe.view.set_tint(Color.WHITE)
	for mechanic: DraftBossMechanic in mechanics:
		mechanic.finish()
	if data.death_visual_id != &"":
		foe.view.swap_visual(data.death_visual_id)
	var clip: StringName = _first_clip([&"collapse", &"death"])
	var length: float = clampf(foe.view.clip_length(clip), 0.6, 3.0)
	foe.view.play_action(clip, length)
	_fx(&"death", foe.pos + Vector3.UP * 0.8, clampf(foe.radius * 2.6, 1.5, 4.0))
	return length


# --- Outils --------------------------------------------------------------------------------------------------------

func family() -> StringName:
	return DraftPixelFx.boss_family(data)


func _damage(amount: float) -> float:
	return amount * enemies.boss_damage_mult


func _pattern_clip(pattern: BossPatternData, gesture: StringName) -> StringName:
	var candidates: Array[StringName] = []
	if pattern.params.has("anim"):
		candidates.append(StringName(str(pattern.params["anim"])))
	candidates.append(BossController.PATTERN_ANIMATIONS.get(pattern.kind, &"attack"))
	for id: StringName in GESTURE_CLIPS.get(gesture, []):
		candidates.append(id)
	return _first_clip(candidates)


func _first_clip(candidates: Array[StringName]) -> StringName:
	for id: StringName in candidates:
		if foe.view.has_clip(id):
			return id
	return &"attack"


## Effet PixelFX dans la palette du boss ; à défaut, le même effet dans la palette commune.
func _fx(effect: StringName, at: Vector3, size: float) -> void:
	var tint: StringName = family()
	if DraftPixelFx.sheet(effect, tint).is_empty():
		tint = DraftPixelFx.DEFAULT_FAMILY
	enemies.run.call("fx", effect, tint, at, size)


func _fx_at(effect: StringName, size: float) -> Callable:
	return func(at: Vector3) -> void: _fx(effect, at + Vector3.UP * 0.6, size)
