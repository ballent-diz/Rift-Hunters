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
## Sorts raccordés (spell_kind) : Taille, Lance, Rupture, Bond de Faille, Parade, Singularité, Mur de faille, Égide,
## Cristal réfracteur.
## Plus les six sorts propres à la v2 (DraftRiftSpells.KINDS).
const SUPPORTED: Array[StringName] = [&"slash", &"lance", &"rupture", &"leap", &"parry", &"singularity", &"wall",
	&"aegis", &"crystal", &"mark", &"rend", &"blink", &"stasis", &"shard_rain", &"veil"]
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
## Objets posés par les sorts (puits, murs, cristaux).
var world: DraftSpellWorld
## Sorts propres à la v2 (marque, fente, pas, stase, pluie, voile).
var rift: DraftRiftSpells
## Variante active par sort (identifiant du sort → variante) et ses réglages ; rangs pris par sort et statistique.
var variants: Dictionary = {}
var variant_params: Dictionary = {}
var bonuses: Dictionary = {}
## Surcharge : emplacement en charge (-1 sinon) et durée de charge.
var charge_slot: int = -1
var charge_time: float = 0.0
var _reticle_material: StandardMaterial3D
## Derniers sorts de Parade et d'Égide lancés (contre-attaque, Riposte).
var _parry_spell: SpellData
var _aegis_spell: SpellData
## Bond en cours : sort et puissance appliqués à l'atterrissage.
var _leap_spell: SpellData
var _leap_power: float = 1.0
## Retour (variante du Bond) : point de départ, sort et fenêtre restante.
var _return_point := Vector3.ZERO
var _return_spell: StringName = &""
var _return_left: float = 0.0
## Puissance du lancement en cours (Surcharge) et zones de Brasier.
var _power: float = 1.0
var _zones: Array[Dictionary] = []


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
	run.hunter.parried.connect(_on_parried)
	run.hunter.shield_broken.connect(_on_shield_broken)
	world = DraftSpellWorld.new(self)
	rift = DraftRiftSpells.new(self)
	reticle = _build_reticle()
	run.add_child(reticle)


## Données d'un sort : sorts de la campagne (GameDB) puis sorts propres à la v2 (draft3d/spells/data/).
static func spell(id: StringName) -> SpellData:
	var data: SpellData = GameDB.spells.get(id)
	return data if data != null else DraftRiftSpells.registry().get(id)


## Sort utilisable dans la 3D (données présentes et spell_kind raccordé).
static func supported(id: StringName) -> bool:
	var data: SpellData = spell(id)
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
	slots[index] = spell(id)
	cooldowns[index] = tuning.learned_cooldown
	return true


## Une carte de sort servirait-elle maintenant ?
func can_apply(effect: DraftSpellEffect) -> bool:
	if effect == null:
		return false
	match effect.kind:
		DraftSpellEffect.Kind.LEARN:
			return supported(effect.spell_id) and not has_spell(effect.spell_id) and free_slots() > 0
		DraftSpellEffect.Kind.VARIANT:
			return has_spell(effect.spell_id) and not variants.has(effect.spell_id)
		DraftSpellEffect.Kind.MODIFY:
			return has_spell(effect.spell_id)
	return false


func apply_effect(effect: DraftSpellEffect) -> void:
	match effect.kind:
		DraftSpellEffect.Kind.LEARN:
			learn(effect.spell_id)
		DraftSpellEffect.Kind.VARIANT:
			variants[effect.spell_id] = effect.variant
			variant_params[effect.spell_id] = effect.params
		DraftSpellEffect.Kind.MODIFY:
			var stats: Dictionary = bonuses.get(effect.spell_id, {})
			stats[effect.stat] = float(stats.get(effect.stat, 0.0)) + effect.pct
			bonuses[effect.spell_id] = stats


func variant_of(data: SpellData) -> StringName:
	return variants.get(data.id, &"")


## Réglage `key` de la variante active du sort.
func param(data: SpellData, key: String, fallback: float) -> float:
	return float((variant_params.get(data.id, {}) as Dictionary).get(key, fallback))


## Somme des rangs pris sur une statistique du sort (+0,2 = +20 %).
func bonus(data: SpellData, stat: StringName) -> float:
	return float((bonuses.get(data.id, {}) as Dictionary).get(stat, 0.0))


func cooldown_of(data: SpellData) -> float:
	return data.cooldown * maxf(run.hunter.stats.get_value(StatKeys.SPELL_COOLDOWN), 0.2) \
		* maxf(1.0 + bonus(data, &"cooldown"), 0.3)


