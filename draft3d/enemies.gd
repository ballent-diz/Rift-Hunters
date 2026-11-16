class_name DraftEnemies
extends Node3D
## Corrompus et boss du premier jet. Données d'origine (`EnemyData`, `BossData` : PV, dégâts, vitesse, rayon, EXP,
## comportement), déplacement propre au monde 3D : chemins sur la navigation (escaliers, abris), suivis sans corps
## physique pour tenir de grandes hordes. Trajectoires stables : un chemin n'est redemandé que si le Chasseur a
## assez bougé, la vitesse est lissée, et les voisins s'écartent doucement.

class Foe:
	extends RefCounted
	var data: EnemyData
	var boss: BossData
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var hp: float = 1.0
	var max_hp: float = 1.0
	var radius: float = 0.4
	var speed: float = 2.0
	var damage: float = 5.0
	var defense: float = 0.0
	var xp: int = 1
	var view: DraftSpriteView
	var path := PackedVector3Array()
	var path_index: int = 0
	var path_timer: float = 0.0
	var path_target := Vector3.INF
	var contact_timer: float = 0.0
	var state: int = 0
	var timer: float = 0.0
	var cooldown: float = 0.0
	var dir := Vector3.ZERO
	var alive: bool = true
	var slot: int = 0
	## Boss de fin de partie (le vaincre donne la victoire) ; faux pour un gardien de mi-parcours.
	var final: bool = false
	## Cerveau d'un boss ou d'un gardien (DraftBossBrain) ; nul pour un Corrompu.
	var brain: DraftBossBrain
	## Entrave (sorts du Chasseur) : vitesse multipliée par `slow_factor` pendant `slow_left` secondes.
	var slow_left: float = 0.0
	var slow_factor: float = 1.0

	## Marque du traqueur, Éclats de stase : dégâts subis multipliés par (1 + `exposed`) pendant `exposed_left` s.
	var exposed: float = 0.0
	var exposed_left: float = 0.0

	func expose(bonus: float, seconds: float) -> void:
		exposed = maxf(bonus, exposed) if exposed_left > 0.0 else bonus
		exposed_left = maxf(exposed_left, seconds)

	func slow(factor: float, seconds: float) -> void:
		slow_factor = minf(factor, slow_factor) if slow_left > 0.0 else factor
		slow_left = maxf(slow_left, seconds)

const CELL := 1.5
const ACCELERATION := 14.0
const PATH_TARGET_DISTANCE := 0.8
const CONTACT_INTERVAL := 0.6
## Écart de hauteur au-delà duquel un contact ou un coup de mêlée ne porte pas (cour contre terrasse).
const MELEE_REACH_UP := 1.0

var level: DraftLevel
var hunter: DraftHunter
var hazards: DraftHazards
var run: Node
var balance: BalanceConfig
var rng := RandomNumberGenerator.new()
var list: Array[Foe] = []
var boss: Foe
var hp_mult: float = 1.0
var damage_mult: float = 1.0
var boss_hp_mult: float = 1.0
var boss_damage_mult: float = 1.0
## Part de l'intervalle d'origine entre deux techniques d'un boss (réglage du mode, `DraftTuning.boss_pace`).
var boss_pace: float = 1.0
var path_requests: int = 0
var _grid: Dictionary = {}
var _corpses: Array[Dictionary] = []
var _counter: int = 0
var _frame: int = 0


func spawn(data: EnemyData, at: Vector3) -> Foe:
	var foe := Foe.new()
	foe.data = data
	foe.max_hp = data.max_hp * hp_mult
	foe.hp = foe.max_hp
	foe.radius = data.radius * DraftHunter.UNIT
	foe.speed = data.move_speed * DraftHunter.UNIT
	foe.damage = data.damage * damage_mult
	foe.defense = data.defense
	foe.xp = data.xp_value
	foe.cooldown = rng.randf_range(0.5, 2.0)
	_add(foe, data.visual.visual_id, at, 1.0)
	return foe


