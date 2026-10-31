class_name AutopilotBrain
extends PlayerBrain
## Bot de test : esquive les ennemis, ramasse l'XP, utilise Ruée et Techniques, joue les mécaniques des boss.
## Sert aux smoke tests (partie complète sans intervention) et à l'équilibrage. Il joue comme un joueur MOYEN
## (docs/design/DIFFICULTE.md) : il connaît les mécaniques principales (abris contre les tirs et les souffles, bulbes
## de braise, œufs, point faible), sans réflexes parfaits (réaction aux tirs à distance une fois sur COVER_REACTION).

## Joueur moyen : il ne réagit pas à chaque menace (part des réévaluations où il cherche un abri).
const COVER_REACTION := 0.7
const COVER_RECHECK := 0.5
const COVER_SEARCH := 200.0
## Traque des derniers Corrompus : distance de recherche (au-delà, la flèche de route mène à eux).
const CHASE_SEARCH := 800.0

var _dash_wanted: bool = false
var _wander := Vector2.RIGHT
var _cached := Vector2.ZERO
var _frame: int = 0
## Anti-blocage : position relevée toutes les 2 s ; si le bot n'avance plus, il longe l'obstacle sans viser les gemmes.
var _check_pos := Vector2.INF
var _check_time: float = 0.0
var _unstick_until: float = -1.0
var _slide: float = 1.0
## Abri visé (INF : aucun) et prochaine réévaluation.
var _cover := Vector2.INF
var _cover_check: float = 0.0


func move_vector() -> Vector2:
	_frame += 1
	if _frame % 2 == 0:
		return _cached
	_cached = _compute_move()
	return _cached


func _compute_move() -> Vector2:
	var player: Player = ctx.player
	var pos: Vector2 = player.global_position
	var flee := Vector2.ZERO
	var closest: float = INF
	# Traque des derniers Corrompus : comme un joueur, il va les chercher au lieu de fuir les élites.
	var hunting: bool = ctx.zones != null and ctx.zones.hunting
	for enemy: Enemy in ctx.enemies.query_radius(pos, 230.0):
		var offset: Vector2 = pos - enemy.global_position
		var dist: float = maxf(offset.length(), 1.0)
		closest = minf(closest, dist - enemy.radius)
		var weight: float = (3.0 if (enemy.is_boss or enemy.is_elite) and not hunting else 1.0) / (dist * dist)
		flee += offset.normalized() * weight * 4000.0
	flee += ctx.danger_vector(pos) * 3.0
	for obstacle: Enemy in ctx.enemies.obstacles:
		var away: Vector2 = pos - obstacle.position
		var gap: float = away.length() - obstacle.radius
		if gap < 90.0:
			flee += away.normalized() * (90.0 - gap) / 30.0
	# Obstacles du décor : comme un joueur, ne pas se laisser coincer contre un rocher ou l'eau.
	flee += ctx.obstacles.repulsion(pos, 90.0)
	var threat: Vector2 = _projectile_threat(pos) + _charge_threat(pos)
	flee += threat * 3.0
	flee += _cover_pull(pos)
	var gem: Vector2 = ctx.pickups.nearest_position(pos, 400.0)
	var seek := Vector2.ZERO
	if gem != Vector2.INF:
		seek = (gem - pos).normalized() * 0.7
	# Rester loin des bords de l'arène.
	var rect: Rect2 = ctx.arena_rect().grow(-260.0)
	var home := Vector2.ZERO
	if not rect.has_point(pos):
		home = (rect.get_center() - pos).normalized() * 1.5
	if ctx.rng.randf() < 0.01:
		_wander = _wander.rotated(ctx.rng.randf_range(-1.2, 1.2))
	_dash_wanted = closest < 22.0 or ctx.danger_vector(pos).length() > 0.5 or threat.length() > 1.5
	# Modes « vagues par zone », « failles » et « autel » : suivre la route (zone suivante, faille, arène, autel).
	var route: Vector2 = ctx.objective_direction(pos) * 1.6
	if route != Vector2.ZERO:
		home = Vector2.ZERO
	if ctx.time >= _check_time:
		if _check_pos != Vector2.INF and pos.distance_to(_check_pos) < 40.0:
			_unstick_until = ctx.time + 2.5
			_slide = -_slide
		_check_pos = pos
		_check_time = ctx.time + 2.0
	var slide := Vector2.ZERO
	if ctx.time < _unstick_until:
		seek = Vector2.ZERO
		var heading: Vector2 = route if route != Vector2.ZERO else _wander
		slide = heading.normalized().orthogonal() * _slide * 1.4
	var result: Vector2 = flee + seek + home + route + slide + _wander * 0.25 + _chase(pos, hunting)
	# Mécaniques de boss : foncer dans un orbe, entrer dans la couronne, se placer derrière un miroir.
	var forced: Vector2 = ctx.boss_bot_move(pos)
	if forced != Vector2.ZERO:
		result = forced * 2.0 + flee * 0.6
	_dash_wanted = _dash_wanted or ctx.boss_bot_dash()
	return result.normalized() if result.length() > 0.05 else Vector2.ZERO


