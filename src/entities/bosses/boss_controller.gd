class_name BossController
extends RefCounted
## Pilote un Dévoreur : phases, choix d'attaques pondéré, mécaniques (absorption, cœur exposé, cristaux).
## Chaque attaque est une méthode _pattern_<kind> paramétrée par BossPatternData. Les mécaniques qui durent au-delà
## d'une attaque vivent dans des BossMechanics (BossSignatures : orbes, couronne, cratères ; GuardianSignatures : voile
## de brume, charge du bûcher ; GlauquemireMechanics).
## params["anim"] choisit l'animation du sprite, params["vfx"] l'effet peint (BossData.vfx_dir) : le dessin suit le
## combat, il ne décide jamais des dégâts.

## Animation jouée au lancement de chaque attaque (absente de la feuille : rien ne change).
const PATTERN_ANIMATIONS := {
	&"claw": &"attack", &"shadow_wave": &"shadow_wave", &"summon": &"summon", &"absorb": &"attack",
	&"void_beam": &"phase2_attack", &"rock_rain": &"attack",
	&"charge": &"attack", &"quake": &"attack", &"blink": &"attack",
	&"sweep": &"attack", &"slam": &"heavy_slam", &"breath": &"rift_breath",
	&"skyfall": &"skyfall", &"eye_beam": &"rift_eye",
	&"source_orb": &"attack", &"star_crown": &"phase2_attack", &"crater_sequence": &"attack",
	&"mud_wall": &"mud_spit", &"root_leash": &"root_lash", &"leech_feed": &"leech_call", &"prism_beam": &"prism_beam",
	&"whirlpool": &"whirlpool", &"swallow": &"swallow", &"mist_veil": &"attack", &"pyre_ram": &"attack",
}
## Effets décoratifs simultanés au plus (les télégraphes ne comptent pas : ils ne sont jamais supprimés).
const MAX_EFFECTS := 8
## Repères de contact des effets peints (part de leur durée) : griffes et souffles, frappes au sol.
const CONTACT_STRIKE := 0.12
const CONTACT_SLAM := 0.3

var ctx: RunContext
var boss: Enemy
var data: BossData
var phase_index: int = 0
var heart_time: float = 0.0
var absorb_time: float = 0.0
var busy_time: float = 0.0
var enraged: bool = false
## Étourdi (orbe ou rayon renvoyé, Écho libéré) : secondes restantes.
var stunned_time: float = 0.0
var _next_pattern_time: float = 0.0
var _ready_at: Dictionary = {}
var _scheduled: Array[Dictionary] = []
var _fight_time: float = 0.0
var _charge_time: float = 0.0
var _charge_dir := Vector2.ZERO
var _charge_speed: float = 0.0
var _effects: Array[Node2D] = []
var _indicators: Array[Node2D] = []
var _summons: Array[Enemy] = []
var _scenes: Dictionary = {}
var _hurt_hp: float = 0.0
var _hurt_window: float = 0.0
var _hurt_cooldown: float = 0.0
var _ended: bool = false
var _signatures: BossSignatures
var _marsh: GlauquemireMechanics
var _guardians: GuardianSignatures
var _mechanics: Array[BossMechanics] = []


func _init(p_ctx: RunContext, p_boss: Enemy) -> void:
	ctx = p_ctx
	boss = p_boss
	data = boss.boss_data
	_next_pattern_time = ctx.time + 2.5
	_hurt_hp = boss.hp
	if data.intro_animation != &"" and boss.visual.has_animation(data.intro_animation):
		boss.visual.play_action(data.intro_animation)
		_vfx(String(data.intro_animation), _mouth(), Vector2.RIGHT)
		busy_time = 1.4
	if not phase().mechanics.is_empty():
		marsh().on_phase(0, phase())


func phase() -> BossPhaseData:
	return data.phases[phase_index]


func phase_threshold(index: int) -> float:
	var threshold: float = data.phases[index].hp_threshold
	if index == 1 and ctx.difficulty.boss_phase2_threshold > 0.0:
		threshold = ctx.difficulty.boss_phase2_threshold
	return threshold