func spawn_boss(data: BossData, at: Vector3, hp_scale: float = 1.0, final: bool = true) -> Foe:
	var foe := Foe.new()
	foe.boss = data
	foe.final = final
	foe.max_hp = data.max_hp * boss_hp_mult * hp_scale
	foe.hp = foe.max_hp
	foe.radius = data.radius * DraftHunter.UNIT
	foe.speed = data.move_speed * DraftHunter.UNIT * 1.6
	foe.damage = data.damage * boss_damage_mult
	foe.defense = data.defense
	foe.xp = 0
	foe.cooldown = 2.5
	_add(foe, data.visual.visual_id, at, data.visual_scale)
	foe.brain = DraftBossBrain.new()
	foe.brain.setup(self, foe)
	boss = foe
	return foe


func _add(foe: Foe, visual_id: StringName, at: Vector3, size: float) -> void:
	foe.pos = level.closest(at)
	foe.slot = _counter
	_counter += 1
	foe.view = DraftSpriteView.new()
	add_child(foe.view)
	foe.view.setup(visual_id, size)
	foe.view.walk_speed = maxf(foe.speed, 0.5)
	foe.view.snap_to(foe.pos)
	list.append(foe)


func count() -> int:
	return list.size()


## Ennemis dont le centre est à moins de `reach` (à plat) du point ; la hauteur est laissée à l'appelant.
func near(point: Vector3, reach: float) -> Array[Foe]:
	var found: Array[Foe] = []
	var span: int = int(ceil(reach / CELL))
	var cx: int = int(floor(point.x / CELL))
	var cz: int = int(floor(point.z / CELL))
	for x: int in range(cx - span, cx + span + 1):
		for z: int in range(cz - span, cz + span + 1):
			var cell: Array = _grid.get(Vector2i(x, z), [])
			for foe: Foe in cell:
				if foe.alive and Vector2(foe.pos.x - point.x, foe.pos.z - point.z).length() <= reach + foe.radius:
					found.append(foe)
	return found


## Dégâts d'une attaque du Chasseur (défense d'origine appliquée). Vrai si l'ennemi meurt.
func hit(foe: Foe, amount: float, push := Vector3.ZERO) -> bool:
	if not foe.alive:
		return false
	var exposure: float = 1.0 + foe.exposed if foe.exposed_left > 0.0 else 1.0
	if foe.brain != null:
		exposure *= foe.brain.damage_mult()
	var dealt: float = amount * exposure * CombatSystem.defense_multiplier(foe.defense)
	foe.hp -= dealt
	if foe.brain != null:
		foe.brain.on_damage(dealt)
	Audio.play_sfx(&"enemy_hit")
	foe.view.flash()
	if foe.boss == null and foe.data.knockback_resist < 1.0:
		foe.vel += push * (1.0 - foe.data.knockback_resist)
	if foe.hp > 0.0:
		return false
	foe.alive = false
	list.erase(foe)
	if foe.brain != null:
		_corpses.append({"view": foe.view, "left": foe.brain.die() + 1.5})
	else:
		foe.view.play_action(&"death", 0.6)
		_corpses.append({"view": foe.view, "left": 0.6})
	if foe == boss:
		hazards.clear()
	run.call("on_foe_killed", foe)
	return true


## Retire un ennemi sans récompense (lanterne éteinte, invocation dissipée).
func vanish(foe: Foe) -> void:
	if not foe.alive:
		return
	foe.alive = false
	list.erase(foe)
	foe.view.play_action(&"death", 0.4)
	_corpses.append({"view": foe.view, "left": 0.4})


