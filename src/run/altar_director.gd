class_name AltarDirector
extends Node2D
## Mode « défense d'autel » (docs/design/CARTES.md, carte 4 du chapitre 1) : un sceau ancien à protéger pendant
## plusieurs vagues qui arrivent de plusieurs côtés. Une partie des Corrompus de corps à corps (les pillards) marche
## vers l'autel et l'abîme à son contact. Entre deux vagues, l'autel se répare et un coffre tombe ; après la dernière,
## le sceau se brise (son onde purifie les Corrompus restants) et libère le gardien de la carte (ArenaData.boss_id),
## qui en sort ; le sceau disparaît avec sa collision et le combat s'étend à toute la carte. Autel détruit pendant
## les vagues : l'expédition est perdue.
## Visuel : « object.altar_seal » (Codex) — intact, endommagé sous DAMAGED_RATIO de PV, éclat quand il est frappé,
## onde quand il se brise ; disque provisoire dessiné si la feuille manque.

enum Phase { START, WAVE, PAUSE, BOSS }

const START_DELAY := 4.0
## Part des PV de l'autel rendue au début de chaque pause.
const REPAIR_RATIO := 0.15
## Distance d'apparition autour de l'autel quand la carte ne donne pas de points d'arrivée.
const SPAWN_DISTANCE := 950.0
## Au-delà de cette distance, une flèche ramène le Chasseur vers l'autel.
const ROUTE_DISTANCE := 340.0
## Pillards qui frappent l'autel en même temps au plus (les autres se pressent derrière).
const MAX_ATTACKERS := 6
## Sous cette part de PV, le sceau s'affiche fendu (fissures violettes).
const DAMAGED_RATIO := 0.5
const VISUAL_ID := &"object.altar_seal"
## Demi-largeur du sceau dans sa cellule (pixels de la feuille, cellule de 512).
const SEAL_HALF_WIDTH := 220.0
## Haut et bas du sceau dans sa cellule : la barre de vie se place juste au-dessus, la collision couvre le tout.
const SEAL_TOP := 6.0
const SEAL_BOTTOM := 400.0
## Les Corrompus frappent le sceau à cette distance de son bord (le repoussement du décor les tient un peu à l'écart).
const CONTACT_MARGIN := 40.0
## Intégration au décor : teinte accordée aux cartes peintes (un peu moins saturée et plus chaude), ombre portée vers
## le bas à droite (lumière haut-gauche, ART_BIBLE) et assombrissement au contact du sol.
const SEAL_TINT := Color(0.93, 0.91, 0.86)
const SHADOW_OFFSET := Vector2(10.0, 12.0)
const STONE := Color(0.42, 0.44, 0.5)
const RUNE := Color(0.72, 0.5, 1.0)

var ctx: RunContext
var hp: float = 0.0
var max_hp: float = 0.0
var phase: Phase = Phase.START
## Vague en cours (0 à waves() - 1).
var wave_index: int = 0
var destroyed: bool = false
## Sceau brisé (après la dernière vague) : plus d'image, plus de collision.
var shattered: bool = false
## Navigation vers l'autel (pillards et flèche de route), calculée une fois : l'autel ne bouge pas.
var guide: FlowField
var _timer: float = START_DELAY
var _budget: float = 0.0
var _elite_spawned: bool = false
var _flash: float = 0.0
var _time: float = 0.0
## Sprite du sceau (état) et surcouche des effets ponctuels (éclat, onde) ; null sans feuille.
var _seal: AnimatedSprite2D
var _burst: AnimatedSprite2D
## Barre de vie au-dessus du sceau (dessinée par-dessus le sprite).
var _bar: Node2D
## Emprise solide du sceau (centre relatif et rayon) : personne ne le traverse.
var _body_center := Vector2.ZERO
var _body_radius: float = 0.0
var _body_index: int = -1


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Altar"
	z_index = -1
	position = ctx.obstacles.push_out(ctx.arena.altar_point, ctx.arena.altar_radius)
	max_hp = ctx.arena.altar_hp
	hp = max_hp
	guide = FlowField.new()
	guide.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	guide.apply_walls(ctx.obstacles)
	guide.update(position)
	_build_visual()
	_build_body()
	_start.call_deferred()


