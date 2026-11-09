class_name ArenaData
extends Resource
## Arène : taille, durée, vagues, événements et boss.

@export var id: StringName = &""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var size: Vector2 = Vector2(3200, 3200)
## Résolution de navigation adaptée aux grandes cartes ; les collisions du terrain restent précises.
@export_range(16.0,64.0,8.0) var navigation_cell_size: float = 16.0
## Moment d'arrivée du boss (secondes).
@export var boss_time: float = 420.0
@export var boss_id: StringName = &""
## Finale : vider les vagues puis rejoindre un cercle (rayons nuls = boss chronométré classique).
@export var finale_center := Vector2.ZERO
@export var finale_radii := Vector2.ZERO
@export var finale_opening_duration: float = 3.0
## Finale murée : barrières qui apparaissent quand le Chasseur entre dans l'arène (ses collisions et ces barrières
## délimitent le combat ; aucun cercle d'énergie). Vide : finale en cercle (finale_radii).
@export var finale_walls: Array[Rect2] = []
## Message d'appel vers l'arène du boss (une fois les zones ou les failles terminées).
@export var finale_travel_key: String = "FINALE_TRAVEL"
@export_group("Fermeture de failles")
## Mode « fermeture de failles » (si non vide, docs/design/LONGEVITE.md) : une faille (structure à détruire) à chaque
## point ; tant qu'elle est ouverte, des Corrompus en sortent. Toutes refermées : la finale appelle vers l'arène.
@export var rift_points: Array[Vector2] = []
@export var rift_enemy_id: StringName = &"rift_breach"
## Corrompus par seconde et par faille ouverte (× difficulté), dans la limite de la vague en cours (max_alive).
@export var rift_spawn_rate: float = 0.8
## Distance d'apparition autour de la faille.
@export var rift_spawn_radius: float = 240.0
## Une élite sort d'une faille ouverte toutes les N secondes (× difficulté).
@export var rift_elite_interval: float = 40.0
## Solidité des failles (× leurs PV, en plus des multiplicateurs de la carte) : durée de la fermeture.
@export var rift_hp_mult: float = 1.0
@export_group("")
@export var waves: Array[WavePhaseData] = []
## Grande arène : les zones sont des paliers qui partagent toute la carte (aucune barrière, pas de trajet entre elles).
@export var open_arena: bool = false
## Mode « vagues par zone » (si non vide) : zones à nettoyer dans l'ordre, puis la finale (boss).
## Les vagues au chrono, les événements et le boss chronométré sont alors désactivés.
@export var zones: Array[LevelZoneData] = []
## Multiplicateur d'XP des Corrompus (mode zones : nombre fini d'ennemis, il faut garder le rythme des niveaux).
@export var xp_mult: float = 1.0
## Progression pendant la partie : « levels » (mode survie : XP et montées de niveau) ou « milestones » (campagne :
## pas d'XP ; un choix à chaque jalon — fin de vague, faille fermée, vague d'autel tenue —, sans les petites
## caractéristiques, déjà dans l'arbre du Chasseur ; docs/design/MODES.md).
@export var progression: StringName = &"levels"
## Jalons : une élite tuée en est un aussi (cartes à peu de vagues, comme la fermeture de failles).
@export var milestone_on_elite: bool = false
## Force des Corrompus propre à la carte (épreuves de survie de plus en plus dures), en plus de la difficulté.
@export var enemy_hp_mult: float = 1.0
@export var enemy_damage_mult: float = 1.0
## Boss et gardien de la carte (Dévoreurs, gardiens) : leurs PV et leurs dégâts ne suivent pas enemy_hp_mult ;
## ces réglages corrigent un boss trop fort ou trop faible pour sa place dans la campagne.
@export var boss_hp_mult: float = 1.0
@export var boss_damage_mult: float = 1.0
@export_group("Vagues infinies (carte bonus, docs/design/MODES.md)")
## Pas de boss : les vagues s'enchaînent sans fin (une toutes les endless_wave_duration secondes) ; score = vague
## atteinte. La dernière tranche de `waves` se répète, plus dense à chaque vague.
@export var endless: bool = false
@export var endless_wave_duration: float = 60.0
## Apparitions en plus par vague (0,12 = +12 % par vague), dans la limite de densité.
@export var endless_spawn_growth: float = 0.12
@export_group("")
@export var events: Array[RunEventData] = []
@export var elite_first_time: float = 90.0
@export var elite_interval: float = 60.0
## Bestiaire réservé aux apparitions élites ; vide utilise les candidats des vagues.
@export var elite_enemy_ids: Array[StringName] = []
## Décor (entrée « environment.<id> » du manifeste d'assets). Absent : sol de remplacement aux couleurs ci-dessous.
@export var environment_id: StringName = &""
## Multiplicateur du nombre d'éléments de décor (1 = densité prévue par le décor).
@export var decor_density: float = 1.0
## Échelle du décor peint (docs/maps/ECHELLE_CHAPITRES_4_5.md) : 0,8 réduit l'image, les collisions, la mini-carte et
## toutes les positions de la carte à 80 %, pour mettre marches, dalles et colonnes à l'échelle des personnages.
## Les .tres restent en coordonnées peintes (éditeur de niveau) ; GameDB charge la copie réduite (scaled_copy).
## Personnages, vitesses, portées et rayons d'effet ne changent pas.
@export_range(0.3, 1.0, 0.05) var decor_scale: float = 1.0
@export var ground_color: Color = Color(0.11, 0.12, 0.18)
@export var ground_detail_color: Color = Color(0.16, 0.17, 0.25)
## Arènes hors campagne seulement : les cartes d'un chapitre se débloquent en avançant (Campaign).
@export var unlocked_by_default: bool = true
## Salle d'entraînement : ni vague, ni gardien, ni récompense (jamais proposée comme carte).
@export var practice: bool = false
## Obstacles présents dès le début : {identifiant d'ennemi STATIC: nombre}.
@export var start_obstacles: Dictionary = {}
## Règles propres à l'arène (effets installés au début de la partie).
@export var rule_effects: Array[GameplayEffect] = []
@export var rule_key: String = ""
@export_group("Défense d'autel (docs/design/CARTES.md)")
## Nombre de vagues à tenir (0 = mode désactivé). Après la dernière, le boss de la carte (gardien) s'éveille.
@export var altar_waves: int = 0
@export var altar_point: Vector2 = Vector2.ZERO
@export var altar_hp: float = 2000.0
@export var altar_radius: float = 70.0
@export var altar_wave_duration: float = 40.0
@export var altar_wave_pause: float = 8.0
## Corrompus apparus par seconde à la première vague (+20 % par vague).
@export var altar_spawn_rate: float = 1.3
## Part des dégâts de contact d'un pillard subie par l'autel.
@export var altar_damage_mult: float = 0.3
## Part des Corrompus de corps à corps qui marchent vers l'autel (pillards).
@export_range(0.0, 1.0) var altar_raider_share: float = 0.4
## Points d'arrivée des vagues (vide : cercle autour de l'autel).
@export var altar_spawn_points: Array[Vector2] = []
## Autel peint dans le décor (phare de la carte 19) : pas de sceau dessiné, l'autel reste sur place même si le décor
## peint le bloque ; seule une jauge au sol montre ses PV.
@export var altar_painted: bool = false
## Suffixe des textes de l'autel (« _LIGHTHOUSE » : ALTAR_INTRO_LIGHTHOUSE…) ; vide : textes du sceau.
@export var altar_text_suffix: String = ""
@export_group("Terrain lent (brique B1, docs/design/CARTES.md)")
## Zones de terrain lent (gués, boue...) : tout le monde y est ralenti, la Ruée garde sa vitesse.
@export var slow_zones: Array[Rect2] = []
@export_range(0.1, 1.0) var slow_zone_mult: float = 0.6
## Gués déjà peints sur la carte : pas de teinte ni d'ondulations dessinées par-dessus.
@export var slow_zones_painted: bool = false
@export_group("Vase qui colle (brique B1, chapitre 3)")
## Nappes de vase praticables : tout le monde y est fortement ralenti, et la vase colle encore mud_stick secondes
## après en être sorti (la vitesse revient progressivement). La Ruée garde sa vitesse.
@export var mud_zones: Array[Rect2] = []
@export_range(0.1, 1.0) var mud_mult: float = 0.45
@export var mud_stick: float = 1.0
## Vase déjà peinte sur la carte : pas de teinte dessinée par-dessus (les bulles restent).
@export var mud_painted: bool = false
@export_group("Marée (brique B4, chapitre 3)")
## Chaussées basses : raccourcis à marée basse, noyées et infranchissables à marée haute (TideDirector).
@export var tide_causeways: Array[Rect2] = []
@export var tide_first: float = 25.0
@export var tide_low: float = 20.0
@export var tide_warning: float = 4.0
@export var tide_high: float = 12.0
@export_group("Banquise qui se fend (brique B4, carte 19)")
## Plaques de banquise (polygones) : praticables, elles se fendent par moments (alerte) puis s'ouvrent sur l'eau noire,
## infranchissables, avant de regeler (FloeDirector).
@export var floe_plates: Array[PackedVector2Array] = []
## Plaques posées sur les accès au phare : jamais plus de floe_access_max ouvertes en même temps.
@export var floe_access: Array[int] = []
@export var floe_access_max: int = 1
## Plaques hors accès ouvertes à chaque cycle (une par quart de la carte au plus).
@export var floe_ring_count: int = 2
## Images de l'eau ouverte (une par plaque, dans l'ordre de floe_plates) et leur rectangle dans le jeu.
@export var floe_overlays: Array[String] = []
@export var floe_overlay_rects: Array[Rect2] = []
@export var floe_first: float = 20.0
@export var floe_period: float = 18.0
@export var floe_warning: float = 3.0
@export var floe_open: float = 9.0
## Dégâts au Chasseur resté sur une plaque qui s'ouvre (il est rejeté sur la glace ferme) ; part des PV max infligée
## aux Corrompus (non volants) qui y sombrent.
@export var floe_damage: float = 14.0
@export_range(0.0, 1.0) var floe_enemy_ratio: float = 0.6
@export_group("Statues qui s'éveillent (brique B8, carte 24)")
## Socles peints : une Statue endormie sur chacun, qui s'éveille quand le Chasseur passe à statue_awaken_radius.
@export var statue_plinths: Array[Vector2] = []
## Décalage du sprite endormi sur le dessus peint du socle.
@export var statue_offset: Vector2 = Vector2(0, 20)
@export var statue_awaken_radius: float = 300.0
@export var statue_warning: float = 1.2
@export var statue_enemy: StringName = &"awakened_statue"
@export_group("Échos piégés (brique B10, carte 24)")
## Cages à briser (objectif facultatif) : rester echo_cage_time s dans le cercle ; embuscade à l'ouverture.
@export var echo_cages: Array[Vector2] = []
@export var echo_cage_radius: float = 90.0
@export var echo_cage_time: float = 4.0
@export var echo_cage_heal: float = 0.15
@export var echo_cage_ambush: StringName = &"torn_shade"
@export var echo_cage_ambush_count: int = 3
@export_group("Portes runiques (brique B4, carte 22)")
## Portes (rectangles fermant leur seuil) et groupes fermés tour à tour (indices dans rune_gates).
@export var rune_gates: Array[Rect2] = []
@export var rune_gate_patterns: Array[PackedInt32Array] = []
@export var rune_gate_first: float = 15.0
@export var rune_gate_period: float = 20.0
@export var rune_gate_warning: float = 3.0
@export_group("Sol corrompu (brique B9, carte 21)")
## Nappes corrompues (polygones) : qui y reste est renforcé (CorruptionDirector).
@export var corrupted_patches: Array[PackedVector2Array] = []
## Bonus de dégâts du Chasseur à pleine charge ; charge pleine en corruption_build s, perdue en corruption_fade s.
@export var corruption_power: float = 0.4
@export var corruption_build: float = 3.0
@export var corruption_fade: float = 2.0
## Dégâts subis par le Chasseur tant qu'il est sur une nappe.
@export var corruption_taken_mult: float = 1.15
## Corrompus sur une nappe : dégâts et vitesse.
@export var corruption_enemy_mult: float = 1.3
@export var corruption_enemy_speed: float = 1.15
@export_group("Écho des sorts (brique B9, carte 20)")
## Part de puissance de l'écho : chaque sort offensif du Chasseur se relance une fois après spell_echo_delay (0 : non).
@export_range(0.0, 1.0) var spell_echo: float = 0.0
@export var spell_echo_delay: float = 0.6
@export_group("Courants (brique B6, docs/design/CARTES.md)")
## Courants permanents : le Chasseur et les Corrompus y dérivent dans le sens du courant (pas pendant la Ruée ;
## boss et Échos épargnés). Le suivre fait gagner du temps, le remonter en fait perdre.
@export var currents: Array[Rect2] = []
## Sens de chaque courant, dans l'ordre de currents (absent : vers la droite).
@export var current_dirs: Array[Vector2] = []
## Vitesse de dérive (px/s), moindre pour les Corrompus lourds (résistance au recul).
@export var current_speed: float = 140.0
@export_group("Crues (brique B3, docs/design/CARTES.md)")
## Lits de rivière qui débordent à tour de rôle : télégraphe (eau qui monte), puis crue qui emporte et blesse
## tout ce qui s'y trouve. Les Corrompus y perdent bien plus que le Chasseur : les y attirer.
@export var flood_lanes: Array[Rect2] = []
## Sens du flot de chaque lit, dans l'ordre de flood_lanes (absent : vers la droite).
@export var flood_dirs: Array[Vector2] = []
## Première crue (secondes après le départ), puis temps calme entre la fin d'une crue et l'alerte suivante.
@export var flood_first: float = 30.0
@export var flood_interval: float = 18.0
@export var flood_warning: float = 3.0
@export var flood_duration: float = 3.5
## Poussée du flot (px/s) : on peut en sortir par le côté ou par la Ruée.
@export var flood_push: float = 300.0
## Dégâts au Chasseur toutes les 0,5 s dans la crue (× dégâts ennemis de la difficulté).
@export var flood_damage: float = 6.0
## Part des PV max d'un Corrompu emportée toutes les 0,5 s dans la crue (boss épargnés).
@export var flood_enemy_ratio: float = 0.12
## Habillage : &"water" (crues) ou &"lava" (débordements de lave, carte 9 : pas de poussée, dégâts forts).
@export var flood_style: StringName = &"water"
## Lave : plaques brûlantes laissées dans le lit après le débordement (secondes ; 0 = aucune).
@export var flood_afterburn: float = 0.0
@export_group("Sol brûlant (carte 6, docs/design/CARTES.md)")
## Plaques brûlantes peintes sur la carte : (x, y, rayon) en unités du monde. Praticables, elles blessent tout le monde.
@export var burn_plates: Array[Vector3] = []
## Dégâts au Chasseur par coup (toutes les burn_tick secondes) ; part des PV max retirée aux Corrompus.
@export var burn_damage: float = 4.0
@export var burn_tick: float = 0.5
@export_range(0.0, 1.0) var burn_enemy_ratio: float = 0.06
@export_group("Nids qui pondent (brique B8, carte 8, docs/design/CARTES.md)")
## Emplacements des nids (structures qui bloquent le passage) ; ils pondent tant qu'ils tiennent debout.
@export var nest_points: Array[Vector2] = []
@export var nest_enemy: StringName = &"cinder_crawler"
@export var nest_interval: float = 7.0
@export var nest_batch: int = 2
## Petits vivants au plus par nid.
@export var nest_max_brood: int = 6
@export var nest_hatch_time: float = 0.8
## Un nid ne pond que si le Chasseur est à moins de cette distance (pas d'accumulation hors de vue).
@export var nest_wake_range: float = 1100.0
@export_group("Bulbes de braise (brique B5, carte 7, docs/design/CARTES.md)")
## Emplacements des bulbes (unités du monde). Un coup allié les amorce ; ils éclatent après pod_prime secondes.
@export var ember_pods: Array[Vector2] = []
@export var pod_radius: float = 170.0
@export var pod_prime: float = 1.5
## Dégâts aux Corrompus : forfait + part des PV max (moitié pour les élites, forfait seul pour les boss).
@export var pod_damage: float = 30.0
@export_range(0.0, 1.0) var pod_damage_ratio: float = 0.35
## Le Chasseur trop proche est touché aussi (télégraphe : il a le temps de s'écarter).
@export var pod_player_damage: float = 12.0
@export var pod_regrow: float = 25.0
@export_group("Abris (règle des abris, docs/design/DIFFICULTE.md)")
## Rochers indestructibles posés par le jeu sur les cartes peintes trop dégagées : ils bloquent le passage, les tirs et
## les souffles (cercles d'obstacles), pour se protéger des attaques de boss.
@export var cover_rocks: Array[Vector2] = []
@export var cover_radius: float = 58.0
@export_group("Miroirs-portails (brique B6, carte 14, docs/design/CARTES.md)")
## Paires de portails, à la suite : portail, jumeau, portail, jumeau… Entrer dans l'un ramène au jumeau.
@export var portal_pairs: Array[Vector2] = []
@export var portal_radius: float = 52.0
## Recharge d'une paire après le passage du Chasseur.
@export var portal_cooldown: float = 5.0
## Un Corrompu qui vient de passer ne repasse pas avant ce délai ; un portail laisse passer au plus
## portal_enemy_rate Corrompus par seconde.
@export var portal_enemy_cooldown: float = 8.0
@export var portal_enemy_rate: float = 1.5
## Mode vagues par zone : zone à atteindre pour qu'une paire s'allume (indice dans l'ordre des paires ; 0 ou absent :
## dès le début ; zones.size() : à l'ouverture de la finale). Évite qu'un portail fasse sauter une zone.
@export var portal_pair_unlock: Array[int] = []
## Socles de téléporteurs peints (carte 23) : pas de miroir posé, le jeu dessine le vortex de faille.
@export var portal_painted: bool = false
@export var portal_intro_key: String = "PORTAL_INTRO"
@export_group("Cristaux-miroirs (brique B5, carte 13, docs/design/CARTES.md)")
## Emplacements des cristaux-miroirs. Un coup allié les charge ; ils éclatent en trois rayons (le premier dans le sens
## du coup, les deux autres à 120°) qui transpercent les Corrompus sur leur ligne et touchent le Chasseur dans l'axe.
@export var crystal_mirrors: Array[Vector2] = []
@export var crystal_prime: float = 0.9
@export var crystal_beam_length: float = 650.0
@export var crystal_beam_width: float = 44.0
## Dégâts aux Corrompus : forfait + part des PV max (moitié pour les élites, forfait seul pour les boss).
@export var crystal_damage: float = 35.0
@export_range(0.0, 1.0) var crystal_damage_ratio: float = 0.3
@export var crystal_player_damage: float = 12.0
@export var crystal_regrow: float = 18.0
## Aimantation du premier rayon vers un boss proche de l'axe (degrés) : viser le gardien reste lisible.
@export var crystal_assist: float = 30.0
@export_group("Pluie de roches magmatiques (carte 10, docs/design/CARTES.md)")
## Une chute toutes les rockfall_interval secondes (0 = aucune) ; plus fréquente à chaque zone nettoyée et contre le boss.
@export var rockfall_interval: float = 0.0
@export var rockfall_radius: float = 90.0
@export var rockfall_warning: float = 1.4
@export var rockfall_damage: float = 14.0
## Part des PV max retirée aux Corrompus touchés (forfait seul pour les boss).
@export_range(0.0, 1.0) var rockfall_enemy_ratio: float = 0.2
## Plaque brûlante laissée à l'impact (secondes ; 0 = aucune).
@export var rockfall_burn_time: float = 4.0
## Intervalle multiplié par ce facteur à chaque zone nettoyée, et par rockfall_boss_mult pendant le combat final.
@export_range(0.3, 1.0) var rockfall_zone_mult: float = 0.85
@export_range(0.3, 1.0) var rockfall_boss_mult: float = 0.6
## Cratères qui crachent les roches (grande arène) : chaque roche part en arc du cratère le plus proche de sa cible.
## Vide : la roche tombe du ciel.
@export var rockfall_vents: Array[Vector2] = []
@export_group("Glace qui fait glisser (brique B1, chapitre 4)")
## Plaques de glace praticables : ellipse inscrite dans chaque rectangle (unités du monde). Sur la glace, tout le monde
## (Chasseur, Corrompus) garde son élan : accélération et changement de direction lents, glissade quand on s'arrête.
@export var ice_patches: Array[Rect2] = []
## Temps pour atteindre sa pleine vitesse (ou retourner sa course) sur la glace.
@export var ice_accel_time: float = 0.6
## Glissade : temps pour s'arrêter quand on lâche la direction.
@export var ice_glide_time: float = 1.5
## Vitesse maximale sur la glace (multiplicateur) et longueur de la Ruée (multiplicateur, finit en glissade).
@export var ice_speed_mult: float = 1.15
@export var ice_dash_mult: float = 1.4
@export_group("Froid et braseros (brique B7, chapitre 4)")
## Froid gagné par seconde loin des braseros (jauge de 0 à 100 ; 0 = pas de froid sur la carte).
@export var cold_rate: float = 0.0
## Froid perdu par seconde dans la chaleur d'un brasero allumé.
@export var cold_recover: float = 30.0
## Braseros de la carte (unités du monde) et rayon de leur chaleur.
@export var braziers: Array[Vector2] = []
@export var brazier_radius: float = 220.0
## Un brasero soufflé par le Chaman du gel se rallume après ce délai (secondes).
@export var brazier_relight: float = 15.0
## Jauge pleine : dégâts au Chasseur toutes les 0,5 s (× dégâts ennemis de la difficulté) et ralentissement.
@export var cold_damage: float = 4.0
@export_range(0.1, 1.0) var cold_hinder: float = 0.7
@export_group("Nuit et lucioles (brique B2, docs/design/CARTES.md)")
## Opacité du voile de nuit (0 = jour ; 0,85 = nuit profonde). La nuit limite les cibles aux ennemis éclairés.
@export_range(0.0, 0.95) var night: float = 0.0
## Rayon de lumière autour du Chasseur (au-delà, ses tirs automatiques ne voient rien).
@export var light_radius: float = 300.0
## Rayon de lumière autour de chaque Écho.
@export var echo_light_radius: float = 120.0
## Clairières de lucioles : zones éclairées qui révèlent les ennemis (statut Révélé).
@export var firefly_glades: Array[Vector2] = []
@export var firefly_radius: float = 220.0
## Couleur des lueurs des clairières (lucioles ; braises flottantes sur les Tanières de suie) et annonce de la nuit.
@export var firefly_color: Color = Color(0.85, 1.0, 0.45)
@export var night_intro_key: String = "NIGHT_INTRO"
@export_group("Blizzard (variante de la brique B2, carte 18)")
## Blizzard : le voile de nuit devient une tempête de neige (couleur blizzard_color). Entre deux rafales, voile léger
## (blizzard_calm) et cibles libres ; pendant une rafale, le voile monte à `night`, on ne vise que ce qu'on voit et le
## vent pousse tout le monde (sauf dans les refuges du vent, firefly_glades, qui restent dégagés).
@export var blizzard: bool = false
@export_range(0.0, 0.95) var blizzard_calm: float = 0.35
@export var blizzard_color: Color = Color(0.86, 0.9, 0.97)
## Cycle : rafale toutes les `period` secondes, annoncée `warning` secondes (le voile s'épaissit), longue de `gust`.
@export var blizzard_period: float = 16.0
@export var blizzard_warning: float = 2.0
@export var blizzard_gust: float = 5.0
## Poussée du vent pendant une rafale (unités par seconde).
@export var blizzard_wind: float = 45.0

