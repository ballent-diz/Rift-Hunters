# Arbres des Échos et sorts des Échos (lot C3)

Statut : **réalisé le 17 octobre 2026 — proposition à valider par le propriétaire** (noms, effets et chiffres
retouchables, tout est en données). Cadre : [COMPETENCES_ET_BUILDS.md](COMPETENCES_ET_BUILDS.md), [ECHOS.md](ECHOS.md).

## Principes

- Chaque Écho a **son propre arbre** de 5 nœuds, sur le modèle de l'arbre du Chasseur : **apprendre** coûte des
  Éclats (une fois pour toutes), **activer** coûte des **Points d'Écho**.
- **Points d'Écho = 1 + niveau de maîtrise de l'Écho** (0 à 5, soit 1 à 6 points). Jouer un Écho le rend plus fort :
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
- Les 9 nouveaux Échos (lot C7) recevront leur arbre sur le même modèle.
