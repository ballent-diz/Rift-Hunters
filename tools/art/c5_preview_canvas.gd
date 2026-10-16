extends Node2D
## Composition statique : les glyphes sont des repères de maquette, pas les icônes finales.
var mode := "overview"
var effect_time := .35
var gallery_static := true
var data: Dictionary
var labels: Dictionary = {}
var textures: Dictionary = {}
var font: Font = ThemeDB.fallback_font
var paper := Color("f5dfc6")
var muted := Color("a69ba9")
var gold := Color("edc18d")
var cyan := Color("74dce7")
var colors := [Color("edc18d"),Color("74dce7"),Color("b7a7df"),Color("a5d4b5")]
var effects: Array[Node2D] = []

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/hunter_tree/mockup_data.json"))
	var csv := FileAccess.open("res://i18n/strings.csv",FileAccess.READ)
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() >= 3:
			labels[row[0]] = row[1]
	for index: int in 6:
		var scene: String = "cleaving_slash" if index < 3 else "prismatic_lance"
		var fx: Node2D = load("res://assets/vfx/hunter/"+scene+"/"+scene+".tscn").instantiate()
		fx.set("destroy_on_finish",false)
		add_child(fx)
		effects.append(fx)

func text(key: String) -> String:
	return str(labels.get(key,key))

func tex(file: String) -> Texture2D:
	if not textures.has(file):
		textures[file] = load("res://assets/ui/hunter_tree/"+file+".svg")
	return textures[file]

func label_at(value: String, pos: Vector2, size: int = 20, color: Color = paper, width: float = 900) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)

func centered(value: String, pos: Vector2, width: float, size: int = 16, color: Color = paper) -> void:
	draw_string(font,pos,value,HORIZONTAL_ALIGNMENT_CENTER,width,size,color)

func wrapped(value: String, rect: Rect2, size: int = 16, color: Color = paper) -> void:
	for word: String in value.split(" "):
		while font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > rect.size.x and size > 10:
			size -= 1
	var line := ""
	var y: float = rect.position.y+size
	for word: String in value.split(" "):
		if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > rect.size.x and not line.is_empty():
			label_at(line,Vector2(rect.position.x,y),size,color,rect.size.x)
			y += size+5
			line = ""
		line += word+" "
	if y <= rect.end.y:
		label_at(line,Vector2(rect.position.x,y),size,color,rect.size.x)

func panel(rect: Rect2) -> void:
	var style := StyleBoxTexture.new()
	style.texture = tex("panel")
	for side: int in 4:
		style.set_texture_margin(side,18)
	draw_style_box(style,rect)

func glyph(center: Vector2, kind: String, color: Color, scale_factor: float) -> void:
	var s: float = scale_factor
	if kind == "spell":
		draw_line(center+Vector2(-12,13)*s,center+Vector2(12,-13)*s,color,4*s,false)
		draw_line(center+Vector2(-8,-2)*s,center+Vector2(3,8)*s,color,3*s,false)
	elif kind == "keystone":
		var points := PackedVector2Array([Vector2(0,-15),Vector2(10,0),Vector2(0,15),Vector2(-10,0),Vector2(0,-15)])
		for i: int in points.size():
			points[i] = center+points[i]*s
		draw_polyline(points,color,3*s,false)
		draw_rect(Rect2(center-Vector2(2,2)*s,Vector2(4,4)*s),paper)
	elif kind == "transform":
		draw_arc(center,12*s,-PI*.8,PI*.7,8,color,3*s,false)
		draw_line(center+Vector2(8,9)*s,center+Vector2(14,7)*s,color,3*s,false)
	else:
		draw_line(center-Vector2(8,0)*s,center+Vector2(8,0)*s,color,3*s,false)
		draw_line(center-Vector2(0,8)*s,center+Vector2(0,8)*s,color,3*s,false)

