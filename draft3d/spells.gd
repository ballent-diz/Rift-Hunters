class_name DraftSpells
extends RefCounted
## Sorts actifs du Chasseur dans la base 3D (docs/design/SORTS_ACTIFS_V2.md). Quatre emplacements, lancés par les
## actions reconfigurables `spell_1` à `spell_4` (InputSetup : flèches au clavier seul, A E R F + clic avec la souris).
## Visée : curseur projeté sur le sol (souris), stick droit (manette) ou, au clavier seul, l'ennemi visible le plus
## proche devant le Chasseur. Données d'origine (`SpellData` : dégâts, recharge, portée, largeur) ; réglages propres
## à la 3D dans `DraftTuning` (groupe « Sorts »). Sorts de départ : ceux équipés dans l'arbre du profil (lecture
## seule), sinon ceux de l'équilibrage ; les autres s'apprennent pendant la partie (cartes `DraftSpellEffect`).
## Le bot (`auto_cast`) lance ses sorts seul quand ils sont utiles.

const SLOTS := 4
const ACTIONS: Array[StringName] = [&"spell_1", &"spell_2", &"spell_3", &"spell_4"]
## Sorts raccordés (spell_kind) : Taille, Lance, Rupture, Bond de Faille.
const SUPPORTED: Array[StringName] = [&"slash", &"lance", &"rupture", &"leap"]
## Cosinus du demi-angle du cône de visée au clavier (environ 37°).
const AIM_CONE := 0.8
const RETICLE_COLOR := Color(0.85, 0.95, 1.0, 0.55)

var run: DraftRun
var tuning: DraftTuning
## Sort par emplacement (null : emplacement libre).
var slots: Array[SpellData] = []
var cooldowns := PackedFloat32Array()
## Sorts équipés dans le profil mais pas encore raccordés à la 3D.
var skipped: Array[StringName] = []
var casts: int = 0
## Lancement automatique (bot et vérifications) : aucune touche lue.
var auto_cast: bool = false
## Emplacement en aperçu (option « aperçu » : maintenir montre la zone, relâcher lance), -1 sinon.
var preview_slot: int = -1
var reticle: MeshInstance3D
var _reticle_material: StandardMaterial3D
## Bond en cours : sort et puissance appliqués à l'atterrissage.
var _leap_spell: SpellData


func setup(p_run: DraftRun, ids: Array[StringName]) -> void:
	run = p_run
	tuning = run.tuning
	slots.resize(SLOTS)
	slots.fill(null)
	cooldowns.resize(SLOTS)
	cooldowns.fill(0.0)
	for id: StringName in ids:
		if not learn(id):
			skipped.append(id)
	for i: int in SLOTS:
		cooldowns[i] = 1.0 + i if slots[i] != null else 0.0
	run.hunter.landed.connect(_on_landed)
	reticle = _build_reticle()
	run.add_child(reticle)


## Sort utilisable dans la 3D (données présentes et spell_kind raccordé).
static func supported(id: StringName) -> bool:
	var data: SpellData = GameDB.spells.get(id)
	return data != null and SUPPORTED.has(data.spell_kind)


func slot_of(id: StringName) -> int:
	for i: int in SLOTS:
		if slots[i] != null and slots[i].id == id:
			return i
	return -1


func has_spell(id: StringName) -> bool:
	return slot_of(id) >= 0


func free_slots() -> int:
	return slots.count(null)


## Place un sort dans le premier emplacement libre. Faux si inconnu, non raccordé, déjà appris ou plus de place.
func learn(id: StringName) -> bool:
	if not supported(id) or has_spell(id) or free_slots() == 0:
		return false
	var index: int = slots.find(null)
	slots[index] = GameDB.spells[id]
	cooldowns[index] = tuning.learned_cooldown
	return true


## Une carte de sort servirait-elle maintenant ?
func can_apply(effect: DraftSpellEffect) -> bool:
	if effect == null:
		return false
	match effect.kind:
		DraftSpellEffect.Kind.LEARN:
			return supported(effect.spell_id) and not has_spell(effect.spell_id) and free_slots() > 0
	return false


