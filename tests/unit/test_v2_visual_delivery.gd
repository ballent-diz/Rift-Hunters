extends TestCase
## Couverture des ressources livrées et contrat de présentation, sans modifier les règles des combos.

const SPELLS: Array[StringName] = [&"cleaving_slash", &"prismatic_lance", &"rupture", &"rift_leap", &"parry",
	&"singularity", &"rift_wall", &"aegis", &"refracting_crystal", &"hunter_mark", &"void_rend", &"rift_step",
	&"stasis_wave", &"shard_rain", &"ash_veil"]
const COMBOS := {
	"prismatic_execution": "combo_prismatic_execution", "prismatic_deluge": "combo_prismatic_deluge",
	"gravity_blade": "combo_gravity_blade", "rift_counter": "combo_counter_rift",
	"dimensional_hunt": "combo_dimensional_hunt", "tracker_rupture": "combo_tracker_rupture",
	"spectral_rebound": "combo_spectral_rebound", "shattering_rampart": "combo_shattering_bastion",
	"vengeful_aegis": "combo_avenging_aegis", "still_storm": "combo_still_storm",
	"rift_prison": "combo_rift_prison", "prismatic_convergence": "combo_prismatic_convergence",
}
const REWARDS: Array[StringName] = [&"passive_dash_blade", &"passive_void_wake", &"passive_counter_cut",
	&"passive_anchor", &"rule_extra_slot"]


func test_all_fifteen_supported_spells_have_a_loadable_icon() -> void:
	for id: StringName in SPELLS:
		check(DraftSpells.supported(id), "%s : sort raccordé" % id)
		var data: SpellData = DraftSpells.spell(id)
		check(data != null, "%s : données présentes" % id)
		check(DraftSpellBar.icon_for(data) != null, "%s : image chargeable par la barre et les choix" % id)


func test_twelve_combo_sheets_and_illustrations_are_available() -> void:
	for id: String in COMBOS:
		var effect := StringName(COMBOS[id])
		check(DraftPixelFx.has_sheet(effect), "%s : effet dédié disponible" % id)
		var sheet: Dictionary = DraftPixelFx.sheet(effect, DraftPixelFx.DEFAULT_FAMILY)
		check(not sheet.is_empty(), "%s : métadonnées chargeables" % id)
		if not sheet.is_empty():
			var rects: Array[Rect2] = sheet["rects"]
			check(rects.size() >= 10, "%s : vraie animation" % id)
			var texture: Texture2D = sheet["texture"]
			for rect: Rect2 in rects:
				check(Rect2(Vector2.ZERO, texture.get_size()).encloses(rect), "%s : cellule dans la planche" % id)
		var art: Texture2D = ItemArt.texture("combo", StringName(id))
		check(art != null, "%s : illustration référencée" % id)
		if art != null:
			check_eq(art.get_size(), Vector2(1254, 1254), "%s : format d’illustration" % id)


func test_five_v2_reward_cards_are_illustrated() -> void:
	for id: StringName in REWARDS:
		var image: Texture2D = ItemArt.texture("upgrade", id)
		check(image != null, "%s : illustration présente" % id)
		if image != null:
			check_eq(image.get_size(), Vector2(1254, 1254), "%s : format de la fiche" % id)
	var delivered: int = 0
	for entry: Dictionary in ItemArt.entries().values():
		if entry.get("scope", "") == "draft3d":
			delivered += 1
	check_eq(delivered, COMBOS.size() + REWARDS.size(), "catalogue v2 complet, sans illustration orpheline")


func test_wake_sheet_loops_and_stops_with_its_visual() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/vfx/pixelfx/passive_void_wake/violet.json"))
	check_eq(data["meta"]["pixelfx"]["loop"], true, "sillage en boucle")
	check_eq(data["meta"]["pixelfx"]["fps"], 8, "cadence du sillage")
	var node: DraftPixelFx = DraftPixelFx.play(host, &"passive_void_wake", DraftPixelFx.DEFAULT_FAMILY,
		Vector3.ZERO, 1.0, true)
	check(node != null, "sillage instancié")
	if node != null:
		node._process(1.125)
		check(not node.is_queued_for_deletion(), "une boucle écoulée, effet encore vivant")
		node.free()


func test_wake_visual_is_removed_when_the_trail_point_expires() -> void:
	var run := DraftRun.new()
	run.tuning = DraftTuning.new()
	run.hunter = DraftHunter.new()
	run.enemies = DraftEnemies.new()
	var passives := DraftPassives.new(run)
	var visual: DraftPixelFx = DraftPixelFx.play(host, &"passive_void_wake", DraftPixelFx.DEFAULT_FAMILY,
		Vector3.ZERO, 1.0, true)
	check(visual != null, "sillage chargé pour le point")
	if visual != null:
		passives.trail.append({"at": Vector3.ZERO, "left": 0.1, "loop": true, "visual": visual})
		passives._step_trail(0.2)
		check(passives.trail.is_empty(), "point expiré retiré")
		check(visual.is_queued_for_deletion(), "effet bouclé retiré avec son point")
		await host.get_tree().process_frame
	run.hunter.free()
	run.enemies.free()
	run.free()
