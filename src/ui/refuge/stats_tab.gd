extends RefugeTab
## Statistiques de compte et records.

const LIFETIME_KEYS: Array[String] = ["runs", "victories", "kills", "elites_killed", "bosses_killed", "time_survived",
	"techniques_cast", "evolutions", "relics_taken", "synergy_procs", "marks_detonated", "dashes", "damage_taken"]


func title_key() -> String:
	return "TAB_STATS"


func refresh() -> void:
	var box: VBoxContainer = scroll_box(6)
	var p: ProfileData = profile()
	box.add_child(UiKit.label(tr("STATS_RECORDS"), 20, UiKit.ACCENT))
	var records: Dictionary = p.data["records"]
	var best_time: float = float(records["best_time"])
	box.add_child(UiKit.label(tr("STATS_BEST_TIME") % [int(best_time) / 60, int(best_time) % 60], 16))
	box.add_child(UiKit.label(tr("STATS_BEST_LEVEL") % int(records["best_level"]), 16))
	box.add_child(UiKit.label(tr("STATS_BEST_KILLS") % int(records["best_kills"]), 16))
	var maps: Array[CampaignMapData] = Campaign.maps_in_order()
	var cleared: int = 0
	var objectives: int = 0
	for map: CampaignMapData in maps:
		cleared += 1 if Campaign.wins(p, map.arena_id) > 0 else 0
		objectives += Campaign.objectives_of(map, Campaign.NORMAL).size() + Campaign.objectives_of(map, Campaign.NIGHTMARE).size()
	box.add_child(UiKit.label(tr("STATS_CAMPAIGN") % [cleared, maps.size()], 16))
	box.add_child(UiKit.label(tr("STATS_MAP_OBJECTIVES") % [Campaign.objectives_completed(p), objectives], 16))
	box.add_child(UiKit.label(tr("STATS_LIFETIME"), 20, UiKit.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	box.add_child(grid)
	for key: String in LIFETIME_KEYS:
		grid.add_child(UiKit.label(tr("STAT_" + key.to_upper()), 16, UiKit.MUTED))
		var value: float = p.lifetime(key)
		var text: String = "%dh %02dm" % [int(value) / 3600, (int(value) % 3600) / 60] if key == "time_survived" else str(int(value))
		grid.add_child(UiKit.label(text, 16))
	var titles: Array = p.data["unlocks"].get("titles", [])
	if not titles.is_empty():
		box.add_child(UiKit.label(tr("STATS_TITLES"), 20, UiKit.ACCENT))
		for title: String in titles:
			box.add_child(UiKit.label("★ " + tr("UNLOCK_TITLE_" + title.to_upper()), 16, UiKit.GOLD))
