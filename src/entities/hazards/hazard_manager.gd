class_name HazardManager
extends Node2D
## Zones télégraphiées et effets au sol : cercles, secteurs, anneaux, rayons, puits de gravité.
## Les zones hostiles se télégraphient TOUJOURS avant de frapper (lisibilité).

enum Kind { CIRCLE, RING, BEAM, WELL, ZONE, CONE }

const DANGER := Color(1.0, 0.25, 0.6)
const FRIENDLY := Color(0.5, 0.9, 1.0)
## Sorts en cercle des boss (retour de test : impossibles à esquiver) : tout anneau hostile garde au moins une brèche
## à portée du Chasseur (à moins de RING_GAP_REACH radians de sa direction) et une autre à l'opposé, d'une demi-largeur
## d'au moins RING_MIN_GAP ; les couloirs sûrs se dessinent dès l'annonce.
const RING_GAP_REACH := 0.9
const RING_MIN_GAP := 0.42
const SAFE := Color(0.45, 1.0, 0.6)
const SAFE_EDGE := Color(0.02, 0.12, 0.08)
## Intervalle entre deux bouffées de poussière (pixelfx) le long du front d'un anneau de boss.
const RING_DUST_INTERVAL := 0.12

var ctx: RunContext
var hazards: Array[Dictionary] = []
var _clear_hostile_pending: bool = false
var _hostile_layer: Node2D


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	z_index = 0
	_hostile_layer = Node2D.new()
	_hostile_layer.z_index = 3  # au-dessus des Corrompus et du voile de nuit (2), sous le Chasseur (4)
	add_child(_hostile_layer)
	_hostile_layer.draw.connect(_draw_hostile)


## Cercle qui frappe après « delay » secondes.
func add_circle(pos: Vector2, radius: float, delay: float, damage: float, hostile: bool, source_id: StringName,
		statuses: Array[StatusApplication] = []) -> void:
	hazards.append({"kind": Kind.CIRCLE, "pos": pos, "radius": radius, "delay": delay, "total": delay,
		"damage": damage, "hostile": hostile, "source": source_id, "statuses": statuses, "life": delay + 0.25})


## Secteur (griffes, balayage) : frappe une fois après « delay » secondes. half_angle en radians.
func add_cone(pos: Vector2, direction: Vector2, radius: float, half_angle: float, delay: float, damage: float,
		source_id: StringName) -> void:
	hazards.append({"kind": Kind.CONE, "pos": pos, "dir": direction.normalized(), "radius": radius,
		"half_angle": half_angle, "delay": delay, "total": delay, "damage": damage, "hostile": true,
		"source": source_id, "life": delay + 0.25})


## Anneau qui s'étend. gaps : angles (rad) des brèches sûres, gap_width : demi-largeur angulaire.
func add_ring(center: Vector2, speed: float, max_radius: float, thickness: float, damage: float, hostile: bool,
		source_id: StringName, gaps: Array = [], gap_width: float = 0.35, statuses: Array[StatusApplication] = [],
		delay: float = 0.6, family: StringName = &"") -> void:
	if hostile:
		gaps = fair_gaps(center, gaps)
		gap_width = maxf(gap_width, RING_MIN_GAP)
	hazards.append({"kind": Kind.RING, "pos": center, "radius": 0.0, "speed": speed, "max": max_radius,
		"thickness": thickness, "damage": damage, "hostile": hostile, "source": source_id, "gaps": gaps,
		"gap_width": gap_width, "statuses": statuses, "hit": {}, "delay": delay, "total": delay, "life": 99.0,
		"family": family, "dust": 0.0})
	if hostile and family != &"" and ctx.pixel_fx:
		ctx.pixel_fx.ring_charge(center, family, delay)


## Brèches d'un anneau hostile : celles prévues, plus (ou à la place de la première) une brèche à portée du Chasseur ;
## sans brèche prévue, une seconde à l'opposé.
func fair_gaps(center: Vector2, gaps: Array) -> Array:
	var result: Array = gaps.duplicate()
	var toward: float = (ctx.player.global_position - center).angle() if ctx.player else 0.0
	var near: float = toward + ctx.rng.randf_range(-RING_GAP_REACH, RING_GAP_REACH) * 0.8
	if result.is_empty():
		return [near, near + PI]
	for gap: float in result:
		if absf(wrapf(gap - toward, -PI, PI)) <= RING_GAP_REACH:
			return result
	result[0] = near
	return result


