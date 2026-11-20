class_name DraftFoeTechniques
extends RefCounted
## Techniques des Corrompus de la v2 (docs/design/TECHNIQUES_ENNEMIS_V2.md) : elles sont lues dans les fiches des
## monstres (`EnemyData.techniques`, `EnemyTechniqueData` : recharge, portée en unités v1, annonce, dégâts, `params`)
## et jouées par `DraftEnemies`. Chaque technique s'annonce au sol (DraftHazards), joue sa rangée de feuille (`anim`),
## puis laisse une fenêtre de récupération où le monstre ne fait rien. Seules les techniques connues ici sont jouées :
## les fiches des familles plus anciennes gardent leur comportement simple.
## Règles communes : une technique à la fois, un délai entre deux techniques d'un même monstre, aucune à travers un
## mur ni sur un autre niveau, aucun contrôle permanent (ralentissements courts, jamais d'immobilisation).

const UNIT := DraftHunter.UNIT
## Délai minimal entre deux techniques d'un même monstre (s), et délai avant la première.
const SPACING := 1.6
const FIRST_DELAY := Vector2(1.5, 3.5)
## Hauteur au-delà de laquelle un monstre ne lance rien (le Chasseur est sur un autre niveau).
const MAX_CLIMB := 1.0

const KINDS: Array[StringName] = [&"brine_jet", &"lock_guard", &"mallet_slam", &"bell_call", &"brine_blessing",
	&"scoop_charge", &"salt_crust_burst"]

var enemies: DraftEnemies
## Déclenchements par technique (essais, mesures).
var played: Dictionary = {}
var _clock: float = 0.0
## Actions différées {at, call}.
var _later: Array[Dictionary] = []


func _init(p_enemies: DraftEnemies) -> void:
	enemies = p_enemies


static func has_any(data: EnemyData) -> bool:
	for technique: EnemyTechniqueData in data.techniques:
		if KINDS.has(technique.kind):
			return true
	return false


## Horloge commune et actions différées (une fois par image).
func tick(delta: float) -> void:
	_clock += delta
	for i: int in range(_later.size() - 1, -1, -1):
		if _clock >= float(_later[i]["at"]):
			var call: Callable = _later[i]["call"]
			_later.remove_at(i)
			if call.is_valid():
				call.call()


func clear() -> void:
	_later.clear()


## Pas d'un monstre à techniques : vrai tant qu'il est occupé (le cerveau de poursuite ne joue pas).
func step(foe: DraftEnemies.Foe, to_hunter: Vector3, distance: float, climb: float, delta: float) -> bool:
	foe.guard_left = maxf(foe.guard_left - delta, 0.0)
	foe.ward_left = maxf(foe.ward_left - delta, 0.0)
	if foe.guard_left <= 0.0 and foe.ward_left <= 0.0 and foe.tinted:
		foe.tinted = false
		foe.view.set_tint(Color.WHITE)
	if not foe.charge.is_empty():
		_step_charge(foe, delta)
		return true
	if foe.tech_busy > 0.0:
		foe.tech_busy -= delta
		return true
	if foe.tech_ready.is_empty():
		for technique: EnemyTechniqueData in foe.data.techniques:
			foe.tech_ready[technique.kind] = _clock + enemies.rng.randf_range(FIRST_DELAY.x, FIRST_DELAY.y)
	if climb > MAX_CLIMB or not enemies.hunter.alive:
		return false
	for technique: EnemyTechniqueData in foe.data.techniques:
		if not KINDS.has(technique.kind) or _clock < float(foe.tech_ready.get(technique.kind, 0.0)):
			continue
		if distance < technique.min_range * UNIT or distance > technique.max_range * UNIT:
			continue
		if not _usable(foe, technique) or not _sight(foe):
			continue
		var busy: float = _perform(foe, technique, to_hunter.normalized() if distance > 0.01 else Vector3.FORWARD)
		foe.tech_ready[technique.kind] = _clock + technique.cooldown
		for other: Variant in foe.tech_ready:
			foe.tech_ready[other] = maxf(float(foe.tech_ready[other]), _clock + busy + SPACING)
		foe.tech_busy = busy
		foe.vel = Vector3.ZERO
		played[technique.kind] = int(played.get(technique.kind, 0)) + 1
		return true
	return false


