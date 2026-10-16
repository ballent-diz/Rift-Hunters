extends Node2D
## Dix familles VFX C5 autonomes. Aucune lecture du combat, aucun dégât, déplacement ou collision.
signal visual_finished
const Shapes = preload("res://assets/vfx/hunter/effects_common.gd")
const BRUSH = preload("res://assets/vfx/hunter/cleaving_slash/textures/blade-ribbon.png")
const PALETTE = preload("res://assets/vfx/hunter/cel_paint.gdshader")
const WHITE := Color("eaffff")
const CYAN := Color("79deee")
const JADE := Color("a0dfba")
const VOID_EDGE := Color("b7c7ec")
const AMBER := Color("ebc48d")

@export var effect_kind: StringName = &"rift_leap"
@export var spell_range: float = 380.0
@export var active_duration: float = -1.0
@export var destination_offset := Vector2(380,0)
@export var destroy_on_finish: bool = true
var variant: StringName = &"base"
var secondary_offsets := PackedVector2Array()
var secondary_colors := PackedColorArray()
var _elapsed := 0.0
var _playing := false
var _pulse_age := 99.0
var _pulse_point := Vector2.ZERO
var _pulse_direction := Vector2.RIGHT

func _ready() -> void:
	var paint := ShaderMaterial.new()
	paint.shader = PALETTE
	material = paint

func play(direction: Vector2 = Vector2.RIGHT, p_variant: StringName = &"base") -> void:
	variant = p_variant
	rotation = direction.angle() if direction.length_squared() > .001 else 0.0
	_elapsed = 0.0
	_pulse_age = 99.0
	_playing = true
	queue_redraw()

func play_from(direction: Vector2, p_variant: StringName, seconds: float) -> void:
	play(direction,p_variant)
	_elapsed = maxf(seconds,0.0)
	queue_redraw()

func play_between(from: Vector2, to: Vector2, p_variant: StringName = &"base") -> void:
	global_position = from
	var delta: Vector2 = to-from
	destination_offset = Vector2(delta.length(),0)
	play(delta,p_variant)

## Positions locales après orientation de la scène. Le parent fournit les vraies positions.
func set_secondary_offsets(offsets: PackedVector2Array) -> void:
	secondary_offsets = offsets.slice(0,16)
	queue_redraw()

func set_secondary_colors(colors: PackedColorArray) -> void:
	secondary_colors = colors
	queue_redraw()

func set_destination(offset: Vector2) -> void:
	destination_offset = offset
	queue_redraw()

## Un contact réel déclenche ces accents, jamais une simulation de parade ou de réfraction.
func trigger_pulse(point: Vector2 = Vector2.ZERO, direction: Vector2 = Vector2.RIGHT) -> void:
	_pulse_point = point
	_pulse_direction = direction.normalized() if direction.length_squared() > .001 else Vector2.RIGHT
	_pulse_age = 0.0
	queue_redraw()

func release() -> void:
	_elapsed = maxf(_elapsed,duration()-.35)
	_playing = true
	queue_redraw()

func seek_visual(seconds: float) -> void:
	_elapsed = maxf(seconds,0.0)
	_playing = false
	queue_redraw()

func _hold(default_seconds: float) -> float:
	return maxf(.1,active_duration) if active_duration >= 0.0 else default_seconds

func duration() -> float:
	match effect_kind:
		&"rift_leap": return 1.05 if variant == &"impact" else .85
		&"parry": return .70
		&"rupture": return 3.65 if variant == &"inferno" else (1.10 if variant == &"reaction" else .85)
		&"refractor_crystal": return _hold(8.0)+.65
		&"singularity": return _hold(1.5 if variant == &"collapse" else 3.0)+.65
		&"rift_wall", &"twin_rifts": return _hold(4.0)+.60
		&"pack_call": return 1.30 if variant == &"rally" else .90
		&"rift_aegis": return _hold(4.0)+.50
		&"swap": return 1.35 if variant == &"sanctuary" else .85
	return .85

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_pulse_age += delta
	queue_redraw()
	if _elapsed >= duration():
		_playing = false
		visual_finished.emit()
		if destroy_on_finish:
			queue_free()

