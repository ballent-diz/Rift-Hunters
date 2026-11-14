# Cour des Veilleurs — matière seule

Captures natives Godot 4.3, OpenGL Compatibility, Intel Iris Xe, 1600 × 900.
Caméra orthographique taille 20, décalage `(0, 18, 17)`, lumière de main inchangée.
Chasseur, Skitterling et Husk : sprites réels, mêmes positions et poses dans chaque paire.
Les fichiers WebP sont sans perte, sans agrandissement ni retouche de rendu.

![Comparaison au pixel écran, avant à gauche](comparaison.webp)

| Cadrage | Original | Matières et détails |
|---|---|---|
| Terrasse | [Avant](terrasse_avant.webp) | [Après](terrasse_apres.webp) |
| Escaliers | [Avant](escaliers_avant.webp) | [Après](escaliers_apres.webp) |
| Abris | [Avant](abris_avant.webp) | [Après](abris_apres.webp) |
| Entrepôts | [Avant](entrepots_avant.webp) | [Après](entrepots_apres.webp) |

[Capture d'une partie à 12 secondes](partie_12s.webp), avec bot immobile/invulnérable, chapitre 1 et graine 241114.
Le lancement produit aussi une capture à 2 secondes, gardée localement pour limiter le poids du lot.

[Rapport de géométrie et collisions](controle_geometrie.json) : conforme, 7 850 triangles, 12 modules,
551 poses et 532 collisions conservées ; les 885 polygones de navigation restent identiques.
Les 23 entrées du manifeste passent également le validateur Godot.
Contrôle bitmap : 32 couleurs, 16 tuiles périodiques, 23 sprites ancrés, 198 placements reproductibles.
Import final, banc natif, contrôle natif, lancement de partie à 2/12 secondes et lint ciblé : conformes.

Le rendu pixel de Claude n'est pas inclus dans ces captures ; la lecture combinée reste à vérifier après
rapprochement des branches. La validation artistique et l'essai avec une horde restent au propriétaire.
Le banc indique 492 appels de dessin avant et 598 après, sur les entrepôts ; ce n'est pas un benchmark de FPS.

Méthode, commandes de reproduction, exceptions UV et propositions d'ambiance :
[MATIERE_DES_CARTES_3D.md](../../art/MATIERE_DES_CARTES_3D.md).
