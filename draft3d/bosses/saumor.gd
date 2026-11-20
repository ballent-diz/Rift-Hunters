class_name DraftSaumor
extends DraftBossMechanic
## Saumor, boss des Saumâtres (docs/art/SAUMOR.md, docs/design/TECHNIQUES_ENNEMIS_V2.md). Deux phases :
## - phase 1 : Appel de la vanne (`gate_pull` : le siphon aspire le Chasseur vers lui, un obstacle entre eux coupe
##   l'aspiration, une Ruée la rompt ; morsure du siphon à la fin) et Écrasement d'épaule (`shoulder_slam`) ;
## - phase 2 (vantaux ouverts) : Balayage saumâtre (`brine_sweep` : large jet qui traverse l'arène couloir après
##   couloir) et Explosion du siphon (`core_burst` : deux pulsations, d'abord le cercle intérieur puis la couronne ;
##   le cercle intérieur, déjà frappé, devient la zone sûre de la seconde).
## Réglages dans les `params` des techniques de data/bosses/saumor.tres (mètres et secondes).

const STREAM := Color(0.45, 0.78, 0.86, 0.55)
const THICKNESS := 0.22

## Aspiration en cours : {"until", "speed", "strike_at"} (vide : aucune).
var pull: Dictionary = {}
## Aspirations rompues (obstacle ou Ruée) et menées au bout (essais).
var pulls_broken: int = 0
var pulls_done: int = 0
var _clock: float = 0.0
var _stream: MeshInstance3D


func handles(kind: StringName) -> bool:
	return kind in [&"gate_pull", &"shoulder_slam", &"brine_sweep", &"core_burst"]


func perform(pattern: BossPatternData) -> float:
	match pattern.kind:
		&"gate_pull":
			return _gate_pull(pattern)
		&"shoulder_slam":
			return _shoulder_slam(pattern)
		&"brine_sweep":
			return _brine_sweep(pattern)
		&"core_burst":
			return _core_burst(pattern)
	return 0.0


## Effet dédié `boss_saumor_<id>` dès qu'il est livré, sinon l'effet PixelFX existant (au moment de la frappe).
func _fx_at(id: String, width: float, fallback: StringName, size: float) -> Callable:
	var run: Node = brain.enemies.run
	var family: StringName = brain.combat_family()
	return func(at: Vector3) -> void:
		run.call("fx_or", StringName("boss_saumor_" + id), width, fallback, family, at + Vector3.UP * 0.6, size)


func _p(pattern: BossPatternData, key: String, fallback: float) -> float:
	return float(pattern.params.get(key, fallback))


func _aim() -> Vector3:
	var offset: Vector3 = DraftSpells._flat(brain.enemies.hunter.global_position - brain.foe.pos)
	return offset.normalized() if offset.length() > 0.05 else Vector3.FORWARD


## Appel de la vanne : annonce (anneau au siphon), puis aspiration ; morsure du siphon à la fin.
func _gate_pull(pattern: BossPatternData) -> float:
	var duration: float = _p(pattern, "duration", 2.2)
	var radius: float = _p(pattern, "bite_radius", 2.6)
	pull = {"from": _clock + pattern.telegraph, "until": _clock + pattern.telegraph + duration,
		"speed": _p(pattern, "pull_speed", 3.2), "reach": _p(pattern, "reach", 14.0)}
	brain.enemies.hazards.circle(brain.foe.pos, radius, pattern.telegraph + duration, brain.damage(pattern.damage),
		_fx_at("gate_bite", radius * 2.0, &"geyser", radius))
	brain.fx(&"ring_charge", brain.foe.pos + Vector3.UP * 0.4, 2.0)
	brain.play_clip([&"gate_pull", &"attack"], pattern.telegraph + duration)
	return pattern.telegraph + duration + _p(pattern, "recover", 0.9)


func step(delta: float) -> void:
	_clock += delta
	if pull.is_empty():
		return
	if _clock >= float(pull["until"]):
		pulls_done += 1
		_release()
		return
	if _clock < float(pull["from"]):
		return
	var hunter: DraftHunter = brain.enemies.hunter
	var foe: DraftEnemies.Foe = brain.foe
	var offset: Vector3 = DraftSpells._flat(foe.pos - hunter.global_position)
	# Un obstacle entre le siphon et le Chasseur coupe le courant ; une Ruée le rompt.
	var sheltered: bool = not bool(brain.enemies.run.call("sight_clear", foe.pos + Vector3.UP * 0.8, hunter.chest()))
	if hunter.is_dashing() or sheltered or offset.length() > float(pull["reach"]):
		pulls_broken += 1
		brain.fx(&"splash", hunter.chest(), 0.9)
		_release()
		return
	if offset.length() > foe.radius + 0.8:
		var step_length: float = minf(float(pull["speed"]) * delta, offset.length() - foe.radius - 0.8)
		hunter.move_and_collide(offset.normalized() * step_length)
	_draw(foe.pos + Vector3.UP * 0.9, hunter.chest())