func damage_of(data: SpellData) -> float:
	return data.damage * run.hunter.stats.get_value(StatKeys.SPELL_DAMAGE) * run.hunter.stats.get_value(StatKeys.DAMAGE) \
		* (1.0 + bonus(data, &"damage"))


## Valeur de dégâts `base` portée par les statistiques de sort du Chasseur et les rangs de dégâts du sort.
func scaled(data: SpellData, base: float) -> float:
	return base * run.hunter.stats.get_value(StatKeys.SPELL_DAMAGE) * run.hunter.stats.get_value(StatKeys.DAMAGE) \
		* (1.0 + bonus(data, &"damage"))


## Durée de l'effet (params.duration de SpellData) avec les rangs de durée.
func duration_of(data: SpellData) -> float:
	return float(data.params.get("duration", 1.0)) * (1.0 + bonus(data, &"duration"))


## Portée du sort en mètres.
func reach_of(data: SpellData) -> float:
	var reach: float = data.spell_range * DraftHunter.UNIT
	match data.spell_kind:
		&"slash":
			if variant_of(data) == &"thrust":
				reach = param(data, "range", data.spell_range) * DraftHunter.UNIT
			elif variant_of(data) == &"whirlwind":
				reach *= param(data, "reach", 1.0)
		&"lance":
			reach = minf(reach, tuning.lance_max_range)
		&"leap":
			reach = minf(reach, tuning.leap_max_range)
	return reach * (1.0 + bonus(data, &"reach"))


## Rayon de la zone touchée en mètres (Rupture, onde du Bond) ; demi-largeur pour la Lance et l'Estoc.
func area_of(data: SpellData) -> float:
	var area: float = data.width * DraftHunter.UNIT * tuning.spell_area_scale
	match data.spell_kind:
		&"slash":
			if variant_of(data) == &"thrust":
				area = param(data, "half_width", data.width) * DraftHunter.UNIT
		&"lance":
			area = maxf(data.width * DraftHunter.UNIT, 0.3)
		&"leap":
			area = data.width * DraftHunter.UNIT * (param(data, "area", 1.0) if variant_of(data) == &"impact" else 1.0)
		&"singularity":
			area *= param(data, "area", 1.0) if variant_of(data) == &"horizon" else 1.0
		&"crystal":
			area = maxf(data.width * DraftHunter.UNIT, tuning.crystal_min_radius)
		&"aegis":
			area = param(data, "area", 3.0)
	return area * (1.0 + bonus(data, &"area"))


## Part de la recharge écoulée (1 : prêt), pour le HUD.
func ready_ratio(slot: int) -> float:
	if slots[slot] == null:
		return 0.0
	return 1.0 - clampf(cooldowns[slot] / maxf(cooldown_of(slots[slot]), 0.01), 0.0, 1.0)


func step(delta: float) -> void:
	for i: int in SLOTS:
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	_step_zones(delta)
	world.step(delta)
	rift.step(delta)
	_return_left = maxf(_return_left - delta, 0.0)
	var hunter: DraftHunter = run.hunter
	if not hunter.alive or not hunter.active:
		preview_slot = -1
		charge_slot = -1
		reticle.visible = false
		return
	if auto_cast:
		reticle.visible = false
		for i: int in SLOTS:
			if slots[i] != null and ready(i):
				var aim: Vector3 = auto_aim(slots[i])
				if aim != Vector3.INF:
					cast(i, aim)
		return
	if charge_slot >= 0:
		charge_time += delta
		if not Input.is_action_pressed(ACTIONS[charge_slot]):
			var slot: int = charge_slot
			charge_slot = -1
			cast(slot, aim_point(), charge_power(slots[slot]))
	for i: int in SLOTS:
		if slots[i] == null:
			continue
		var pressed: bool = Input.is_action_just_pressed(ACTIONS[i])
		if pressed and _return_left > 0.0 and slots[i].id == _return_spell:
			leap_back()
		elif variant_of(slots[i]) == &"overcharge":
			if pressed and cooldowns[i] <= 0.0 and charge_slot < 0:
				charge_slot = i
				charge_time = 0.0
		elif Settings.spell_preview:
			if pressed:
				preview_slot = i
			elif preview_slot == i and not Input.is_action_pressed(ACTIONS[i]):
				preview_slot = -1
				cast(i, aim_point())
		elif pressed:
			cast(i, aim_point())
	_show_reticle()