func apply_effect(effect: DraftSpellEffect) -> void:
	match effect.kind:
		DraftSpellEffect.Kind.LEARN:
			learn(effect.spell_id)


func cooldown_of(data: SpellData) -> float:
	return data.cooldown * maxf(run.hunter.stats.get_value(StatKeys.SPELL_COOLDOWN), 0.2)


func damage_of(data: SpellData) -> float:
	return data.damage * run.hunter.stats.get_value(StatKeys.SPELL_DAMAGE) * run.hunter.stats.get_value(StatKeys.DAMAGE)


## Portée du sort en mètres.
func reach_of(data: SpellData) -> float:
	var reach: float = data.spell_range * DraftHunter.UNIT
	match data.spell_kind:
		&"lance":
			return minf(reach, tuning.lance_max_range)
		&"leap":
			return minf(reach, tuning.leap_max_range)
	return reach


## Rayon de la zone touchée en mètres (Rupture, onde du Bond) ; demi-largeur pour la Lance.
func area_of(data: SpellData) -> float:
	match data.spell_kind:
		&"lance":
			return maxf(data.width * DraftHunter.UNIT, 0.3)
		&"leap":
			return data.width * DraftHunter.UNIT
	return data.width * DraftHunter.UNIT * tuning.spell_area_scale


## Part de la recharge écoulée (1 : prêt), pour le HUD.
func ready_ratio(slot: int) -> float:
	if slots[slot] == null:
		return 0.0
	return 1.0 - clampf(cooldowns[slot] / maxf(cooldown_of(slots[slot]), 0.01), 0.0, 1.0)


func step(delta: float) -> void:
	for i: int in SLOTS:
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	var hunter: DraftHunter = run.hunter
	if not hunter.alive or not hunter.active:
		preview_slot = -1
		reticle.visible = false
		return
	if auto_cast:
		reticle.visible = false
		for i: int in SLOTS:
			if slots[i] != null and cooldowns[i] <= 0.0:
				var aim: Vector3 = auto_aim(slots[i])
				if aim != Vector3.INF:
					cast(i, aim)
		return
	for i: int in SLOTS:
		if slots[i] == null:
			continue
		if Settings.spell_preview:
			if Input.is_action_just_pressed(ACTIONS[i]):
				preview_slot = i
			elif preview_slot == i and not Input.is_action_pressed(ACTIONS[i]):
				preview_slot = -1
				cast(i, aim_point())
		elif Input.is_action_just_pressed(ACTIONS[i]):
			cast(i, aim_point())
	_show_reticle()


## Lance le sort de l'emplacement vers `aim` (point du sol). Faux si vide, en recharge ou pendant un Bond.
func cast(slot: int, aim: Vector3) -> bool:
	var data: SpellData = slots[slot] if slot >= 0 and slot < SLOTS else null
	if data == null or cooldowns[slot] > 0.0 or run.hunter.is_leaping() or not run.hunter.alive:
		return false
	var done: bool = false
	match data.spell_kind:
		&"slash":
			done = _slash(data, aim)
		&"lance":
			done = _lance(data, aim)
		&"rupture":
			done = _rupture(data, aim)
		&"leap":
			done = _leap(data, aim)
	if done:
		cooldowns[slot] = cooldown_of(data)
		casts += 1
		Audio.play_sfx(&"technique")
		run.hunter.view.face_left(_flat(aim - run.hunter.global_position).dot(run.camera.global_basis.x) < 0.0)
		run.hunter.view.play_action(&"attack", 0.25)
	return done


# --- Visée --------------------------------------------------------------------------------------------------------

## Point visé selon le mode de contrôle : curseur (souris), stick droit (manette), sinon devant le Chasseur.
func aim_point() -> Vector3:
	var hunter: DraftHunter = run.hunter
	var here: Vector3 = hunter.global_position
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.3:
		return here + Vector3(stick.x, 0, stick.y).normalized() * tuning.aim_distance
	if Settings.uses_mouse() and run.camera != null and run.is_inside_tree():
		var mouse: Vector2 = run.get_viewport().get_mouse_position()
		var ground := Plane(Vector3.UP, here.y)
		var hit: Variant = ground.intersects_ray(run.camera.project_ray_origin(mouse), run.camera.project_ray_normal(mouse))
		if hit != null:
			return hit
	return facing_aim(hunter.facing)