## Traque : se rapprocher à portée de tir (et en vue) du dernier Corrompu le plus proche ; au-delà de la distance où
## la flèche de route s'affiche, c'est la route qui guide.
func _chase(pos: Vector2, hunting: bool) -> Vector2:
	if not hunting:
		return Vector2.ZERO
	var prey: Enemy = null
	for enemy: Enemy in ctx.enemies.query_radius(pos, CHASE_SEARCH):
		if not enemy.alive or enemy.is_boss or enemy.is_obstacle or (enemy.data and enemy.data.structure):
			continue
		if prey == null or enemy.position.distance_to(pos) < prey.position.distance_to(pos):
			prey = enemy
	if prey == null:
		return Vector2.ZERO
	var reach: float = ctx.player.stats.get_value(StatKeys.BOLT_RANGE) * 0.7
	if pos.distance_to(prey.position) <= reach and ctx.obstacles.line_clear(pos, prey.position):
		return Vector2.ZERO
	return (prey.position - pos).normalized() * 1.4


## Source de tir ou de souffle qui menace le Chasseur : souffle ou rayon en préparation, sinon le tireur le plus
## proche en vue. INF s'il n'y en a pas.
func _threat_source(pos: Vector2) -> Vector2:
	for h: Dictionary in ctx.hazards.hazards:
		if h["kind"] in [HazardManager.Kind.CONE, HazardManager.Kind.BEAM] and float(h.get("delay", 0.0)) > 0.0 \
				and (h["pos"] as Vector2).distance_to(pos) < 700.0:
			return h["pos"]
	var best := Vector2.INF
	for enemy: Enemy in ctx.enemies.query_radius(pos, 450.0):
		if enemy.alive and enemy.data and enemy.data.brain == EnemyData.Brain.RANGED \
				and (best == Vector2.INF or enemy.position.distance_to(pos) < best.distance_to(pos)):
			best = enemy.position
	return best


## Abris : derrière un rocher par rapport à la menace, à courte distance. Réévalué toutes les COVER_RECHECK secondes.
func _cover_pull(pos: Vector2) -> Vector2:
	if ctx.time >= _cover_check:
		_cover_check = ctx.time + COVER_RECHECK
		_cover = Vector2.INF
		var source: Vector2 = _threat_source(pos)
		# Pendant la traque des derniers Corrompus, un joueur moyen fonce sur eux au lieu de se cacher.
		var hunting: bool = ctx.zones != null and ctx.zones.hunting
		if not hunting and source != Vector2.INF and ctx.rng.randf() < COVER_REACTION \
				and ctx.obstacles.line_clear(source, pos):
			_cover = _find_cover(pos, source)
	if _cover == Vector2.INF or pos.distance_to(_cover) < 12.0:
		return Vector2.ZERO
	return (_cover - pos).normalized() * 2.2


func _find_cover(pos: Vector2, source: Vector2) -> Vector2:
	var best := Vector2.INF
	for ring: float in [70.0, 130.0, COVER_SEARCH]:
		for i: int in 12:
			var point: Vector2 = pos + Vector2.RIGHT.rotated(TAU * i / 12.0) * ring
			if ctx.obstacles.distance(point) < 24.0 or ctx.obstacles.line_clear(source, point):
				continue
			if best == Vector2.INF or point.distance_to(pos) < best.distance_to(pos):
				best = point
		if best != Vector2.INF:
			return best
	return best


