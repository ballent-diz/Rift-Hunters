class_name DraftHazards
extends Node3D
## Attaques annoncées au sol (premier jet) : cercle, ligne, onde en anneau. Chaque attaque montre d'abord sa zone,
## puis frappe. Règle de hauteur : une zone ne touche que ce qui se trouve à moins de `REACH_UP` de son niveau
## (une attaque lancée dans la cour ne touche pas la terrasse, et inversement). Une onde en anneau est en plus
## arrêtée par le décor : on s'en abrite derrière n'importe quel obstacle.

const REACH_UP := 1.2
## Une onde est faite de tronçons : chacun avance tant qu'il ne rencontre pas de décor, puis s'éteint. L'onde est
## donc coupée derrière un obstacle (à l'image comme pour les dégâts) et ne passe que par les ouvertures.
const RING_SEGMENTS := 120
const ZONE_TICK := 0.5

var hunter: DraftHunter
var hits: int = 0
## Matériau du boss en train de jouer. Chaque annonce garde le sien une fois posée.
var family: StringName = &"void"
var _impacts: Array[MeshInstance3D] = []
var _items: Array[Dictionary] = []
var _zones: Array[Dictionary] = []


## `on_hit` : appelé quand la frappe blesse le Chasseur (entrave, recul...).
func circle(at: Vector3, radius: float, delay: float, damage: float, fx := Callable(), on_hit := Callable()) -> void:
	var node: MeshInstance3D = _disc(at, radius)
	_items.append({"kind": &"circle", "at": at, "radius": radius, "left": delay, "delay": delay, "damage": damage,
		"fx": fx, "on_hit": on_hit, "node": node, "family": family})


## `covered` : le décor entre l'origine et le Chasseur l'abrite (souffle arrêté par les obstacles).
## `visual_lead` : sur un balayage, les pistes lointaines restent discrètes jusqu'à l'approche du rayon.
func line(from: Vector3, direction: Vector3, length: float, width: float, delay: float, damage: float,
		covered: bool = false, visual_lead: float = 0.0, beam_height: float = 0.0) -> void:
	var node: MeshInstance3D = DraftCombatFx.ground(self, from + direction * length * 0.5,
		Vector2(width, length), family, DraftCombatFx.LANE, DraftCombatFx.WINDUP, DraftCombatFx.WARNING,
		0.13 if visual_lead > 0.0 else 1.0, direction)
	_items.append({"kind": &"line", "at": from, "dir": direction, "length": length, "width": width, "left": delay,
		"delay": delay, "damage": damage, "node": node, "covered": covered, "family": family, "lead": visual_lead,
		"beam_height": beam_height})


## Onde qui part de `at` après `delay` et s'étend jusqu'à `reach` : une Ruée la traverse.
func ring(at: Vector3, speed: float, reach: float, delay: float, damage: float, fx := Callable(),
		on_hit := Callable()) -> void:
	var node: MeshInstance3D = _disc(at, 1.5)
	_items.append({"kind": &"ring", "at": at, "radius": 1.5, "speed": speed, "reach": reach, "left": delay,
		"delay": delay, "damage": damage, "fx": fx, "on_hit": on_hit, "node": node, "arcs": _arcs(at),
		"alive": _full_ring()})


func _full_ring() -> PackedByteArray:
	var alive := PackedByteArray()
	alive.resize(RING_SEGMENTS)
	alive.fill(1)
	return alive


func _arcs(at: Vector3) -> MultiMeshInstance3D:
	var arcs := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var piece := PlaneMesh.new()
	piece.size = Vector2(1.0, 0.4)
	multimesh.mesh = piece
	multimesh.instance_count = RING_SEGMENTS
	arcs.multimesh = multimesh
	arcs.material_override = DraftCombatFx.material(piece.size, DraftCombatFx.WAVE, family, DraftCombatFx.HOLD,
		DraftCombatFx.WARNING)
	arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arcs.visible = false
	add_child(arcs)
	arcs.global_position = at + Vector3.UP * 0.1
	return arcs


## Fait avancer les tronçons de `before` à `after` : celui qui touche le décor s'éteint pour de bon.
func _advance_ring(item: Dictionary, before: float, after: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = (item["at"] as Vector3) + Vector3.UP * 0.8
	var alive: PackedByteArray = item["alive"]
	var arcs: MultiMeshInstance3D = item["arcs"]
	arcs.visible = true
	var length: float = after * TAU / RING_SEGMENTS * 1.05
	for k: int in RING_SEGMENTS:
		var angle: float = TAU * k / RING_SEGMENTS
		var direction := Vector3(cos(angle), 0, sin(angle))
		if alive[k] == 1 and not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin + direction * before,
				origin + direction * after, 1)).is_empty():
			alive[k] = 0
		var basis := Basis(Vector3.UP, -angle + PI * 0.5).scaled(Vector3(length, 1, 1) if alive[k] == 1 else Vector3.ZERO)
		arcs.multimesh.set_instance_transform(k, Transform3D(basis, direction * after))
	item["alive"] = alive