## Surcharge : puissance selon la durée de charge (×1 jusqu'au maximum de la variante).
func charge_power(data: SpellData) -> float:
	return lerpf(1.0, param(data, "max", 1.0), clampf(charge_time / maxf(param(data, "time", 1.0), 0.05), 0.0, 1.0))


## Sort prêt : recharge finie, ou charge disponible (Deux charges).
func ready(slot: int) -> bool:
	return slots[slot] != null and (cooldowns[slot] <= 0.0 or rift.has_charge(slots[slot]))


## Lance le sort de l'emplacement vers `aim` (point du sol), avec un multiplicateur de dégâts `power` (Surcharge).
## Faux si vide, en recharge ou pendant un Bond.
func cast(slot: int, aim: Vector3, power: float = 1.0) -> bool:
	var data: SpellData = slots[slot] if slot >= 0 and slot < SLOTS else null
	if data == null or not ready(slot) or run.hunter.is_leaping() or not run.hunter.alive:
		return false
	_power = power
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
		&"parry":
			done = _parry(data)
		&"singularity":
			done = _singularity(data, aim)
		&"wall":
			done = _wall(data, aim)
		&"aegis":
			done = _aegis(data)
		&"crystal":
			done = _crystal(data, aim)
		_:
			done = rift.cast(data, aim)
	_power = 1.0
	if done:
		if not rift.after_cast(slot, data):
			cooldowns[slot] = cooldown_of(data)
		casts += 1
		Audio.play_sfx(&"technique")
		run.hunter.view.face_left(_flat(aim - run.hunter.global_position).dot(run.camera.global_basis.x) < 0.0)
		# Animation complète pour la Taille : ses dernières images portent l'arc de lame du Chasseur.
		run.hunter.view.play_action(&"attack", -1.0 if data.spell_kind == &"slash" else 0.25)
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
		# Rendu pixel : la caméra vit dans une vue basse résolution affichée en plein écran.
		var view: Viewport = run.camera.get_viewport()
		if view != run.get_viewport():
			mouse *= Vector2(view.get_visible_rect().size) / run.get_viewport().get_visible_rect().size
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
		&"parry", &"aegis", &"singularity", &"wall", &"crystal":
			return _auto_support(data)
	return rift.auto_aim(data)


## Bot : sorts défensifs quand le Chasseur est serré (ou blessé), sorts de zone sur un groupe.
func _auto_support(data: SpellData) -> Vector3:
	var here: Vector3 = run.hunter.global_position
	if data.spell_kind == &"parry":
		return here if _level(run.enemies.near(here, 1.4), here).size() >= 2 else Vector3.INF
	if data.spell_kind == &"aegis":
		var hurt: bool = run.hunter.hp < run.hunter.max_hp() * 0.75
		return here if hurt and run.enemies.near(here, 3.0).size() >= 2 else Vector3.INF
	var foe: DraftEnemies.Foe = run.target()
	if foe == null or run.enemies.near(foe.pos, 3.0).size() < 3:
		return Vector3.INF
	return foe.pos if data.spell_kind == &"singularity" else here + _flat(foe.pos - here).limit_length(2.5)


# --- Sorts --------------------------------------------------------------------------------------------------------

## Taille fendante : arc de lame vers la visée ; tout ce qui est dans l'arc, de plain-pied et visible.
## Tourbillon : cercle complet autour du Chasseur. Estoc : ligne longue et étroite qui perce tout.
func _slash(data: SpellData, aim: Vector3) -> bool:
	var here: Vector3 = run.hunter.global_position
	var reach: float = reach_of(data)
	var dir: Vector3 = _direction(aim)
	var variant: StringName = variant_of(data)
	var push: Vector3 = dir * data.knockback * DraftHunter.UNIT * 3.0
	if variant == &"thrust":
		var half_width: float = area_of(data)
		run.fx(&"arcane_beam", DraftPixelFx.DEFAULT_FAMILY, here + dir * reach * 0.5 + Vector3.UP * 0.7, reach * 0.4)
		for foe: DraftEnemies.Foe in _level(run.enemies.near(here, reach), here):
			var offset: Vector3 = _flat(foe.pos - here)
			var along: float = offset.dot(dir)
			if along > 0.0 and along <= reach and (offset - dir * along).length() <= half_width + foe.radius:
				run.enemies.hit(foe, damage_of(data) * _power, push)
		return true
	var whirl: bool = variant == &"whirlwind"
	var half: float = -1.0 if whirl else cos(deg_to_rad(clampf(data.width, 0.0, 180.0)))
	if whirl:
		run.fx(&"spin_slash", DraftPixelFx.DEFAULT_FAMILY, here + Vector3.UP * 0.7, reach * 0.7)
	# Arc simple : aucun effet PixelFX. La feuille heavy_cleave (coup vertical planté dans le sol) donnait un slash
	# violet tourné vers le sol à chaque lancement ; l'arc de lame de l'animation d'attaque du Chasseur suffit.
	for foe: DraftEnemies.Foe in _level(run.enemies.near(here, reach), here):
		var offset: Vector3 = _flat(foe.pos - here)
		if offset.length() < foe.radius + 0.4 or offset.normalized().dot(dir) >= half:
			run.enemies.hit(foe, damage_of(data) * _power, offset.normalized() * push.length() if whirl else push)
	return true


