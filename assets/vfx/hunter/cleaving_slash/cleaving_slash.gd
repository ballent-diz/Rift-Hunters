extends Node2D
## Chorégraphie autonome : armé, coupe balayée, doubles traînées, étincelles et dissipation.
signal visual_finished
const Shapes = preload("res://assets/vfx/hunter/effects_common.gd")
const GOLD := Color("f6b760")
const IVORY := Color("fff5d7")
const COPPER := Color("bb603a")

@export var spell_range: float = 150.0
@export var thrust_range: float = 320.0
@export var half_angle_degrees: float = 60.0
@export var destroy_on_finish: bool = true
var variant: StringName = &"base"
var _elapsed: float = 0.0
var _playing: bool = false

func play(direction: Vector2 = Vector2.RIGHT, p_variant: StringName = &"base") -> void:
	variant = p_variant
	rotation = direction.angle() if direction.length_squared() > 0.001 else 0.0
	_elapsed = 0.0
	_playing = true
	queue_redraw()

func duration() -> float:
	return .55 if variant == &"whirlwind" else (.40 if variant == &"thrust" else .34)

func seek_visual(seconds: float) -> void:
	_elapsed = maxf(seconds,0.0)
	_playing = false
	queue_redraw()

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= duration():
		_playing = false
		visual_finished.emit()
		if destroy_on_finish:
			queue_free()

func _draw() -> void:
	if _elapsed >= duration():
		return
	if variant == &"thrust":
		_thrust()
		return
	var phase: float = _elapsed/duration()
	var windup: float = clampf(phase/.14,0.0,1.0)
	var sweep: float = clampf((phase-.08)/.58,0.0,1.0)
	var fade: float = 1.0-smoothstep(.55,1.0,phase)
	var half: float = deg_to_rad(half_angle_degrees)
	var start: float = -half
	var finish: float = half
	if variant == &"whirlwind":
		start = -PI*.85
		finish = start+TAU
	var head: float = lerpf(start,finish,1.0-pow(1.0-sweep,1.8))
	var tail: float = maxf(start,head-(2.8 if variant == &"whirlwind" else 1.3))
	if phase < .18:
		var armed := Vector2.from_angle(start)*38.0
		Shapes.facet(self,armed,start,43.0*windup,3,GOLD,IVORY,(1.0-phase/.18)*.8)
		Shapes.star(self,armed,9.0*sin(windup*PI),IVORY)
	if sweep > 0.0:
		_ribbon(spell_range-7,tail-.07,head-.07,20,Color(COPPER,fade*.24))
		_ribbon(spell_range-2,tail,head,17,Color(GOLD,fade*.35))
		_ribbon(spell_range-5,tail+.02,head,10,Color(GOLD,fade))
		_ribbon(spell_range-3,tail+.13,head,3.3,Color(IVORY,fade))
		_ribbon(spell_range-24,tail+.1,head-.1,2,Color(IVORY,fade*.42))
		var tip := Vector2.from_angle(head)*(spell_range-8)
		var inner := Vector2.from_angle(head)*38.0
		var sideways := Vector2.from_angle(head).orthogonal()
		if phase < .65:
			draw_colored_polygon(PackedVector2Array([inner,tip+sideways*4,tip-sideways*2]),Color(IVORY,fade*.8))
		Shapes.star(self,tip,11.0*fade,Color(IVORY,fade),head)
		for i: int in 11:
			var lag: float = float(i)/11.0
			var angle: float = lerpf(tail,head,lag)
			var radius: float = spell_range-30-12*sin(float(i)*2.1+phase*7)
			var point := Vector2.from_angle(angle)*radius
			var ink: Color = Color(IVORY,fade*lag*.8)
			draw_line(point-Vector2.from_angle(angle+.8)*7,point,ink,1.5,false)
	var impact := Vector2.from_angle(finish)*(spell_range-8)
	Shapes.burst(self,impact,_elapsed-duration()*.49,duration()*.51,17,37,GOLD,IVORY,.17)
	if variant == &"whirlwind":
		for i: int in 3:
			var angle: float = start+float(i)*TAU/3.0
			Shapes.burst(self,Vector2.from_angle(angle)*(spell_range-16),
				_elapsed-.08-float(i)*.065,.25,8,25,COPPER,GOLD,float(i)*.11)
		var ring_opacity: float = sin(clampf(phase/.72,0.0,1.0)*PI)*.32
		Shapes.ring(self,Vector2.ZERO,spell_range*(.25+phase*.55),Color(GOLD,ring_opacity),1.4)

func _ribbon(radius: float, start: float, finish: float, thickness: float, ink: Color) -> void:
	if finish-start < .01:
		return
	var steps := 36
	for j: int in steps:
		var t0: float = float(j)/steps
		var t1: float = float(j+1)/steps
		var width0: float = maxf(.15,thickness*.5*pow(maxf(sin(t0*PI),0),.65))
		var width1: float = maxf(.15,thickness*.5*pow(maxf(sin(t1*PI),0),.65))
		var a := Vector2.from_angle(lerpf(start,finish,t0))
		var b := Vector2.from_angle(lerpf(start,finish,t1))
		draw_colored_polygon(PackedVector2Array([a*(radius+width0),b*(radius+width1),
			b*(radius-width1),a*(radius-width0)]),ink)

func _thrust() -> void:
	var phase: float = _elapsed/duration()
	var reach: float = thrust_range*(1.0-pow(1.0-clampf((phase-.12)/.36,0.0,1.0),2.2))
	var fade: float = 1.0-smoothstep(.50,1.0,phase)
	if phase < .28:
		Shapes.ring(self,Vector2(22,0),23.0*(1.0-phase/.28),Color(GOLD,.6),1.5,-1.1,1.1)
		Shapes.star(self,Vector2(18,0),9*sin(clampf(phase/.28,0.0,1.0)*PI),IVORY)
	if reach > 12:
		var points := PackedVector2Array([Vector2(7,0),Vector2(reach-29,-9),
			Vector2(reach,0),Vector2(reach-29,9)])
		draw_colored_polygon(points,Color(COPPER,fade*.7))
		draw_line(Vector2(9,0),Vector2(reach-4,0),Color(GOLD,fade),5.0,false)
		draw_line(Vector2(12,0),Vector2(reach,0),Color(IVORY,fade),1.8,false)
		Shapes.facet(self,Vector2(reach-24,0),0,48,12,GOLD,IVORY,fade)
		for i: int in 4:
			var x: float = reach-float(i)*38-42
			if x > 20:
				for sign_y: float in [-1.0,1.0]:
					draw_line(Vector2(x-20,sign_y*12),Vector2(x,sign_y*6),Color(GOLD,fade*.7),1,false)
	Shapes.burst(self,Vector2(thrust_range-5,0),_elapsed-.16,.24,20,35,GOLD,IVORY,.3)
	if phase > .40:
		var impact: float = (phase-.40)/.60
		Shapes.ring(self,Vector2(thrust_range-8,0),4+impact*26,Color(GOLD,(1-impact)*.8),1.5)