func _envelope() -> float:
	return smoothstep(0.0,.13,_elapsed)*(1.0-smoothstep(duration()-.35,duration(),_elapsed))

func _draw() -> void:
	if _elapsed >= duration():
		return
	match effect_kind:
		&"rift_leap": _leap()
		&"parry": _parry()
		&"rupture": _rupture()
		&"refractor_crystal": _refractor()
		&"singularity": _singularity()
		&"rift_wall": _wall()
		&"twin_rifts": _twins()
		&"pack_call": _pack()
		&"rift_aegis": _aegis()
		&"swap": _swap()

func _arc(center: Vector2, radius: float, start: float, finish: float, width: float, ink: Color) -> void:
	if radius < .1 or finish-start < .01:
		return
	var points := PackedVector2Array()
	for i: int in 25:
		points.append(center+Vector2.from_angle(lerpf(start,finish,float(i)/24))*radius)
	Shapes.painted_path(self,points,width,BRUSH,ink)

func _curve(from: Vector2, to: Vector2, bend: Vector2, begin: float, end: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in 17:
		var t: float = lerpf(begin,end,float(i)/16)
		result.append(from.lerp(to,t)+bend*sin(t*PI))
	return result

func _stream(from: Vector2, to: Vector2, bend: Vector2, progress: float, width: float, ink: Color) -> void:
	var head: float = clampf(progress,0,1)
	if head < .01:
		return
	var points := _curve(from,to,bend,maxf(0,head-.42),head)
	Shapes.painted_path(self,points,width,BRUSH,ink)
	Shapes.star(self,points[points.size()-1],5,Color(WHITE,ink.a))

func _portal(center: Vector2, radius: float, opacity: float, spin: float, ink: Color = CYAN) -> void:
	if opacity < .001 or radius < .1:
		return
	draw_set_transform(center,0,Vector2(1,.72))
	draw_circle(Vector2.ZERO,radius*.72,Color(.025,.055,.10,opacity*.68))
	for i: int in 3:
		var a: float = spin+float(i)*TAU/3
		_arc(Vector2.ZERO,radius,a,a+1.65,16,Color(ink,opacity*.75))
	Shapes.ring(self,Vector2.ZERO,radius*.68,Color(WHITE,opacity*.6),1.2)
	for i: int in 6:
		var angle: float = spin*1.5+float(i)*TAU/6
		Shapes.facet(self,Vector2.from_angle(angle)*(radius+4),angle+PI*.5,8,3,ink,WHITE,opacity*.7)
	draw_set_transform(Vector2.ZERO)

func _fracture(center: Vector2, radius: float, opacity: float, count: int = 10) -> void:
	if opacity < .001 or radius < 1:
		return
	for i: int in count:
		var angle: float = float(i)*TAU/count+.11*sin(float(i)*3)
		var along := Vector2.from_angle(angle)
		var sideways := along.orthogonal()
		var points := PackedVector2Array([center+along*8,center+along*radius*.35+sideways*9,
			center+along*radius*.64-sideways*5,center+along*radius])
		Shapes.painted_path(self,points,10,BRUSH,Color(WHITE,opacity))
		Shapes.facet(self,center+along*radius,angle,12,4,CYAN,WHITE,opacity*.7)

func _leap() -> void:
	var arrival := destination_offset
	var travel: float = clampf((_elapsed-.10)/.28,0,1)
	var fade: float = 1.0-smoothstep(.38,.72,_elapsed)
	_portal(Vector2.ZERO,19*(.65+travel*.35),fade,_elapsed*5)
	if travel < 1:
		_stream(Vector2.ZERO,arrival,Vector2(0,-48),travel,86,Color(WHITE,fade*.9))
		for i: int in 3:
			var p: float = maxf(0,travel-float(i+1)*.06)
			var point: Vector2 = Vector2.ZERO.lerp(arrival,p)+Vector2(0,-48*sin(p*PI))
			Shapes.facet(self,point,0,12,4,CYAN,WHITE,fade*(.50-float(i)*.1))
	var age: float = _elapsed-.38
	var reach: float = 150 if variant == &"impact" else 75
	Shapes.burst(self,arrival,age,.45,26,reach*.6,CYAN,WHITE,.2)
	if age >= 0 and age < .60:
		var p: float = age/.60
		_arc(arrival,8+p*reach,-p*2,TAU-p*2,24,Color(CYAN,pow(1-p,1.8)*.8))
		_fracture(arrival,reach*.72,clampf(1-age/.35,0,1)*.35,8)
	if variant == &"return":
		_portal(Vector2.ZERO,23,_envelope()*.45,-_elapsed*4,VOID_EDGE)
		_portal(arrival,23,clampf(age*8,0,1)*(1-smoothstep(.55,.85,_elapsed)),_elapsed*4,VOID_EDGE)

func _guard(center: Vector2, radius: float, ink: Color, opacity: float) -> void:
	_arc(center,radius,-PI*.42,PI*.42,35,Color(ink,opacity*.65))
	Shapes.ring(self,center,radius-7,Color(WHITE,opacity*.7),1.5,-PI*.42,PI*.42)
	for i: int in 5:
		var angle: float = lerpf(-1.2,1.2,float(i)/4)
		Shapes.facet(self,center+Vector2.from_angle(angle)*radius,angle+PI*.5,10,3,ink,WHITE,opacity)

func _parry() -> void:
	var fade: float = smoothstep(0,.035,_elapsed)*(1-smoothstep(.40,.70,_elapsed))
	_guard(Vector2(0,-12),spell_range,CYAN,fade)
	if variant == &"pack_guard":
		for i: int in mini(3,secondary_offsets.size()):
			_guard(secondary_offsets[i]+Vector2(0,-12),34,JADE,fade*.75)
			draw_line(Vector2.ZERO,secondary_offsets[i],Color(JADE,fade*.16),1,false)
	if _pulse_age < .32:
		var point: Vector2 = _pulse_point if _pulse_point != Vector2.ZERO else Vector2(spell_range-6,-12)
		Shapes.burst(self,point,_pulse_age,.32,22,48,CYAN,WHITE,.3)
		Shapes.star(self,point,28*(1-_pulse_age/.32),WHITE)
		_arc(Vector2.ZERO,96,-1.1+_pulse_age*7,1.1+_pulse_age*7,45,Color(WHITE,1-_pulse_age/.32))
		if variant == &"mirror":
			_stream(point,point+_pulse_direction*260,Vector2.ZERO,_pulse_age/.25,42,WHITE)

func _detonation(center: Vector2, age: float, radius: float, opacity: float = 1.0) -> void:
	if age < 0 or age > .75:
		return
	var p: float = age/.75
	var growing: float = 1.0-pow(1-clampf(p/.42,0,1),2.0)
	Shapes.star(self,center,36*(1-smoothstep(0,.15,age)),Color(WHITE,opacity))
	_arc(center,6+radius*growing,-p*3,TAU-p*3,38,Color(CYAN,opacity*pow(1-p,2)*.65))
	_fracture(center,radius*growing,opacity*pow(1-p,2)*.65,12)
	Shapes.burst(self,center,age,.7,28,radius*.88,CYAN,WHITE,.4)

func _rupture() -> void:
	_detonation(Vector2.ZERO,_elapsed,spell_range)
	if variant == &"reaction":
		for i: int in mini(8,secondary_offsets.size()):
			_detonation(secondary_offsets[i],_elapsed-float(i+1)*.045,spell_range*.36,.65)
	if variant == &"inferno" and _elapsed > .15:
		var alpha: float = smoothstep(.15,.40,_elapsed)*(1-smoothstep(3.15,3.65,_elapsed))
		for i: int in 12:
			var angle: float = float(i)*TAU/12
			var base := Vector2.from_angle(angle)*spell_range*.65
			var height: float = 22+9*sin(_elapsed*8+float(i)*2.1)
			var flame := PackedVector2Array([base,base+Vector2(7,-height*.45),base+Vector2(-3,-height)])
			Shapes.painted_path(self,flame,37,BRUSH,Color(AMBER,alpha*.50))
		Shapes.ring(self,Vector2.ZERO,spell_range*.72,Color(AMBER,alpha*.18),2)

func _crystal(center: Vector2, opacity: float, spin: float) -> void:
	var floating := center+Vector2(0,-25+sin(_elapsed*3+spin)*2)
	draw_set_transform(center,0,Vector2(1,.38))
	Shapes.ring(self,Vector2.ZERO,19,Color(CYAN,opacity*.35),1.5)
	draw_set_transform(Vector2.ZERO)
	Shapes.facet(self,floating,-PI*.5,64,29,Color("297b9e"),CYAN,opacity)
	Shapes.facet(self,floating+Vector2(-4,-3),-PI*.5,43,10,CYAN,WHITE,opacity*.9)
	for i: int in 3:
		var angle: float = spin+float(i)*TAU/3
		var satellite := floating+Vector2(cos(angle)*25,sin(angle)*12)
		Shapes.facet(self,satellite,-angle,11,5,CYAN,WHITE,opacity*.7)
	Shapes.star(self,floating+Vector2(-5,-14),5,Color(WHITE,opacity))

func _refractor() -> void:
	var alpha: float = _envelope()
	_crystal(Vector2.ZERO,alpha,_elapsed*1.6)
	if variant == &"double_prism":
		_crystal(destination_offset,alpha,-_elapsed*1.6)
		draw_line(Vector2(0,-25),destination_offset+Vector2(0,-25),Color(CYAN,alpha*.13),1,false)
	if _pulse_age < .30:
		var center: Vector2 = _pulse_point+Vector2(0,-25)
		var progress: float = clampf(_pulse_age/.22,0,1)
		for i: int in 3:
			var angle: float = _pulse_direction.angle()+float(i-1)*.30
			var end := center+Vector2.from_angle(angle)*260
			if variant == &"focus":
				end = destination_offset
			_stream(center,end,Vector2(0,float(i-1)*12),progress,36,Color(WHITE,1-_pulse_age/.30))
		Shapes.burst(self,center,_pulse_age,.30,14,33,CYAN,WHITE,.1)

func _singularity() -> void:
	var radius: float = spell_range*(1.4 if variant == &"horizon" else 1.0)
	var end_hold: float = duration()-.65
	var implode: float = clampf((_elapsed-end_hold)/.65,0,1)
	var alpha: float = _envelope()
	var size: float = radius*(1-implode*.86)
	draw_circle(Vector2.ZERO,17*(1-implode*.7),Color(.025,.035,.08,alpha*.85))
	Shapes.ring(self,Vector2.ZERO,21*(1-implode*.7),Color(WHITE,alpha*.9),2)
	for arm: int in 3:
		var points := PackedVector2Array()
		for i: int in 29:
			var p: float = float(i)/28
			var angle: float = _elapsed*(3.0 if variant == &"collapse" else 1.5)+float(arm)*TAU/3+p*2.7
			points.append(Vector2.from_angle(angle)*lerpf(size,22,p))
		Shapes.painted_path(self,points,23,BRUSH,Color(VOID_EDGE,alpha*.38))
	for i: int in 24:
		var p: float = fmod(_elapsed*(.75 if variant != &"collapse" else 1.3)+float(i)*.137,1)
		var angle: float = float(i)*2.399+_elapsed*.5
		var point := Vector2.from_angle(angle)*size*(1-p)
		Shapes.facet(self,point,angle+PI,4+5*p,2,VOID_EDGE,WHITE,alpha*p*.8)
	if implode > .01:
		Shapes.star(self,Vector2.ZERO,42*sin(implode*PI),Color(WHITE,alpha))
		Shapes.burst(self,Vector2.ZERO,_elapsed-end_hold-.26,.38,24,58,VOID_EDGE,WHITE,.25)

func _wall() -> void:
	var alpha: float = _envelope()
	var half: float = spell_range*.5
	var wall := PackedVector2Array()
	for i: int in 17:
		var y: float = lerpf(-half,half,float(i)/16)
		wall.append(Vector2(sin(float(i)*3+_elapsed*4)*2,y))
	Shapes.painted_path(self,wall,66,BRUSH,Color(WHITE,alpha*.75))
	for i: int in 13:
		var y: float = lerpf(-half,half,float(i)/12)
		Shapes.facet(self,Vector2(0,y),PI*.5,18,7,VOID_EDGE,WHITE,alpha*.6)
		if variant == &"burning_wall":
			var flame := PackedVector2Array([Vector2(4,y),Vector2(18+sin(_elapsed*8+i)*7,y-6),Vector2(35,y-3)])
			Shapes.painted_path(self,flame,24,BRUSH,Color(AMBER,alpha*.65))
	if variant == &"chains":
		for i: int in mini(8,secondary_offsets.size()):
			var end: Vector2 = secondary_offsets[i]
			var start := Vector2(0,clampf(end.y,-half,half))
			var chain := _curve(start,end,Vector2(0,12),0,1)
			draw_polyline(chain,Color(VOID_EDGE,alpha*.6),1.5,false)
			for link: int in 5:
				var point: Vector2 = start.lerp(end,float(link+1)/6)
				Shapes.ring(self,point,3,Color(WHITE,alpha*.6),1)
	if _pulse_age < .25:
		Shapes.burst(self,_pulse_point,_pulse_age,.25,14,36,CYAN,WHITE,.5)

func _twins() -> void:
	var alpha: float = _envelope()
	var radius: float = 39 if variant == &"exile" else 31
	_portal(Vector2.ZERO,radius,alpha,_elapsed*3)
	_portal(destination_offset,radius,alpha,-_elapsed*3)
	for i: int in 4:
		var p: float = fmod(_elapsed*.55+float(i)*.25,1)
		_stream(Vector2.ZERO,destination_offset,Vector2(0,-22),p,25,Color(CYAN,alpha*.23))
	if variant == &"loop":
		_portal(destination_offset,radius*.68,alpha*.45,_elapsed*4,WHITE)
		_stream(destination_offset,Vector2.ZERO,Vector2(0,22),fmod(_elapsed*.7,1),25,Color(WHITE,alpha*.3))
	if variant == &"exile":
		_arc(destination_offset,radius+17,_elapsed*2,_elapsed*2+PI*1.7,15,Color(VOID_EDGE,alpha*.4))
	if _pulse_age < .30:
		for point: Vector2 in [Vector2.ZERO,destination_offset]:
			Shapes.burst(self,point,_pulse_age,.30,12,38,CYAN,WHITE,.15)

func _pack() -> void:
	var travel: float = clampf((_elapsed-.06)/.33,0,1)
	var alpha: float = 1-smoothstep(.46,.90,_elapsed)
	for i: int in mini(3,secondary_offsets.size()):
		var ink: Color = secondary_colors[i] if i < secondary_colors.size() else JADE
		_stream(secondary_offsets[i],destination_offset,Vector2(0,-26-float(i)*9),travel,58,Color(ink,alpha*.85))
	var age: float = _elapsed-.39
	Shapes.burst(self,destination_offset,age,.44,22,58,JADE,WHITE,.17)
	if age >= 0 and age < .40:
		var p: float = age/.40
		_arc(destination_offset,12+p*57,-p*3,TAU-p*3,24,Color(JADE,(1-p)*.65))
	if variant == &"feast" and age >= 0 and age < .27:
		for i: int in 3:
			var off := Vector2(float(i-1)*13,0)
			var slash := PackedVector2Array([destination_offset+off+Vector2(-28,-34),
				destination_offset+off,destination_offset+off+Vector2(26,36)])
			Shapes.painted_path(self,slash,30,BRUSH,Color(WHITE,1-age/.27))
	if variant == &"rally":
		var opacity: float = smoothstep(.1,.3,_elapsed)*(1-smoothstep(.8,1.3,_elapsed))
		for i: int in mini(3,secondary_offsets.size()):
			var center: Vector2 = secondary_offsets[i]
			Shapes.ring(self,center,27+sin(_elapsed*7+i)*2,Color(JADE,opacity*.45),1.5)
			Shapes.star(self,center+Vector2(0,-32),6,Color(WHITE,opacity*.8))

func _shield(center: Vector2, alpha: float, strength: float = 1.0) -> void:
	var p := PackedVector2Array([Vector2(-27,8),Vector2(-31,-22),Vector2(0,-49),
		Vector2(31,-22),Vector2(27,8),Vector2(0,25)])
	for i: int in p.size():
		p[i] = center+p[i]*strength
	draw_colored_polygon(p,Color(JADE,alpha*.055))
	p.append(p[0])
	draw_polyline(p,Color(JADE,alpha*.75),1.6,false)
	_arc(center+Vector2(0,-10),34*strength,-_elapsed*2,-_elapsed*2+2.3,25,Color(WHITE,alpha*.35))
	for i: int in 3:
		var point: Vector2 = center+Vector2.from_angle(_elapsed*1.5+float(i)*TAU/3)*Vector2(32,25)
		Shapes.star(self,point,3,Color(WHITE,alpha*.6))

func _aegis() -> void:
	var alpha: float = _envelope()
	_shield(Vector2.ZERO,alpha,.82 if variant == &"sharing" else 1.0)
	for i: int in mini(3,secondary_offsets.size()):
		var center: Vector2 = secondary_offsets[i]
		_shield(center,alpha,.78)
		if variant == &"sharing":
			draw_polyline(_curve(Vector2.ZERO,center,Vector2(0,-16),0,1),Color(JADE,alpha*.24),1,false)
	if _pulse_age < .38:
		Shapes.burst(self,_pulse_point,_pulse_age,.38,24,68,JADE,WHITE,.3)
		if variant == &"riposte":
			var radius: float = 12+_pulse_age/.38*180
			_arc(Vector2.ZERO,radius,-_pulse_age*4,TAU-_pulse_age*4,35,Color(WHITE,1-_pulse_age/.38))

func _swap() -> void:
	var travel: float = clampf((_elapsed-.12)/.28,0,1)
	var opacity: float = smoothstep(0,.10,_elapsed)*(1-smoothstep(.48,.85,_elapsed))
	_portal(Vector2.ZERO,27,opacity,_elapsed*6,JADE)
	_portal(destination_offset,27,opacity,-_elapsed*6,JADE)
	_stream(Vector2.ZERO,destination_offset,Vector2(0,-30),travel,67,Color(WHITE,opacity*.85))
	_stream(destination_offset,Vector2.ZERO,Vector2(0,30),travel,67,Color(JADE,opacity*.65))
	var age: float = _elapsed-.40
	for point: Vector2 in [Vector2.ZERO,destination_offset]:
		Shapes.burst(self,point,age,.40,12,37,JADE,WHITE,.2)
		if variant == &"sanctuary" and age >= 0 and age < .95:
			var p: float = age/.95
			_arc(point,19+p*70,-p,TAU-p,28,Color(JADE,(1-p)*.55))
			Shapes.star(self,point+Vector2(0,-25-p*16),6*(1-p),Color(WHITE,1-p))
	if variant == &"relay" and _pulse_age < .26:
		_stream(destination_offset,destination_offset+_pulse_direction*160,Vector2.ZERO,
			_pulse_age/.22,43,Color(WHITE,1-_pulse_age/.26))
