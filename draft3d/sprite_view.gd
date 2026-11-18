class_name DraftSpriteView
extends Node3D
## Sprite 2D d'origine affiché dans le monde 3D (premier jet, docs/PREMIER_JET_3D.md).
## Reprend les corrections de fluidité du prototype KayKit : image interpolée entre deux pas physiques, orientation
## gauche/droite confirmée, cycle de marche lié à la distance réellement parcourue.
## Le nœud est `top_level` : son propriétaire lui donne les positions physiques avec `push_position`.

## Mètres par pixel d'art pour une échelle de manifeste de 1 (même valeur que le prototype).
const PIXEL := 0.037
const TURN_CONFIRM_TIME := 0.12
## Orientation dos/face (Chasseur) : part verticale à l'écran du déplacement pour passer en dos ou en face, et sous
## laquelle on revient au profil. L'écart entre les deux évite le clignotement sur les diagonales.
const HEADING_ENTER := 0.82
const HEADING_LEAVE := 0.6
const SIDE := &"side"
const BACK := &"back"
const FRONT := &"front"
## Groupe de tous les sprites du monde (le rendu pixel change leur mode de transparence).
const GROUP := &"draft_sprites"

## Rendu pixel (DraftPixelRender) : sprites en transparence mélangée, dessinés après la passe de palette et de
## contours du décor, donc intacts.
static var blend_alpha: bool = false

static var _shared_blob: Mesh

var sprite: Sprite3D
var entry: Dictionary = {}
var animation: StringName = &"idle"
## Vitesse de référence du cycle de marche (m/s) : une boucle de `move` par seconde de marche à cette vitesse.
var walk_speed: float = 5.0
var facing_changes: int = 0
## Sélection dos/face/profil selon la direction à l'écran (Chasseur seulement ; repli sur le profil sans les rangées).
var directional: bool = false
## Orientation à l'écran confirmée : `SIDE`, `BACK` (s'éloigne vers le haut) ou `FRONT` (descend).
var heading: StringName = SIDE
## Animation de repos (un boss en seconde phase passe sur `phase2_idle`).
var idle_clip: StringName = &"idle"
## Hauteur ajoutée à l'image (bond d'un boss), en mètres.
var hop: float = 0.0
var _time: float = 0.0
var _walk_phase: float = 0.0
var _idle_time: float = 0.0
var _previous := Vector3.ZERO
var _current := Vector3.ZERO
var _turn_candidate: bool = false
var _turn_time: float = 0.0
var _heading_candidate: StringName = SIDE
var _heading_time: float = 0.0
var _side_left: bool = false
var _action: StringName = &""
var _action_left: float = 0.0
var _flash: float = 0.0
var _tint := Color.WHITE
var _size_mult: float = 1.0
var _base_y: float = 0.0


func setup(visual_id: StringName, size_mult: float = 1.0) -> void:
	top_level = true
	_size_mult = size_mult
	entry = Assets.entry(visual_id)
	sprite = Sprite3D.new()
	sprite.region_enabled = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.alpha_scissor_threshold = 0.3
	add_to_group(GROUP)
	refresh_alpha()
	_apply_sheet()
	var cell: Array = entry["cell"]
	# Ombre au sol calée sur l'empreinte mesurée de la feuille (champ "shadow" du manifeste, build_shadows.py) :
	# un disque plat sous les appuis, moins coûteux qu'une ombre projetée par sprite dans une horde.
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	var shape: Array = entry.get("shadow", [])
	var reach: float = (float(shape[2]) if shape.size() == 4 else float(cell[0]) * 0.2) * sprite.pixel_size
	var blob := MeshInstance3D.new()
	blob.mesh = _blob_mesh()
	blob.scale = Vector3(reach, 1.0, reach * 0.62)
	blob.position = Vector3((float(shape[0]) if shape.size() == 4 else 0.0) * sprite.pixel_size, 0.03, 0.0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)
	if not has_clip(animation):
		animation = &"move"


