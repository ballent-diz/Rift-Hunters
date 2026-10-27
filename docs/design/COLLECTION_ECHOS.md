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

**Révision du 26 octobre 2026 (décision du propriétaire)** : chaque carte de campagne gagnée débloque **exactement un
Écho**, dans l'ordre de force mesuré (les moins forts d'abord, à quelques échanges près pour coller au décor). Plus de
boutique, d'étoiles ni de capture en partie pour les Échos ; l'équipe (3 au plus) se compose au refuge.

| Carte | Écho gagné à la victoire |
|---|---|
| — (départ) | Cendrelame |
| 1. Ruines des Cascades | Sylvécaille |
| 2. Hautes Terres d'Orage | Scoriade |
| 3. Bois des Lucioles | Lueurine |
| 4. Gué des Brumes | Sporelune |
| 5. Source des Cascades | Lucivelle |
| 6. Lisière calcinée | Égidor |
| 7. Évents de cendre (`ash_vents`) | Pyraile |
| 8. Tanières de suie (`soot_dens`) | Spectrâtre |
| 9. Volcan carré (`volcano_heart`) | Gravelune |
| 10. Grande arène (`caldera_arena`) | Solgriffe |
| 11. Mangrove des racines (`root_mangrove`) | Ronceline |
| 12. Temple des marées (`tide_temple`) | Mirelle |
| 13 (`chapter3_map3`) | Fulgurine |
| 14 (`chapter3_map4`) | Mousseroc |
| 15 (`chapter3_map5`, finale du chapitre 3) | Gueule-d'ombre — le dernier |

Identifiants des cartes 13 à 15 à renommer quand elles arrivent. Bot (Cendrelame seul au départ, bonus d'arbre
« veteran ») : campagne 11 victoires sur 12 sur les cartes 1 à 4.