func node_at(id: String, center: Vector2, size: float, color: Color, show_label: bool = true, label_width: float = 88) -> void:
	var node: Dictionary = data.nodes[id]
	var state: String = node.state
	draw_texture_rect(tex("node_"+str(node.type)+"_"+state),Rect2(center-Vector2.ONE*size*.5,Vector2.ONE*size),false)
	var ink: Color = color if state != "locked" else Color("635d70")
	glyph(center,str(node.type),ink,size/86.0)
	if show_label:
		wrapped(text(node.label_key),Rect2(center+Vector2(-label_width*.5,size*.5+1),Vector2(label_width,49)),12,ink)

func header(subtitle: String) -> void:
	draw_texture_rect(load("res://assets/ui/menus/refuge-backdrop.png"),Rect2(0,0,1920,1080),false)
	draw_rect(Rect2(0,0,1920,1080),Color(.025,.025,.055,.86))
	label_at(text("C5_REFUGE").to_upper(),Vector2(52,39),15,muted)
	label_at(text("C5_TITLE"),Vector2(52,91),38)
	label_at(subtitle,Vector2(54,122),17,muted)
	draw_line(Vector2(52,145),Vector2(1868,145),Color("6e4b5d"),2)
	label_at(text("C5_PROTOTYPE_NOTE"),Vector2(54,1054),15,muted)

func build_bar() -> void:
	for i: int in 3:
		var x: float = 52+i*265
		draw_texture_rect(tex("build_active" if i == 0 else "build_idle"),Rect2(x,165,250,50),false)
		centered(text("C5_BUILD_"+str(i+1)),Vector2(x,197),250,18,paper if i == 0 else muted)
	draw_texture_rect(tex("points"),Rect2(1450,163,418,56),false)
	centered(text("C5_POINTS")+"   20 / 20",Vector2(1515,199),330,19,gold)

func slots(y: float = 942) -> void:
	label_at(text("C5_EQUIPPED"),Vector2(64,y-16),18,muted)
	for i: int in 4:
		var rect := Rect2(58+i*330,y,314,68)
		draw_texture_rect(tex("slot_focus" if i == 0 else "slot_equipped"),rect,false)
		draw_texture_rect(tex("keycap"),Rect2(rect.position+Vector2(12,14),Vector2(40,40)),false)
		centered(["A","E","R","F"][i],rect.position+Vector2(12,42),40,21)
		wrapped(text(data.nodes[data.slots[i]].label_key),Rect2(rect.position+Vector2(114,17),Vector2(192,48)),17)
	wrapped(text("C5_FREE_CHANGE"),Rect2(1430,y+2,416,65),17,muted)

func _draw() -> void:
	if data == null:
		return
	for fx: Node2D in effects:
		fx.visible = mode == "effects"
	if mode == "effects":
		effect_gallery()
		return
	header(text("C5_COMMON")+"  /  "+text("C5_BLADE")+"  /  "+text("C5_PRISM")+"  /  "+text("C5_ABYSS")+"  /  "+text("C5_BOND"))
	build_bar()
	if mode == "overview":
		overview()
	elif mode == "focus":
		focus()
	else:
		states()
	slots()

