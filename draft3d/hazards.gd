class_name DraftHazards
extends Node3D
## Attaques annoncées au sol (premier jet) : cercle, ligne, onde en anneau. Chaque attaque montre d'abord sa zone,
## puis frappe. Règle de hauteur : une zone ne touche que ce qui se trouve à moins de `REACH_UP` de son niveau
## (une attaque lancée dans la cour ne touche pas la terrasse, et inversement). Une onde en anneau est en plus
## arrêtée par le décor : on s'en abrite derrière n'importe quel obstacle.

const REACH_UP := 1.2
const WARN := Color(0.85, 0.25, 0.75)
## Une onde est faite de tronçons : chacun avance tant qu'il ne rencontre pas de décor, puis s'éteint. L'onde est
## donc coupée derrière un obstacle (à l'image comme pour les dégâts) et ne passe que par les ouvertures.
const RING_SEGMENTS := 120

var hunter: DraftHunter
var hits: int = 0
var _items: Array[Dictionary] = []


func circle(at: Vector3, radius: float, delay: float, damage: float, fx := Callable()) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 40
	_items.append({"kind": &"circle", "at": at, "radius": radius, "left": delay, "delay": delay, "damage": damage,
		"fx": fx, "node": _node(mesh, at)})


func line(from: Vector3, direction: Vector3, length: float, width: float, delay: float, damage: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.04, length)
	var node: MeshInstance3D = _node(mesh, from + direction * length * 0.5)
	node.look_at(node.global_position + direction, Vector3.UP)
	_items.append({"kind": &"line", "at": from, "dir": direction, "length": length, "width": width, "left": delay,
		"delay": delay, "damage": damage, "node": node})


## Onde qui part de `at` après `delay` et s'étend jusqu'à `reach` : une Ruée la traverse.
func ring(at: Vector3, speed: float, reach: float, delay: float, damage: float, fx := Callable()) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.95
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 6
	var node: MeshInstance3D = _node(mesh, at)
	node.scale = Vector3(1.5, 0.15, 1.5)
	_items.append({"kind": &"ring", "at": at, "radius": 1.5, "speed": speed, "reach": reach, "left": delay,
		"delay": delay, "damage": damage, "fx": fx, "node": node, "arcs": _arcs(at), "alive": _full_ring()})


func _full_ring() -> PackedByteArray:
	var alive := PackedByteArray()
	alive.resize(RING_SEGMENTS)
	alive.fill(1)
	return alive


func _arcs(at: Vector3) -> MultiMeshInstance3D:
	var arcs := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var piece := BoxMesh.new()
	piece.size = Vector3(1.0, 0.12, 0.4)
	multimesh.mesh = piece
	multimesh.instance_count = RING_SEGMENTS
	arcs.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.5, 1.0, 0.8)
	arcs.material_override = material
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
	for item: Dictionary in _items:
		if item.has("arcs"):
			(item["arcs"] as Node).queue_free()
		(item["node"] as Node).queue_free()
	_items.clear()


func _node(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(WARN, 0.3)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = at + Vector3.UP * 0.08
	return node


func _physics_process(delta: float) -> void:
	var i: int = _items.size() - 1
	while i >= 0:
		var item: Dictionary = _items[i]
		var node: MeshInstance3D = item["node"]
		var material: StandardMaterial3D = node.material_override
		item["left"] = float(item["left"]) - delta
		var done: bool = false
		if float(item["left"]) > 0.0:
			var progress: float = 1.0 - float(item["left"]) / maxf(float(item["delay"]), 0.01)
			material.albedo_color = Color(WARN, 0.18 + 0.45 * progress)
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
			if _inside(item) and _level_with(item):
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
	if hunter.take_damage(float(item["damage"])) > 0.0:
		hits += 1


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
