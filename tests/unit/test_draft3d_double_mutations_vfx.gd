extends TestCase
## Rendu des doubles mutations des neuf sorts historiques (docs/design/DOUBLES_MUTATIONS_VFX.md) : la variante peinte
## ne dépend pas de l'ordre d'obtention ; l'autre mutation a sa couche ou son effet événementiel ; incompatibilités,
## remplacements et échanges d'arsenal inchangés.

## Sort → [mutation peinte en priorité, autre mutation] (cartes `draft3d/spells/<carte>.tres`).
const PAIRS := {
	&"rupture": ["rupture_blaze", "rupture_reaction"],
	&"rift_leap": ["leap_impact", "leap_return"],
	&"parry": ["parry_mirror", "parry_long_guard"],
	&"singularity": ["singularity_collapse", "singularity_horizon"],
	&"rift_wall": ["wall_burning", "wall_chains"],
	&"aegis": ["aegis_second_wind", "aegis_riposte"],
	&"refracting_crystal": ["crystal_focus", "crystal_double"],
}

var run: DraftRun
var _profile: ProfileData


func before_each() -> void:
	_profile = Profile.profile
	Profile.profile = ProfileData.new()


func after_each() -> void:
	Profile.profile = _profile
	if run != null:
		host.get_tree().paused = false
		run.queue_free()
		run = null


func _start() -> void:
	run = (load("res://draft3d/main.tscn") as PackedScene).instantiate()
	host.add_child(run)
	for frame: int in 600:
		if run.state == DraftRun.State.PLAYING:
			break
		await host.get_tree().physics_frame
	run.boss_time = INF
	run.tuning = run.tuning.duplicate()
	run.tuning.waves.assign([{"at": 0.0, "rate": 0.0, "cap": 0, "mix": {"skitterling": 1.0}}])
	run.tuning.swarm_every = INF
	run._swarm_at = INF
	run.hunter.attack_timer = 100000.0
	run.hunter.god_mode = true


func _frames(count: int) -> void:
	for frame: int in count:
		await host.get_tree().physics_frame


func _effect(card: String) -> DraftSpellEffect:
	return (load("res://draft3d/spells/%s.tres" % card) as UpgradeData).effects[0] as DraftSpellEffect


## Sort appris et équipé en case 3, sans mutation.
func _equip(id: StringName) -> void:
	if not run.spells.owns(id):
		run.spells.learn(id)
	if run.spells.slot_of(id) < 0:
		run.spells.equip(id, 2)
	_reset(id)


func _reset(id: StringName) -> void:
	for table: Dictionary in [run.spells.variants, run.spells.variant_params, run.spells.variant_incompatible]:
		table.erase(id)


## Lance le sort et renvoie la variante transmise à la scène peinte jouée.
func _painted(id: StringName) -> StringName:
	for frame: int in 120:
		if not run.hunter.is_leaping():
			break
		await host.get_tree().physics_frame
	var slot: int = run.spells.slot_of(id)
	run.spells.cooldowns[slot] = 0.0
	var before: int = run.spells.vfx.playing.size()
	check(run.spells.cast(slot, run.hunter.global_position + Vector3(3, 0, 0)), "%s lancé" % id)
	if run.spells.vfx.playing.size() <= before:
		check(false, "%s : animation peinte jouée" % id)
		return &"?"
	return StringName((run.spells.vfx.playing.back()["node"] as Node2D).get("variant"))


func _pixel_effects(effect: StringName, family: StringName) -> int:
	var count: int = 0
	var sheet: Texture2D = DraftPixelFx.sheet(effect, family).get("texture")
	for child: Node in run.get_children():
		if child is DraftPixelFx and (child as DraftPixelFx).texture == sheet and not child.is_queued_for_deletion():
			count += 1
	return count


func test_painted_variant_ignores_acquisition_order() -> void:
	for id: StringName in PAIRS:
		var kind: StringName = (GameDB.spells[id] as SpellData).spell_kind
		var first: StringName = _effect(PAIRS[id][0]).variant
		var second: StringName = _effect(PAIRS[id][1]).variant
		check_eq(DraftSpellVfx.painted_variant(kind, [] as Array[StringName]), &"", "%s : aucune mutation" % id)
		check_eq(DraftSpellVfx.painted_variant(kind, [second] as Array[StringName]), second, "%s : seule" % id)
		check_eq(DraftSpellVfx.painted_variant(kind, [first, second] as Array[StringName]), first, "%s : A puis B" % id)
		check_eq(DraftSpellVfx.painted_variant(kind, [second, first] as Array[StringName]), first, "%s : B puis A" % id)


