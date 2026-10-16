extends RefCounted
## Vocabulaire visuel partagé : cristaux facettés, filaments et éclats déterministes.

static func facet(canvas: Node2D, center: Vector2, angle: float, length: float,
		width: float, ink: Color, light: Color, opacity: float = 1.0) -> void:
	if length < .1 or width < .1 or opacity < .001:
		return
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	var nose: Vector2 = center+along*length*.55
	var tail: Vector2 = center-along*length*.45
	var left: Vector2 = center+across*width*.5
	var right: Vector2 = center-across*width*.5
	canvas.draw_colored_polygon(PackedVector2Array([tail,left,nose]),Color(ink,opacity))
	canvas.draw_colored_polygon(PackedVector2Array([tail,right,nose]),Color(light,opacity))
	canvas.draw_line(tail,nose,Color("fff8e3")*Color(1,1,1,opacity),1.0,false)

static func burst(canvas: Node2D, origin: Vector2, age: float, lifetime: float,
		count: int, reach: float, ink: Color, light: Color, seed_offset: float = 0.0) -> void:
	if age < 0.0 or age >= lifetime:
		return
	var p: float = age/lifetime
	var fade: float = pow(1.0-p,1.6)
	for i: int in count:
		var random: float = fmod(float(i)*.6180339+seed_offset,.999)
		var angle: float = float(i)*2.39996+seed_offset*TAU
		var direction := Vector2.from_angle(angle)
		var distance: float = reach*(.32+random*.68)*(1.0-pow(1.0-p,2.0))
		var center: Vector2 = origin+direction*distance+Vector2(0,p*p*reach*.18)
		var size: float = (3+random*8)*(1.0-p*.65)
		facet(canvas,center,angle+p*2.0,size,size*.35,ink,light,fade)
		if i%3 == 0:
			canvas.draw_line(center-direction*(5+random*10),center,Color(light,fade*.6),1,false)

static func ring(canvas: Node2D, center: Vector2, radius: float, color: Color,
		width: float, start: float = 0.0, end: float = TAU) -> void:
	if radius <= 0.1 or width <= 0.1:
		return
	canvas.draw_arc(center,radius,start,end,48,color,width,false)

static func star(canvas: Node2D, center: Vector2, radius: float, color: Color, angle: float = 0.0) -> void:
	if radius <= .1:
		return
	var points := PackedVector2Array()
	for i: int in 8:
		var distance: float = radius if i%2 == 0 else radius*.17
		points.append(center+Vector2.from_angle(float(i)*PI*.25+angle)*distance)
	canvas.draw_colored_polygon(points,color)