## Lance prismatique : trait lourd vers la visée, qui traverse tout. Éventail : plusieurs lances en cône, plus faibles.
## Surcharge : la puissance de la charge multiplie les dégâts et grossit la lance.
func _lance(data: SpellData, aim: Vector3) -> bool:
	var origin: Vector3 = run.hunter.chest()
	var dir: Vector3 = _direction(aim)
	var count: int = 1
	var spread: float = 0.0
	var damage: float = damage_of(data) * _power
	if variant_of(data) == &"fan":
		count = int(param(data, "count", 3.0))
		spread = deg_to_rad(param(data, "angle", 15.0))
		damage *= param(data, "damage", 1.0)
	for i: int in count:
		var angle: float = spread * (i - (count - 1) * 0.5)
		run.fire_bolt(origin, dir.rotated(Vector3.UP, angle), damage, reach_of(data), 99, 0, &"ice_lance",
			1.1 * sqrt(_power), area_of(data) * sqrt(_power), tuning.lance_speed, &"reflets")
	return true


## Rupture : détonation de zone au point visé (portée limitée, arrêtée par le décor).
## Réaction : la détonation rebondit sur les ennemis visibles proches. Brasier : un sol ardent reste quelques secondes.
func _rupture(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = _landing(aim, reach_of(data))
	var radius: float = area_of(data)
	var damage: float = damage_of(data) * tuning.rupture_damage_mult * _power
	var struck: Array[DraftEnemies.Foe] = _detonate(at, radius, damage)
	match variant_of(data):
		&"reaction":
			var from: Vector3 = at
			for jump: int in int(param(data, "jumps", 2.0)):
				var next: DraftEnemies.Foe = null
				for foe: DraftEnemies.Foe in _level(run.enemies.near(from, param(data, "reach", 6.0)), from):
					if not struck.has(foe):
						next = foe
						break
				if next == null:
					break
				from = next.pos
				struck.append_array(_detonate(from, radius * param(data, "area", 0.6), damage * param(data, "damage", 0.5)))
		&"blaze":
			var zone := {"at": at, "radius": radius, "left": param(data, "duration", 3.0),
				"tick": param(data, "tick", 0.5), "clock": 0.0, "damage": damage * param(data, "damage", 0.15),
				"visual": run.fx(&"fire_ring", &"calcines", at + Vector3.UP * 0.3, radius, true)}
			_zones.append(zone)
	return true


func _detonate(at: Vector3, radius: float, damage: float) -> Array[DraftEnemies.Foe]:
	run.fx(&"dark_explosion", DraftPixelFx.DEFAULT_FAMILY, at + Vector3.UP * 0.6, radius)
	var foes: Array[DraftEnemies.Foe] = _level(run.enemies.near(at, radius), at)
	for foe: DraftEnemies.Foe in foes:
		run.enemies.hit(foe, damage)
	return foes


## Zone au sol qui frappe à intervalle régulier (Brasier, Pluie d'éclats) : {at, radius, left, tick, clock, damage,
## visual} et, au choix, follow (suit le Chasseur) et rain (éclats qui tombent à chaque coup).
func add_zone(zone: Dictionary) -> void:
	_zones.append(zone)


## Zones de Brasier et de Pluie : frappent ce qui s'y tient, à intervalle régulier.
func _step_zones(delta: float) -> void:
	for i: int in range(_zones.size() - 1, -1, -1):
		var zone: Dictionary = _zones[i]
		zone["left"] = float(zone["left"]) - delta
		zone["clock"] = float(zone["clock"]) + delta
		if zone.get("follow", false):
			zone["at"] = run.hunter.global_position
		if float(zone["clock"]) >= float(zone["tick"]):
			zone["clock"] = 0.0
			var at: Vector3 = zone["at"]
			var radius: float = zone["radius"]
			if zone.get("rain", false):
				var drop := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).limit_length(1.0) * radius
				run.fx(&"star_fall", DraftPixelFx.DEFAULT_FAMILY, at + drop + Vector3.UP * 0.8, 0.9)
			for foe: DraftEnemies.Foe in _level(run.enemies.near(at, radius), at):
				run.enemies.hit(foe, float(zone["damage"]))
		if float(zone["left"]) <= 0.0:
			DraftSpellWorld._free(zone)
			_zones.remove_at(i)


