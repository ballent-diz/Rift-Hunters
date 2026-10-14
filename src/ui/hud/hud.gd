class_name Hud
extends Control
## Interface de combat dessinée en un passage : PV, XP, temps, équipe et Techniques, synergies, boss, bannières.

## Conseils de première partie : [instant (s), clé de traduction].
const TUTORIAL_TIPS := [[2.0, "TIP_MOVE"], [9.0, "TIP_AUTO_ATTACK"], [18.0, "TIP_TECHNIQUES"], [32.0, "TIP_FOCUS"],
	[48.0, "TIP_DASH"], [70.0, "TIP_CHESTS"], [100.0, "TIP_BOSS"]]

var ctx: RunContext
var _font: Font
var _banner_text: String = ""
var _banner_time: float = 0.0
var _icons: Dictionary = {}
var _beat: float = 0.0
var _tips: Array = []
var _tip_text: String = ""
var _tip_time: float = 0.0


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	_font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctx.events.event_started.connect(func(key: String) -> void: banner(tr(key)))
	ctx.events.synergy_activated.connect(func(id: StringName) -> void:
		banner(tr("HUD_SYNERGY_ACTIVATED") % tr(GameDB.synergies[id].name_key)))
	ctx.events.boss_spawned.connect(func(boss: Enemy) -> void:
		banner(tr("HUD_BOSS_ARRIVES") % boss.display_name()))
	ctx.events.boss_phase_changed.connect(func(_phase: int) -> void: banner(tr("HUD_BOSS_PHASE2")))
	Audio.beat.connect(func(_index: int) -> void: _beat = 1.0)
	if ctx.setup.show_tutorial:
		_tips = TUTORIAL_TIPS.duplicate()
	ctx.events.evolution_taken.connect(func(_id: StringName, evo_id: StringName) -> void:
		for monster: MonsterData in GameDB.monsters.values():
			for evo: EvolutionData in monster.evolutions:
				if evo.id == evo_id:
					banner(tr("HUD_EVOLUTION") % tr(evo.name_key)))


func banner(text: String) -> void:
	_banner_text = text
	_banner_time = 3.0


func _process(delta: float) -> void:
	_banner_time = maxf(_banner_time - delta, 0.0)
	_beat = maxf(_beat - delta * 4.0, 0.0)
	_tip_time = maxf(_tip_time - delta, 0.0)
	if ctx and not _tips.is_empty() and ctx.time >= float(_tips[0][0]):
		_tip_text = tr(str(_tips[0][1]))
		_tip_time = 7.0
		_tips.pop_front()
	if ctx and ctx.player:
		ctx.player.hurt_flash = maxf(ctx.player.hurt_flash - delta * 3.0, 0.0)
	queue_redraw()


func _text(pos: Vector2, value: String, font_size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	# Contour épais et opaque : texte lisible sur les sols clairs (herbe, sable, neige).
	draw_string_outline(_font, pos, value, align, width, font_size, 7, Color(0.02, 0.02, 0.05, 1.0))
	draw_string(_font, pos, value, align, width, font_size, color)


func _bar(rect: Rect2, ratio: float, fill: Color, back: Color = Color(0.05, 0.05, 0.09, 0.85)) -> void:
	draw_rect(rect.grow(2.0), Color(0, 0, 0, 0.7))
	draw_rect(rect, back)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), fill)