## Clavier seul : l'ennemi visible le plus proche dans le cône devant le Chasseur, sinon un point devant lui.
func facing_aim(facing: Vector3) -> Vector3:
	var here: Vector3 = run.hunter.global_position
	var best: DraftEnemies.Foe = null
	var best_distance: float = tuning.aim_range
	for foe: DraftEnemies.Foe in run.enemies.near(here, tuning.aim_range):
		var offset: Vector3 = _flat(foe.pos - here)
		var distance: float = offset.length()
		if distance < best_distance and distance > 0.1 and offset.dot(facing) / distance >= AIM_CONE \
				and absf(foe.pos.y - here.y) <= DraftEnemies.MELEE_REACH_UP \
				and run.sight_clear(run.hunter.chest(), foe.pos + Vector3.UP * 0.5):
			best = foe
			best_distance = distance
	return best.pos if best != null else here + facing.normalized() * tuning.aim_distance


## Visée du bot : un point utile, ou Vector3.INF quand le sort ne servirait à rien maintenant.
func auto_aim(data: SpellData) -> Vector3:
	var here: Vector3 = run.hunter.global_position
	match data.spell_kind:
		&"slash":
			var foes: Array[DraftEnemies.Foe] = _level(run.enemies.near(here, reach_of(data)), here)
			return foes[0].pos if not foes.is_empty() else Vector3.INF
		&"lance", &"rupture":
			var foe: DraftEnemies.Foe = run.target()
			return foe.pos if foe != null else Vector3.INF
		&"leap":
			var close: Array[DraftEnemies.Foe] = _level(run.enemies.near(here, 2.2), here)
			if close.size() < 3:
				return Vector3.INF
			var away := Vector3.ZERO
			for foe: DraftEnemies.Foe in close:
				away += _flat(here - foe.pos).normalized()
			away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
			return here + away * reach_of(data)
	return Vector3.INF


# --- Sorts --------------------------------------------------------------------------------------------------------

## Taille fendante : arc de lame vers la visée ; tout ce qui est dans l'arc, de plain-pied et visible.
func _slash(data: SpellData, aim: Vector3) -> bool:
	var here: Vector3 = run.hunter.global_position
	var reach: float = reach_of(data)
	var dir: Vector3 = _direction(aim)
	var half: float = cos(deg_to_rad(clampf(data.width, 0.0, 180.0)))
	run.fx(&"heavy_cleave", DraftPixelFx.DEFAULT_FAMILY, here + dir * reach * 0.5 + Vector3.UP * 0.7, 2.2)
	for foe: DraftEnemies.Foe in _level(run.enemies.near(here, reach), here):
		var offset: Vector3 = _flat(foe.pos - here)
		if offset.length() < foe.radius + 0.4 or offset.normalized().dot(dir) >= half:
			run.enemies.hit(foe, damage_of(data), dir * data.knockback * DraftHunter.UNIT * 3.0)
	return true


## Lance prismatique : trait lourd vers la visée, qui traverse tout.
func _lance(data: SpellData, aim: Vector3) -> bool:
	var origin: Vector3 = run.hunter.chest()
	var dir: Vector3 = _direction(aim)
	run.fire_bolt(origin, dir, damage_of(data), reach_of(data), 99, 0, &"ice_lance", 1.1, area_of(data),
		tuning.lance_speed, &"reflets")
	return true