func overview() -> void:
	panel(Rect2(52,235,1320,666))
	label_at(text("C5_COMMON"),Vector2(76,267),19,gold)
	for i: int in 5:
		var center := Vector2(340+i*218,281)
		node_at(data.trunk[i],center,48,paper,false)
		wrapped(text(data.nodes[data.trunk[i]].label_key),Rect2(center+Vector2(35,-20),Vector2(155,50)),15)
	draw_line(Vector2(84,327),Vector2(1340,327),Color("5c465f"),1)
	for column: int in 4:
		var path: Dictionary = data.paths[column]
		var left: float = 92+column*320
		draw_texture_rect(tex("heading_"+str(path.id)),Rect2(left,342,284,42),false)
		centered(text("C5_"+str(path.id).to_upper()),Vector2(left,369),284,23,colors[column])
		for tier: int in 5:
			var y: float = 423+tier*91
			label_at(["I","II","III","IV","V"][tier],Vector2(left-27,y+7),15,muted)
			if tier > 0:
				draw_line(Vector2(left+142,y-47),Vector2(left+142,y-33),colors[column]*Color(1,1,1,.45),2)
			var row: Array = path.rows[tier]
			for j: int in row.size():
				var x: float = left+284.0/row.size()*(j+.5)
				var id: String = row[j]
				var size: float = 46 if row.size() > 3 else 54
				if data.nodes[id].type == "keystone":
					size = 64
				node_at(id,Vector2(x,y),size,colors[column],true,284.0/row.size()-8)
			if tier >= 2:
				draw_texture_rect(tex("choice_exclusive"),Rect2(left+284.0/row.size()*.5,y-39,284.0/row.size(),13),false)
		if column < 3:
			draw_line(Vector2(left+303,394),Vector2(left+303,876),Color("493c50"),1)
	inspector()

func inspector() -> void:
	panel(Rect2(1400,235,468,666))
	label_at(text("C5_SELECT_NODE"),Vector2(1428,275),17,muted)
	node_at("cleaving_slash",Vector2(1485,346),84,gold,false)
	wrapped(text("C5_CLEAVING_SLASH"),Rect2(1544,307,290,74),27)
	label_at(text("C5_KNOWN_FOREVER"),Vector2(1430,417),18,gold)
	wrapped(text("C5_SLASH_DESC"),Rect2(1430,443,402,90),20)
	label_at(text("C5_ACTIVATE_COST"),Vector2(1430,565),20)
	label_at(text("C5_VARIANTS"),Vector2(1430,612),17,muted)
	for i: int in 2:
		var y: float = 632+i*69
		draw_texture_rect(tex("slot_focus" if i == 0 else "slot_empty"),Rect2(1426,y,410,58),false)
		centered("A" if i == 0 else "B",Vector2(1454,y+36),78,22,gold if i == 0 else muted)
		label_at(text("C5_WHIRLWIND" if i == 0 else "C5_THRUST"),Vector2(1572,y+36),22,gold if i == 0 else muted)
	wrapped(text("C5_ONE_VARIANT"),Rect2(1430,790,402,68),17,muted)

func focus() -> void:
	panel(Rect2(52,235,1180,666))
	label_at(text("C5_FOCUS_TITLE"),Vector2(82,276),25,gold)
	var path: Dictionary = data.paths[0]
	for tier: int in 5:
		var x: float = 170+tier*218
		label_at(["I","II","III","IV","V"][tier],Vector2(x-10,323),22,muted)
		if tier < 4:
			draw_texture_rect(tex("link_vertical_active"),Rect2(x+94,366,12,380),false)
		var row: Array = path.rows[tier]
		for j: int in row.size():
			var y: float = 399+j*112
			node_at(row[j],Vector2(x,y),64,gold,false)
			wrapped(text(data.nodes[row[j]].label_key),Rect2(x-78,y+36,164,62),17)
		if tier >= 2:
			label_at("A",Vector2(x-59,405),18,gold)
			label_at("B",Vector2(x-59,517),18,muted)
	wrapped(text("C5_ONE_VARIANT"),Rect2(84,822,520,56),18,muted)
	wrapped(text("C5_ONE_KEYSTONE"),Rect2(654,822,530,56),18,gold)
	panel(Rect2(1260,235,608,666))
	label_at(text("C5_COMMON"),Vector2(1290,282),25)
	for i: int in 5:
		var y: float = 339+i*90
		node_at(data.trunk[i],Vector2(1325,y),60,paper,false)
		wrapped(text(data.nodes[data.trunk[i]].label_key),Rect2(1375,y-22,440,56),22)
	wrapped(text("C5_TRUNK_NOTE"),Rect2(1290,805,535,72),18,muted)

