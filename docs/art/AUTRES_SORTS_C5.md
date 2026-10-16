# Animations des dix autres sorts du Chasseur

Suite du lot C5, 16 octobre 2026. Dix scènes autonomes et trente configurations
(base et deux variantes), sans nouvelle génération d’image, capture ou vidéo.
Réutilisation des textures dessinées de Taille fendante, du maillage de traînée,
des fragments et de la palette alliée blanc/cyan. Accents jade pour le Lien,
bleu argenté pour l’Abîme, ambre discret pour les persistances de feu.

Ces ressources sont **raccordables, pas déjà intégrées au combat**. Le code partagé
`assets/vfx/hunter/spell_vfx.gd` ne lit aucun `RunContext`, `Player`, `Enemy`,
statistique ou entrée utilisateur ; aucune collision ni règle de jeu.
Le propriétaire valide leur rendu en jeu après raccordement par Claude dans C1/C2.
Les ressources restent `wip` tant que ce rendu n’est pas accepté.

## Catalogue

Scènes : `assets/vfx/hunter/<identifiant>/<identifiant>.tscn`.
Manifeste : `vfx.hunter.<identifiant>` ; catalogue : `assets/vfx/hunter/remaining_catalog.json`.
Les durées comprennent la fin de l’effet. Les dimensions sont des unités du monde,
jamais des hitboxes ni des valeurs d’équilibrage imposées à C1.

| Sort / identifiant | Variantes de ressource | Durées de référence | Animation et dimensions |
|---|---|---|---|
| Bond de faille / `rift_leap` | `base`, `return`, `impact` | 0,85 / 0,85 / 1,05 s | Départ déchiré, traînée courbe vers l’arrivée, dispersion et onde. Trajet 380 ; onde 75, ou 150 pour Impact. Retour conserve des signatures aux deux extrémités. |
| Parade / `parry` | `base`, `mirror`, `pack_guard` | 0,70 s | Garde avant de rayon 65 pendant 0,4 s, disparition 0,3 s. Contact confirmé : éclat, contre-coupe ; Miroir ajoute un trait réfléchi. Garde de meute ajoute les vraies positions des alliés. |
| Rupture / `rupture` | `base`, `reaction`, `inferno` | 0,85 / 1,10 / 3,65 s | Éclat central, cercle fracturé et fragments jusqu’à 220. Réaction répète des accents aux Marques fournies. Brasier ajoute trois secondes de flammes de sol. |
| Cristal réfracteur / `refractor_crystal` | `base`, `double_prism`, `focus` | 8,65 s | Matérialisation, cristal de hauteur 64, satellites en orbite, disparition. Réfraction de trois traits sur signal réel ; second cristal ou convergence selon variante. |
| Singularité / `singularity` | `base`, `horizon`, `collapse` | 3,65 / 3,65 / 2,15 s | Trois bras dessinés en spirale, fragments convergents, noyau et implosion. Rayon proposé 220 ; Horizon 308 ; maintien 3 s ou 1,5 s pour Effondrement, puis 0,65 s de fin. |
| Mur de faille / `rift_wall` | `base`, `chains`, `burning_wall` | 4,60 s | Couture peinte instable, facettes et contacts. Largeur 260 ; maintien 4 s, ouverture et fermeture 0,60 s. Chaînes vers les points fournis ; Rempart ardent ajoute des langues de feu. |
| Failles jumelles / `twin_rifts` | `base`, `loop`, `exile` | 4,60 s | Deux ouvertures irisées et filaments de transit. Rayons 31, ou 39 pour Exil ; Boucle dessine une circulation de retour. Maintien visuel de référence 4 s, à fixer par C1. |
| Appel de meute / `pack_call` | `base`, `rally`, `feast` | 0,90 / 1,30 / 0,90 s | Jusqu’à trois traînées depuis les vrais Échos vers la cible, puis impact. Ralliement ajoute des signatures autour des alliés ; Curée des tailles croisées au contact. |
| Égide de faille / `rift_aegis` | `base`, `riposte`, `sharing` | 4,50 s | Boucliers transparents facettés autour des positions fournies, hauteur environ 74. Riposte attend le signal de rupture pour l’onde de rayon 180 ; Partage lie les boucliers. |
| Permutation / `swap` | `base`, `relay`, `sanctuary` | 0,85 / 0,85 / 1,35 s | Deux portails et deux flux opposés, arrivée et dispersion. Relais attend le vrai sort de l’Écho ; Sanctuaire dessine deux ondes de soin. |

