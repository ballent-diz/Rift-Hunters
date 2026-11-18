class_name DraftSpells
extends RefCounted
## Sorts actifs du Chasseur dans la base 3D (docs/design/SORTS_ACTIFS_V2.md). Quatre emplacements, lancés par les
## actions reconfigurables `spell_1` à `spell_4` (InputSetup : flèches au clavier seul, A E R F + clic avec la souris).
## Visée : curseur projeté sur le sol (souris), stick droit (manette) ou, au clavier seul, l'ennemi visible le plus
## proche devant le Chasseur. Données d'origine (`SpellData` : dégâts, recharge, portée, largeur) ; réglages propres
## à la 3D dans `DraftTuning` (groupe « Sorts »). Sorts de départ : ceux équipés dans l'arbre du profil (lecture
## seule), sinon ceux de l'équilibrage ; les autres s'apprennent pendant la partie (cartes `DraftSpellEffect`).
## Le bot (`auto_cast`) lance ses sorts seul quand ils sont utiles.

## Emplacements de départ, et maximum avec la récompense légendaire (5e emplacement jusqu'à la fin de l'expédition).
const SLOTS := 4
const MAX_SLOTS := 5
## Mutations au plus par sort (docs/design/GAMEPLAY_COMBOS_2P5D.md).
const MAX_MUTATIONS := 2
const ACTIONS: Array[StringName] = [&"spell_1", &"spell_2", &"spell_3", &"spell_4", &"spell_5"]
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
## Sort par emplacement (null : emplacement libre) et recharge restante de chaque emplacement équipé.
var slots: Array[SpellData] = []
var cooldowns := PackedFloat32Array()
## Arsenal de l'expédition (docs/design/GAMEPLAY_V2_ARCHITECTURE.md) : sorts possédés dans l'ordre d'acquisition
## (équipés et réserve) et recharges des sorts en réserve, par identifiant. Une recharge suit toujours son sort :
## un échange ne la remet jamais à zéro.
var owned: Array[StringName] = []
var reserve_cooldowns: Dictionary = {}
## Noms (clés de traduction) des mutations prises par sort, pour l'arsenal.
var mutation_labels: Dictionary = {}
## Sorts équipés dans le profil mais pas encore raccordés à la 3D.
var skipped: Array[StringName] = []
var casts: int = 0
## Lancement automatique (bot et vérifications) : aucune touche lue.
var auto_cast: bool = false
## Emplacement en aperçu (option « aperçu » : maintenir montre la zone, relâcher lance), -1 sinon.
var preview_slot: int = -1
## Anneau de visée au sol (draft3d/spell_reticle.gd).
var reticle: MeshInstance3D
## Objets posés par les sorts (puits, murs, cristaux).
var world: DraftSpellWorld
## Sorts propres à la v2 (marque, fente, pas, stase, pluie, voile).
var rift: DraftRiftSpells
## Animations peintes de la v1 jouées au sol (draft3d/spell_vfx.gd).
var vfx: DraftSpellVfx
## Mutations par sort (identifiant → liste, 2 au plus), leurs réglages et leurs incompatibilités (identifiant →
## {mutation → réglages / mutations incompatibles}) ; rangs pris par sort et statistique.
var variants: Dictionary = {}
var variant_params: Dictionary = {}
var variant_incompatible: Dictionary = {}
## Mutation à remplacer par la prochaine carte de mutation (choix explicite du joueur), &"" s'il reste une case.
var mutation_to_replace: StringName = &""
## Clé de nom de chaque mutation (arsenal).
var mutation_label_of: Dictionary = {}
var bonuses: Dictionary = {}
## Surcharge : emplacement en charge (-1 sinon) et durée de charge.
var charge_slot: int = -1
var charge_time: float = 0.0
## Derniers sorts de Parade et d'Égide lancés (contre-attaque, Riposte).
var _parry_spell: SpellData
var _aegis_spell: SpellData
var _parry_drawn: Node2D
## Bond en cours : sort et puissance appliqués à l'atterrissage.
var _leap_spell: SpellData
var _leap_power: float = 1.0
## Retour (variante du Bond) : point de départ, sort et fenêtre restante.
var _return_point := Vector3.ZERO
var _return_spell: StringName = &""
var _return_left: float = 0.0
## Repère du point de retour, affiché pendant la fenêtre (le dessin peint du Retour ne dure que l'animation du saut).
var _return_marker: Node3D
## Puissance du lancement en cours (Surcharge) et zones de Brasier.
var _power: float = 1.0
var _zones: Array[Dictionary] = []