func _draw() -> void:
	if ctx == null or ctx.player == null:
		return
	var w: float = size.x
	var h: float = size.y
	var player: Player = ctx.player
	_draw_vignette(w, h, player)
	# Barre d'XP (haut, pulse sur le tempo de la musique) + niveau
	var pulse: float = 0.0 if Settings.reduce_flashes else _beat
	_bar(Rect2(0, 0, w, 10 + 3.0 * pulse), player.xp_ratio(), Color(0.35, 0.85, 1.0).lightened(0.3 * pulse))
	_text(Vector2(16, 40), tr("HUD_LEVEL") % player.level, 22, UiKit.ACCENT)
	# PV + bouclier
	var hp_rect := Rect2(16, 52, 260, 18)
	_bar(hp_rect, player.hp / player.max_hp, Color(0.9, 0.25, 0.35))
	if player.shield > 0.0:
		draw_rect(Rect2(hp_rect.position + Vector2(0, -5), Vector2(minf(player.shield * 2.0, 260.0), 4)), Color(1.0, 0.95, 0.6))
	_text(hp_rect.position + Vector2(8, 15), "%d / %d" % [int(ceil(player.hp)), int(player.max_hp)], 15, Color.WHITE)
	# Ruée
	var dash_cd: float = player.dash_cooldown_left
	var dash_text: String = tr("HUD_DASH_READY") if dash_cd <= 0.0 else tr("HUD_DASH_CD") % dash_cd
	_text(Vector2(16, 96), dash_text, 15, UiKit.MUTED if dash_cd > 0.0 else UiKit.ACCENT)
	# Temps + éliminations
	var minutes: int = int(ctx.time) / 60
	var seconds: int = int(ctx.time) % 60
	_text(Vector2(0, 44), "%02d:%02d" % [minutes, seconds], 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
	if ctx.finale and ctx.finale.state >= ArenaFinale.State.CLEARING:
		var key: String = "FINALE_CLEAR"
		if ctx.finale.state == ArenaFinale.State.TRAVEL:
			key = "FINALE_TRAVEL"
		elif ctx.finale.state >= ArenaFinale.State.OPENING:
			key = "FINALE_OPENING" if ctx.finale.state == ArenaFinale.State.OPENING else "FINALE_FIGHT"
		_text(Vector2(0, 66), tr(key), 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
	elif ctx.boss == null:
		var left: float = maxf(ctx.arena.boss_time - ctx.time, 0.0)
		_text(Vector2(0, 66), tr("HUD_NAMED_BOSS_IN") % [tr(GameDB.boss(ctx.arena.boss_id).name_key), int(left) / 60, int(left) % 60], 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
	var kills: int = int(ctx.stats.get_value(&"kills"))
	_text(Vector2(w - 220, 40), tr("HUD_KILLS") % kills, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	_text(Vector2(w - 220, 62), tr("HUD_RELICS") % ctx.build.relics.size(), 15, UiKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	# Synergies actives
	var y: float = 96.0
	for synergy_id: StringName in ctx.build.active_synergies:
		var synergy: SynergyData = GameDB.synergies[synergy_id]
		_text(Vector2(w - 320, y), "◆ " + tr(synergy.name_key), 15, synergy.color, HORIZONTAL_ALIGNMENT_RIGHT, 300)
		y += 20.0
	_draw_team(w, h)
	_draw_boss(w)
	if _banner_time > 0.0:
		var alpha: float = clampf(_banner_time, 0.0, 1.0)
		_text(Vector2(0, h * 0.28), _banner_text, 30, Color(1.0, 0.92, 0.6, alpha), HORIZONTAL_ALIGNMENT_CENTER, w)
	if _tip_time > 0.0:
		var tip_alpha: float = clampf(_tip_time, 0.0, 1.0)
		draw_rect(Rect2(w * 0.2, h - 172, w * 0.6, 34), Color(0.05, 0.06, 0.1, 0.75 * tip_alpha))
		_text(Vector2(0, h - 148), _tip_text, 17, Color(0.85, 0.95, 1.0, tip_alpha), HORIZONTAL_ALIGNMENT_CENTER, w)
	if Settings.show_fps:
		_text(Vector2(w - 120, h - 12), "%d FPS" % Engine.get_frames_per_second(), 14, UiKit.MUTED)


## Vignette : rouge bref quand le Chasseur est touché, pulsation lente sous 30 % de PV.
func _draw_vignette(w: float, h: float, player: Player) -> void:
	var intensity: float = player.hurt_flash * (0.25 if Settings.reduce_flashes else 0.55)
	var ratio: float = player.hp / maxf(player.max_hp, 1.0)
	if ratio < 0.3 and player.alive:
		var wave: float = 0.5 if Settings.reduce_flashes else 0.5 + 0.5 * sin(ctx.time * 5.0)
		intensity = maxf(intensity, (0.3 - ratio) / 0.3 * 0.35 * wave + 0.08)
	if intensity <= 0.01:
		return
	var color := Color(0.9, 0.05, 0.15, intensity)
	var thickness: float = 60.0
	for i: int in 6:
		var t: float = thickness * (1.0 - i / 6.0)
		var c := Color(color, color.a * (i + 1) / 6.0 * 0.5)
		draw_rect(Rect2(0, 0, w, t), c)
		draw_rect(Rect2(0, h - t, w, t), c)
		draw_rect(Rect2(0, 0, t, h), c)
		draw_rect(Rect2(w - t, 0, t, h), c)


func _draw_team(w: float, h: float) -> void:
	var team: Array[Ally] = ctx.allies.team
	var card_w: float = 210.0
	var total: float = card_w * team.size() + 12.0 * maxf(team.size() - 1, 0.0)
	var x: float = (w - total) * 0.5
	var y: float = h - 86.0
	for i: int in team.size():
		var ally: Ally = team[i]
		var rect := Rect2(x, y, card_w, 72)
		draw_rect(rect, Color(0.07, 0.08, 0.13, 0.85))
		draw_rect(rect, ally.data.visual.primary, false, 2.0)
		var icon: Texture2D = _icon_for(ally)
		if icon:
			draw_texture_rect(icon, Rect2(rect.position + Vector2(6, 8), Vector2(56, 56)), false)
		_text(rect.position + Vector2(68, 22), ally.display_name(), 16, Color.WHITE)
		_text(rect.position + Vector2(68, 40), tr("HUD_RANK") % ally.rank, 13, UiKit.MUTED)
		var tech: TechniqueData = ally.technique
		if tech:
			var cd: float = ally.technique_cd
			var ready: bool = cd <= 0.0
			var key_text: String = "[%d] " % (i + 1)
			var label: String = key_text + (tr(tech.name_key) if ready else "%.1fs" % cd)
			_text(rect.position + Vector2(68, 60), label, 14, UiKit.GOLD if ready else UiKit.MUTED)
			if not ready:
				var ratio: float = cd / maxf(ally.technique_cooldown(), 0.01)
				draw_rect(Rect2(rect.position + Vector2(0, 70), Vector2(card_w * (1.0 - ratio), 2)), UiKit.GOLD)
		x += card_w + 12.0
	if ctx.allies.has_free_slot():
		var free: int = ctx.allies.team_slots() - team.size()
		_text(Vector2(0, h - 96), tr("HUD_FREE_SLOT") % free, 13, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)


func _icon_for(ally: Ally) -> Texture2D:
	var visual: VisualData = ally.evolution.visual if (ally.evolution and ally.evolution.visual) else ally.data.visual
	var key: String = String(visual.visual_id) + str(visual.get_instance_id())
	if not _icons.has(key):
		var icon: Texture2D = Assets.icon(visual.visual_id)
		_icons[key] = icon if icon else Assets.placeholder(visual)[0]
	return _icons[key]


func _draw_boss(w: float) -> void:
	var boss: Enemy = ctx.boss
	if boss == null or not boss.alive:
		return
	var rect := Rect2(w * 0.25, 84, w * 0.5, 16)
	_bar(rect, boss.hp / boss.max_hp, Color(0.65, 0.2, 0.95))
	_text(Vector2(rect.position.x, rect.position.y - 4), boss.display_name(), 18, Color(0.95, 0.8, 1.0))
	if boss.extra_damage_taken > 1.0:
		_text(Vector2(rect.end.x - 220, rect.position.y - 4), tr("BOSS_HEART_EXPOSED"), 16, Color(1.0, 0.7, 1.0),
			HORIZONTAL_ALIGNMENT_RIGHT, 220)
	elif boss.is_invulnerable():
		_text(Vector2(rect.end.x - 220, rect.position.y - 4), tr("BOSS_INVULNERABLE"), 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 220)
