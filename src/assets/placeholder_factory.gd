class_name PlaceholderFactory
extends RefCounted
## Génère des textures placeholder lisibles à partir d'une VisualData (formes + contour).
## Rendu CPU (fonctionne aussi en headless). Coordonnées normalisées dans [-1, 1], face à droite.

const MAX_TEXTURE_PX := 112
const OUTLINE_COLOR := Color(0.03, 0.03, 0.06, 1.0)


## Retourne [ImageTexture, échelle d'affichage].
static func make(visual: VisualData, primary: Color, secondary: Color) -> Array:
	var display_px: float = visual.size * 1.3 + 4.0
	var tex_px: int = clampi(int(ceil(display_px)), 8, MAX_TEXTURE_PX)
	var scale_factor: float = display_px / float(tex_px)
	var img := Image.create(tex_px, tex_px, false, Image.FORMAT_RGBA8)
	var layers: Array = shape_layers(visual.shape, primary, secondary, visual.accent)
	var half: float = tex_px * 0.5
	var unit: float = (visual.size * 0.5) / scale_factor
	var outline_px: float = maxf(1.2, unit / 14.0)
	for y: int in tex_px:
		for x: int in tex_px:
			var p := Vector2((x + 0.5 - half) / unit, (y + 0.5 - half) / unit)
			var color := Color(0, 0, 0, 0)
			var body: float = INF
			for layer: Dictionary in layers:
				if layer.get("outline", true):
					body = minf(body, sdf(layer["prims"], p))
			var outline_cov: float = clampf(outline_px + 0.5 - body * unit, 0.0, 1.0)
			if outline_cov > 0.0:
				color = _blend(color, Color(OUTLINE_COLOR, outline_cov))
			for layer: Dictionary in layers:
				var d: float = sdf(layer["prims"], p) * unit
				var cov: float = clampf(0.5 - d, 0.0, 1.0)
				if cov <= 0.0:
					continue
				var layer_color: Color = layer["color"]
				if layer.get("shade", true):
					layer_color = layer_color.lightened(clampf(-p.y * 0.12, 0.0, 0.2)).darkened(clampf(p.y * 0.12, 0.0, 0.2))
				color = _blend(color, Color(layer_color, layer_color.a * cov))
			img.set_pixel(x, y, color)
	return [ImageTexture.create_from_image(img), scale_factor]


static func _blend(dst: Color, src: Color) -> Color:
	var a: float = src.a + dst.a * (1.0 - src.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb: Color = (Color(src.r, src.g, src.b) * src.a + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - src.a)) / a
	return Color(rgb.r, rgb.g, rgb.b, a)


static func sdf(prims: Array, p: Vector2) -> float:
	var d: float = INF
	for prim: Dictionary in prims:
		d = minf(d, _prim_sdf(prim, p))
	return d


static func _prim_sdf(prim: Dictionary, p: Vector2) -> float:
	match prim["t"]:
		"c":
			return p.distance_to(prim["c"]) - float(prim["r"])
		"e":
			var q: Vector2 = p - (prim["c"] as Vector2)
			var r := Vector2(prim["rx"], prim["ry"])
			var k0: float = (q / r).length()
			var k1: float = (q / (r * r)).length()
			return k0 * (k0 - 1.0) / maxf(k1, 0.0001)
		"s":
			var a: Vector2 = prim["a"]
			var b: Vector2 = prim["b"]
			var pa: Vector2 = p - a
			var ba: Vector2 = b - a
			var h: float = clampf(pa.dot(ba) / maxf(ba.dot(ba), 0.0001), 0.0, 1.0)
			return (pa - ba * h).length() - float(prim["r"])
		"p":
			return _polygon_sdf(prim["pts"], p)
	return INF


static func _polygon_sdf(v: PackedVector2Array, p: Vector2) -> float:
	var n: int = v.size()
	var d: float = (p - v[0]).dot(p - v[0])
	var s: float = 1.0
	var j: int = n - 1
	for i: int in n:
		var e: Vector2 = v[j] - v[i]
		var w: Vector2 = p - v[i]
		var b: Vector2 = w - e * clampf(w.dot(e) / maxf(e.dot(e), 0.0001), 0.0, 1.0)
		d = minf(d, b.dot(b))
		var c1: bool = p.y >= v[i].y
		var c2: bool = p.y < v[j].y
		var c3: bool = e.x * w.y > e.y * w.x
		if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
			s = -s
		j = i
	return s * sqrt(d)