func _build_visual() -> void:
	var frames: SpriteFrames = Assets.get_sprite_frames(VISUAL_ID)
	if frames == null:
		return
	var offset: Vector2 = -Assets.anchor(VISUAL_ID)
	var scale_factor: float = Assets.pixel_scale(VISUAL_ID)
	for i: int in 2:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.centered = false
		sprite.offset = offset
		sprite.scale = Vector2.ONE * scale_factor
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		if i == 0:
			_seal = sprite
		else:
			_burst = sprite
	_seal.modulate = SEAL_TINT
	_seal.play(&"intact")
	_bar = Node2D.new()
	_bar.z_index = 1
	add_child(_bar)
	_bar.draw.connect(_draw_health_bar)
	_burst.visible = false
	_burst.animation_finished.connect(func() -> void: _burst.visible = false)


## Le sceau entier est un obstacle (après la navigation des pillards, qui marchent droit sur lui).
func _build_body() -> void:
	_body_radius = ctx.arena.altar_radius
	if _seal:
		var s: float = Assets.pixel_scale(VISUAL_ID)
		var anchor_y: float = Assets.anchor(VISUAL_ID).y
		_body_center = Vector2(0.0, ((SEAL_TOP + SEAL_BOTTOM) * 0.5 - anchor_y) * s)
		_body_radius = maxf(SEAL_HALF_WIDTH, (SEAL_BOTTOM - SEAL_TOP) * 0.5) * s
	_body_index = ctx.obstacles.add(position + _body_center, _body_radius)


## Le sceau disparaît (l'onde joue une dernière fois par-dessus) et libère la place : collision retirée, navigation
## rouverte.
func _shatter() -> void:
	shattered = true
	if _body_index >= 0:
		ctx.obstacles.remove(_body_index)
		_body_index = -1
		if ctx.flow:
			ctx.flow.apply_walls(ctx.obstacles)
	if _seal:
		_seal.visible = false
		_play_burst(&"seal_wave")
		# L'image de l'onde porte encore le sceau : elle s'efface pendant l'animation.
		create_tween().tween_property(_burst, "modulate:a", 0.0, 0.7)
	queue_redraw()


## État affiché du sceau (intact, endommagé, scellé).
func visual_state() -> StringName:
	if phase == Phase.BOSS:
		return &"sealed"
	if destroyed or hp < max_hp * DAMAGED_RATIO:
		return &"damaged"
	return &"intact"


func _play_burst(anim: StringName) -> void:
	if _burst == null or (_burst.visible and _burst.animation == &"seal_wave"):
		return
	if anim == &"hit" and _burst.visible:
		return
	_burst.visible = true
	_burst.play(anim)
	_burst.frame = 0


func _start() -> void:
	ctx.events.event_started.emit(TranslationServer.translate("ALTAR_INTRO") % waves())


func waves() -> int:
	return ctx.arena.altar_waves


## Secondes restantes avant la prochaine étape (début de vague ou fin de vague).
func time_left() -> float:
	return maxf(_timer, 0.0)


