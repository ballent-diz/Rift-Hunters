extends TestCase
## Sorts du Chasseur (lot C1) : Taille fendante, Lance prismatique, recharge, visée, touches reconfigurables.

var run: RunController


func before_each() -> void:
	run = RunFixture.create(host)


func after_each() -> void:
	RunFixture.dispose(run)


func _spells() -> HunterSpells:
	return run.ctx.spells


func test_default_spells_are_equipped() -> void:
	check_eq(_spells().slots.size(), HunterSpells.SLOTS, "4 emplacements")
	check_eq(_spells().slots[0].id, &"cleaving_slash", "Taille fendante sur A")
	check_eq(_spells().slots[1].id, &"prismatic_lance", "Lance prismatique sur E")
	check(_spells().slots[2] == null and _spells().slots[3] == null, "R et F libres")


func test_slash_hits_only_the_arc_and_fractures() -> void:
	var front: Enemy = RunFixture.spawn(run, &"skitterling", Vector2(90, 0))
	var behind: Enemy = RunFixture.spawn(run, &"skitterling", Vector2(-90, 0))
	var far: Enemy = RunFixture.spawn(run, &"skitterling", Vector2(400, 0))
	var front_hp: float = front.hp
	var aim: Vector2 = run.ctx.player.global_position + Vector2(200, 0)
	check(_spells().cast(0, aim), "sort lancé")
	run.ctx.combat.flush_queue()
	check(front.hp < front_hp or not front.alive, "l'ennemi devant est touché")
	check_eq(behind.hp, behind.max_hp, "l'ennemi derrière n'est pas touché")
	check_eq(far.hp, far.max_hp, "l'ennemi hors de portée n'est pas touché")
	if front.alive:
		check(front.statuses.get_stacks(&"fracture") > 0, "Fracture appliquée")


func test_cooldown_blocks_recast() -> void:
	var aim: Vector2 = run.ctx.player.global_position + Vector2(100, 0)
	check(_spells().cast(0, aim), "premier lancement")
	check(not _spells().cast(0, aim), "en recharge")
	check(_spells().cooldowns[0] > 3.5, "recharge de ≈ 4 s")
	_spells().step(4.1)
	check(_spells().cast(0, aim), "relancé après la recharge")


func test_lance_pierces_and_marks() -> void:
	var first: Enemy = RunFixture.spawn(run, &"husk", Vector2(120, 0))
	var second: Enemy = RunFixture.spawn(run, &"husk", Vector2(260, 0))
	var aim: Vector2 = run.ctx.player.global_position + Vector2(600, 0)
	check(_spells().cast(1, aim), "Lance lancée")
	for i: int in 30:
		run.ctx.projectiles.step(1.0 / 60.0)
	run.ctx.combat.flush_queue()
	for enemy: Enemy in [first, second]:
		check(enemy.hp < enemy.max_hp or not enemy.alive, "les deux ennemis alignés sont touchés")
		if enemy.alive:
			check(enemy.statuses.get_stacks(&"mark") >= 2, "2 Marques posées")


func test_spell_damage_scales_with_stats() -> void:
	var first: Enemy = RunFixture.spawn(run, &"husk", Vector2(80, 0))
	_spells().cast(0, first.global_position)
	run.ctx.combat.flush_queue()
	var base: float = first.max_hp - first.hp
	first.position = run.ctx.player.global_position + Vector2(-900, 0)
	var second: Enemy = RunFixture.spawn(run, &"husk", Vector2(80, 0))
	run.ctx.player.stats.add_modifier(StatKeys.SPELL_DAMAGE, 0.0, 1.0)
	_spells().cooldowns[0] = 0.0
	_spells().cast(0, second.global_position)
	run.ctx.combat.flush_queue()
	var boosted: float = second.max_hp - second.hp if second.alive else second.max_hp
	check(base > 0.0, "dégâts de base infligés")
	check(boosted >= minf(base * 1.9, second.max_hp), "dégâts des sorts doublés (%.1f → %.1f)" % [base, boosted])


