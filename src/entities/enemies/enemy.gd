class_name Enemy
extends Combatant
## Corrompu, élite ou boss. Mis à jour par EnemyManager (aucun _process propre).

enum State { MOVE, WINDUP, CHARGE, RECOVER }

var data: EnemyData
var boss_data: BossData
var is_elite: bool = false
var is_boss: bool = false
## Élite en version boss (gardien de palier de la grande arène) : barre de boss, ne finit pas la carte.
var mini_boss: bool = false
## Obstacle immobile (posé au départ via ArenaData.start_obstacles) : bloque le passage.
var is_obstacle: bool = false
var affixes: Array[EliteAffixData] = []
var move_speed: float = 60.0
var contact_damage: float = 5.0
var xp_value: int = 1
var velocity := Vector2.ZERO
var push_velocity := Vector2.ZERO
var state: State = State.MOVE
var state_timer: float = 0.0
var attack_timer: float = 0.0
var aim_dir := Vector2.RIGHT
var touch_cooldown: float = 0.0
var taunt_target: Node2D
## Navigation vers la cible de provocation quand elle est fixe (pillards de l'autel) ; null : ligne droite.
var goal_flow: FlowField
var taunt_time: float = 0.0
var invulnerable_time: float = 0.0
var spawn_time: float = 0.0
## Rayon d'absorption des projectiles alliés (boss), 0 = inactif.
var absorb_radius: float = 0.0
var absorbed_count: int = 0
## Techniques (EnemyTechniqueData) : prochaine disponibilité par technique, immobilisation pendant l'exécution, rage.
var technique_ready: Dictionary = {}
var technique_busy: float = 0.0
var raged: bool = false
## Structure en sommeil (bulbe vide qui repousse) : ni ciblée ni touchée.
var dormant: bool = false
## Déplacement d'une technique (bond, charge) en cours : voir EnemyManager._step_motion.
var motion: Dictionary = {}
## Bouclier d'un allié (E15) : aucun dégât tant que la source tient le bouclier.
var shield_source: Enemy
var shield_until: float = 0.0
## Miroir renvoyeur : renvoie les tirs reçus de face jusqu'à reflect_until.
var reflect_until: float = 0.0
var reflect_dir := Vector2.RIGHT
## Clone (E17) : copie fragile qui disparaît à clone_until.
var is_clone: bool = false
## Né d'un nid (B8) : ne compte pas dans les vagues.
var from_nest: bool = false
var clone_until: float = 0.0
## Coups reçus récemment (téléportation quand on la frappe trop).
var recent_hits: int = 0
var _hit_window: float = -10.0


func note_hit(time: float) -> void:
	if time - _hit_window > 2.0:
		_hit_window = time
		recent_hits = 0
	recent_hits += 1


func is_shielded(time: float) -> bool:
	return shield_until > time and is_instance_valid(shield_source) and shield_source.alive and shield_source != self


func is_invulnerable() -> bool:
	return invulnerable_time > 0.0


func push(impulse: Vector2) -> void:
	push_velocity += impulse


## Cible des attaques automatiques : tout Corrompu sauf les obstacles, à l'exception des structures (failles).
func is_target() -> bool:
	return not dormant and (not is_obstacle or (data != null and data.structure))


func data_knockback_resist() -> float:
	if is_boss or is_obstacle or mini_boss:
		return 1.0
	return data.knockback_resist if data else 0.0


func display_name() -> String:
	if is_boss and boss_data:
		return tr(boss_data.name_key)
	return tr(data.name_key) if data else ""
