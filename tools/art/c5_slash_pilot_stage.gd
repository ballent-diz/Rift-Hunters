extends Node2D
## Poses, recul et pause d’impact de démonstration seulement. Aucun Enemy / Player / RunContext.
const WORLD_SCALE := 2.0
const START := .50
const HIT := .19
const HOLD := .045
const HERO := Vector2(-90,10)
const TARGET := Vector2(44,10)
const FLASH_SHADER := "shader_type canvas_item;
uniform float flash = 0.0;
uniform vec4 ink : source_color = vec4(0.88,1.0,1.0,1.0);
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){vec4 c=texture(TEXTURE,UV);COLOR=vec4(mix(c.rgb,ink.rgb,flash),c.a)*tint;}"
var time := 0.0
var cast_time := -1.0
var labels: Dictionary = {}
var world: Node2D
var hunter: Sprite2D
var target: Sprite2D
var ghosts: Array[Sprite2D] = []
var slash: Node2D
var impact: Node2D
var hunter_frames: SpriteFrames
var enemy_frames: SpriteFrames
var target_shadow: Polygon2D
var hunter_shadow: Polygon2D
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	var csv := FileAccess.open("res://i18n/strings.csv",FileAccess.READ)
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() > 2:
			labels[row[0]] = row[1]
	world = Node2D.new()
	world.scale = Vector2.ONE*WORLD_SCALE
	world.z_index = -1
	add_child(world)
	var background := Sprite2D.new()
	background.texture = load("res://assets/environments/fractured_plain_map/map.webp")
	background.centered = false
	background.position = HERO-Vector2(740,340)*.75
	background.scale = Vector2.ONE*.75
	background.modulate = Color(.72,.78,.79)
	world.add_child(background)
	hunter_shadow = _shadow(HERO,13)
	world.add_child(hunter_shadow)
	target_shadow = _shadow(TARGET,17)
	world.add_child(target_shadow)
	hunter_frames = Assets.get_sprite_frames(&"player.hunter")
	enemy_frames = Assets.get_sprite_frames(&"enemy.husk")
	for i: int in 3:
		var ghost := _actor(&"player.hunter")
		ghost.material = _flash_material(.8)
		world.add_child(ghost)
		ghosts.append(ghost)
	hunter = _actor(&"player.hunter")
	world.add_child(hunter)
	target = _actor(&"enemy.husk")
	target.flip_h = true
	target.material = _flash_material(0)
	world.add_child(target)
	slash = load("res://assets/vfx/hunter/cleaving_slash/cleaving_slash.tscn").instantiate()
	slash.set("destroy_on_finish",false)
	world.add_child(slash)
	impact = load("res://assets/vfx/hunter/cleaving_slash/blade_impact.tscn").instantiate()
	impact.set("destroy_on_finish",false)
	world.add_child(impact)
	sample(0.0)

func _shadow(center: Vector2, radius: float) -> Polygon2D:
	var result := Polygon2D.new()
	var points := PackedVector2Array()
	for i: int in 24:
		points.append(Vector2.from_angle(float(i)*TAU/24)*Vector2(radius,radius*.35))
	result.polygon = points
	result.position = center
	result.color = Color(.02,.035,.06,.42)
	return result

func _actor(id: StringName) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.offset = -Assets.anchor(id)
	sprite.scale = Vector2.ONE*Assets.pixel_scale(id)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite

