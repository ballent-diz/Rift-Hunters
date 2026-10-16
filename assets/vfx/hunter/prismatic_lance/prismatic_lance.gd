extends Node2D
## Cristal lancé : charge orbitale, poussée, pointe facettée, sillage et dispersion terminale.
signal visual_finished
const Shapes = preload("res://assets/vfx/hunter/effects_common.gd")
const CYAN := Color("64def4")
const WHITE := Color("eaffff")
const BLUE := Color("326faa")

@export var spell_range: float = 700.0
@export var projectile_speed: float = 950.0
@export var half_width: float = 14.0
@export var fan_angle_degrees: float = 14.0
@export var destroy_on_finish: bool = true
var variant: StringName = &"base"
var charge_ratio: float = 0.0
var _elapsed: float = 0.0
var _playing: bool = false

func play(direction: Vector2 = Vector2.RIGHT, p_variant: StringName = &"base") -> void:
	variant = p_variant
	rotation = direction.angle() if direction.length_squared() > .001 else 0.0
	_elapsed = 0.0
	_playing = true
	queue_redraw()

func duration() -> float:
	return INF if variant == &"charge" else spell_range/maxf(projectile_speed,1.0)+.24

func set_charge_ratio(value: float) -> void:
	charge_ratio = clampf(value,0.0,1.0)
	queue_redraw()

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
	if variant == &"charge":
		_charge()
		return
	if _elapsed >= duration():
		return
	var power: float = 1.5 if variant == &"overcharge" else 1.0
	Shapes.burst(self,Vector2(26,0),_elapsed,.24,14,36*power,BLUE,CYAN,.3)
	var muzzle: float = 1.0-clampf(_elapsed/.18,0.0,1.0)
	if muzzle > 0:
		Shapes.star(self,Vector2(22,0),18*power*muzzle,Color(WHITE,muzzle*.8))
		Shapes.ring(self,Vector2(22,0),8+(1-muzzle)*24,Color(CYAN,muzzle*.7),1.5)
	if variant == &"fan":
		for angle: float in [-fan_angle_degrees,0.0,fan_angle_degrees]:
			_lance(deg_to_rad(angle),1.0)
	else:
		_lance(0.0,power)

func _charge() -> void:
	var ratio: float = charge_ratio
	var radius: float = 12+ratio*15
	var pulse: float = .78+.22*sin(_elapsed*TAU*4)
	var center := Vector2(25,0)
	Shapes.ring(self,center,radius,Color(CYAN,.35*pulse),1.5,_elapsed*2,_elapsed*2+PI*1.5)
	Shapes.ring(self,center,radius*.64,Color(WHITE,.65*pulse),1,-_elapsed*3,-_elapsed*3+PI*1.3)
	for i: int in 6:
		var angle: float = _elapsed*(2.5+ratio*3)+float(i)*TAU/6
		var point: Vector2 = center+Vector2(cos(angle)*radius,sin(angle)*radius*.74)
		var opacity: float = .45+.45*(sin(angle)+1)*.5
		Shapes.facet(self,point,angle+.6,6+ratio*9,4+ratio*3,BLUE,WHITE,opacity)
		var inner: Vector2 = center+(point-center)*.64
		draw_line(inner,point,Color(CYAN,ratio*.25),1,false)
	Shapes.facet(self,center,0,12+ratio*22,5+ratio*12,CYAN,WHITE,pulse)
	Shapes.star(self,center,5+ratio*9,Color(WHITE,pulse))
	for i: int in 8:
		var travel: float = fmod(_elapsed*1.7+float(i)*.137,1.0)
		var angle: float = float(i)*2.399
		var outside: Vector2 = center+Vector2.from_angle(angle)*(radius+20)*(1.0-travel)
		draw_line(outside,outside+Vector2.from_angle(angle)*4,Color(CYAN,travel*.7),1,false)

func _lance(angle: float, power: float) -> void:
	draw_set_transform(Vector2.ZERO,angle,Vector2.ONE)
	var travel_time: float = spell_range/maxf(projectile_speed,1.0)
	var head: float = minf(spell_range,_elapsed*projectile_speed)
	var end_fade: float = 1.0-clampf((_elapsed-travel_time)/.24,0.0,1.0)
	var width: float = half_width*power
	if head > 4 and end_fade > 0:
		var tail: float = maxf(14.0,head-155*power)
		if head > tail+2:
			# Traînée fuselée, fil blanc et deux filaments décalés.
			for layer: int in 3:
				var opacity: float = [.13,.35,.85][layer]*end_fade
				var thickness: float = [width*.85,width*.40,2.0][layer]
				var points := PackedVector2Array([Vector2(tail,0),Vector2(head-38,-thickness),
					Vector2(head,0),Vector2(head-38,thickness)])
				draw_colored_polygon(points,Color(BLUE if layer == 0 else CYAN,opacity))
			draw_line(Vector2(tail+12,0),Vector2(head-4,0),Color(WHITE,end_fade),1.7*power,false)
			for sign_y: float in [-1.0,1.0]:
				var filament := PackedVector2Array()
				for j: int in 9:
					var t: float = float(j)/8
					var x: float = lerpf(tail,head-15,t)
					var y: float = sin(t*PI)*width*.7*sign_y
					y += sin(t*10+_elapsed*13)*2*power
					filament.append(Vector2(x,y))
				draw_polyline(filament,Color(CYAN,end_fade*.5),1,false)
		# Pointe en cristal à trois faces, reflets et fragments en orbite.
		if head > 25:
			var length: float = minf(76*power,head-8)
			var center := Vector2(head-length*.55,0)
			Shapes.facet(self,center,0,length,width*2,BLUE,CYAN,end_fade)
			Shapes.facet(self,center+Vector2(5,-width*.12),0,length*.71,width*.55,CYAN,WHITE,end_fade)
			Shapes.star(self,Vector2(head-10,0),8.0*power,Color(WHITE,end_fade*.85))
			for i: int in 6:
				var lag: float = float(i)*19+30
				var x: float = head-lag
				if x < 12:
					continue
				var orbit: float = float(i)*2.4+_elapsed*10
				var y: float = sin(orbit)*(width+7)*(.45+float(i)*.1)
				var opacity: float = (1.0-float(i)/7.0)*end_fade*.8
				Shapes.facet(self,Vector2(x,y),-.2*cos(orbit),10+power*5,4,BLUE,WHITE,opacity)
			if power > 1.0:
				for ring_index: int in 2:
					var ellipse := PackedVector2Array()
					var origin: float = head-32-float(ring_index)*28
					for j: int in 25:
						var a: float = float(j)/24*TAU+_elapsed*5
						ellipse.append(Vector2(origin+cos(a)*5,sin(a)*width*1.5))
					draw_polyline(ellipse,Color(CYAN,end_fade*.6),1.5,false)
	var impact_age: float = _elapsed-travel_time
	Shapes.burst(self,Vector2(spell_range-5,0),impact_age,.24,22 if power > 1 else 14,
		43*power,BLUE,WHITE,.2)
	if impact_age >= 0 and impact_age < .24:
		var p: float = impact_age/.24
		Shapes.ring(self,Vector2(spell_range,0),4+p*28*power,Color(CYAN,(1-p)*.65),1.5)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