## Multiplicateur des coups reçus (Garde de vanne : de face / de dos ; Bénédiction saumâtre).
func damage_taken_mult(foe: DraftEnemies.Foe) -> float:
	var mult: float = 1.0
	if foe.guard_left > 0.0:
		var from: Vector3 = enemies.hunter.global_position - foe.pos
		from.y = 0.0
		var front: bool = from.length() < 0.05 or from.normalized().dot(foe.guard_dir) >= cos(deg_to_rad(foe.guard_arc))
		mult *= foe.guard_front if front else foe.guard_back
	if foe.ward_left > 0.0:
		mult *= foe.ward_mult
	return mult


func _usable(foe: DraftEnemies.Foe, technique: EnemyTechniqueData) -> bool:
	if technique.kind == &"brine_blessing":
		return not _allies(foe, technique).is_empty()
	return true


func _sight(foe: DraftEnemies.Foe) -> bool:
	return bool(enemies.run.call("sight_clear", foe.pos + Vector3.UP * 0.6, enemies.hunter.chest()))


func _perform(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, dir: Vector3) -> float:
	var previous: StringName = enemies.hazards.family
	enemies.hazards.family = DraftPixelFx.enemy_family(foe.data)
	var busy: float = 0.0
	match technique.kind:
		&"brine_jet":
			busy = _brine_jet(foe, technique, dir)
		&"lock_guard":
			busy = _lock_guard(foe, technique, dir)
		&"mallet_slam":
			busy = _mallet_slam(foe, technique, dir)
		&"bell_call":
			busy = _bell_call(foe, technique)
		&"brine_blessing":
			busy = _brine_blessing(foe, technique)
		&"scoop_charge":
			busy = _scoop_charge(foe, technique, dir)
		&"salt_crust_burst":
			busy = _salt_crust_burst(foe, technique, dir)
	enemies.hazards.family = previous
	return busy


func _p(technique: EnemyTechniqueData, key: String, fallback: float) -> float:
	return float(technique.params.get(key, fallback))


func _damage(technique: EnemyTechniqueData) -> float:
	return technique.damage * enemies.damage_mult


func _clip(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, duration: float) -> void:
	var clip: StringName = technique.anim if foe.view.has_clip(technique.anim) else &"attack"
	foe.view.play_action(clip, duration)


## Effet de technique : la feuille dédiée `tech_<id>` dès qu'elle est livrée (assets/vfx/pixelfx/tech_<id>/,
## largeur `width` m), sinon l'effet PixelFX existant `fallback` (docs/design/TECHNIQUES_ENNEMIS_V2.md, § FX).
func vfx(id: StringName, width: float, fallback: StringName, family: StringName, at: Vector3, size: float) -> void:
	enemies.run.call("fx_or", StringName("tech_" + String(id)), width, fallback, family, at, size)


## Même effet joué au moment de la frappe (rappel des annonces au sol).
func _fx(id: StringName, width: float, fallback: StringName, foe: DraftEnemies.Foe, size: float) -> Callable:
	var family: StringName = DraftPixelFx.enemy_family(foe.data)
	return func(at: Vector3) -> void: vfx(id, width, fallback, family, at + Vector3.UP * 0.4, size)


func _later_call(delay: float, call: Callable) -> void:
	_later.append({"at": _clock + delay, "call": call})


# --- Saumâtres --------------------------------------------------------------------------------------------------