func _physics_process(delta: float) -> void:
	_frame += 1
	var i: int = _corpses.size() - 1
	while i >= 0:
		_corpses[i]["left"] = float(_corpses[i]["left"]) - delta
		if float(_corpses[i]["left"]) <= 0.0:
			(_corpses[i]["view"] as Node).queue_free()
			_corpses.remove_at(i)
		i -= 1
	if not level.ready_for_paths:
		return
	_grid.clear()
	for foe: Foe in list:
		var key := Vector2i(int(floor(foe.pos.x / CELL)), int(floor(foe.pos.z / CELL)))
		if not _grid.has(key):
			_grid[key] = []
		(_grid[key] as Array).append(foe)
	var target: Vector3 = hunter.global_position
	for foe: Foe in list.duplicate():
		if foe.alive:
			_step(foe, target, delta)


func _step(foe: Foe, target: Vector3, delta: float) -> void:
	foe.cooldown = maxf(foe.cooldown - delta, 0.0)
	foe.contact_timer = maxf(foe.contact_timer - delta, 0.0)
	var to_hunter: Vector3 = target - foe.pos
	var climb: float = absf(to_hunter.y)
	to_hunter.y = 0.0
	var distance: float = to_hunter.length()
	var wish := Vector3.ZERO
	var speed: float = foe.speed
	if foe.slow_left > 0.0:
		foe.slow_left -= delta
		speed *= foe.slow_factor
	foe.exposed_left = maxf(foe.exposed_left - delta, 0.0)
	var turn: bool = true
	if foe.brain != null:
		foe.brain.step(to_hunter, distance, climb, delta)
		if foe.brain.moves_itself() or foe.brain.busy():
			# Charge, bond, transition, technique : le cerveau tient la position ; le contact blesse toujours.
			if not foe.brain.moves_itself():
				foe.vel = Vector3.ZERO
			_contact(foe, distance, climb)
			foe.view.push_position(foe.pos, delta, false)
			return
		wish = foe.brain.wish
		speed *= foe.brain.speed_mult
		turn = foe.brain.turns
	elif foe.data.brain == EnemyData.Brain.CHARGER and foe.state > 0:
		foe.timer -= delta
		if foe.state == 1:
			if foe.timer <= 0.0:
				foe.state = 2
				foe.timer = 0.45
				foe.view.set_tint(Color.WHITE)
				foe.view.play_action(&"attack", 0.45)
		else:
			wish = foe.dir
			speed = 9.0
			foe.vel = foe.dir * speed
			if foe.timer <= 0.0:
				foe.state = 0
				foe.cooldown = foe.data.attack.cooldown if foe.data.attack else 3.0
		turn = false
	else:
		wish = chase(foe, target, to_hunter, distance, climb, delta)
		if foe.data.brain == EnemyData.Brain.BLINKER and foe.cooldown <= 0.0 and distance > 4.0:
			# Passe-faille : réapparaît près du Chasseur, du côté d'où il vient.
			foe.cooldown = 4.5
			run.call("fx", &"blink_out", DraftPixelFx.enemy_family(foe.data), foe.pos + Vector3.UP * 0.5)
			foe.pos = level.closest(target - to_hunter.normalized() * 2.6)
			foe.vel = Vector3.ZERO
			foe.path = PackedVector3Array()
			foe.view.snap_to(foe.pos)
			run.call("fx", &"blink_in", DraftPixelFx.enemy_family(foe.data), foe.pos + Vector3.UP * 0.5)
		elif foe.data.brain == EnemyData.Brain.SUMMONER and foe.cooldown <= 0.0:
			foe.cooldown = 6.0
			foe.view.play_action(&"attack")
			run.call("foe_summon", foe, 2)
		if foe.data.brain == EnemyData.Brain.CHARGER and foe.cooldown <= 0.0 and distance < 6.0 and climb < 0.6 \
				and distance > 1.5:
			foe.state = 1
			foe.timer = 0.55
			foe.dir = to_hunter.normalized()
			foe.view.set_tint(Color(1.6, 1.0, 0.6))
			wish = Vector3.ZERO
		elif foe.data.brain == EnemyData.Brain.RANGED and foe.data.attack != null and foe.data.attack.projectile_speed > 0.0:
			var reach: float = foe.data.attack.attack_range * DraftHunter.UNIT * 0.6
			if distance < reach and climb < 3.0:
				if distance < reach * 0.75:
					wish = Vector3.ZERO
				if foe.cooldown <= 0.0 and run.call("sight_clear", foe.pos + Vector3.UP * 0.6, hunter.chest()):
					foe.cooldown = foe.data.attack.cooldown
					foe.view.play_action(&"attack")
					run.call("enemy_shot", foe)
	foe.vel = foe.vel.move_toward(wish * speed, ACCELERATION * delta)
	var next: Vector3 = foe.pos + foe.vel * delta + _separation(foe) * delta
	# Murs de faille du Chasseur : un ennemi ne les traverse pas.
	if run.call("barrier_blocks", foe.pos, next):
		next = foe.pos
		foe.vel = Vector3.ZERO
	# Recalage sur la navigation une image sur deux (hauteur dans l'escalier, murs) : les ennemis n'ont pas de corps.
	if (foe.slot + _frame) % 2 == 0 or foe.boss != null:
		next = level.closest(next + Vector3.UP * 0.2)
	foe.pos = next
	_contact(foe, distance, climb)
	foe.view.push_position(foe.pos, delta, turn)