func clear() -> void:
	for impact: MeshInstance3D in _impacts.duplicate():
		impact.queue_free()
	for item: Dictionary in _zones:
		(item["node"] as Node).queue_free()
	_zones.clear()
	for item: Dictionary in _items:
		if item.has("arcs"):
			(item["arcs"] as Node).queue_free()
		(item["node"] as Node).queue_free()
	_items.clear()


func _disc(at: Vector3, radius: float, beat: int = DraftCombatFx.WINDUP) -> MeshInstance3D:
	return DraftCombatFx.ground(self, at, Vector2.ONE * radius * 2.0, family, DraftCombatFx.DISC,
		beat, DraftCombatFx.WARNING)


## Après la frappe, quelques images d'impact. Ces maillages sont hors des annonces actives : le bot
## se sert du nombre d'enfants de DraftHazards pour prendre ses décisions.
func _impact(item: Dictionary, telegraph: MeshInstance3D) -> void:
	if float(item["damage"]) <= 0.0:
		return
	var plane := telegraph.mesh as PlaneMesh
	var shape: int = DraftCombatFx.LANE if item["kind"] == &"line" else DraftCombatFx.DISC
	var node: MeshInstance3D = DraftCombatFx.ground(get_parent(), telegraph.global_position - Vector3.UP * 0.065,
		plane.size, item["family"], shape, DraftCombatFx.IMPACT, DraftCombatFx.CONTACT, 0.88)
	node.global_basis = telegraph.global_basis
	_show_impact(node, 0.24 if shape == DraftCombatFx.LANE else 0.32)
	if float(item.get("beam_height", 0.0)) > 0.0:
		_show_beam(item)


func _show_impact(node: MeshInstance3D, duration: float) -> void:
	_impacts.append(node)
	node.tree_exiting.connect(func() -> void: _impacts.erase(node))
	DraftCombatFx.fade(node, duration)


