class_name DraftFoeTechniques
extends RefCounted
## Techniques des Corrompus dans la base 3D (normaux à technique et élites des familles propres à la v2 :
## docs/art/SAUMATRES.md...). Chaque technique des données (`EnemyData.techniques`, `kind` = nom de la technique et de
## son clip) se joue avec un style 3D commun (`STYLES`), réglé par ses `params`. Les techniques de la campagne 2D sans
## style ici restent ignorées : les monstres déjà raccordés ne changent pas.
##
## Toutes les attaques sont annoncées au sol (DraftHazards) dans la matière de la famille du monstre ; aucune ne
## retient le Chasseur sans issue. Distances des données en pixels v1 (× DraftHunter.UNIT).

const UNIT := DraftHunter.UNIT
const STYLES := {
	# Saumâtres (chapitre 8)
	&"brine_jet": &"jet", &"lock_guard": &"guard", &"mallet_slam": &"slam", &"bell_call": &"call",
	&"brine_blessing": &"bless", &"scoop_charge": &"charge", &"salt_crust_burst": &"burst",
}
## Premier essai d'une technique après l'apparition du monstre (s), tiré dans cet intervalle.
const FIRST_TRY := Vector2(1.5, 3.5)
## Arrêt du monstre contre le décor au bout d'une charge (s).
const CHARGE_STUN := 1.0

var enemies: DraftEnemies
## Techniques jouées, par nom (essais, mesures).
var played: Dictionary = {}


func setup(p_enemies: DraftEnemies) -> void:
	enemies = p_enemies


static func style_of(kind: StringName) -> StringName:
	return STYLES.get(kind, &"")


## Le monstre a-t-il au moins une technique jouable en 3D ?
static func has_any(data: EnemyData) -> bool:
	for technique: EnemyTechniqueData in data.techniques:
		if STYLES.has(technique.kind):
			return true
	return false


## Une image du monstre : techniques en cours ou à lancer. Vrai tant qu'il tient sa position (annonce, garde
## enracinée, charge) : DraftEnemies ne le fait alors pas marcher.
func step(foe: DraftEnemies.Foe, to_hunter: Vector3, distance: float, climb: float, delta: float) -> bool:
	foe.tech_clock += delta
	if foe.guard_left > 0.0:
		foe.guard_left -= delta
		if foe.guard_left <= 0.0:
			foe.view.set_tint(Color.WHITE)
	if not foe.dash.is_empty():
		_step_dash(foe, delta)
		return true
	if foe.acting > 0.0:
		foe.acting -= delta
		return true
	if not enemies.hunter.alive or foe.tech_ready.is_empty() and not _arm(foe):
		return false
	for technique: EnemyTechniqueData in foe.data.techniques:
		var style: StringName = style_of(technique.kind)
		if style == &"" or foe.tech_clock < float(foe.tech_ready.get(technique.kind, INF)):
			continue
		if distance < technique.min_range * UNIT or distance > technique.max_range * UNIT:
			continue
		if not style in [&"call", &"bless", &"guard"] and climb > DraftEnemies.MELEE_REACH_UP:
			continue
		if style in [&"jet", &"charge"] and not bool(enemies.run.call("sight_clear", foe.pos + Vector3.UP * 0.6,
				enemies.hunter.chest())):
			continue
		perform(foe, technique, to_hunter / maxf(distance, 0.001))
		return true
	return false


## Premières recharges, décalées d'un monstre à l'autre. Faux si le monstre n'a aucune technique jouable.
func _arm(foe: DraftEnemies.Foe) -> bool:
	for technique: EnemyTechniqueData in foe.data.techniques:
		if STYLES.has(technique.kind):
			foe.tech_ready[technique.kind] = foe.tech_clock + enemies.rng.randf_range(FIRST_TRY.x, FIRST_TRY.y)
	return not foe.tech_ready.is_empty()


