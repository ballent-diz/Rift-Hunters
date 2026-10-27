# Arbres des Échos et sorts des Échos (lot C3)

Statut : **réalisé le 17 octobre 2026 — proposition à valider par le propriétaire** (noms, effets et chiffres
retouchables, tout est en données). Cadre : [COMPETENCES_ET_BUILDS.md](COMPETENCES_ET_BUILDS.md), [ECHOS.md](ECHOS.md).

## Principes

- Chaque Écho a **son propre arbre** de 5 nœuds, sur le modèle de l'arbre du Chasseur : **apprendre** coûte des
  Éclats (une fois pour toutes), **activer** coûte des **Points d'Écho**.
- **Points d'Écho = 2 + niveau de maîtrise de l'Écho** (0 à 5, soit 2 à 7 points ; 1 + maîtrise avant la v2). Jouer un Écho le rend plus fort :
  la maîtrise existante prend tout son sens.
- **Deux sorts par Écho, un seul équipé** (choix exclusif, gratuit en points) : sa Technique d'origine, connue
  d'office, et un **second sort** à apprendre. Le sort équipé se lance avec la touche de l'Écho (1, 2 ou 3 selon sa
  place dans l'équipe), visé au curseur.
- L'activation est enregistrée **dans le build du Chasseur** : changer de build change aussi les Échos.
- Si un second sort est équipé, une évolution de l'Écho ne le remplace pas.

## Les 5 nœuds de chaque Écho

| Nœud | Type | Effet | Apprendre (Éclats) | Points |
|---|---|---|---|---|
| Puissance | Passif, 3 rangs | Dégâts de cet Écho +8 % par rang | 40 / 70 / 110 | 1 par rang |
| Concentration | Passif, 2 rangs | Recharge du sort de cet Écho −10 % par rang | 60 / 100 | 1 par rang |
| Sort d'origine | Sort | La Technique actuelle de l'Écho | connu d'office | 0 |
| Second sort | Sort | Voir le tableau ci-dessous (exclusif avec le sort d'origine) | 200 | 0 |
| Signature | Passif | Bonus propre à l'Écho (tableau ci-dessous) | 300 | 3 |

Tout activer coûte 8 points pour 6 au maximum : il faut choisir. Prérequis : le second sort et la Signature
demandent au moins un rang de Puissance ou de Concentration.

## Seconds sorts et signatures

| Écho | Second sort (visé au curseur) | Signature |
|---|---|---|
| Cendrelame | **Lame de cendres** : fonce jusqu'au curseur en tranchant tout sur son passage, Brûlure | Frénésie : vitesse d'attaque +20 % |
| Mousseroc | **Rempart de mousse** : provoque les ennemis autour du curseur 3 s et les ralentit | Écorce : dégâts subis par le Chasseur −6 % |
| Lucivelle | **Pluie d'étincelles** : pose 2 Marques sur les ennemis autour du curseur | Prisme : Marques, cumul maximal +1 |
| Ronceline | **Floraison** : soigne le Chasseur de 10 % et enracine les ennemis autour du curseur | Sève : régénération +0,4 PV/s |
| Fulgurine | **Arc chaîné** : éclair qui rebondit sur 6 ennemis depuis le curseur, électrise | Portée : portée d'attaque +20 % |
| Gueule-d'ombre | **Gouffre** : petit puits du Vide au curseur qui aspire, mord et Fracture | Appétit : dégâts contre élites et boss +10 % |
| Mirelle | **Éclats miroirs** : 5 éclats en éventail vers le curseur | Reflet : +15 PV max |

## Réalisation

- Données : `data/progression/echo_tree/` (`SkillNodeData`, `branch` = identifiant de l'Écho), sorts dans
  `data/techniques/`. Règles : `src/progression/echo_tree.gd`. Sorts : `src/entities/allies/techniques.gd`.
- Interface : onglet **Échos** du refuge (`src/ui/refuge/echo_tab.gd`) : liste des Échos, arbre de l'Écho
  (`echo_tree_board.gd` : Puissance et Concentration, choix « ou » entre les deux sorts, Signature) et fiche commune
  avec l'arbre du Chasseur (`skill_card.gd`). Icônes des nœuds : symboles provisoires, à illustrer (Codex).
- Les 9 nouveaux Échos (lot C7) ont leur arbre sur le même modèle : seconds sorts et signatures dans
  [ECHOS.md](ECHOS.md), section « Réalisation ». Icônes des nœuds : illustrations de Codex.

## v2 — moteur et écran (lot E1, 27 octobre 2026)

Validé par le propriétaire (« ok go ») : la proposition des arbres à 12 nœuds par Écho. Le lot E1 pose le moteur et
l'écran, **sans nouveau contenu** (chaque Écho garde ses 5 nœuds ; variantes, Instinct, Éveil et Signature B arriveront
par lots de 4 Échos, dans l'ordre de la collection).

- **La maîtrise ouvre l'arbre** : `SkillNodeData.required_mastery` (statut « scellé » tant que la maîtrise de l'Écho
  est trop basse). Second sort : maîtrise 1 ; Signature : maîtrise 3. Ce qui est déjà appris le reste.
- **Points d'Écho = 2 + maîtrise.**
- **Variantes** (`VARIANT`, prérequis = leur sort) : actives seulement avec leur sort équipé ; changer de sort retire
  les variantes de l'ancien et rend leurs points. `EchoTree.chosen_variant()` donne la variante jouée en partie.
- **Groupes exclusifs** (signatures A ou B, variantes A ou B) : activer l'un remplace l'autre (`EchoTree.rivals()`).
- **Écran** (`echo_tab.gd`, `echo_tree_board.gd`) : bandeau des trois étapes, plateau lu de gauche à droite
  (Fondations, Sort d'origine, Second sort, Apogée) avec sceaux « Maîtrise x/y », coûts sur les nœuds, pastilles Points
  d'Écho libres et Maîtrise, fiche « Pour l'utiliser » en étapes, repère doré dans la liste sur les Échos qui ont des
  points libres, page « Arbres des Échos » du guide (ouverte à la première visite de l'onglet).
