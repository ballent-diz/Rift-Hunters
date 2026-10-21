class_name MonsterData
extends Resource
## Définition d'un Écho (allié). Aucune logique : le comportement est choisi par behavior_id.

enum Role { ASSASSIN, GUARDIAN, SUPPORT, CONTROLLER, BRUISER, MARKSMAN }

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var lore_key: String = ""
@export var role: Role = Role.ASSASSIN
@export var affinities: Array[StringName] = []
@export_range(0, 3) var rarity: int = 0
@export_group("Stats")
## PV et défense de référence, inutilisés : les Échos sont invulnérables (non affichés au bestiaire).
@export var max_hp: float = 100.0
@export var defense: float = 0.0
@export var move_speed: float = 170.0
@export_group("Combat")
@export var behavior_id: StringName = &""
@export var attack: AttackData
@export var passive_name_key: String = ""
@export var passive_desc_key: String = ""
@export var passive_effects: Array[GameplayEffect] = []
@export var technique: TechniqueData
@export var evolutions: Array[EvolutionData] = []
@export_group("Progression")
## Variante de gameplay débloquée par la maîtrise.
@export var variant: EvolutionData
@export var mastery: MasteryData
@export var unlocked_by_default: bool = true
## Découverte (EchoCollection, docs/design/COLLECTION_ECHOS.md) : « start » (dès le départ), « capture » (Écho errant garanti
## sur discovery_arena), « victory » (victoire sur discovery_arena), « stars » (tous les objectifs Normal du chapitre
## discovery_chapter), « shop » (boutique, shop_price éclats, en vente après une victoire sur discovery_arena).
@export var discovery: StringName = &"capture"
@export var discovery_arena: StringName = &""
@export var discovery_chapter: StringName = &""
@export var shop_price: int = 0
@export_group("Visuel")
@export var visual: VisualData


func get_range() -> float:
	return attack.attack_range if attack else 0.0