## Esquive latérale des projectiles qui se dirigent vers le Chasseur.
func _projectile_threat(pos: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for p: Projectile in ctx.projectiles.hostile:
		var to_player: Vector2 = pos - p.position
		var dist: float = to_player.length()
		if dist > 200.0 or p.velocity.dot(to_player) <= 0.0:
			continue
		var dir: Vector2 = p.velocity.normalized()
		var side: Vector2 = to_player - dir * to_player.dot(dir)
		if side.length() < 40.0:
			var away: Vector2 = side.normalized() if side.length() > 0.5 else dir.orthogonal()
			result += away * (1.0 + (200.0 - dist) / 100.0)
	return result


## Sort de la trajectoire des Bondisseurs qui se préparent à charger.
func _charge_threat(pos: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for enemy: Enemy in ctx.enemies.query_radius(pos, 420.0):
		if enemy.data == null or enemy.data.brain != EnemyData.Brain.CHARGER:
			continue
		if enemy.state != Enemy.State.WINDUP and enemy.state != Enemy.State.CHARGE:
			continue
		var to_player: Vector2 = pos - enemy.position
		var side: Vector2 = to_player - enemy.aim_dir * to_player.dot(enemy.aim_dir)
		if to_player.dot(enemy.aim_dir) > 0.0 and side.length() < 50.0:
			result += (side.normalized() if side.length() > 0.5 else enemy.aim_dir.orthogonal()) * 2.0
	return result


func wants_dash() -> bool:
	return _dash_wanted


func technique_pressed(_index: int) -> bool:
	return ctx.enemies.count() > 8 or ctx.boss != null or _guardian() != null


## Comme un joueur : Taille fendante (emplacement 0) au contact, Lance prismatique (1) dès qu'une cible est à portée.
func spell_pressed(slot: int) -> bool:
	var spells: HunterSpells = ctx.spells
	if spells == null or slot >= spells.slots.size() or spells.slots[slot] == null:
		return false
	var spell: SpellData = spells.slots[slot]
	var pos: Vector2 = ctx.player.global_position
	match spell.spell_kind:
		&"parry", &"swap":
			return ctx.enemies.find_nearest(pos, 70.0) != null
		&"aegis":
			return ctx.player.hp < ctx.player.max_hp * 0.6
		&"rifts", &"wall", &"crystal":
			return ctx.enemies.count() > 10 and ctx.enemies.find_nearest(pos, 300.0) != null
	var reach: float = spell.spell_range * (0.9 if spell.spell_kind == &"slash" else 0.7)
	return ctx.enemies.find_nearest(pos, maxf(reach, 120.0)) != null


## Comme un joueur : ordonne aux Échos de cibler le boss, ou un point faible exposé (ordre de focus).
func focus_requested() -> bool:
	if ctx.allies.focus_time > 0.0:
		return false
	return (ctx.boss != null and ctx.boss.alive) or _guardian() != null or _weak_point() != null


## Visée d'un joueur moyen : point faible exposé, œuf à casser, bulbe entouré de Corrompus, boss, puis ennemi en vue.
func aim_point() -> Vector2:
	var pos: Vector2 = ctx.player.global_position
	var weak: Enemy = _weak_point()
	if weak:
		return weak.global_position
	var target: Vector2 = _mechanic_target(pos)
	if target != Vector2.INF:
		return target
	if ctx.boss and ctx.boss.is_alive():
		return ctx.boss.global_position
	if _guardian() and _guardian().global_position.distance_to(pos) < 500.0:
		return _guardian().global_position
	var enemy: Enemy = ctx.enemies.find_nearest_visible(pos, 400.0)
	return enemy.global_position if enemy else pos


## Gardien de palier vivant (grande arène), sinon null.
func _guardian() -> Enemy:
	var guardian: Enemy = ctx.mini_boss
	return guardian if guardian != null and is_instance_valid(guardian) and guardian.alive else null


## Ennemi au point faible exposé (cratère ouvert du Titan) à portée.
func _weak_point() -> Enemy:
	for enemy: Enemy in ctx.enemies.query_radius(ctx.player.global_position, 450.0):
		if enemy.alive and enemy.extra_damage_taken > 1.0 and not enemy.is_obstacle:
			return enemy
	return null


## Œuf de cendre proche, ou bulbe de braise au repos entouré d'au moins 5 Corrompus (le Chasseur à l'écart).
func _mechanic_target(pos: Vector2) -> Vector2:
	for enemy: Enemy in ctx.enemies.query_radius(pos, 380.0):
		if enemy.alive and enemy.data and enemy.data.structure and not enemy.data.pod and enemy.is_target():
			return enemy.global_position
	if ctx.pods == null:
		return Vector2.INF
	for pod: Dictionary in ctx.pods.pods:
		var held: Variant = pod["enemy"]
		if pod["state"] != PodDirector.State.IDLE or not is_instance_valid(held):
			continue
		var bulb: Enemy = held
		if bulb.position.distance_to(pos) > 450.0:
			continue
		if bulb.position.distance_to(pos) < ctx.arena.pod_radius + 40.0:
			continue
		if ctx.enemies.query_radius(bulb.position, ctx.arena.pod_radius).size() >= 6:
			return bulb.global_position
	return Vector2.INF
