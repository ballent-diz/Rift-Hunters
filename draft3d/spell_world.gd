class_name DraftSpellWorld
extends RefCounted
## Objets que les sorts du Chasseur laissent dans le monde 3D (docs/design/SORTS_ACTIFS_V2.md, lot 4) :
## puits de Singularité, Murs de faille, Cristaux réfracteurs. Mis à jour par `DraftSpells.step` ; les ennemis
## consultent `blocks` (Murs) et les traits du Chasseur `refract` (Cristaux).

const WALL_COLOR := Color(0.75, 0.45, 1.0, 0.45)
## Distance (m) en deçà de laquelle un ennemi « touche » un Mur (Chaînes, Rempart ardent).
const WALL_TOUCH := 0.7

var spells: DraftSpells
var run: DraftRun
## {at, radius, left, pull, damage, visual}
var wells: Array[Dictionary] = []
## {a, b, left, root, burn, tick, clock, visual}
var walls: Array[Dictionary] = []
## {at, radius, left, focus, visual}
var crystals: Array[Dictionary] = []


func _init(p_spells: DraftSpells) -> void:
	spells = p_spells
	run = p_spells.run


func step(delta: float) -> void:
	_step_wells(delta)
	_step_walls(delta)
	for i: int in range(crystals.size() - 1, -1, -1):
		crystals[i]["left"] = float(crystals[i]["left"]) - delta
		if float(crystals[i]["left"]) <= 0.0:
			_free(crystals[i])
			crystals.remove_at(i)


# --- Singularité --------------------------------------------------------------------------------------------------

## `drawn` : l'animation peinte de la v1 est jouée (pas d'effet PixelFX en plus).
func add_well(at: Vector3, radius: float, duration: float, pull: float, damage: float, drawn: bool = false) -> void:
	wells.append({"at": at, "radius": radius, "left": duration, "pull": pull, "damage": damage, "drawn": drawn,
		"visual": null if drawn else run.fx(&"black_hole", DraftPixelFx.DEFAULT_FAMILY, at + Vector3.UP * 0.8,
			radius * 0.8, true)})


## Les ennemis du même niveau sont attirés vers le centre (jamais les boss), puis le puits implose.
func _step_wells(delta: float) -> void:
	for i: int in range(wells.size() - 1, -1, -1):
		var well: Dictionary = wells[i]
		var at: Vector3 = well["at"]
		var radius: float = well["radius"]
		for foe: DraftEnemies.Foe in run.enemies.near(at, radius * 1.6):
			if foe.boss != null or absf(foe.pos.y - at.y) > DraftEnemies.MELEE_REACH_UP:
				continue
			var offset: Vector3 = DraftSpells._flat(at - foe.pos)
			if offset.length() > 0.3:
				foe.pos += offset.normalized() * minf(float(well["pull"]) * delta, offset.length())
		run.combos.on_well(well)
		well["left"] = float(well["left"]) - delta
		if float(well["left"]) <= 0.0:
			if not well["drawn"]:
				run.fx(&"dark_explosion", DraftPixelFx.DEFAULT_FAMILY, at + Vector3.UP * 0.6, radius)
			for foe: DraftEnemies.Foe in spells._level(run.enemies.near(at, radius), at):
				run.enemies.hit(foe, float(well["damage"]))
			_free(well)
			wells.remove_at(i)


# --- Mur de faille ------------------------------------------------------------------------------------------------

## `drawn` : l'animation peinte est jouée ; le volume translucide (hauteur du mur) reste, plus discret.
func add_wall(center: Vector3, along: Vector3, length: float, duration: float, root: float, burn: float,
		tick: float, drawn: bool = false) -> void:
	var half: Vector3 = along.normalized() * length * 0.5
	var box := BoxMesh.new()
	box.size = Vector3(length, 1.6, 0.25)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(WALL_COLOR, WALL_COLOR.a * (0.4 if drawn else 1.0))
	box.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = box
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	run.add_child(visual)
	visual.global_position = center + Vector3.UP * 0.8
	visual.rotation.y = atan2(-along.z, along.x)
	if not drawn:
		run.fx(&"rune_circle", DraftPixelFx.DEFAULT_FAMILY, center + Vector3.UP * 0.3, length * 0.4)
	walls.append({"a": center - half, "b": center + half, "left": duration, "root": root, "burn": burn,
		"tick": tick, "clock": 0.0, "visual": visual})


## Vrai si le segment `from` → `to` (au sol) traverse un Mur actif du même niveau.
func blocks(from: Vector3, to: Vector3) -> bool:
	for wall: Dictionary in walls:
		var a: Vector3 = wall["a"]
		var b: Vector3 = wall["b"]
		if absf(from.y - a.y) > DraftEnemies.MELEE_REACH_UP:
			continue
		if Geometry2D.segment_intersects_segment(Vector2(from.x, from.z), Vector2(to.x, to.z), Vector2(a.x, a.z),
				Vector2(b.x, b.z)) != null:
			return true
	return false


