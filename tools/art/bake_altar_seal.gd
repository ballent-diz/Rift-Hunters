extends SceneTree
## Baker autonome : trois peintures fixes + animation Godot des énergies du sceau.
## --input=<dossier> --out=<dossier> --center=128,164 --core=128,82
const CELL := 256
const COLUMNS := 8
const ROWS := 5

class SealCanvas extends Node2D:
	var bases: Array[Texture2D] = []
	var emissive: Array[Texture2D] = []
	var center := Vector2(128, 164)
	var core := Vector2(128, 82)
	var blue := Color("#6fe6ff")
	var white := Color("#e9fcff")
	var violet := Color("#a28cff")
	var red := Color("#ff738d")

	func _draw() -> void:
		for row in range(ROWS):
			for col in range(COLUMNS):
				if row == 3 and col >= 4:
					continue
				draw_set_transform(Vector2(col * CELL, row * CELL))
				_frame(row, col)
		draw_set_transform(Vector2.ZERO)

	func _frame(row: int, frame: int) -> void:
		var t := float(frame) / 8.0
		var pulse := 0.68 + 0.18 * sin(TAU * t)
		var color := violet if row == 1 else blue
		var base_index := 0
		if row == 1:
			base_index = 1
		elif row == 2 or row == 4:
			base_index = 2
		# Ombres et anneau au sol restent sous la peinture de pierre.
		if row != 3:
			var radius := 57.0
			if row == 4:
				radius = 32.0 + t * 76.0
			_ground_runes(t, radius, color, pulse if row != 4 else 1.0 - t)
		draw_texture(bases[base_index], Vector2.ZERO)
		# Masque de gravures peintes : seuls les pigments cyan/violet brillants pulsent.
		if row <= 2:
			var engraving_alpha := 0.08 + 0.42 * (0.5 + 0.5 * sin(TAU * t))
			if row == 2:
				engraving_alpha = 0.12 + 0.015 * sin(TAU * t)
			draw_texture(emissive[base_index], Vector2.ZERO, Color(1, 1, 1, engraving_alpha))
		if row == 3:
			_hit(float(frame) / 4.0)
		elif row == 4:
			_purification(t)
		else:
			_loop(row, t, pulse, color)

	func _ground_runes(t: float, radius: float, color: Color, opacity: float) -> void:
		var cy := center.y
		for k in range(12):
			var a := TAU * float(k) / 12.0 + t * TAU / 12.0
			var points := PackedVector2Array()
			for j in range(7):
				var angle := a + float(j) * 0.025
				points.append(Vector2(center.x + cos(angle) * radius, cy + sin(angle) * radius * 0.32))
			_ink(points, color, opacity * 0.6, 1.25)
		for k in range(7):
			var a := TAU * float(k) / 7.0 - t * TAU / 7.0
			var p := Vector2(center.x + cos(a) * radius, cy + sin(a) * radius * 0.32)
			_rune(p, a, color, opacity * 0.85, 2.8)

	func _loop(row: int, t: float, pulse: float, color: Color) -> void:
		# Filaments fins : ancrés sur le noyau, pas de déplacement de l'objet.
		var strand_count := 6 if row == 1 else 4
		for k in range(strand_count):
			var side := -1.0 if k % 2 == 0 else 1.0
			var h := float(k / 2)
			var start := core + Vector2(side * (9.0 + h * 7.0), 18.0 + h * 11.0)
			var end := center + Vector2(side * (30.0 + h * 9.0), -4.0)
			var points := PackedVector2Array()
			for j in range(21):
				var q := float(j) / 20.0
				var p := start.lerp(end, q)
				p.x += sin(q * PI) * side * (7.0 + 3.0 * sin(TAU * t + q * TAU + h))
				p.y -= sin(q * PI) * (7.0 + h)
				points.append(p)
			_ink(points, color, pulse * (0.42 if row == 2 else 0.62), 1.1)
		for k in range(14):
			var seed := float(k)
			var phase := fposmod(t + seed * 0.6180339, 1.0)
			var side := sin(seed * 2.39996)
			var p := center + Vector2(side * (24.0 + fposmod(seed * 13.0, 29.0)), -14.0 - phase * 75.0)
			p.x += sin(TAU * phase + seed) * 4.0
			var alpha := sin(PI * phase) * (0.55 if row == 2 else 0.82)
			var fleck := PackedVector2Array([p, p + Vector2(0.8, -3.0 - fposmod(seed, 3.0))])
			_ink(fleck, color.lerp(white, 0.5), alpha, 1.0)
		for k in range(3):
			var a := float(k) * TAU / 3.0 + t * TAU
			var p := core + Vector2(cos(a) * 13.0, sin(a) * 8.0)
			_rune(p, -a, white if row != 1 else violet, 0.45 + pulse * 0.25, 2.1)
		# Fissures violettes localisées ; jamais de teinte sur toute la pierre.
		if row == 1:
			for k in range(5):
				var start := core + Vector2(float(k - 2) * 9.0, 17.0)
				var points := PackedVector2Array([start, start + Vector2(3, 7), start + Vector2(-2, 13),
					start + Vector2(1, 21)])
				_ink(points, violet, pulse * 0.75, 1.0)

	func _hit(t: float) -> void:
		var power := 1.0 - t
		for k in range(9):
			var a := float(k) * TAU / 9.0 + 0.23
			var origin := core + Vector2(cos(a), sin(a)) * (7.0 + t * 15.0)
			var tip := core + Vector2(cos(a), sin(a)) * (15.0 + t * 39.0)
			var bend := origin.lerp(tip, 0.52) + Vector2(sin(a), -cos(a)) * 3.0
			_ink(PackedVector2Array([origin, bend, tip]), red.lerp(violet, float(k % 3) / 2.0), power, 1.5)
		_rune(core, t * 0.3, white, power * 0.75, 5.0)

	func _purification(t: float) -> void:
		var alpha := sin(PI * minf(1.0, t * 1.3))
		# Onde de purification sur le plateau : rayonnement depuis le cristal peint.
		var wave_radius := 13.0 + t * 98.0
		for k in range(14):
			var start_angle := float(k) * TAU / 14.0 + t * 0.12
			var wave_points := PackedVector2Array()
			for j in range(6):
				var angle := start_angle + float(j) * 0.042
				wave_points.append(core + Vector2(cos(angle) * wave_radius, sin(angle) * wave_radius * 0.47))
			_ink(wave_points, white.lerp(blue, 0.25), alpha * 0.86, 1.4)
		for k in range(4):
			var direction := Vector2.RIGHT.rotated(float(k) * PI / 2.0)
			_ink(PackedVector2Array([core + direction * 5.0, core + direction * (10.0 + t * 15.0)]),
				white, alpha * 0.6, 1.0)
		for k in range(18):
			var seed := float(k)
			var a := seed * TAU / 18.0
			var radius := 17.0 + t * (65.0 + fposmod(seed * 11.0, 27.0))
			var p := Vector2(center.x + cos(a) * radius, center.y + sin(a) * radius * 0.42 - sin(PI * t) * 21.0)
			var v := Vector2(cos(a), sin(a) * 0.42) * 5.0
			_ink(PackedVector2Array([p - v, p, p + Vector2(0, -2)]), blue.lerp(white, 0.6), alpha, 1.2)
		for k in range(5):
			var x := float(k - 2) * 11.0
			var bottom := center + Vector2(x, -5.0)
			var top := bottom + Vector2(sin(t * TAU + float(k)) * 9.0, -t * 104.0)
			_ink(PackedVector2Array([bottom, bottom.lerp(top, 0.5) + Vector2(4, 0), top]), white,
				alpha * 0.62, 1.0)

	func _rune(p: Vector2, a: float, color: Color, opacity: float, size: float) -> void:
		var axis := Vector2(cos(a), sin(a)) * size
		var cross := Vector2(-sin(a), cos(a)) * size * 0.7
		_ink(PackedVector2Array([p - axis, p + cross, p + axis, p - cross, p - axis]), color, opacity, 1.0)
		_ink(PackedVector2Array([p - axis * 0.55, p + axis * 0.55]), color, opacity, 0.8)

	func _ink(points: PackedVector2Array, color: Color, alpha: float, width: float) -> void:
		if alpha <= 0.001:
			return
		var glow := color
		glow.a = alpha * 0.12
		draw_polyline(points, glow, width + 3.0, true)
		var ink := color
		ink.a = alpha
		draw_polyline(points, ink, width, true)