func schedule(delay: float, action: Callable) -> void:
	_scheduled.append({"time": ctx.time + delay, "action": action})


func step(delta: float) -> void:
	if not boss.alive:
		if not _ended:
			_ended = true
			_clear_indicators()
			for mechanics: BossMechanics in _mechanics:
				mechanics.finish()
			_vfx("death", boss.position, Vector2.RIGHT, {}, -1.0, true)
		return
	_run_scheduled()
	_fight_time += delta
	stunned_time = maxf(stunned_time - delta, 0.0)
	for mechanics: BossMechanics in _mechanics:
		mechanics.step(delta)
	if not enraged and _fight_time >= ctx.balance.boss_enrage_time:
		enraged = true
		boss.contact_damage *= ctx.balance.boss_enrage_damage_mult
		boss.move_speed *= ctx.balance.boss_enrage_speed_mult
		boss.visual.set_tint(Color(1.0, 0.55, 0.55))
		ctx.events.event_started.emit("BOSS_ENRAGED")
	heart_time = maxf(heart_time - delta, 0.0)
	boss.extra_damage_taken = 2.0 if heart_time > 0.0 else 1.0
	if absorb_time > 0.0:
		absorb_time -= delta
		if absorb_time <= 0.0:
			_release_absorbed()
	_check_phase()
	_check_hurt(delta)
	busy_time = maxf(busy_time - delta, 0.0)
	var to_player: Vector2 = ctx.player.global_position - boss.position
	if _charge_time > 0.0:
		_charge_time -= delta
		boss.velocity = _charge_dir * _charge_speed
		boss.position += boss.velocity * delta
		var rect: Rect2 = ctx.arena_rect().grow(-boss.radius)
		boss.position = boss.position.clamp(rect.position, rect.end)
	elif busy_time <= 0.0 and boss.invulnerable_time <= 0.0 and absorb_time <= 0.0:
		if to_player.length() > boss.radius + 40.0:
			boss.velocity = to_player.normalized() * boss.move_speed * phase().move_speed_mult * boss.statuses.speed_mult()
			boss.position += boss.velocity * delta
		else:
			boss.velocity = Vector2.ZERO
	else:
		boss.velocity = Vector2.ZERO
	if busy_time <= 0.0:
		boss.visual.set_facing_left(to_player.x < 0.0)
	boss.visual.tick(delta, boss.velocity.length() > 2.0, boss.velocity.length())
	if busy_time <= 0.0 and absorb_time <= 0.0 and boss.invulnerable_time <= 0.0 and ctx.time >= _next_pattern_time:
		var pattern: BossPatternData = _choose_pattern(to_player.length())
		if pattern:
			_ready_at[pattern] = ctx.time + pattern.cooldown
			Audio.play_sfx(&"boss_telegraph")
			call("_pattern_" + String(pattern.kind), pattern)
			boss.visual.play_action(StringName(pattern.params.get("anim", PATTERN_ANIMATIONS.get(pattern.kind, &"attack"))))
			ctx.stats.add(&"boss_patterns")
		_next_pattern_time = ctx.time + phase().pattern_interval * (0.7 if enraged else 1.0)


func _run_scheduled() -> void:
	var i: int = _scheduled.size() - 1
	while i >= 0:
		if ctx.time >= float(_scheduled[i]["time"]):
			var action: Callable = _scheduled[i]["action"]
			_scheduled.remove_at(i)
			if boss.alive:
				action.call()
		i -= 1