## Feuille, cellule, ancre et échelle de l'entrée courante du manifeste.
func _apply_sheet() -> void:
	sprite.texture = load(str(entry["sheet"]))
	var cell: Array = entry["cell"]
	var anchor: Array = entry["anchor"]
	sprite.region_rect = Rect2(0, 0, float(cell[0]), float(cell[1]))
	sprite.pixel_size = PIXEL * float(entry.get("scale", 1.0)) * _size_mult
	sprite.offset = Vector2(float(cell[0]) * 0.5 - float(anchor[0]), 0)
	_base_y = (float(anchor[1]) - float(cell[1]) * 0.5) * sprite.pixel_size + 0.04
	sprite.position.y = _base_y


## Change de feuille en gardant position et orientation (forme d'un boss par phase, feuille de mort).
## Faux si la feuille n'existe pas : rien ne change.
func swap_visual(visual_id: StringName) -> bool:
	if not Assets.has_sheet(visual_id):
		return false
	entry = Assets.entry(visual_id)
	_apply_sheet()
	_action = &""
	animation = idle_clip if has_clip(idle_clip) else &"idle"
	_time = 0.0
	return true


## Durée d'un clip à sa cadence (0 s s'il manque).
func clip_length(id: StringName) -> float:
	if not has_clip(id):
		return 0.0
	var c: Dictionary = clip(id)
	return float(c["frames"]) / maxf(float(c["fps"]), 1.0)


func refresh_alpha() -> void:
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if blend_alpha else SpriteBase3D.ALPHA_CUT_DISCARD


static func _blob_mesh() -> Mesh:
	if _shared_blob == null:
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.01
		disc.radial_segments = 20
		disc.rings = 0
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.0, 0.0, 0.03, 0.34)
		disc.material = material
		_shared_blob = disc
	return _shared_blob


func has_clip(id: StringName) -> bool:
	return (entry.get("animations", {}) as Dictionary).has(String(id))


func clip(id: StringName) -> Dictionary:
	var clips: Dictionary = entry.get("animations", {})
	return clips.get(String(id), clips.get("move", clips.get("idle", {})))


## Téléportation ou apparition : aucune traînée entre l'ancienne et la nouvelle position.
func snap_to(pos: Vector3) -> void:
	_previous = pos
	_current = pos
	global_position = pos


## Nouveau pas physique : l'image glissera de l'ancienne position vers celle-ci.
func push_position(pos: Vector3, delta: float, turn: bool = true) -> void:
	_previous = _current
	_current = pos
	var travel: Vector3 = _current - _previous
	travel.y = 0.0
	if delta <= 0.0:
		return
	if turn:
		_update_facing(travel / delta, delta)
	_update_animation(travel.length(), delta)


func render_position() -> Vector3:
	return _previous.lerp(_current, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))


## Animation ponctuelle (attaque, esquive, technique) jouée une fois par-dessus la marche.
func play_action(id: StringName, duration: float = -1.0) -> void:
	if not has_clip(id):
		return
	var c: Dictionary = clip(id)
	_action = id
	_action_left = duration if duration > 0.0 else float(c["frames"]) / maxf(float(c["fps"]), 1.0)
	animation = id
	_time = 0.0
	_apply_flip()


func flash(seconds: float = 0.12) -> void:
	_flash = seconds


func set_tint(color: Color) -> void:
	_tint = color


func face_left(left: bool) -> void:
	_side_left = left
	_apply_flip()
	_turn_time = 0.0


## Orientation suivante selon le déplacement à l'écran (x : droite, y : haut), avec hystérésis.
static func next_heading(current: StringName, screen: Vector2) -> StringName:
	var length: float = screen.length()
	if length < 0.5:
		return current
	var vertical: float = screen.y / length
	if current == SIDE:
		if vertical >= HEADING_ENTER:
			return BACK
		if vertical <= -HEADING_ENTER:
			return FRONT
		return SIDE
	var held: bool = vertical >= HEADING_LEAVE if current == BACK else vertical <= -HEADING_LEAVE
	if held:
		return current
	return next_heading(SIDE, screen)