## Jet de saumure (Siphon de sel) : jet chargé en ligne droite, puis flaque qui ralentit au bout du jet.
func _brine_jet(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, dir: Vector3) -> float:
	var length: float = _p(technique, "length", 9.0)
	var from: Vector3 = foe.pos
	enemies.hazards.line(from, dir, length, _p(technique, "width", 0.9), technique.telegraph, _damage(technique), true)
	var reach: float = minf(DraftSpells._flat(enemies.hunter.global_position - from).length(), length)
	var pool: Vector3 = enemies.level.closest(from + dir * reach)
	var radius: float = _p(technique, "pool_radius", 1.6)
	var duration: float = _p(technique, "pool_time", 3.0)
	var slow: float = _p(technique, "pool_slow", 0.6)
	var hazards: DraftHazards = enemies.hazards
	_later_call(technique.telegraph, func() -> void:
		hazards.zone(pool, radius, duration, 0.0, slow, Color(0.55, 0.8, 0.86))
		vfx(&"brine_jet_pool", radius * 2.0, &"splash", &"enlises", pool + Vector3.UP * 0.3, radius * 0.8))
	_clip(foe, technique, technique.telegraph + 0.2)
	return technique.telegraph + _p(technique, "recover", 0.6)


## Garde de vanne (Gardien de l'écluse) : la vanne levée couvre l'avant ; le dos reste vulnérable. Le gardien tient
## sa position pendant la garde : on le contourne.
func _lock_guard(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, dir: Vector3) -> float:
	var duration: float = _p(technique, "duration", 2.6)
	foe.guard_dir = dir
	foe.guard_left = technique.telegraph + duration
	foe.guard_front = _p(technique, "front_mult", 0.25)
	foe.guard_back = _p(technique, "back_mult", 1.5)
	foe.guard_arc = _p(technique, "arc", 70.0)
	foe.tinted = true
	foe.view.set_tint(Color(0.8, 0.95, 1.25))
	vfx(&"lock_guard", 1.6, &"shield_block", DraftPixelFx.enemy_family(foe.data), foe.pos + dir * 0.6 + Vector3.UP * 0.7, 1.0)
	_clip(foe, technique, technique.telegraph + duration)
	return technique.telegraph + duration


## Frappe du maillet : cône devant le gardien (disque décalé), dégâts et recul.
func _mallet_slam(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, dir: Vector3) -> float:
	var at: Vector3 = enemies.level.closest(foe.pos + dir * _p(technique, "reach", 2.6))
	var radius: float = _p(technique, "radius", 1.9)
	var push: float = _p(technique, "knockback", 7.0)
	var hunter: DraftHunter = enemies.hunter
	enemies.hazards.circle(at, radius, technique.telegraph, _damage(technique),
		_fx(&"mallet_slam", radius * 2.0, &"quake", foe, radius),
		func() -> void: hunter.velocity += dir * push)
	_clip(foe, technique, technique.telegraph + 0.3)
	return technique.telegraph + _p(technique, "recover", 0.8)


## Appel des cloches (Chantre de saumure) : deux ondes successives, arrêtées par le décor ; une Ruée les traverse.
func _bell_call(foe: DraftEnemies.Foe, technique: EnemyTechniqueData) -> float:
	var gap: float = _p(technique, "gap", 0.8)
	var speed: float = _p(technique, "speed", 7.0)
	var reach: float = _p(technique, "reach", 9.0)
	for wave: int in 2:
		enemies.hazards.ring(foe.pos, speed, reach, technique.telegraph + gap * wave, _damage(technique),
			_fx(&"bell_call", 2.4, &"thunderclap", foe, 1.2))
	_clip(foe, technique, technique.telegraph + gap)
	return technique.telegraph + gap + _p(technique, "recover", 0.6)


## Bénédiction saumâtre : trois alliés au plus (les plus proches) encaissent moins pendant quelques secondes.
func _brine_blessing(foe: DraftEnemies.Foe, technique: EnemyTechniqueData) -> float:
	var duration: float = technique.telegraph + _p(technique, "duration", 4.0)
	for ally: DraftEnemies.Foe in _allies(foe, technique):
		ally.ward_left = duration
		ally.ward_mult = _p(technique, "mult", 0.5)
		ally.tinted = true
		ally.view.set_tint(Color(0.75, 1.1, 1.2))
		vfx(&"brine_blessing", 1.4, &"healing_bloom", &"enlises", ally.pos + Vector3.UP * 0.6, 1.0)
	_clip(foe, technique, technique.telegraph + 0.3)
	return technique.telegraph + 0.3