func states() -> void:
	panel(Rect2(52,235,1816,666))
	label_at(text("C5_STATES_TITLE"),Vector2(84,282),27)
	var names := ["locked","learnable","learned","active"]
	for i: int in 4:
		var x: float = 130+i*445
		draw_texture_rect(tex("node_spell_"+names[i]),Rect2(x,325,112,112),false)
		glyph(Vector2(x+56,381),"spell",muted if i == 0 else cyan,1.1)
		label_at(text("C5_"+names[i].to_upper()),Vector2(x+139,374),24)
		draw_texture_rect(tex("link_vertical_"+names[i]),Rect2(x+46,456,20,120),false)
		draw_texture_rect(tex("node_passive_"+names[i]),Rect2(x+13,592,86,86),false)
	label_at(text("C5_EXCLUSIVE_AB"),Vector2(98,744),24,gold)
	for i: int in 2:
		var x: float = 600+i*198
		node_at("whirlwind" if i == 0 else "thrust",Vector2(x,764),82,gold,false)
		centered("A" if i == 0 else "B",Vector2(x-40,834),80,20)
	draw_texture_rect(tex("choice_exclusive"),Rect2(642,749,115,30),false)
	wrapped(text("C5_ONE_KEYSTONE"),Rect2(1054,721,730,57),22,gold)
	for i: int in 4:
		draw_texture_rect(tex("node_keystone_active" if i == 0 else "node_keystone_learned"),Rect2(1110+i*167,790,74,74),false)

func effect_gallery() -> void:
	header(text("C5_VFX_TITLE"))
	var names := ["C5_CLEAVING_SLASH","C5_WHIRLWIND","C5_THRUST","C5_PRISMATIC_LANCE","C5_FAN","C5_OVERCHARGE"]
	var variants := ["base","whirlwind","thrust","base","fan","overcharge"]
	for i: int in 6:
		var x: float = 52+(i%3)*614
		var y: float = 180+(i/3)*398
		panel(Rect2(x,y,588,374))
		label_at(text(names[i]),Vector2(x+24,y+42),25,gold if i < 3 else cyan)
		label_at(text("C5_RADIUS_150" if i < 2 else ("C5_RANGE_320" if i == 2 else "C5_RANGE_700")),Vector2(x+24,y+75),17,muted)
		var origin := Vector2(x+98,y+216)
		if i < 2:
			origin.x = x+284
		var fx: Node2D = effects[i]
		fx.position = origin
		fx.scale = Vector2.ONE*(.86 if i < 3 else .62)
		fx.call("play",Vector2.RIGHT,StringName(variants[i]))
		var seconds: float = fmod(effect_time,1.1)
		if i < 3:
			seconds = fmod(effect_time,.7)
		if i == 5 and fmod(effect_time,1.8) < .8:
			fx.call("play",Vector2.RIGHT,&"charge")
			fx.call("set_charge_ratio",fmod(effect_time,1.8)/.8)
			seconds = fmod(effect_time,1.8)
		elif i == 5:
			seconds = fmod(effect_time,1.8)-.8
		if gallery_static:
			fx.call("play",Vector2.RIGHT,StringName(variants[i]))
			seconds = .12 if i < 3 else .35
		fx.call("seek_visual",seconds)
		for grid: int in 9:
			draw_line(Vector2(x+22,y+105+grid*27),Vector2(x+566,y+105+grid*27),Color(.17,.18,.24,.48),1)
		var frames: SpriteFrames = Assets.get_sprite_frames(&"player.hunter")
		if frames != null:
			var hunter: Texture2D = frames.get_frame_texture(&"idle",0)
			var factor: float = .65*fx.scale.x
			draw_texture_rect(hunter,Rect2(origin-Vector2(48,74)*factor,Vector2(96,80)*factor),false)
	wrapped(text("C5_VFX_NOTE"),Rect2(70,1000,1760,58),20,muted)