## Rayon : télégraphe pendant delay, puis actif pendant duration (dégâts par tick).
func add_beam(origin: Vector2, direction: Vector2, length: float, width: float, delay: float, duration: float,
		damage: float, source_id: StringName) -> void:
	# Le rayon s'arrête au premier décor qui arrête les tirs (abris).
	length = ctx.obstacles.clear_distance(origin, direction.normalized(), length)
	hazards.append({"kind": Kind.BEAM, "pos": origin, "dir": direction.normalized(), "length": length,
		"width": width, "delay": delay, "total": delay, "duration": duration, "damage": damage, "source": source_id,
		"tick": 0.0, "life": delay + duration})


## Puits de gravité allié : aspire les ennemis, émet well_tick chaque seconde, implose à la fin.
func add_well(pos: Vector2, radius: float, duration: float, pull: float, implode_info: DamageInfo,
		source_id: StringName) -> Dictionary:
	var well := {"kind": Kind.WELL, "pos": pos, "radius": radius, "duration": duration, "total": duration,
		"pull": pull, "info": implode_info, "source": source_id, "tick": 0.0, "pulled": {}, "life": duration}
	hazards.append(well)
	return well


## Zone alliée persistante : dégâts et statuts toutes les 0,5 s (ronces, champs).
func add_zone(pos: Vector2, radius: float, duration: float, damage: float, source_id: StringName,
		statuses: Array[StatusApplication] = [], color: Color = Color(0.45, 0.85, 0.35)) -> void:
	hazards.append({"kind": Kind.ZONE, "pos": pos, "radius": radius, "duration": duration, "total": duration,
		"damage": damage, "source": source_id, "statuses": statuses, "tick": 0.0, "color": color, "life": duration})


## Zone alliée qui soigne aussi le Chasseur (heal PV par demi-seconde) tant qu'il s'y trouve (Bosquet).
func add_heal_zone(pos: Vector2, radius: float, duration: float, heal: float, damage: float, source_id: StringName,
		statuses: Array[StatusApplication] = [], color: Color = Color(0.55, 0.9, 0.45)) -> void:
	add_zone(pos, radius, duration, damage, source_id, statuses, color)
	hazards[-1]["heal"] = heal