func _contact(foe: Foe, distance: float, climb: float) -> void:
	if distance < foe.radius + DraftHunter.RADIUS + 0.12 and climb < MELEE_REACH_UP and foe.contact_timer <= 0.0 \
			and hunter.alive:
		foe.contact_timer = CONTACT_INTERVAL
		if hunter.take_damage(foe.damage) > 0.0:
			run.call("on_hunter_hit", foe)


## Direction de poursuite : en ligne droite de près et de plain-pied, sinon le long du chemin de navigation.
func chase(foe: Foe, target: Vector3, to_hunter: Vector3, distance: float, climb: float, delta: float) -> Vector3:
	if distance < 2.5 and climb < 0.6:
		foe.path_target = Vector3.INF
		return to_hunter / maxf(distance, 0.001) if distance > foe.radius + DraftHunter.RADIUS else Vector3.ZERO
	foe.path_timer -= delta
	if foe.path.is_empty() or (foe.path_timer <= 0.0 and target.distance_to(foe.path_target) >= PATH_TARGET_DISTANCE):
		foe.path = level.path(foe.pos, target)
		foe.path_index = 0
		foe.path_target = target
		foe.path_timer = rng.randf_range(0.45, 0.8)
		path_requests += 1
	while foe.path_index < foe.path.size():
		var step: Vector3 = foe.path[foe.path_index] - foe.pos
		step.y = 0.0
		if step.length() > 0.35:
			return step.normalized()
		foe.path_index += 1
	return to_hunter / maxf(distance, 0.001)


func _separation(foe: Foe) -> Vector3:
	if foe.boss != null:
		return Vector3.ZERO
	var push := Vector3.ZERO
	var key := Vector2i(int(floor(foe.pos.x / CELL)), int(floor(foe.pos.z / CELL)))
	for x: int in range(key.x - 1, key.x + 2):
		for z: int in range(key.y - 1, key.y + 2):
			var cell: Array = _grid.get(Vector2i(x, z), [])
			for other: Foe in cell:
				if other == foe or absf(other.pos.y - foe.pos.y) > 1.0:
					continue
				var away := Vector3(foe.pos.x - other.pos.x, 0.0, foe.pos.z - other.pos.z)
				var gap: float = foe.radius + other.radius - away.length()
				if gap > 0.0:
					push += (away.normalized() if away.length() > 0.01 else Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5)) * gap
	return (push * 4.0).limit_length(1.8)


# --- Boss et gardiens : DraftBossBrain (docs/design/BOSS_V2.md) --------------------------------------------------

## Phase du boss (0 : première), seuils de ses données d'origine.
func boss_phase(foe: Foe) -> int:
	return foe.brain.phase if foe.brain != null else 0
