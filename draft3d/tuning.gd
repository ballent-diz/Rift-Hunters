class_name DraftTuning
extends Resource
## Réglages propres au premier jet (draft3d/tuning.tres). Les valeurs de base (PV, vitesses, dégâts, EXP par ennemi,
## courbe de niveaux) viennent toujours de l'équilibrage commun ; ce fichier ne porte que les écarts nécessaires au
## Chasseur seul, que la campagne compensait par l'équipe d'Échos.

## Phase de test : tous les chapitres sont ouverts au lancement (le déblocage par les victoires reste enregistré).
@export var all_chapters_open: bool = true
@export_group("Chasseur")
## Bonus de départ : sans Échos, le Trait de Faille doit suffire à tenir les premières vagues.
@export var hunter_damage_pct: float = 0.5
@export var hunter_attack_speed_pct: float = 0.25
## Rythme : vitesse de déplacement du Chasseur (+25 %) et des monstres et boss (×1,15), données v1 inchangées.
@export var hunter_move_speed_pct: float = 0.25
@export var enemy_speed_mult: float = 1.15
## Essai : l'EXP lâchée par un ennemi vole aussitôt vers le Chasseur, quelle que soit la distance.
@export var xp_auto_collect: bool = true
@export_group("Sorts")
## Les rayons de zone de SpellData (unités du monde 2D) sont resserrés pour la vue 3D, plus proche.
@export var spell_area_scale: float = 0.5
## Rupture : sans Marques à faire détoner (statuts non repris), la détonation frappe plus fort.
@export var rupture_damage_mult: float = 2.0
## Bond de Faille : distance maximale (m) et rayon de recherche des ennemis serrés (bot).
@export var leap_max_range: float = 9.0
## Lance : vitesse (m/s) et portée maximale (m).
@export var lance_speed: float = 24.0
@export var lance_max_range: float = 22.0
## Visée au clavier seul : ennemi visible le plus proche dans le cône devant le Chasseur (portée en m), sinon point
## à `aim_distance` devant lui.
@export var aim_range: float = 15.0
@export var aim_distance: float = 6.0
## Recharge d'un sort qui vient d'être appris (s).
@export var learned_cooldown: float = 1.0
## Parade : étourdissement des ennemis touchés par la contre-attaque (s).
@export var parry_stun: float = 1.5
## Singularité : force d'attraction (unités 2D/s de SpellData.params.pull) convertie en m/s avec ce facteur.
@export var singularity_pull_scale: float = 0.5
## Cristal : rayon minimal (m), traits ajoutés par réfraction, écart (°) et part des dégâts de chaque éclat.
@export var crystal_min_radius: float = 0.9
@export var crystal_split: int = 2
@export var crystal_angle: float = 18.0
@export var crystal_damage: float = 0.6
@export_group("Progression")
## XP : multiplicateur des seuils de la courbe commune (cible : 8 à 12 choix pour 20-25 min, à régler en jeu).
@export var xp_scale: float = 24.0
## Croissance automatique à chaque niveau (sans choix du joueur) : dégâts du Chasseur (part) et PV max.
@export var level_damage_pct: float = 0.05
@export var level_max_hp: float = 6.0
## Cartes retirées du tirage normal (décision du 16 novembre) : statistiques brutes et rangs chiffrés.
@export var stat_cards_in_pool: bool = false
@export var rank_cards_in_pool: bool = false
## Poids de tirage par rareté (Commun, Rare, Épique, Légendaire) et anti-frustration : après `pity_after` choix sans
## Épique ni Légendaire, ces raretés pèsent `pity_mult` fois plus.
@export var rarity_weights: Array[float] = [10.0, 6.0, 2.5, 0.6]
@export var pity_after: int = 3
@export var pity_mult: float = 2.5
@export_group("Passifs")
## Ruée tranchante : dégâts (× dégâts du Chasseur) aux ennemis traversés, rayon (m).
@export var dash_blade_damage: float = 18.0
@export var dash_blade_radius: float = 1.0
## Sillage du vide : durée de la traînée (s), rayon (m), ralentissement.
@export var void_wake_duration: float = 2.0
@export var void_wake_radius: float = 0.9
@export var void_wake_slow: float = 0.45
## Contre-taille : fenêtre (s) après une esquive pendant la Ruée, puissance du sort suivant.
@export var counter_cut_window: float = 3.0
@export var counter_cut_power: float = 1.6
## Ancre : petite Singularité quand un ennemi ralenti ou immobilisé meurt (rayon m, durée s, dégâts, délai mini s).
@export var anchor_radius: float = 1.8
@export var anchor_duration: float = 0.9
@export var anchor_damage: float = 16.0
@export var anchor_cooldown: float = 1.2
@export_group("Combos")
## Fenêtre (s) entre la Lance et la Rupture (Exécution prismatique).
@export var combo_window: float = 2.0
## Exécution prismatique : dégâts de la détonation secondaire (× dégâts de la Rupture), seuil d'achèvement (part des
## PV max, hors boss), nombre maximal de cibles par Rupture.
@export var combo_execution_mult: float = 0.8
@export var combo_execution_threshold: float = 0.2
@export var combo_execution_max: int = 6
## Déluge prismatique : éclats par Lance, écart (degrés), dégâts (× la Lance), éclats au plus par Cristal.
@export var combo_deluge_split: int = 4
@export var combo_deluge_angle: float = 12.0
@export var combo_deluge_damage: float = 0.8
@export var combo_deluge_cap: int = 8
## Lame gravitationnelle : dégâts de l'onde (× la Taille), rayon (× le puits), exposition (bonus de dégâts subis, s).
@export var combo_gravity_mult: float = 1.5
@export var combo_gravity_area: float = 1.3
@export var combo_gravity_expose: float = 0.25
@export var combo_gravity_expose_time: float = 3.0
## Annonce (bannière et son) au plus une fois par combo sur cet intervalle (s) ; le combo agit à chaque fois.
@export var combo_banner_gap: float = 1.5
## Chasse dimensionnelle : frappe secondaire sur la cible marquée (× dégâts de la Fente).
@export var combo_hunt_mult: float = 1.0
## Rupture du traqueur : explosion concentrée sur la cible marquée (× dégâts de la Rupture), éclaboussure autour
## (× dégâts de la Rupture) et rayon (m).
@export var combo_tracker_mult: float = 1.2
@export var combo_tracker_splash: float = 0.3
@export var combo_tracker_radius: float = 1.4
## Convergence prismatique : arc qui saute d'ennemi en ennemi (× dégâts de la Rupture par ennemi), sauts au plus,
## portée d'un saut (m).
@export var combo_convergence_mult: float = 0.6
@export var combo_convergence_jumps: int = 4
@export var combo_convergence_reach: float = 5.0
## Contre-faille : rayon de la contre-attaque (× portée de la Taille) et dégâts (× la Taille).
@export var combo_counter_area: float = 1.5
@export var combo_counter_mult: float = 1.5
## Rebond spectral : copie de la Fente partie de l'ombre (× dégâts de la Fente).
@export var combo_spectral_mult: float = 0.8
## Égide vengeresse : bonus de la riposte (+0,75 = ×1,75). Sans la mutation Riposte, le bouclier qui cède libère
## une onde de base (× dégâts de l'Égide).
@export var combo_aegis_bonus: float = 0.75
@export var combo_aegis_plain: float = 1.0
## Prison de faille : distance au Mur (m) en deçà de laquelle l'ennemi attiré est entravé, durée (s), entravés au
## plus par puits.
@export var combo_prison_reach: float = 1.5
@export var combo_prison_root: float = 1.5
@export var combo_prison_cap: int = 12
## Rempart fracassant : distance d'atterrissage au Mur (m), largeur de l'onde de chaque côté (m), dégâts (× l'onde du
## Bond).
@export var combo_rampart_reach: float = 3.0
@export var combo_rampart_area: float = 2.5
@export var combo_rampart_mult: float = 1.2
## Tempête immobile : éclats supplémentaires (× dégâts d'un coup de Pluie), au plus par coup.
@export var combo_storm_mult: float = 0.6
@export var combo_storm_cap: int = 4
@export_group("Déblocages")
## Sorts offerts (débloqués d'office, sorts de départ par défaut), coûts et gains de Fragments de faille
## (docs/design/DEBLOCAGE_V2.md, indicatifs).
## Kit offert d'office (tiré en partie dès le premier lancement) : sorts, mutations de Taille et de Lance, et les 2
## sorts de départ par défaut.
@export var free_spells: Array[StringName] = [&"cleaving_slash", &"prismatic_lance", &"rupture", &"singularity",
	&"refracting_crystal", &"parry"]