func _initialize() -> void:
	call_deferred("_bake")


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--" + name + "="):
			return arg.get_slice("=", 1)
	return fallback


func _vec_arg(name: String, fallback: Vector2) -> Vector2:
	var parts := _arg(name, "%s,%s" % [fallback.x, fallback.y]).split(",")
	return Vector2(float(parts[0]), float(parts[1]))


func _bake() -> void:
	if "--help" in OS.get_cmdline_user_args():
		print("seal_baker.gd -- --input=<intact.png,damaged.png,sealed.png folder> --out=<folder>")
		quit()
		return
	var input := _arg("input", "")
	var output := _arg("out", input.path_join("baked"))
	var canvas := SealCanvas.new()
	canvas.center = _vec_arg("center", Vector2(128, 164))
	canvas.core = _vec_arg("core", Vector2(128, 82))
	for filename in ["intact.png", "damaged.png", "sealed.png"]:
		var image := Image.load_from_file(input.path_join(filename))
		if image == null or image.get_size() != Vector2i(CELL, CELL):
			push_error("Base absente ou format autre que256x256 : " + filename)
			quit(1)
			return
		canvas.bases.append(ImageTexture.create_from_image(image))
		var mask := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		for y in range(CELL):
			for x in range(CELL):
				var pixel := image.get_pixel(x, y)
				var cyan := pixel.b > 0.60 and pixel.g > 0.44 and pixel.b > pixel.r * 1.06
				var purple := pixel.b > 0.56 and pixel.r > 0.40 and pixel.b > pixel.g * 1.12
				if pixel.a > 0.02 and (cyan or purple):
					var emission := pixel.lerp(Color.WHITE, 0.62)
					emission.a = pixel.a * clampf((pixel.b - 0.40) / 0.35, 0.0, 1.0)
					mask.set_pixel(x, y, emission)
		canvas.emissive.append(ImageTexture.create_from_image(mask))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL * COLUMNS, CELL * ROWS)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var atlas := viewport.get_texture().get_image()
	if atlas == null or atlas.is_empty():
		push_error("Le moteur de rendu n'a pas produit d'image : utiliser une fenêtre hors écran, pas Dummy.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var error := atlas.save_png(output.path_join("sheet.png"))
	if error != OK:
		push_error("Impossible d'écrire sheet.png : " + str(error))
		quit(3)
		return
	var names := ["intact", "damaged", "sealed", "hit", "seal_wave"]
	var counts := [8, 8, 8, 4, 8]
	var fps := [8, 8, 8, 16, 12]
	var animations := {}
	for row in range(ROWS):
		var frames_dir := output.path_join(names[row])
		DirAccess.make_dir_recursive_absolute(frames_dir)
		for frame in range(counts[row]):
			atlas.get_region(Rect2i(frame * CELL, row * CELL, CELL, CELL)).save_png(
				frames_dir.path_join("%02d.png" % frame))
		animations[names[row]] = {"row": row, "frames": counts[row], "fps": fps[row], "loop": row < 3}
	var metadata := {"cell": [CELL, CELL], "grid": [COLUMNS, ROWS], "anchor": [128, 200],
		"animations": animations, "center": [canvas.center.x, canvas.center.y],
		"core": [canvas.core.x, canvas.core.y], "renderer": RenderingServer.get_video_adapter_name()}
	var metadata_file := FileAccess.open(output.path_join("animations.json"), FileAccess.WRITE)
	metadata_file.store_string(JSON.stringify(metadata, "\t") + "\n")
	print("Sceau : atlas2048x1280, animations et métadonnées écrits dans " + output)
	quit()