func test_bindings_rebind_and_swap() -> void:
	var saved: Dictionary = Settings.bindings.duplicate(true)
	var path: String = Settings.path
	Settings.path = "user://test_settings_spells.json"
	Settings.bind_key(&"spell_1", KEY_UP)
	check(InputSetup.keys_of(&"spell_1").has(KEY_UP), "Sort 1 sur la flèche du haut")
	check(InputSetup.keys_of(&"spell_2").has(KEY_RIGHT), "Sort 2 récupère l'ancienne touche (échange)")
	Settings.reset_bindings()
	check_eq(InputSetup.keys_of(&"spell_1"), [KEY_RIGHT] as Array[int], "touches par défaut rétablies")
	check(not InputSetup.keys_of(&"move_left").has(KEY_LEFT), "les flèches ne déplacent plus le Chasseur")
	check(InputSetup.keys_of(&"technique_1").has(KEY_Q), "Écho 1 : touche physique Q (A en AZERTY)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = path
	Settings.bindings = saved
	Settings.apply()


func test_keyboard_aim_follows_facing() -> void:
	var player: Player = run.ctx.player
	player.facing = Vector2.LEFT
	var origin: Vector2 = player.global_position
	var aim: Vector2 = HumanBrain.facing_aim(run.ctx, origin)
	check(aim.x < origin.x - 100.0 and absf(aim.y - origin.y) < 1.0, "sans ennemi : droit devant le Chasseur")
	var behind: Enemy = RunFixture.spawn(run, &"husk", Vector2(150, 0))
	var ahead: Enemy = RunFixture.spawn(run, &"husk", Vector2(-200, 40))
	aim = HumanBrain.facing_aim(run.ctx, origin)
	check(aim.distance_to(ahead.global_position) < 1.0, "vise l'ennemi devant, pas celui derrière")
	check(behind.alive, "ennemi derrière ignoré")


func _set_variant(slot: int, variant: StringName) -> void:
	_spells().variants[slot] = variant


func test_whirlwind_hits_all_around() -> void:
	_set_variant(0, &"whirlwind")
	var behind: Enemy = RunFixture.spawn(run, &"husk", Vector2(-90, 0))
	_spells().cast(0, run.ctx.player.global_position + Vector2(200, 0))
	run.ctx.combat.flush_queue()
	check(behind.hp < behind.max_hp or not behind.alive, "Tourbillon : l'ennemi derrière est touché")


func test_thrust_reaches_far_in_a_line() -> void:
	_set_variant(0, &"thrust")
	var far: Enemy = RunFixture.spawn(run, &"husk", Vector2(290, 0))
	var side: Enemy = RunFixture.spawn(run, &"husk", Vector2(100, 90))
	_spells().cast(0, run.ctx.player.global_position + Vector2(200, 0))
	run.ctx.combat.flush_queue()
	check(far.hp < far.max_hp or not far.alive, "Estoc : touche loin dans l'axe")
	check_eq(side.hp, side.max_hp, "Estoc : épargne les côtés")


func test_fan_fires_three_lances() -> void:
	_set_variant(1, &"fan")
	var before: int = run.ctx.projectiles.friendly.size()
	_spells().cast(1, run.ctx.player.global_position + Vector2(300, 0))
	check_eq(run.ctx.projectiles.friendly.size() - before, 3, "Éventail : 3 lances")


func test_overcharge_scales_damage_with_charge() -> void:
	_set_variant(1, &"overcharge")
	_spells().charge_time = 0.0
	check_eq(_spells().charge_power(), 1.0, "sans charge : ×1")
	_spells().charge_time = HunterSpells.OVERCHARGE_TIME * 2.0
	check_eq(_spells().charge_power(), HunterSpells.OVERCHARGE_MAX, "charge pleine : ×2,5")
	_spells().cast(1, run.ctx.player.global_position + Vector2(300, 0), _spells().charge_power())
	var lance: Projectile = run.ctx.projectiles.friendly.back()
	check(lance.info.amount >= 30.0 * 2.4, "dégâts de la lance chargée")