## 5e emplacement (récompense légendaire) : action `spell_5` créée par la v2 sans toucher aux actions partagées avec la
## v1 (InputSetup). Touches : Entrée (clavier seul, près des flèches), G (avec la souris), croix bas à la manette.
static func ensure_actions() -> void:
	if InputMap.has_action(&"spell_5"):
		return
	InputMap.add_action(&"spell_5", 0.2)
	for keycode: Key in [KEY_ENTER, KEY_G]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		InputMap.action_add_event(&"spell_5", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_DOWN
	InputMap.action_add_event(&"spell_5", pad)


func setup(p_run: DraftRun, ids: Array[StringName]) -> void:
	ensure_actions()
	run = p_run
	tuning = run.tuning
	slots.resize(SLOTS)
	slots.fill(null)
	cooldowns.resize(SLOTS)
	cooldowns.fill(0.0)
	for id: StringName in ids:
		if not learn(id):
			skipped.append(id)
	for i: int in slots.size():
		cooldowns[i] = 1.0 + i if slots[i] != null else 0.0
	run.hunter.landed.connect(_on_landed)
	run.hunter.parried.connect(_on_parried)
	run.hunter.shield_broken.connect(_on_shield_broken)
	world = DraftSpellWorld.new(self)
	rift = DraftRiftSpells.new(self)
	vfx = DraftSpellVfx.new(run)
	reticle = DraftSpellReticle.new()
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
	for i: int in slots.size():
		if slots[i] != null and slots[i].id == id:
			return i
	return -1


func has_spell(id: StringName) -> bool:
	return slot_of(id) >= 0


func free_slots() -> int:
	return slots.count(null)


## Sort possédé pendant l'expédition (équipé ou en réserve).
func owns(id: StringName) -> bool:
	return owned.has(id)


## Sorts possédés mais non équipés, dans l'ordre d'acquisition (consultables et rééquipables depuis la pause).
func reserve() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in owned:
		if not has_spell(id):
			result.append(id)
	return result


func mutation_names(id: StringName) -> Array[String]:
	var result: Array[String] = []
	result.assign(mutation_labels.get(id, []))
	return result


## Recharge restante d'un sort possédé, où qu'il soit (case ou réserve).
func cooldown_left(id: StringName) -> float:
	var slot: int = slot_of(id)
	return cooldowns[slot] if slot >= 0 else float(reserve_cooldowns.get(id, 0.0))


## Acquiert un sort pour l'expédition : équipé dans le premier emplacement libre, sinon gardé en réserve (le choix de
## la case à remplacer revient alors au joueur, `equip`). Faux si inconnu, non raccordé ou déjà possédé.
func learn(id: StringName) -> bool:
	if not supported(id) or owns(id):
		return false
	owned.append(id)
	reserve_cooldowns[id] = tuning.learned_cooldown
	var index: int = slots.find(null)
	if index >= 0:
		equip(id, index)
	return true


## Équipe un sort possédé dans la case `slot`. Le sort qui l'occupait part en réserve avec sa recharge ; un sort déjà
## équipé ailleurs échange sa place. Aucune recharge n'est remise à zéro, aucun sort n'est dupliqué.
func equip(id: StringName, slot: int) -> bool:
	if not owns(id) or slot < 0 or slot >= slots.size():
		return false
	_settle_slot(slot)
	var from: int = slot_of(id)
	if from == slot:
		return true
	if from >= 0:
		_settle_slot(from)
		var other: SpellData = slots[slot]
		var other_cooldown: float = cooldowns[slot]
		slots[slot] = slots[from]
		cooldowns[slot] = cooldowns[from]
		slots[from] = other
		cooldowns[from] = other_cooldown
		return true
	var previous: SpellData = slots[slot]
	if previous != null:
		reserve_cooldowns[previous.id] = cooldowns[slot]
	slots[slot] = spell(id)
	cooldowns[slot] = float(reserve_cooldowns.get(id, 0.0))
	reserve_cooldowns.erase(id)
	return true


## Range en réserve le sort de la case `slot` (avec sa recharge).
func stash(slot: int) -> bool:
	if slot < 0 or slot >= slots.size() or slots[slot] == null:
		return false
	_settle_slot(slot)
	reserve_cooldowns[slots[slot].id] = cooldowns[slot]
	slots[slot] = null
	cooldowns[slot] = 0.0
	return true


## Ajoute un emplacement (récompense légendaire, une fois, jusqu'à la fin de l'expédition). Faux au maximum.
func add_slot() -> bool:
	if slots.size() >= MAX_SLOTS:
		return false
	slots.append(null)
	cooldowns.append(0.0)
	return true


## Avant de déplacer un sort : charge, aperçu ou seconde fente en cours sur cette case se terminent proprement.
func _settle_slot(slot: int) -> void:
	if charge_slot == slot:
		charge_slot = -1
	if preview_slot == slot:
		preview_slot = -1
	if rift != null:
		rift.settle_slot(slot)


## Une carte de sort servirait-elle maintenant ?
func can_apply(effect: DraftSpellEffect) -> bool:
	if effect == null:
		return false
	match effect.kind:
		DraftSpellEffect.Kind.LEARN:
			return supported(effect.spell_id) and not owns(effect.spell_id)
		DraftSpellEffect.Kind.VARIANT:
			return owns(effect.spell_id) and not mutations(effect.spell_id).has(effect.variant) \
				and not replaceable_mutations(effect).is_empty()
		DraftSpellEffect.Kind.MODIFY:
			return owns(effect.spell_id)
	return false


func apply_effect(effect: DraftSpellEffect) -> void:
	match effect.kind:
		DraftSpellEffect.Kind.LEARN:
			learn(effect.spell_id)
		DraftSpellEffect.Kind.VARIANT:
			add_mutation(effect, mutation_to_replace)
			mutation_to_replace = &""
		DraftSpellEffect.Kind.MODIFY:
			var stats: Dictionary = bonuses.get(effect.spell_id, {})
			stats[effect.stat] = float(stats.get(effect.stat, 0.0)) + effect.pct
			bonuses[effect.spell_id] = stats


## Mutations prises sur un sort (2 au plus), dans l'ordre d'obtention.
func mutations(id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(variants.get(id, []))
	return result


func has_variant(data: SpellData, variant: StringName) -> bool:
	return data != null and (variants.get(data.id, []) as Array).has(variant)


## Mutation dont l'animation peinte est jouée (la plus prioritaire des deux, quel que soit l'ordre d'obtention ;
## l'autre a sa couche ou son effet événementiel), &"" sans mutation.
func variant_of(data: SpellData) -> StringName:
	return DraftSpellVfx.painted_variant(data.spell_kind, mutations(data.id))


## Mutations qu'une nouvelle mutation peut prendre : [&""] s'il reste une case et qu'elle est compatible avec celles
## déjà prises ; sinon celles qu'elle peut remplacer (une incompatible doit partir) ; vide si elle ne peut pas entrer.
func replaceable_mutations(effect: DraftSpellEffect) -> Array[StringName]:
	var current: Array[StringName] = mutations(effect.spell_id)
	var clashing: Array[StringName] = []
	for taken: StringName in current:
		if _incompatible(effect.spell_id, taken, effect):
			clashing.append(taken)
	if clashing.size() > 1:
		return []
	if clashing.size() == 1:
		return clashing
	if current.size() < MAX_MUTATIONS:
		return [&""] as Array[StringName]
	return current


func _incompatible(id: StringName, taken: StringName, effect: DraftSpellEffect) -> bool:
	var other: Array = (variant_incompatible.get(id, {}) as Dictionary).get(taken, [])
	return effect.incompatible.has(taken) or other.has(effect.variant)


## Ajoute une mutation ; `replace` : mutation retirée à sa place (choix explicite du joueur). Faux si impossible
## (jamais de troisième mutation, jamais d'écrasement silencieux, jamais deux mutations incompatibles).
func add_mutation(effect: DraftSpellEffect, replace: StringName = &"") -> bool:
	var allowed: Array[StringName] = replaceable_mutations(effect)
	if not owns(effect.spell_id) or mutations(effect.spell_id).has(effect.variant) or not allowed.has(replace):
		return false
	var id: StringName = effect.spell_id
	var list: Array = variants.get(id, [])
	var params: Dictionary = variant_params.get(id, {})
	var blocked: Dictionary = variant_incompatible.get(id, {})
	if replace != &"":
		list.erase(replace)
		params.erase(replace)
		blocked.erase(replace)
	list.append(effect.variant)
	params[effect.variant] = effect.params
	blocked[effect.variant] = effect.incompatible
	variants[id] = list
	variant_params[id] = params
	variant_incompatible[id] = blocked
	return true


## Réglage `key` des mutations du sort (chaque clé n'appartient qu'à une mutation d'un même sort).
func param(data: SpellData, key: String, fallback: float) -> float:
	for variant: StringName in mutations(data.id):
		var params: Dictionary = (variant_params.get(data.id, {}) as Dictionary).get(variant, {})
		if params.has(key):
			return float(params[key])
	return fallback


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
			if has_variant(data, &"thrust"):
				reach = param(data, "range", data.spell_range) * DraftHunter.UNIT
			elif has_variant(data, &"whirlwind"):
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
			if has_variant(data, &"thrust"):
				area = param(data, "half_width", data.width) * DraftHunter.UNIT
		&"lance":
			area = maxf(data.width * DraftHunter.UNIT, 0.3)
		&"leap":
			area = data.width * DraftHunter.UNIT * (param(data, "area", 1.0) if has_variant(data, &"impact") else 1.0)
		&"singularity":
			area *= param(data, "area", 1.0) if has_variant(data, &"horizon") else 1.0
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
	for i: int in slots.size():
		cooldowns[i] = maxf(cooldowns[i] - delta, 0.0)
	for id: StringName in reserve_cooldowns:
		reserve_cooldowns[id] = maxf(float(reserve_cooldowns[id]) - delta, 0.0)
	_step_zones(delta)
	world.step(delta)
	rift.step(delta)
	vfx.step()
	_return_left = maxf(_return_left - delta, 0.0)
	if _return_left <= 0.0:
		_clear_return_marker()
	var hunter: DraftHunter = run.hunter
	if not hunter.alive or not hunter.active:
		preview_slot = -1
		charge_slot = -1
		reticle.visible = false
		return
	if auto_cast:
		reticle.visible = false
		for i: int in slots.size():
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
	for i: int in slots.size():
		if slots[i] == null:
			continue
		var pressed: bool = Input.is_action_just_pressed(ACTIONS[i])
		if pressed and _return_left > 0.0 and slots[i].id == _return_spell:
			leap_back()
		elif has_variant(slots[i], &"overcharge"):
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
	(reticle as DraftSpellReticle).show_for(self)


## Surcharge : puissance selon la durée de charge (×1 jusqu'au maximum de la variante).
func charge_power(data: SpellData) -> float:
	return lerpf(1.0, param(data, "max", 1.0), clampf(charge_time / maxf(param(data, "time", 1.0), 0.05), 0.0, 1.0))


## Sort prêt : recharge finie, ou charge disponible (Deux charges).
func ready(slot: int) -> bool:
	return slots[slot] != null and (cooldowns[slot] <= 0.0 or rift.has_charge(slots[slot]))


## Lance le sort de l'emplacement vers `aim` (point du sol), avec un multiplicateur de dégâts `power` (Surcharge).
## Faux si vide, en recharge ou pendant un Bond.
func cast(slot: int, aim: Vector3, power: float = 1.0) -> bool:
	var data: SpellData = slots[slot] if slot >= 0 and slot < slots.size() else null
	if data == null or not ready(slot) or run.hunter.is_leaping() or not run.hunter.alive:
		return false
	# Contre-taille (passif) : le sort qui suit une esquive pendant la Ruée part renforcé.
	var boost: float = run.passives.power() if run.passives != null else 1.0
	_power = power * boost
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
		if run.passives != null and boost > 1.0:
			run.passives.consume()
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
	var thrust: bool = has_variant(data, &"thrust")
	var push: Vector3 = dir * data.knockback * DraftHunter.UNIT * 3.0
	var drawn: Node2D = _anim("cleaving_slash", here, dir, data, reach, {"spell_range": reach / DraftHunter.UNIT,
		"thrust_range": reach / DraftHunter.UNIT, "half_angle_degrees": data.width}, false, 0.3,
		DraftSpellVfx.SLASH_CUT_PHASE)
	if thrust:
		var half_width: float = area_of(data)
		if drawn == null:
			run.fx(&"arcane_beam", DraftPixelFx.DEFAULT_FAMILY, here + dir * reach * 0.5 + Vector3.UP * 0.7, reach * 0.4)
		for foe: DraftEnemies.Foe in _level(run.enemies.near(here, reach), here):
			var offset: Vector3 = _flat(foe.pos - here)
			var along: float = offset.dot(dir)
			if along > 0.0 and along <= reach and (offset - dir * along).length() <= half_width + foe.radius:
				run.enemies.hit(foe, damage_of(data) * _power, push)
		run.combos.on_slash(here, dir, reach, cos(atan2(half_width, reach)), damage_of(data) * _power)
		return true
	var whirl: bool = has_variant(data, &"whirlwind")
	var half: float = -1.0 if whirl else cos(deg_to_rad(clampf(data.width, 0.0, 180.0)))
	if drawn != null:
		pass
	elif whirl:
		run.fx(&"spin_slash", &"calcines", here + Vector3.UP * 0.7, reach * 0.7)
	# Arc simple : aucun effet PixelFX. La feuille heavy_cleave (coup vertical planté dans le sol) donnait un slash
	# violet tourné vers le sol à chaque lancement ; l'arc de lame de l'animation d'attaque du Chasseur suffit.
	for foe: DraftEnemies.Foe in _level(run.enemies.near(here, reach), here):
		var offset: Vector3 = _flat(foe.pos - here)
		if offset.length() < foe.radius + 0.4 or offset.normalized().dot(dir) >= half:
			run.enemies.hit(foe, damage_of(data) * _power, offset.normalized() * push.length() if whirl else push)
	run.combos.on_slash(here, dir, reach, half, damage_of(data) * _power)
	return true


## Lance prismatique : trait lourd vers la visée, qui traverse tout. Éventail : plusieurs lances en cône, plus faibles.
## Surcharge : la puissance de la charge multiplie les dégâts et grossit la lance.
func _lance(data: SpellData, aim: Vector3) -> bool:
	var origin: Vector3 = run.hunter.chest()
	var dir: Vector3 = _direction(aim)
	var count: int = 1
	var spread: float = 0.0
	var damage: float = damage_of(data) * _power
	if has_variant(data, &"fan"):
		count = int(param(data, "count", 3.0))
		spread = deg_to_rad(param(data, "angle", 15.0))
		damage *= param(data, "damage", 1.0)
	# Animation de la v1 : elle dessine la lance ; les traits de jeu deviennent invisibles (comme en v1).
	var drawn: Node2D = _anim("prismatic_lance", run.hunter.global_position, dir, data, reach_of(data), {
		"spell_range": reach_of(data) / DraftHunter.UNIT, "projectile_speed": tuning.lance_speed / DraftHunter.UNIT,
		"half_width": area_of(data) * sqrt(_power) / DraftHunter.UNIT, "fan_angle_degrees": rad_to_deg(spread)},
		false, 0.75)
	for i: int in count:
		var angle: float = spread * (i - (count - 1) * 0.5)
		var shot: Dictionary = run.fire_bolt(origin, dir.rotated(Vector3.UP, angle), damage, reach_of(data), 99, 0,
			&"" if drawn != null else &"ice_lance", 1.1 * sqrt(_power), area_of(data) * sqrt(_power), tuning.lance_speed,
			&"reflets")
		shot["lance"] = true
	return true


## Rupture : détonation de zone au point visé (portée limitée, arrêtée par le décor).
## Réaction : la détonation rebondit sur les ennemis visibles proches. Brasier : un sol ardent reste quelques secondes.
func _rupture(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = _landing(aim, reach_of(data))
	var radius: float = area_of(data)
	var damage: float = damage_of(data) * tuning.rupture_damage_mult * _power
	var struck: Array[DraftEnemies.Foe] = _detonate(at, radius, damage, data)
	if has_variant(data, &"reaction"):
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
			struck.append_array(_detonate(from, radius * param(data, "area", 0.6), damage * param(data, "damage", 0.5),
				null))
	run.combos.on_rupture(struck, damage)
	if has_variant(data, &"blaze"):
		var zone := {"at": at, "radius": radius, "left": param(data, "duration", 3.0),
			"tick": param(data, "tick", 0.5), "clock": 0.0, "damage": damage * param(data, "burn", 0.15),
			"visual": null if DraftSpellVfx.scene("rupture") != null
				else run.fx(&"fire_ring", &"calcines", at + Vector3.UP * 0.3, radius, true)}
		_zones.append(zone)
	return true


## Détonation de Rupture ; `data` : sort dont l'animation porte la variante (null : rebond de Réaction, version de base).
func _detonate(at: Vector3, radius: float, damage: float, data: SpellData) -> Array[DraftEnemies.Foe]:
	if _anim("rupture", at, Vector3.RIGHT, data, radius, {"spell_range": radius / DraftHunter.UNIT}) == null:
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
			var visual: Variant = zone.get("visual")
			if visual is DraftPixelFx and is_instance_valid(visual):
				(visual as DraftPixelFx).place(run.hunter.global_position + Vector3.UP * 0.3)
			elif visual is Node3D and is_instance_valid(visual):
				(visual as Node3D).position = run.hunter.global_position + Vector3.UP * 0.3
		if float(zone["clock"]) >= float(zone["tick"]):
			zone["clock"] = 0.0
			var at: Vector3 = zone["at"]
			var radius: float = zone["radius"]
			if zone.get("rain", false):
				var drop := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).limit_length(1.0) * radius
				if StringName(zone.get("drop_fx", &"")) != &"":
					run.fx_or(zone["drop_fx"], 1.6, &"star_fall", DraftPixelFx.DEFAULT_FAMILY, at + drop + Vector3.UP * 0.8,
						0.9)
				else:
					run.fx(&"star_fall", DraftPixelFx.DEFAULT_FAMILY, at + drop + Vector3.UP * 0.8, 0.9)
			for foe: DraftEnemies.Foe in _level(run.enemies.near(at, radius), at):
				run.enemies.hit(foe, float(zone["damage"]))
			if zone.get("rain", false):
				run.combos.on_rain_tick(at, radius, float(zone["damage"]))
		if float(zone["left"]) <= 0.0:
			DraftSpellWorld._free(zone)
			_zones.remove_at(i)


## Bond de Faille : saut jusqu'au point visé (arrêté par le décor), invulnérable, onde de choc à l'arrivée.
func _leap(data: SpellData, aim: Vector3) -> bool:
	var hunter: DraftHunter = run.hunter
	var landing: Vector3 = _landing(aim, reach_of(data))
	var jump: Vector3 = _flat(landing - hunter.global_position)
	if _anim("rift_leap", hunter.global_position, jump, data, jump.length() + 2.0,
			{"destination_offset": Vector2(jump.length() / DraftHunter.UNIT, 0.0)}) == null:
		run.fx(&"blink_out", DraftPixelFx.DEFAULT_FAMILY, hunter.global_position + Vector3.UP * 0.6)
	if has_variant(data, &"return"):
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
	_clear_return_marker()
	_leap_spell = null
	var back: Vector3 = _flat(_return_point - run.hunter.global_position)
	var leaped: SpellData = spell(_return_spell)
	if _anim("rift_leap", run.hunter.global_position, back, leaped, back.length() + 2.0,
			{"destination_offset": Vector2(back.length() / DraftHunter.UNIT, 0.0)}) == null:
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
	var impact: bool = has_variant(data, &"impact")
	if has_variant(data, &"return"):
		_return_left = param(data, "window", 3.0)
		_show_return_marker()
	var size: float = 2.0 * (param(data, "area", 1.0) if impact else 1.0)
	if DraftSpellVfx.scene("rift_leap") == null:
		run.fx(&"ring_burst", DraftPixelFx.DEFAULT_FAMILY, landing + Vector3.UP * 0.4, size)
	for foe: DraftEnemies.Foe in _level(run.enemies.near(landing, area_of(data)), landing):
		run.enemies.hit(foe, damage_of(data) * _leap_power,
			_flat(foe.pos - landing).normalized() * data.knockback * DraftHunter.UNIT)
		if impact and foe.alive:
			foe.slow(param(data, "slow", 0.5), param(data, "duration", 2.0))
	run.combos.on_landed(landing, damage_of(data) * _leap_power)


## Retour : portail au point de départ tant que la touche du Bond peut y ramener (sous les zones annoncées).
func _show_return_marker() -> void:
	_clear_return_marker()
	var marker: Sprite3D = run.fx(&"portal", &"riftborn", _return_point + Vector3.UP * 0.5, 0.7, true)
	marker.render_priority = DraftPixelFx.UNDER_TELEGRAPHS
	_return_marker = marker


func _clear_return_marker() -> void:
	if _return_marker != null and is_instance_valid(_return_marker):
		_return_marker.queue_free()
	_return_marker = null


## Parade : garde courte ; un coup paré n'inflige rien, déclenche une contre-attaque autour du Chasseur (×counter),
## étourdit et remet la recharge à zéro. Garde longue : fenêtre plus longue. Miroir : les tirs ennemis proches
## repartent comme traits du Chasseur.
func _parry(data: SpellData) -> bool:
	var window: float = float(data.params.get("window", 0.4))
	if has_variant(data, &"long_guard"):
		window *= param(data, "window", 1.0)
	run.hunter.guard_left = window
	_parry_spell = data
	_parry_drawn = _anim("parry", run.hunter.global_position, run.hunter.facing, data, area_of(data), {}, true, 0.3)
	if _parry_drawn == null:
		run.fx(&"shield_block", &"fallen", run.hunter.chest(), 1.2)
	return true


func _on_parried() -> void:
	var data: SpellData = _parry_spell
	if data == null:
		return
	var here: Vector3 = run.hunter.global_position
	if _parry_drawn != null and is_instance_valid(_parry_drawn):
		_parry_drawn.call("trigger_pulse", Vector2(40, 0), Vector2.RIGHT)
	else:
		run.fx(&"spin_slash", &"calcines", here + Vector3.UP * 0.7, area_of(data) * 0.8)
	for foe: DraftEnemies.Foe in _level(run.enemies.near(here, area_of(data)), here):
		run.enemies.hit(foe, damage_of(data) * float(data.params.get("counter", 1.0)),
			_flat(foe.pos - here).normalized() * data.knockback * DraftHunter.UNIT)
		if foe.alive and foe.boss == null:
			foe.slow(0.0, tuning.parry_stun)
	if has_variant(data, &"mirror"):
		for i: int in range(run.hostile.size() - 1, -1, -1):
			var shot: Dictionary = run.hostile[i]
			if (shot["at"] as Vector3).distance_to(run.hunter.chest()) <= param(data, "reach", 4.0):
				run.fire_bolt(shot["at"], -(shot["dir"] as Vector3), damage_of(data), 12.0, 1, 0)
				(shot["visual"] as Node).queue_free()
				run.hostile.remove_at(i)
	var slot: int = slot_of(data.id)
	if slot >= 0:
		cooldowns[slot] = 0.0
	run.combos.on_parried()


## Singularité : puits au point visé qui attire les ennemis puis implose. Horizon : rayon plus grand.
## Effondrement : implosion plus forte, plus tôt.
func _singularity(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = _landing(aim, reach_of(data))
	var duration: float = duration_of(data)
	var damage: float = damage_of(data) * _power
	if has_variant(data, &"collapse"):
		duration *= param(data, "duration", 1.0)
		damage *= param(data, "damage", 1.0)
	var drawn: Node2D = _anim("singularity", at, Vector3.RIGHT, data, area_of(data) * 1.6, {
		"spell_range": area_of(data) / DraftHunter.UNIT, "active_duration": duration})
	world.add_well(at, area_of(data), duration,
		float(data.params.get("pull", 0.0)) * DraftHunter.UNIT * tuning.singularity_pull_scale, damage, drawn != null)
	return true


## Mur de faille : mur au point visé, perpendiculaire à la visée, qui arrête les ennemis et leurs tirs.
## Chaînes : les ennemis qui le touchent sont immobilisés. Rempart ardent : le toucher brûle.
func _wall(data: SpellData, aim: Vector3) -> bool:
	var dir: Vector3 = _direction(aim)
	var at: Vector3 = _landing(aim, reach_of(data))
	var root: float = param(data, "root", 0.0) if has_variant(data, &"chains") else 0.0
	var burn: float = scaled(data, param(data, "damage", 0.0)) if has_variant(data, &"burning") else 0.0
	var drawn: Node2D = _anim("rift_wall", at, dir, data, area_of(data) * 0.6, {
		"spell_range": area_of(data) / DraftHunter.UNIT, "active_duration": duration_of(data)})
	world.add_wall(at, Vector3(-dir.z, 0, dir.x), area_of(data), duration_of(data), root, burn, param(data, "tick", 0.5),
		drawn != null)
	return true


## Égide de faille : bouclier d'une part des PV max. Riposte : onde de choc quand il cède. Second souffle : bouclier
## réduit mais soin immédiat.
func _aegis(data: SpellData) -> bool:
	var hunter: DraftHunter = run.hunter
	var amount: float = hunter.max_hp() * data.width * (1.0 + bonus(data, &"area"))
	if has_variant(data, &"second_wind"):
		amount *= param(data, "shield", 1.0)
		hunter.heal(hunter.max_hp() * param(data, "heal", 0.0))
		# Soin immédiat visible (le dessin peint ne montre que le bouclier réduit).
		run.fx(&"healing_bloom", &"enlises", hunter.chest(), 1.2)
	hunter.shield = amount
	hunter.shield_left = duration_of(data)
	_aegis_spell = data
	if _anim("rift_aegis", hunter.global_position, hunter.facing, data, 2.5, {"active_duration": duration_of(data)},
			true, 0.1) == null:
		run.fx(&"shield_block", &"fallen", hunter.chest(), 1.6)
	return true


## Égide vengeresse (combo) : riposte renforcée, ou onde de base sans la mutation.
func _on_shield_broken() -> void:
	var data: SpellData = _aegis_spell
	if data == null:
		return
	var riposte: bool = has_variant(data, &"riposte")
	var power: float = run.combos.riposte_power()
	if not riposte and power <= 1.0:
		return
	var damage: float = damage_of(data) * (param(data, "damage", 1.0) if riposte else tuning.combo_aegis_plain) * power
	var here: Vector3 = run.hunter.global_position
	if power > 1.0:
		run.fx_or(&"combo_avenging_aegis", area_of(data) * 2.0, &"ring_burst",
			DraftPixelFx.DEFAULT_FAMILY, here + Vector3.UP * 0.4, area_of(data))
	else:
		run.fx(&"ring_burst", DraftPixelFx.DEFAULT_FAMILY, here + Vector3.UP * 0.4, area_of(data))
	for foe: DraftEnemies.Foe in _level(run.enemies.near(here, area_of(data)), here):
		run.enemies.hit(foe, damage, _flat(foe.pos - here).normalized() * 4.0)


## Cristal réfracteur : cristal au point visé ; les traits qui le traversent se divisent. Prisme double : deux
## cristaux côte à côte. Foyer : les éclats filent vers l'ennemi le plus résistant.
func _crystal(data: SpellData, aim: Vector3) -> bool:
	var at: Vector3 = _landing(aim, reach_of(data))
	var count: int = int(param(data, "count", 1.0)) if has_variant(data, &"double") else 1
	var side: Vector3 = _direction(aim).rotated(Vector3.UP, PI * 0.5) * param(data, "gap", 0.0)
	for i: int in count:
		var offset: Vector3 = side * (i - (count - 1) * 0.5)
		var spot: Vector3 = run.level.closest(at + offset)
		var drawn: Node2D = _anim("refractor_crystal", spot, _direction(aim), data, 2.0,
			{"active_duration": duration_of(data)})
		world.add_crystal(spot, area_of(data), duration_of(data), has_variant(data, &"focus"), drawn != null)
	return true


# --- Outils -------------------------------------------------------------------------------------------------------

## Animation peinte v1 `effect_id` au sol en `at`, orientée selon `dir`, variante du sort, propriétés `props` (unités
## v1) ; `extent` : rayon du dessin (m). Null sans scène : l'appelant joue alors son effet PixelFX.
func _anim(effect_id: String, at: Vector3, dir: Vector3, data: SpellData, extent: float, props: Dictionary = {},
		follow: bool = false, lift: float = 0.06, from_phase: float = 0.0) -> Node2D:
	var variant: StringName = DraftSpellVfx.variant_name(variant_of(data)) if data != null else &"base"
	var flat: Vector2 = DraftSpellVfx.flat(dir)
	return vfx.spawn(effect_id, at, extent / DraftHunter.UNIT,
		func(node: Node2D) -> void:
			if from_phase > 0.0 and node.has_method("play_from"):
				node.call("play_from", flat, variant, from_phase)
			else:
				node.call("play", flat, variant),
		func(node: Node2D) -> void:
			for key: String in props:
				node.set(key, props[key]),
		follow, lift)


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


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