static func _c(cx: float, cy: float, r: float) -> Dictionary:
	return {"t": "c", "c": Vector2(cx, cy), "r": r}


static func _e(cx: float, cy: float, rx: float, ry: float) -> Dictionary:
	return {"t": "e", "c": Vector2(cx, cy), "rx": rx, "ry": ry}


static func _s(ax: float, ay: float, bx: float, by: float, r: float) -> Dictionary:
	return {"t": "s", "a": Vector2(ax, ay), "b": Vector2(bx, by), "r": r}


static func _p(points: Array) -> Dictionary:
	var pts := PackedVector2Array()
	for i: int in range(0, points.size(), 2):
		pts.append(Vector2(points[i], points[i + 1]))
	return {"t": "p", "pts": pts}


static func _layer(prims: Array, color: Color, outline: bool = true, shade: bool = true) -> Dictionary:
	return {"prims": prims, "color": color, "outline": outline, "shade": shade}


## Couches de dessin par forme (ordre du peintre).
static func shape_layers(shape: VisualData.Shape, pri: Color, sec: Color, acc: Color) -> Array:
	match shape:
		VisualData.Shape.HUNTER:
			return [
				_layer([_e(0, 0.25, 0.55, 0.62)], pri),
				_layer([_s(-0.45, 0.35, 0.45, 0.35, 0.09)], sec),
				_layer([_c(0, -0.42, 0.34)], pri.darkened(0.15)),
				_layer([_s(-0.05, -0.42, 0.22, -0.42, 0.07)], acc, false, false),
				_layer([_c(0.55, 0.2, 0.15)], acc, false, false),
			]
		VisualData.Shape.BLADE_BEAST:
			return [
				_layer([_p([-0.55, 0.05, -1.0, -0.35, -0.5, 0.3])], pri),
				_layer([_e(-0.05, 0.1, 0.62, 0.38)], pri),
				_layer([_p([0.3, 0.2, 1.0, 0.55, 0.45, 0.38]), _p([0.2, -0.15, 0.95, -0.6, 0.38, 0.0])], sec),
				_layer([_c(0.5, -0.05, 0.27)], pri),
				_layer([_s(-0.45, 0.08, 0.2, 0.08, 0.05)], acc, false, false),
				_layer([_c(0.62, -0.1, 0.075)], acc, false, false),
			]
		VisualData.Shape.MONOLITH:
			return [
				_layer([_p([-0.62, -0.78, 0.55, -0.88, 0.72, 0.72, -0.72, 0.82])], pri),
				_layer([_c(-0.3, -0.6, 0.25), _c(0.35, -0.68, 0.22), _c(0.5, 0.42, 0.2), _c(-0.5, 0.3, 0.18)], sec),
				_layer([_s(0.0, -0.05, 0.0, 0.45, 0.06)], acc, false, false),
				_layer([_c(-0.22, -0.25, 0.08), _c(0.22, -0.25, 0.08)], acc, false, false),
			]
		VisualData.Shape.MOTH:
			return [
				_layer([_e(-0.08, -0.55, 0.45, 0.4), _e(-0.08, 0.55, 0.45, 0.4)], sec),
				_layer([_c(-0.08, -0.55, 0.15), _c(-0.08, 0.55, 0.15)], acc, false, false),
				_layer([_s(-0.5, 0, 0.45, 0, 0.18)], pri),
				_layer([_s(0.45, 0, 0.85, -0.32, 0.04), _s(0.45, 0, 0.85, 0.32, 0.04)], pri),
			]
		VisualData.Shape.SKITTER:
			return [
				_layer([_s(0, 0, -0.8, -0.7, 0.07), _s(0, 0, -0.8, 0.7, 0.07), _s(0, 0, 0.1, -0.95, 0.07),
					_s(0, 0, 0.1, 0.95, 0.07), _s(0, 0, 0.75, -0.7, 0.07), _s(0, 0, 0.75, 0.7, 0.07)], sec),
				_layer([_c(0, 0, 0.5)], pri),
				_layer([_c(0.3, -0.16, 0.11), _c(0.3, 0.16, 0.11)], acc, false, false),
			]
		VisualData.Shape.SHELL:
			return [
				_layer([_c(0.72, 0, 0.26)], sec),
				_layer([_c(-0.05, 0, 0.8)], pri),
				_layer([_s(-0.55, -0.3, 0.5, -0.3, 0.05), _s(-0.6, 0.05, 0.55, 0.05, 0.05), _s(-0.5, 0.4, 0.45, 0.4, 0.05)],
					sec, false, false),
				_layer([_c(0.86, 0, 0.08)], acc, false, false),
			]
		VisualData.Shape.SPITTER:
			return [
				_layer([_s(0.2, 0, 0.78, 0, 0.22)], sec),
				_layer([_c(-0.15, 0, 0.6)], pri),
				_layer([_c(-0.35, -0.3, 0.13), _c(-0.4, 0.28, 0.11)], acc.darkened(0.2), false, false),
				_layer([_c(0.78, 0, 0.13)], acc, false, false),
			]
		VisualData.Shape.LUNGER:
			return [
				_layer([_p([1.0, 0.0, -0.45, -0.65, -0.2, 0.0, -0.45, 0.65])], pri),
				_layer([_p([0.1, -0.25, -0.75, -0.95, -0.35, -0.3]), _p([0.1, 0.25, -0.75, 0.95, -0.35, 0.3])], sec),
				_layer([_c(0.42, 0, 0.09)], acc, false, false),
			]
		VisualData.Shape.DEVOURER:
			var shards: Array = []
			var shards_alt: Array = []
			for i: int in 11:
				var a: float = i * TAU / 11.0
				var pts: Array = []
				for polar: Vector2 in [Vector2(a - 0.2, 0.36), Vector2(a + 0.32, 1.0), Vector2(a + 0.22, 0.42)]:
					pts.append(cos(polar.x) * polar.y)
					pts.append(sin(polar.x) * polar.y)
				(shards if i % 2 == 0 else shards_alt).append(_p(pts))
			return [
				_layer(shards, pri),
				_layer(shards_alt, sec),
				_layer([_c(0, 0, 0.46)], pri.darkened(0.3)),
				_layer([_c(0, 0, 0.3)], acc, false, false),
				_layer([_c(0, 0, 0.12)], Color(0.05, 0.02, 0.1), false, false),
			]
		VisualData.Shape.ORB:
			return [
				_layer([_c(0, 0, 1.0)], Color(pri, 0.22), false, false),
				_layer([_c(0, 0, 0.7)], Color(pri, 0.5), false, false),
				_layer([_c(0, 0, 0.45)], pri, false, false),
				_layer([_c(0, 0, 0.2)], acc, false, false),
			]
		VisualData.Shape.CRYSTAL:
			return [
				_layer([_p([0, -1, 0.45, 0, 0, 1, -0.45, 0])], pri),
				_layer([_p([0, -1, 0.45, 0, 0, 0.2])], sec, false),
				_layer([_c(0, -0.1, 0.12)], acc, false, false),
			]
		VisualData.Shape.CHEST:
			return [
				_layer([_p([-0.8, -0.5, 0.8, -0.5, 0.8, 0.6, -0.8, 0.6])], pri),
				_layer([_s(-0.8, -0.1, 0.8, -0.1, 0.08)], sec, false),
				_layer([_c(0, 0.12, 0.15)], acc, false, false),
			]
		VisualData.Shape.GEM:
			return [
				_layer([_p([0, -1, 0.65, 0, 0, 1, -0.65, 0])], pri),
				_layer([_p([0, -1, 0.65, 0, 0, -0.1])], Color(acc, 0.7), false, false),
			]
	return _extra_layers(shape, pri, sec, acc)