## Trait en volume sur la ligne annoncée. Le cœur s'arrête au premier obstacle qui le coupe ;
## ce rayon de présentation ne sert ni à l'abri du Chasseur ni au calcul des dégâts.
func _show_beam(item: Dictionary) -> void:
	var origin: Vector3 = item["at"]
	var direction: Vector3 = item["dir"]
	var ray_start: Vector3 = origin + Vector3.UP * 0.8
	var end: Vector3 = ray_start + direction * float(item["length"])
	if item.get("covered", false):
		var query := PhysicsRayQueryParameters3D.create(ray_start, end, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit["position"]
	if ray_start.distance_squared_to(end) < 0.04:
		return
	var start: Vector3 = origin + Vector3.UP * float(item["beam_height"])
	var center: Vector3 = (start + end) * 0.5
	var extent := Vector2(float(item["width"]) * 0.7, start.distance_to(end))
	var node: MeshInstance3D = DraftCombatFx.ground(get_parent(), center - Vector3.UP * 0.09, extent,
		item["family"], DraftCombatFx.BEAM, DraftCombatFx.IMPACT, DraftCombatFx.CONTACT)
	node.look_at(end, Vector3.UP)
	_show_impact(node, 0.21)


func _physics_process(delta: float) -> void:
	_step_zones(delta)
	var i: int = _items.size() - 1
	while i >= 0:
		var item: Dictionary = _items[i]
		var node: MeshInstance3D = item["node"]
		item["left"] = float(item["left"]) - delta
		var done: bool = false
		if float(item["left"]) > 0.0:
			var delay: float = float(item["delay"])
			var lead: float = float(item.get("lead", 0.0))
			var progress: float = 1.0 - float(item["left"]) / maxf(lead if lead > 0.0 else delay, 0.01)
			if lead > 0.0:
				var look := node.material_override as ShaderMaterial
				look.set_shader_parameter("opacity", lerpf(0.13, 1.0, smoothstep(-0.18, 0.27, progress)))
			DraftCombatFx.update(node, maxf(progress, 0.0))
		elif item["kind"] == &"ring":
			_play_fx(item)
			var before: float = item["radius"]
			item["radius"] = before + float(item["speed"]) * delta
			node.visible = false
			_advance_ring(item, before, float(item["radius"]))
			var distance: float = _flat(hunter.global_position - (item["at"] as Vector3)).length()
			if distance > before and distance <= float(item["radius"]) and _level_with(item) and not hunter.is_dashing() \
					and _exposed(item):
				_strike(item)
			done = float(item["radius"]) >= float(item["reach"])
		else:
			_play_fx(item)
			_impact(item, node)
			if _inside(item) and _level_with(item) and not (bool(item.get("covered", false)) and _sheltered(item)):
				_strike(item)
			done = true
		if done:
			if item.has("arcs"):
				(item["arcs"] as Node).queue_free()
			node.queue_free()
			_items.remove_at(i)
		i -= 1


## Effet de la frappe, une seule fois, au moment où la zone annoncée se déclenche.
func _play_fx(item: Dictionary) -> void:
	var fx: Callable = item.get("fx", Callable())
	if fx.is_valid():
		fx.call(item["at"])
		item["fx"] = Callable()


## Le tronçon de l'onde qui arrive sur le Chasseur est-il encore en vie (aucun décor rencontré depuis le centre) ?
func _exposed(item: Dictionary) -> bool:
	var offset: Vector3 = hunter.global_position - (item["at"] as Vector3)
	var k: int = posmod(roundi(atan2(offset.z, offset.x) / TAU * RING_SEGMENTS), RING_SEGMENTS)
	return (item["alive"] as PackedByteArray)[k] == 1


func _strike(item: Dictionary) -> void:
	# Ligne d'annonce sans dégâts (charge, racine) : rien à porter.
	if float(item["damage"]) <= 0.0:
		return
	if hunter.take_damage(float(item["damage"])) > 0.0:
		hits += 1
		var on_hit: Callable = item.get("on_hit", Callable())
		if on_hit.is_valid():
			on_hit.call()


## Un décor s'interpose-t-il entre l'origine de l'attaque et le Chasseur ?
func _sheltered(item: Dictionary) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create((item["at"] as Vector3) + Vector3.UP * 0.8, hunter.chest(), 1)
	return not space.intersect_ray(query).is_empty()


func _level_with(item: Dictionary) -> bool:
	return absf(hunter.global_position.y - (item["at"] as Vector3).y) <= REACH_UP


func _inside(item: Dictionary) -> bool:
	var offset: Vector3 = _flat(hunter.global_position - (item["at"] as Vector3))
	if item["kind"] == &"circle":
		return offset.length() <= float(item["radius"]) + DraftHunter.RADIUS
	var along: float = offset.dot(item["dir"])
	var side: float = (offset - (item["dir"] as Vector3) * along).length()
	return along >= 0.0 and along <= float(item["length"]) and side <= float(item["width"]) * 0.5 + DraftHunter.RADIUS


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Zones persistantes (sol brûlant) ------------------------------------------------------------------------------

## Zone au sol qui dure `duration` s : toutes les `ZONE_TICK` s, le Chasseur dedans (et à son niveau) prend `damage` et
## est ralenti (`slow` < 1). Dessinée en disque coloré.
func zone(at: Vector3, radius: float, duration: float, damage: float, slow: float = 1.0,
		color := Color(1.0, 0.4, 0.1)) -> void:
	var node: MeshInstance3D = _disc(at, radius, DraftCombatFx.HOLD)
	var look := node.material_override as ShaderMaterial
	look.set_shader_parameter("pigment", color.darkened(0.22))
	look.set_shader_parameter("highlight", color.lerp(Color("#ffe0d8"), 0.55))
	_zones.append({"at": at, "radius": radius, "left": duration, "damage": damage, "slow": slow, "tick": 0.0,
		"node": node})


func zones() -> int:
	return _zones.size()


func _step_zones(delta: float) -> void:
	for i: int in range(_zones.size() - 1, -1, -1):
		var item: Dictionary = _zones[i]
		item["left"] = float(item["left"]) - delta
		item["tick"] = maxf(float(item["tick"]) - delta, 0.0)
		if float(item["left"]) <= 0.0:
			(item["node"] as Node).queue_free()
			_zones.remove_at(i)
			continue
		var offset: Vector3 = _flat(hunter.global_position - (item["at"] as Vector3))
		if offset.length() > float(item["radius"]) + DraftHunter.RADIUS or not _level_with(item):
			continue
		if float(item["slow"]) < 1.0:
			hunter.hinder(float(item["slow"]), 0.3)
		if float(item["tick"]) <= 0.0:
			item["tick"] = ZONE_TICK
			if hunter.take_damage(float(item["damage"])) > 0.0:
				hits += 1

