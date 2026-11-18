extends TestCase
## Raccord des effets dédiés des mutations des six sorts v2 (docs/design/FICHES_VFX_MUTATIONS_V2.md) : sans planche,
## le jeu garde l'effet générique ; avec planche, l'effet dédié est joué sous les zones annoncées des ennemis.

const EFFECTS: Array[StringName] = [&"mutation_mark_execute", &"mutation_mark_hunt", &"mutation_rend_pierce",
	&"mutation_step_trap", &"mutation_stasis_shards", &"mutation_rain_storm", &"mutation_rain_focus",
	&"mutation_veil_recoil"]
## Planche existante prêtée aux effets dédiés le temps d'un test (texture reconnaissable).
const STAND_IN := &"hex_sigil"

var run: DraftRun
var _profile: ProfileData
var _lent: Array[String] = []


func before_each() -> void:
	_profile = Profile.profile
	Profile.profile = ProfileData.new()


func after_each() -> void:
	Profile.profile = _profile
	for key: String in _lent:
		DraftPixelFx._sheets.erase(key)
	_lent.clear()
	if run != null:
		host.get_tree().paused = false
		run.queue_free()
		run = null


func _start(spell: StringName, mutation: String) -> void:
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
	run.spells.learn(spell)
	var effect: DraftSpellEffect = (load(mutation) as UpgradeData).effects[0] as DraftSpellEffect
	check(run.spells.add_mutation(effect), "mutation %s" % mutation.get_file())


## Fait comme si la planche de l'effet dédié était livrée.
func _deliver(effect: StringName) -> void:
	var key: String = "%s/%s" % [effect, DraftPixelFx.DEFAULT_FAMILY]
	DraftPixelFx._sheets[key] = DraftPixelFx.sheet(STAND_IN, &"fallen")
	_lent.append(key)


func _foe(offset: Vector3) -> DraftEnemies.Foe:
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + offset)
	foe.speed = 0.0
	foe.defense = 0.0
	foe.max_hp = 100000.0
	foe.hp = foe.max_hp
	return foe


func _cast(id: StringName, aim: Vector3) -> bool:
	var slot: int = run.spells.slot_of(id)
	run.spells.cooldowns[slot] = 0.0
	return run.spells.cast(slot, aim)


## Effets dédiés en jeu : texture prêtée et priorité sous les télégraphes.
func _dedicated() -> Array[DraftPixelFx]:
	var found: Array[DraftPixelFx] = []
	var texture: Texture2D = DraftPixelFx.sheet(STAND_IN, &"fallen").get("texture")
	for child: Node in run.get_children():
		if child is DraftPixelFx and (child as DraftPixelFx).texture == texture \
				and (child as DraftPixelFx).render_priority == DraftPixelFx.UNDER_TELEGRAPHS:
			found.append(child)
	return found


func test_dedicated_plays_only_delivered_sheets() -> void:
	var parent := Node3D.new()
	host.add_child(parent)
	for effect: StringName in EFFECTS:
		var node: DraftPixelFx = DraftPixelFx.dedicated(parent, effect, 2.0, Vector3.ZERO)
		check_eq(node != null, DraftPixelFx.has_sheet(effect), "%s : joué seulement si livré" % effect)
	_deliver(&"mutation_rend_pierce")
	var played: DraftPixelFx = DraftPixelFx.dedicated(parent, &"mutation_rend_pierce", 2.0, Vector3.ZERO)
	check(played != null, "planche livrée : effet joué")
	if played != null:
		check_eq(played.render_priority, DraftPixelFx.UNDER_TELEGRAPHS, "sous les zones annoncées")
		check(absf(played.region_rect.size.x * played.pixel_size - 2.0) < 0.01, "largeur en jeu respectée")
	parent.queue_free()


func test_piercing_rend_uses_dedicated_impact_on_each_foe() -> void:
	await _start(&"void_rend", "res://draft3d/spells/rend_pierce.tres")
	_deliver(&"mutation_rend_pierce")
	_foe(Vector3(2.0, 0, 0))
	_foe(Vector3(3.5, 0, 0))
	for frame: int in 2:
		await host.get_tree().physics_frame
	check(_cast(&"void_rend", run.hunter.global_position + Vector3(5.0, 0, 0)), "fente lancée")
	check_eq(_dedicated().size(), 2, "un impact perçant par ennemi traversé")


func test_storm_cloud_follows_the_hunter_and_ends_with_the_zone() -> void:
	await _start(&"shard_rain", "res://draft3d/spells/rain_storm.tres")
	_deliver(&"mutation_rain_storm")
	check(_cast(&"shard_rain", run.hunter.global_position + Vector3(3.0, 0, 0)), "pluie lancée")
	var clouds: Array[DraftPixelFx] = _dedicated()
	check_eq(clouds.size(), 1, "orage affiché")
	run.hunter.global_position += Vector3(2.0, 0, 1.0)
	for frame: int in 3:
		await host.get_tree().physics_frame
	if clouds.size() == 1:
		var flat := Vector2(clouds[0].position.x, clouds[0].position.z)
		var hunter := Vector2(run.hunter.global_position.x, run.hunter.global_position.z)
		check(flat.distance_to(hunter) < 0.3, "l'orage suit le Chasseur")
	for frame: int in 240:
		await host.get_tree().physics_frame
	check_eq(_dedicated().size(), 0, "l'orage disparaît avec sa zone")


func test_without_sheet_the_generic_effect_stays() -> void:
	await _start(&"void_rend", "res://draft3d/spells/rend_pierce.tres")
	_foe(Vector3(2.0, 0, 0))
	for frame: int in 2:
		await host.get_tree().physics_frame
	var hit: Texture2D = DraftPixelFx.sheet(&"hit", DraftPixelFx.DEFAULT_FAMILY).get("texture")
	check(_cast(&"void_rend", run.hunter.global_position + Vector3(5.0, 0, 0)), "fente lancée")
	var count: int = 0
	for child: Node in run.get_children():
		if child is DraftPixelFx and (child as DraftPixelFx).texture == hit:
			count += 1
	check(DraftPixelFx.has_sheet(&"mutation_rend_pierce") or count >= 1, "impact générique conservé")
