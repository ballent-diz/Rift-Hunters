class_name NivorathMechanics
extends BossMechanics
## Nivorath, Dévoreur du chapitre 4 (docs/design/MONSTRES.md) :
## - Écho des sorts (mécanique phare, `spell_capture`) : il ouvre sa gueule de cristal ; chaque sort que le Chasseur
##   lance pendant ce temps est aspiré (il ne le blesse pas) puis renvoyé, amplifié, en couronne de tirs. Si aucun sort
##   n'a été lancé, il s'étouffe : sonné et vulnérable. Le Chasseur choisit donc quand lancer.
## - Pics de glace (ligne), banquise qui éclate autour de lui (phase 3), plongée sous la glace (phase 3).

const ICE := Color(0.75, 0.92, 1.0)
const RIFT := Color(0.7, 0.45, 1.0)

## Capture en cours : {"opens", "until", "count", "damage", "per", "stun"} (vide : aucune).
var capture: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	super.setup(p_ctx, p_brain)
	name = "NivorathMechanics"
	ctx.combat.add_damage_modifier(_damage_modifier)
	ctx.events.spell_cast.connect(_on_spell_cast)


func step(delta: float) -> void:
	super.step(delta)
	if not capture.is_empty() and ctx.time >= float(capture["until"]):
		_release()
	queue_redraw()


func finish() -> void:
	capture = {}
	queue_redraw()


func capturing() -> bool:
	return not capture.is_empty() and ctx.time >= float(capture["opens"])


## Gueule ouverte : les sorts qui le touchent sont aspirés, sans dégâts.
func _damage_modifier(enemy: Enemy, info: DamageInfo) -> float:
	if brain == null or enemy != boss() or not capturing() or not info.tags.has(DamageInfo.TAG_SPELL):
		return 1.0
	return 0.0


func _on_spell_cast(_id: StringName) -> void:
	if not capturing() or brain == null or not boss().alive:
		return
	capture["count"] = int(capture["count"]) + 1
	ctx.fx.danger_line(ctx.player.global_position, boss().position, 6.0, 0.4)
	ctx.fx.ring(boss().position, boss().radius * 1.4, Color(RIFT, 0.8), 0.4)
	ctx.stats.add(&"boss_spells_captured")


# --- Écho des sorts -------------------------------------------------------------------------------------------

func spell_capture(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	capture = {"opens": ctx.time + pattern.telegraph, "until": ctx.time + pattern.telegraph
		+ float(params.get("duration", 3.5)), "count": 0, "damage": brain._damage(pattern),
		"per": int(params.get("per_spell", 12)), "stun": float(params.get("stun", 3.0))}
	ctx.fx.ring(boss().position, boss().radius * 2.2, Color(RIFT, 0.9), pattern.telegraph)
	intro("BOSS_CAPTURE_INTRO")
	brain.busy_time = pattern.telegraph + float(params.get("duration", 3.5)) + 0.6


func _release() -> void:
	if ctx.pixel_fx:
		ctx.pixel_fx.technique(boss(), &"spell_capture_release")
	var count: int = capture["count"]
	var damage: float = capture["damage"]
	var per: int = capture["per"]
	var stun: float = capture["stun"]
	capture = {}
	if brain == null or not boss().alive:
		return
	if count == 0:
		# Rien à renvoyer : il s'étouffe, sonné et vulnérable.
		brain.stun(stun)
		brain.heart_time = stun
		ctx.fx.burst(boss().position, boss().radius * 1.8, Color(ICE, 0.6))
		ctx.stats.add(&"boss_capture_choked")
		return
	boss().visual.play_action(&"spell_release")
	ctx.stats.add(&"boss_spells_released")
	for wave: int in mini(count, 3):
		brain.schedule(wave * 0.45, func() -> void:
			var offset: float = ctx.rng.randf() * TAU
			for i: int in per:
				var dir: Vector2 = Vector2.RIGHT.rotated(offset + TAU * i / per)
				ctx.projectiles.spawn_hostile(boss().position + dir * boss().radius, dir, 300.0,
					damage * (1.0 + 0.25 * (count - 1)), brain.data.id, 12.0, 3.0)
			ctx.fx.burst(boss().position, boss().radius * 2.0, Color(RIFT, 0.5)))


# --- Pics de glace, banquise, plongée ---------------------------------------------------------------------------

## Pics de glace : une ligne de pics jaillit vers le Chasseur.
func ice_spikes(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var lines: int = int(params.get("lines", 1))
	var radius: float = float(params.get("radius", 60.0))
	var length: float = float(params.get("length", 700.0))
	var base: Vector2 = (ctx.player.global_position - boss().position).normalized()
	for l: int in lines:
		var dir: Vector2 = base.rotated((l - (lines - 1) * 0.5) * deg_to_rad(float(params.get("spread", 25.0))))
		var d: float = boss().radius + radius
		var k: int = 0
		while d <= length:
			var pos: Vector2 = boss().position + dir * d
			ctx.hazards.add_circle(pos, radius, pattern.telegraph + k * 0.05, brain._damage(pattern), true, brain.data.id)
			d += radius * 1.6
			k += 1
	brain.busy_time = pattern.telegraph + 0.5


## Banquise qui éclate : des plaques de glace cèdent autour de lui, puis restent glissantes et lentes.
func shatter_floor(pattern: BossPatternData) -> void:
	var params: Dictionary = pattern.params
	var radius: float = float(params.get("radius", 90.0))
	var area: Rect2 = ctx.arena_rect().grow(-radius)
	for ring: float in params.get("rings", [220.0, 400.0]):
		var count: int = maxi(int(TAU * ring / (radius * 2.6)), 4)
		var offset: float = ctx.rng.randf() * TAU
		for i: int in count:
			var pos: Vector2 = (boss().position + Vector2.RIGHT.rotated(offset + TAU * i / count) * ring).clamp(
				area.position, area.end)
			ctx.hazards.add_circle(pos, radius, pattern.telegraph, brain._damage(pattern), true, brain.data.id)
			if ctx.burn:
				brain.schedule(pattern.telegraph, func() -> void:
					ctx.burn.add_plate(pos, radius, float(params.get("duration", 6.0)), false, 0.55))
	intro("BOSS_SHATTER_INTRO")
	brain.busy_time = pattern.telegraph + 0.6


## Plongée sous la glace : même lecture que la Gueule des marais (ride, onde annoncée, sortie sonnée).
func frozen_dive(pattern: BossPatternData) -> void:
	brain.marsh_guardians().maw_dive(pattern)


# --- Bot ------------------------------------------------------------------------------------------------------

## Gueule ouverte : ne rien lancer (il s'étouffe).
func bot_hold_spells() -> bool:
	return not capture.is_empty()


# --- Dessin ---------------------------------------------------------------------------------------------------

func _draw() -> void:
	if capture.is_empty() or brain == null or not boss().alive:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * 8.0)
	var radius: float = boss().radius * (1.6 + 0.2 * pulse)
	draw_arc(boss().position, radius, 0.0, TAU, 48, Color(RIFT, 0.5 + 0.4 * pulse) if capturing() else Color(RIFT, 0.3),
		4.0)
	for i: int in int(capture["count"]):
		var angle: float = _time * 3.0 + TAU * i / maxf(float(capture["count"]), 1.0)
		draw_circle(boss().position + Vector2.RIGHT.rotated(angle) * boss().radius * 0.6, 8.0, Color(RIFT, 0.9))