## Clé de texte de l'autel propre à la carte (ALTAR_INTRO → ALTAR_INTRO + altar_text_suffix).
func altar_key(key: String) -> String:
	return key + altar_text_suffix


## Copie en coordonnées du jeu (décor réduit de decor_scale) ; l'arène elle-même si l'échelle vaut 1.
func scaled_copy() -> ArenaData:
	if is_equal_approx(decor_scale, 1.0):
		return self
	var k: float = decor_scale
	var a: ArenaData = duplicate()
	a.size = size * k
	a.finale_center = finale_center * k
	a.finale_radii = finale_radii * k
	a.finale_walls = _rects(finale_walls, k)
	a.rift_points = _points(rift_points, k)
	var scaled_zones: Array[LevelZoneData] = []
	for zone: LevelZoneData in zones:
		var z: LevelZoneData = zone.duplicate()
		z.anchor = zone.anchor * k
		z.exit_walls = _rects(zone.exit_walls, k)
		scaled_zones.append(z)
	a.zones = scaled_zones
	a.altar_point = altar_point * k
	a.altar_spawn_points = _points(altar_spawn_points, k)
	a.slow_zones = _rects(slow_zones, k)
	a.mud_zones = _rects(mud_zones, k)
	a.tide_causeways = _rects(tide_causeways, k)
	a.floe_plates = _polys(floe_plates, k)
	a.corrupted_patches = _polys(corrupted_patches, k)
	a.rune_gates = _rects(rune_gates, k)
	a.statue_plinths = _points(statue_plinths, k)
	a.statue_offset = statue_offset * k
	a.echo_cages = _points(echo_cages, k)
	a.floe_overlay_rects = _rects(floe_overlay_rects, k)
	a.currents = _rects(currents, k)
	a.flood_lanes = _rects(flood_lanes, k)
	var plates: Array[Vector3] = []
	for plate: Vector3 in burn_plates:
		plates.append(plate * k)
	a.burn_plates = plates
	a.nest_points = _points(nest_points, k)
	a.ember_pods = _points(ember_pods, k)
	a.cover_rocks = _points(cover_rocks, k)
	a.portal_pairs = _points(portal_pairs, k)
	a.crystal_mirrors = _points(crystal_mirrors, k)
	a.rockfall_vents = _points(rockfall_vents, k)
	a.ice_patches = _rects(ice_patches, k)
	a.braziers = _points(braziers, k)
	a.firefly_glades = _points(firefly_glades, k)
	return a


static func _points(list: Array[Vector2], k: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Vector2 in list:
		out.append(p * k)
	return out


static func _polys(list: Array[PackedVector2Array], k: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in list:
		var scaled := PackedVector2Array()
		for p: Vector2 in poly:
			scaled.append(p * k)
		out.append(scaled)
	return out


static func _rects(list: Array[Rect2], k: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Rect2 in list:
		out.append(Rect2(r.position * k, r.size * k))
	return out


## L'arène se termine par une finale (cercle ou arène murée) plutôt que par un boss chronométré classique.
func has_finale() -> bool:
	return finale_radii.x > 0 or not finale_walls.is_empty()