func step(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	if _seal and _seal.animation != visual_state():
		_seal.play(visual_state())
	if _seal and destroyed:
		_seal.modulate = SEAL_TINT * Color(0.6, 0.55, 0.65)
	queue_redraw()
	if _bar:
		_bar.queue_redraw()
	if destroyed or phase == Phase.BOSS:
		return
	_suffer_contacts(delta)
	match phase:
		Phase.START, Phase.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_begin_wave()
		Phase.WAVE:
			_timer -= delta
			_spawn(delta)
			if _timer <= 0.0:
				_end_wave()


func _begin_wave() -> void:
	phase = Phase.WAVE
	_timer = ctx.arena.altar_wave_duration
	_budget = 0.0
	_elite_spawned = false
	ctx.events.event_started.emit(TranslationServer.translate("ALTAR_WAVE") % [wave_index + 1, waves()])


func _end_wave() -> void:
	ctx.stats.add(&"altar_waves")
	ctx.events.milestone_reached.emit()
	if wave_index + 1 >= waves():
		# Le sceau se brise : son onde purifie les Corrompus restants (leur XP tombe) et le gardien en sort ; le
		# combat commence sur un terrain dégagé.
		phase = Phase.BOSS
		var purge: DamageInfo = DamageInfo.make(1e9, DamageInfo.SourceKind.PLAYER, &"altar", [DamageInfo.TAG_EXPLOSION])
		for enemy: Enemy in ctx.enemies.list.duplicate():
			if enemy.alive and not enemy.is_boss and not enemy.is_obstacle:
				ctx.combat.deal_damage(enemy, purge)
		ctx.fx.ring(position, 1400.0, Color(RUNE, 0.6), 0.6)
		ctx.fx.burst(position, ctx.arena.altar_radius * 2.5, Color(RUNE, 0.6))
		_shatter()
		ctx.events.event_started.emit("ALTAR_SHATTERED")
		ctx.spawner.spawn_boss(position + _body_center)
		return
	wave_index += 1
	phase = Phase.PAUSE
	_timer = ctx.arena.altar_wave_pause
	hp = minf(max_hp, hp + max_hp * REPAIR_RATIO)
	ctx.fx.burst(position, ctx.arena.altar_radius * 2.0, Color(RUNE, 0.5))
	ctx.events.chest_collected.emit()
	ctx.events.event_started.emit(TranslationServer.translate("ALTAR_WAVE_HELD") % [wave_index, waves()])


## Corrompus au contact : chacun inflige une part de ses dégâts de contact (altar_damage_mult) au rythme des coups au
## Chasseur, MAX_ATTACKERS au plus à la fois.
func _suffer_contacts(delta: float) -> void:
	var reach: float = _body_radius + CONTACT_MARGIN
	var rate: float = delta / maxf(ctx.balance.contact_damage_interval, 0.05) * ctx.arena.altar_damage_mult
	var attackers: int = 0
	var center: Vector2 = position + _body_center
	for enemy: Enemy in ctx.enemies.query_radius(center, reach + 40.0):
		if attackers >= MAX_ATTACKERS:
			break
		if not enemy.alive or enemy.is_boss or enemy.is_obstacle:
			continue
		if enemy.position.distance_to(center) > reach + enemy.radius:
			continue
		hp -= enemy.contact_damage * rate
		attackers += 1
		if _flash <= 0.0:
			_play_burst(&"hit")
		_flash = 0.2
	if hp <= 0.0:
		hp = 0.0
		destroyed = true
		ctx.fx.burst(position, ctx.arena.altar_radius * 3.0, Color(1.0, 0.3, 0.5, 0.7))
		ctx.events.event_started.emit("ALTAR_DESTROYED")


func _spawn(delta: float) -> void:
	var wave: WavePhaseData = ctx.spawner.current_wave()
	if wave == null:
		return
	var rate: float = ctx.arena.altar_spawn_rate * (1.0 + 0.2 * wave_index) * ctx.difficulty.spawn_rate_mult
	_budget = minf(_budget + rate * delta, 8.0)
	var alive: int = ctx.enemies.count()
	while _budget >= 1.0 and alive < ctx.spawner.current_cap():
		_budget -= 1.0
		var data: EnemyData = ctx.spawner.pick_enemy(wave)
		if data:
			_spawn_enemy(data)
			alive += 1
	# À partir de la deuxième vague, une élite à mi-vague.
	if wave_index >= 1 and not _elite_spawned and _timer <= ctx.arena.altar_wave_duration * 0.5:
		_elite_spawned = true
		var elite: Enemy = ctx.spawner.spawn_elite(&"", spawn_position())
		if elite:
			_make_raider(elite)


func _spawn_enemy(data: EnemyData) -> void:
	var enemy: Enemy = ctx.enemies.spawn(data, spawn_position())
	if enemy and data.brain == EnemyData.Brain.CHASER and ctx.rng.randf() < ctx.arena.altar_raider_share:
		_make_raider(enemy)


## Pillard : marche vers l'autel (navigation propre) au lieu de chasser le Chasseur.
func _make_raider(enemy: Enemy) -> void:
	enemy.taunt_target = self
	enemy.taunt_time = INF
	enemy.goal_flow = guide


## Point d'arrivée : un des points de la carte, ou un cercle autour de l'autel ; jamais sur le Chasseur.
func spawn_position() -> Vector2:
	var points: Array[Vector2] = ctx.arena.altar_spawn_points
	for attempt: int in 8:
		var pos: Vector2
		if points.is_empty():
			pos = position + Vector2.from_angle(ctx.rng.randf() * TAU) * SPAWN_DISTANCE
		else:
			pos = points[ctx.rng.randi() % points.size()] + Vector2.from_angle(ctx.rng.randf() * TAU) * 80.0
		pos = ctx.obstacles.push_out(pos.clamp(ctx.arena_rect().position, ctx.arena_rect().end), 20.0)
		if pos.distance_to(ctx.player.global_position) > 300.0:
			return pos
	return position + Vector2.from_angle(ctx.rng.randf() * TAU) * SPAWN_DISTANCE


## Flèche de route : vers l'autel quand le Chasseur s'en éloigne (rien pendant le combat du gardien).
func objective_direction(pos: Vector2) -> Vector2:
	if phase == Phase.BOSS or pos.distance_to(position) < ROUTE_DISTANCE:
		return Vector2.ZERO
	return guide.direction(pos, (position - pos).normalized())


func _draw() -> void:
	if shattered:
		return
	var r: float = ctx.arena.altar_radius if ctx else 70.0
	if _seal:
		_draw_ground_shadow()
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.2)
	draw_circle(Vector2.ZERO, r * 1.25, Color(0.0, 0.0, 0.0, 0.3))
	draw_circle(Vector2.ZERO, r, STONE.darkened(0.35))
	draw_circle(Vector2.ZERO, r * 0.78, STONE)
	for i: int in 6:
		var a: float = TAU * i / 6.0 + _time * 0.3
		draw_circle(Vector2.from_angle(a) * r * 0.58, 5.0, Color(RUNE, 0.6 + 0.4 * pulse))
	var core: Color = Color(1.0, 0.45, 0.55) if _flash > 0.0 else RUNE
	draw_circle(Vector2.ZERO, r * 0.28, Color(core, 0.75 + 0.25 * pulse))
	_draw_gauge(r)