## Écrasement d'épaule : coup lourd au corps à corps (disque devant le boss), recul, longue récupération.
func _shoulder_slam(pattern: BossPatternData) -> float:
	var dir: Vector3 = _aim()
	var radius: float = _p(pattern, "radius", 2.8)
	var at: Vector3 = brain.enemies.level.closest(brain.foe.pos + dir * _p(pattern, "reach", 2.4))
	var hunter: DraftHunter = brain.enemies.hunter
	var push: float = _p(pattern, "knockback", 9.0)
	brain.enemies.hazards.circle(at, radius, pattern.telegraph, brain.damage(pattern.damage),
		_fx_at("shoulder_slam", radius * 2.0, &"quake", radius),
		func() -> void: hunter.velocity += dir * push)
	brain.play_clip([&"shoulder_slam", &"attack"], pattern.telegraph + 0.4)
	return pattern.telegraph + _p(pattern, "recover", 1.2)


## Balayage saumâtre : couloirs successifs qui balaient un arc devant le boss ; le décor abrite.
func _brine_sweep(pattern: BossPatternData) -> float:
	var dir: Vector3 = _aim()
	var lanes: int = int(_p(pattern, "lanes", 7.0))
	var arc: float = deg_to_rad(_p(pattern, "arc", 110.0))
	var step_time: float = _p(pattern, "step", 0.18)
	var side: float = 1.0 if brain.enemies.rng.randf() < 0.5 else -1.0
	for i: int in lanes:
		var angle: float = side * (-arc * 0.5 + arc * i / maxf(lanes - 1, 1))
		brain.enemies.hazards.line(brain.foe.pos, dir.rotated(Vector3.UP, angle), _p(pattern, "length", 15.0),
			_p(pattern, "width", 1.5), pattern.telegraph + step_time * i, brain.damage(pattern.damage), true,
			_p(pattern, "lead", 0.5), 1.0)
	var total: float = pattern.telegraph + step_time * lanes
	brain.play_clip([&"brine_sweep", &"attack"], total)
	return total + _p(pattern, "recover", 1.0)


## Explosion du siphon : 1) cercle intérieur ; 2) couronne de disques autour. Après la première, revenir au centre.
func _core_burst(pattern: BossPatternData) -> float:
	var at: Vector3 = brain.foe.pos
	var inner: float = _p(pattern, "inner_radius", 4.2)
	var gap: float = _p(pattern, "gap", 1.1)
	brain.enemies.hazards.circle(at, inner, pattern.telegraph, brain.damage(pattern.damage),
		_fx_at("core_burst_inner", inner * 2.0, &"geyser", inner))
	var count: int = int(_p(pattern, "outer_count", 10.0))
	var ring_radius: float = _p(pattern, "outer_radius", 7.2)
	var disc: float = _p(pattern, "outer_disc", 2.0)
	for i: int in count:
		var spot: Vector3 = brain.enemies.level.closest(at + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / count) * ring_radius)
		brain.enemies.hazards.circle(spot, disc, pattern.telegraph + gap, brain.damage(pattern.damage),
			_fx_at("core_burst_outer", disc * 2.0, &"splash", disc))
	brain.fx(&"ring_charge", at + Vector3.UP * 0.4, 2.6)
	brain.play_clip([&"core_burst", &"attack"], pattern.telegraph + gap)
	return pattern.telegraph + gap + _p(pattern, "recover", 1.1)


func _draw(from: Vector3, to: Vector3) -> void:
	if _stream == null:
		_stream = MeshInstance3D.new()
		_stream.mesh = BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = STREAM
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_stream.material_override = material
		_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		brain.enemies.add_child(_stream)
	var span: float = maxf(from.distance_to(to), 0.1)
	(_stream.mesh as BoxMesh).size = Vector3(THICKNESS, THICKNESS, span)
	_stream.global_position = (from + to) * 0.5
	if span > 0.1:
		_stream.look_at(to, Vector3.UP)


func _release() -> void:
	pull = {}
	if _stream != null:
		_stream.queue_free()
		_stream = null


func on_phase(_index: int) -> void:
	_release()


func finish() -> void:
	_release()
