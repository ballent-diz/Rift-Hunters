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
	# Rapiécés (chapitre 6)
	&"spring_kick": &"slam", &"braced_shuttle": &"guard", &"loom_strike": &"jet", &"thread_gather": &"pull",
	&"shroud": &"guard", &"bow_and_ram": &"charge", &"fringe_bristle": &"burst",
	# Vernissés (chapitre 9)
	&"pigment_spit": &"jet", &"tile_barrier": &"wall", &"verdict": &"slam", &"clay_assembly": &"call",
	&"sherd_cast": &"throw", &"roll_windup": &"charge", &"tile_ridge": &"ridge",
}
## Carreaux dressés par une technique (barrage du Juge) : même couche que le décor, ils arrêtent tirs et Chasseur.
const TILE := Color(0.24, 0.38, 0.7)
## Premier essai d'une technique après l'apparition du monstre (s), tiré dans cet intervalle.
const FIRST_TRY := Vector2(1.5, 3.5)
## Arrêt du monstre contre le décor au bout d'une charge (s).
const CHARGE_STUN := 1.0

var enemies: DraftEnemies
## Murs de carreaux dressés (barrage du Juge), retirés à leur échéance ou au changement d'étage.
var walls: Array[StaticBody3D] = []
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
		# `below` : seulement une fois blessé (repli sous le linceul).
		if foe.hp > foe.max_hp * float(technique.params.get("below", 1.0)):
			continue
		if style in [&"jet", &"charge", &"pull"] and not bool(enemies.run.call("sight_clear", foe.pos + Vector3.UP * 0.6,
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

## Jet chargé en ligne droite vers le Chasseur ; le décor l'arrête. `puddle` (px) : flaque de pigment au bout,
## qui ralentit (`slow`) pendant `puddle_time` s.
func _style_jet(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var length: float = float(technique.params.get("length", 260.0)) * UNIT
	var width: float = float(technique.params.get("width", 40.0)) * UNIT
	var from: Vector3 = foe.pos + aim * foe.radius
	enemies.hazards.line(from, aim, length, width, technique.telegraph, _damage(technique), true)
	_fx(foe, str(technique.params.get("fx", "splash")), from + aim * length * 0.5, width * 2.0, technique.telegraph)
	var puddle: float = float(technique.params.get("puddle", 0.0)) * UNIT
	if puddle > 0.0:
		var at: Vector3 = enemies.level.closest(from + aim * length * 0.8)
		var hazards: DraftHazards = enemies.hazards
		var family: StringName = hazards.family
		var time: float = float(technique.params.get("puddle_time", 4.0))
		var slow: float = float(technique.params.get("slow", 0.6))
		var tick: float = _damage(technique) * 0.1
		enemies.get_tree().create_timer(technique.telegraph, false).timeout.connect(func() -> void:
			if is_instance_valid(hazards):
				var previous: StringName = hazards.family
				hazards.family = family
				hazards.zone(at, puddle, time, tick, slow, TILE)
				hazards.family = previous)
	return technique.telegraph + 0.3


## Coup lourd annoncé : devant lui (`at` = front), sur lui (self) ou sous le Chasseur (target) ; `push` (m) repousse
## le Chasseur touché (coup de pied à ressort).
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
	var push: float = float(technique.params.get("push", 0.0))
	var hunter: DraftHunter = enemies.hunter
	var shove := Callable()
	if push > 0.0:
		shove = func() -> void:
			var away: Vector3 = hunter.global_position - foe.pos
			away.y = 0.0
			hunter.move_and_collide((away.normalized() if away.length() > 0.01 else aim) * push)
	enemies.hazards.circle(at, radius, technique.telegraph, _damage(technique), _fx_at(foe, effect, radius * 1.6), shove)
	return technique.telegraph + 0.35


## Garde : coups reçus × `mult` (de face seulement si `frontal`) pendant `duration` s ; enracinée, il ne bouge
## plus et ne pivote pas : on le contourne. `heal` : part des PV max rendue (repli sous le linceul).
func _style_guard(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var duration: float = float(technique.params.get("duration", 3.0))
	foe.guard_mult = float(technique.params.get("mult", 0.2))
	foe.guard_left = duration
	foe.guard_dir = aim if bool(technique.params.get("frontal", false)) else Vector3.ZERO
	foe.view.set_tint(Color(0.85, 0.95, 1.25))
	foe.hp = minf(foe.hp + foe.max_hp * float(technique.params.get("heal", 0.0)), foe.max_hp)
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


## Fil lancé en ligne vers le Chasseur : touché, il est tiré de `pull` m vers le monstre et ralenti.
func _style_pull(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var length: float = float(technique.params.get("length", 320.0)) * UNIT
	var width: float = float(technique.params.get("width", 34.0)) * UNIT
	var pull: float = float(technique.params.get("pull", 3.0))
	var hinder: float = float(technique.params.get("hinder", 0.6))
	var hunter: DraftHunter = enemies.hunter
	var from: Vector3 = foe.pos + aim * foe.radius
	enemies.hazards.line(from, aim, length, width, technique.telegraph, _damage(technique), true, 0.0, 0.0,
		func() -> void:
			var toward: Vector3 = foe.pos - hunter.global_position
			toward.y = 0.0
			if toward.length() > foe.radius + 1.0:
				hunter.move_and_collide(toward.normalized() * minf(pull, toward.length() - foe.radius - 0.8))
			hunter.hinder(hinder, 1.2)
			_fx(foe, str(technique.params.get("fx", "soul_drain")), hunter.chest(), 1.0, 0.0))
	return technique.telegraph + 0.3


## Barrage de carreaux : un mur dressé entre lui et le Chasseur (`distance`, `width` en px) pendant `duration` s ;
## il arrête les tirs comme le décor, on le contourne.
func _style_wall(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var duration: float = float(technique.params.get("duration", 4.0))
	var width: float = float(technique.params.get("width", 110.0)) * UNIT
	var at: Vector3 = enemies.level.closest(foe.pos + aim * (foe.radius + float(technique.params.get("distance", 60.0)) * UNIT))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var size := Vector3(width, 1.8, 0.4)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = TILE
	mesh.material_override = material
	body.add_child(mesh)
	enemies.add_child(body)
	body.global_position = at + Vector3.UP * size.y * 0.5
	body.global_basis = Basis(Vector3.UP, atan2(aim.x, aim.z))
	walls.append(body)
	_fx(foe, "shield_block", at + Vector3.UP * 0.8, width, 0.0)
	enemies.get_tree().create_timer(duration, false).timeout.connect(func() -> void:
		walls.erase(body)
		if is_instance_valid(body):
			body.queue_free())
	return technique.telegraph + 0.3


## Tessons lancés en cloche : `count` zones autour du Chasseur, l'une après l'autre.
func _style_throw(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, _aim: Vector3) -> float:
	var count: int = int(technique.params.get("count", 3))
	var radius: float = float(technique.params.get("radius", 40.0)) * UNIT
	var spread: float = float(technique.params.get("spread", 60.0)) * UNIT
	var gap: float = float(technique.params.get("gap", 0.2))
	var center: Vector3 = enemies.hunter.global_position
	var effect: StringName = StringName(str(technique.params.get("fx", "mana_burst")))
	for k: int in count:
		var offset := Vector3.ZERO if k == 0 else Vector3(enemies.rng.randf_range(-spread, spread), 0,
			enemies.rng.randf_range(-spread, spread))
		enemies.hazards.circle(enemies.level.closest(center + offset), radius, technique.telegraph + gap * k,
			_damage(technique), _fx_at(foe, effect, radius * 1.6))
	return technique.telegraph * 0.6 + 0.3


## Crête de carreaux : zones qui jaillissent l'une après l'autre du monstre vers le Chasseur.
func _style_ridge(foe: DraftEnemies.Foe, technique: EnemyTechniqueData, aim: Vector3) -> float:
	var radius: float = float(technique.params.get("radius", 34.0)) * UNIT
	var length: float = float(technique.params.get("length", 300.0)) * UNIT
	var effect: StringName = StringName(str(technique.params.get("fx", "ring_burst")))
	var count: int = maxi(int(length / (radius * 1.6)), 2)
	for k: int in count:
		var at: Vector3 = enemies.level.closest(foe.pos + aim * (foe.radius + radius + radius * 1.6 * k))
		enemies.hazards.circle(at, radius, technique.telegraph + 0.07 * k, _damage(technique),
			_fx_at(foe, effect, radius * 1.4))
	return technique.telegraph + 0.3


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