func test_zero_one_and_two_mutations_in_both_orders() -> void:
	await _start()
	for id: StringName in PAIRS:
		_equip(id)
		var first: DraftSpellEffect = _effect(PAIRS[id][0])
		var second: DraftSpellEffect = _effect(PAIRS[id][1])
		var expected: StringName = DraftSpellVfx.variant_name(first.variant)
		check_eq(await _painted(id), &"base", "%s sans mutation : base" % id)
		check(run.spells.add_mutation(second), "%s : %s prise" % [id, second.variant])
		check_eq(await _painted(id), DraftSpellVfx.variant_name(second.variant), "%s : une mutation" % id)
		check(run.spells.add_mutation(first), "%s : %s prise" % [id, first.variant])
		check_eq(await _painted(id), expected, "%s : deux mutations (B puis A)" % id)
		_reset(id)
		run.spells.add_mutation(first)
		run.spells.add_mutation(second)
		check_eq(await _painted(id), expected, "%s : deux mutations (A puis B)" % id)
		run.spells.stash(run.spells.slot_of(id))
		run.spells.equip(id, 3)
		check_eq(await _painted(id), expected, "%s : rendu conservé après passage en réserve" % id)
		run.spells.stash(3)
		await _frames(150)


func test_incompatible_pairs_stay_refused_and_replacement_repaints() -> void:
	await _start()
	var slash: SpellData = GameDB.spells[&"cleaving_slash"]
	var lance: SpellData = GameDB.spells[&"prismatic_lance"]
	check(run.spells.add_mutation(_effect("slash_whirlwind")), "Tourbillon pris")
	check(not run.spells.add_mutation(_effect("slash_thrust")), "Estoc refusé sans remplacement")
	check_eq(run.spells.variant_of(slash), &"whirlwind", "Tourbillon toujours peint")
	check_eq(await _painted(&"cleaving_slash"), &"whirlwind", "animation du Tourbillon")
	check(run.spells.add_mutation(_effect("slash_thrust"), &"whirlwind"), "Estoc remplace le Tourbillon")
	check_eq(run.spells.mutations(&"cleaving_slash"), [&"thrust"] as Array[StringName], "une seule mutation")
	check_eq(await _painted(&"cleaving_slash"), &"thrust", "animation de l'Estoc")
	check(run.spells.add_mutation(_effect("lance_overcharge")), "Surcharge prise")
	check(not run.spells.add_mutation(_effect("lance_fan")), "Éventail refusé sans remplacement")
	check_eq(run.spells.variant_of(lance), &"overcharge", "Surcharge toujours peinte")
	check(run.spells.add_mutation(_effect("lance_fan"), &"overcharge"), "Éventail remplace la Surcharge")
	check_eq(run.spells.variant_of(lance), &"fan", "Éventail peint")


func test_second_mutation_layers() -> void:
	await _start()
	# Bond : Retour pris en second, l'Impact est peint ; le point de retour reste marqué pendant la fenêtre.
	_equip(&"rift_leap")
	run.spells.add_mutation(_effect("leap_return"))
	run.spells.add_mutation(_effect("leap_impact"))
	check_eq(await _painted(&"rift_leap"), &"impact", "Impact peint")
	await _frames(60)
	check_eq(_pixel_effects(&"portal", &"riftborn"), 1, "Retour : point de départ marqué")
	check(run.spells.leap_back(), "retour pris")
	await _frames(2)
	check_eq(_pixel_effects(&"portal", &"riftborn"), 0, "repère retiré au retour")
	await _frames(40)
	# Égide : Riposte puis Second souffle ; le soin du Second souffle se voit.
	_equip(&"aegis")
	run.spells.add_mutation(_effect("aegis_riposte"))
	run.spells.add_mutation(_effect("aegis_second_wind"))
	var blooms: int = _pixel_effects(&"healing_bloom", &"enlises")
	check_eq(await _painted(&"aegis"), &"sharing", "Second souffle peint")
	check_eq(_pixel_effects(&"healing_bloom", &"enlises"), blooms + 1, "soin du Second souffle visible")
	# Mur : Chaînes puis Rempart ardent ; les flammes sont peintes, l'entrave se voit sur l'ennemi.
	_equip(&"rift_wall")
	run.spells.add_mutation(_effect("wall_chains"))
	run.spells.add_mutation(_effect("wall_burning"))
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + Vector3(3, 0, 0))
	foe.speed = 0.0
	foe.max_hp = 100000.0
	foe.hp = foe.max_hp
	await _frames(2)
	var snares: int = _pixel_effects(&"root_snare", &"enlises")
	check_eq(await _painted(&"rift_wall"), &"burning_wall", "Rempart ardent peint")
	await _frames(40)
	check(_pixel_effects(&"root_snare", &"enlises") > snares, "Chaînes : entrave visible")
