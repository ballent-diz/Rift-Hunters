# Collection d'Échos : 16 Échos étalés sur trois chapitres

Décision du propriétaire (21 octobre 2026) : on récupère les Échos petit à petit, pour donner envie de tous les
découvrir et les posséder ; la collection se complète à la carte finale du chapitre 3. Les moins forts d'abord.

## Sources (MonsterData, groupe « Progression »)

- `discovery = &"start"` : disponible dès le départ (Cendrelame seul).
- `&"capture"` : à découvrir sur la carte `discovery_arena`. Tant qu'il n'est pas débloqué, son **Écho errant
  apparaît à coup sûr** à la mort d'une élite (`EchoCollection.capture_target`) ; on le capture (Rite de lien), il
  rejoint l'équipe pour la partie et il est débloqué pour toujours. Sinon, les Échos errants ne sont que des Échos
  déjà possédés (recrutés pour la partie).
- `&"victory"` : débloqué en terminant la carte `discovery_arena`.
- `&"stars"` : débloqué en obtenant tous les objectifs Normal du chapitre `discovery_chapter`.
- `&"shop"` : en vente à la boutique (`shop_price` éclats) après une victoire sur `discovery_arena` (lot M3).

Une carte ou un chapitre qui n'existe pas encore s'affiche « une carte à venir ». Le refuge (Écho de départ verrouillé,
bestiaire) indique la source de chaque Écho et la collection « Échos · n / 16 ».

Les anciennes récompenses qui débloquaient des Échos (objectifs « Premiers pas », « Vétéran des Failles »,
« Chasseur d'élites », « L'appel du vide », recherche « Conducteurs de faille ») donnent maintenant des éclats ou un
titre. Sauvegarde v4 : Mousseroc, offert au départ jusqu'ici, reste acquis aux joueurs existants.

## Répartition

Classement de force mesuré au bot (chaque Écho en Écho de départ, Plaine fracturée, 2 graines) : les moins forts
arrivent en premier. Voir le tableau ci-dessous, rempli d'après ce classement.

Classement mesuré (21 octobre 2026) : 5 minutes en invulnérable, dégâts totaux de l'équipe, du moins fort au plus
fort : Scoriade, Lueurine, Sylvécaille, Sporelune, Lucivelle, Égidor, Spectrâtre, Pyraile, Gravelune, Ronceline,
Solgriffe, Cendrelame, Fulgurine, Mirelle, Mousseroc, Gueule-d'ombre. Les quinze premiers sont à ±10 % ;
Gueule-d'ombre (exécutions) est hors classement, gardé pour la toute fin. Les dégâts comptés sont désormais plafonnés
aux PV retirés (une dévoration comptait PV × 10 + 9999).

| Chapitre | Écho | Source |
|---|---|---|
| — | Cendrelame | départ |
| 1 | Sylvécaille | capture : Ruines des Cascades (carte 1) |
| 1 | Scoriade | boutique, 600 éclats, après les Hautes Terres d'Orage (carte 2) |
| 1 | Lueurine | capture : Bois des Lucioles (carte 3) |
| 1 | Sporelune | capture : Source des Cascades (carte 5, à venir) |
| 2 | Lucivelle | boutique, 900 éclats, après la Source des Cascades |
| 2 | Pyraile | capture : carte 7 (à venir) |
| 2 | Égidor | victoire : Épreuve du Gué (fin des épreuves de survie) |
| 2 | Spectrâtre | capture : carte 9 (à venir) |
| 2 | Gravelune | victoire : carte 10 (Dévoreur du chapitre 2, à venir) |
| 3 | Ronceline | capture : carte 11 (à venir) |
| 3 | Solgriffe | étoiles : toutes celles du chapitre 2 |
| 3 | Fulgurine | boutique, 1200 éclats, après la carte 10 |
| 3 | Mirelle | capture : carte 13 (à venir) |
| 3 | Mousseroc | boutique, 1600 éclats, après la carte 13 |
| 3 | Gueule-d'ombre | capture : carte 15 (finale du chapitre 3, à venir) — le dernier |

Identifiants des cartes à venir : `cascade_source` (carte 5), `chapter2_map2` (7), `chapter2_map4` (9),
`chapter2_map5` (10), `chapter3_map1` (11), `chapter3_map3` (13), `chapter3_map5` (15), chapitre `chapter2` ; à
renommer avec les vrais identifiants quand ces cartes arrivent. Bot (Cendrelame seul au départ, bonus d'arbre
« veteran ») : campagne 11 victoires sur 12 sur les cartes 1 à 4.