## Clip de marche ou de repos tenant compte de l'orientation (`move_back`, `idle_front`...), sinon le profil.
func oriented(base: StringName) -> StringName:
	if not directional or heading == SIDE:
		return base
	var id := StringName("%s_%s" % [base, heading])
	return id if has_clip(id) else base


func _is_walk(id: StringName) -> bool:
	return id == &"move" or id == &"move_back" or id == &"move_front"


## Les poses dos et face sont dessinées avec l'épée en main droite : jamais retournées.
func _apply_flip() -> void:
	sprite.flip_h = _side_left and not (animation == &"idle_back" or animation == &"move_back"
		or animation == &"idle_front" or animation == &"move_front")


func _process(delta: float) -> void:
	global_position = render_position()
	sprite.position.y = _base_y + hop
	_flash = maxf(_flash - delta, 0.0)
	sprite.modulate = Color(2.2, 1.4, 1.4) if _flash > 0.0 else _tint
	var c: Dictionary = clip(animation)
	if c.is_empty():
		return
	var phase: float = _walk_phase if _is_walk(animation) else _time * float(c["fps"])
	var frame: int = int(phase)
	if bool(c.get("loop", true)) and _action == &"":
		frame %= int(c["frames"])
	else:
		frame = mini(frame, int(c["frames"]) - 1)
	var cell: Array = entry["cell"]
	sprite.region_rect.position = Vector2(frame * int(cell[0]), int(c["row"]) * int(cell[1]))


func _update_facing(velocity: Vector3, delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var horizontal: float = velocity.x if camera == null else velocity.dot(camera.global_basis.x)
	if directional:
		_update_heading(velocity, horizontal, camera, delta)
	# Trajet presque vertical ou petite correction : l'orientation est gardée.
	if absf(horizontal) < 0.5 or absf(horizontal) < velocity.length() * 0.22:
		_turn_time = 0.0
		return
	var flipped: bool = horizontal < 0.0
	if flipped == _side_left:
		_turn_time = 0.0
	elif flipped != _turn_candidate:
		_turn_candidate = flipped
		_turn_time = delta
	else:
		_turn_time += delta
	if _turn_time >= TURN_CONFIRM_TIME:
		_side_left = flipped
		_apply_flip()
		facing_changes += 1
		_turn_time = 0.0


func _update_heading(velocity: Vector3, horizontal: float, camera: Camera3D, delta: float) -> void:
	var away: Vector3 = Vector3.FORWARD if camera == null else -camera.global_basis.z
	away.y = 0.0
	var screen := Vector2(horizontal, velocity.dot(away.normalized() if away.length() > 0.01 else Vector3.FORWARD))
	var wanted: StringName = next_heading(heading, screen)
	if wanted == heading:
		_heading_time = 0.0
		return
	if wanted != _heading_candidate:
		_heading_candidate = wanted
		_heading_time = delta
	else:
		_heading_time += delta
	if _heading_time >= TURN_CONFIRM_TIME:
		heading = wanted
		_heading_time = 0.0


func _update_animation(distance: float, delta: float) -> void:
	_time += delta
	if _action != &"":
		_action_left -= delta
		if _action_left > 0.0:
			return
		_action = &""
	var speed: float = distance / delta
	_idle_time = _idle_time + delta if speed < 0.15 else 0.0
	var moving: bool = speed > 0.3 or (_is_walk(animation) and _idle_time < 0.1)
	var rest: StringName = idle_clip if has_clip(idle_clip) else &"idle"
	var next: StringName = oriented(&"move") if moving or not has_clip(rest) else oriented(rest)
	if next != animation:
		animation = next
		_time = 0.0
	_apply_flip()
	if _is_walk(next):
		var c: Dictionary = clip(next)
		# Le cycle avance avec le terrain parcouru : aucun piétinement contre un obstacle.
		_walk_phase = fmod(_walk_phase + distance * float(c["fps"]) / maxf(walk_speed, 0.1), float(c["frames"]))