## Ombre portée et contact au sol, dessinés sous le sprite (le nœud dessine avant ses enfants).
func _draw_ground_shadow() -> void:
	var radius: float = SEAL_HALF_WIDTH * Assets.pixel_scale(VISUAL_ID)
	for i: int in 4:
		var t: float = i / 4.0
		draw_circle(_body_center + SHADOW_OFFSET * (1.0 - t * 0.5), radius * (1.08 - t * 0.12), Color(0.0, 0.0, 0.04, 0.07 + 0.03 * i))


## Barre de vie juste au-dessus du sceau (rien une fois détruit ou scellé).
func _draw_health_bar() -> void:
	if destroyed or phase == Phase.BOSS:
		return
	var scale_factor: float = Assets.pixel_scale(VISUAL_ID)
	var width: float = SEAL_HALF_WIDTH * scale_factor * 1.2
	var top: float = (SEAL_TOP - Assets.anchor(VISUAL_ID).y) * scale_factor - 18.0
	var rect := Rect2(Vector2(-width * 0.5, top), Vector2(width, 9.0))
	var ratio: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var fill := Color(0.45, 0.9, 0.6) if ratio >= DAMAGED_RATIO else Color(0.95, 0.4, 0.55)
	if _flash > 0.0:
		fill = fill.lightened(0.5)
	_bar.draw_rect(rect.grow(2.0), Color(0.02, 0.02, 0.05, 0.85))
	_bar.draw_rect(rect, Color(0.12, 0.1, 0.16))
	_bar.draw_rect(Rect2(rect.position, Vector2(width * ratio, rect.size.y)), fill)


## Jauge de l'autel (disque provisoire, sans feuille) : arc au sol qui se vide avec ses PV (rien une fois détruit ou scellé).
func _draw_gauge(r: float) -> void:
	if destroyed or phase == Phase.BOSS:
		return
	var ratio: float = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var color := Color(0.6, 1.0, 0.75, 0.9) if ratio >= DAMAGED_RATIO else Color(1.0, 0.55, 0.75, 0.9)
	# Sur le contour du socle peint (ou de l'emprise si le sceau n'a pas de feuille).
	var radius: float = SEAL_HALF_WIDTH * Assets.pixel_scale(VISUAL_ID) + 2.0 if _seal else r + 10.0
	draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * ratio, 64, color, 5.0, true)