func _check_phase() -> void:
	var next: int = phase_index + 1
	if next >= data.phases.size():
		return
	if boss.hp / boss.max_hp > phase_threshold(next):
		return
	phase_index = next
	var p: BossPhaseData = phase()
	if p.defense_override >= 0.0:
		boss.base_defense = p.defense_override
	boss.invulnerable_time = p.transition_time
	absorb_time = 0.0
	boss.absorb_radius = 0.0
	busy_time = p.transition_time
	_next_pattern_time = ctx.time + p.transition_time + 1.0
	ctx.hazards.add_ring(boss.position, 520.0, 700.0, 30.0, 10.0 * ctx.difficulty.enemy_damage_mult, true, data.id,
		[ctx.rng.randf() * TAU], 0.5, [], p.transition_time * 0.5)
	ctx.fx.burst(boss.position, boss.radius * 2.0, Color(0.8, 0.3, 1.0, 0.5))
	boss.visual.play_action(p.transition_animation)
	_clear_indicators()
	_vfx("transform", boss.position, Vector2.RIGHT, {}, -1.0, true)
	if not p.mechanics.is_empty() or _marsh != null:
		marsh().on_phase(phase_index, p)
	var phase_idle := StringName("phase%d_idle" % (phase_index + 1))
	if boss.visual.has_animation(phase_idle):
		boss.visual.idle_animation = phase_idle
	ctx.events.boss_phase_changed.emit(phase_index)


## Réaction aux gros coups (part des PV perdue en une seconde) : jamais au milieu d'une attaque.
func _check_hurt(delta: float) -> void:
	if data.hurt_ratio <= 0.0:
		return
	_hurt_cooldown = maxf(_hurt_cooldown - delta, 0.0)
	_hurt_window += delta
	if _hurt_window < 1.0:
		return
	var lost: float = (_hurt_hp - boss.hp) / boss.max_hp
	_hurt_window = 0.0
	_hurt_hp = boss.hp
	if lost >= data.hurt_ratio and busy_time <= 0.0 and _hurt_cooldown <= 0.0:
		_hurt_cooldown = 6.0
		boss.visual.play_action(&"hurt")
		_vfx("hurt", boss.position + Vector2(0.0, -boss.radius * 0.5), Vector2.RIGHT)


func _choose_pattern(distance: float) -> BossPatternData:
	var options: Array[BossPatternData] = []
	var total: float = 0.0
	for pattern: BossPatternData in phase().patterns:
		if ctx.time < float(_ready_at.get(pattern, 0.0)):
			continue
		var in_reach: bool = pattern.kind == &"claw" or pattern.params.has("range")
		if in_reach and distance > float(pattern.params.get("range", 200.0)):
			continue
		options.append(pattern)
		total += pattern.weight
	if options.is_empty():
		return null
	var roll: float = ctx.rng.randf() * total
	for pattern: BossPatternData in options:
		roll -= pattern.weight
		if roll <= 0.0:
			return pattern
	return options.back()


## Étourdi : ni attaque ni déplacement ; les attaques déjà annoncées partent quand même.
func stun(seconds: float) -> void:
	stunned_time = maxf(stunned_time, seconds)
	busy_time = maxf(busy_time, seconds)
	_charge_time = 0.0
	boss.visual.play_action(&"hurt")
	ctx.fx.text(boss.position + Vector2(0, -boss.radius - 20.0), tr("BOSS_STUNNED"), Color(1.0, 0.95, 0.6))
	ctx.stats.add(&"boss_stuns")


func signatures() -> BossSignatures:
	if _signatures == null:
		_signatures = BossSignatures.new()
		_add_mechanics(_signatures)
	return _signatures


func guardians() -> GuardianSignatures:
	if _guardians == null:
		_guardians = GuardianSignatures.new()
		_add_mechanics(_guardians)
	return _guardians


func marsh() -> GlauquemireMechanics:
	if _marsh == null:
		_marsh = GlauquemireMechanics.new()
		_add_mechanics(_marsh)
	return _marsh


func _add_mechanics(mechanics: BossMechanics) -> void:
	mechanics.setup(ctx, self)
	ctx.world.add_child(mechanics)
	_mechanics.append(mechanics)
	ctx.boss_mechanics.append(mechanics)


func _damage(pattern: BossPatternData) -> float:
	return pattern.damage * ctx.difficulty.enemy_damage_mult * ctx.arena.boss_damage_mult \
		* (ctx.balance.boss_enrage_damage_mult if enraged else 1.0)


