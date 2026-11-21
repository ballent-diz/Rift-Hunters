class_name DraftFairon
extends DraftBossMechanic
## Faïron, Dévoreur des Émaux (chapitre 9, docs/art/VERNISSES_FAIRON.md) : « Choc d'émail ». Il glace des bandes de
## sol en travers de l'arène, une par une, puis elles se fendent dans l'ordre où elles ont été marquées : la bande qui
## vient de se fendre est sûre, la suivante pas encore. Lire l'ordre donne la fenêtre pour traverser.
## - Coque de porcelaine (phase 1) : bandes marquées de la plus proche du boss à la plus lointaine.
## - Four ouvert (phase 2) : une bande de plus, ordre mêlé, fissures plus rapprochées ; matière du four (`calcines`).
## - Pose d'émail : une traînée glacée vers le Chasseur, qui ralentit quelques secondes.
## Aucun texte ne l'explique : l'ordre se lit à l'apparition des bandes.

const GLAZE := Color(0.25, 0.42, 0.85)
## Au-delà de cette distance (m), il ne lance pas le choc : il se rapproche d'abord.
const REACH := 18.0

## Chocs et poses joués, bandes fendues (essais).
var shocks: int = 0
var lines: int = 0
var cracked: int = 0
## Bandes en cours : {"mark_at", "crack_at", "center", "dir", "marked", "done"}, dans l'ordre de marquage.
var bands: Array[Dictionary] = []
## Traînées d'émail à poser : {"at", "pos", "radius", "time", "damage", "slow"}.
var _glaze: Array[Dictionary] = []
var _clock: float = 0.0
var _hold_until: float = -1.0
var _band_length: float = 16.0
var _band_width: float = 2.2
var _damage: float = 0.0


func handles(kind: StringName) -> bool:
	return kind == &"enamel_shock" or kind == &"enamel_line"


func allows(kind: StringName, distance: float) -> bool:
	return kind != &"enamel_shock" or distance <= REACH


func next_kind(last: StringName) -> StringName:
	match last:
		&"enamel_line":
			return &"enamel_shock"
		&"enamel_shock":
			return &"kiln_spit" if brain.phase >= 1 else &"sweep"
	return &""


func holds_boss() -> bool:
	return _hold_until >= 0.0 and _clock < _hold_until


func perform(pattern: BossPatternData) -> float:
	if pattern.kind == &"enamel_line":
		return _line(pattern)
	return _shock(pattern)


func _shock(pattern: BossPatternData) -> float:
	shocks += 1
	bands.clear()
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var hunter: Vector3 = brain.enemies.hunter.global_position
	var axis: Vector3 = hunter - foe.pos
	axis.y = 0.0
	axis = axis.normalized() if axis.length() > 0.01 else Vector3.RIGHT
	var side := Vector3(-axis.z, 0, axis.x)
	var count: int = int(params.get("count", 4)) + (1 if brain.phase >= 1 else 0)
	var spacing: float = float(params.get("spacing", 90.0)) * DraftHunter.UNIT
	var mark_gap: float = float(params.get("mark_gap", 0.45))
	var pause: float = float(params.get("pause", 0.6))
	var crack_gap: float = float(params.get("crack_gap", 0.55)) * (0.8 if brain.phase >= 1 else 1.0)
	_band_length = float(params.get("length", 540.0)) * DraftHunter.UNIT
	_band_width = float(params.get("width", 72.0)) * DraftHunter.UNIT
	_damage = brain.damage(pattern.damage)
	var order: Array[int] = []
	for i: int in count:
		order.append(i)
	if brain.phase >= 1:
		# Four ouvert : ordre mêlé, à lire à l'apparition des bandes.
		for i: int in range(count - 1, 0, -1):
			var j: int = brain.enemies.rng.randi() % (i + 1)
			var swap: int = order[i]
			order[i] = order[j]
			order[j] = swap
	var start: float = _clock + pattern.telegraph * 0.5
	var first_crack: float = start + mark_gap * (count - 1) + pause + pattern.telegraph * 0.5
	for n: int in count:
		var offset: float = (order[n] - (count - 1) * 0.5) * spacing
		bands.append({"mark_at": start + mark_gap * n, "crack_at": first_crack + crack_gap * n,
			"center": brain.enemies.level.closest(hunter + axis * offset), "dir": side, "marked": false,
			"done": false})
	_hold_until = start + mark_gap * (count - 1) + 0.3
	brain.play_clip([StringName(str(params.get("anim", "enamel_shock"))), &"enamel_line", &"attack"],
		_hold_until - _clock)
	return _hold_until - _clock + 0.2


## Pose d'émail : traînée glacée du boss vers le Chasseur ; elle ralentit et blesse peu tant qu'on s'y tient.
func _line(pattern: BossPatternData) -> float:
	lines += 1
	var params: Dictionary = pattern.params
	var foe: DraftEnemies.Foe = brain.foe
	var aim: Vector3 = brain.enemies.hunter.global_position - foe.pos
	aim.y = 0.0
	var length: float = clampf(aim.length() + 3.0, 6.0, float(params.get("length", 420.0)) * DraftHunter.UNIT)
	aim = aim.normalized() if aim.length() > 0.01 else Vector3.RIGHT
	var radius: float = float(params.get("radius", 42.0)) * DraftHunter.UNIT
	brain.enemies.hazards.line(foe.pos, aim, length, radius * 2.0, pattern.telegraph, 0.0)
	var count: int = maxi(int(length / (radius * 1.7)), 2)
	for k: int in count:
		_glaze.append({"at": _clock + pattern.telegraph + 0.05 * k,
			"pos": brain.enemies.level.closest(foe.pos + aim * (foe.radius + radius * 1.7 * k)), "radius": radius,
			"time": float(params.get("duration", 6.0)), "damage": brain.damage(pattern.damage),
			"slow": float(params.get("slow", 0.55))})
	brain.play_clip([StringName(str(params.get("anim", "enamel_line"))), &"attack"], pattern.telegraph + 0.3)
	return pattern.telegraph + 0.4


func step(delta: float) -> void:
	_clock += delta
	var hazards: DraftHazards = brain.enemies.hazards
	var previous: StringName = hazards.family
	hazards.family = brain.combat_family()
	for i: int in range(_glaze.size() - 1, -1, -1):
		var glaze: Dictionary = _glaze[i]
		if _clock >= float(glaze["at"]):
			hazards.zone(glaze["pos"], glaze["radius"], glaze["time"], glaze["damage"], glaze["slow"], GLAZE)
			_glaze.remove_at(i)
	for band: Dictionary in bands:
		if not bool(band["marked"]) and _clock >= float(band["mark_at"]):
			band["marked"] = true
			var center: Vector3 = band["center"]
			var direction: Vector3 = band["dir"]
			hazards.line(center - direction * _band_length * 0.5, direction, _band_length, _band_width,
				float(band["crack_at"]) - _clock, _damage)
			brain.fx(&"ring_charge", center + Vector3.UP * 0.2, 1.2)
		if bool(band["marked"]) and not bool(band["done"]) and _clock >= float(band["crack_at"]):
			band["done"] = true
			cracked += 1
			brain.fx(&"ring_burst", (band["center"] as Vector3) + Vector3.UP * 0.4, 1.6)
	hazards.family = previous
	if not bands.is_empty() and bands.all(func(band: Dictionary) -> bool: return bool(band["done"])):
		bands.clear()


func finish() -> void:
	bands.clear()
	_glaze.clear()
	_hold_until = -1.0