## Bond de Faille : saut jusqu'au point visé (arrêté par le décor), invulnérable, onde de choc à l'arrivée.
func _leap(data: SpellData, aim: Vector3) -> bool:
	var hunter: DraftHunter = run.hunter
	var landing: Vector3 = _landing(aim, reach_of(data))
	run.fx(&"blink_out", DraftPixelFx.DEFAULT_FAMILY, hunter.global_position + Vector3.UP * 0.6)
	if variant_of(data) == &"return":
		_return_point = hunter.global_position
		_return_spell = data.id
	_leap_spell = data
	_leap_power = _power
	hunter.leap_to(landing + Vector3.UP * 0.05, float(data.params.get("duration", 0.25)))
	return true


## Retour : pendant la fenêtre de la variante, la touche du Bond ramène au point de départ (sans onde).
func leap_back() -> bool:
	if _return_left <= 0.0 or run.hunter.is_leaping():
		return false
	_return_left = 0.0
	_leap_spell = null
	run.fx(&"blink_out", DraftPixelFx.DEFAULT_FAMILY, run.hunter.global_position + Vector3.UP * 0.6)
	run.hunter.leap_to(_return_point, 0.2)
	return true


func _on_landed() -> void:
	var data: SpellData = _leap_spell
	_leap_spell = null
	run.hunter.reset_motion()
	if data == null:
		return
	var landing: Vector3 = run.hunter.global_position
	var impact: bool = variant_of(data) == &"impact"
	if variant_of(data) == &"return":
		_return_left = param(data, "window", 3.0)
	var size: float = 2.0 * (param(data, "area", 1.0) if impact else 1.0)
	run.fx(&"ring_burst", DraftPixelFx.DEFAULT_FAMILY, landing + Vector3.UP * 0.4, size)
	for foe: DraftEnemies.Foe in _level(run.enemies.near(landing, area_of(data)), landing):
		run.enemies.hit(foe, damage_of(data) * _leap_power,
			_flat(foe.pos - landing).normalized() * data.knockback * DraftHunter.UNIT)
		if impact and foe.alive:
			foe.slow(param(data, "slow", 0.5), param(data, "duration", 2.0))


## Parade : garde courte ; un coup paré n'inflige rien, déclenche une contre-attaque autour du Chasseur (×counter),
## étourdit et remet la recharge à zéro. Garde longue : fenêtre plus longue. Miroir : les tirs ennemis proches
## repartent comme traits du Chasseur.
func _parry(data: SpellData) -> bool:
	var window: float = float(data.params.get("window", 0.4))
	if variant_of(data) == &"long_guard":
		window *= param(data, "window", 1.0)
	run.hunter.guard_left = window
	_parry_spell = data
	run.fx(&"shield_block", DraftPixelFx.DEFAULT_FAMILY, run.hunter.chest(), 1.2)
	return true


func _on_parried() -> void:
	var data: SpellData = _parry_spell
	if data == null:
		return
	var here: Vector3 = run.hunter.global_position
	run.fx(&"spin_slash", DraftPixelFx.DEFAULT_FAMILY, here + Vector3.UP * 0.7, area_of(data) * 0.8)
	for foe: DraftEnemies.Foe in _level(run.enemies.near(here, area_of(data)), here):
		run.enemies.hit(foe, damage_of(data) * float(data.params.get("counter", 1.0)),
			_flat(foe.pos - here).normalized() * data.knockback * DraftHunter.UNIT)
		if foe.alive and foe.boss == null:
			foe.slow(0.0, tuning.parry_stun)
	if variant_of(data) == &"mirror":
		for i: int in range(run.hostile.size() - 1, -1, -1):
			var shot: Dictionary = run.hostile[i]
			if (shot["at"] as Vector3).distance_to(run.hunter.chest()) <= param(data, "reach", 4.0):
				run.fire_bolt(shot["at"], -(shot["dir"] as Vector3), damage_of(data), 12.0, 1, 0)
				(shot["visual"] as Node).queue_free()
				run.hostile.remove_at(i)
	var slot: int = slot_of(data.id)
	if slot >= 0:
		cooldowns[slot] = 0.0