func _flash_material(amount: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = FLASH_SHADER
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("flash",amount)
	return result

func _pose(t: float) -> int:
	if t < .055:
		return 0
	if t < .10:
		return 1
	if t < .14:
		return 2
	if t < .185:
		return 3
	if t < .215:
		return 4
	if t < .26:
		return 6
	if t < .32:
		return 5
	if t < .38:
		return 3
	return 1

func _lunge(t: float) -> float:
	return -3.0*smoothstep(0,.1,t)+15.0*smoothstep(.10,.20,t)-12.0*smoothstep(.28,.49,t)

func sample(seconds: float) -> void:
	time = fmod(seconds,2.0)
	var clock: float = time
	if clock > START+HIT:
		clock = maxf(START+HIT,clock-HOLD)
	cast_time = clock-START
	var active: bool = cast_time >= 0.0 and cast_time < .44
	var animation: StringName = &"attack" if active else &"idle"
	var frame: int = _pose(cast_time) if active else int(time*7)%6
	hunter.texture = hunter_frames.get_frame_texture(animation,frame)
	hunter.position = HERO+Vector2(_lunge(cast_time),0)
	hunter_shadow.position = hunter.position
	var hit_age: float = cast_time-HIT
	if absf(hit_age) < .0001:
		hit_age = 0.0
	var recoil: float = 0.0
	if hit_age >= 0.0:
		recoil = 13.0*(1.0-exp(-hit_age*40))*exp(-hit_age*4)
	target.texture = enemy_frames.get_frame_texture(&"move",0)
	target.position = TARGET+Vector2(recoil,-sin(clampf(hit_age/.20,0.0,1.0)*PI)*3)
	target_shadow.position = TARGET+Vector2(recoil,0)
	var flash: float = 1.0-smoothstep(0,.08,hit_age) if hit_age >= 0.0 else 0.0
	(target.material as ShaderMaterial).set_shader_parameter("flash",flash)
	for i: int in ghosts.size():
		var old_time: float = cast_time-float(i+1)*.026
		var ghost: Sprite2D = ghosts[i]
		ghost.texture = hunter_frames.get_frame_texture(&"attack",_pose(old_time))
		ghost.position = HERO+Vector2(_lunge(old_time)-float(i+1)*2.0,0)
		ghost.modulate = Color(.48,.91,1,.16-float(i)*.035)
		ghost.visible = old_time > .1 and old_time < .26
	slash.position = HERO+Vector2(6,-14)
	slash.visible = cast_time >= .09 and cast_time < .43
	slash.call("play",Vector2.RIGHT,&"base")
	slash.call("seek_visual",maxf(0,cast_time-.09))
	impact.position = target.position+Vector2(0,-20)
	impact.visible = hit_age >= 0 and hit_age < .40
	impact.call("play",Vector2.RIGHT)
	impact.call("seek_visual",maxf(0,hit_age+.02))
	var shake := Vector2.ZERO
	if hit_age >= 0 and hit_age < .16:
		shake = Vector2(sin(hit_age*150),cos(hit_age*120))*(1-hit_age/.16)*2.0
	world.position = Vector2(960,620)+shake
	queue_redraw()

func _label(key: String, pos: Vector2, size: int, ink: Color = Color("f3e4d3")) -> void:
	draw_string(font,pos,str(labels.get(key,key)),HORIZONTAL_ALIGNMENT_LEFT,1800,size,ink)

func _draw() -> void:
	# Ce bandeau décrit le démonstrateur ; il ne reproduit pas un HUD fonctionnel.
	draw_rect(Rect2(0,0,1920,150),Color(.025,.04,.07,.94))
	_label("C5P_TITLE",Vector2(54,64),35)
	_label("C5P_SUBTITLE",Vector2(56,106),20,Color("a6ccd3"))
	draw_line(Vector2(54,132),Vector2(1866,132),Color("638a98"),2)
	draw_rect(Rect2(0,925,1920,155),Color(.025,.04,.07,.95))
	var phase: int = 0 if cast_time < .14 else (1 if cast_time+.0001 < .19 else (2 if cast_time < .27 else 3))
	if cast_time < 0 or cast_time > .5:
		phase = -1
	for i: int in 4:
		var x: float = 56+i*466
		draw_rect(Rect2(x,950,438,52),Color("203c48") if phase == i else Color("111c29"))
		draw_rect(Rect2(x,950,4,52),Color("d6f8ff") if phase == i else Color("465e6e"))
		_label(["C5P_WINDUP","C5P_CUT","C5P_HIT","C5P_RECOVERY"][i],Vector2(x+20,985),21)
	_label("C5P_NOTE",Vector2(56,1044),17,Color("b9c8cd"))