## Rupture : détonation de zone au point visé (portée limitée, arrêtée par le décor).
func _rupture(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = _landing(aim, reach_of(data))
	var radius: float = area_of(data)
	run.fx(&"dark_explosion", DraftPixelFx.DEFAULT_FAMILY, at + Vector3.UP * 0.6, radius)
	for foe: DraftEnemies.Foe in _level(run.enemies.near(at, radius), at):
		run.enemies.hit(foe, damage_of(data) * tuning.rupture_damage_mult)
	return true


## Bond de Faille : saut jusqu'au point visé (arrêté par le décor), invulnérable, onde de choc à l'arrivée.
func _leap(data: SpellData, aim: Vector3) -> bool:
	var hunter: DraftHunter = run.hunter
	var landing: Vector3 = _landing(aim, reach_of(data))
	run.fx(&"blink_out", DraftPixelFx.DEFAULT_FAMILY, hunter.global_position + Vector3.UP * 0.6)
	_leap_spell = data
	hunter.leap_to(landing + Vector3.UP * 0.05, float(data.params.get("duration", 0.25)))
	return true


func _on_landed() -> void:
	var data: SpellData = _leap_spell
	_leap_spell = null
	if data == null:
		return
	var landing: Vector3 = run.hunter.global_position
	run.hunter.reset_motion()
	run.fx(&"ring_burst", DraftPixelFx.DEFAULT_FAMILY, landing + Vector3.UP * 0.4, 2.0)
	for foe: DraftEnemies.Foe in _level(run.enemies.near(landing, area_of(data)), landing):
		run.enemies.hit(foe, damage_of(data), _flat(foe.pos - landing).normalized() * data.knockback * DraftHunter.UNIT)


# --- Outils -------------------------------------------------------------------------------------------------------

## Direction horizontale vers la visée (devant le Chasseur si la visée est sur lui).
func _direction(aim: Vector3) -> Vector3:
	var dir: Vector3 = _flat(aim - run.hunter.global_position)
	return dir.normalized() if dir.length() > 0.05 else run.hunter.facing.normalized()


## Point au sol vers `aim`, à `reach` au plus, arrêté avant le décor qui le cache, posé sur la navigation.
func _landing(aim: Vector3, reach: float) -> Vector3:
	var here: Vector3 = run.hunter.global_position
	var offset: Vector3 = _flat(aim - here)
	var target: Vector3 = here + offset.limit_length(reach)
	target.y = aim.y
	var from: Vector3 = run.hunter.chest()
	var to: Vector3 = target + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var wall: Dictionary = run.get_world_3d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		var stop: Vector3 = wall["position"]
		to = stop - from.direction_to(stop) * 0.5
	var ground: Vector3 = run.level.closest(to - Vector3.UP * 0.8)
	return ground if ground.distance_to(to) < 3.0 else here


## Ennemis du même niveau et visibles depuis `from` (aucun décor entre les deux), les plus proches d'abord.
func _level(foes: Array[DraftEnemies.Foe], from: Vector3) -> Array[DraftEnemies.Foe]:
	var result: Array[DraftEnemies.Foe] = []
	for foe: DraftEnemies.Foe in foes:
		if absf(foe.pos.y - from.y) <= DraftEnemies.MELEE_REACH_UP \
				and run.sight_clear(from + Vector3.UP * 0.8, foe.pos + Vector3.UP * 0.5):
			result.append(foe)
	result.sort_custom(func(a: DraftEnemies.Foe, b: DraftEnemies.Foe) -> bool:
		return a.pos.distance_squared_to(from) < b.pos.distance_squared_to(from))
	return result


## Anneau au sol : point visé, ou zone du sort en aperçu (option « aperçu »).
func _build_reticle() -> MeshInstance3D:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.88
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = RETICLE_COLOR
	ring.material = material
	_reticle_material = material
	var node := MeshInstance3D.new()
	node.name = "SpellReticle"
	node.mesh = ring
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	return node


func _show_reticle() -> void:
	var here: Vector3 = run.hunter.global_position
	var aim: Vector3 = aim_point()
	var radius: float = 0.35
	var at: Vector3 = aim
	var color: Color = RETICLE_COLOR
	if preview_slot >= 0 and slots[preview_slot] != null:
		var data: SpellData = slots[preview_slot]
		color = Color(data.color, 0.7)
		match data.spell_kind:
			&"slash":
				at = here
				radius = reach_of(data)
			&"rupture", &"leap":
				at = here + _flat(aim - here).limit_length(reach_of(data))
				radius = area_of(data)
			_:
				radius = area_of(data) * 2.0
	reticle.visible = slots.any(func(s: SpellData) -> bool: return s != null)
	reticle.position = Vector3(at.x, here.y + 0.06, at.z)
	reticle.scale = Vector3(radius, 0.3, radius)
	_reticle_material.albedo_color = color


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