func _allies(foe: DraftEnemies.Foe, technique: EnemyTechniqueData) -> Array[DraftEnemies.Foe]:
	var found: Array[DraftEnemies.Foe] = []
	for other: DraftEnemies.Foe in enemies.near(foe.pos, _p(technique, "radius", 7.0)):
		if other != foe and other.alive and other.boss == null and other.ward_left <= 0.0:
			found.append(other)
	found.sort_custom(func(a: DraftEnemies.Foe, b: DraftEnemies.Foe) -> bool:
		return a.pos.distance_squared_to(foe.pos) < b.pos.distance_squared_to(foe.pos))
	return found.slice(0, int(_p(technique, "targets", 3.0)))


## Charge au godet (Dragueur de sel) : couloir annoncé, course droite qui blesse une fois, puis récupération.
func _scoop_charge(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, dir: Vector3) -> float:
	var length: float = _p(technique, "length", 9.0)
	var width: float = _p(technique, "width", 1.6)
	enemies.hazards.line(foe.pos, dir, length, width, technique.telegraph, 0.0)
	foe.charge = {"dir": dir, "wait": technique.telegraph, "left": length / maxf(_p(technique, "speed", 13.0), 1.0),
		"speed": _p(technique, "speed", 13.0), "width": width, "damage": _damage(technique), "hit": false,
		"recover": _p(technique, "recover", 1.3)}
	_clip(foe, technique, technique.telegraph + float(foe.charge["left"]))
	return 0.0


func _step_charge(foe: DraftEnemies.Foe, delta: float) -> void:
	var charge: Dictionary = foe.charge
	if float(charge["wait"]) > 0.0:
		charge["wait"] = float(charge["wait"]) - delta
		return
	var dir: Vector3 = charge["dir"]
	var next: Vector3 = enemies.level.closest(foe.pos + dir * float(charge["speed"]) * delta + Vector3.UP * 0.2)
	# Bloqué par le décor : la charge s'arrête net.
	var moved: float = DraftSpells._flat(next - foe.pos).length()
	foe.pos = next
	charge["left"] = float(charge["left"]) - delta
	var hunter: DraftHunter = enemies.hunter
	var offset: Vector3 = DraftSpells._flat(hunter.global_position - foe.pos)
	if not charge["hit"] and offset.length() < float(charge["width"]) * 0.5 + foe.radius \
			and absf(hunter.global_position.y - foe.pos.y) < DraftEnemies.MELEE_REACH_UP:
		charge["hit"] = true
		hunter.take_damage(float(charge["damage"]))
		hunter.velocity += dir * 6.0
	if float(charge["left"]) <= 0.0 or moved < float(charge["speed"]) * delta * 0.3:
		foe.tech_busy = float(charge["recover"])
		foe.charge = {}
		vfx(&"scoop_charge_impact", 2.0, &"dirt_explosion", DraftPixelFx.enemy_family(foe.data), foe.pos + Vector3.UP * 0.3,
			1.0)


## Éclatement salin : six éclats en étoile autour du dragueur (couloirs annoncés, passages entre eux).
func _salt_crust_burst(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, dir: Vector3) -> float:
	var count: int = int(_p(technique, "count", 6.0))
	var length: float = _p(technique, "length", 6.0)
	var width: float = _p(technique, "width", 0.7)
	# Le premier éclat part à côté du Chasseur : il reste un passage entre deux éclats.
	var start: Vector3 = dir.rotated(Vector3.UP, PI / count)
	for i: int in count:
		var lane: Vector3 = start.rotated(Vector3.UP, TAU * i / count)
		enemies.hazards.line(foe.pos, lane, length, width, technique.telegraph, _damage(technique), true)
	vfx(&"salt_crust_burst", 3.0, &"ice_shatter_small", &"reflets", foe.pos + Vector3.UP * 0.6, 1.4)
	_clip(foe, technique, technique.telegraph + 0.3)
	return technique.telegraph + _p(technique, "recover", 0.7)
