extends TestCase


func test_base_flat_pct() -> void:
	var sheet := StatSheet.new()
	sheet.set_base(&"x", 10.0)
	sheet.add_modifier(&"x", 5.0, 0.0)
	sheet.add_modifier(&"x", 0.0, 0.5)
	check_near(sheet.get_value(&"x"), 22.5, 0.001, "(10+5)*1.5")


func test_pct_floor() -> void:
	var sheet := StatSheet.new()
	sheet.set_base(&"cd", 3.0)
	sheet.add_modifier(&"cd", 0.0, -2.0)
	check_near(sheet.get_value(&"cd"), 0.3, 0.001, "les pourcentages sont bornés à -90 %")


func test_remove_modifier() -> void:
	var sheet := StatSheet.new()
	sheet.set_base(&"x", 1.0)
	sheet.add_modifier(&"x", 2.0, 0.25)
	sheet.remove_modifier(&"x", 2.0, 0.25)
	check_near(sheet.get_value(&"x"), 1.0)


func test_spatial_grid_query() -> void:
	var grid := SpatialGrid.new(64.0)
	var a := Node2D.new()
	var b := Node2D.new()
	grid.insert(a, Vector2(10, 10))
	grid.insert(b, Vector2(1000, 1000))
	var out: Array = []
	grid.query(Vector2(0, 0), 50.0, out)
	check(out.has(a) and not out.has(b), "seul l'élément proche est retourné")
	grid.clear()
	out.clear()
	grid.query(Vector2(0, 0), 50.0, out)
	check(out.is_empty(), "grille vidée")
	a.free()
	b.free()


func test_xp_curve_increases() -> void:
	var balance: BalanceConfig = GameDB.balance
	var previous: int = 0
	for level: int in range(1, 40):
		var needed: int = balance.xp_to_next(level)
		check(needed > previous, "XP requise croissante au niveau %d" % level)
		previous = needed