## Griffe du vide : frappe télégraphiée devant le boss.
func _pattern_claw(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var radius: float = float(pattern.params.get("radius", 110.0))
	ctx.hazards.add_circle(boss.position + dir * boss.radius * 0.9, radius, pattern.telegraph, _damage(pattern), true, data.id)
	busy_time = pattern.telegraph + 0.3


## Vague d'ombres : anneau(x) en expansion avec brèches sûres.
func _pattern_shadow_wave(pattern: BossPatternData) -> void:
	var waves: int = int(pattern.params.get("waves", 1))
	for w: int in waves:
		schedule(w * float(pattern.params.get("wave_gap", 0.9)), func() -> void:
			var gaps: Array = []
			for g: int in int(pattern.params.get("gaps", 2)):
				gaps.append(ctx.rng.randf() * TAU)
			ctx.hazards.add_ring(boss.position, float(pattern.params.get("speed", 230.0)), 1000.0,
				float(pattern.params.get("thickness", 26.0)), _damage(pattern), true, data.id, gaps,
				float(pattern.params.get("gap_width", 0.38)), [], pattern.telegraph)
		)
	busy_time = pattern.telegraph + 0.4


## Invocation : portails télégraphiés puis apparition de Corrompus.
## Points praticables seulement (hors rochers et falaises) ; plafond d'invocations actives (max_active).
func _pattern_summon(pattern: BossPatternData) -> void:
	var enemy_ids: Array = pattern.params.get("enemies", ["skitterling"])
	_summons.assign(_summons.filter(func(e: Variant) -> bool: return is_instance_valid(e) and (e as Enemy).alive))
	var count: int = mini(int(pattern.params.get("count", 6)), ctx.spawner.current_cap() - ctx.enemies.count())
	count = mini(count, int(pattern.params.get("max_active", 999)) - _summons.size())
	var points := PackedVector2Array()
	for i: int in maxi(count, 0):
		var pos: Vector2 = boss.position + Vector2.RIGHT.rotated(TAU * i / count + ctx.rng.randf()) * (boss.radius + 70.0)
		pos = ctx.obstacles.push_out(pos, 20.0)
		if ctx.obstacles.distance(pos) < 20.0:
			continue
		points.append(pos - boss.position)
		ctx.fx.ring(pos, 22.0, Color(0.8, 0.3, 1.0, 0.8), pattern.telegraph)
		var id: StringName = StringName(enemy_ids[i % enemy_ids.size()])
		schedule(pattern.telegraph, func() -> void:
			var enemy: EnemyData = GameDB.enemy(id)
			if enemy:
				_summons.append(ctx.enemies.spawn(enemy, pos))
		)
	if points.is_empty():
		return
	var fx: Node2D = _vfx(String(pattern.params.get("vfx", "")), boss.position, Vector2.RIGHT)
	if fx:
		fx.call("set_secondary_offsets", points)
	busy_time = pattern.telegraph + 0.2


## Absorption : avale les projectiles alliés, puis les recrache et expose son cœur.
func _pattern_absorb(pattern: BossPatternData) -> void:
	absorb_time = float(pattern.params.get("duration", 4.0))
	boss.absorb_radius = float(pattern.params.get("radius", 150.0))
	boss.absorbed_count = 0
	busy_time = absorb_time
	_ready_at[&"absorb_release"] = pattern.damage


func _release_absorbed() -> void:
	boss.absorb_radius = 0.0
	var count: int = clampi(boss.absorbed_count / 2 + 6, 6, 28)
	var damage: float = float(_ready_at.get(&"absorb_release", 12.0)) * ctx.difficulty.enemy_damage_mult
	var offset: float = ctx.rng.randf() * TAU
	for i: int in count:
		var dir := Vector2.RIGHT.rotated(offset + TAU * i / count)
		ctx.projectiles.spawn_hostile(boss.position + dir * boss.radius, dir, 170.0, damage, data.id, 9.0, 6.0)
	ctx.stats.set_max(&"boss_absorbed_max", float(boss.absorbed_count))
	heart_time = 3.0
	Audio.play_sfx(&"heart_exposed")
	ctx.fx.text(boss.position + Vector2(0, -boss.radius - 20.0), tr("BOSS_HEART_EXPOSED"), Color(1.0, 0.8, 1.0))
	ctx.fx.burst(boss.position, boss.radius * 0.6, Color(1.0, 0.6, 1.0, 0.5))


## Rayon du vide : laser télégraphié verrouillé sur la position du Chasseur.
func _pattern_void_beam(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var beams: int = int(pattern.params.get("beams", 1))
	for b: int in beams:
		var angle: float = (b - (beams - 1) * 0.5) * float(pattern.params.get("spread", 0.5))
		ctx.hazards.add_beam(boss.position, dir.rotated(angle), float(pattern.params.get("length", 950.0)),
			float(pattern.params.get("width", 34.0)), pattern.telegraph, float(pattern.params.get("duration", 1.2)),
			_damage(pattern), data.id)
	busy_time = pattern.telegraph + float(pattern.params.get("duration", 1.2))


## Pluie de roches : impacts télégraphiés en salves autour du Chasseur.
func _pattern_rock_rain(pattern: BossPatternData) -> void:
	var waves: int = int(pattern.params.get("waves", 3))
	var per_wave: int = int(pattern.params.get("count", 6))
	var radius: float = float(pattern.params.get("radius", 70.0))
	for w: int in waves:
		schedule(w * float(pattern.params.get("wave_gap", 0.6)), func() -> void:
			var center: Vector2 = ctx.player.global_position
			for i: int in per_wave:
				var offset := Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * ctx.rng.randf_range(0.0, 260.0)
				if i == 0:
					offset = Vector2.ZERO
				ctx.hazards.add_circle(center + offset, radius, pattern.telegraph, _damage(pattern), true, data.id)
				# Pluie du cratère (Pyrevorn) : chaque impact laisse une plaque de sol brûlant.
				if pattern.params.has("burn_time") and ctx.burn:
					var spot: Vector2 = center + offset
					schedule(pattern.telegraph, func() -> void:
						ctx.burn.add_plate(spot, radius * 0.8, float(pattern.params["burn_time"])))
		)
	busy_time = 0.6


## Charge : ligne télégraphiée puis ruée à travers l'arène.
func _pattern_charge(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var speed: float = float(pattern.params.get("speed", 620.0))
	var duration: float = float(pattern.params.get("duration", 0.9))
	ctx.fx.danger_line(boss.position, boss.position + dir * speed * duration, boss.radius * 1.6, pattern.telegraph)
	busy_time = pattern.telegraph + duration
	schedule(pattern.telegraph, func() -> void:
		_charge_dir = dir
		_charge_speed = speed
		_charge_time = duration
	)


## Séisme : anneaux sans brèche, à franchir avec la Ruée (invulnérabilité).
func _pattern_quake(pattern: BossPatternData) -> void:
	for w: int in int(pattern.params.get("waves", 1)):
		schedule(w * float(pattern.params.get("wave_gap", 0.8)), func() -> void:
			ctx.hazards.add_ring(boss.position, float(pattern.params.get("speed", 200.0)), 900.0,
				float(pattern.params.get("thickness", 18.0)), _damage(pattern), true, data.id, [], 0.0, [], pattern.telegraph)
		)
	busy_time = pattern.telegraph + 0.3


## Pas de brume : le boss se dissout dans la brume et réapparaît près du Chasseur ; frappe télégraphiée à l'arrivée.
## Il traverse ainsi toute la carte (gardien du sceau du Gué des Brumes).
func _pattern_blink(pattern: BossPatternData) -> void:
	var distance: float = float(pattern.params.get("distance", 220.0))
	var radius: float = float(pattern.params.get("radius", 130.0))
	var rect: Rect2 = ctx.arena_rect().grow(-boss.radius - 40.0)
	var target: Vector2 = ctx.player.global_position + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU) * distance
	target = ctx.obstacles.push_out(target.clamp(rect.position, rect.end), boss.radius)
	var mist := Color(0.75, 0.82, 1.0, 0.6)
	ctx.fx.burst(boss.position, boss.radius * 1.6, mist)
	ctx.hazards.add_circle(target, radius, pattern.telegraph, _damage(pattern), true, data.id)
	boss.visual.visible = false
	boss.invulnerable_time = pattern.telegraph * 0.8
	busy_time = pattern.telegraph + 0.4
	schedule(pattern.telegraph * 0.8, func() -> void:
		boss.position = target
		boss.visual.visible = true
		ctx.fx.burst(target, boss.radius * 1.6, mist)
	)


## Secteur devant le boss (griffes, balayage de racines) : télégraphe en secteur, frappe unique.
func _pattern_sweep(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var radius: float = float(pattern.params.get("radius", 180.0))
	var half_deg: float = float(pattern.params.get("half_angle", 45.0))
	var origin: Vector2 = boss.position + dir * boss.radius * 0.3
	ctx.hazards.add_cone(origin, dir, radius, deg_to_rad(half_deg), pattern.telegraph, _damage(pattern), data.id)
	var props := {"radius": radius, "half_angle_degrees": half_deg}
	_telegraph(pattern, "cone", origin, dir, props)
	schedule(pattern.telegraph, func() -> void:
		_vfx(String(pattern.params.get("vfx", "")), origin, dir, props, CONTACT_STRIKE))
	busy_time = pattern.telegraph + float(pattern.params.get("recovery", 0.5))


## Écrasement : un impact par poing devant le boss (fists), zones télégraphiées.
func _pattern_slam(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var radius: float = float(pattern.params.get("radius", 150.0))
	var reach: float = float(pattern.params.get("reach", boss.radius + radius * 0.6))
	var spread: float = float(pattern.params.get("spread", 0.0))
	var fists: int = int(pattern.params.get("fists", 1))
	var area: Rect2 = ctx.arena_rect().grow(-radius * 0.5)
	for f: int in fists:
		var side: float = 0.0 if fists == 1 else (f / float(fists - 1) - 0.5) * 2.0
		var pos: Vector2 = (boss.position + dir * reach + dir.orthogonal() * spread * side).clamp(area.position, area.end)
		ctx.hazards.add_circle(pos, radius, pattern.telegraph, _damage(pattern), true, data.id)
		var props := {"radius": radius}
		_telegraph(pattern, "area", pos, dir, props)
		schedule(pattern.telegraph, func() -> void:
			_vfx(String(pattern.params.get("vfx", "")), pos, dir, props, CONTACT_SLAM)
			# Bûcher écrasé du gardien : l'impact laisse une plaque de sol brûlant (burn_time secondes).
			if pattern.params.has("burn_time") and ctx.burn:
				ctx.burn.add_plate(pos, float(pattern.params.get("burn_radius", radius)), float(pattern.params["burn_time"])))
	busy_time = pattern.telegraph + float(pattern.params.get("recovery", 0.6))


## Souffle : ligne depuis la gueule, verrouillée au lancement et arrêtée au premier obstacle réel (rochers-abris).
func _pattern_breath(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	boss.visual.set_facing_left(dir.x < 0.0, true)
	var mouth: Vector2 = _mouth()
	var length: float = clear_length(mouth, dir, float(pattern.params.get("length", 480.0)))
	var width: float = float(pattern.params.get("width", 80.0))
	var duration: float = float(pattern.params.get("duration", 1.0))
	ctx.hazards.add_beam(mouth, dir, length, width, pattern.telegraph, duration, _damage(pattern), data.id)
	var props := {"travel_distance": length, "width": width}
	_telegraph(pattern, "line", mouth, dir, props)
	schedule(pattern.telegraph, func() -> void:
		var fx_props := props.duplicate()
		fx_props["visual_duration"] = duration + 0.3
		_vfx(String(pattern.params.get("vfx", "")), mouth, dir, fx_props, CONTACT_STRIKE))
	busy_time = pattern.telegraph + duration + float(pattern.params.get("recovery", 0.4))


## Envol et chute (E9) : le boss s'envole, intouchable ; son ombre suit le Chasseur puis se fige, et il retombe sur le
## point marqué : impact, anneaux de lave à franchir (brèches ou Ruée) et sol brûlant.
func _pattern_skyfall(pattern: BossPatternData) -> void:
	var airborne: float = float(pattern.params.get("airborne", 1.6))
	var radius: float = float(pattern.params.get("radius", 170.0))
	boss.invulnerable_time = airborne + pattern.telegraph
	busy_time = airborne + pattern.telegraph + float(pattern.params.get("recovery", 0.8))
	ctx.fx.burst(boss.position, boss.radius * 1.4, Color(1.0, 0.5, 0.15, 0.5))
	schedule(0.35, func() -> void: boss.visual.visible = false)
	schedule(airborne, func() -> void:
		var area: Rect2 = ctx.arena_rect().grow(-boss.radius - 40.0)
		var target: Vector2 = ctx.obstacles.push_out(ctx.player.global_position.clamp(area.position, area.end), boss.radius)
		ctx.hazards.add_circle(target, radius, pattern.telegraph, _damage(pattern), true, data.id)
		schedule(pattern.telegraph, func() -> void:
			boss.position = target
			boss.visual.visible = true
			boss.visual.play_action(&"skyfall")
			ctx.fx.burst(target, radius * 1.2, Color(1.0, 0.45, 0.1, 0.6))
			for w: int in int(pattern.params.get("rings", 2)):
				schedule(w * 0.5, func() -> void:
					ctx.hazards.add_ring(target, float(pattern.params.get("ring_speed", 260.0)), 900.0, 24.0,
						_damage(pattern) * 0.5, true, data.id, [ctx.rng.randf() * TAU, ctx.rng.randf() * TAU], 0.45, [], 0.0))
			if ctx.burn:
				ctx.burn.add_plate(target, radius, float(pattern.params.get("burn_time", 6.0)))))


## Œil de la Faille (E13) : rayon qui balaie un arc devant le boss, arrêté par le décor (se cacher derrière un abri).
## Suite de tronçons courts qui tournent : on lit le sens du balayage et on se met à couvert.
func _pattern_eye_beam(pattern: BossPatternData) -> void:
	var dir: Vector2 = (ctx.player.global_position - boss.position).normalized()
	var arc: float = deg_to_rad(float(pattern.params.get("arc", 120.0)))
	var steps: int = int(pattern.params.get("steps", 10))
	var sweep_time: float = float(pattern.params.get("sweep_time", 2.0))
	var side: float = 1.0 if ctx.rng.randf() < 0.5 else -1.0
	var length: float = float(pattern.params.get("length", 900.0))
	var width: float = float(pattern.params.get("width", 40.0))
	var start: Vector2 = dir.rotated(-arc * 0.5 * side)
	var origin: Vector2 = _mouth()
	ctx.fx.danger_line(origin, origin + start * length, width, pattern.telegraph)
	for i: int in steps:
		var beam_dir: Vector2 = start.rotated(arc * side * i / float(maxi(steps - 1, 1)))
		schedule(pattern.telegraph + sweep_time * i / float(steps), func() -> void:
			var from: Vector2 = _mouth()
			ctx.hazards.add_beam(from, beam_dir, clear_length(from, beam_dir, length), width, 0.05,
				sweep_time / float(steps) + 0.05, _damage(pattern), data.id))
	busy_time = pattern.telegraph + sweep_time + float(pattern.params.get("recovery", 0.6))


## Mécaniques phares (BossSignatures, GuardianSignatures) et attaques de Glauquemire (GlauquemireMechanics).
func _pattern_source_orb(pattern: BossPatternData) -> void:
	signatures().source_orb(pattern)


func _pattern_star_crown(pattern: BossPatternData) -> void:
	signatures().star_crown(pattern)


func _pattern_crater_sequence(pattern: BossPatternData) -> void:
	signatures().crater_sequence(pattern)


func _pattern_mist_veil(pattern: BossPatternData) -> void:
	guardians().mist_veil(pattern)


func _pattern_pyre_ram(pattern: BossPatternData) -> void:
	guardians().pyre_ram(pattern)


func _pattern_mud_wall(pattern: BossPatternData) -> void:
	marsh().mud_wall(pattern)


func _pattern_root_leash(pattern: BossPatternData) -> void:
	marsh().root_leash(pattern)


func _pattern_leech_feed(pattern: BossPatternData) -> void:
	marsh().leech_feed(pattern)


func _pattern_prism_beam(pattern: BossPatternData) -> void:
	marsh().prism_beam(pattern)


func _pattern_whirlpool(pattern: BossPatternData) -> void:
	marsh().whirlpool(pattern)


func _pattern_swallow(pattern: BossPatternData) -> void:
	marsh().swallow(pattern)


## Longueur dégagée d'une ligne : jusqu'au premier décor qui arrête les tirs (rochers-abris).
func clear_length(origin: Vector2, dir: Vector2, length: float) -> float:
	return ctx.obstacles.clear_distance(origin, dir, length)


func _mouth() -> Vector2:
	var offset: Vector2 = data.mouth_offset
	if ctx.player.global_position.x < boss.position.x:
		offset.x = -offset.x
	return boss.position + offset


## Télégraphe peint (indicator.tscn) de la géométrie exacte de l'attaque, retiré à la frappe, au changement de phase
## ou à la mort. Le repère du jeu reste dessiné, plus discret.
func _telegraph(pattern: BossPatternData, shape: String, pos: Vector2, dir: Vector2, props: Dictionary) -> void:
	if data.vfx_dir == "" or pattern.params.get("vfx", "") == "":
		return
	ctx.hazards.mark_last_painted()
	var indicator_props := props.duplicate()
	indicator_props["target_shape"] = StringName(shape)
	indicator_props["loop_visual"] = true
	indicator_props["visual_duration"] = maxf(pattern.telegraph, 0.3)
	var fx: Node2D = _vfx("indicator", pos, dir, indicator_props, -1.0, true)
	if fx == null:
		return
	_indicators.append(fx)
	schedule(pattern.telegraph, func() -> void:
		if is_instance_valid(fx):
			fx.call("release")
		_indicators.erase(fx))


func _clear_indicators() -> void:
	for fx: Node2D in _indicators:
		if is_instance_valid(fx):
			fx.queue_free()
	_indicators.clear()


## Effet peint du boss (scène autonome) : position et géométrie fournies par le combat. contact >= 0 : démarre au repère
## de contact (frappe déjà confirmée). required : télégraphes, mort, transformation (jamais supprimés par le plafond).
func _vfx(scene_name: String, pos: Vector2, dir: Vector2, props: Dictionary = {}, contact: float = -1.0,
		required: bool = false) -> Node2D:
	if data.vfx_dir == "" or scene_name == "":
		return null
	_effects.assign(_effects.filter(func(fx: Variant) -> bool: return is_instance_valid(fx)))
	if not required and _effects.size() >= MAX_EFFECTS:
		return null
	var path: String = data.vfx_dir.path_join(scene_name + ".tscn")
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	if _scenes[path] == null:
		return null
	var fx: Node2D = (_scenes[path] as PackedScene).instantiate()
	for key: String in props:
		fx.set(key, props[key])
	fx.set("phase2", phase_index > 0)
	fx.position = pos
	ctx.world.add_child(fx)
	if contact >= 0.0:
		fx.call("play_from", float(fx.call("duration")) * contact, dir)
	else:
		fx.call("play", dir)
	if not required:
		_effects.append(fx)
	return fx