Les portées 220/240 non précisées dans la conception sont des dimensions visuelles proposées,
ajustables par C1. Les durées de maintien des entités persistantes sont des valeurs de référence,
pas un second système de temporisation du gameplay.

## API commune

Après ajout de la scène à l’arbre :

```gdscript
var fx = load("res://assets/vfx/hunter/rift_leap/rift_leap.tscn").instantiate()
effects_parent.add_child(fx)
fx.play_between(start_position, end_position, &"impact")
```

- `play(direction, variant)` : joue depuis l’axe local +X, avec rotation selon la direction.
- `play_from(direction, variant, seconds)` : commence à une phase avancée ; utile pour
  synchroniser un coup instantané déjà confirmé.
- `play_between(from, to, variant)` : place et oriente l’effet entre deux points **globaux**,
  sans déplacer d’acteur. La destination devient `(distance, 0)` dans le repère de l’effet.
- `set_destination(local_offset)` : destination **locale**, après orientation de l’effet.
  Pour convertir une position globale existante, utiliser `fx.to_local(world_position)`.
- `set_secondary_offsets(PackedVector2Array)` : positions locales des vrais Échos,
  Marques ou ennemis concernés. Seize positions maximum ; les effets d’équipe en utilisent trois.
- `set_secondary_colors(PackedColorArray)` : couleurs réelles des Échos pour les traînées de meute.
  Aucun sprite de créature n’est créé ou remplacé par ces effets.
- `trigger_pulse(local_contact, local_direction)` : accent de contact, parade, réfraction,
  passage de portail ou rupture de bouclier, **seulement sur confirmation du gameplay**.
- `release()` : saute à la dernière phase de disparition ; utile à la destruction anticipée
  d’un cristal, d’un mur, d’un portail, d’une singularité ou d’un bouclier.
- `seek_visual(seconds)` : positionnement de contrôle, lecture temporelle arrêtée.
- `duration()` et `visual_finished` : durée courante et fin de présentation.
  L’effet se détruit par défaut ; `destroy_on_finish = false` permet sa réutilisation.

Exports : `spell_range`, `destination_offset`, `active_duration` et `destroy_on_finish`.
`active_duration = -1` garde la durée par défaut. Une valeur positive fournit la durée
de maintien réelle d’une entité persistante ; mettre la valeur avant de démarrer.
Les trois variantes de chaque famille partagent le même fichier de scène.

### Règles de raccordement importantes

Parade ne décide pas qu’un coup est paré. Cristal ne crée aucun projectile.
Singularité n’attire personne. Mur ne bloque personne. Failles et Permutation
ne téléportent rien. Appel de meute ne remplace pas les modèles des Échos.
Égide ne donne aucun bouclier et ne soigne pas. Rupture ne choisit pas les Marques.
Les noms des variantes ne sont qu’un choix de présentation ; leurs vrais effets restent dans C1/C2.

Les positions secondaires peuvent être rafraîchies pendant la lecture pour suivre les
vrais acteurs. Sans positions secondaires, aucune équipe fictive de trois Échos n’apparaît.
Les effets persistants restent à une position fixe tant que leur parent ne les déplace pas.
Pour Égide, l’attacher à l’acteur ou actualiser son transform visuel ; aucune poursuite automatique.

Miroir et Relais montrent une impulsion stylisée après `trigger_pulse` ; les vrais tirs
peuvent employer leurs propres scènes de projectile, sans superposer deux tirs opaques.
Les teintes et dimensions doivent rester subordonnées aux télégraphes ennemis et à la lisibilité.

## Fichiers et coût graphique

Une texture dessinée réutilisée par les dix scènes, aucun nouvel atlas lourd et aucune
nouvelle image générée. Le champ `sheet` du manifeste pointe vers cette texture de travail :
il ne s’agit ni d’une icône ni d’une planche animée. Charger le champ `scene`.
Le rendu emploie des courbes maillées, des facettes et un nombre borné de fragments.
Les effets d’équipe affichent au maximum trois alliés, les réactions en chaîne huit accents.

Contrôle ciblé unique en fin de lot : `res://tools/art/check_hunter_vfx.tscn` charge les dix
familles et leurs trente variantes, contrôle leurs durées et les rend à cinq moments,
y compris les accents de contact et une fermeture anticipée. Aucune capture ou vidéo exportée.
Puis validation du manifeste. Les tests de gameplay restent du ressort de C1/C2.

Résultat du contrôle : 30 configurations chargées et rendues sans erreur ; manifeste
de 83 entrées, 82 valides, un placeholder préexistant (`monster.mirrorling`), zéro erreur.