func _step_walls(delta: float) -> void:
	for i: int in range(walls.size() - 1, -1, -1):
		var wall: Dictionary = walls[i]
		wall["left"] = float(wall["left"]) - delta
		wall["clock"] = float(wall["clock"]) + delta
		var tick: bool = float(wall["clock"]) >= float(wall["tick"])
		if tick:
			wall["clock"] = 0.0
		if tick and (float(wall["root"]) > 0.0 or float(wall["burn"]) > 0.0):
			var a: Vector3 = wall["a"]
			var b: Vector3 = wall["b"]
			for foe: DraftEnemies.Foe in run.enemies.near((a + b) * 0.5, a.distance_to(b) * 0.5 + WALL_TOUCH):
				var closest: Vector3 = Geometry3D.get_closest_point_to_segment(foe.pos, a, b)
				if DraftSpells._flat(foe.pos - closest).length() > foe.radius + WALL_TOUCH:
					continue
				if float(wall["root"]) > 0.0 and foe.boss == null:
					# Chaînes : entrave visible à chaque nouvel ennemi pris (le dessin peint des chaînes n'a pas de
					# cible en v2 et le Rempart ardent peut porter l'animation du mur).
					if foe.slow_left <= 0.0 or foe.slow_factor > 0.0:
						run.fx(&"root_snare", &"enlises", foe.pos + Vector3.UP * 0.3, 0.8)
					foe.slow(0.0, float(wall["root"]))
				if float(wall["burn"]) > 0.0:
					run.enemies.hit(foe, float(wall["burn"]))
		if float(wall["left"]) <= 0.0:
			_free(wall)
			walls.remove_at(i)


# --- Cristal réfracteur -------------------------------------------------------------------------------------------

func add_crystal(at: Vector3, radius: float, duration: float, focus: bool, drawn: bool = false) -> void:
	crystals.append({"at": at, "radius": radius, "left": duration, "focus": focus,
		"visual": null if drawn else run.fx(&"ice_shatter", &"givres", at + Vector3.UP * 0.8, 1.2, true)})


## Un trait du Chasseur qui traverse un Cristal se divise une fois (deux traits de plus, en éventail) ; Foyer : les
## éclats filent vers l'ennemi visible le plus résistant. Une Lance prismatique peut y déclencher le Déluge prismatique
## (`DraftCombos.refraction`). Renvoie le nombre de traits ajoutés.
func refract(shot: Dictionary) -> int:
	if shot.get("refracted", false) or int(shot.get("split", 0)) < 0:
		return 0
	var at: Vector3 = shot["at"]
	for crystal: Dictionary in crystals:
		var center: Vector3 = crystal["at"] + Vector3.UP * 0.8
		if at.distance_to(center) > float(crystal["radius"]):
			continue
		shot["refracted"] = true
		var setting: Dictionary = run.combos.refraction(shot, crystal)
		var split: int = setting["split"]
		var angle: float = setting["angle"]
		var damage: float = setting["damage"]
		var dir: Vector3 = shot["dir"]
		var focus: DraftEnemies.Foe = _toughest(at) if crystal["focus"] else null
		for n: int in split:
			var side: float = deg_to_rad(angle) * (1.0 if n % 2 == 0 else -1.0) * (1 + n / 2)
			var aim: Vector3 = at.direction_to(focus.pos + Vector3.UP * 0.5) if focus != null else dir.rotated(Vector3.UP, side)
			var bolt: Dictionary = run.fire_bolt(at, aim, float(shot["damage"]) * damage, float(shot["left"]), 0, -1,
				&"arcane_orb", 0.6, 0.3, DraftRun.BOLT_SPEED, &"reflets")
			bolt["refracted"] = true
			# Éclat d'une Lance (Convergence prismatique) ; jamais réfracté à nouveau.
			bolt["prism"] = shot.get("lance", false)
		return split
	return 0


func _toughest(from: Vector3) -> DraftEnemies.Foe:
	var best: DraftEnemies.Foe = null
	for foe: DraftEnemies.Foe in spells._level(run.enemies.near(from, run.tuning.aim_range), from):
		if best == null or foe.hp > best.hp:
			best = foe
	return best


func clear() -> void:
	for list: Array[Dictionary] in [wells, walls, crystals]:
		for item: Dictionary in list:
			_free(item)
		list.clear()


static func _free(item: Dictionary) -> void:
	var visual: Variant = item.get("visual")
	if visual is Node and is_instance_valid(visual):
		(visual as Node).queue_free()
