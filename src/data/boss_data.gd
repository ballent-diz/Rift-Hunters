class_name BossData
extends Resource
## Dévoreur (boss de fin de chapitre) ou gardien (boss de carte, plus court : docs/design/CARTES.md).

@export var id: StringName = &""
@export var name_key: String = ""
@export var title_key: String = ""
@export var max_hp: float = 5000.0
@export var damage: float = 20.0
@export var defense: float = 30.0
@export var move_speed: float = 40.0
@export var radius: float = 70.0
@export var phases: Array[BossPhaseData] = []
@export var shard_reward: int = 200
@export var essence_reward: int = 10
@export var visual: VisualData
## Gardien : boss de carte en une phase, souvent sur le sprite d'une élite agrandi (annonce et barre propres).
@export var guardian: bool = false
## Agrandissement du sprite (un gardien réutilise le sprite d'une élite).
@export var visual_scale: float = 1.0
## Effets peints du boss (dossier de scènes <nom>.tscn, ex. assets/vfx/bosses/source_devourer/) ; vide : aucun.
@export var vfx_dir: String = ""
## Gueule (souffles), relative au centre du boss quand il regarde à droite ; retournée vers la gauche.
@export var mouth_offset := Vector2.ZERO
## Réaction « hurt » : part des PV max perdue en une seconde qui la déclenche (0 = jamais).
@export_range(0.0, 1.0) var hurt_ratio: float = 0.0
## Animation et effet d'entrée (rugissement), sans dégâts.
@export var intro_animation: StringName = &""
## Mécanique phare (type d'attaque) : propre à ce boss, aucun autre ne l'utilise (docs/design/MONSTRES.md).
@export var signature: StringName = &""
## Réglages d'une mécanique phare passive, active dès l'arrivée du boss (carapace de la Matrone : shell_mult,
## cracked_mult, crack_time, stun).
@export var signature_params: Dictionary = {}
