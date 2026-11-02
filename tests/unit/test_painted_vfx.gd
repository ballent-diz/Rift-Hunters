extends TestCase
## Effets peints du chapitre 3 et de Glauquemire (docs/art/MARAIS_SORTS_GODOT.md) : résolus par le manifeste, posés
## sur les événements réels, plafonnés, et dissipés quand l'état du combat disparaît. Présentation seulement.

var run: RunController
var ctx: RunContext


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> void:
	run = RunFixture.create(host, &"ashblade")
	ctx = run.ctx


func _technique(enemy_id: StringName, kind: StringName) -> EnemyTechniqueData:
	for technique: EnemyTechniqueData in GameDB.enemy(enemy_id).techniques:
		if technique.kind == kind:
			return technique
	return null


func _live(prefix: String) -> int:
	var found: int = 0
	for child: Node in ctx.painted.get_children():
		if not child.is_queued_for_deletion() and String(child.scene_file_path).contains(prefix) \
				and not bool(child.get("_releasing")):
			found += 1
	return found


func test_every_wired_scene_is_in_the_manifest() -> void:
	_start()
	var keys: Array[String] = []
	for owner: String in ["mire_leech.bite", "bloat_toad.projectile", "bloat_toad.mud_landing", "rift_gnat.needle",
			"creeping_root.burrow", "wandering_shard.projectile", "glass_sentinel.slash", "quartz_golem.impact",
			"creeping_mirror.snap", "creeping_mirror.reflection_jump", "spore_mother.spore_mark",
			"spore_mother.mark_explosion", "spore_mother.spore_carpet", "spore_mother.heal_aura",
			"bark_warden.binding_roots", "bark_warden.bark_shield", "bark_warden.armor_break", "marsh_maw.plunge",
			"marsh_maw.belly_charge", "marsh_maw.rage", "mirror_priestess.clones", "mirror_priestess.reflecting_mirror",
			"mirror_priestess.evasive_blink", "crystal_colossus.sweep_beam", "crystal_colossus.shard_fan",
			"crystal_colossus.exposed_core", "reflection_huntress.chain_blink", "reflection_huntress.prism_mark",
			"reflection_huntress.prism_explosion", "reflection_huntress.reveal"]:
		keys.append("vfx.enemy." + owner)
	for anim: String in ["mud_impact", "mud_wall", "root_leash", "leech_feed", "facets", "facet_break", "mirror",
			"prism_beam", "whirlpool", "tide_ring", "swallow", "echo_release", "phase_transition", "heart_pulse"]:
		keys.append("vfx.boss.glauquemire." + anim)
	for key: String in keys:
		check(ctx.painted.scene(key) != null, "%s : scène chargée" % key)
	var data: BossData = GameDB.boss(&"glauquemire")
	check(ResourceLoader.exists(data.vfx_dir.path_join("claws.tscn"))
		and ResourceLoader.exists(data.vfx_dir.path_join("slam.tscn")), "griffes et écrasement du boss")


func test_hostile_shot_carries_its_painted_body() -> void:
	_start()
	var shot: Projectile = ctx.projectiles.spawn_hostile(ctx.player.global_position + Vector2(300, 0), Vector2.UP, 200.0,
		5.0, &"rift_gnat")
	check(is_instance_valid(shot.fx), "l'aiguille du Moucheron est peinte")
	ctx.projectiles.step(0.1)
	check((shot.fx as Node2D).global_position.is_equal_approx(shot.position), "le corps suit le tir réel")
	var plain: Projectile = ctx.projectiles.spawn_hostile(ctx.player.global_position + Vector2(300, 0), Vector2.UP, 200.0,
		5.0, &"boss")
	check(plain.fx == null, "sans scène, le tir garde son dessin")
	var body: Node2D = shot.fx
	ctx.projectiles.clear_hostile()
	check(bool(body.get("_releasing")), "le tir arrêté dissipe son corps")


func test_spore_mark_follows_then_explodes() -> void:
	_start()
	var mother: Enemy = ctx.enemies.spawn(GameDB.enemy(&"spore_mother"), ctx.player.global_position + Vector2(250, 0))
	var technique: EnemyTechniqueData = _technique(&"spore_mother", &"mark")
	check(ctx.enemies._run_technique(mother, technique, ctx.player.global_position), "la Mère-spore marque")
	ctx.time += technique.telegraph + 0.1
	ctx.enemies._step_pending_actions()
	ctx.painted._process(0.05)
	check_eq(_live("spore_mark"), 1, "la marque peinte suit le Chasseur")
	ctx.player.mark_time = 0.0
	ctx.painted._process(0.05)
	check_eq(_live("spore_mark"), 0, "marque terminée : elle se dissipe")
	check_eq(_live("mark_explosion"), 1, "et explose")


func test_bark_shield_breaks_with_its_warden() -> void:
	_start()
	var warden: Enemy = ctx.enemies.spawn(GameDB.enemy(&"bark_warden"), ctx.player.global_position + Vector2(400, 0))
	ctx.enemies.spawn(GameDB.enemy(&"mire_leech"), warden.position + Vector2(60, 0))
	check(ctx.enemies._run_technique(warden, _technique(&"bark_warden", &"ally_shield"), ctx.player.global_position),
		"la Gardienne protège")
	ctx.painted._process(0.05)
	check_eq(_live("bark_shield"), 1, "une bulle par Corrompu protégé")
	warden.alive = false
	ctx.painted._process(0.05)
	check_eq(_live("bark_shield"), 0, "la Gardienne tombe : la bulle cède")
	check_eq(_live("armor_break"), 1, "en éclats")


func test_budget_caps_decorative_effects() -> void:
	_start()
	for i: int in PaintedVfx.MAX_EFFECTS + 10:
		ctx.painted.play("vfx.enemy.quartz_golem.impact", Vector2(i * 10.0, 0.0))
	check_eq(ctx.painted.count(), PaintedVfx.MAX_EFFECTS, "plafond de 24 effets")
	ctx.painted.clear()


func test_glauquemire_loops_follow_the_fight() -> void:
	_start()
	var boss: Enemy = ctx.enemies.spawn_boss(GameDB.boss(&"glauquemire"), ctx.player.global_position + Vector2(400, 0))
	var brain := BossController.new(ctx, boss)
	var marsh: GlauquemireMechanics = brain.marsh()
	brain.phase_index = 1
	marsh.on_phase(1, brain.phase())
	marsh.step(0.05)
	check_eq(_live("glauquemire/facets"), 1, "carapace peinte")
	check_eq(_live("glauquemire/mirror"), 4, "quatre miroirs peints")
	check_eq(_live("phase_transition"), 1, "changement de phase")
	marsh._break_facet(0)
	check_eq(_live("facet_break"), 1, "une face éclate")
	marsh.whirl = {"start": ctx.time, "until": ctx.time + 3.0, "pull": 0.0, "enemy_pull": 0.0}
	marsh.leash = {"anchor": ctx.player.global_position, "length": 130.0, "until": ctx.time + 3.0}
	marsh.step(0.05)
	check_eq(_live("whirlpool"), 1, "tourbillon peint")
	check_eq(_live("root_leash"), 1, "racine-laisse peinte")
	marsh.whirl = {}
	marsh.leash = {}
	marsh.step(0.05)
	check_eq(_live("whirlpool") + _live("root_leash"), 0, "état disparu : boucles dissipées")
	marsh.finish()
	marsh.step(0.05)
	check_eq(_live("glauquemire/mirror") + _live("glauquemire/facets"), 0, "fin du combat : plus rien")