## Singularité : puits au point visé qui attire les ennemis puis implose. Horizon : rayon plus grand.
## Effondrement : implosion plus forte, plus tôt.
func _singularity(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = _landing(aim, reach_of(data))
	var duration: float = duration_of(data)
	var damage: float = damage_of(data) * _power
	if variant_of(data) == &"collapse":
		duration *= param(data, "duration", 1.0)
		damage *= param(data, "damage", 1.0)
	world.add_well(at, area_of(data), duration,
		float(data.params.get("pull", 0.0)) * DraftHunter.UNIT * tuning.singularity_pull_scale, damage)
	return true


## Mur de faille : mur au point visé, perpendiculaire à la visée, qui arrête les ennemis et leurs tirs.
## Chaînes : les ennemis qui le touchent sont immobilisés. Rempart ardent : le toucher brûle.
func _wall(data: SpellData, aim: Vector3) -> bool:
	var dir: Vector3 = _direction(aim)
	var at: Vector3 = _landing(aim, reach_of(data))
	var root: float = param(data, "root", 0.0) if variant_of(data) == &"chains" else 0.0
	var burn: float = scaled(data, param(data, "damage", 0.0)) if variant_of(data) == &"burning" else 0.0
	world.add_wall(at, Vector3(-dir.z, 0, dir.x), area_of(data), duration_of(data), root, burn, param(data, "tick", 0.5))
	return true


## Égide de faille : bouclier d'une part des PV max. Riposte : onde de choc quand il cède. Second souffle : bouclier
## réduit mais soin immédiat.
func _aegis(data: SpellData) -> bool:
	var hunter: DraftHunter = run.hunter
	var amount: float = hunter.max_hp() * data.width * (1.0 + bonus(data, &"area"))
	if variant_of(data) == &"second_wind":
		amount *= param(data, "shield", 1.0)
		hunter.heal(hunter.max_hp() * param(data, "heal", 0.0))
	hunter.shield = amount
	hunter.shield_left = duration_of(data)
	_aegis_spell = data
	run.fx(&"shield_block", &"reflets", hunter.chest(), 1.6)
	return true


func _on_shield_broken() -> void:
	var data: SpellData = _aegis_spell
	if data == null or variant_of(data) != &"riposte":
		return
	var here: Vector3 = run.hunter.global_position
	run.fx(&"ring_burst", DraftPixelFx.DEFAULT_FAMILY, here + Vector3.UP * 0.4, area_of(data))
	for foe: DraftEnemies.Foe in _level(run.enemies.near(here, area_of(data)), here):
		run.enemies.hit(foe, damage_of(data) * param(data, "damage", 1.0),
			_flat(foe.pos - here).normalized() * 4.0)


## Cristal réfracteur : cristal au point visé ; les traits qui le traversent se divisent. Prisme double : deux
## cristaux côte à côte. Foyer : les éclats filent vers l'ennemi le plus résistant.
func _crystal(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = _landing(aim, reach_of(data))
	var count: int = int(param(data, "count", 1.0)) if variant_of(data) == &"double" else 1
	var side: Vector3 = _direction(aim).rotated(Vector3.UP, PI * 0.5) * param(data, "gap", 0.0)
	for i: int in count:
		var offset: Vector3 = side * (i - (count - 1) * 0.5)
		world.add_crystal(run.level.closest(at + offset), area_of(data), duration_of(data), variant_of(data) == &"focus")
	return true


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
	var shown: int = preview_slot if preview_slot >= 0 else charge_slot
	if shown >= 0 and slots[shown] != null:
		var data: SpellData = slots[shown]
		color = Color(data.color, 0.7)
		match data.spell_kind:
			&"slash":
				at = here
				radius = reach_of(data)
			&"rupture", &"leap", &"singularity", &"crystal":
				at = here + _flat(aim - here).limit_length(reach_of(data))
				radius = area_of(data)
			&"wall":
				at = here + _flat(aim - here).limit_length(reach_of(data))
				radius = area_of(data) * 0.5
			&"parry", &"aegis", &"veil":
				at = here
				radius = area_of(data)
			&"stasis":
				at = here
				radius = reach_of(data)
			&"mark", &"shard_rain", &"blink", &"rend":
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
