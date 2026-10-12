class_name RunContext
extends RefCounted
## Tout l'état d'une partie. Passé aux systèmes : aucun état de partie global.

var setup: RunSetup
var balance: BalanceConfig
var arena: ArenaData
var difficulty: DifficultyData
var rng := RandomNumberGenerator.new()
var time: float = 0.0
var finished: bool = false
var victory: bool = false

var root: Node
var world: Node2D
var events: RunEvents
var stats := RunStats.new()
var build := BuildState.new()

var player: Player
var combat: CombatSystem
var status_system: StatusSystem
var enemies: EnemyManager
var allies: AllyManager
var projectiles: ProjectileManager
var pickups: PickupManager
var hazards: HazardManager
var fx: FxRenderer
var boss: Enemy
var spawner: SpawnDirector


func minutes() -> float:
	return time / 60.0


func has_monster(id: StringName) -> bool:
	return allies != null and allies.get_ally(id) != null


func arena_rect() -> Rect2:
	return Rect2(-arena.size * 0.5, arena.size)
