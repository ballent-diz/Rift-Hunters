extends TestCase
## Profils d'équilibrage par étape (tests/smoke/stage_profile.gd) : un joueur qui arrive sur la carte 1 n'a que les
## sorts de départ ; plus loin, il a les points, les sorts, le sceau d'Écho et la maîtrise de sa progression.


func test_first_map_starts_from_scratch() -> void:
	var profile: ProfileData = StageProfile.build(Campaign.maps_in_order()[0].arena_id, &"ashblade")
	var loadout: Dictionary = HunterTree.loadout(profile)
	check_eq(HunterTree.points_total(profile), HunterTree.BASE_POINTS, "aucun point gagné")
	check_eq(loadout["spells"].filter(func(id: StringName) -> bool: return id != &"").size(), 2, "les 2 sorts de départ")
	check(loadout["variants"].is_empty(), "aucune variante")
	check_eq(profile.preference("team", ""), "ashblade", "Cendrelame seule")


func test_progression_grows_along_the_campaign() -> void:
	var previous: int = -1
	for map: CampaignMapData in Campaign.maps_in_order():
		var profile: ProfileData = StageProfile.build(map.arena_id, &"ashblade")
		print("    %s : %s" % [map.arena_id, StageProfile.describe(profile)])
		var points: int = HunterTree.points_used(profile)
		check(points >= previous, "%s : jamais moins de points actifs qu'avant" % map.arena_id)
		check(HunterTree.points_used(profile) <= HunterTree.points_total(profile), "%s : points respectés" % map.arena_id)
		previous = points
	var late: ProfileData = StageProfile.build(&"crystal_gardens", &"ashblade")
	check(late.tree_rank(&"echoes_third_seal") > 0, "au chapitre 3, le troisième sceau d'Écho est acquis")
	check_eq(late.preference("team", "").split(",").size(), 3, "trois Échos")
	check(HunterTree.loadout(late)["spells"].filter(func(id: StringName) -> bool: return id != &"").size() >= 3,
		"au moins trois sorts équipés")