## Vecteur d'évitement des zones hostiles (utilisé par le bot de test).
func danger_vector(pos: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for h: Dictionary in hazards:
		if not h.get("hostile", h["kind"] == Kind.BEAM):
			continue
		match h["kind"]:
			Kind.CIRCLE:
				var offset: Vector2 = pos - h["pos"]
				if offset.length() < float(h["radius"]) + 30.0:
					result += offset.normalized()
			Kind.CONE:
				if in_cone(h, pos, 30.0):
					result += (pos - (h["pos"] as Vector2)).normalized()
			Kind.BEAM:
				var to_pos: Vector2 = pos - h["pos"]
				var along: float = to_pos.dot(h["dir"])
				if along > 0.0 and along < float(h["length"]):
					var perp: Vector2 = to_pos - (h["dir"] as Vector2) * along
					if perp.length() < float(h["width"]) + 40.0:
						result += perp.normalized() if perp.length() > 0.1 else (h["dir"] as Vector2).orthogonal()
	return result


func step(delta: float) -> void:
	# Itère sur une copie : un coup peut ajouter des zones (explosions) ou en retirer (mort du boss).
	var current: Array[Dictionary] = hazards.duplicate()
	var kept: Array[Dictionary] = []
	for h: Dictionary in current:
		h["life"] = float(h["life"]) - delta
		var keep: bool = true
		match h["kind"]:
			Kind.CIRCLE:
				keep = _step_circle(h, delta)
			Kind.CONE:
				keep = _step_cone(h, delta)
			Kind.RING:
				keep = _step_ring(h, delta)
			Kind.BEAM:
				keep = _step_beam(h, delta)
			Kind.WELL:
				keep = _step_well(h, delta)
			Kind.ZONE:
				keep = _step_zone(h, delta)
		if keep:
			kept.append(h)
	for h: Dictionary in hazards:
		if not current.has(h):
			kept.append(h)
	hazards = kept
	if _clear_hostile_pending:
		_clear_hostile_pending = false
		hazards.assign(hazards.filter(func(h: Dictionary) -> bool: return h["kind"] in [Kind.WELL,
				Kind.ZONE] or not h.get("hostile", true)))
	queue_redraw()
	_hostile_layer.queue_redraw()


func _step_circle(h: Dictionary, delta: float) -> bool:
	if float(h["delay"]) > 0.0:
		h["delay"] = float(h["delay"]) - delta
		if float(h["delay"]) <= 0.0:
			_strike_area(h, h["pos"], float(h["radius"]))
	return float(h["life"]) > 0.0


func _step_cone(h: Dictionary, delta: float) -> bool:
	if float(h["delay"]) > 0.0:
		h["delay"] = float(h["delay"]) - delta
		if float(h["delay"]) <= 0.0:
			var player: Player = ctx.player
			if ctx.pixel_fx:
				ctx.pixel_fx.impact(h["source"], (h["pos"] as Vector2) + (h["dir"] as Vector2) * float(h["radius"]) * 0.4)
			# Souffle : un abri entre la source et le Chasseur le protège.
			if in_cone(h, player.global_position, player.radius * 0.5) and ctx.obstacles.line_clear(h["pos"],
					player.global_position):
				ctx.combat.damage_player(float(h["damage"]), h["source"])
	return float(h["life"]) > 0.0


## Point dans le secteur (marge : tolérance en unités, rayon du corps).
func in_cone(h: Dictionary, pos: Vector2, margin: float) -> bool:
	var offset: Vector2 = pos - (h["pos"] as Vector2)
	if offset.length() > float(h["radius"]) + margin:
		return false
	if offset.length() < margin:
		return true
	return absf((h["dir"] as Vector2).angle_to(offset)) <= float(h["half_angle"])


func _step_ring(h: Dictionary, delta: float) -> bool:
	if float(h["delay"]) > 0.0:
		h["delay"] = float(h["delay"]) - delta
		if float(h["delay"]) <= 0.0:
			_ring_fx(h, true)
		return true
	if float(h["radius"]) <= 0.0 and float(h["total"]) <= 0.0:
		_ring_fx(h, true)
	h["radius"] = float(h["radius"]) + float(h["speed"]) * delta
	h["dust"] = float(h["dust"]) - delta
	if float(h["dust"]) <= 0.0:
		h["dust"] = RING_DUST_INTERVAL
		_ring_fx(h, false)
	var r: float = h["radius"]
	var half: float = float(h["thickness"]) * 0.5
	var center: Vector2 = h["pos"]
	if h["hostile"]:
		var player: Player = ctx.player
		var offset: Vector2 = player.global_position - center
		if not h["hit"].has(0) and absf(offset.length() - r) < half + player.radius and not _in_gap(h, offset.angle()):
			if player.can_be_hurt():
				h["hit"][0] = true
				ctx.combat.damage_player(float(h["damage"]), h["source"])
	else:
		for enemy: Enemy in ctx.enemies.query_radius(center, r + half):
			var id: int = enemy.get_instance_id()
			if h["hit"].has(id) or enemy.position.distance_to(center) < r - half - enemy.radius:
				continue
			h["hit"][id] = true
			_hit_enemy(enemy, h)
	return r < float(h["max"])


## Animations pixelfx d'un anneau de boss : onde de choc au départ (`start`), poussière le long du front ensuite.
func _ring_fx(h: Dictionary, start: bool) -> void:
	var family: StringName = h.get("family", &"")
	if family == &"" or ctx.pixel_fx == null:
		return
	if start:
		ctx.pixel_fx.ring_burst(h["pos"], family)
	else:
		ctx.pixel_fx.ring_dust(h["pos"], float(h["radius"]), family, func(angle: float) -> bool: return _in_gap(h, angle))


## Couloirs sûrs d'un anneau hostile : un secteur clair par brèche, du boss jusqu'à la portée de l'anneau.
func _draw_safe_lanes(canvas: CanvasItem, h: Dictionary) -> void:
	var center: Vector2 = h["pos"]
	var inner: float = maxf(float(h["radius"]) - 40.0, 50.0)
	var outer: float = h["max"]
	if inner >= outer:
		return
	var width: float = h["gap_width"]
	var fade: float = 1.0 - float(h["radius"]) / maxf(outer, 1.0)
	for gap: float in h["gaps"]:
		var points := PackedVector2Array()
		for k: int in 9:
			points.append(center + Vector2.RIGHT.rotated(gap - width + width * 2.0 * k / 8.0) * inner)
		for k: int in 9:
			points.append(center + Vector2.RIGHT.rotated(gap + width - width * 2.0 * k / 8.0) * outer)
		canvas.draw_colored_polygon(points, Color(SAFE, 0.16 * fade + 0.06))
		for side: float in [-width, width]:
			var dir := Vector2.RIGHT.rotated(gap + side)
			canvas.draw_line(center + dir * inner, center + dir * outer, Color(SAFE_EDGE, 0.5 * fade + 0.15), 5.0)
			canvas.draw_line(center + dir * inner, center + dir * outer, Color(SAFE, 0.75 * fade + 0.2), 2.0)


func _draw_gapped_arc(canvas: CanvasItem, h: Dictionary, radius: float, color: Color, width: float) -> void:
	var segments: int = 64
	for s: int in segments:
		var a0: float = TAU * s / segments
		var a1: float = TAU * (s + 1) / segments
		if not _in_gap(h, (a0 + a1) * 0.5):
			canvas.draw_arc(h["pos"], radius, a0, a1, 3, color, width)


func _in_gap(h: Dictionary, angle: float) -> bool:
	for gap: float in h["gaps"]:
		if absf(wrapf(angle - gap, -PI, PI)) < float(h["gap_width"]):
			return true
	return false


func _step_beam(h: Dictionary, delta: float) -> bool:
	if float(h["delay"]) > 0.0:
		h["delay"] = float(h["delay"]) - delta
		return true
	h["tick"] = float(h["tick"]) - delta
	if float(h["tick"]) <= 0.0:
		h["tick"] = 0.25
		var player: Player = ctx.player
		var to_player: Vector2 = player.global_position - (h["pos"] as Vector2)
		var along: float = to_player.dot(h["dir"])
		if along > 0.0 and along < float(h["length"]):
			var perp: float = (to_player - (h["dir"] as Vector2) * along).length()
			if perp < float(h["width"]) * 0.5 + player.radius:
				ctx.combat.damage_player(float(h["damage"]), h["source"])
	return float(h["life"]) > 0.0


func _step_well(h: Dictionary, delta: float) -> bool:
	var center: Vector2 = h["pos"]
	var radius: float = h["radius"]
	var inside: Array = []
	for enemy: Enemy in ctx.enemies.query_radius(center, radius):
		if enemy.is_boss or enemy.is_obstacle:
			continue
		var offset: Vector2 = center - enemy.position
		var d: float = offset.length()
		if d > 6.0:
			var strength: float = float(h["pull"]) * (1.0 - enemy.data_knockback_resist() * 0.5)
			enemy.position += offset / d * minf(strength * delta, d - 4.0)
		inside.append(enemy)
		h["pulled"][enemy.get_instance_id()] = true
	h["tick"] = float(h["tick"]) - delta
	if float(h["tick"]) <= 0.0:
		h["tick"] = 1.0
		ctx.events.well_tick.emit(inside, h["source"])
	h["duration"] = float(h["duration"]) - delta
	if float(h["duration"]) <= 0.0:
		var info: DamageInfo = h["info"]
		for enemy: Enemy in ctx.enemies.query_radius(center, radius * 0.6):
			ctx.combat.deal_damage(enemy, info)
		ctx.fx.burst(center, radius * 0.6, Color(0.6, 1.0, 0.7, 0.45))
		ctx.stats.set_max(StringName(String(h["source"]) + "_max_pulled"), float((h["pulled"] as Dictionary).size()))
		return false
	return true


func _step_zone(h: Dictionary, delta: float) -> bool:
	h["tick"] = float(h["tick"]) - delta
	if float(h["tick"]) <= 0.0:
		h["tick"] = 0.5
		for enemy: Enemy in ctx.enemies.query_radius(h["pos"], float(h["radius"])):
			_hit_enemy(enemy, h)
		var heal: float = float(h.get("heal", 0.0))
		if heal > 0.0 and ctx.player.global_position.distance_to(h["pos"]) <= float(h["radius"]):
			var before: float = ctx.player.hp
			ctx.player.heal(heal, false)
			ctx.stats.add(StringName(String(h["source"]) + "_healed"), ctx.player.hp - before)
	h["duration"] = float(h["duration"]) - delta
	return float(h["duration"]) > 0.0


func _strike_area(h: Dictionary, center: Vector2, radius: float) -> void:
	if h["hostile"]:
		var player: Player = ctx.player
		if player.global_position.distance_to(center) < radius + player.radius * 0.5:
			ctx.combat.damage_player(float(h["damage"]), h["source"])
		ctx.fx.burst(center, radius, Color(1.0, 0.3, 0.7, 0.4))
		if ctx.pixel_fx:
			ctx.pixel_fx.impact(h["source"], center)
	else:
		for enemy: Enemy in ctx.enemies.query_radius(center, radius):
			_hit_enemy(enemy, h)
		ctx.fx.burst(center, radius, Color(0.6, 0.95, 1.0, 0.35))


func _hit_enemy(enemy: Enemy, h: Dictionary) -> void:
	var source: StringName = h["source"]
	var kind := DamageInfo.SourceKind.PLAYER if source == &"player" else DamageInfo.SourceKind.ALLY
	var tags: Array[StringName] = [DamageInfo.TAG_ATTACK]
	var info := DamageInfo.make(float(h["damage"]), kind, source, tags)
	info.statuses = h["statuses"]
	ctx.combat.deal_damage(enemy, info)


## Retire les zones hostiles (appliqué à la fin du prochain pas, jamais pendant une itération).
func clear_hostile() -> void:
	_clear_hostile_pending = true


func _draw() -> void:
	for h: Dictionary in hazards:
		if not _is_hostile(h):
			_draw_hazard(self, h)


## Dangers (télégraphes ennemis) dessinés sur une couche au-dessus du voile de nuit : toujours visibles.
func _draw_hostile() -> void:
	for h: Dictionary in hazards:
		if _is_hostile(h):
			_draw_hazard(_hostile_layer, h)


func _is_hostile(h: Dictionary) -> bool:
	return bool(h.get("hostile", h["kind"] == Kind.BEAM))


func _draw_hazard(canvas: CanvasItem, h: Dictionary) -> void:
	match h["kind"]:
		Kind.CIRCLE:
			var color: Color = DANGER if h["hostile"] else FRIENDLY
			if float(h["delay"]) > 0.0:
				var progress: float = 1.0 - float(h["delay"]) / maxf(float(h["total"]), 0.01)
				var soft: float = 0.35 if _painted(h) else 1.0
				canvas.draw_circle(h["pos"], float(h["radius"]), Color(color, 0.12 * soft))
				canvas.draw_circle(h["pos"], float(h["radius"]) * progress, Color(color, 0.22 * soft))
				canvas.draw_arc(h["pos"], float(h["radius"]), 0.0, TAU, 48, Color(color, 0.9 * soft), 2.5 * soft)
		Kind.CONE:
			if float(h["delay"]) > 0.0:
				var progress: float = 1.0 - float(h["delay"]) / maxf(float(h["total"]), 0.01)
				var soft: float = 0.35 if _painted(h) else 1.0
				_draw_sector(canvas, h, float(h["radius"]), Color(DANGER, 0.12 * soft))
				_draw_sector(canvas, h, float(h["radius"]) * progress, Color(DANGER, 0.22 * soft))
		Kind.RING:
			_draw_ring(canvas, h)
		Kind.BEAM:
			var end: Vector2 = (h["pos"] as Vector2) + (h["dir"] as Vector2) * float(h["length"])
			if float(h["delay"]) > 0.0:
				var soft: float = 0.35 if _painted(h) else 1.0
				canvas.draw_line(h["pos"], end, Color(DANGER, 0.35 * soft), float(h["width"]))
				canvas.draw_line(h["pos"], end, Color(DANGER, 0.9 * soft), 2.0)
			elif not _painted(h):
				canvas.draw_line(h["pos"], end, Color(0.55, 0.1, 0.9, 0.85), float(h["width"]))
				canvas.draw_line(h["pos"], end, Color(1.0, 0.8, 1.0), float(h["width"]) * 0.35)
		Kind.ZONE:
			var fade: float = clampf(float(h["duration"]) / 0.5, 0.0, 1.0)
			var zone_color: Color = h["color"]
			# Écho aux effets peints (Codex) : repère discret, la peinture porte le visuel.
			var soft: float = 0.45 if _painted(h) else 1.0
			canvas.draw_circle(h["pos"], float(h["radius"]), Color(zone_color, 0.16 * fade * soft))
			canvas.draw_arc(h["pos"], float(h["radius"]), 0.0, TAU, 40, Color(zone_color, 0.6 * fade * soft), 2.0)
		Kind.WELL:
			var t: float = float(h["duration"]) / maxf(float(h["total"]), 0.01)
			var soft: float = 0.3 if _painted(h) else 1.0
			canvas.draw_circle(h["pos"], float(h["radius"]), Color(0.3, 0.8, 0.5, 0.12 * soft))
			canvas.draw_arc(h["pos"], float(h["radius"]) * (0.3 + 0.7 * t), 0.0, TAU, 48, Color(0.6, 1.0, 0.7, 0.7 * soft), 2.0)
			canvas.draw_arc(h["pos"], float(h["radius"]), 0.0, TAU, 48, Color(0.6, 1.0, 0.7, 0.5 * soft), 1.5)


## Effet peint (Codex) qui porte déjà le visuel : le repère du jeu reste discret. « painted » : posé par le boss.
func _painted(h: Dictionary) -> bool:
	return bool(h.get("painted", false)) or (ctx.allies != null and ctx.allies.vfx.has_effects(h.get("source", &"")))


## Dernière zone ajoutée : habillée par un effet peint.
func mark_last_painted() -> void:
	if not hazards.is_empty():
		hazards[-1]["painted"] = true


func _draw_sector(canvas: CanvasItem, h: Dictionary, radius: float, color: Color) -> void:
	var center: Vector2 = h["pos"]
	var base: float = (h["dir"] as Vector2).angle()
	var half: float = h["half_angle"]
	var points := PackedVector2Array([center])
	for s: int in 17:
		points.append(center + Vector2.RIGHT.rotated(base - half + 2.0 * half * s / 16.0) * radius)
	canvas.draw_colored_polygon(points, color)
	points.append(center)
	canvas.draw_polyline(points, Color(color, 0.9), 2.0)


func _draw_ring(canvas: CanvasItem, h: Dictionary) -> void:
	var color: Color = DANGER if h["hostile"] else Color(1.0, 0.65, 0.3)
	var center: Vector2 = h["pos"]
	if h["hostile"]:
		_draw_safe_lanes(canvas, h)
	if float(h["delay"]) > 0.0:
		canvas.draw_arc(center, 40.0, 0.0, TAU, 32, Color(color, 0.8), 3.0)
		if h["hostile"] and ctx.player:
			# Annonce : l'anneau à venir, à la distance du Chasseur, brèches comprises.
			var reach: float = minf(center.distance_to(ctx.player.global_position), float(h["max"]))
			var alpha: float = 0.35 + 0.25 * (1.0 - float(h["delay"]) / maxf(float(h["total"]), 0.01))
			_draw_gapped_arc(canvas, h, reach, Color(color, alpha), 3.0)
		return
	var r: float = h["radius"]
	var segments: int = 64
	for s: int in segments:
		var a0: float = TAU * s / segments
		var a1: float = TAU * (s + 1) / segments
		if h["hostile"] and _in_gap(h, (a0 + a1) * 0.5):
			continue
		canvas.draw_arc(center, r, a0, a1, 3, Color(color, 0.85), float(h["thickness"]) * 0.6)
