# Prompts pour Codex en attente (mis de côté le 3 novembre 2026)

Prompts rédigés par Claude et validés par le propriétaire, à envoyer à Codex après sa réinitialisation. Les envoyer
dans l'ordre ; chacun est autonome. Rappel pour Codex : une branche par tâche depuis `main` à jour, PR vers `main`
(AGENTS.md) ; si l'API GitHub le bloque, pousser la branche et donner son nom et son dernier commit : Claude ouvrira
la PR.

## 1. Carte 15, Cœur des marais : rambarde en double sur le pont nord-ouest

```
Tâche : retouche locale de la carte 15 « Cœur des marais » (environment.marsh_heart). Lis d'abord AGENTS.md,
docs/maps/COEUR_DES_MARAIS.md et docs/maps/QUALITE_DES_CARTES.md. Branche codex/carte-15-rambarde depuis main à jour,
PR vers main, poids indiqué. Aucun changement dans src/ ni data/.

Défaut : sur le pont nord-ouest (monde x de -690 à -540, y de -60 à 0 ; soit les pixels 980 à 1130 × 2450 à 2510 de
la carte à 1 px par unité), un morceau de rambarde est peint en double au milieu du tablier, décalé vers le bas et la
droite par rapport à la vraie rambarde sud, avec un bout de poutre rouge. Efface ce morceau et prolonge le dallage du
pont (mêmes dalles, mousse et lierre que le reste du tablier), puis continue la rambarde sud d'un seul trait jusqu'à
la colonne d'angle. Ne change ni le plan, ni l'emprise du pont, ni le reste de la carte : pixels identiques hors de
la zone retouchée (preuve numérique comme pour la correction d'échelle).

Livraison : master et tuiles régénérés (2,25 px par unité, sans perte), contrôle check_map_quality.py conforme,
capture Godot avant/après au zoom réel avec le Chasseur sur le pont. Ne touche pas à collision.png : Claude
rouvrira la collision du tablier à l'intégration.
```

## Déjà réglé (ne plus envoyer)

- Barrières de zone peintes, une par chapitre (ancien prompt 4) : livrées par Codex (25 assets `object.barrier_1` à
  `_5`, docs/art/BARRIERES_PEINTES.md), raccordées en jeu par Claude le 9 novembre (le rideau shader est retiré).
- Échelle des décors de la carte 4 et proportions des chapitres 4 et 5 : réglé le 8 novembre par la réduction du
  décor par carte (`decor_scale`, docs/maps/ECHELLE_CHAPITRES_4_5.md), sans repeindre. Proportions des cartes 16 à 25
  (ancien prompt 3) : sans objet.
- Échelle des décors de la carte 15 (ancien prompt 2) : escaliers et colonnes repeints par Codex (PR #136).
- Objets posés sur les cartes (miroirs-portails, cristaux, mannequin) : livrés par Codex (PR #131, fusionnée le
  8 novembre via #132) ; intégration en jeu à faire par Claude.
- Carte 16 : corrections de la composition, devenues sans objet (carte détaillée et intégrée en jeu).
- PR #90 (objets miroirs) et PR #92 (sprites du chapitre 4) : fusionnées.
- Image de référence des collisions de la carte 15 : le propriétaire a peint les collisions, carte intégrée.
- Rochers-abris en sprite séparé (`object.cover_rock`) : abandonné, les abris se peignent dans les décors.
