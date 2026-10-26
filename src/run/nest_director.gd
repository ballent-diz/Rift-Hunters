class_name NestDirector
extends Node2D
## Brique B8 « ennemis liés au lieu », habillage nids de cendre (carte 8, docs/design/CARTES.md) : des nids sont posés
## sur la carte (structures immobiles qui bloquent le passage). Tant qu'un nid tient debout et que le Chasseur est assez
## proche, il libère périodiquement des Rampe-cendres (alerte au sol, puis éclosion). Le détruire coupe la source :
## cibles prioritaires. Ses petits ne comptent pas dans les vagues (une vague ne traîne jamais à cause d'un nid).

const NEST_ID := &"ash_nest"
const GLOW := Color(0.9, 0.55, 0.3)

var ctx: RunContext
## {"enemy": Enemy, "timer": float, "brood": Array[Enemy]}
var nests: Array[Dictionary] = []
var hatched: int = 0
var _announced: bool = false


static func uses_nests(arena: ArenaData) -> bool:
	return not arena.nest_points.is_empty()


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	name = "Nests"
	z_index = -2
	var data: EnemyData = GameDB.enemy(NEST_ID)
	for i: int in ctx.arena.nest_points.size():
		var enemy: Enemy = ctx.enemies.spawn(data, ctx.arena.nest_points[i])
		enemy.visual.play(&"idle")
		var brood: Array[Enemy] = []
		# Décalage : les nids ne pondent pas tous au même instant.
		nests.append({"enemy": enemy, "timer": ctx.arena.nest_interval * (0.5 + 0.15 * i), "brood": brood})


## Nids encore debout.
func standing() -> int:
	var count: int = 0
	for nest: Dictionary in nests:
		if (nest["enemy"] as Enemy).alive:
			count += 1
	return count


func step(delta: float) -> void:
	var player: Vector2 = ctx.player.global_position
	for nest: Dictionary in nests:
		var enemy: Enemy = nest["enemy"]
		if not enemy.alive:
			continue
		if enemy.position.distance_to(player) > ctx.arena.nest_wake_range:
			continue
		nest["timer"] = float(nest["timer"]) - delta
		if float(nest["timer"]) > 0.0:
			continue
		nest["timer"] = ctx.arena.nest_interval
		var brood: Array[Enemy] = nest["brood"]
		brood.assign(brood.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and e.alive))
		var room: int = mini(ctx.arena.nest_batch, ctx.arena.nest_max_brood - brood.size())
		if room > 0:
			_lay(nest, room)


func _lay(nest: Dictionary, count: int) -> void:
	var enemy: Enemy = nest["enemy"]
	if not _announced:
		_announced = true
		ctx.events.event_started.emit("NEST_INTRO")
	enemy.visual.play_action(&"spawn")
	var data: EnemyData = GameDB.enemy(ctx.arena.nest_enemy)
	if data == null:
		return
	for i: int in count:
		var pos: Vector2 = ctx.obstacles.push_out(enemy.position + Vector2.RIGHT.rotated(ctx.rng.randf() * TAU)
			* (enemy.radius + 40.0), 16.0)
		ctx.fx.ring(pos, 22.0, Color(GLOW, 0.8), ctx.arena.nest_hatch_time)
		ctx.enemies._later(enemy, ctx.arena.nest_hatch_time, func() -> void:
			var child: Enemy = ctx.enemies.spawn(data, pos)
			child.from_nest = true
			(nest["brood"] as Array[Enemy]).append(child)
			hatched += 1)
