extends TestCase
## Carte 21, Faubourgs brisés (docs/maps/FAUBOURGS_BRISES.md) : vagues par zone du sud-ouest au nord-est, sol corrompu
## (brique B9, CorruptionDirector) et Commandant déchu sur la place du Beffroi.

var run: RunController


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null


func _start() -> RunContext:
	var setup := RunSetup.new()
	setup.arena_id = &"shattered_outskirts"
	setup.starter_id = &"ashblade"
	setup.run_seed = 6
	setup.autopilot = true
	run = load(Router.RUN).instantiate()
	run.skip_profile = true
	run.start(setup)
	host.add_child(run)
	run.set_physics_process(false)
	return run.ctx


func test_arena_and_campaign() -> void:
	var arena: ArenaData = GameDB.arena(&"shattered_outskirts")
	check(arena.zones.size() == 2 and arena.has_finale(), "deux zones puis la place du Beffroi")
	check_eq(arena.corrupted_patches.size(), 6, "six nappes corrompues")
	check_eq(GameDB.boss(arena.boss_id).signature, &"war_cry", "gardien : Cri de guerre")
	var city: ChapterData = GameDB.chapters.get(&"rift_city")
	check(city != null and city.order == 5, "chapitre 5 dans la campagne")
	check_eq(city.maps[0].arena_id, &"shattered_outskirts", "première carte du chapitre 5")


func test_points_stand_on_open_ground_and_zones_are_sealed() -> void:
	var ctx: RunContext = _start()
	var arena: ArenaData = ctx.arena
	check(not ctx.obstacles.blocks(ctx.player.global_position, 20.0), "départ dégagé")
	check(not ctx.corruption.inside(ctx.player.global_position), "départ hors des nappes")
	for zone: LevelZoneData in arena.zones:
		check(not ctx.obstacles.blocks(zone.anchor, 40.0, false), "centre de zone praticable : %s" % zone.anchor)
	check(not ctx.obstacles.blocks(arena.finale_center, 200.0, false), "place du Beffroi dégagée")
	var field := FlowField.new()
	field.setup(ctx.obstacles, ctx.arena_rect(), FlowField.CELL)
	field.apply_walls(ctx.obstacles)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) >= FlowField.UNREACHED, "barrières étanches")
	for i: int in ctx.obstacles.walls.size():
		ctx.obstacles.set_wall_enabled(i, false)
	field.apply_walls(ctx.obstacles)
	field.update(arena.finale_center)
	check(field.cost_at(ctx.player.global_position) < FlowField.UNREACHED, "le départ mène à la place")
	for zone: LevelZoneData in arena.zones:
		check(field.cost_at(zone.anchor) < FlowField.UNREACHED, "zone %s sur le parcours" % zone.anchor)


## Sol corrompu : la charge du Chasseur monte sur une nappe (plus de dégâts), retombe dehors ; les Corrompus y sont
## renforcés tant qu'ils y restent.
func test_corrupted_ground_empowers_who_stays() -> void:
	var ctx: RunContext = _start()
	var corruption: CorruptionDirector = ctx.corruption
	var patch: PackedVector2Array = ctx.arena.corrupted_patches[0]
	var center := Vector2.ZERO
	for p: Vector2 in patch:
		center += p
	center /= patch.size()
	check(corruption.inside(center), "centre de nappe")
	var start: Vector2 = ctx.player.global_position
	ctx.player.global_position = center
	for i: int in 40:
		corruption.step(0.1)
	check(corruption.charge > 0.99, "charge pleine")
	var enemy: Enemy = ctx.enemies.spawn(GameDB.enemy(&"fallen_militia"), center + Vector2(20, 0))
	var damage: float = enemy.contact_damage
	corruption.step(0.3)
	check(enemy.contact_damage > damage * 1.2, "le Déchu se renforce")
	enemy.position = start
	ctx.player.global_position = start
	for i: int in 30:
		corruption.step(0.1)
	check_near(enemy.contact_damage, damage, 0.01, "renfort perdu hors de la nappe")
	check(corruption.charge < 0.01, "charge retombée")
	check(ctx.stats.counters.get(&"corruption_time", 0.0) >= 3.9, "compté pour l'objectif")
