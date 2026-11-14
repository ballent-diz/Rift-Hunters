# Cour des Veilleurs — matière seule

Captures natives Godot 4.3, OpenGL Compatibility, Intel Iris Xe, 1600 × 900.
Caméra orthographique taille 20, décalage `(0, 18, 17)`, lumière de main inchangée.
Chasseur, Skitterling et Husk : sprites réels, mêmes positions et poses dans chaque paire.
Les fichiers WebP sont sans perte, sans agrandissement ni retouche de rendu.

Le propriétaire a demandé le remplacement intégral du sol : les hexagones visibles ont été remplacés par
une surface continue de terre tassée, pierre plate et mousse, sur les 336 emprises de sol, terrasses comprises.
Les escaliers gardent leur géométrie et leur matière de pierre.
Les dernières captures de détail montrent aussi 40 groupes d'herbe en vrais maillages 3D,
avec éclairage et ombres ; les plaques de mousse restent peintes dans le terrain.
Le rapport confirme les mêmes collisions et la même navigation après cet ajout.

![Ancien sol à gauche, sol terre/pierre/verdure à droite](sol_comparaison.webp)

[Vue d'ensemble du nouveau sol](ensemble_apres.webp), cadrage d'inspection plus large que le zoom de jeu.

![Comparaison au pixel écran, avant à gauche](comparaison.webp)

| Cadrage | Original | Matières et détails |
|---|---|---|
| Terrasse | [Avant](terrasse_avant.webp) | [Après](terrasse_apres.webp) |
| Escaliers | [Avant](escaliers_avant.webp) | [Après](escaliers_apres.webp) |
| Abris | [Avant](abris_avant.webp) | [Après](abris_apres.webp) |
| Entrepôts | [Avant](entrepots_avant.webp) | [Après](entrepots_apres.webp) |

[Capture d'une partie à 12 secondes avant ajout de l'herbe 3D](partie_12s.webp),
avec bot immobile/invulnérable, chapitre 1 et graine 241114.
Le lancement produit aussi une capture à 2 secondes, gardée localement pour limiter le poids du lot.

[Rapport de géométrie et collisions](controle_geometrie.json) : conforme, 7 662 triangles, 11 modules hors sol,
551 poses et 532 collisions conservées ; les 885 polygones de navigation restent identiques.
Les 336 emprises et altitudes des surfaces de sol remplacées sont contrôlées ; leurs UV ont une phase commune.
Les 23 entrées du manifeste passent également le validateur Godot.
Contrôle bitmap : 32 couleurs, 16 tuiles périodiques, terrain continu 640 px / 16 m,
23 sprites ancrés, 193 placements reproductibles de 21 variantes. Les fissures superposées sont retirées.
Import final, banc natif, contrôle natif, lancement de partie à 2/12 secondes et lint ciblé : conformes.

Le rendu pixel de Claude n'est pas inclus dans ces captures ; la lecture combinée reste à vérifier après
rapprochement des branches. La validation artistique et l'essai avec une horde restent au propriétaire.
Le banc indique 492 appels de dessin d'origine et 363 avec herbe 3D, sur les entrepôts ; ce n'est pas un benchmark de FPS.
La version du sol continu avant herbe 3D en indiquait 318.
Le premier essai de matières, avec les hexagones, en indiquait 598. Le terrain continu est désormais un maillage partagé.

Méthode, commandes de reproduction, exceptions UV et propositions d'ambiance :
[MATIERE_DES_CARTES_3D.md](../../art/MATIERE_DES_CARTES_3D.md).