static func _extra_layers(shape: VisualData.Shape, pri: Color, sec: Color, acc: Color) -> Array:
	match shape:
		VisualData.Shape.VINE:
			return [
				_layer([_s(-0.8, 0.6, -0.2, -0.1, 0.12), _s(-0.2, -0.1, 0.5, 0.3, 0.12), _s(0.5, 0.3, 0.8, -0.5, 0.1)], sec),
				_layer([_c(0.0, -0.05, 0.42)], pri),
				_layer([_p([-0.75, -0.3, -0.45, -0.7, -0.35, -0.2]), _p([0.45, -0.75, 0.8, -0.45, 0.35, -0.35])], sec),
				_layer([_c(0.18, -0.12, 0.09), _c(0.18, 0.12, 0.09)], acc, false, false),
			]
		VisualData.Shape.WISP:
			return [
				_layer([_p([-1.0, 0.0, -0.3, -0.35, -0.45, 0.0, -0.3, 0.35])], Color(sec, 0.8), false),
				_layer([_c(0.1, 0, 0.5)], pri),
				_layer([_p([0.1, -0.5, 0.35, -0.05, 0.05, 0.1, 0.3, 0.55, -0.05, 0.05, 0.2, -0.1])], acc, false, false),
			]
		VisualData.Shape.MAW:
			return [
				_layer([_c(-0.1, 0, 0.75)], pri),
				_layer([_p([0.05, -0.45, 0.95, 0.0, 0.05, 0.45])], Color(0.05, 0.02, 0.06), false, false),
				_layer([_p([0.2, -0.35, 0.3, -0.12, 0.4, -0.3]), _p([0.2, 0.35, 0.3, 0.12, 0.4, 0.3]),
					_p([0.55, -0.22, 0.62, -0.05, 0.7, -0.17]), _p([0.55, 0.22, 0.62, 0.05, 0.7, 0.17])], acc, false, false),
				_layer([_c(-0.35, -0.35, 0.1)], sec, false, false),
			]
		VisualData.Shape.MIRROR:
			return [
				_layer([_p([0, -0.95, 0.6, -0.3, 0.6, 0.3, 0, 0.95, -0.6, 0.3, -0.6, -0.3])], pri),
				_layer([_p([0, -0.6, 0.35, -0.2, 0.0, 0.1, -0.35, -0.2])], Color(acc, 0.85), false, false),
				_layer([_s(-0.3, 0.35, 0.3, 0.35, 0.05)], sec, false, false),
			]
		VisualData.Shape.BROOD:
			return [
				_layer([_e(-0.1, 0, 0.75, 0.6)], pri),
				_layer([_c(-0.35, -0.25, 0.18), _c(-0.4, 0.25, 0.16), _c(0.0, 0.35, 0.14), _c(0.05, -0.38, 0.15)], sec, false),
				_layer([_c(0.55, 0, 0.22)], pri.darkened(0.2)),
				_layer([_c(0.65, -0.08, 0.06), _c(0.65, 0.08, 0.06)], acc, false, false),
			]
		VisualData.Shape.SHADE:
			return [
				_layer([_p([0.9, 0.0, 0.1, -0.7, -0.9, -0.2, -0.5, 0.0, -0.9, 0.2, 0.1, 0.7])], Color(pri, 0.85)),
				_layer([_c(0.35, -0.12, 0.08), _c(0.35, 0.12, 0.08)], acc, false, false),
			]
		VisualData.Shape.WARDEN:
			return [
				_layer([_c(0, 0, 0.62)], pri),
				_layer([_p([0, -1.0, 0.25, -0.55, -0.25, -0.55]), _p([0, 1.0, 0.25, 0.55, -0.25, 0.55]),
					_p([-1.0, 0, -0.55, -0.25, -0.55, 0.25]), _p([1.0, 0, 0.55, -0.25, 0.55, 0.25])], sec),
				_layer([_c(0, 0, 0.25)], acc, false, false),
			]
		VisualData.Shape.COLOSSUS:
			return [
				_layer([_p([-0.85, -0.6, -0.3, -0.95, 0.4, -0.85, 0.9, -0.3, 0.85, 0.45, 0.3, 0.9, -0.5, 0.85, -0.95, 0.25])], pri),
				_layer([_p([-0.5, -0.45, -0.1, -0.6, 0.0, -0.2, -0.4, -0.1]), _p([0.2, 0.15, 0.6, 0.05, 0.55, 0.5, 0.15, 0.55])],
					sec, false),
				_layer([_s(-0.2, 0.05, 0.35, -0.15, 0.08)], acc, false, false),
				_layer([_c(0.45, -0.4, 0.09), _c(0.6, -0.15, 0.09)], acc, false, false),
			]
	return [
		_layer([_c(0, 0, 0.8)], pri),
		_layer([_c(0.3, -0.15, 0.1), _c(0.3, 0.15, 0.1)], acc, false, false),
	]
