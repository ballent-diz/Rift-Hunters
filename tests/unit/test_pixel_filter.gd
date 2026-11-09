extends TestCase

func make_ground(arena_id: StringName) -> ArenaGround:
	var ground := ArenaGround.new()
	ground.setup(GameDB.arena(arena_id), 7)
	host.add_child(ground)
	return ground


func test_filter_applies_and_restores_on_drawn_map() -> void:
	var saved_filter: String = Settings.pixel_filter
	Settings.pixel_filter = PixelFilter.OFF
	var ground: ArenaGround = make_ground(&"rift_eye")
	check(PixelFilter.supports(ground), "carte dessinée : filtre applicable")
	var base: Material = ground.material
	var base_filter: CanvasItem.TextureFilter = ground.texture_filter
	ground.set_pixel_filter(PixelFilter.GRAPHIC)
	check_eq(ground.pixel_filter, PixelFilter.GRAPHIC, "préréglage graphique actif")
	var mat := ground.material as ShaderMaterial
	check(mat != null and mat.shader == PixelFilter.SHADER, "matériau du filtre posé")
	check_eq(mat.get_shader_parameter("grid_origin"), ground.arena_rect().position, "grille ancrée au coin de l'arène")
	var tiles: int = maxi(1, ground.environment.map_tiles.size())
	var density: float = ground.environment.map_texture.get_width() / (ground.arena_rect().size.x / tiles)
	check_near(float(mat.get_shader_parameter("texture_density")), density, 0.0001, "densité depuis la taille du monde")
	check_eq(ground.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "filtrage au plus proche")
	ground.set_pixel_filter(PixelFilter.OFF)
	check(ground.material == base, "matériau d'origine restauré")
	check_eq(ground.texture_filter, base_filter, "filtrage d'origine restauré")
	# Changement de réglage en cours de partie : le sol suit.
	Settings.pixel_filter = PixelFilter.FINE
	Settings.changed.emit()
	check_eq(ground.pixel_filter, PixelFilter.FINE, "réglage suivi en cours de partie")
	host.remove_child(ground)
	check(ground.material == base, "restauré à la sortie de l'arbre")
	ground.free()
	Settings.pixel_filter = saved_filter


func test_procedural_ground_is_untouched() -> void:
	var arena := ArenaData.new()
	arena.size = Vector2(800, 600)
	var ground := ArenaGround.new()
	ground.setup(arena, 1)
	ground.set_pixel_filter(PixelFilter.GRAPHIC)
	check(not PixelFilter.supports(ground), "sol sans carte dessinée : non filtrable")
	check_eq(ground.pixel_filter, PixelFilter.OFF, "aucun filtre posé")
	check(ground.material == null, "matériau inchangé")
	ground.free()


func test_setting_saved_and_cycled() -> void:
	var path: String = "user://test_pixel_filter_%d.json" % Time.get_ticks_usec()
	var original_path: String = Settings.path
	var saved_filter: String = Settings.pixel_filter
	Settings.path = path
	check_eq(PixelFilter.next_choice(PixelFilter.OFF), PixelFilter.FINE, "désactivé → fin")
	check_eq(PixelFilter.next_choice(PixelFilter.FINE), PixelFilter.GRAPHIC, "fin → graphique")
	check_eq(PixelFilter.next_choice(PixelFilter.GRAPHIC), PixelFilter.OFF, "graphique → désactivé")
	Settings.set_pixel_filter(PixelFilter.FINE)
	Settings.pixel_filter = PixelFilter.OFF
	Settings.load_settings()
	check_eq(Settings.pixel_filter, PixelFilter.FINE, "réglage relu")
	Settings.set_pixel_filter("inconnu")
	check_eq(Settings.pixel_filter, PixelFilter.GRAPHIC, "valeur inconnue : défaut graphique")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.path = original_path
	Settings.pixel_filter = saved_filter