## Joue la technique tout de suite (essais) ; renvoie la durée pendant laquelle le monstre reste occupé.
func perform(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	if aim.length() < 0.01:
		aim = Vector3.RIGHT
	aim.y = 0.0
	aim = aim.normalized()
	foe.tech_ready[technique.kind] = foe.tech_clock + technique.cooldown
	played[technique.kind] = int(played.get(technique.kind, 0)) + 1
	foe.view.face_left(aim.x < 0.0)
	var hazards: DraftHazards = enemies.hazards
	var previous: StringName = hazards.family
	hazards.family = _combat_family(foe)
	var busy: float = call("_style_" + String(style_of(technique.kind)), foe, technique, aim)
	hazards.family = previous
	foe.acting = maxf(foe.acting, busy)
	if foe.view.has_clip(technique.anim):
		foe.view.play_action(technique.anim, maxf(busy, 0.5))
	# Suite imposée (garde puis maillet) : la technique suivante est prête à la fin de celle-ci.
	var then := StringName(str(technique.params.get("then", "")))
	if then != &"":
		foe.tech_ready[then] = foe.tech_clock + busy
	return busy


# --- Styles ----------------------------------------------------------------------------------------------------------

## Jet chargé en ligne droite vers le Chasseur ; le décor l'arrête.
func _style_jet(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var length: float = float(technique.params.get("length", 260.0)) * UNIT
	var width: float = float(technique.params.get("width", 40.0)) * UNIT
	var from: Vector3 = foe.pos + aim * foe.radius
	enemies.hazards.line(from, aim, length, width, technique.telegraph, _damage(technique), true)
	_fx(foe, str(technique.params.get("fx", "splash")), from + aim * length * 0.5, width * 2.0, technique.telegraph)
	return technique.telegraph + 0.3


## Coup lourd annoncé : devant lui (`at` = front), sur lui (self) ou sous le Chasseur (target).
func _style_slam(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var radius: float = float(technique.params.get("radius", 60.0)) * UNIT
	var at: Vector3 = foe.pos
	match str(technique.params.get("at", "front")):
		"front":
			at = foe.pos + aim * (foe.radius + radius * 0.7)
		"target":
			at = enemies.hunter.global_position
	at = enemies.level.closest(at)
	var effect: StringName = StringName(str(technique.params.get("fx", "ring_burst")))
	enemies.hazards.circle(at, radius, technique.telegraph, _damage(technique), _fx_at(foe, effect, radius * 1.6))
	return technique.telegraph + 0.35


## Garde : coups reçus × `mult` (de face seulement si `frontal`) pendant `duration` s ; enracinée, il ne bouge
## plus et ne pivote pas : on le contourne.
func _style_guard(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var duration: float = float(technique.params.get("duration", 3.0))
	foe.guard_mult = float(technique.params.get("mult", 0.2))
	foe.guard_left = duration
	foe.guard_dir = aim if bool(technique.params.get("frontal", false)) else Vector3.ZERO
	foe.view.set_tint(Color(0.85, 0.95, 1.25))
	_fx(foe, str(technique.params.get("fx", "shield_block")), foe.pos + aim * foe.radius + Vector3.UP * 0.4,
		foe.radius * 3.0, 0.0)
	return duration if bool(technique.params.get("rooted", true)) else 0.5


## Charge annoncée par une ligne, puis course droite ; elle blesse une fois et s'arrête contre le décor.
func _style_charge(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var length: float = float(technique.params.get("length", 320.0)) * UNIT
	var speed: float = float(technique.params.get("speed", 420.0)) * UNIT
	enemies.hazards.line(foe.pos, aim, length, foe.radius * 2.0 + 0.4, technique.telegraph, 0.0)
	foe.view.set_tint(Color(1.4, 1.1, 0.8))
	foe.dash = {"dir": aim, "wait": technique.telegraph, "left": length / maxf(speed, 0.1), "speed": speed,
		"damage": _damage(technique), "hit": false}
	return 0.0


## Croûte qui éclate autour de lui.
func _style_burst(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, _aim: Vector3) -> float:
	var radius: float = foe.radius + float(technique.params.get("radius", 70.0)) * UNIT
	var effect: StringName = StringName(str(technique.params.get("fx", "ring_burst")))
	enemies.hazards.circle(foe.pos, radius, technique.telegraph, _damage(technique), _fx_at(foe, effect, radius * 1.8))
	return technique.telegraph + 0.3


## Appel : petits monstres autour de lui, dans la limite de la vague.
func _style_call(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, _aim: Vector3) -> float:
	var data: EnemyData = GameDB.enemy(StringName(str(technique.params.get("spawn", ""))))
	var count: int = int(technique.params.get("count", 2))
	var cap: int = int((enemies.run.call("wave") as Dictionary).get("cap", 60)) + 6
	if not DraftRoster.usable(data) or enemies.count() >= cap:
		return 0.6
	for i: int in count:
		var at: Vector3 = enemies.level.closest(foe.pos + Vector3.RIGHT.rotated(Vector3.UP, TAU * i / count) * 2.2)
		enemies.spawn(data, at)
		_fx(foe, "summon_rise", at + Vector3.UP * 0.6, 1.0, 0.0)
	return technique.telegraph + 0.2


## Bénédiction : les Corrompus proches vont plus vite et frappent plus fort quelque temps.
func _style_bless(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, _aim: Vector3) -> float:
	var reach: float = float(technique.params.get("radius", 220.0)) * UNIT
	var mult: float = float(technique.params.get("mult", 1.3))
	var duration: float = float(technique.params.get("duration", 5.0))
	_fx(foe, "ring_charge", foe.pos + Vector3.UP * 0.3, reach * 2.0, 0.0)
	for other: DraftEnemies.Foe in enemies.near(foe.pos, reach):
		if other.boss == null:
			other.boost(mult, duration)
			_fx(other, str(technique.params.get("fx", "healing_bloom")), other.pos + Vector3.UP * 0.6, 0.9, 0.0)
	return technique.telegraph + 0.2


# --- Charge en cours -------------------------------------------------------------------------------------------------

func _step_dash(foe: DraftEnemies.Foe, delta: float) -> void:
	foe.dash["wait"] = float(foe.dash["wait"]) - delta
	if float(foe.dash["wait"]) > 0.0:
		return
	var direction: Vector3 = foe.dash["dir"]
	var speed: float = foe.dash["speed"]
	var next: Vector3 = foe.pos + direction * speed * delta
	var landed: Vector3 = enemies.level.closest(next + Vector3.UP * 0.2)
	if (landed - foe.pos).dot(direction) < speed * delta * 0.5 or bool(enemies.run.call("barrier_blocks", foe.pos, next)):
		# Contre le décor : sonné un instant.
		_end_dash(foe, CHARGE_STUN)
		_fx(foe, "dirt_explosion", foe.pos + direction * foe.radius + Vector3.UP * 0.5, 1.2, 0.0)
		return
	foe.pos = landed
	var hunter: DraftHunter = enemies.hunter
	var offset: Vector3 = hunter.global_position - foe.pos
	if not bool(foe.dash["hit"]) and Vector2(offset.x, offset.z).length() < foe.radius + DraftHunter.RADIUS + 0.3 \
			and absf(offset.y) < DraftEnemies.MELEE_REACH_UP and hunter.alive:
		foe.dash["hit"] = true
		if hunter.take_damage(float(foe.dash["damage"])) > 0.0:
			enemies.run.call("on_hunter_hit", foe)
	foe.dash["left"] = float(foe.dash["left"]) - delta
	if float(foe.dash["left"]) <= 0.0:
		_end_dash(foe, 0.4)


func _end_dash(foe: DraftEnemies.Foe, rest: float) -> void:
	foe.dash = {}
	foe.vel = Vector3.ZERO
	foe.path = PackedVector3Array()
	foe.acting = rest
	foe.view.set_tint(Color.WHITE)


# --- Outils ----------------------------------------------------------------------------------------------------------

func _damage(technique: EnemyTechniqueData) -> float:
	return technique.damage * enemies.damage_mult


static func _combat_family(foe: DraftEnemies.Foe) -> StringName:
	return DraftPixelFx.enemy_family(foe.data)


## Palette de la famille du monstre si l'effet y existe, sinon la palette commune.
static func _tint(effect: StringName, foe: DraftEnemies.Foe) -> StringName:
	var family: StringName = DraftPixelFx.enemy_family(foe.data)
	return family if not DraftPixelFx.sheet(effect, family).is_empty() else DraftPixelFx.DEFAULT_FAMILY


## Effet PixelFX dans la palette de la famille, tout de suite ou après `delay` s.
func _fx(foe: DraftEnemies.Foe, effect: String, at: Vector3, size: float, delay: float) -> void:
	var family: StringName = _tint(StringName(effect), foe)
	if delay <= 0.0:
		enemies.run.call("fx", StringName(effect), family, at, size)
		return
	enemies.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if is_instance_valid(enemies):
			enemies.run.call("fx", StringName(effect), family, at, size))


func _fx_at(foe: DraftEnemies.Foe, effect: StringName, size: float) -> Callable:
	var family: StringName = _tint(effect, foe)
	return func(at: Vector3) -> void: enemies.run.call("fx", effect, family, at + Vector3.UP * 0.5, size)