@export var free_mutations: Array[StringName] = [&"slash_thrust", &"slash_whirlwind", &"lance_fan", &"lance_overcharge"]
@export var default_starting: Array[StringName] = [&"cleaving_slash", &"prismatic_lance"]
@export var spell_unlock_cost: int = 150
@export var mutation_unlock_cost: int = 80
@export var fragments_per_kill: float = 0.1
@export var fragments_per_minute: float = 6.0
@export var fragments_per_guardian: int = 25
@export var fragments_per_devourer: int = 60
@export_group("Ennemis")
@export var enemy_damage_scale: float = 0.8
@export var enemy_hp_growth_per_min: float = 0.1
@export var swarm_every: float = 60.0
@export var swarm_size: int = 10
@export_group("Boss")
## Gardien de mi-parcours : un des gardiens du chapitre, affaibli ; le vaincre lâche une grosse réserve d'EXP.
@export var guardian_time: float = 240.0
@export var guardian_hp_mult: float = 0.45
@export var guardian_xp: int = 40
@export var boss_time: float = 480.0
@export var boss_hp_mult: float = 0.55
@export var boss_damage_mult: float = 0.8
## PV effectifs (PV × multiplicateur de défense) visés pour le Dévoreur et pour le gardien du chapitre 1 ; ceux des
## autres chapitres montent de `boss_chapter_growth` par chapitre. Chaque partie 3D dure 8 minutes : le Chasseur arrive
## au boss avec à peu près la même puissance dans tous les chapitres, alors que les PV d'origine montent de × 4 sur
## la campagne 2D. Réglage du 16 novembre 2026 (docs/design/BOSS_V2.md, « Durée des combats »).
@export var boss_effective_hp: float = 5000.0
@export var guardian_effective_hp: float = 2900.0
@export var boss_chapter_growth: float = 0.15
## Raccourci de test --boss-test : niveaux donnés au Chasseur avant le boss (--boss-level=N pour changer).
@export var test_boss_levels: int = 15
## Part de l'intervalle d'origine entre deux techniques d'un boss (BossPhaseData.pattern_interval) : les boss 3D
## marchent et tournent entre deux techniques, un intervalle un peu plus court garde le rythme.
@export var boss_pace: float = 0.8
@export_group("Tour du chapitre 6")
## Durée d'un étage avant l'ouverture de la rampe (s), délai du gardien après l'arrivée à son étage, délai minimal
## du Dévoreur après l'arrivée au sommet (docs/maps/CARTES_3D.md).
@export var tower_floor_time: float = 180.0
@export var tower_guardian_delay: float = 45.0
@export var tower_boss_delay: float = 30.0
@export_group("Vagues")
## Début (s), apparitions par seconde, plafond d'ennemis en vie. Le mélange vient du bestiaire du chapitre
## (DraftRoster.mix) : chaque palier ouvre de nouveaux monstres.
@export var waves: Array[Dictionary] = [
	{"at": 0.0, "rate": 0.9, "cap": 22},
	{"at": 45.0, "rate": 1.3, "cap": 36},
	{"at": 120.0, "rate": 1.8, "cap": 55},
	{"at": 210.0, "rate": 2.4, "cap": 75},
	{"at": 300.0, "rate": 3.0, "cap": 100},
	{"at": 390.0, "rate": 3.6, "cap": 125},
]
@export var boss_wave: Dictionary = {"rate": 0.9, "cap": 28}
