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

var root: RunController
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
var spells: HunterSpells
var fx: FxRenderer
## Obstacles infranchissables du décor (rochers, arbres, eau).
var obstacles := ObstacleField.new()
## Carte de flux vers le Chasseur (null sans décor infranchissable) : les ennemis contournent par les routes.
var flow: FlowField
var boss: Enemy
var spawner: SpawnDirector
var finale: ArenaFinale
## Mode « vagues par zone » (null sinon).
var zones: ZoneDirector
## Mode « fermeture de failles » (null sinon).
var rifts: RiftDirector
## Mode « défense d'autel » (null sinon).
var altar: AltarDirector
## Terrain lent (B1) et courants (B6) ; null si la carte n'en a pas.
var terrain: TerrainDirector
## Crues, brique B3 (null sans lit de crue).
var flood: FloodDirector
var burn: BurnDirector
## Nuit et lucioles, brique B2 (null de jour).
var night: NightDirector


## Campagne : choix aux jalons, sans XP (ArenaData.progression).
func milestones() -> bool:
	return arena.progression == &"milestones"


## Vague en cours d'une carte à vagues infinies (1, 2, 3…).
func endless_wave() -> int:
	return int(time / maxf(arena.endless_wave_duration, 1.0)) + 1


func minutes() -> float:
	return time / 60.0


func has_monster(id: StringName) -> bool:
	return allies != null and allies.get_ally(id) != null


func arena_rect() -> Rect2:
	return Rect2(-arena.size * 0.5, arena.size)


## Flèche de route du mode en cours (zones, failles, autel) ; zéro si rien à rejoindre.
func objective_direction(pos: Vector2) -> Vector2:
	if zones:
		return zones.objective_direction(pos)
	if rifts:
		return rifts.objective_direction(pos)
	if altar:
		return altar.objective_direction(pos)
	return Vector2.ZERO


## Ralentissement du terrain à cette position (1 si la carte n'a pas de terrain lent).
func terrain_speed(pos: Vector2) -> float:
	return terrain.speed_mult(pos) if terrain else 1.0


## Dérive des courants et des crues à cette position (px/s ; zéro ailleurs).
func terrain_drift(pos: Vector2) -> Vector2:
	var result := Vector2.ZERO
	if terrain:
		result += terrain.drift(pos)
	if flood:
		result += flood.drift(pos)
	return result


## Dangers à fuir (bot de test) : zones télégraphiées et lit en crue.
func danger_vector(pos: Vector2) -> Vector2:
	var result: Vector2 = hazards.danger_vector(pos)
	if flood:
		result += flood.danger(pos)
	if burn:
		result += burn.danger(pos)
	return result
